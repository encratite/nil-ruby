require 'nil/http'

client = Nil::HTTP.new('www.google.com')
client.ssl = true
data = client.get('/')
puts data.inspect
