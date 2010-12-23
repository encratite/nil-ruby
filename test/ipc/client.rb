require 'nil/ipc'
require 'configuration'

client = Nil::IPCClient.new(Path)
while true
  puts client.newMethod.inspect
  STDIN.readline
end
