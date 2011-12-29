require 'nil/file'

module Nil
  def self.serialise(object, path)
    contents = Marshal.dump(object)
    Nil.writeFile(path, contents)
  end

  def self.deserialise(path)
    contents = Nil.readFile(path)
    if contents == nil
      raise "No such file \"#{path}\""
    end
    return Marshal.load(contents)
  end
end
