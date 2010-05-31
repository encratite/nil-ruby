require 'nil/ipc'
require 'configuration'

class TestServer < Nil::IPCServer
	def initialize(path)
		super
		@methods << :newMethod
	end
	
	def newMethod
		return [1, 2, 3, 'test']
	end
end

server = TestServer.new(Path)
server.run
