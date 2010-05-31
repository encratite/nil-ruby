require 'socket'

require 'nil/string'

module Nil
	module IPCCommunication
		ReceiveSize = 4 * 1024
		ReceiveLimit = 100 * ReceiveSize
		
		def self.bufferErrorCheck(buffer, socket)
			if buffer.size > ReceiveLimit
				socket.close
				raise IPCError.new("Buffer size exceeded: #{buffer.size}")
			end
		end
		
		def self.processUnit(socket, buffer)
			while true
				data = socket.recv(ReceiveSize)
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
				buffer = buffer[(ofset + 1)..-1]
				while buffer.size < length
					buffer.concat(socket.recv(ReceiveSize))
					bufferErrorCheck(buffer, socket)
				end
				serialisedData = buffer[0..(length - 1)]
				buffer = buffer[length..-1]
				begin
					deserialisedData = Marshal.load(serialisedData)
					return deserialisedData
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
		def initialize(path)
			if !File.exists?(path)
				File.rm(path)
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
					call = IPCCommunication.processUnit(client, buffer)
					processData(call, buffer)
				rescue IPCError => exception
					puts "An IPC error occured: #{exception.message}"
					return
				rescue RuntimeError => exception
					puts "An error occured while processing deserialised data: #{exception.message}"
					return
				end
			end
		end
		
		def processData(call, client)
			if call.class != IPCCall
				raise "Invalid IPC call object: #{call.class}"
			end
			if @methods.include?(call.symbol)
				output = nil
				begin
					function = method(call.symbol)
					output = function(*call.arguments)
				rescue rescue ArgumentError
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
		
		def call(socket)
			IPCCommunication.sendData(socket, self)
			output = IPCCommunication.processUnit(socket, buffer)
			raise output if output.class == IPCError
			return output
		end
	end
	
	class IPCError
		attr_reader :message
		
		def initialize(message)
			@message = message
		end
	end
	
	class IPCClient
		def initialize(path)
			@socket = UNIXSocket.new(path)
			receiveMethods
		end
		
		def receiveMethods
			methods = IPCCall.new(:getMethods, []).call(@socket)
			methods.each do |method|
				extend Module.new
					define_method(method) |*arguments|
						ipc = IPCCall.new(method, arguments).call(@socket)
						return ipc.call(@socket)
					end
				end
			end
		end
	end
end
