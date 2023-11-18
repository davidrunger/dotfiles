# frozen_string_literal: true

# This is used by `gal` when the `spec` `--guardfile` option is used.

require "active_support/core_ext/string/filters"
require "guard/shell"
require "memery"

class RspecPrefixer
  include Memery

  memoize \
  def rspec_prefix
    if project_uses_spring? && ENV.fetch("DISABLE_SPRING", nil) != "1"
      "spring "
    else
      "bin/"
    end
  end

  memoize \
  def project_uses_spring?
    return false if !File.exist?("Gemfile")

    File.read("Gemfile").match?(/gem ['"]spring['"]/)
  end
end

rspec_prefixer = RspecPrefixer.new

guard(:shell, all_on_start: true) do
  directories_to_watch = %w[app bin lib personal spec].select { Dir.exist?(_1) }

  # https://web.archive.org/web/20200927034139/https://github.com/guard/listen/wiki/Duplicate-directory-errors
  directories(directories_to_watch)

  watch(
    %r{
    ^(
    app/|
    lib/|
    spec/(?!fixtures/)|
    tools/|
    config/routes.rb$
    )
    }x,
  ) do |guard_match_result|
    begin
      match = guard_match_result.instance_variable_get(:@match_result) || "[no match]"
      puts("Match for #{match} triggered execution.")
      # rubocop:disable Rails/TimeZone, Lint/RedundantCopDisableDirective
      start_time = Time.now
      # rubocop:enable Rails/TimeZone, Lint/RedundantCopDisableDirective
      system("clear")
      system(<<~SH.squish)
        #{rspec_prefixer.rspec_prefix}rspec
          #{'-b' if ENV.fetch('RSPEC_BACKTRACE', nil) == '1'}
          #{ENV.fetch('TARGET_SPEC_FILES', nil)}
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
