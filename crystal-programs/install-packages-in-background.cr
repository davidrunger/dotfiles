#!/usr/bin/env crystal

# Install Ruby and JavaScript packages in the background, and run other commands, as needed.

require "colorize"
require "digest/sha256"
require "file_utils"
require "redis"
require "../utils/crystal/memoize"

class InstallPackagesInBackground
  REDIS_HASH_KEY = "runger_dependencies"

  def initialize
    @hashes_to_register = [] of String
  end

  def run
    update_ruby_dependencies_in_background
    update_javascript_dependencies_in_background
    register_hashes
  end

  memoize redis : Redis do
    Redis.new(database: 2)
  end

  private def update_ruby_dependencies_in_background
    execute_command_in_background(ruby_dependencies_update_command, "Ruby")
  end

  private def update_javascript_dependencies_in_background
    execute_command_in_background(javascript_dependencies_update_command, "JavaScript")
  end

  private def register_hashes
    @hashes_to_register.each do |hash_to_register|
      register_hash(hash_to_register)
    end
  end

  private def ruby_dependencies_update_command
    ruby_command_parts = [] of String

    if file_changed?("Gemfile.lock")
      ruby_command_parts << "bundle install"
    end

    if file_changed?("db/schema.rb")
      ruby_command_parts << "dbm"
    end

    ruby_command_parts.join(" && ")
  end

  private def javascript_dependencies_update_command
    javascript_command_parts = [] of String

    if file_changed?("yarn.lock")
      javascript_command_parts << "yarn install --check-files"
    end

    if file_changed?("pnpm-lock.yaml")
      javascript_command_parts << "pnpm install --frozen-lockfile"
    end

    javascript_command_parts.join(" && ")
  end

  private def file_changed?(file_name)
    File.exists?(file_name) && !seen_hash?(file_name)
  end

  private def seen_hash?(file_or_directory)
    hash_string = hash_string(file_or_directory)
    is_seen = !redis.hget(REDIS_HASH_KEY, hash_string).nil?

    if !is_seen
      @hashes_to_register << hash_string
    end

    is_seen
  end

  private def register_hash(hash_string)
    redis.hset(REDIS_HASH_KEY, hash_string, "1")
  end

  private def hash_string(file_or_directory)
    file_paths = `git ls-files #{file_or_directory}`.split("\n", remove_empty: true)

    Digest::SHA256.hexdigest(
      file_paths.
        sort.
        map { |path| Digest::SHA256.hexdigest(File.read(path)) }.
        join(""),
    )
  end

  private def execute_command_in_background(command : String, command_name : String)
    unless command.empty?
      executable_path = executable_path_for_command(command, command_name.downcase)
      Process.new(command: executable_path)
      puts "Running `#{command}` in background.".colorize(:yellow)
    else
      puts "No #{command_name} updates required.".colorize(:green)
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

    File.write(
      executable_path,
      <<-SCRIPT,
      #!/usr/bin/env zsh

      #{zsh_command}
      SCRIPT
    )

    File.chmod(executable_path, 0o755)

    executable_path
  end
end

InstallPackagesInBackground.new.run
