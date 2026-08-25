# frozen_string_literal: true

# This is used by `gal` when the `node` `--guardfile` option is used.

require 'active_support/core_ext/string/filters'
require 'amazing_print'
require_relative "#{Dir.home}/code/dotfiles/utils/ruby/guard_shell_with_guard_monkeypatch.rb"

guard(:shell, all_on_start: true) do
  directories_to_watch = %w[app personal].select { Dir.exist?(it) }

  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(directories_to_watch)

  watch(%r{^(
    app/javascript/.*
  )}x) do |guard_match_result|
    begin
      match = guard_match_result.instance_variable_get(:@match_result) || '[no match]'
      puts("Match for #{match} triggered execution.")
      start_time = Time.now
      system('clear')
      system(<<~SH.squish, exception: true)
        tsx app/javascript/typescript-scratchpad.ts
      SH
    rescue => error
      puts(AmazingPrint::Colors.red(error.ai))
    end

    "Done in #{(Time.now - start_time).round(2)} seconds."
  end
end
