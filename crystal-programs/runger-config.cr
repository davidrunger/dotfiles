#!/usr/bin/env crystal

require "yaml"
require "../utils/crystal/memoize"

class RungerConfig
  memoize unified_runger_config : Hash(String, YAML::Any) do
    public_runger_config = read_yaml(".runger-config.yml")
    private_runger_config = read_yaml(".runger-config.private.yml")

    public_runger_config.merge(private_runger_config)
  end

  def read_yaml(file)
    if File.exists?(file)
      content = File.read(file)
      YAML.parse(content).as_h.transform_keys { |key| key.to_s } || {} of String => YAML::Any
    else
      {} of String => YAML::Any
    end
  end

  def write_and_open_config_file(file_name : String)
    File.write(file_name, "# commit-to-main: true\n")
    puts "Created #{file_name} ."

    if (editor = ENV["EDITOR"])
      system("#{editor} #{file_name}")
    end
  end

  def print_config
    unified_runger_config.keys.sort.each do |key|
      puts "#{key} : #{unified_runger_config[key]}"
    end
  end
end

require "clim"

class RungerConfig::Cli < Clim
  main do
    desc "Manage and check configuration for a repository."
    usage "runger-config [options] [arguments]"
    version "0.0.1"

    option "-i", "--init", type: Bool, desc: "Create a .runger-config.yml file.", required: false
    option "-p", "--init-private", type: Bool, desc: "Create a .runger-config.private.yml file.", required: false
    option "-s", "--show", type: Bool, desc: "Print the current config.", required: false

    argument "config_key", type: String, desc: "The configuration option to check.", required: false

    run do |opts, args|
      runger_config = RungerConfig.new

      if (config_key = args.config_key)
        config_value = runger_config.unified_runger_config[config_key]?

        if config_value == true
          exit(0)
        elsif config_value
          puts(config_value)
          exit(0)
        else
          exit(1)
        end
      elsif opts.show
        runger_config.print_config
      elsif opts.init
        runger_config.write_and_open_config_file(".runger-config.yml")
      elsif opts.init_private
        runger_config.write_and_open_config_file(".runger-config.private.yml")
      end
    end
  end
end

RungerConfig::Cli.start(ARGV)
