# frozen_string_literal: true

# This is used by `gal` when the `ctest` `--guardfile` option is used.

require_relative "#{Dir.home}/code/dotfiles/utils/ruby/guard_shell_with_guard_monkeypatch.rb"

guard(:shell, all_on_start: true) do
  directories_to_watch = %w[bin exe personal spec src].select { Dir.exist?(_1) }

  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(directories_to_watch)

  watch_regex =
    %r{^(
      #{directories_to_watch.map { "#{_1}/.*" }.join("|\n")}
    )}x

  watch(watch_regex) do |guard_match_result|
    begin
      match = guard_match_result.instance_variable_get(:@match_result) || '[no match]'
      system('hard-clear', exception: true)
      puts("Match for #{match} triggered execution.")
      system('crystal spec --fail-fast --order=defined', exception: true)
    rescue => error
      pp(error)
    end
    # rubocop:disable Rails/TimeZone, Lint/RedundantCopDisableDirective
    puts("Ran at #{Time.new.iso8601} .")
    # rubocop:enable Rails/TimeZone, Lint/RedundantCopDisableDirective
  end
end
