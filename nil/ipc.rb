require 'socket'

require 'nil/string'

module Nil
	ReceiveSize = 4 * 1024
	ReceiveLimit = 100 * ReceiveSize
	
	class IPCServer
		def initialize(path)
			if !File.exists?(path)
				File.rm(path)
			end
			@path = path
			@methods = [:getMethods]
		end
		
		def run
			buffer = ''
			server = UNIXServer.new(@path)
			File.chmod(0600, @path)
			while true
				client = server.accept
				processClient(client)
			end
		end
		
		def bufferError(buffer, client)
			if buffer.size > ReceiveLimit
				puts "Buffer size exceeded: #{buffer.size}"
				client.close
				return true
			else
				return false
			end
		end
		
		def processClient(client)
			while true
				data = client.recv(ReceiveSize)
				buffer.concat data
				return if bufferError(buffer, client)				
				offset = buffer.index(':')
				next if offset == nil
				lengthString = buffer[0..(offset - 1)]
				if !lengthString.isNumber
					puts "Invalid length string: #{lengthString}"
					client.close
					return
				end
				length = lengthString.to_i
				buffer = buffer[(ofset + 1)..-1]
				while buffer.size < length
					buffer.concat(client.recv(ReceiveSize))
					return if bufferError(buffer, client)
				end
				serialisedData = buffer[0..(length - 1)]
				buffer = buffer[length..-1]
				if !processData(serialisedData, client)
					client.close
					return
				end
			end
		end
		
		def processData(input, client)
			begin
				call = Marshal.load(input)
				if call.class != IPCCall
					puts "Invalid IPC call object: #{call.class}"
					return false
				end
				output = nil
				if @methods.include?(call.symbol)
					begin
					function = method(call.symbol)
					rescue rescue ArgumentError
						output = IPCError.new("Invalid argument count for method \"#{call.symbol}\"")
					end
					output = function(*call.arguments)
				else
					output = IPCError.new("Unknown method \"#{call.symbol}\"")
				end
				outputData = Marshal.dump(output)
				client.print(outputData)
				return true
			rescue TypeError
				puts 'Invalid Marshal data'
				return false
			end
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
		
		def call(client)
			data = Marshal.dump(self)
			packet = "#{data.size}:#{data}"
			client.print(packet)
			#need to receive the reply here with proper deserialisation
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
						ipc = IPCCall.new(method, arguments)
						call = ipc.call(@socket)
					end
				end
			end
		end
	end
end
