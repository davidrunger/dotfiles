require "clim"

abstract class ClimProgram < Clim
  def self.start!(argv : Array(String))
    start_parse(argv)
  rescue ex : Clim::ClimException | Clim::ClimInvalidOptionException | Clim::ClimInvalidTypeCastException
    STDERR.puts "ERROR: #{ex.message}"
    STDERR.puts
    STDERR.puts "Please see the `--help`."
    exit(1)
  end
end
