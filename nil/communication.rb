module Nil
	class SerialisedCommunication
		attr_reader :socket
		
		ReceiveSize = 4 * 1024
		ReceiveLimit = 100 * ReceiveSize
		
		class CommunicationError < Exception
		end
		
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
		
		def initialize(socket, exception)
			@socket = socket
			@exception = exception
			@buffer = ''
		end
		
		def bufferErrorCheck
			if @buffer.size > ReceiveLimit
				@socket.close
				raise CommunicationError.new("Buffer size exceeded: #{@buffer.size}")
			end
		end
		
		def processUnit
			while true
				data = @socket.recv(ReceiveSize)
				if data.empty?
					return CommunicationResult.closedResult
				end
				@buffer.concat data
				bufferErrorCheck
				offset = @buffer.index(':')
				next if offset == nil
				lengthString = @buffer[0..(offset - 1)]
				if !lengthString.isNumber
					@socket.close
					raise CommunicationError.new("Invalid length string: #{lengthString}")
				end
				length = lengthString.to_i
				@buffer.replace(@buffer[(offset + 1)..-1])
				while @buffer.size < length
					@buffer.concat(@socket.recv(ReceiveSize))
					bufferErrorCheck
				end
				serialisedData = @buffer[0..(length - 1)]
				@buffer.replace(@buffer[length..-1])
				begin
					deserialisedData = deserialiseData(serialisedData)
					return CommunicationResult.valueResult(deserialisedData)
				rescue @exception
					@socket.close
					raise CommunicationError.new('Failed to deserialise data')
				end
			end
		end
		
		def sendData(input)
			data = serialiseData(input)
			packet = "#{data.size}:#{data}"
			@socket.print(packet)
		end
		
		def serialiseData(input)
			raise 'Serialising data has not been implemented'
		end
		
		def deserialiseData(input)
			raise 'Deserialising data has not been implemented'
		end
	end
end
