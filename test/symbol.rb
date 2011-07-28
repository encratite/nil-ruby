require 'nil/symbol'

class Test
  include SymbolicAssignment
end

test = Test.new
test.setPublicMember(:test, 'test')
puts test.test
