#!/usr/bin/env crystal

require "clim"

class Notify
  def initialize(
    @title : String,
    @body : String,
    @time : Int32,
    @icon : String,
  )
  end

  def call
    if ENV["LINUX"]?
      notify_on_linux
    else
      notify_on_macos
    end
  end

  private def notify_on_linux
    run_command("notify-send", [
      @title,
      @body,
      "-i",
      icon_path,
      "--expire-time=#{@time * 1000}",
    ])
  end

  private def notify_on_macos
    script = %(display notification "#{escape_for_applescript(@body)}" with title "#{escape_for_applescript(@title)}")
    run_command("osascript", ["-e", script])
  end

  private def icon_path : String
    case @icon
    when "information"
      "/usr/share/icons/Adwaita/96x96/ui/checkbox-checked-symbolic.symbolic.png"
    when "error"
      "/usr/share/icons/Adwaita/96x96/status/dialog-error-symbolic.symbolic.png"
    else
      raise ArgumentError.new("Unknown notification icon: #{@icon}")
    end
  end

  private def escape_for_applescript(value : String) : String
    String.build do |escaped_value|
      value.each_char do |character|
        escaped_value << '\\' if character == '\\' || character == '"'
        escaped_value << character
      end
    end
  end

  private def run_command(command : String, arguments : Array(String))
    status = Process.run(
      command,
      arguments,
      input: Process::Redirect::Inherit,
      output: Process::Redirect::Inherit,
      error: Process::Redirect::Inherit,
    )

    exit(status.exit_code) unless status.success?
  end
end

class Notify::Cli < Clim
  main do
    desc "Display a pop-up desktop notification."
    usage "notify title body [options]"

    option "-t TIME", "--time TIME", type: Int32,
      desc: "Number of seconds for which to display the message. Only works on Linux.",
      default: 8
    option "-i ICON", "--icon ICON", type: String,
      desc: "Notification icon. Options: information|error. Only works on Linux.",
      default: "information"
    help short: "-h"

    argument "title", type: String, desc: "Message title", required: true
    argument "body", type: String, desc: "Message body", required: true

    run do |opts, args|
      if args.all_args.size != 2
        raise Clim::ClimInvalidOptionException.new "Expected exactly two arguments: title and body."
      end

      Notify.new(
        title: args.title,
        body: args.body,
        time: opts.time,
        icon: opts.icon,
      ).call
    end
  end

  def self.start(argv : Array(String))
    start_parse(argv)
  rescue ex : Clim::ClimException | Clim::ClimInvalidOptionException | Clim::ClimInvalidTypeCastException
    STDERR.puts "ERROR: #{ex.message}"
    STDERR.puts
    STDERR.puts "Please see the `--help`."
    exit(1)
  end
end

Notify::Cli.start(ARGV)
