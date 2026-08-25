# frozen_string_literal: true

# This is used by `gal` when the `jest` `--guardfile` option is used.

require 'active_support/core_ext/string/filters'
require_relative "#{Dir.home}/code/dotfiles/utils/ruby/guard_shell_with_guard_monkeypatch.rb"

guard(:shell, all_on_start: true) do
  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(%w[app/javascript])

  watch(%r{^(
    app/javascript/.*
  )}x) do |guard_match_result|
    begin
      match = guard_match_result.instance_variable_get(:@match_result) || '[no match]'
      puts("Match for #{match} triggered execution.")
      start_time = Time.now
      system('clear')
      system(<<~SH.squish.tap { puts(it) })
        jest --verbose=false #{ENV.fetch('TARGET_SPEC_FILES')}
          #{if ENV.fetch('JEST_TARGET_PATTERN', nil)
              "-t '#{ENV.fetch('JEST_TARGET_PATTERN')}'"
            end}
      SH
    rescue => error
      pp(error)
      puts(error.message)
      puts(error.backtrace)
    end

    "Done in #{(Time.now - start_time).round(2)} seconds."
  end
end
