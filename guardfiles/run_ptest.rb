# frozen_string_literal: true

# This is used by `gal` when the `ptest` `--guardfile` option is used.

require_relative "#{Dir.home}/code/dotfiles/utils/ruby/guard_shell_with_guard_monkeypatch.rb"

guard(:shell, all_on_start: true) do
  directories_to_watch = %w[app bin kitty lib personal test].select { Dir.exist?(it) }

  # Don't watch `lib/` (the shards directory) if `shard.yml` exists.
  if File.exist?('shard.yml')
    directories_to_watch.reject! { it == 'lib' }
  end

  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(directories_to_watch)

  watch_regex =
    %r{^(
      #{directories_to_watch.map { "#{it}/.*.py$" }.join("|\n")}
    )}x

  watch(watch_regex) do |guard_match_result|
    begin
      match = guard_match_result.instance_variable_get(:@match_result) || '[no match]'
      system('hard-clear', exception: true)
      puts("Match for #{match} triggered execution.")
      system("python3 -m unittest discover -s test -p '*_test.py'", exception: true)
    rescue => error
      pp(error)
    end
    # rubocop:disable Rails/TimeZone, Lint/RedundantCopDisableDirective
    puts("Ran at #{Time.new}")
    # rubocop:enable Rails/TimeZone, Lint/RedundantCopDisableDirective
  end
end
