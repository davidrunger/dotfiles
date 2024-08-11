#!/usr/bin/env crystal

require "colorize"
require "yaml"
require "../utils/crystal/memoize"

class RungerConfig
  memoize unified_runger_config : Hash(String, YAML::Any) do
    public_runger_config.merge(private_runger_config)
  end

  memoize public_runger_config : Hash(String, YAML::Any) do
    read_yaml(".runger-config.yml")
  end

  memoize private_runger_config : Hash(String, YAML::Any) do
    read_yaml(".runger-config.private.yml")
  end

  memoize private_runger_config_keys : Set(String) do
    Set.new(private_runger_config.keys)
  end

  def exit_and_maybe_print(config_key : String)
    config_value = unified_runger_config[config_key]?

    if config_value == true
      exit(0)
    elsif config_value
      puts(config_value)
      exit(0)
    else
      exit(1)
    end
  end

  def print_config
    unified_runger_config.keys.sort.each do |key|
      puts "#{colorized_key(key)} #{":".colorize(:green)} #{unified_runger_config[key]}"
    end
  end

  def edit_config_file(file_name : String)
    if !File.exists?(file_name)
      File.write(file_name, "# commit-to-main: true\n")
      puts "Created #{file_name} ."
    end

    if (editor = ENV["EDITOR"])
      system("#{editor} #{file_name}")
    end
  end

  private def read_yaml(file_name)
    if File.exists?(file_name)
      content = File.read(file_name)
      YAML.parse(content).as_h.transform_keys { |key| key.to_s } || {} of String => YAML::Any
    else
      {} of String => YAML::Any
    end
  end

  private def colorized_key(key)
    color =
      if key.in?(private_runger_config_keys)
        :magenta
      else
        :blue
      end

    key.colorize(color)
  end
end

require "clim"

class RungerConfig::Cli < Clim
  main do
    desc "Manage and check configuration for a repository."
    usage "runger-config [options] [arguments]"
    version "0.0.1"

    option "-e", "--edit", type: Bool, desc: "Edit (and create, if needed) a .runger-config.yml file.", required: false
    option "-p", "--edit-private", type: Bool, desc: "Edit (and create, if needed) a .runger-config.private.yml file.", required: false
    option "-s", "--show", type: Bool, desc: "Print the current config (combining both public and private configs).", required: false
    help short: "-h"

    argument "config_key", type: String, desc: "The configuration option to check.", required: false

    run do |opts, args|
      runger_config = RungerConfig.new

      if (config_key = args.config_key)
        runger_config.exit_and_maybe_print(config_key)
      elsif opts.show
        runger_config.print_config
      elsif opts.edit
        runger_config.edit_config_file(".runger-config.yml")
      elsif opts.edit_private
        runger_config.edit_config_file(".runger-config.private.yml")
      end
    end
  end
end

RungerConfig::Cli.start(ARGV)
