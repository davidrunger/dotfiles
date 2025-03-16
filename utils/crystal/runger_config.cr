require "memoization"
require "yaml"

class RungerConfig
  def self.[](key)
    instance.unified_config[key]
  end

  def self.has_key?(key)
    instance.unified_config.has_key?(key)
  end

  def self.instance
    @@instance ||= new
  end

  memoize def unified_config : Hash(String, YAML::Any)
    public_config.merge(private_config)
  end

  memoize def public_config : Hash(String, YAML::Any)
    parsed_yaml(".runger-config.yml")
  end

  memoize def private_config : Hash(String, YAML::Any)
    parsed_yaml(".runger-config.private.yml")
  end

  private def parsed_yaml(file_name : String) : Hash(String, YAML::Any)
    if File.exists?(file_name)
      content = File.read(file_name)
      YAML.parse(content).as_h.transform_keys(&.to_s)
    else
      {} of String => YAML::Any
    end
  end
end
