# frozen_string_literal: true

# This is used by `gal` when the `spec` `--guardfile` option is used.

require 'active_support/core_ext/string/filters'
require_relative "#{Dir.home}/code/dotfiles/utils/ruby/guard_shell_with_guard_monkeypatch.rb"
require_relative "#{Dir.home}/code/dotfiles/utils/ruby/memoization.rb"

class RspecPrefixer
  prepend Memoization

  memoize \
  def rspec_prefix
    if project_uses_spring? && ENV.fetch('DISABLE_SPRING', nil) != '1'
      'spring '
    elsif File.exist?('bin/rspec')
      'bin/'
    elsif File.exist?('Gemfile')
      'bundle exec '
    else
      fail 'Could not determine how to run RSpec.'
    end
  end

  memoize \
  def project_uses_spring?
    return false if !File.exist?('Gemfile')

    File.read('Gemfile').match?(/gem ['"]spring['"]/)
  end
end

IGNORED_FILES = %w[
  spec/examples.txt
].freeze

rspec_prefixer = RspecPrefixer.new

guard(:shell, all_on_start: true) do
  directories_to_watch = %w[app bin lib personal spec].select { Dir.exist?(it) }

  # Don't watch `lib/` (the shards directory) if `shard.yml` exists.
  if File.exist?('shard.yml')
    directories_to_watch.reject! { it == 'lib' }
  end

  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(directories_to_watch)

  watch(
    %r{
    ^(
    app/(?!(javascript/types/(bootstrap|responses|serializers)/))|
    lib/|
    spec/(?!fixtures/)|
    tools/|
    config/routes.rb$
    )
    }x,
  ) do |guard_match_result|
    if IGNORED_FILES.include?(guard_match_result.instance_variable_get(:@original_value))
      next
    end

    # rubocop:disable RSpec/Output
    begin
      match = guard_match_result.instance_variable_get(:@original_value) || '[no match]'
      puts("Match for #{match} triggered execution.")
      # rubocop:disable Rails/TimeZone, Lint/RedundantCopDisableDirective
      start_time = Time.now
      # rubocop:enable Rails/TimeZone, Lint/RedundantCopDisableDirective
      system('hard-clear')
      system(<<~SH.squish)
        #{rspec_prefixer.rspec_prefix}rspec
          #{'-b' if ENV.fetch('RSPEC_BACKTRACE', nil) == '1'}
          #{'--fail-fast' if ENV.fetch('FAIL_FAST', nil) == '1'}
          #{ENV.fetch('TARGET_SPEC_FILES', nil)}
      SH
    rescue StandardError => exception
      pp(exception)
      puts(exception.message)
      puts(exception.backtrace)
    end
    # rubocop:enable RSpec/Output

    # rubocop:disable Rails/TimeZone, Lint/RedundantCopDisableDirective
    "Done in #{(Time.now - start_time).round(2)} seconds."
    # rubocop:enable Rails/TimeZone, Lint/RedundantCopDisableDirective
  end
end
