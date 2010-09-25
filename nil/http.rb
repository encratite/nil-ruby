require 'net/http'

module Nil
	class HTTP
		def initialize(server, cookieHash = {})
			@http = Net::HTTP.new(server)
			
			cookies = []
			cookieHash.each do |key, value|
				cookies << "#{key}=#{value}"
			end
			
			cookies = cookies.join('; ')
			
			@headers =
			{
				'User-Agent' => 'User-Agent: Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3',
				'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
				'Accept-Language' => 'en-us,en;q=0.5',
				#'Accept-Encoding' => 'gzip,deflate',
				'Accept-Charset' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
				'Cookie' => cookies
			}
		end
		
		def get(path)
			begin
				@http.request_get(path, @headers) do |response|
					response.value
					return response.read_body
				end
			rescue Net::HTTPError
				return nil
			rescue
				return nil
			end
		end
		
		def post(path, input)
			data = input.map { |key, value| "#{key}=#{value}" }
			postData = data.join '&'
			begin
				@http.request_post(path, postData, @headers) do |response|
					response.value
					return response.read_body
				end
			rescue Net::HTTPError
				return nil
				
			rescue Errno::ETIMEDOUT
				return nil
				
			rescue Errno::ECONNRESET
				return nil
				
			rescue Net::HTTPFatalError
				return nil
			rescue
				return nil
			end
		end
	end
	
	def self.httpDownload(url)
		pattern = /(.+?):\/\/([^\/]+)(\/.+)/
		match = pattern.match(url)
		if match == nil
			raise 'Invalid URL specified'
		end
		protocol = match[1]
		server = match[2]
		path = match[3]
		if protocol != 'http'
			raise 'Unsupported protocol'
		end
		client = HTTP.new(server)
		return client.get(path)
	end
end
