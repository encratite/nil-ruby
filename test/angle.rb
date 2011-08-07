require 'nil/vector'

def combine(targets, depth, combination = [])
  if combination.size == depth
    a = Nil::Vector.new(*combination[0..2])
    b = Nil::Vector.new(*combination[3..5])
    if a.norm == 0 || b.norm == 0
      return
    end
    angle = a.angle(b)

    puts "#{a.string} #{b.string}: #{angle}"
    return
  end

  targets.each do |target|
    currentCombination = combination + [target]
    combine(targets, depth, currentCombination)
  end
  return
end

targets = [-1, 0, 1]
depth = targets.size * 2

combine(targets, depth)
