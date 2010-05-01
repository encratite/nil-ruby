require 'nil/environment'

module Nil
	module Console
		LightGrey = "\e[0;37m"
		LightRed = "\e[1;31m"
		LightGreen = "\e[1;32m"
		LightBlue = "\e[1;34m"
		LightCyan = "\e[1;36m"
		DarkGrey = "\e[1;30m"
		
		Black = "\e[0;30m"
		Red = "\e[0;31m"
		Green = "\e[0;32m"
		Brown = "\e[0;33m"
		Blue = "\e[0;34m"
		Purple = "\e[0;35m"
		Cyan = "\e[0;36m"
		Yellow = "\e[1;33m"
		Pink = "\e[1;35m"
		White = "\e[1;37m"
		
		Normal = "\e[0m"
	end
	
	def self.colouredText(text, colour)
		#Windows doesn't support terminal colour codes by default
		return text if getOS == :windows
		colour = Console.const_get colour
		return colour + text + Console::Normal
	end
	
	def self.defineConsoleColours
		output = []
		Console.constants.each do |symbol|
			name = symbol.to_s
			name = name[0].downcase + name[1..-1]
			functionSymbol = name.to_sym
			self.send :define_method, functionSymbol do |text|
				self.colouredText(text, symbol)
			end
			output << functionSymbol
		end
		return output
	end
	
	self.defineConsoleColours.each { |symbol| module_function symbol }
end
