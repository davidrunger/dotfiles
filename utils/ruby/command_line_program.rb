# frozen_string_literal: true

require 'active_support'
require 'active_support/all'
require 'amazing_print'
require 'slop'

require_relative "#{Dir.home}/code/dotfiles/utils/ruby/memoization.rb"
require_relative "#{Dir.home}/code/dotfiles/utils/ruby/monkeypatch_string_color.rb"

class CommandLineProgram
  prepend Memoization

  OPTION_TYPES_TO_EXPOSE = [
    Slop::IntegerOption,
    Slop::StringOption,
  ].freeze

  attr_reader :arguments, :options, :stdin_content

  def initialize(sloptions:)
    @arguments = sloptions.arguments
    @options = sloptions
    options.options.options.
      select { OPTION_TYPES_TO_EXPOSE.include?(_1.class) }.
      each do |option|
        define_singleton_method(option.key) do
          @options[option.key]
        end
      end
    @stdin_content = STDIN.tty? ? nil : STDIN.read
  end
end
