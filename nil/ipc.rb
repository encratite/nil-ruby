require 'socket'

require 'nil/string'

module Nil
	ReceiveSize = 4 * 1024
	ReceiveLimit = 100 * ReceiveSize
	
	class IPCServer
		def initialize(path)
			if !File.exists?(path)
				UNIXServer.new(path)
				File.chmod(0600, path)
			end
			@path = path
			@methods = []
		end
		
		def run
			buffer = ''
			server = UNIXSocket.open(@path)
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
				if !@methods.include?(call.symbol)
					puts "Illegal IPC call to non IPC method #{call.symbol}"
					return false
				end
				function = method(call.symbol)
				output = function(*call.arguments)
				outputData = Marshal.dump(output)
				client.print(outputData)
				return true
			rescue TypeError
				puts 'Invalid Marshal data'
				return false
			rescue ArgumentError
				puts 'Invalid argument count'
				return false
			end
		end
	end
	
	class IPCCall
		attr_reader :symbol, :arguments
		
		def initialize(symbol, arguments)
			@symbol = symbol
			@arguments = arguments
		end
	end
end
