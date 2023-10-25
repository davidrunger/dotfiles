# frozen_string_literal: true

# NOTE! Because of the `.rb` extension, IRB doesn't automatically load this. That's what we want,
# because, if IRB _does_ automatically load it, then IRB won't also load any project-local `.irbrc`.
# Instead, load this file through other means:
# - load it in `z.rb`
# - load it from the project-local `.irbrc`
# - run `irb` via `bin/irb` and have that load this file

if !defined?(CopyUtils) || !(Object <= CopyUtils)
  require_relative './utils/ruby/monkeypatch_repl.rb'
end

if !defined?(AmazingPrint)
  require_relative "#{Dir.home}/code/dotfiles/utils/ruby/load_gem.rb"
  load_gem 'amazing_print'
end

IRB::Irb.class_eval do
  def output_value(...)
    puts("#=> #{@context.last_value.ai}")
  end
end
