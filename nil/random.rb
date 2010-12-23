module Nil
  def self.randomInteger(minimum, maximum)
    return minimum + rand(maximum - minimum)
  end
end
