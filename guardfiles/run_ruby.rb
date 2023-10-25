# frozen_string_literal: true

# This is used by `gal` when the `ruby` `--guardfile` option is used.

require 'guard/shell'

NUM_BACKTRACE_LINES_TO_PRINT = 5

guard(:shell, all_on_start: true) do
  directories_to_watch = %w[app lib personal spec]

  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(directories_to_watch)

  watch_regex =
    %r{^(
      #{directories_to_watch.map { "#{_1}/.*" }.join("|\n")}
    )}x

  watch(watch_regex) do |guard_match_result|
    begin
      match = guard_match_result.instance_variable_get(:@match_result) || '[no match]'
      puts("Match for #{match} triggered execution.")
      system('clear')
      load('./personal/ruby.rb')
    rescue => error
      pp(error)
      puts
      puts(error.backtrace.first(NUM_BACKTRACE_LINES_TO_PRINT))
      puts('[...]') if error.backtrace.size > NUM_BACKTRACE_LINES_TO_PRINT
      puts
    end
    puts("Ran at #{Time.now}")
  end
end
