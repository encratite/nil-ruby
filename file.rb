module Nil
	def self.readFile(path)
		begin
			file = File.open(path, 'r')
			return file.read
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
			file = File.open(path, 'w+')
			file.write data
		rescue Errno::EINVAL
			return nil
		end
	end
end
