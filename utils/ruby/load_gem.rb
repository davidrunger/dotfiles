# frozen_string_literal: true

# This method allows a gem to be loaded, even if running within the context of bundler and the gem
# to be loaded is not listed in the Gemfile.

# rubocop:disable Style/TopLevelMethodDefinition
def load_gem(gem_name, load_path_only: false, require_name: gem_name)
  begin
    require gem_name
  rescue LoadError
    # Continue with code below to load the gem.
  else
    # The gem loaded successfully without our help; return.
    return
  end

  rbenv_gem_path = Gem.paths.path.find { _1.include?('.rbenv') }
  matching_gem_directories =
    Dir["#{rbenv_gem_path}/gems/#{gem_name}-*"].grep(%r{/#{gem_name}-\d[^/]+\z})
  latest_gem_directory =
    matching_gem_directories.max_by do |gem_directory_path|
      version_number = gem_directory_path.split('/').last.delete_prefix("#{gem_name}-")
      Gem::Version.new(version_number)
    end

  if latest_gem_directory.nil?
    fail("Could not find installed gem #{gem_name}")
  end

  gem_lib_directory = "#{latest_gem_directory}/lib"
  $LOAD_PATH << gem_lib_directory if !$LOAD_PATH.include?(gem_lib_directory)
  gem_name_and_version = latest_gem_directory.split('/').last
  gemspec_path = "#{rbenv_gem_path}/specifications/#{gem_name_and_version}.gemspec"
  Gem::Specification.load(gemspec_path).runtime_dependencies.map do |dependency|
    load_gem(dependency.name, load_path_only: true)
  end
  require require_name unless load_path_only
end
# rubocop:enable Style/TopLevelMethodDefinition
