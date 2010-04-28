require 'socket'
require 'timeout'
require 'nil/random'

module Nil
	class IRCuser
		attr_reader :raw, :error, :nick, :ident, :address
		
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
			@address = tokens[1]
		end
	end
	
	class IRCClient
		DoNothing = lambda { |*arguments| }
		
		attr_writer :onConnecting, :onConnect, :onConnectError, :onConnected, :onDisconnect, :onTimeout, :onLine, :onEntry
		
		attr_writer :autoReconnect, :reconnectDelay
		
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
			
			@autoReconnect = true
			@reconnectDelay = 5
			
			@gotServer = false
			@gotUser = false
			
			@receiveTimeout = 600
			@receiveSize = 1024
			
			@maximumPingCount = 10
			
			@nickChangeDelay = 5
			
			setEvents
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
				@pingCounter = 0
				@buffer = ''
				@reclaimingNick = false
				logIn
				runReader
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
		
		def tryToSendLine(input)
			begin
				sendLine input
				return true
			rescue IOError
				return false
			end
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
				puts 'Reader'
				processData
			end
		end
		
		def receiveData
			begin
				timeout(@receiveTimeout) do
					data = @socket.recv(@receiveSize)
					puts "Got data: #{data}"
					forceDisconnect if data.empty?
					puts "Appending #{data.size} bytes to the buffer"
					@buffer.append(data)
					puts 'Appended data'
				end
			rescue Timeout::Error
				puts 'Timeout error'
				@onTimeout.call
				forceDisconnect
			end
			puts 'End of receiveData'
		end
		
		def processData
			receiveData
			puts 'Blah'
			while true
				puts 'Blah2'
				line = getLine
				puts 'Blah3'
				return if line == nil
				processLine line
			end
		end
		
		def getLine
			offset = @buffer.index("\n")
			return nil if offset == nil
			line = buffer[0..offset].chop
			newBuffer = @buffer[(offset + 1)..-1]
			@buffer.replace(newBuffer)
			return line
		end
		
		def processLine(line)
			puts "Got a line: #{line}"
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
			
			processComand tokens
		end
		
		def processCommand(tokens)
			if tokens[0] && len(tokens) == 2
				sendLine "PONG #{tokens[1]}"
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
			if message == nil
				sendLine 'QUIT'
			else
				sendLine "QUIT :#{message}"
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
	end
end
