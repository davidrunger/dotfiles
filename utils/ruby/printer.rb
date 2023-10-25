# frozen_string_literal: true

# Example:
#     Printer.print_in_place('11MB 294K/s')
#     sleep(0.4)
#     Printer.print_in_place('20KB')
# This just prints on a single line in the terminal.

class Printer
  class << self
    def printing_in_place
      printer = new
      yield(printer)
      puts if !printer.broke_out && @printed_something_in_place
    end
  end

  attr_reader :broke_out

  def print_in_place(string)
    # https://stackoverflow.com/a/14971522/4009384
    print("\r\e[J#{string}")
    @printed_something_in_place = true
  end

  def break_out
    puts if @printed_something_in_place
    @broke_out = true
  end
end
