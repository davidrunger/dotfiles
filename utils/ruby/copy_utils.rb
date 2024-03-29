# frozen_string_literal: true

require_relative './load_gem'
load_gem 'amazing_print' if !defined?(AmazingPrint)
load_gem 'clipboard' if !defined?(Clipboard)

module CopyUtils
  # Copies the object upon which this method is called as a string into the clipboard.
  def cpp(input = nil)
    str = (input || self).to_s
    Clipboard.copy(str)
    if str.size < 100
      puts(AmazingPrint::Colors.green("Copied '#{str}' to clipboard."))
    else
      puts(AmazingPrint::Colors.green("Copied #{str.size} characters to clipboard."))
    end
    true
  end
end

if !(Object <= CopyUtils)
  Object.prepend(CopyUtils)
end
