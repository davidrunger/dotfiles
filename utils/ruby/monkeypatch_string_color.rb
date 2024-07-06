# frozen_string_literal: true

if !defined?(AmazingPrint)
  require_relative "#{Dir.home}/code/dotfiles/utils/ruby/load_gem.rb"
  load_gem 'amazing_print'
end

AmazingPrint::Colors.methods(false).each do |color|
  define_method(color) do
    AmazingPrint::Colors.public_send(color, self)
  end
end
