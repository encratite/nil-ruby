module Nil
	def self.extractString(input, left, right, occurence = 1)
		offset = 0
		while occurence > 0
			offset = input.index(left, offset)
			return nil if offset == nil
			offset += left.size
			occurence -= 1
		end
		rightOffset = input.index(right, offset)
		return nil if rightOffset == nil
		output = input[offset..(rightOffset - 1)]
		return output
	end
end
