# frozen_string_literal: true

# This is used by `gal` when the `bash` `--guardfile` option is used.

require 'fileutils'
require_relative "#{Dir.home}/code/dotfiles/utils/ruby/guard_shell_with_guard_monkeypatch.rb"

FileUtils.chmod('+x', './personal/bash.sh')

guard(:shell, all_on_start: true) do
  directories_to_watch = %w[app bin lib personal spec test].select { Dir.exist?(_1) }

  # Don't watch `lib/` (the shards directory) if `shard.yml` exists.
  if File.exist?('shard.yml')
    directories_to_watch.reject! { _1 == 'lib' }
  end

  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(directories_to_watch)

  watch_regex =
    %r{^(
      #{directories_to_watch.map { "#{_1}/.*" }.join("|\n")}
    )}x

  ignore(/__pycache__/)

  watch(watch_regex) do |guard_match_result|
    start_time = Time.now

    begin
      match = guard_match_result.instance_variable_get(:@match_result) || '[no match]'
      puts("Match for #{match} triggered execution.")
      system('clear')
      system('./personal/bash.sh', exception: true)
    rescue => error
      pp(error)
    end

    puts("Ran at #{Time.now} (took #{(Time.now - start_time).round(2)}s)")
  end
end
