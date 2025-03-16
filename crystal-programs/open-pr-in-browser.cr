#!/usr/bin/env crystal

# Opens a GitHub PR in the browser (extracted from input piped to this command).

require "memoization"

class OpenPrInBrowser
  @create_pr_command_output : String

  def initialize(create_pr_command_output)
    @create_pr_command_output = create_pr_command_output
  end

  def open_pr
    if pr_link
      Process.new("open #{pr_link}", shell: true)
    end
  end

  memoize def pr_link : String
    @create_pr_command_output[%r{https://github.com/[^/]+/[^/]+/pull/\d+}]
  end
end

OpenPrInBrowser.new(STDIN.gets_to_end).open_pr
