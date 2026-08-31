require "spec"
require "../../utils/crystal/reflog_history"

private def reflog_entry(
  sha : String,
  *,
  parent_sha : String = "parent",
  action : String = "commit (amend): Message",
  position : Int32,
) : ReflogEntry
  ReflogEntry.new(sha, [parent_sha], "recently", action, position)
end

describe ReflogHistory do
  it "collapses an excursion that returns to the same commit" do
    entries = [
      reflog_entry("rebased", parent_sha: "new-base", action: "rebase (finish): branch onto new-base", position: 0),
      reflog_entry("branch-commit", position: 1),
      reflog_entry("temporary-commit", parent_sha: "branch-commit", action: "commit: Temporary", position: 2),
      reflog_entry("branch-commit", position: 3),
      reflog_entry("original", position: 4),
    ]

    transitions = ReflogHistory.new(entries).transitions

    transitions.map(&.label).should eq(["@{1}->@{0}", "@{4}->@{1}"])
    transitions.map(&.older_entry.sha).should eq(["branch-commit", "original"])
    transitions.map(&.newer_entry.sha).should eq(["rebased", "branch-commit"])
  end

  it "compares a completed rebase as a revision across changed parents" do
    entries = [
      reflog_entry("new", parent_sha: "new-base", action: "rebase (finish): branch onto new-base", position: 0),
      reflog_entry("old", parent_sha: "old-base", position: 1),
    ]

    transition = ReflogHistory.new(entries).transitions.first

    transition.compare_commit_patches?.should be_true
    transition.show_message_as_new?.should be_false
  end
end
