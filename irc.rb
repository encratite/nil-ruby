require 'socket'
require 'timeout'

module Nil
	class IRCClient
		DoNothing = lambda { |*arguments| }
		
		attr_writer :onConnecting, :onConnect, :onConnectError, :onConnected, :onDisconnect, :onTimeout, :onLine
		
		attr_writer :autoReconnect, :reconnectDelay
		
		def initialize
			@onConnecting = DoNothing
			@onConnect = DoNothing
			@onConnectError = DoNothing
			@onConnected = DoNothing
			@onDisconnect = DoNothing
			@onTimeout = DoNothing
			@onLine = DoNothing
			
			@autoReconnect = true
			@reconnectDelay = 5
			
			@gotServer = false
			@gotUser = false
			
			@receiveTimeout = 600
			@receiveSize = 1024
		end
		
		def setServer(host, port)
			@host = host
			@port = port
			@gotServer = true
		end
		
		def setUser(nick, user, localHost, realName)
			@nick = nick
			@user = user
			@localHost = localHost
			@realName = realName
			@gotUser = true
		end
		
		def start
			if @gotServer && @gotuser
				return Thread.new { serverHandler }
			else
				raise 'The IRC client has not been fully initialised yet'
			end
		end
		
		def serverHandler
			while true
				begin
					connect
				rescue IOError
					@onDisconnect.call
					if @autoReconnect
						sleep @reconnectDelay
					else
						return
					end
				end
			end
		end
		
		def connect
			begin
				@onConnecting.call
				@socket = TCPSocket.open(@host, @port)
				@onConnected.call
				logIn
			rescue Errno::ECONNREFUSED
				@onConnectError.call
			rescue Errno::ETIMEDOUT
				@onConnectError.call
			end
			return nil
		end
		
		def sendLine(input)
			@socket.print(input + "\r\n")
		end
		
		def logIn
			sendLine "NICK #{@nick}"
			sendLine "USER #{@user} \"#{@localHost}\" \"#{@host}\" :#{@realName}"
			receiveData
		end
		
		def receiveData
			buffer = ''
			while true
				begin
					Timeout::timeout(@receiveTimeout) do
						data = @socket.recv(@receiveSize)
						raise IOError if data.empty?
						buffer.append data
					end
				rescue Timeout::Error
					@onTimeout.call
					raise IOError
				end
				
				processData buffer
			end
		end
		
		def processData(buffer)
			while true
				offset = buffer.index("\n")
				return if offset == nil
				line = buffer[0..offset].chop
				newBuffer = buffer[(offset + 1)..-1]
				buffer.replace(newBuffer)
				processLine line
			end
		end
		
		def processLine(line)
			@onLine.call(line)
			#continue here
		end
	end
end
