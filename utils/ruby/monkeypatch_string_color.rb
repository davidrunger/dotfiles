# frozen_string_literal: true

if !defined?(Rainbow)
  begin
    require 'rainbow'
  rescue LoadError
    require_relative "#{Dir.home}/code/dotfiles/utils/ruby/load_gem.rb"
    load_gem('rainbow')
  end
end

class String
  Rainbow::Color::Named.color_names.each do |color|
    define_method(color) do
      Rainbow(self).color(color)
    end
  end
end
