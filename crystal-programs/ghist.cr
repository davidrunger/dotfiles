#!/usr/bin/env crystal

# Print [g]it [hist]ory of a file.

require "memoization"
require "../utils/crystal/command_line_tool"
require "../utils/crystal/clim_program"

class GitHistory < CommandLineTool
  record Commit, sha : String, file_names : Array(String)
  record HistorySegment, commits : Array(Commit), parent_commit : String?, file_name : String

  def initialize(
    @file : String,
    @include_ignored : Bool,
    @num_commits_to_show : Int32?,
    @num_days_to_show : Int32?,
  )
  end

  def call
    commits_to_show.each do |commit|
      puts
      run_command("hr")
      run_command(
        "git",
        ["show", commit.sha, "--", *commit.file_names],
        env: {"DELTA_PAGER" => "cat"},
      )
      run_command("hr")
    end
  end

  private def file : String
    @file
  end

  memoize def num_commits_to_show : Int32?
    @num_days_to_show ? nil : @num_commits_to_show
  end

  memoize def num_days_to_show : Int32?
    @num_days_to_show
  end

  memoize def commits_to_show : Array(Commit)
    commits_from_git = [] of Commit
    start_commit = most_recent_commit_with_file
    file_name = file

    loop do
      history_segment = history_segment(start_commit, file_name)
      commits_from_git.concat(history_segment.commits)

      if parent_commit = history_segment.parent_commit
        start_commit = parent_commit
        file_name = history_segment.file_name
      else
        break
      end
    end

    commits_without_ignored_commits = commits_from_git.reject do |commit|
      commits_to_ignore.includes?(commit.sha)
    end

    if num_commits = num_commits_to_show
      commits_without_ignored_commits.first(num_commits)
    else
      commits_without_ignored_commits
    end
  end

  private def history_segment(start_commit : String, file_name : String) : HistorySegment
    commits = [] of Commit
    file_name_at_commit = file_name
    parent_commit : String? = nil

    capture_command("git", [
      "log",
      *git_log_limiting_arguments,
      start_commit,
      "--format=%H",
      "--name-status",
      "--follow",
      "--",
      file_name,
    ]).split("\n", remove_empty: true).each_slice(2) do |commit_and_status|
      commit, status = commit_and_status
      status_parts = status.split("\t")
      file_names = if status.starts_with?("R")
                     [status_parts[1], file_name_at_commit]
                   else
                     [file_name_at_commit]
                   end

      commits << Commit.new(commit, file_names)

      if status.starts_with?("A") || status.starts_with?("C")
        parent_commit = parent_commit_for(commit)
        break
      end

      file_name_at_commit = file_names.first
    end

    HistorySegment.new(commits, parent_commit, file_name_at_commit)
  end

  private def parent_commit_for(commit : String) : String?
    capture_command("git", [
      "rev-list",
      "--parents",
      "-n",
      "1",
      commit,
    ]).split[1]?
  end

  memoize def git_log_limiting_arguments : Array(String)
    if num_days = num_days_to_show
      ["--since=#{num_days} days ago"]
    elsif num_commits = num_commits_to_show
      ["-n", (num_commits + commits_to_ignore.size).to_s]
    else
      [] of String
    end
  end

  memoize def most_recent_commit_with_file : String
    if File.exists?(file)
      "HEAD"
    else
      capture_command("git", ["log", "--all", "-1", "--format=%H", "--", file]).rstrip
    end
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
    option "-c COMMITS", "--commits COMMITS", type: Int32, desc: "number of commits to show"
    option "-d DAYS", "--days DAYS", type: Int32, desc: "number of days of history to show"
    help short: "-h"

    argument "file", type: String, desc: "file path", required: true

    run do |opts, args|
      file = args.file

      if args.all_args.size != 1
        raise Clim::ClimInvalidOptionException.new "Expected exactly one file argument."
      end

      GitHistory.new(
        file: file,
        include_ignored: opts.include_ignored,
        num_commits_to_show: opts.commits,
        num_days_to_show: opts.days,
      ).call
    end
  end
end

GitHistory::Cli.start!
