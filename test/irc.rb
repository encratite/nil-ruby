require 'nil/irc'

def onLine(line)
	puts line
end

def getTestClient
	server = 'irc.freenode.net'
	nick = 'test'
	user = nick
	localHost = nick
	realName = nick

	client = Nil::IRCClient.new
	client.setServer(server)
	client.setUser(nick, user, localHost, realName)
	client.onLine = method(:onLine)
	client.start
	
	return client
end

def runTest
	client = getTestClient
	
	begin
		while true
			line = STDIN.readline
			client.tryToSendLine(line)
		end
	rescue EOFError
	rescue Interrupt
	end
end

runTest
