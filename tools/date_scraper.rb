# frozen_string_literal: true

# Prep:
# 1. Change serialization in Api::V1::LibraryController#serialized_results to return no results.
# 2. Make sure that assessment scheduling is open (by changing
#    school_years.assessment_scheduling_opens_on)

# Run with:
#   ruby $HOME/code/dotfiles/tools/date_scraper.rb

# Reset with:
#   rm ./tmp/scraping.yml

# Parse with:
#   ruby $HOME/code/dotfiles/tools/date_scrape_parser.rb

require 'active_support/all'
require 'amazing_print'
require 'dotenv/load'
require 'ferrum'
require 'nokogiri'
require 'yaml'

class Scraper
  BAD_PATTERNS = [
    %r{(\A|/)es(/|\z)},
    %r{(\A|/)vulnerability-disclosure(/|\z)},
    %r{/texts/},
    %r{/themes/},
    %r{[&?]page=},
    %r{sign_out},
    %r{performance_downloads},
    %r{download_lessons_performance},
    %r{download_small_group_lessons_performance},
    %r{/print},
    %r{/lesson_downloads/},
    %r{\.xlsx},
  ].freeze
  LOCALHOST = 'http://localhost:3000'
  NETWORK_BLACKLIST = [
    %r{\.(jpg|png|svg|woff2)(\?.*)?\z},
  ].freeze
  YAML_PATH = './tmp/scraping.yml'

  def initialize
    visited = []
    next_paths = ['/en/home']
    @dates = {}

    if File.exist?(YAML_PATH)
      visited, next_paths, @dates =
        YAML.load_file(YAML_PATH).
          values_at(:visited, :next_paths, :dates)
    end

    @browser = Ferrum::Browser.new(
      headless: false,
      timeout: 10,
      window_size: [1280, 1024],
    )
    @browser.network.blacklist = NETWORK_BLACKLIST
    @visited_paths = Set.new(visited)
    @next_paths =
      (next_paths.uniq - visited).reject { |path| BAD_PATTERNS.any? { path.match?(_1) } }

    log_in
  end

  def crawl
    next_path = nil

    loop do
      next_path = @next_paths.shift
      break if next_path.nil?

      crawl_path(next_path)
    end
  ensure
    File.write(
      YAML_PATH,
      {
        visited: @visited_paths.to_a - [next_path],
        next_paths: ([next_path] + @next_paths.to_a).uniq,
        dates: @dates,
      }.to_yaml,
    )
    @browser.quit
  end

  private

  def crawl_path(path)
    puts(%(path: #{path}))
    @browser.goto("#{LOCALHOST}#{path}")

    wait_for_done_loading

    return if !@browser.current_url.start_with?(LOCALHOST)

    store_dates(path)

    @visited_paths << path

    new_paths_on_page =
      @browser.css('a[href]').filter_map do |link|
        path = link.attribute('href')
        path if good_new_path?(path)
      end.uniq

    @next_paths.concat(new_paths_on_page)
    @next_paths.uniq!
  end

  def store_dates(path)
    dates =
      Nokogiri::HTML5(@browser.page.body).inner_text.
        scan(%r{.{0,30}[0-3]?[[:digit:]][/-][0-3]?[[:digit:]][/-]20(?:18|19|20|21|22|23).{0,30}}).
        map do |date_line|
          date_line.sub(
            %r{([0-3]?[[:digit:]][/-][0-3]?[[:digit:]][/-]20(?:18|19|20|21|22|23))},
          ) do |match|
            " #{AmazingPrint::Colors.blue(match)} "
          end.squish
        end

    @dates[path] = dates if dates.present?
  end

  def good_new_path?(path)
    return false if BAD_PATTERNS.any? { path.match?(_1) }
    return false if @visited_paths.include?(path)

    path.match?(%r{\A/[^/]}) || path.start_with?("#{LOCALHOST}/")
  end

  def log_in
    @browser.cookies.clear

    @browser.goto("#{LOCALHOST}/en/user/login")

    @browser.at_css('input[name=login]').tap do |element|
      element.focus
      # element.type('dsdemo@cl-test.org')
      element.type('jackdawson@cl.org')
    end

    @browser.at_css('input[name=password]').tap do |element|
      element.focus
      element.type(ENV.fetch('USER_PASSWORD'))
    end

    @browser.at_css('.login-form button[type=submit]').click
  end

  def done_loading?
    all_frames_stopped_loading? && no_spinners?
  end

  def all_frames_stopped_loading?
    states = @browser.frames.map(&:state).uniq
    states == [:stopped_loading]
  end

  def no_spinners?
    @browser.css('.cl-spinner').size <= 1 # There's always one for notifications, I think.
  end

  def wait_for_done_loading
    tenths_of_a_second_to_wait.times do
      break if done_loading?

      sleep(0.1)
    end

    sleep(0.3) # Allow JavaScript to execute.
  end

  def tenths_of_a_second_to_wait
    case @browser.current_url
    when %r{/performance_print/} then 80
    else 30
    end
  end
end

Scraper.new.crawl
