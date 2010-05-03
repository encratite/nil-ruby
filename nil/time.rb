module Nil
	def self.timestamp
		string = Time.now.utc.to_s
		tokens = string.split(' ')[0..-2]
		return tokens.join(' ')
	end
end
