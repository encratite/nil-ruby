require 'nil/xml'

class Root < Nil::XMLObject
  def initialize
    super
  end
end

class Child < Nil::XMLObject
  attr_accessor :property

  def initialize(content)
    super()
    setContent(content)
  end
end

root = Root.new

child1 = Child.new('First')
child1.property = 'value1'
root.add(child1)

child2 = Child.new('Second')
child2.property = 'value2'
root.add(child2)

puts root.serialise
