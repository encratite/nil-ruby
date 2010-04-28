require 'socket'

module Nil
	class IRCClient
		DoNothing = lambda { |*arguments| }
		
		attr_writer :onConnecting, :onConnect, :onConnectError, :onConnected, :onDisconnect
		
		attr_writer :autoReconnect, :reconnectDelay
		
		def initialize
			@onConnecting = DoNothing
			@onConnect = DoNothing
			@onConnectError = DoNothing
			@onConnected = DoNothing
			@onDisconnect = DoNothing
			
			@autoReconnect = true
			@reconnectDelay = 5
			
			@gotServer = false
			@gotUser = false
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
				return Thread.new { connect }
			else
				raise 'The IRC client has not been fully initialised yet'
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
		
		def disconnected
			@onDisconnect.call
			if @autoReconnect
				sleep @reconnectDelay
				connect
			end
		end
		
		def sendLine(input)
			begin
				@socket.print(input + "\r\n")
			rescue IOError
				disconnected
			end
		end
		
		def logIn
			sendLine "NICK #{@nick}"
			sendLine "USER #{@user} \"#{@localHost}\" \"#{@host}\" :{@realName}"
			receiveData
		end
		
		def receiveData
		end
	end
end
