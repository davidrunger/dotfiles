# frozen_string_literal: true

# Make it easy to copy any object as a string to the clipboard.
require_relative "#{ENV['USER_HOME'] || Dir.home}/code/dotfiles/utils/ruby/copy_utils.rb"
require_relative "#{ENV['USER_HOME'] || Dir.home}/code/dotfiles/utils/ruby/string_patches.rb"

# rubocop:disable Style/TopLevelMethodDefinition
def skip_for!(seconds)
  $stop_skipping_at = Time.at(Integer(Time.now) + seconds)
end

def skip!
  skip_for!(5)
end

def code(filename = nil)
  system("code -g #{filename}")
end

def fzf(options)
  require 'pty'
  leader, follower = PTY.open
  read, write = IO.pipe
  spawn('fzf', in: read, out: follower)
  read.close
  follower.close
  write.puts(options.join("\n"))
  selection = leader.gets&.rstrip
  write.close
  leader.close
  selection
end
# rubocop:enable Style/TopLevelMethodDefinition

module MethodPatches
  # "source location" (returns the source location of a method as "path/file.rb:line_number")
  def sl
    source_location&.map(&:to_s)&.join(':')
  end

  # "sublime" (open the current method's source location in VSCode)
  def s
    return nil if sl.blank?

    code(sl)
  end
end
Method.prepend(MethodPatches)

class Object
  # Alias Object#method as #m (because it's shorter to type).
  # Ex.:
  #     user.m(:access_to_library?).source_location
  alias m method

  # copy for a spec expectation
  def cpps
    ai.uncolor.cpp
  end
end

class Array
  def cpp
    super(to_json.gsub(',', ', ')[1..-2]) # spaces between commas and drop brackets for SQL
  end
end
