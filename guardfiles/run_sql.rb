# frozen_string_literal: true

# This is used by `gal` when the `jest` `--guardfile` option is used.

require_relative "#{Dir.home}/code/dotfiles/utils/ruby/sql_utils.rb"
require 'active_support/core_ext/string/filters'
require 'guard/shell'

class Runner
  include SqlUtils
end

runner = Runner.new

# rubocop:disable Lint/RedundantCopDisableDirective, Metrics/BlockLength, Style/StringLiterals
guard(:shell, all_on_start: true) do
  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(%w[app lib personal spec])

  watch(%r{^(
    personal/sql.sql
  )}x) do |guard_match_result|
    begin
      match = guard_match_result.instance_variable_get(:@match_result) || "[no match]"
      puts("Match for #{match} triggered execution.")
      # rubocop:disable Rails/TimeZone, Lint/RedundantCopDisableDirective
      start_time = Time.now
      runner.format_sql_if_necessary
      # rubocop:enable Rails/TimeZone, Lint/RedundantCopDisableDirective
      system("clear")
      system(<<~SH.squish)
        psql commonlit_development < personal/sql.sql
      SH
    rescue StandardError => exception
      pp(exception)
      puts(exception.message)
      puts(exception.backtrace)
    end

    # rubocop:disable Rails/TimeZone, Lint/RedundantCopDisableDirective
    "Done in #{(Time.now - start_time).round(2)} seconds."
    # rubocop:enable Rails/TimeZone, Lint/RedundantCopDisableDirective
  end
end
# rubocop:enable Lint/RedundantCopDisableDirective, Metrics/BlockLength, Style/StringLiterals
