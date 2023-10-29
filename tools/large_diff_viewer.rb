last_viewed_file = Runger.config.scratch

changed_files = `gf`.rstrip.split("\n")

changed_files.
  each.with_index(1) do |file, position|
    if last_viewed_file.present? && file <= last_viewed_file
      next
    end

    system("clear && printf '\e[3J'", exception: true)
    puts("#{position} / #{changed_files.size}")
    system({ "DELTA_PAGER" => "cat" }, "gdom #{file}", exception: true)
    gets
    scratch!(file, silent: true)
  end
