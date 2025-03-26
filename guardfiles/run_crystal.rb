# frozen_string_literal: true

# This is used by `gal` when the `crystal` `--guardfile` option is used.

require_relative "#{Dir.home}/code/dotfiles/utils/ruby/guard_shell_with_guard_monkeypatch.rb"

# rubocop:disable Rails/TimeZone, Lint/RedundantCopDisableDirective
guard(:shell, all_on_start: true) do
  directories_to_watch = %w[bin exe personal spec src].select { Dir.exist?(it) }

  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(directories_to_watch)

  watch(/./) do |guard_match_result|
    begin
      match = guard_match_result.instance_variable_get(:@match_result) || '[no match]'
      system('hard-clear')
      puts("Match for #{match} triggered execution.")
      start_time = Time.now
      system('crystal run personal/crystal.cr', exception: true)
    rescue => error
      puts(error)
    end

    "Done in #{(Time.now - start_time).round(2)} seconds."
  end
end
# rubocop:enable Rails/TimeZone, Lint/RedundantCopDisableDirective
