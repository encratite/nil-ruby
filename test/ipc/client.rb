require 'nil/ipc'
require 'configuration'

client = Nil::IPCClient.new(Path)
puts client.newMethod.inspect
