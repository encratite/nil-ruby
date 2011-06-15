require 'fileutils'
require 'thread'

require 'nil/file'
require 'nil/console'

module Nil
  class Builder
    CPlusPlusExtension = 'cpp'
    ObjectExtension = 'o'

    def initialize(output)
      @includeDirectories = ['.']
      @sourceFiles = []
      @libraries = []

      @pic = false

      @outputDirectory = 'output'
      @objectDirectory = 'object'

      @output = output

      @threads = 1

      sources('source')

      @mutex = Mutex.new
    end

    def include(directory)
      @includeDirectories << directory
    end

    def sources(directory)
      contents = Nil.readDirectory(directory, true)
      if contents == nil
        raise "Unable to read #{directory}"
      end
      directories, files = contents
      paths = files.map { |x| x.path }
      sourceFiles = paths.reject do |path|
        Nil.getExtension(path) != CPlusPlusExtension
      end
      @sourceFiles += sourceFiles
    end

    def library(library)
      @libraries << library
    end

    def makeDirectory(directory)
      FileUtils.mkdir_p(directory)
    end

    def getObject(path)
      extension = Nil.getExtension(path)
      if extension == CPlusPlusExtension
        output = path[0..- (extension.size + 2)]
      else
        output = path
      end

      return Nil.joinPaths(@objectDirectory, File.basename(output + '.' + ObjectExtension))
    end

    def command(commandString)
      Nil.threadPrint("Executing: #{commandString}")
      return system(commandString)
    end

    def worker
      while true
        source = nil
        object = nil
        @mutex.synchronize do
          if @targets.size == 0 || @compilationFailed
            return
          end
          source, object = @targets[0]
          @targets = @targets[1..-1]
        end

        fpicString = ''
        if @pic
          fpicString = ' -fPIC'
        end

        if !command("g++ -c #{source}#{fpicString} -o #{object}#{@includeString}")
          @mutex.synchronize do
            if !@compilationFailed
              Nil.threadPrint('Compilation failed')
              @compilationFailed = true
            end
          end
          return
        end
      end
    end

    def compile
      makeDirectory(@objectDirectory)

      @includeString = ''
      @includeDirectories.each do |directory|
        @includeString += " -I#{directory}"
      end

      @objectString = ''
      @targets.each do |source, object|
        @objectString += " #{object}"
      end

      threadString = 'thread'
      if @threads > 1
        threadString += 's'
      end

      puts "Compiling project with #{@threads} #{threadString}"

      start = Time.new

      threads = []
      @compilationFailed = false
      counter = 1
      @threads.times do |i|
        thread = Thread.new { worker }
        threads << thread
        counter += 1
      end

      threads.each do |thread|
        thread.join
      end

      success = !@compilationFailed

      difference = Time.new - start
      if success
        printf("Compilation finished after %.2f s\n", difference)
      end

      return success
    end

    def makeTargets
      makeDirectory(@outputDirectory)
      @targets = @sourceFiles.map { |path| [path, getObject(path)] }
    end

    def getLibraryString
      libraryString = ''
      @libraries.each do |library|
        libraryString += " -l#{library}"
      end
      return libraryString
    end

    def linkProgram
      libraryString = getLibraryString

      outputPath = Nil.joinPaths(@outputDirectory, @output)
      if !command('g++ -o ' + outputPath + @objectString + libraryString)
        puts 'Failed to link'
        return false
      end

      return true
    end

    def linkStaticLibrary
      @library = "lib#{@output}.a"
      output = Nil.joinPaths(@outputDirectory, @library)
      FileUtils.rm_f(output)
      return command('ar -cq ' + output + @objectString)
    end

    def linkDynamicLibrary
      libraryString = getLibraryString

      @library = "#{@output}.so"
      output = Nil.joinPaths(@outputDirectory, @library)
      return command('g++ -shared -o ' + output + @objectString + libraryString)
    end

    def program
      makeTargets
      return compile && linkProgram
    end

    def staticLibrary(pic = false)
      @pic = pic
      makeTargets
      return compile && linkStaticLibrary
    end

    def dynamicLibrary
      makeTargets
      @pic = true
      return compile && linkDynamicLibrary
    end
  end
end
