module Nil
	def getOS
		names =
		{
			'mswin32' => :windows,
			'linux' => :linux,
		}
		
		tokens = RUBY_PLATFORM.split '-'
		os = tokens[1]
		
		return names[os]
	end
end
