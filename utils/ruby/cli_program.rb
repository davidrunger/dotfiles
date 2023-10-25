require 'memo_wise'
require 'slop'

class CliProgram
  OPTION_TYPES_TO_EXPOSE = [
    Slop::IntegerOption,
  ]

  prepend MemoWise

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
    @stdin_content = STDIN.read
  end
end
