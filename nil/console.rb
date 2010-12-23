require 'thread'

require_relative 'environment'

module Nil
  ConsoleMutex = Mutex.new

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

  class ColumnBreadthManager
    def initialize
      @columnSizes = {}
      @lastColumn = 0
    end

    def process(columnIndex, string)
      value = @columnSizes[columnIndex]
      if value == nil
        newValue = string.size
      else
        newValue = [value, string.size].max
      end
      @columnSizes[columnIndex] = newValue
      @lastColumn = [columnIndex, @lastColumn].max
    end

    def get(columnIndex)
      return [@columnSizes[columnIndex], columnIndex == @lastColumn]
    end
  end

  class RowOperator
    def initialize(rows)
      @rows = rows
    end

    def operate(&block)
      @rows.each do |row|
        offset = 0
        row.each do |column|
          block.call(offset, column)
          offset += 1
        end
      end
    end
  end

  def self.printTable(rows)
    minimumDistance = 4
    columns = ColumnBreadthManager.new
    rowOperator = RowOperator.new(rows)
    rowOperator.operate do |offset, column|
      columns.process(offset, column)
    end
    rowOperator.operate do |offset, column|
      size, isLast = columns.get(offset)
      string = column + (' ' * (minimumDistance + size - column.size))
      print string
      print "\n" if isLast
    end
  end

  def self.threadPrint(message)
    ConsoleMutex.synchronize { puts message }
  end
end
