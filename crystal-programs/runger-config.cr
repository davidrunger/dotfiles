#!/usr/bin/env crystal

require "colorize"
require "yaml"
require "../utils/crystal/memoization"

class RungerConfig
  memoize def unified_runger_config : Hash(String, YAML::Any)
    public_runger_config.merge(private_runger_config)
  end

  memoize def public_runger_config : Hash(String, YAML::Any)
    read_yaml(".runger-config.yml")
  end

  memoize def private_runger_config : Hash(String, YAML::Any)
    read_yaml(".runger-config.private.yml")
  end

  memoize def private_runger_config_keys : Set(String)
    Set.new(private_runger_config.keys)
  end

  def exit_and_maybe_print(config_key : String, silent = false)
    config_value = unified_runger_config[config_key]?

    if config_value == true
      exit(0)
    elsif config_value == false
      exit(1)
    elsif config_value
      unless silent
        puts(config_value)
      end

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

  def open_public_config_file(config_key = nil)
    open_config_file(".runger-config.yml", config_key: config_key)
  end

  def open_private_config_file(config_key = nil)
    open_config_file(".runger-config.private.yml", config_key: config_key)
  end

  def open_config_file(file_name : String, config_key : String | Nil = nil)
    if !File.exists?(file_name)
      File.write(file_name, "# commit-to-main: true\n")
      puts "Created #{file_name} ."
    end

    if (editor = ENV["EDITOR"])
      if config_key
        line_number = number_of_line_matching_regex(file_name, /\A#{config_key}: /)
      end

      file_path_argument =
        if line_number
          "#{file_name}:#{line_number}"
        else
          file_name
        end

      system("#{editor} #{file_path_argument}")
    end
  end

  private def number_of_line_matching_regex(file_name : String, regex : Regex) : Int32?
    File.open(file_name) do |file|
      file.each_line.with_index(1) do |line, line_number|
        return line_number if line =~ regex
      end
    end

    nil
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
    option "--silent", type: Bool, desc: "Don't print value (useful to check if a config key exists)", required: false
    help short: "-h"

    argument "config_key", type: String, desc: "The configuration option to check.", required: false

    run do |opts, args|
      runger_config = RungerConfig.new

      if (config_key = args.config_key)
        if opts.show
          runger_config.exit_and_maybe_print(config_key, silent: opts.silent)
        elsif opts.edit
          if runger_config.private_runger_config.has_key?(config_key)
            runger_config.open_private_config_file(config_key)
          else
            runger_config.open_public_config_file(config_key)
          end
        elsif opts.edit_private
          runger_config.open_private_config_file(config_key)
        end
      else
        if opts.show
          runger_config.print_config
        elsif opts.edit
          runger_config.open_public_config_file
        elsif opts.edit_private
          runger_config.open_private_config_file
        end
      end
    end
  end
end

RungerConfig::Cli.start(ARGV)
