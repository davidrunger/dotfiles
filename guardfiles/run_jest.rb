# frozen_string_literal: true

# This is used by `gal` when the `jest` `--guardfile` option is used.

require 'active_support/core_ext/string/filters'
require 'guard/shell'

guard(:shell, all_on_start: true) do
  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(%w[app/javascript])

  watch(%r{^(
    app/javascript/.*
  )}x) do |guard_match_result|
    begin
      match = guard_match_result.instance_variable_get(:@match_result) || '[no match]'
      puts("Match for #{match} triggered execution.")
      # rubocop:disable Rails/TimeZone, Lint/RedundantCopDisableDirective
      start_time = Time.now
      # rubocop:enable Rails/TimeZone, Lint/RedundantCopDisableDirective
      system('clear')
      system(<<~SH.squish.tap { puts(_1) })
        jest --verbose=false #{ENV.fetch('TARGET_SPEC_FILES')}
          #{"-t '#{ENV.fetch('JEST_TARGET_PATTERN')}'" if ENV.fetch('JEST_TARGET_PATTERN', nil)}
      SH
    rescue => error
      pp(error)
      puts(error.message)
      puts(error.backtrace)
    end

    # rubocop:disable Rails/TimeZone, Lint/RedundantCopDisableDirective
    "Done in #{(Time.now - start_time).round(2)} seconds."
    # rubocop:enable Rails/TimeZone, Lint/RedundantCopDisableDirective
  end
end
