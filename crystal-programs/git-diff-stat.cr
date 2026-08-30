#!/usr/bin/env crystal

# Show per-file Git diff statistics with separate insertion and deletion counts.

require "../utils/crystal/command_line_tool"
require "../utils/crystal/clim_program"

record DiffStat, path : String, additions : Int32?, deletions : Int32? do
  def binary? : Bool
    additions.nil? || deletions.nil?
  end

  def total_changes : Int32
    (additions || 0) + (deletions || 0)
  end
end

class GitDiffStat < CommandLineTool
  MAX_BAR_WIDTH = 60
  GREEN         = "\e[32m"
  RED           = "\e[31m"
  RESET         = "\e[0m"

  def initialize(@revision : String?, @color : Bool = STDOUT.tty?)
  end

  def call
    stats = diff_stats
    return if stats.empty?

    filename_width = stats.max_of(&.path.size)
    count_width = max_count_width(stats)
    largest_change = stats.max_of(&.total_changes)
    bar_width = calculated_bar_width(filename_width, count_width)

    stats.each do |stat|
      print_stat(stat, filename_width, count_width, largest_change, bar_width)
    end

    print_summary(stats)
  end

  private def diff_stats : Array(DiffStat)
    git_arguments = ["diff", "--numstat"]
    if revision = @revision
      git_arguments << revision
    end

    output = IO::Memory.new
    status = Process.run("git", git_arguments, output: output, error: Process::Redirect::Inherit)
    exit(status.exit_code) if !status.success?

    output.to_s.lines(chomp: true).reject(&.empty?).map do |line|
      additions, deletions, path = line.split('\t', 3)

      if additions == "-" || deletions == "-"
        DiffStat.new(path, nil, nil)
      else
        DiffStat.new(path, additions.to_i, deletions.to_i)
      end
    end
  end

  private def max_count_width(stats : Array(DiffStat)) : Int32
    stats.reduce(1) do |width, stat|
      [width, (stat.additions || 0).to_s.size, (stat.deletions || 0).to_s.size].max
    end
  end

  private def calculated_bar_width(filename_width : Int32, count_width : Int32) : Int32
    if width = terminal_width
      fixed_width = 1 + filename_width + 3 + (count_width + 1) * 2 + 2 + 3
      available_width = width - fixed_width

      return 0 if available_width < 0

      return [available_width, MAX_BAR_WIDTH].min
    end

    MAX_BAR_WIDTH
  end

  private def print_stat(
    stat : DiffStat,
    filename_width : Int32,
    count_width : Int32,
    largest_change : Int32,
    bar_width : Int32,
  )
    if stat.binary?
      puts " #{stat.path.ljust(filename_width)} | binary file"
      return
    end

    additions = stat.additions || 0
    deletions = stat.deletions || 0
    added_bar, deleted_bar = bars(additions, deletions, largest_change, bar_width)

    puts " #{stat.path.ljust(filename_width)} | " \
         "#{additions.to_s.rjust(count_width)}#{colorize("+", GREEN)}, " \
         "#{deletions.to_s.rjust(count_width)}#{colorize("-", RED)} | " \
         "#{colorize("+" * added_bar, GREEN)}#{colorize("-" * deleted_bar, RED)}"
  end

  private def bars(
    additions : Int32,
    deletions : Int32,
    largest_change : Int32,
    bar_width : Int32,
  ) : {Int32, Int32}
    total_changes = additions + deletions
    return {0, 0} if total_changes == 0 || largest_change == 0 || bar_width == 0

    minimum_width = additions > 0 && deletions > 0 ? 2 : 1
    scaled_width = (total_changes.to_f / largest_change * bar_width).round.to_i
    scaled_width = minimum_width if scaled_width < minimum_width
    scaled_width = bar_width if scaled_width > bar_width

    added_bar = (additions.to_f / total_changes * scaled_width).round.to_i
    deleted_bar = scaled_width - added_bar

    if additions > 0 && added_bar == 0
      added_bar = 1
      deleted_bar = scaled_width - added_bar
    end

    if deletions > 0 && deleted_bar == 0
      deleted_bar = 1
      added_bar = scaled_width - deleted_bar
    end

    {added_bar, deleted_bar}
  end

  private def terminal_width : Int32?
    return unless STDIN.tty?

    if columns = ENV["COLUMNS"]?.try(&.to_i?)
      return columns if columns > 0
    end

    capture_command("stty", ["size"]).split.last?.try(&.to_i?)
  end

  private def print_summary(stats : Array(DiffStat))
    additions = stats.sum { |stat| stat.additions || 0 }
    deletions = stats.sum { |stat| stat.deletions || 0 }

    puts "#{stats.size} #{pluralize(stats.size, "file", "files")} changed, " \
         "#{additions}#{colorize("+", GREEN)}, #{deletions}#{colorize("-", RED)}"
  end

  private def pluralize(count : Int, singular : String, plural : String) : String
    count == 1 ? singular : plural
  end

  private def colorize(value : String, color : String) : String
    @color && !value.empty? ? "#{color}#{value}#{RESET}" : value
  end
end

class GitDiffStat::Cli < ClimProgram
  main do
    desc "Show per-file Git diff statistics with insertion and deletion counts."
    usage "git-diff-stat [revision]"

    help short: "-h"

    argument "revision", type: String, desc: "revision to compare against", required: false

    run do |_opts, args|
      if args.all_args.size > 1
        raise Clim::ClimInvalidOptionException.new "Expected at most one revision."
      end

      GitDiffStat.new(args.all_args.first?).call
    end
  end
end

GitDiffStat::Cli.start!
