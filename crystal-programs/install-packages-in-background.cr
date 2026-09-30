#!/usr/bin/env crystal

# Install Ruby and JavaScript packages in the background, and run other commands, as needed.

require "colorize"
require "digest/sha256"
require "file_utils"
require "redis"
require "memoization"

if ENV["FORCE_COLOR"]? == "1"
  Colorize.enabled = true
end

class InstallPackagesInBackground
  REDIS_HASH_KEY = "runger_dependencies_last_installed"

  def initialize
    # Maps project file key (project + file name) => content hash that we are about to install for
    @hashes_to_register = {} of String => String
  end

  def run
    update_ruby_dependencies_in_background
    update_javascript_dependencies_in_background
    register_hashes
  end

  memoize def redis : Redis
    Redis.new(database: 2)
  end

  private def update_ruby_dependencies_in_background
    execute_command_in_background(ruby_dependencies_update_command, "Ruby")
  end

  private def update_javascript_dependencies_in_background
    execute_command_in_background(javascript_dependencies_update_command, "JavaScript")
  end

  private def register_hashes
    @hashes_to_register.each do |project_file_key, content_hash|
      register_hash(project_file_key, content_hash)
    end
  end

  memoize def ruby_dependencies_update_command : String
    ruby_command_parts = [] of String

    if file_changed?("Gemfile.lock")
      ruby_command_parts << "bundle install"
    end

    if file_changed?("db/schema.rb")
      ruby_command_parts << "dbm"
    end

    ruby_command_parts.join(" && ")
  end

  memoize def javascript_dependencies_update_command : String
    javascript_command_parts = [] of String

    if (
         file_changed?("yarn.lock") ||
         file_changed?("pnpm-lock.yaml") ||
         file_changed?("package-lock.json")
       )
      javascript_command_parts << "yic"
    end

    javascript_command_parts.join(" && ")
  end

  # A file counts as "changed" unless its current content hash is the same as the hash we most
  # recently installed dependencies for (in this project).
  memoize def file_changed?(file_name : String) : Bool
    return false unless File.exists?(file_name)

    current_hash = hash_string(file_name)
    key = project_file_key(file_name)
    last_installed_hash = redis.hget(REDIS_HASH_KEY, key)
    changed = last_installed_hash != current_hash

    if changed
      @hashes_to_register[key] = current_hash
    end

    changed
  end

  private def project_file_key(file_name : String) : String
    "#{Dir.current}:#{file_name}"
  end

  private def register_hash(project_file_key : String, content_hash : String)
    redis.hset(REDIS_HASH_KEY, project_file_key, content_hash)
  end

  private def hash_string(file_or_directory)
    file_paths = `git ls-files #{file_or_directory}`.split("\n", remove_empty: true)

    Digest::SHA256.hexdigest(
      file_paths
        .sort
        .map { |path| Digest::SHA256.hexdigest(File.read(path)) }
        .join(""),
    )
  end

  private def execute_command_in_background(command : String, command_name : String)
    if command.empty?
      puts "No #{command_name} updates required.".colorize(:green)
    else
      executable_path = executable_path_for_command(command, command_name.downcase)
      Process.new(command: executable_path)
      puts "Running `#{command}` in background.".colorize(:yellow)
    end
  end

  private def executable_path_for_command(command : String, filename : String)
    current_directory = `basename "$PWD"`.chomp
    installer_directory = "./personal/installer_executables/"
    FileUtils.mkdir_p(installer_directory)
    executable_path = File.join(installer_directory, "#{filename}.sh")

    zsh_command =
      <<-ZSH
        {
          (
            #{command} && \\
              notify 'Command succeeded in #{current_directory}' '#{command}' || \\
              notify-error 'Command failed in #{current_directory}' '#{command}'
          ) & disown
        } &>/dev/null
        ZSH

    File.write(executable_path, <<-SCRIPT)
      #!/usr/bin/env zsh

      #{zsh_command}
      SCRIPT

    File.chmod(executable_path, 0o755)

    executable_path
  end
end

InstallPackagesInBackground.new.run
