# frozen_string_literal: true

# This is used by `gal` when the `sidekiq` `--guardfile` option is used.

require 'sidekiq'
require_relative "#{Dir.home}/code/dotfiles/utils/ruby/guard_shell_with_guard_monkeypatch.rb"

Sidekiq.configure_client do |config|
  config.redis = { db: 3 }
end

output_reader, output_writer = IO.pipe
system('redis-cli -n 3 FLUSHDB', exception: true)
sidekiq_pid =
  Process.spawn(
    {
      'REDIS_DATABASE_NUMBER' => '3',
      'SIDEKIQ_CONCURRENCY' => '1',
    },
    'bin/sidekiq',
    out: output_writer,
    err: :out,
  )

output_thread =
  Thread.new do
    loop do
      select([output_reader])
      print(output_reader.readpartial(4096))
    rescue IO::WaitReadable
      # Expected exception. Do nothing.
    end
  end

guard(:shell, all_on_start: true) do
  directories_to_watch = %w[app bin lib personal spec].select { Dir.exist?(_1) }

  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(directories_to_watch)

  watch_regex =
    %r{^(
      #{directories_to_watch.map { "#{_1}/.*.rb" }.join("|\n")}
    )}x

  watch(watch_regex) do |guard_match_result|
    match = guard_match_result.instance_variable_get(:@match_result) || '[no match]'
    puts("Match for #{match} triggered execution.")
    Sidekiq::Client.push(
      'class' => 'LoadRunner',
      'args' => [],
      'queue' => 'default',
      'retry' => false,
    )
    nil
  rescue StandardError => exception
    pp(exception)
  end

  callback(:stop_begin) do
    Process.kill('TERM', sidekiq_pid)
    Process.wait(sidekiq_pid)
    output_writer.close
    output_reader.close
    output_thread.kill
  end
end
# rubocop:enable Metrics/BlockLength
