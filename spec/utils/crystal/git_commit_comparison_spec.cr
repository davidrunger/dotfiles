require "file_utils"
require "spec"
require "../../../utils/crystal/git_commit_comparison"

private def git(repository : String, *arguments : String) : String
  output = IO::Memory.new
  status = Process.run("git", arguments, chdir: repository, output: output, error: Process::Redirect::Inherit)
  status.success?.should be_true
  output.to_s.rstrip
end

describe GitCommitComparison do
  it "distinguishes identical rebased commits from message and code changes" do
    repository = File.join(Dir.tempdir, "gad-git-commit-comparison-#{Process.pid}")
    Dir.mkdir(repository)

    begin
      git(repository, "init", "--quiet")
      git(repository, "config", "user.email", "gad@example.com")
      git(repository, "config", "user.name", "gad spec")

      File.write(File.join(repository, "base"), "base\n")
      git(repository, "add", "base")
      git(repository, "commit", "--quiet", "-m", "Base")
      base_sha = git(repository, "rev-parse", "HEAD")

      File.write(File.join(repository, "branch"), "branch\n")
      git(repository, "add", "branch")
      git(repository, "commit", "--quiet", "-m", "Branch change")
      older_sha = git(repository, "rev-parse", "HEAD")

      git(repository, "switch", "--quiet", "--detach", base_sha)
      File.write(File.join(repository, "upstream"), "upstream\n")
      git(repository, "add", "upstream")
      git(repository, "commit", "--quiet", "-m", "Upstream change")

      git(repository, "cherry-pick", "--quiet", older_sha)
      rebased_sha = git(repository, "rev-parse", "HEAD")

      Dir.cd(repository) do
        GitCommitComparison.new(older_sha, rebased_sha).identical?.should be_true
      end

      git(repository, "commit", "--quiet", "--amend", "-m", "Changed message")
      message_changed_sha = git(repository, "rev-parse", "HEAD")

      Dir.cd(repository) do
        GitCommitComparison.new(older_sha, message_changed_sha).identical?.should be_false
      end

      File.write(File.join(repository, "branch"), "changed branch\n")
      git(repository, "add", "branch")
      git(repository, "commit", "--quiet", "--amend", "-m", "Branch change")
      code_changed_sha = git(repository, "rev-parse", "HEAD")

      Dir.cd(repository) do
        GitCommitComparison.new(older_sha, code_changed_sha).identical?.should be_false
      end
    ensure
      FileUtils.rm_rf(repository)
    end
  end
end
