require 'socket'

module Nil
  def self.getOS
    names =
      {
      'mswin32' => :windows,
      'linux' => :linux,
    }

    tokens = RUBY_PLATFORM.split '-'
    os = tokens[1]

    return names[os]
  end

  def self.getUser
    return ENV['USER']
  end

  def self.getHostname
    return Socket.gethostname
  end
end
