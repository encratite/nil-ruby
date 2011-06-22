require 'cgi'
require 'net/http'
require 'uri'
require 'openssl'

module Nil
  class HTTP
    Debugging = false

    attr_accessor :ssl

    def initialize(server, cookies = {})
      @http = nil
      @cookies = cookies
      @ssl = false
      @port = nil
      @server = server
    end

    def setHeaders
      cookieArray = []
      @cookies.each do |key, value|
        value = CGI.escape(value)
        cookieArray << "#{key}=#{value}"
      end

      cookieString = cookieArray.join('; ')

      @headers =
        {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:2.0.1) Gecko/20100101 Firefox/4.0.1',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language' => 'en-us,en;q=0.5',
        #'Accept-Encoding' => 'gzip,deflate',
        'Accept-Charset' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
        'Cookie' => cookieString
      }
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
      setHeaders
    end

    def get(path, origin = nil)
      puts "GET #{path}" if Debugging
      httpInitialisation

      begin
        response = @http.request_get(path, @headers)
        processResponse(response)
        location = response.header['Location']
        if location != nil
          newPath = locationToPath(location)
          return nil if newPath == nil
          if newPath == path
            puts "Circular referral: #{newPath}"
          end
          return get(newPath, path)
        end
        return response.body
      rescue SystemCallError, Net::ProtocolError, RuntimeError, IOError, SocketError, OpenSSL::SSL::SSLError => exception
        puts "GET exception: #{exception.inspect}"
        return nil
      end
    end

    def getPostData(input)
      data = input.map do |key, value|
        escapedValue = URI.escape(value)
        "#{key}=#{escapedValue}"
      end
      postData = data.join '&'
      return postData
    end

    def cookieHandler(name, value)
      @cookies[name] = value
    end

    def processResponse(response)
      setCookie = response.header['set-cookie']
      if setCookie != nil
        ignore = ['expires', 'path', 'domain']
        pattern = /([^ ]+?)=([^ ;,]+)/
        setCookie.scan(pattern) do |match|
          name = match[0]
          next if ignore.include?(name)
          value = CGI.unescape(match[1])
          cookieHandler(name, value)
        end
      end
      #puts @cookies.inspect
    end

    def locationToPath(location)
      pattern = /[a-z]+:\/\/(.+?)(\/.*)/
      match = location.match(pattern)
      if match == nil
        puts "Invalid location specified: #{location}"
        return nil
      end
      if match[1] != @server
        puts "Server mismatch: #{match[1]} vs. #{@server}"
        return nil
      end
      return match[2]
    end

    def post(path, input)
      puts "POST #{path}" if Debugging
      httpInitialisation

      postData = getPostData(input)
      begin
        response = @http.request_post(path, postData, @headers)
        processResponse(response)
        location = response.header['Location']
        if location != nil
          newPath = locationToPath(location)
          return nil if newPath == nil
          return get(newPath, path)
        end
        return response.body
        #@http.request_post(path, postData, @headers) do |response|
        #  processResponse(response)
        #  response.value
        #  return response.read_body
        #end
      rescue SystemCallError, Net::ProtocolError, RuntimeError, IOError, SocketError, OpenSSL::SSL::SSLError => exception
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
    client = HTTP.new(server, cookieHash)
    case protocol
    when 'http'
    when 'https'
      client.ssl = true
    else
      raise 'Unsupported protocol'
    end
    return client.get(path)
  end
end
