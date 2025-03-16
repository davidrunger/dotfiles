#!/usr/bin/env crystal

# Check for and flag diffs in specified paths (files and/or directories).

require "redis"
require "digest/sha256"

require "memoization"
require "../utils/crystal/runger_config"

class FlagUnackedFileVersions
  MONITORED_PATHS_KEY = "monitored-paths"

  class RedisAgent
    def initialize(redis_hash_key : String)
      @redis_hash_key = redis_hash_key
      @redis = Redis.new(database: 2)
    end

    def get(key : String) : String?
      @redis.hget(@redis_hash_key, key)
    end

    def set(key : String, value : String)
      @redis.hset(@redis_hash_key, key, value)
    end
  end

  class AckData
    def initialize(raw_data : String?)
      @raw_data = raw_data
    end

    memoize def present? : Bool
      !!@raw_data
    end

    memoize def most_recently_acked_content_sha : String?
      data_parts.first
    end

    memoize def most_recently_acked_git_sha : String?
      data_parts.last
    end

    private def data_parts : Array(String)
      (@raw_data || "").split(":") || [] of String
    end
  end

  class AckUpdater
    def initialize(path : String, flagger : FlagUnackedFileVersions, monitoring_reason : String)
      @path = path
      @flagger = flagger
      @monitoring_reason = monitoring_reason
    end

    def perform
      print_diff_since_last_ack
      print_monitoring_reason

      if user_acks?
        save_ack
      end
    end

    private def print_diff_since_last_ack
      if ack_data.present?
        puts("'#{@path}' has changed since your last ack.")
        system("DELTA_PAGER=cat git diff #{ack_data.most_recently_acked_git_sha}.. '#{@path}'") || raise "Error occurred!"
      else
        puts("You have never acked '#{@path}', so we'll print it all.")
        system("BAT_PAGER=cat bat $(git ls-files '#{@path}')") || raise "Error occurred!"
      end
    end

    private def print_monitoring_reason
      puts("Monitoring reason: #{@monitoring_reason}")
    end

    private def user_acks? : Bool
      puts("Do you acknowledge this content? [y]n")

      case STDIN.raw &.read_char
      when 'y', '\r'
        true
      when 'n', '\u0003' # Ctrl-C
        false
      else
        puts("Choice not recognized. Try again.")
        user_acks?
      end
    end

    memoize def ack_data : AckData
      AckData.new(@flagger.redis_agent.get(@path))
    end

    def save_ack
      @flagger.redis_agent.set(@path, "#{@flagger.current_content_sha(@path)}:#{current_git_sha}")
    end

    memoize def current_git_sha : String
      `git log --format=format:%H | head -1`.strip
    end
  end

  def seek_ack_of_unacked_files
    if !RungerConfig.has_key?(MONITORED_PATHS_KEY)
      return
    end

    on_main_branch do
      paths_without_up_to_date_ack.each do |path|
        monitoring_reason = monitored_paths_hash[path]

        if monitoring_reason
          AckUpdater.new(path, flagger: self, monitoring_reason: monitoring_reason.to_s).perform
        else
          puts("No monitoring reason was given for #{path}.")
        end
      end
    end
  end

  memoize def current_content_sha(file_or_directory : String) : String
    file_paths = `git ls-files #{file_or_directory}`.split("\n", remove_empty: true)

    Digest::SHA256.hexdigest(
      file_paths
        .sort
        .map { |path| Digest::SHA256.hexdigest(File.read(path)) }
        .join(""),
    )
  end

  memoize def redis_agent : RedisAgent
    RedisAgent.new("runger_path_monitors")
  end

  private def on_main_branch(&)
    original_branch = `branch`.strip
    system("git checkout \"$(main-branch)\" >/dev/null 2>&1") || raise "Error occurred!"

    yield
  ensure
    system("git checkout '#{original_branch}' >/dev/null 2>&1") || raise "Error occurred!"
  end

  memoize def paths_without_up_to_date_ack : Array(String)
    monitored_paths.reject { |path| content_acked?(path) }
  end

  memoize def monitored_paths : Array(String)
    monitored_paths_hash.keys
  end

  memoize def monitored_paths_hash : Hash(String, YAML::Any)
    RungerConfig[MONITORED_PATHS_KEY].as_h.transform_keys(&.to_s)
  end

  memoize def content_acked?(path : String) : Bool
    File.exists?(path) && seen_hash?(path)
  end

  memoize def seen_hash?(path : String) : Bool
    ack_data(path).most_recently_acked_content_sha == current_content_sha(path)
  end

  memoize def ack_data(path : String) : AckData
    AckData.new(redis_agent.get(path))
  end
end

FlagUnackedFileVersions.new.seek_ack_of_unacked_files
