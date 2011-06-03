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

      @pic = False

      @outputDirectory = 'output'
      @objectDirectory = 'object'

      @output = output

      @threads = 1

      source('source')

      @mutex = Mutex.new
    end

    def include(directory)
      @includeDirectories << directory
    end

    def source(directory)
      contents = Nil.readDirectory(directory, true)
      if contents == nil
        raise "Unable to read #{directory}"
      end
      directories, files = contents
      sourceFiles = files.reject do |name|
        Nil.getExtension(name) != CPlusPlusExtension
      end
      @sourceFiles += files
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
        @mutex.synchronize do
          if len(@targets) == 0 or @compilationFailed
            @mutex.release()
            return
          end
          source, object = @targets[0]
          @targets = @targets[1..-1]
        end

        fpic_string = ''
        if @pic
          fpicString = ' -fPIC'
        end

        Nil.consolePrint("#{Thread.current.inspect}: ")
        if !command("g++ -c #{source}#{fpicString} -o #{object}#{@includeString}")
          @mutex.synchronize do
            if !@compilationFailed
              nil.printer.line('Compilation failed')
              @compilationFailed = True
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

      print "Compiling project with #{@threads} #{threadString}"

      start = Time.new

      threads = []
      @compilationFailed = False
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
        printf("Compilation finished after %.2f s", difference)
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
        return False
      end

      return True
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
