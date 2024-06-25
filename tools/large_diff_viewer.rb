# frozen_string_literal: true

# Goes through changed files in the most recent commit one at a time.

# Example (run from the repo that has the commit):
#   bin/rails runner /home/david/code/dotfiles/tools/large_diff_viewer.rb

# rubocop:disable Style/TopLevelMethodDefinition
def clear_scratch
  scratch!(nil, silent: true)
end
# rubocop:enable Style/TopLevelMethodDefinition

last_viewed_file = Runger.config.scratch

changed_files = `gfc`.rstrip.split("\n")

if !last_viewed_file.in?(changed_files)
  clear_scratch
  last_viewed_file = nil
end

changed_files.
  each.with_index(1) do |file, position|
    if last_viewed_file.present? && file <= last_viewed_file
      next
    end

    system('hard-clear', exception: true)
    puts("#{position} / #{changed_files.size}")
    system({ 'DELTA_PAGER' => 'cat' }, "gs --pretty="" #{file}", exception: true)
    gets
    scratch!(file, silent: true)
  end

clear_scratch
