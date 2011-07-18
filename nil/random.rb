module Nil
  class RandomScaleElement
    attr_reader :element, :weight

    def initialize(element, weight)
      @element = element
      @weight = weight
    end
  end

  class RandomScale
    def initialize
      @elements = []
      @totalWeight = 0
    end

    def add(element, weight)
      @elements << RandomScaleElement.new(element, weight)
      @totalWeight += weight
    end

    def get
      choice = rand(@totalWeight)
      @elements.each do |element|
        if choice < element.weight
          return element.element
        end
        choice -= element.weight
      end
      raise 'Failed to retrieve an element'
    end
  end

  def self.randomInteger(minimum, maximum)
    return minimum + rand(maximum - minimum)
  end
end
