module Nil
	def self.readFile(path)
		begin
			file = File.open(path, 'rb')
			output = file.read
			file.close
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
end
