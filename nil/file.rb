require_relative 'string'
require_relative 'environment'

module Nil
  class FileInformation
    attr_reader :name, :path, :timeAccessed, :timeCreated, :timeModified, :symlink

    def initialize(path)
      @name = File.basename(path)
      @path = path
      if File.symlink?(path)
        data = File.lstat(path)
      else
        data = File.stat(path)
      end
      @timeAccessed = data.atime.utc
      @timeCreated = data.ctime.utc
      @timeModified = data.mtime.utc
    end
  end

  def self.getFileInformation(path)
    begin
      return FileInformation.new(path)
    rescue Errno::ENOENT
      return nil
    end
  end

  def self.readFile(path)
    begin
      file = File.open(path, 'rb')
      output = file.read
      file.close
      return output
    rescue Errno::ENOENT
      return nil
    end
  end

  def self.readLines(path)
    data = readFile path
    return nil if data == nil
    data = data.gsub("\r", '')
    return data.split "\n"
  end

  def self.writeFile(path, data)
    begin
      file = File.open(path, 'wb+')
      file.write data
      file.close
    rescue Errno::EINVAL
      return nil
    end
  end

  def self.getFreeSpace(path)
    if getOS == :windows
      data = `dir #{path}`.split("\n")
      raise StandardError.new 'Empty directory listing output' if data.empty?
      data = data[-1].gsub(',', '')
      match = /\d+.+?(\d+)/.match(data)
      raise StandardError.new 'Unable to match free space pattern' if match == nil
      return match[1].to_i
    else
      data = `df -Pk #{path}`.split("\n")
      raise StandardError.new 'Invalid line count from df' if data.size != 2
      data = data[1].split(' ')
      raise StandardError.new 'Invalid token count from df' if data.size != 6
      data = data[3]
      raise StandardError.new 'Invalid size from df' if !data.isNumber
      output = data.to_i * 1024
      return output
    end
  end

  def self.readDirectory(path, separateDirectoriesAndFiles = false)
    begin
      data = Dir.entries(path)
      data.reject! do |entry|
        ['.', '..'].include?(entry)
      end

      output = []
      data.each do |entry|
        entryPath = File.expand_path(entry, path)
        info = self.getFileInformation(entryPath)
        if info == nil
          raise "Unable to retrieve file information of path #{entryPath}"
        end
        output << info
      end

      output = output.sort do |x, y|
        x.name <=> y.name
      end

      return output if !separateDirectoriesAndFiles

      directories = []
      files = []
      output.each do |entry|
        if File.directory?(entry.path)
          directories << entry
        else
          files << entry
        end
      end
      return [directories, files]

    rescue Errno::ENOENT
      return nil
    end
  end

  WindowsSeparator = '\\'
  UNIXSeparator = '/'

  Separator =
    getOS == :windows ?
  WindowsSeparator :
    UNIXSeparator

  def self.joinPaths(*arguments)
    expression = Regexp.new "\\#{Separator}+"
    path = arguments.join(Separator).gsub(expression, Separator)
    if getOS == :windows
      path = path.gsub(UNIXSeparator, WindowsSeparator)
    end
    return path
  end

  def self.symbolicLink(target, link)
    if getOS == :windows
      #mklink doesn't work for some reason - wrote a std::system proxy in C++
      arguments = ['system', 'mklink']
      arguments << '/D' if File.directory? target
      arguments += ["\"#{link}\"", "\"#{target}\""]
      commandLine = arguments.join ' '
      `#{commandLine}`

      #GNU ln failed me, too - it simply copies everything, it's insane
      #`ln -s "#{target}" "#{link}"`
    else
      File.symlink(target, link)
    end
  end

  def self.getExtension(path)
    offset = path.rindex('.')
    return nil if offset == nil
    return path[offset + 1..-1]
  end
end
