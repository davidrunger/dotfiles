require "memoization"
require "./command_line_tool"

class GitCommitComparison < CommandLineTool
  def initialize(@older_sha : String, @newer_sha : String)
  end

  memoize def identical? : Bool
    older_message == newer_message && patches_identical?
  end

  memoize def older_message : String
    commit_message(@older_sha)
  end

  memoize def newer_message : String
    commit_message(@newer_sha)
  end

  memoize def patch_diff : String
    return "" if patches_identical?

    range_diff_without_commit_message(
      capture_command("git", [
        "range-diff",
        "--no-color",
        "#{@older_sha}^!",
        "#{@newer_sha}^!",
      ]),
    )
  end

  private def commit_message(sha : String) : String
    capture_command("git", ["show", "--no-patch", "--format=%B", sha])
  end

  private def commit_patch(sha : String) : String
    capture_command("git", ["diff", "#{sha}^", sha])
  end

  private def patch_id(patch : String) : String
    capture_command("git", ["patch-id", "--stable"], input: IO::Memory.new(patch)).split.first? || ""
  end

  private def patches_identical? : Bool
    patch_id(commit_patch(@older_sha)) == patch_id(commit_patch(@newer_sha))
  end

  private def range_diff_without_commit_message(diff : String) : String
    String.build do |filtered_diff|
      skipping_commit_message = false

      diff.each_line do |line|
        if line.starts_with?("    @@ Commit message")
          skipping_commit_message = true
        elsif skipping_commit_message && line.starts_with?("    @@ ")
          skipping_commit_message = false
        end

        filtered_diff << line << '\n' if !skipping_commit_message
      end
    end.strip
  end
end
