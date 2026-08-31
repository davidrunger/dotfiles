record ReflogEntry, sha : String, parent_shas : Array(String), age : String, action : String, position : Int32 do
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

record ReflogTransition, older_entry : ReflogEntry, newer_entry : ReflogEntry do
  def compare_commit_patches? : Bool
    newer_entry.rebase_completion?
  end

  def label : String
    "@{#{older_entry.position}}->@{#{newer_entry.position}}"
  end

  def show_message_as_new? : Bool
    older_entry.branch_creation? || (!compare_commit_patches? && !newer_entry.revision_of?(older_entry))
  end
end

class ReflogHistory
  def initialize(@entries : Array(ReflogEntry))
  end

  def transitions : Array(ReflogTransition)
    meaningful_entries.each_cons_pair.map do |newer_entry, older_entry|
      ReflogTransition.new(older_entry, newer_entry)
    end.to_a
  end

  private def meaningful_entries : Array(ReflogEntry)
    entries = [] of ReflogEntry
    index = 0

    while index < @entries.size
      entry = @entries[index]
      entries << entry

      matching_index = ((index + 1)...@entries.size).find do |older_index|
        @entries[older_index].sha == entry.sha
      end
      index = matching_index ? matching_index + 1 : index + 1
    end

    entries
  end
end
