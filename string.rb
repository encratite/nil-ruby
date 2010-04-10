class String
	def extract(left, right, occurence = 1)
		offset = 0
		while occurence > 0
			offset = index(left, offset)
			return nil if offset == nil
			offset += left.size
			occurence -= 1
		end
		rightOffset = index(right, offset)
		return nil if rightOffset == nil
		output = self[offset..(rightOffset - 1)]
		return output
	end
	
	def isNumber
		pattern = /^-?((0|[1-9]\d*)(\.\d*)?|\.\d+)$/
		return pattern.match(self) != nil
	end
end
