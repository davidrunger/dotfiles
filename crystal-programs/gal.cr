#!/usr/bin/env crystal

require "file_utils"
require "memoization"
require "../utils/crystal/command_line_tool"
require "../utils/crystal/clim_program"

class Gal
  GUARDFILES_DIRECTORY_PATH = File.join(ENV.fetch("HOME"), "code/dotfiles/guardfiles")

  struct ScriptInfo
    getter path : String
    getter content : String?

    def initialize(@path : String, @content : String? = nil)
    end
  end

  def self.guardfile_types : Array(String)
    Dir.glob(File.join(GUARDFILES_DIRECTORY_PATH, "run_*.rb")).map do |path|
      File.basename(path).sub(/\Arun_/, "").sub(/\.rb\z/, "")
    end.sort!
  end

  def self.guardfile_description : String
    "guardfile flag [#{guardfile_types.join("|").sub(/\bspec\b/, "spec(default)")}]"
  end
end

struct GalOptions
  getter arguments : Array(String)
  getter guardfile : String?
  getter target : String?
  getter coverage_target : String?
  getter? backtrace : Bool
  getter? fail_fast : Bool
  getter? skip_spring : Bool
  getter? force_coverage_detail : Bool
  getter? force : Bool
  getter? debug_guard : Bool
  getter? debug_listen : Bool
  getter? headful_chrome : Bool
  getter? isolate : Bool

  def initialize(
    @arguments : Array(String),
    @guardfile : String?,
    @target : String?,
    @coverage_target : String?,
    @backtrace : Bool,
    @fail_fast : Bool,
    @skip_spring : Bool,
    @force_coverage_detail : Bool,
    @force : Bool,
    @debug_guard : Bool,
    @debug_listen : Bool,
    @headful_chrome : Bool,
    @isolate : Bool,
  )
  end
end

class Gal::Runner < CommandLineTool
  BASH_SCRIPT_CONTENT = "#!/usr/bin/env bash\n\nset -euo pipefail # exit on any error, don't allow undefined variables, pipes don't swallow errors\n"

  PROJECT_LOCAL_SCRIPT_INFOS = {
    "bash"    => Gal::ScriptInfo.new("personal/bash.sh", BASH_SCRIPT_CONTENT),
    "crystal" => Gal::ScriptInfo.new("personal/crystal.cr"),
    "node"    => Gal::ScriptInfo.new("app/javascript/typescript-scratchpad.ts"),
    "python"  => Gal::ScriptInfo.new("personal/python.py"),
    "rails"   => Gal::ScriptInfo.new("personal/runner.rb", "# frozen_string_literal: true\n"),
    "ruby"    => Gal::ScriptInfo.new("personal/ruby.rb", "# frozen_string_literal: true\n"),
    "sidekiq" => Gal::ScriptInfo.new("personal/runner.rb"),
    "sql"     => Gal::ScriptInfo.new("personal/sql.sql"),
  }

  def initialize(@options : GalOptions)
  end

  def run
    ensure_local_script
    open_local_script

    puts "Running #{blue("#{formatted_environment} #{command}")}"
    status = run_command("guard", command_arguments, env: environment)
    exit(status.exit_code) if !status.success?
  end

  private def command_arguments : Array(String)
    arguments = ["-G", guardfile_path, "--no-bundler-warning"]
    arguments << "--debug" if @options.debug_guard?
    arguments
  end

  private memoize def command : String
    command = "guard -G #{guardfile_path} --no-bundler-warning"
    command += " --debug" if @options.debug_guard?
    command
  end

  private def formatted_environment : String
    environment.map { |key, value| %(#{key}="#{value}") }.join(" ")
  end

  private memoize def environment : Hash(String, String)
    environment = {
      "RUBYGEMS_GEMDEPS" => "",
      "GUARDFILE_TYPE"   => guardfile_type,
    }

    environment["RSPEC_BACKTRACE"] = "1" if @options.backtrace?
    environment["FAIL_FAST"] = "1" if @options.fail_fast?
    environment["HEADFUL_CHROME"] = "1" if @options.headful_chrome?
    environment["LISTEN_GEM_DEBUGGING"] = "debug" if @options.debug_listen?
    environment["TARGET_SPEC_FILES"] = @options.arguments.join(" ") unless @options.arguments.empty?
    environment["DISABLE_SPRING"] = ENV["DISABLE_SPRING"]? || "1" if @options.skip_spring? || ENV["DISABLE_SPRING"]?
    environment["SIMPLECOV_FORCE_DETAILS"] = "1" if @options.force_coverage_detail?
    environment["ISOLATE_RUBY_RUNS"] = "1" if @options.isolate?

    if coverage_target = @options.coverage_target
      environment["SIMPLECOV_TARGET_FILE"] = coverage_target unless coverage_target.strip.empty?
    end

    if target = @options.target
      environment["JEST_TARGET_PATTERN"] = target unless target.strip.empty?
    end

    environment
  end

  private def ensure_local_script
    return unless script_info = project_local_script_info

    script_path = personal_executable_path(script_info)

    if !File.exists?(script_path)
      Dir.mkdir_p(working_directory_personal_directory)
      write_default_script_content(script_path, script_info)
    elsif File.read(script_path) != script_info.content.to_s
      run_command("bat", [script_path], env: {"BAT_PAGER" => "cat"})

      puts "^ That is the existing file content.\nPress Enter to proceed, r to reset, or q to quit."

      receive_and_execute_decision_about_existing_script(script_path, script_info)
    end
  end

  private def write_default_script_content(script_path : String, script_info : Gal::ScriptInfo)
    File.write(script_path, script_info.content.to_s)
  end

  private def receive_and_execute_decision_about_existing_script(
    script_path : String,
    script_info : Gal::ScriptInfo,
  )
    case STDIN.raw &.read_char
    when '\r'
      # Proceed.
    when 'r'
      write_default_script_content(script_path, script_info)
    when 'q', '\u0003'
      exit(0)
    else
      puts "Choice not recognized. Try again."
      receive_and_execute_decision_about_existing_script(script_path, script_info)
    end
  end

  private def open_local_script
    if script_info = project_local_script_info
      if editor = ENV["EDITOR"]
        system("#{editor} #{personal_executable_path(script_info)}")
      end
    end
  end

  private memoize def guardfile_path : String
    path = working_directory_guardfile_path
    copy_dotfile_to_working_directory if !File.exists?(path) || @options.force?
    path
  end

  private def copy_dotfile_to_working_directory
    Dir.mkdir_p(working_directory_guardfile_directory)
    FileUtils.cp(dotfiles_absolute_guardfile_path, working_directory_guardfile_directory)
  end

  private memoize def dotfiles_absolute_guardfile_path : String
    File.join(Gal::GUARDFILES_DIRECTORY_PATH, "#{guardfile_filename}.rb")
  end

  private memoize def guardfile_filename : String
    if Gal.guardfile_types.includes?(guardfile_type)
      "run_#{guardfile_type}"
    else
      raise "Unexpected guardfile flag '#{guardfile_type}'."
    end
  end

  private memoize def guardfile_type : String
    if guardfile = @options.guardfile
      return guardfile unless guardfile.strip.empty?
    end

    if !@options.arguments.empty?
      if @options.arguments.all? { |argument| argument.includes?("spec/") && argument.matches?(/\.rb(:\d+)?\z/) }
        return "spec"
      elsif @options.arguments.all?(&.matches?(/\.test\.tsx?\z/))
        return "jest"
      else
        raise "Could not determine guardfile type from argument(s)!"
      end
    end

    raise "Neither `--guardfile` flag nor argument(s) were given!"
  end

  private memoize def project_local_script_info : Gal::ScriptInfo?
    PROJECT_LOCAL_SCRIPT_INFOS[guardfile_type]?
  end

  private memoize def personal_executable_path(script_info : Gal::ScriptInfo) : String
    File.join(working_directory, script_info.path)
  end

  private def working_directory_guardfile_path : String
    File.join(working_directory_guardfile_directory, "#{guardfile_filename}.rb")
  end

  private def working_directory_guardfile_directory : String
    File.join(working_directory_personal_directory, "guardfiles")
  end

  private def working_directory_personal_directory : String
    File.join(working_directory, "personal")
  end

  private memoize def working_directory : String
    ENV.fetch("PWD")
  end

  private def blue(value : String) : String
    "\e[34m#{value}\e[0m"
  end
end

class Gal::Cli < ClimProgram
  main do
    desc "Run Guard with a selected guardfile."
    usage "gal [spec file(s) to run] [options]"

    option "-g GUARD_FILE", "--guardfile GUARD_FILE", type: String, desc: Gal.guardfile_description
    option "-t TARGET", "--target TARGET", type: String, desc: "jest target pattern"
    option "--coverage-target FILE", type: String, desc: "specify SIMPLECOV_TARGET_FILE"
    option "-b", "--backtrace", type: Bool, desc: "print backtrace when errors occur or tests fail"
    option "-f", "--fail-fast", type: Bool, desc: "stop running specs after first failure"
    option "-s", "--skip-spring", type: Bool, desc: "do not use spring"
    option "-c", "--force-coverage-detail", type: Bool, desc: "print code coverage info even if 100% covered"
    option "--force", type: Bool, desc: "force copying guardfile to personal directory"
    option "-d", "--debug-guard", type: Bool, desc: "enable guard debug logging"
    option "-l", "--debug-listen", type: Bool, desc: "enable listen debug logging"
    option "-v", "--headful-chrome", type: Bool, desc: "run tests with headful chrome browser"
    option "-i", "--isolate", type: Bool, desc: "perform each run in a separate process (slower)"
    help short: "-h"

    run do |opts, args|
      if args.argv.empty?
        puts opts.help_string
      else
        Gal::Runner.new(
          GalOptions.new(
            arguments: args.all_args,
            guardfile: opts.guardfile,
            target: opts.target,
            coverage_target: opts.coverage_target,
            backtrace: opts.backtrace,
            fail_fast: opts.fail_fast,
            skip_spring: opts.skip_spring,
            force_coverage_detail: opts.force_coverage_detail,
            force: opts.force,
            debug_guard: opts.debug_guard,
            debug_listen: opts.debug_listen,
            headful_chrome: opts.headful_chrome,
            isolate: opts.isolate,
          ),
        ).run
      end
    end
  end
end

Gal::Cli.start!
