module Nil
	def self.getOS
		names =
		{
			'mswin32' => :windows,
			'linux' => :linux,
		}
		
		tokens = RUBY_PLATFORM.split '-'
		os = tokens[1]
		
		return names[os]
	end
	
	def self.getUser
		return ENV['USER']
	end
	
	def self.getHost
		if self.getOS == :windows
			#this doesn't look right
			return ENV['USERDOMAIN']
		else
			return ENV['HOSTNAME']
		end
	end
end
