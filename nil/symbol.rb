module SymbolicAssignment
	def setMember(symbol, value)
		symbol = ('@' + symbol.to_s).to_sym
		instance_variable_set(symbol, value)
	end
end
