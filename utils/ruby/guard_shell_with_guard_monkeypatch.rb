# frozen_string_literal: true

# This avoids re-running specs (or other guard-watched scripts) multiple times
# when a file is saved multiple times while the spec(s) are executing or if a
# bunch of files are updated at once (e.g. via a bulk save in the editor or via
# a git rebase). Instead, just run once after the most recent modification.

# This breaks with the idea of guard, which is that if file X is modified, then
# we need to take action Y, and if file A is modified, then we need to take
# action B. Instead, this monkeypatch assumes that if X or A is modified, then
# we just need to take action M (and only one time). In the way that we are
# currently using guard, this assumption is true.

require 'guard/shell'

module RungerGuardWatcherPatches
  def match_files(guard, files)
    super(guard, files.empty? ? [] : [files.first])
  end
end

Guard::Watcher.singleton_class.prepend(RungerGuardWatcherPatches)
