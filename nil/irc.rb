require 'socket'
require 'openssl'
require 'timeout'

require_relative 'random'

module Nil
	class IRCUser
		attr_reader :raw, :error, :nick, :ident, :host
		
		def initialize(input)
			@raw = input
			tokens = input[1..-1].split('!')
			@error = tokens.size != 2
			return if @error
			
			@nick = tokens[0]
			
			tokens = tokens[1].split('@')
			@error = true if tokens.size != 2
			return if @error
			
			@ident = tokens[0]
			@host = tokens[1]
		end
	end
	
	class IRCClient
		DoNothing = lambda { |*arguments| }
		
		attr_reader :nick
		
		attr_writer :onConnecting, :onConnect, :onConnectError, :onConnected, :onDisconnect, :onTimeout, :onLine, :onEntry, :onNickInUse, :onNotice, :onInvite, :onJoin, :onPrivateMessage, :onChannelMessage, :onQuit, :onSendLine
		
		attr_writer :autoReconnect, :reconnectDelay
		
		attr_writer :ssl
		
		def initialize
			@onConnecting = DoNothing
			@onConnect = DoNothing
			@onConnectError = DoNothing
			@onConnected = DoNothing
			@onDisconnect = DoNothing
			@onTimeout = DoNothing
			@onLine = DoNothing
			@onEntry = DoNothing
			@onNickInUse = method(:reclaimNick)
			@onNotice = DoNothing
			@onInvite = DoNothing
			@onJoin = DoNothing
			@onPrivateMessage = DoNothing
			@onChannelMessage = DoNothing
			@onQuit = DoNothing
			@onSendLine = DoNothing
			
			@autoReconnect = true
			@reconnectDelay = 5
			
			@gotServer = false
			@gotUser = false
			
			@ssl = false
			
			@receiveTimeout = 600
			@receiveSize = 1024
			
			@maximumPingCount = 20
			
			@nickChangeDelay = 5
			
			setEvents
			
			Thread.abort_on_exception = true
		end
		
		def setServer(host, port = 6667)
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
		
		def setEvents
			@events =
			[
				['376', :eventEndOfMotd],
				['422', :eventEndOfMotd],
				['433', :eventNickInUse],
				['437', :eventNickInUse],
				['NOTICE', :eventNotice],
				['INVITE', :eventInvite],
				['JOIN', :eventJoin],
				['PRIVMSG', :eventMessage],
				['MODE', :eventMode],
				['QUIT', :eventQuit]
			].map do |string, symbol|
				[string, method(symbol)]
			end			
		end
		
		def start
			if @gotServer && @gotUser
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
					puts 'IOError occurred!'
					reconnect
				rescue SystemCallError
					reconnect
				rescue SocketError
					puts 'Socket error occurred!'
					reconnect
				end
			end
		end
		
		def connect
			begin
				@onConnecting.call
				@socket = TCPSocket.open(@host, @port)
				
				if @ssl
					@socket = OpenSSL::SSL::SSLSocket.new(@socket)
					@socket.sync_close = true
					@socket.connect
				end

				@onConnected.call
				@pingCounter = 0
				@buffer = ''
				@reclaimingNick = false
				logIn
				runReader
			rescue SystemCallError
				@onConnectError.call
			end
			return nil
		end
		
		def reconnect
			@onDisconnect.call
			if @autoReconnect
				sleep @reconnectDelay
			else
				return
			end
		end
		
		def sendLine(input)
			@onSendLine.call(input)
			@socket.print(input + "\r\n")
		end
		
		def tryToSendLine(input)
			begin
				sendLine input
				return true
			rescue IOError
				return false
			end
		end
		
		def sendMessage(target, text)
			tryToSendLine "PRIVMSG #{target} :#{text}"
		end
		
		def joinChannel(channel)
			tryToSendLine "JOIN #{channel}"
		end
		
		def logIn
			changeNick @nick
			sendLine "USER #{@user} \"#{@localHost}\" \"#{@host}\" :#{@realName}"
		end
		
		def forceDisconnect
			@socket.close
			raise IOError
		end
		
		def runReader
			while true
				processData
			end
		end
		
		def receiveData
			begin
				timeout(@receiveTimeout) do
					if @socket.class == TCPSocket
						data = @socket.recv(@receiveSize)
					else
						data = @socket.readpartial(@receiveSize)
					end
					forceDisconnect if data.empty?
					@buffer.concat(data)
				end
			rescue Timeout::Error
				@onTimeout.call
				forceDisconnect
			end
		end
		
		def processData
			receiveData
			while true
				line = getLine
				return if line == nil
				processLine line
			end
		end
		
		def getLine
			offset = @buffer.index("\n")
			return nil if offset == nil
			line = @buffer[0..offset].chop
			newBuffer = @buffer[(offset + 1)..-1]
			@buffer.replace(newBuffer)
			return line
		end
		
		def processLine(line)
			@onLine.call(line)
			return if line.empty?
			delimiter = ' '
			offset = line.index(':', 1)
			if offset == nil
				tokens = line.split(delimiter)
			else
				tokens = line[0..(offset - 2)].split(delimiter)
				tokens << line[(offset + 1)..-1]
			end
			
			processCommand(tokens, line)
		end
		
		def processCommand(tokens, line)
			if tokens[0] == 'PING' && tokens.size == 2
				sendLine "PONG #{line[5..-1]}"
				@pingCounter += 1
				forceDisconnect if @maximumPingCount != nil && @pingCounter >= @maximumPingCount
				return
			end
			
			return if tokens.size < 3
			
			@pingCounter = 0
			
			@events.each do |identifier, handler|
				if identifier == tokens[1]
					handler.call(tokens)
					break
				end
			end
		end
		
		def generateNick
			return @nick + randomInteger(100, 999).to_s
		end
		
		def changeNick(newNick)
			sendLine "NICK #{newNick}"
		end
		
		def quit(message = nil)
			begin
				if message == nil
					sendLine 'QUIT'
				else
					sendLine "QUIT :#{message}"
				end
				@autoReconnect = false
				@socket.close
			rescue IOError
			end
		end
			
		def eventEndOfMotd(tokens)
			@actualNick = tokens[2]
			@onNickInUse.call if @actualNick != @nick
			@onEntry.call
		end
		
		def reclaimNick
			while true
				changeNick @nick
				sleep @nickChangeDelay
				processData
				return if @actualNick == @nick
			end
		end
			
		def eventNickInUse(tokens)
			@onNickInUse.call
		end
			
		def eventNotice(tokens)
			user = IRCUser.new(tokens[0])
			return if user.error
			text = tokens[-1]
			@onNotice.call(user, text)
		end
			
		def eventInvite(tokens)
			user = IRCUser.new(tokens[0])
			return if user.error
			channel = tokens[-1]
			@onInvite.call(user, channel)
		end
			
		def eventJoin(tokens)
			user = IRCUser.new(tokens[0])
			return if user.error
			ownJoin = (user.nick == @actualNick)
			channel = tokens[-1]
			@onJoin.call(channel, user, ownJoin)
		end
			
		def eventMessage(tokens)
			user = IRCUser.new(tokens[0])
			return if user.error
			target = tokens[2]
			message = tokens[-1]
			if target == @nick
				@onPrivateMessage.call(user, message)
			else
				@onChannelMessage.call(target, user, message)
			end
		end
				
		def eventMode(tokens)
			return
		end
			
		def eventQuit(tokens)
			user = IRCUser.new(tokens[0])
			return if user.error
				return
			message = tokens[-1]
			@onQuit.call(user, message)
		end
		
		def self.stripTags(input)
			output = ''	
			
			i = 0
			lastIndex = input.length - 1
			while i <= lastIndex
				currentChar = input[i]
				if currentChar.ord < ' '.ord
					if currentChar == "\x03" and lastIndex - i >= 2
						nextChar = input[i + 1]
						nextCharValue = nextChar.ord
						if nextChar == '1'
							i += 1
							second_digit = input[i + 1].ord
							if second_digit >= '0'.ord and second_digit <= '5'.ord
								i += 1
							end
						elsif nextChar == '0'
							i += 2
						elsif nextCharValue >= '2'.ord and nextCharValue <= '9'.ord
							i += 1
						end
					end
				else
					output += currentChar
				end
				i += 1
			end
			return output
		end
	end
end
