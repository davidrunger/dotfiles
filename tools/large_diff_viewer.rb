# frozen_string_literal: true

# Goes through changed files (relative to the main branch) one at a time.

def clear_scratch
  scratch!(nil, silent: true)
end

last_viewed_file = Runger.config.scratch

changed_files = `gf`.rstrip.split("\n")

if !last_viewed_file.in?(changed_files)
  clear_scratch
  last_viewed_file = nil
end

changed_files.
  each.with_index(1) do |file, position|
    if last_viewed_file.present? && file <= last_viewed_file
      next
    end

    system("hard-clear", exception: true)
    puts("#{position} / #{changed_files.size}")
    system({ "DELTA_PAGER" => "cat" }, "gdom #{file}", exception: true)
    gets
    scratch!(file, silent: true)
  end

clear_scratch
