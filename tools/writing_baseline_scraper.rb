# frozen_string_literal: true

# Prep:
# 1. Change serialization in Api::V1::LibraryController#serialized_results to return no results.
# 2. Make sure that assessment scheduling is open (by changing
#    school_years.assessment_scheduling_opens_on)

# Run with:
#   ruby personal/writing_baseline_scraper.rb

# Reset with:
#   rm ./tmp/scraping.yml

require "active_support/all"
require "amazing_print"
require "dotenv/load"
require "ferrum"
require "nokogiri"
require "yaml"bund

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
  LOCALHOST = "http://localhost:3000"
  NETWORK_BLACKLIST = [
    %r{\.(jpg|png|svg|woff2)(\?.*)?\z},
  ].freeze

  def initialize
    @browser = Ferrum::Browser.new(
      headless: false,
      timeout: 10,
      window_size: [1280, 1024],
    )
    @browser.network.blacklist = NETWORK_BLACKLIST
  end

  def crawl
    log_in

    grade_start_arg = ARGV[0]
    grade_start = grade_start_arg ? Integer(grade_start_arg) : 6
    position_start_arg = ARGV[1]
    position_start = position_start_arg ? Integer(position_start_arg) : 1
    (grade_start..12).each do |grade|
      (position_start..end_position_for_grade(grade)).each do |position|
        check_baseline_link(grade, position)
      end
    end
  rescue StandardError => exception
    ap(exception)
    raise
  ensure
    @browser.quit
  end

  private

  def end_position_for_grade(grade)
    case grade
    in (6..10) then 6
    in (11..12) then 3
    end
  end

  def check_baseline_link(grade, position)
    go_to("/en/library/units?grade=#{grade}")
    click("Unit #{position}")
    click("Lessons & Materials")
    click("Additional Materials")

    if !page_has_text?("Baseline")
      puts("NIL: G#{grade} U#{position}")
      sleep(1.5)
      return
    end

    click_aria("Writing Baseline Assessment Show More")
    click_aria("Preview or Assign Writing Baseline Assessment")

    if page_has_text?("Student Assignment Preview")
      puts("GOOD: G#{grade} U#{position}")
    else
      puts("BAD: G#{grade} U#{position}")
    end

    sleep(1.5)

    nil
  end

  def go_to(path)
    @browser.goto("#{LOCALHOST}#{path}")
    wait_for_done_loading
  end

  def click(text, raise_on_missing: true)
    element = element_containing_text(text)
    click_element(element, text, raise_on_missing:)
  end

  def click_aria(aria_label, raise_on_missing: true)
    element = element_with_aria_label(aria_label)
    click_element(element, aria_label, raise_on_missing:)
  end

  def click_element(element, matcher, raise_on_missing:)
    if element
      element.click
      wait_for_done_loading
    elsif raise_on_missing
      raise "No element found matching '#{matcher}'."
    end
  end

  def element_with_aria_label(aria_label)
    @browser.at_css("[aria-label='#{aria_label}']")
  end

  def element_containing_text(text)
    @browser.at_xpath(xpath_containing_text_selector(text))
  end

  def xpath_containing_text_selector(text)
    <<~XPATH.squish
      //*[
        text()[
          contains(
            translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'),
            '#{text.downcase}'
          )
        ]
      ]
    XPATH
  end

  def page_has_text?(text)
    @browser.at_css('body').text.include?(text)
  end

  def log_in
    @browser.cookies.clear

    @browser.goto("#{LOCALHOST}/en/user/login")

    @browser.at_css("input[name=login]").tap do |element|
      element.focus
      # element.type('dsdemo@cl-test.org')
      element.type("victoria.navarro@commonlit.org")
    end

    @browser.at_css("input[name=password]").tap do |element|
      element.focus
      element.type(ENV.fetch("USER_PASSWORD"))
    end

    @browser.at_css(".login-form button[type=submit]").click

    wait_for_done_loading

    # Clear cookie banner (if present).
    click("Okay", raise_on_missing: false)
  end

  def done_loading?
    all_frames_stopped_loading? && no_spinners?
  end

  def all_frames_stopped_loading?
    states = @browser.frames.map(&:state).uniq
    states == [:stopped_loading]
  end

  def no_spinners?
    @browser.css(".cl-spinner").size <= 1 # There's always one for notifications, I think.
  end

  def wait_for_done_loading
    tenths_of_a_second_to_wait.times do
      break if done_loading?

      sleep(0.1)
    end

    sleep(0.3) # Allow JavaScript to execute.

    nil
  end

  def tenths_of_a_second_to_wait
    case @browser.current_url
    when %r{/performance_print/} then 80
    else 30
    end
  end
end

Scraper.new.crawl
