# frozen_string_literal: true

# This is a Ruby binding to read the configuration managed by `runger-config`.

require 'yaml'
require_relative 'memoization.rb'

class RungerConfig
  prepend Memoization

  class << self
    def [](key)
      new(Dir.pwd).unified_config[key]
    end
  end

  def initialize(directory)
    @directory = directory
  end

  def get(key)
    unified_config[key]
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
    file_path = File.join(@directory, file_name)

    if File.exist?(file_path)
      content = File.read(file_path)
      YAML.load(content)
    else
      {}
    end
  end
end
