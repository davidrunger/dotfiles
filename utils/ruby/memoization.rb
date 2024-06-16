# frozen_string_literal: true

if !defined?(MemoWise)
  require_relative "#{Dir.home}/code/dotfiles/utils/ruby/load_gem.rb"
  load_gem 'memo_wise'
end

module MemoWisePatches
  def prepended(target)
    super

    target.singleton_class.alias_method(:memoize, :memo_wise)
  end
end

MemoWise.singleton_class.prepend(MemoWisePatches)

Memoization = MemoWise
