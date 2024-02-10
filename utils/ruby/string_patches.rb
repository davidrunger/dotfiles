# frozen_string_literal: true

class String
  AmazingPrint::Colors.methods(false).each do |color|
    define_method(color) do
      AmazingPrint::Colors.send(color, self)
    end
  end

  def cpp
    # copying SQL, e.g. User.select(:id, :email).to_sql.cpp
    if start_with?('SELECT')
      super(tr('"', '')) # remove double quotes (from around table names, etc.)
    else
      super(self)
    end
  end

  # "Sublime regex (for searching)"
  def sr
    underscore.gsub('_', '.?').cpp
  end

  def upp
    underscore.cpp
  end

  def const
    gsub(%r{((app/\w+)|lib)/}, '').
      gsub(/\d{4}-\d{2}-\d{2}-/, '').
      gsub('.rb', '').
      underscore.
      camelize.
      cpp
  end

  def spec
    gsub(%r{\A(lib/)}, '').
      then { |path| "spec/#{path}" }.
      gsub(%r{\.rb}, '_spec.rb').
      cpp
  end

  # Remove colorizing ANSI escape codes.
  def uncolor
    gsub(/\e\[([;\d]+)?m/, '')
  end
end
