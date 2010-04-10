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
end
