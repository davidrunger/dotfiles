#!/usr/bin/env ruby
# frozen_string_literal: true

# This tool parses the VS Code theme data output from themes.vscode.one and
# formats it in the way required by the VS Coe settings.json file.
#
# Example (copies the formatted theme JSON to the clipboard):
#   ~/code/dotfiles/tools/parse-vs-code-theme.rb ~/Downloads/bloom-1-1-0-fork-color-theme.json

require 'json'

BAD_TOKEN_COLOR_NAMES = [
  'inserted.diff',
  'deleted.diff',
].freeze

theme_data = JSON.parse(File.read(ARGV[0]))
token_colors = theme_data['tokenColors']
colors = theme_data['colors']

token_colors.reject! { BAD_TOKEN_COLOR_NAMES.include?(_1['name']) }

hash_for_vs_code = {
  'editor.tokenColorCustomizations' => {
    'textMateRules' => token_colors,
  },
  'workbench.colorCustomizations' => colors,
}

class String
  def pipe(command)
    IO.popen(command, 'r+') do |io|
      io.puts(self)
      io.close_write
      io.read
    end
  end
end

JSON.dump(hash_for_vs_code).
  pipe('prettier --stdin-filepath=x.json').
  pipe("sed '1d;$d'").
  pipe('cpy')
