#!/usr/bin/env crystal

# Flags files and directories that have changed since you last looked at them, and
# asks you to acknowledge ("ack") the new version.
#
# This is meant for paths that other people (or bots) might change on the main
# branch, possibly without your knowledge, and whose changes you may need to take
# into account. For example:
#
# - A collaborator edits a deploy script or CI workflow, and you need to know
#   about it so you can update related config elsewhere.
# - Dependabot bumps a dependency (or a Dockerfile base image), and you need to
#   check that the change is reflected in other places, like a pinned version in
#   `.tool-versions` or documentation.
#
# ## How it works
#
# 1. Reads the `monitored-paths` key from the runger config (see below). If the key
#    is absent, the program does nothing.
# 2. Checks out the repo's main branch (via the `main-branch` command), so that
#    comparisons are always made against main. The original branch is restored
#    afterward, even if an error occurs.
# 3. For each monitored path, computes a SHA256 of the current content (for a
#    directory, this is derived from all git-tracked files within it) and compares
#    it with the content SHA recorded at your last ack.
# 4. For each path that differs from the last ack (or has never been acked), the
#    program:
#    - prints the full content (via `bat`) if the path has never been acked, or
#      prints a `git diff` (via `delta`) since the git commit at which you last
#      acked it;
#    - prints the monitoring reason configured for the path; and
#    - asks `Do you acknowledge this content? [y]n`. Pressing `y` or Enter records
#      the ack; pressing `n` or Ctrl-C skips it, so you'll be asked again next time.
#
# Acks are stored in Redis (database 2) in the `runger_path_monitors` hash, keyed by
# path, with values of the form `<content sha>:<git sha>`.
#
# ## Configuration
#
# Paths are configured under the `monitored-paths` key in `.runger-config.yml`
# and/or `.runger-config.private.yml` (read from the current working directory).
# The key maps each path (relative to the repo root; a file or a directory) to a
# human-readable reason for monitoring it. The reason is shown whenever the path is
# flagged, so it's a good place to say what you should do or check when it changes:
#
# ```yaml
# monitored-paths:
#   Dockerfile: Dependabot may bump the base image; keep .tool-versions in sync.
#   .github/workflows/: Collaborators may change CI; make sure deploys still work.
#   config/deploy.yml: Changes here can affect production; update the runbook.
# ```
#
# Note that the two config files are merged at the top level, so if both define
# `monitored-paths`, the entry in the private file replaces the one in the public
# file entirely (the paths are not combined).
#
# ## Requirements
#
# - A running Redis server
# - `git`, `bat`, and `delta` on the PATH
# - The `main-branch` and `branch` executables on the PATH (these print the main
#   branch name and current branch name, respectively)
# - Being run from the root of the git repository containing the monitored paths

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
