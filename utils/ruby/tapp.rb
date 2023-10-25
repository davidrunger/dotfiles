# frozen_string_literal: true

# Give ourselves the ability to load gems that are not included in the `Gemfile`.
require_relative "#{Dir.home}/code/dotfiles/utils/ruby/load_gem"

# Print things (especially ActiveRecord objects) with pretty colors and formatting.
# See https://gem.wtf/amazing_print .
load_gem "amazing_print" # rubocop:disable Style/StringLiterals

# Give ourselves the ability to call `#tapp` on any object to print it to the terminal.
# See https://gem.wtf/tapp .
load_gem "tapp" # rubocop:disable Style/StringLiterals
module Tapp::Printer
  class ObjectNamePrinter < Base
    def print(tapped_object)
      calling_line =
        caller.find do |line|
          !line.match?(%r{z\.rb|tapp|pry|[b]yebug|internal:kernel})
        end
      filepath, line_number_string = calling_line.match(/\A([^:]*):(\d+)/).to_a.drop(1)
      line_number = Integer(line_number_string)
      calling_line =
        if ["(irb)"].include?(filepath)
          filepath
        else
          File.read(filepath).split("\n")[line_number - 1].strip
        end
      tapped_object_name = calling_line.match(%r{([_a-z0-9]+)\.tapp})&.[](1) || calling_line

      puts("#{AmazingPrint::Colors.yellow(tapped_object_name)}:")
      amazing_print(tapped_object)
    end
  end

  register :object_name_printer, ObjectNamePrinter
end

Tapp.configure do |config|
  config.report_caller = true
  config.default_printer = :object_name_printer
end
