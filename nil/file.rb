require 'nil/string'
require 'nil/environment'

module Nil
	def self.readFile(path)
		begin
			file = File.open(path, 'rb')
			output = file.read
			file.close
			return output
		rescue Errno::ENOENT
			return nil
		end
	end
	
	def self.readLines(path)
		data = readFile path
		return nil if data == nil
		return data.split "\n"
	end
	
	def self.writeFile(path, data)
		begin
			file = File.open(path, 'wb+')
			file.write data
			file.close
		rescue Errno::EINVAL
			return nil
		end
	end
	
	def self.getFreeSpace(path)
		if getOS == :windows
			data = `dir #{path}`.split("\n")
			raise StandardError.new 'Empty directory listing output' if data.empty?
			data = data[-1].gsub(',', '')
			match = /\d+.+?(\d+)/.match(data)
			raise StandardError.new 'Unable to match free space pattern' if match == nil
			return match[1].to_i
		else
			data = `df -Pk #{path}`.split("\n")
			raise StandardError.new 'Invalid line count from df' if data.size != 2
			data = data[1].split(' ')
			raise StandardError.new 'Invalid token count from df' if data.size != 6
			data = data[3]
			raise StandardError.new 'Invalid size from df' if !data.isNumber
			output = data.to_i * 1024
			return output
		end
	end
	
	def self.readDirectory(path)
		begin
			data = Dir.entries path
			data.reject! do |entry|
				['.', '..'].include? entry
			end
		rescue Errno::ENOENT
			return nil
		end
	end
end
