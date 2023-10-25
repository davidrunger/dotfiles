# frozen_string_literal: true

require 'chronic'
require 'yaml'

parsed_yaml = YAML.load_file('tmp/scraping.yml')[:dates]

dates = Hash.new { |h, k| h[k] = [] }

parsed_yaml.each do |path, date_strings|
  date_strings.map do |date_string|
    string_date =
      date_string.
        match(%r{([0-3]?[[:digit:]][/-][0-3]?[[:digit:]][/-]20(?:18|19|20|21|22|23))}).
        to_s
    date = Chronic.parse(string_date)
    dates[date] << "#{date_string} (#{path})"
  end
end

dates.sort_by(&:first).each do |_date, date_strings|
  puts(date_strings)
end
