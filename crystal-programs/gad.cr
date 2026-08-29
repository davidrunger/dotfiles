#!/usr/bin/env crystal

# Interactively walk diffs between consecutive versions of the current branch.
#
# Keyboard controls:
# - Enter or Down: select the next older reflog transition
# - Up: select the next newer reflog transition
# - Shift+Up or Shift+Down: scroll the preview by one line
# - Shift+Page Up or Shift+Page Down: scroll the preview by one page
# - q or Escape: quit

require "memoization"
require "../utils/crystal/command_line_tool"
require "../utils/crystal/clim_program"

record ReflogEntry, sha : String, parent_shas : Array(String), age : String, action : String do
  def branch_creation? : Bool
    action.starts_with?("branch: Created from ")
  end

  def rebase_completion? : Bool
    action.starts_with?("rebase (finish): ")
  end

  # Rewritten versions of one commit retain the same parents even though their SHAs differ.
  def revision_of?(other : ReflogEntry) : Bool
    parent_shas == other.parent_shas
  end
end

class GitAmendmentDiff < CommandLineTool
  def initialize(@older_sha : String, @newer_sha : String, @change_age : String, @show_message_as_new : Bool)
  end

  def call
    print_transition_details
    puts
    print_diff_section("COMMIT MESSAGE", commit_message_diff)
    puts
    print_diff_section("CODE", code_diff)
  end

  private def print_transition_details
    puts "#{@older_sha} -> #{@newer_sha} (#{@change_age})"
  end

  private def print_diff_section(title : String, diff : String)
    puts "\e[1;34m#{title}\e[0m"
    puts "\e[34m#{"=" * title.size}\e[0m"

    if diff.empty?
      puts "No changes."
    else
      run_command("delta", delta_arguments, input: IO::Memory.new(diff))
    end
  end

  memoize def delta_arguments : Array(String)
    arguments = ["--paging=never"]

    if preview_columns = ENV["FZF_PREVIEW_COLUMNS"]?
      arguments << "--width=#{preview_columns}"
    end

    arguments
  end

  memoize def commit_message_diff : String
    older_file = File.tempfile("gad-older-commit-message")
    newer_file = File.tempfile("gad-newer-commit-message")

    begin
      older_message = @show_message_as_new ? "" : commit_message(@older_sha)
      older_file << older_message
      older_file.flush
      newer_file << commit_message(@newer_sha)
      newer_file.flush

      normalize_commit_message_paths(
        capture_command("git", [
          "--no-pager",
          "diff",
          "--no-index",
          "--no-color",
          "--no-prefix",
          "--",
          older_file.path,
          newer_file.path,
        ]),
        older_file.path,
        newer_file.path,
      )
    ensure
      older_file.delete
      newer_file.delete
    end
  end

  private def normalize_commit_message_paths(diff : String, older_path : String, newer_path : String) : String
    diff
      .gsub(older_path.lstrip('/'), "older-commit-message")
      .gsub(newer_path.lstrip('/'), "newer-commit-message")
  end

  private def commit_message(sha : String) : String
    capture_command("git", ["show", "--no-patch", "--format=%B", sha])
  end

  memoize def code_diff : String
    capture_command("git", [
      "--no-pager",
      "diff",
      "--no-color",
      "--no-prefix",
      @older_sha,
      @newer_sha,
    ])
  end
end

class GitAmendmentDiffWalker < CommandLineTool
  FIELD_SEPARATOR              = '\u001f'
  MINIMUM_PREVIEW_PANE_COLUMNS = 40
  NAVIGATION_PANE_COLUMNS      = 20
  RECORD_SEPARATOR             = '\u0000'

  def call
    if reflog_entries.size < 2
      puts "No previous reflog version exists for branch '#{branch_name}'."
      return
    end

    if fzf_input.empty?
      puts "No non-rebase reflog transition exists for branch '#{branch_name}'."
      return
    end

    status = run_command("fzf", fzf_arguments, input: IO::Memory.new(fzf_input))
    exit(status.exit_code) if !status.success? && status.exit_code != 130
  end

  memoize def branch_name : String
    branch_name = capture_command("git", ["branch", "--show-current"]).rstrip

    if branch_name.empty?
      STDERR.puts "ERROR: gad requires a checked-out branch; HEAD is detached."
      exit(1)
    end

    branch_name
  end

  memoize def reflog_entries : Array(ReflogEntry)
    reflog_output = capture_command("git", [
      "reflog",
      "show",
      "--date=relative",
      "--format=%H%x1f%P%x1f%gd%x1f%gs%x00",
      "refs/heads/#{branch_name}",
    ])

    records = reflog_output.split(RECORD_SEPARATOR).map(&.strip).reject(&.empty?)

    records.map do |record|
      sha, parent_shas, selector, action = record.split(FIELD_SEPARATOR, 4)
      ReflogEntry.new(sha, parent_shas.split, selector.rpartition("@{")[2].rstrip('}'), action)
    end
  end

  memoize def fzf_input : String
    String.build do |input|
      reflog_entries.each_cons_pair.with_index do |(newer_entry, older_entry), index|
        next if newer_entry.rebase_completion?

        older_position = index + 1
        newer_position = index
        transition = "@{#{older_position}}->@{#{newer_position}}"
        show_message_as_new = older_entry.branch_creation? || !newer_entry.revision_of?(older_entry)

        input << older_entry.sha << '\t'
        input << newer_entry.sha << '\t'
        input << newer_entry.age << '\t'
        input << show_message_as_new << '\t'
        input << transition << '\n'
      end
    end
  end

  memoize def fzf_arguments : Array(String)
    executable = Process.executable_path || "gad"
    preview_command = "#{Process.quote(executable)} --preview {1} {2} {3} {4}"

    [
      "--ansi",
      "--bind=enter:down,shift-up:preview-up,shift-down:preview-down,shift-page-up:preview-page-up,shift-page-down:preview-page-down,q:abort",
      "--delimiter=\\t",
      "--highlight-line",
      "--info=hidden",
      "--layout=reverse",
      "--list-label=#{branch_name} reflog transitions",
      "--no-input",
      "--no-mouse",
      "--no-sort",
      "--preview=#{preview_command}",
      "--preview-label=reflog transition diff",
      "--preview-window=right,#{preview_pane_columns},nowrap",
      "--with-nth=5",
    ]
  end

  memoize def preview_pane_columns : String
    terminal_columns = capture_command("stty", ["size"]).split.last?.try(&.to_i?) if STDIN.tty?

    if terminal_columns && terminal_columns >= NAVIGATION_PANE_COLUMNS + MINIMUM_PREVIEW_PANE_COLUMNS
      (terminal_columns - NAVIGATION_PANE_COLUMNS).to_s
    else
      "80%"
    end
  end
end

class GitAmendmentDiffWalker::Cli < ClimProgram
  main do
    desc "Interactively walk current-branch reflog diffs."
    usage "gad"

    help short: "-h"

    run do |_opts, args|
      if args.all_args.present?
        raise Clim::ClimInvalidOptionException.new "Expected no arguments."
      end

      GitAmendmentDiffWalker.new.call
    end
  end
end

if ARGV.first? == "--preview"
  if ARGV.size != 5
    STDERR.puts "ERROR: --preview requires older and newer commit SHAs, a change age, and a new-message flag."
    exit(1)
  end

  GitAmendmentDiff.new(ARGV[1], ARGV[2], ARGV[3], ARGV[4] == "true").call
else
  GitAmendmentDiffWalker::Cli.start!
end
