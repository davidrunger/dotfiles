#!/usr/bin/env crystal

# Print [g]it [hist]ory of a file.

require "memoization"
require "../utils/crystal/command_line_tool"
require "../utils/crystal/clim_program"

class GitHistory < CommandLineTool
  def initialize(
    @file : String,
    @include_ignored : Bool,
    @show_all : Bool,
    @num_commits_to_show : Int32?,
    @num_days_to_show : Int32?,
  )
  end

  def call
    file_name_at_this_commit = file

    commits_to_show.each do |commit|
      puts
      run_command("hr")
      run_command(
        "git",
        ["show", commit, "--", file_name_at_this_commit],
        env: {"DELTA_PAGER" => "cat"},
      )
      run_command("hr")

      file_name_at_this_commit = renames[commit]? || file_name_at_this_commit
    end
  end

  private def file : String
    @file
  end

  memoize def num_commits_to_show : Int32?
    @show_all || @num_days_to_show ? nil : (@num_commits_to_show || 3)
  end

  memoize def num_days_to_show : Int32?
    @num_days_to_show
  end

  memoize def num_commits_to_request_from_git : Int32
    (num_commits_to_show || 0) + commits_to_ignore.size
  end

  memoize def commits_to_show : Array(String)
    commits_from_git = capture_command("git", [
      "log",
      *git_log_limiting_arguments,
      most_recent_commit_with_file,
      "--format=%H",
      "--follow",
      "--",
      file,
    ]).split("\n", remove_empty: true)

    commits_without_ignored_commits = commits_from_git.reject do |commit|
      commits_to_ignore.includes?(commit)
    end

    if num_commits = num_commits_to_show
      commits_without_ignored_commits.first(num_commits)
    else
      commits_without_ignored_commits
    end
  end

  memoize def git_log_limiting_arguments : Array(String)
    if @show_all
      [] of String
    elsif num_days = num_days_to_show
      ["--since=#{num_days} days ago"]
    else
      ["-n", num_commits_to_request_from_git.to_s]
    end
  end

  memoize def most_recent_commit_with_file : String
    if File.exists?(file)
      "HEAD"
    else
      capture_command("git", ["log", "--all", "-1", "--format=%H", "--", file]).rstrip
    end
  end

  memoize def renames : Hash(String, String)
    renames = {} of String => String

    rename_log = capture_command("git", [
      "log",
      "HEAD",
      "--format=%H",
      "--name-status",
      "--follow",
      "--diff-filter=R",
      "--",
      file,
    ])

    rename_log.split("\n").each_slice(3) do |lines|
      if lines.size == 3
        if match = lines[2].match(/\AR\d+\s+(\S+)/)
          renames[lines[0]] = match[1]
        end
      end
    end

    renames
  end

  memoize def git_blame_ignore_revs_file : String?
    file_path = capture_command("git", ["config", "blame.ignoreRevsFile"]).rstrip
    file_path.empty? ? nil : file_path
  end

  memoize def commits_to_ignore : Array(String)
    if @include_ignored || (file_path = git_blame_ignore_revs_file).nil?
      [] of String
    else
      File.read(file_path).split("\n").select do |commit|
        commit.matches?(/\A[0-9a-f]{40}\z/)
      end
    end
  end
end

class GitHistory::Cli < ClimProgram
  main do
    desc "Print the Git history of a file."
    usage "ghist file [options]"

    option "-i", "--include-ignored", type: Bool, desc: "show changes listed in git blame ignore revs file"
    option "-a", "--all", type: Bool, desc: "show all commits"
    option "-c COMMITS", "--commits COMMITS", type: Int32, desc: "number of commits to show"
    option "-d DAYS", "--days DAYS", type: Int32, desc: "number of days of history to show"
    help short: "-h"

    argument "file", type: String, desc: "file path", required: true

    run do |opts, args|
      file = args.file

      if args.all_args.size != 1
        raise Clim::ClimInvalidOptionException.new "Expected exactly one file argument."
      end

      if opts.all && (opts.commits || opts.days)
        raise Clim::ClimInvalidOptionException.new "The --all option cannot be used with --commits or --days."
      end

      GitHistory.new(
        file: file,
        include_ignored: opts.include_ignored,
        show_all: opts.all,
        num_commits_to_show: opts.commits,
        num_days_to_show: opts.days,
      ).call
    end
  end
end

GitHistory::Cli.start!(ARGV)
