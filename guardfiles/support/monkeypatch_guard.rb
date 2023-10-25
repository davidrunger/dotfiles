# frozen_string_literal: true

# This is used in `GuardSupport`, which is ultimately used in `gal`.

# This avoids re-running specs multiple times when a file is saved multiple times while the spec(s)
# are executing. Instead, just run once after the most recent modification.
module RungerGuardWatcherPatches
  def match_files(guard, files)
    super(guard, files.uniq)
  end
end
Guard::Watcher.singleton_class.prepend(RungerGuardWatcherPatches)
