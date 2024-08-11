# frozen_string_literal: true

# This is a Ruby binding to read the configuration managed by `runger-config`.

require 'singleton'
require_relative 'memoization.rb'

class RungerConfig
  include Singleton
  prepend Memoization

  class << self
    def [](key)
      instance.unified_config[key]
    end
  end

  memoize \
  def unified_config
    public_config.merge(private_config)
  end

  private

  memoize \
  def public_config
    parsed_yaml('.runger-config.yml')
  end

  memoize \
  def private_config
    parsed_yaml('.runger-config.private.yml')
  end

  def parsed_yaml(file_name)
    if File.exist?(file_name)
      content = File.read(file_name)
      YAML.load(content)
    else
      {}
    end
  end
end
