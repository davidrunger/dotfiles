# frozen_string_literal: true

# This is used by `gal` when the `ruby` `--guardfile` option is used.

require_relative "#{Dir.home}/code/dotfiles/utils/ruby/guard_shell_with_guard_monkeypatch.rb"

NUM_BACKTRACE_LINES_TO_PRINT = 5

guard(:shell, all_on_start: true) do
  directories_to_watch = %w[app bin lib personal spec].select { Dir.exist?(_1) }

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
      start_time = Time.now
      ruby_path = './personal/ruby.rb'
      if ENV.key?('ISOLATE_RUBY_RUNS')
        system('ruby', ruby_path)
      else
        load(ruby_path)
      end
    rescue => error
      pp(error)
      puts
      puts(error.backtrace.first(NUM_BACKTRACE_LINES_TO_PRINT))
      puts('[...]') if error.backtrace.size > NUM_BACKTRACE_LINES_TO_PRINT
      puts
    end
    finish_time = Time.now
    puts("Ran at #{finish_time}. Took #{'%0.3f' % (finish_time - start_time).round(3)} seconds.")
  end
end
