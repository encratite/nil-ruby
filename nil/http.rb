require 'cgi'
require 'net/http'

module Nil
	class HTTP
		attr_accessor :ssl
		def initialize(server, cookieHash = {})
			@http = nil
			
			cookies = []
			cookieHash.each do |key, value|
				value = CGI.escape(value)
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
			
			@ssl = false
			@port = nil
			@server = server
		end
		
		def httpInitialisation
			if @http == nil
				if @ssl
					defaultPort = 443
				else
					defaultPort = 80					
				end
				@port = defaultPort if @port == nil
				@http = Net::HTTP.new(@server, @port)
				if @ssl
					@http.use_ssl = true
					@http.verify_mode = OpenSSL::SSL::VERIFY_NONE
				end
			end
		end
		
		def get(path)
			httpInitialisation
			
			begin
				@http.request_get(path, @headers) do |response|
					response.value
					return response.read_body
				end
			rescue SystemCallError, Net::ProtocolError, RuntimeError, IOError => exception
				puts "GET exception: #{exception.inspect}"
				return nil
			end
		end
		
		def post(path, input)
			httpInitialisation
			
			data = input.map { |key, value| "#{key}=#{value}" }
			postData = data.join '&'
			begin
				@http.request_post(path, postData, @headers) do |response|
					response.value
					return response.read_body
				end
			rescue SystemCallError, Net::ProtocolError, RuntimeError, IOError => exception
				puts "POST exception: #{exception.inspect}"
				return nil
			end
		end
	end
	
	def self.httpDownload(url, cookieHash = {})
		pattern = /(.+?):\/\/([^\/]+)(\/.+)/
		match = pattern.match(url)
		if match == nil
			raise 'Invalid URL specified'
		end
		protocol = match[1]
		server = match[2]
		path = match[3]
		case protocol
		when 'http'
		when 'https'
			client.ssl = true
		else
			raise 'Unsupported protocol'
		end
		client = HTTP.new(server, cookieHash)
		return client.get(path)
	end
end
