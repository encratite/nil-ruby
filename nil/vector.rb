module Nil
  class Vector
    attr_reader :values

    def initialize(*values)
      @values = values
      Vector.defineOperations
    end

    def self.defineOperations
      operationMap = {
        :+ => lambda { |x, y| x + y },
        :- => lambda { |x, y| x - y },
        :* => lambda { |x, y| x * y },
        :/ => lambda { |x, y| x / y },
      }
      operationMap.each do |symbol, operation|
        define_method(symbol) do |other|
          sizeCheck(other)
          values = []
          @values.size.times do |i|
            values << operation.call(@values[i], other.values[i])
          end
          Vector.new(*values)
        end
      end
    end

    def sizeCheck(other)
      if @values.size != other.values.size
        raise "Vector size mismatch"
      end
    end

    def string
      valueString = @values.join(', ')
      return "[#{valueString}]"
    end

    def x
      return @values[0]
    end

    def y
      return @values[1]
    end

    def z
      return @values[2]
    end

    def scale(factor)
      Vector.new(@values.map { |x| x * factor })
    end

    def dotProduct(other)
      sizeCheck(other)
      sum = 0.0
      @values.size.times do |i|
        sum += @values[i] * other.values[i]
      end
      return sum
    end

    def norm
      if @values.size != 3
        raise "Can't calculate the Euclidean norm of a vector with the dimension #{@values.size}"
      end
      sum = 0.0
      @values.each do |value|
        sum += value ** 2
      end
      return sum ** 0.5
    end

    def angle(other)
      thisNorm = norm
      otherNorm = other.norm
      if [thisNorm, otherNorm].include?(0.0)
        raise 'Cannot determine the angle between two vectors if one of them is a zero vector'
      end
      argument = dotProduct(other) / thisNorm / otherNorm
      argument = [argument, 1].min
      argument = [argument, -1].max
      output = Math.acos(argument)
      return output
    end
  end
end
