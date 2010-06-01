require 'socket'
require 'fileutils'

require 'nil/string'

module Nil
	module IPCCommunication
		ReceiveSize = 4 * 1024
		ReceiveLimit = 100 * ReceiveSize
		
		class CommunicationResult
			attr_accessor :connectionClosed, :value
			
			def self.closedResult
				output = CommunicationResult.new
				output.connectionClosed = true
				return output
			end
			
			def self.valueResult(value)
				output = CommunicationResult.new
				output.connectionClosed = false
				output.value = value
				return output
			end
		end
		
		def self.bufferErrorCheck(buffer, socket)
			if buffer.size > ReceiveLimit
				socket.close
				raise IPCError.new("Buffer size exceeded: #{buffer.size}")
			end
		end
		
		def self.processUnit(socket, buffer)
			while true
				data = socket.recv(ReceiveSize)
				if data.empty?
					return CommunicationResult.closedResult
				end
				buffer.concat data
				bufferErrorCheck(buffer, socket)				
				offset = buffer.index(':')
				next if offset == nil
				lengthString = buffer[0..(offset - 1)]
				if !lengthString.isNumber
					socket.close
					raise IPCError.new("Invalid length string: #{lengthString}")
				end
				length = lengthString.to_i
				buffer.replace(buffer[(offset + 1)..-1])
				while buffer.size < length
					buffer.concat(socket.recv(ReceiveSize))
					bufferErrorCheck(buffer, socket)
				end
				serialisedData = buffer[0..(length - 1)]
				buffer.replace(buffer[length..-1])
				begin
					deserialisedData = Marshal.load(serialisedData)
					return CommunicationResult.valueResult(deserialisedData)
				rescue TypeError
					socket.close
					raise IPCError.new('Failed to deserialise data')
				end
			end
		end
		
		def self.sendData(socket, input)
			data = Marshal.dump(input)
			packet = "#{data.size}:#{data}"
			socket.print(packet)
		end
	end
	
	class IPCServer
		class InvalidCall < RuntimeError
		end

		def initialize(path)
			if File.exists?(path)
				FileUtils.rm(path)
			end
			@path = path
			@methods = [:getMethods]
		end
		
		def run
			server = UNIXServer.new(@path)
			File.chmod(0600, @path)
			while true
				client = server.accept
				processClient(client)
			end
		end
		
		def processClient(client)
			buffer = ''
			while true
				begin
					result = IPCCommunication.processUnit(client, buffer)
					if result.connectionClosed
						#puts 'Client closed the connection'
						return
					end
					processData(result.value, client)
				rescue IPCError => exception
					puts "An IPC error occurred: #{exception.message}"
					return
				rescue InvalidCall => exception
					puts exception.message
					return
				rescue Errno::EPIPE
					puts 'Broken pipe'
					return
				end
			end
		end
		
		def processData(call, client)
			if call.class != IPCCall
				client.close
				raise InvalidCall.new("Invalid IPC call object: #{call.class}")
			end
			if @methods.include?(call.symbol)
				output = nil
				begin
					function = method(call.symbol)
					output = function.call(*(call.arguments))
				rescue ArgumentError
					output = IPCError.new("Invalid argument count for method \"#{call.symbol}\"")
				end
			else
				output = IPCError.new("Unknown method \"#{call.symbol}\"")
			end
			IPCCommunication.sendData(client, output)
		end
		
		def getMethods
			return @methods
		end
	end
	
	class IPCCall
		attr_reader :symbol, :arguments
		
		def initialize(symbol, arguments)
			@symbol = symbol
			@arguments = arguments
		end
		
		def call(socket, buffer)
			IPCCommunication.sendData(socket, self)
			result = IPCCommunication.processUnit(socket, buffer)
			raise IPCError.new('The server closed the connection') if result.connectionClosed
			output = result.value
			raise output if output.class == IPCError
			return output
		end
	end
	
	class IPCError < RuntimeError
	end
	
	class IPCClient
		def initialize(path)
			@socket = UNIXSocket.new(path)
			@buffer = ''
			receiveMethods
		end
		
		def receiveMethods
			methods = IPCCall.new(:getMethods, []).call(@socket, @buffer)
			methods.each do |method|
				extend(
					Module.new do
						define_method(method) do |*arguments|
							ipc = IPCCall.new(method, arguments)
							return ipc.call(@socket, @buffer)
						end
					end
				)
			end
		end
	end
end
