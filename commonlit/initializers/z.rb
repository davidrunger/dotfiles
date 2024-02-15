# frozen_string_literal: true

if Rails.env.production?
  fail("Don't run z.rb in production mode!")
end

# This is a Rails initializer with various patches/utilities that improve the Rails development
# experience. It's called `z.rb` so that it runs after all other initializers (since they are
# executed alphabetically).

if defined?(Pry)
  # Load the pry enhancements defined in `pryrc.rb` of dotfiles repo.
  load("#{Dir.home}/.pryrc")
end

if defined?(IRB)
  # Load the IRB enhancements defined in `irbrc.rb` of dotfiles repo.
  load("#{Dir.home}/.irbrc.rb")
end

if Rails.env.in?(%w[development test])
  load("#{Dir.home}/code/dotfiles/utils/ruby/tapp.rb")
end

if Rails.env.test? && !defined?(Rails::Console)
  # This is needed on z-dr-silence-irb-context-warning branch.
  require("rspec/core")
end

module Runger
end

$runger_redis = Redis.new(db: 2)

class Runger::RungerConfig
  include Singleton

  CONFIG_KEYS = %w[
    code_coverage
    current_admin_user
    current_user
    headful_browser
    log_ar_trace
    log_expensive_queries
    log_response_body
    log_to_stdout
    log_verbose_ar_trace
    scratch
    verbose_trace
    walk_through_system_specs
  ].freeze

  CONFIG_KEYS.each do |config_key|
    define_method(config_key) do
      unless $runger_config_last_memoized_at && $runger_config_last_memoized_at >= 1.second.ago
        memoize_settings_from_redis
      end
      instance_variable_get("@#{config_key}")
    end

    define_method("#{config_key}?") do
      public_send(config_key).present?
    end
  end

  def memoize_settings_from_redis
    $runger_config_last_memoized_at = Time.current
    CONFIG_KEYS.each do |config_key|
      instance_variable_set("@#{config_key}", setting_in_redis(config_key))
    end
  end

  def setting_in_redis(setting_name)
    JSON($runger_redis.get(setting_name) || "null")
  end

  def set_in_redis(key, value, clear_memo: false)
    $runger_redis.set(key, JSON.dump(value))
    if clear_memo
      $runger_config_last_memoized_at = nil
    end
    true
  end

  def as_json
    CONFIG_KEYS.index_with do |key|
      setting(key)
    end
  end

  def setting(key)
    instance_variable_get("@#{key}")
  end

  def print_config
    max_key_length = CONFIG_KEYS.map(&:size).max
    CONFIG_KEYS.sort.map do |key|
      value = setting_in_redis(key)
      puts("#{AmazingPrint::Colors.yellow(key.ljust(max_key_length + 1))}: #{value.ai}")
    end
    nil
  end
end

module Runger
  class << self
    def config
      @config ||= Runger::RungerConfig.instance
    end

    def print_caller
      Runger.log_puts(
        Runger.commonlit_stack_trace_lines_until_logging.map { AmazingPrint::Colors.yellow(_1) },
      )
    end

    def print_verbose_caller
      Runger.log_puts(
        Runger.caller_lines_until_logging.map { AmazingPrint::Colors.yellow(_1) },
      )
    end
  end
end

def show_runger_config
  Runger.config.print_config
end

Runger::RungerConfig::CONFIG_KEYS.each do |runger_config_key|
  define_method("#{runger_config_key}!") do |value = true, quiet: false, silent: false|
    Runger.config.set_in_redis(runger_config_key, value)
    unless quiet || silent
      show_runger_config
    end
    true
  end

  define_method("un#{runger_config_key}!") do
    Runger.config.set_in_redis(runger_config_key, false)
    show_runger_config
    true
  end

  define_method("with_#{runger_config_key}!") do |&block|
    original_value = Runger.config.setting_in_redis(runger_config_key)
    Runger.config.set_in_redis(runger_config_key, true, clear_memo: true)

    block.call
  ensure
    Runger.config.set_in_redis(runger_config_key, original_value, clear_memo: true)
  end
end

if defined?(RSpec)
  show_code_coverage =
    ENV["SIMPLECOV_TARGET_FILE"].present? ||
    (
      Runger.config.code_coverage? &&
        RSpec.configuration.files_to_run.one? &&
        !RSpec.configuration.files_to_run.first.include?("spec/system/")
    )

  if show_code_coverage
    require_relative "#{Dir.home}/code/dotfiles/utils/ruby/load_gem.rb"

    if !defined?(SimpleCov)
      load_gem "simplecov"
    end

    if !defined?(SimpleCov::Formatter::Terminal)
      load_gem("simple_cov-formatter-terminal", load_path_only: true)
      require "simple_cov/formatter/terminal"
    end

    FileUtils.rm_rf("./coverage") # https://github.com/simplecov-ruby/simplecov/issues/ 389

    SimpleCov.formatter = SimpleCov::Formatter::Terminal
    SimpleCov::Formatter::Terminal.config.spec_to_app_file_map.merge!(
      %r{\Aspec/(cops|datamigrate)/} => 'lib/\1/',
      %r{\Aspec/requests/} => "app/controllers/",
      %r{
        \Aspec/
        (
        controllers|
        decorators|
        events|
        forms|
        helpers|
        inputs|
        integration_clients|
        mailers|
        models|
        parsers|
        presenters|
        queries|
        serializers|
        services|
        validators|
        workers
        )
        /
      }x => 'app/\1/',
    )

    SimpleCov.start
  end

  # https://github.com/simplecov-ruby/simplecov/issues/ 389
  module RungerObjectLoadPatch
    def load(file, **kwargs)
      if caller.any?(%r{/spec/})
        coverage_target =
          ENV["SIMPLECOV_TARGET_FILE"].presence || RSpec.configuration.files_to_run.first

        if coverage_target.present? && file.to_s.include?(coverage_target)
          SimpleCov.result
          SimpleCov.start do
            command_name("RungerObjectLoadPatch-#{SecureRandom.alphanumeric(5)}")
          end
        end
      end

      super(file, **kwargs)
    end
  end

  if !defined?(Rails::Console)
    RSpec.configure do |config|
      # Allow focusing RSpec test(s) using `fit`, `fdescribe`, and `fcontext`.
      config.filter_run_when_matching(:focus)

      config.before(:all) do
        if show_code_coverage && !Object.ancestors.include?(RungerObjectLoadPatch)
          Object.prepend(RungerObjectLoadPatch)
        end
      end

      config.before(:each) do |example|
        Rails.logger.info("@@@: #{example.full_description}")
      end

      config.before(:each, type: :system, js: true) do
        if Runger.config.headful_browser? || Runger.config.walk_through_system_specs?
          ENV["NO_HEADLESS"] = "true"
        else
          ENV.delete("NO_HEADLESS")
        end
      end
    end
  end
end

ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, start, finish, _id, payload|
  $runger_query_count ||= 0
  $runger_query_count += 1

  sql = payload[:sql]

  if sql.match?(/\bpg_/)
    next
  end

  log_expensive_queries = Runger.config.log_expensive_queries? && defined?(Rails::Server)
  log_ar_trace = Runger.config.log_ar_trace?
  log_verbose_ar_trace = Runger.config.log_verbose_ar_trace?

  if log_expensive_queries || log_ar_trace || log_verbose_ar_trace
    commonlit_caller_lines =
      caller.select { |filename| filename.include?("/commonlit/") }.presence || caller
    commonlit_caller_lines_until_logging =
      commonlit_caller_lines.
        take_while { |line| line.exclude?("config/initializers/z.rb") }.
        presence || commonlit_caller_lines
  end

  if log_expensive_queries
    time = finish - start
    $runger_expensive_queries ||= {}
    $runger_expensive_queries[time] = [
      "#{sql} #{payload[:binds].map { |b| [b.name, b.value] }}",
      commonlit_caller_lines_until_logging,
    ]
  end

  if (log_ar_trace || log_verbose_ar_trace) && !defined?(Rails::Console)
    Runger.log_puts(AmazingPrint::Colors.blue(sql))
    Runger.log_puts(AmazingPrint::Colors.yellow(<<~MESSAGE.squish))
      ^^^ (took
      #{AmazingPrint::Colors.red((finish - start).round(3).to_s)}
      sec)
      --
      #{AmazingPrint::Colors.green("query # #{$runger_query_count}")}
    MESSAGE
    log_verbose_ar_trace ? Runger.print_verbose_caller : Runger.print_caller
    Runger.log_puts
  end
end

ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
  unless Runger.config.log_expensive_queries?
    next
  end

  payload = args.extract_options!

  controller_name = payload[:controller]
  if controller_name == "AnonymousController" # this occurs in tests
    next
  end

  puts("\nMost expensive queries:")
  $runger_expensive_queries.sort.last(3).each do |time, (query, backtrace)|
    puts("#{AmazingPrint::Colors.red(time.round(3).to_s)} seconds")
    puts(AmazingPrint::Colors.blue(query))
    puts(backtrace.map { AmazingPrint::Colors.yellow(_1) })
    puts
  end

  $runger_expensive_queries = {}
end

if (Rails.env.development? || Rails.env.test?) && ENV["QUIET_AR"] == "1"
  if ENV["RAILS_LOG_TO_STDOUT"] == "1"
    ActiveRecord::Base.logger = ActiveSupport::Logger.new("log/development.log")
  else
    ActiveRecord::Base.logger = ActiveSupport::Logger.new("/dev/null")
  end
end

if Rails.env.development? && Runger.config.log_to_stdout?
  Rails.logger =
    ActiveSupport::Logger.new($stdout).
      tap { |logger| logger.formatter = ActiveSupport::Logger::SimpleFormatter.new }
end

# write ActiveRecord queries and other Rails logs in Sidekiq process to stdout in development
if Rails.env.development? && $PROGRAM_NAME.include?("sidekiq")
  puts("Logging to $stdout for Rails and ActiveRecord in Sidekiq process.")

  Rails.logger =
    ActiveSupport::Logger.new($stdout).
      tap { |logger| logger.formatter = ActiveSupport::Logger::SimpleFormatter.new }

  ActiveRecord::Base.logger =
    ActiveSupport::Logger.new($stdout).
      tap { |logger| logger.formatter = ActiveSupport::Logger::SimpleFormatter.new }

  puts("Improving Sidekiq logging.")

  require "sidekiq/logger"
  require "sidekiq/job_logger"

  module RungerSidekiqLoggerPatches
    def info(message = "")
      color =
        case message
        when "start" then :yellow
        when "done" then :green
        when "fail" then :red
        else :whiteish
        end

      if message == "start"
        puts(
          AmazingPrint::Colors.public_send(
            color,
            (pattern = " ▿ ") * (Integer(`tput cols`.rstrip) / pattern.size),
          ),
        )
      end

      super(AmazingPrint::Colors.public_send(color, message))

      if message == "done"
        puts(
          AmazingPrint::Colors.public_send(
            color,
            "#{(pattern = ' ▵ ') * (Integer(`tput cols`.rstrip) / pattern.size)}\n\n",
          ),
        )
      end

      if message == "fail"
        Thread.new do
          # Give some time for exception to be printed.
          sleep(0.1)

          puts(
            AmazingPrint::Colors.public_send(
              color,
              "#{(pattern = ' ! ') * (Integer(`tput cols`.rstrip) / pattern.size)}\n\n",
            ),
          )
        end
      end
    end
  end

  module SidekiqExt; end

  class SidekiqExt::JobLogger < Sidekiq::JobLogger
    # This is basically copy-pasted from the Sidekiq source code, but we are adding
    # `:queue` and `:args` to `Sidekiq::Context` so that they'll be logged.
    def call(item, queue)
      start = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      Sidekiq::Context.add(:queue, queue)
      json = JSON.dump(item["args"])
      Sidekiq::Context.add(
        :args,
        AmazingPrint::Colors.cyan(json.size <= 140 ? json : "#{json[0...140]}...]"),
      )
      @logger.info("start")

      yield

      Sidekiq::Context.add(:elapsed, elapsed(start))
      @logger.info("done")
      # rubocop:disable Lint/RescueException
      # This is what the Sidekiq source code does, so we'll do it here, too.
    rescue Exception
      # rubocop:enable Lint/RescueException
      Sidekiq::Context.add(:elapsed, elapsed(start))
      @logger.info("fail")

      raise
    end
  end

  Sidekiq.configure_server do |config|
    if ENV["REDIS_DATABASE_NUMBER"] == "3"
      config.logger = nil
    else
      Sidekiq::Logger.prepend(RungerSidekiqLoggerPatches)
      config[:job_logger] = SidekiqExt::JobLogger
    end
  end
end

def quiet_ar
  original_logger = ActiveRecord::Base.logger

  ActiveRecord::Base.logger = ActiveSupport::Logger.new("/dev/null")

  yield
ensure
  ActiveRecord::Base.logger = original_logger
end

def ar_model_classes
  ApplicationRecord.
    descendants.
    sort_by { |klass| klass.descendants.size }.
    uniq(&:table_name).
    sort_by(&:table_name)
end

# [c]apturing [a]ctive[r]ecord [l]ogs
def carl
  original_logger = ActiveRecord::Base.logger

  string_io = StringIO.new

  ActiveRecord::Base.logger =
    ActiveSupport::Logger.new(string_io).tap do |logger|
      logger.formatter = ActiveSupport::Logger::SimpleFormatter.new
    end

  result =
    begin
      yield
    # Rescue bc. we might want a query for a record not in the local DB.
    rescue StandardError => exception
      puts("This exception was rescued:")
      ap(exception)

      nil
    end

  # Force an un-materialized relation to make a query.
  if result.is_a?(ActiveRecord::Relation)
    result.to_a
  end

  string_io.rewind
  string_io.
    read.
    uncolor.
    split("\n").
    reject { |string| string.include?("↳") }.
    last.
    strip.
    cpp
  system({ "BAT_PAGER" => "cat" }, "fsc", exception: true)

  true
ensure
  ActiveRecord::Base.logger = original_logger
end

# [j]son [p]arse [f]ile
def jpf(path)
  JSON.parse(File.read(path))
end

# [b]ench[m]ark [m]easure
def bmm
  result = nil

  time =
    Benchmark.measure do
      result = yield
    end.real

  puts(<<~LOG.squish)
    #{AmazingPrint::Colors.cyan('BENCHMARK TIME:')}
    Took
    #{AmazingPrint::Colors.purple('%.3f' % time.round(3))}
    seconds.
  LOG

  result
end

def d
  system("clear")
end

# password copy
def pc
  ENV.fetch("USER_PASSWORD").cpp
end

module RungerTimePatches
  def et
    in_time_zone("America/New_York")
  end

  def ct
    in_time_zone("America/Chicago")
  end

  def pt
    in_time_zone("America/Los_Angeles")
  end
end
Time.prepend(RungerTimePatches)
ActiveSupport::TimeWithZone.prepend(RungerTimePatches)

load("#{Dir.home}/code/commonlit/app/models/application_record.rb")
load("#{Dir.home}/code/commonlit/app/models/person.rb")
class Person
  # [up]date [p]assword
  def upp
    active_user.upp
  end
end

load("#{Dir.home}/code/commonlit/app/models/school_district.rb")
class SchoolDistrict
  def users
    ap("Acknowledge by pressing 'Enter' that this method is not available in the codebase.")
    gets

    User.
      where(id: __district_admins).
      or(User.where(id: __teachers)).
      or(User.where(id: __students))
  end

  private

  def __district_admins
    User.joins(:district_memberships).merge(district_memberships).distinct
  end

  def __teachers
    User.joins(:faculty_memberships).merge(faculty_memberships).distinct
  end

  def __students
    User.
      joins(roster_members: { roster: { primary_faculty_membership: :school } }).
      where(schools: { school_district_id: self }).
      distinct
  end
end

load("#{Dir.home}/code/commonlit/app/models/user.rb")
class User
  # Log in the user, which we used to do by [up]dating their [p]assword.
  def upp
    current_user!(email || user_name)
  end
end

# [s]tudent user that is [me]
def sme
  User.find_by!(user_name: ENV.fetch("MY_STUDENT_USER_NAME"))
end

# [t]eacher user that is [me]
def tme
  User.find_by!(user_name: ENV.fetch("MY_TEACHER_USER_NAME"))
end

def ube(id_or_email_or_username)
  if id_or_email_or_username.is_a?(Numeric) || id_or_email_or_username.match?(/\A\d+\z/)
    User.find(Integer(id_or_email_or_username))
  elsif id_or_email_or_username.include?("@")
    User.find_by!(email: id_or_email_or_username)
  else
    User.find_by!(user_name: id_or_email_or_username)
  end
end

# [f]uzzy-find a [u]ser
def fu(recent_login_only: true)
  user_relation = User.select("COALESCE(email, user_name) AS login").reorder("login")

  if recent_login_only
    user_relation = user_relation.where(current_sign_in_at: 1.year.ago..)
  end

  user_logins = quiet_ar { user_relation.map { _1["login"] } }

  if (selected_login = fzf(user_logins))
    ube(selected_login)
  end
end

# [s]et current_[u]ser
def su
  if (selected_login = (user = fu)&.email || user&.user_name)
    Runger.config.current_user!(selected_login)
  else
    show_runger_config
  end
end

# Set the [c]urrent [u]ser[!]
def cu!(...)
  current_user!(...)
end

# [c]urrent [u]ser
def cu
  ube(Runger.config.current_user)
end

# [s]et current_[a]dmin_[u]ser
def sau
  admin_emails =
    quiet_ar do
      AdminUser.
        where(current_sign_in_at: 1.year.ago..).
        reorder(:email).
        pluck(:email)
    end

  if (selected_email = fzf(admin_emails))
    Runger.config.current_admin_user!(selected_email)
  else
    show_runger_config
  end
end

def fbs
  # rubocop:disable Style/MixinUsage
  include FactoryBot::Syntax::Methods
  # rubocop:enable Style/MixinUsage
end

def lr
  load("./personal/runner.rb")
end

if Rails.env.test? && !defined?(Rails::Console)
  # Don't print full details about ActiveRecord objects if really long.
  class ActiveRecord::Base
    module RungerPatches
      def inspect
        original = super
        original.size > 50 ? "#{self.class.name}:#{id}" : original
      end
    end
    prepend RungerPatches
  end

  # For failed tests, print slashes (rather than spaces) between RSpec's joined-together
  # describe/context/it strings.
  class RSpec::Core::Metadata::HashPopulator
    module RungerPatches
      private

      def description_separator(parent_part, child_part)
        if parent_part.is_a?(Module) && child_part.to_s =~ /^(#|::|\.)/
          ""
        else
          " / "
        end
      end
    end
    prepend RungerPatches
  end
end

# Print Sentry messages to the terminal
module RungerSentryPatches
  def capture_exception(exception, **options)
    handled_display =
      if caller.any? { _1.match?(/\bswitch_locale\b/) }
        handled_from = caller(1..1).first
        AmazingPrint::Colors.greenish("handled")
      else
        AmazingPrint::Colors.redish("unhandled")
      end
    Runger.log_puts(<<~LOG.squish)
      #{AmazingPrint::Colors.yellowish('[Sentry captured')}
      #{handled_display}
      #{AmazingPrint::Colors.yellowish('exception]')}
      #{handled_from && AmazingPrint::Colors.cyanish("(handled from #{handled_from})")}
    LOG
    Runger.log_puts(AmazingPrint::Colors.red("#{exception.class}: #{exception.message}"))

    backtrace_to_print =
      if Runger.config.verbose_trace?
        exception.backtrace
      else
        Runger.commonlit_stack_trace_lines_until_logging(exception.backtrace)
      end

    Runger.log_puts(backtrace_to_print.map { AmazingPrint::Colors.yellow(_1) })

    if (extra = options[:extra])
      Runger.log_puts_yellowish("[extra Sentry captured data]")
      Runger.log_ap(extra)
    end

    super
  end

  def capture_message(message)
    Runger.log_puts(AmazingPrint::Colors.red("[Sentry captured message] #{message}"))

    super
  end
end
if Rails.env.development? || Rails.env.test?
  Sentry.singleton_class.prepend(RungerSentryPatches)
end

class Runger::LogFormatter < Lograge::Formatters::KeyValue
  # rubocop:disable Lint/MissingSuper
  def initialize(data)
    controller = data.delete(:controller) # e.g. 'Api::LogEntriesController'
    action = data.delete(:action) # e.g. 'index'

    # convert to 'api/log_entries_controller.rb@index'
    data[:action] = "[ #{controller.underscore}.rb@#{action} ]"

    @data =
      data.
        sort_by.
        with_index do |(key, _value), index|
          case key
          when :path then 0
          when :method then 1
          when :action then 2
          else index
          end
        end.to_h
  end
  # rubocop:enable Lint/MissingSuper

  def call
    log_message = super(@data)

    if Rails.env.in?(%w[development test])
      log_message = AmazingPrint::Colors.red(log_message)

      if !File.exist?(Rails.root.join("lib/rack/response_end_logger.rb"))
        log_message << "\n\n"
      end
    end

    log_message
  end
end

# we have a low enough volume of requests that without `STDOUT.sync = true` there is a notable delay
# in logs being written (due to log buffering); set this value so that logs are written in real time
$stdout.sync = true

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = ->(data) { Runger::LogFormatter.new(data).call }
end

module Runger
  def caller_lines_until_logging
    caller.reject { |line| line.include?("config/initializers/z.rb") }
  end

  def commonlit_stack_trace_lines_until_logging(stack_trace = caller)
    commonlit_stack_trace_lines =
      stack_trace.select { |filename| filename.include?("/commonlit/") }.presence || stack_trace

    commonlit_stack_trace_lines.
      reject { |line| line.include?("config/initializers/z.rb") }.
      presence || commonlit_stack_trace_lines
  end

  def log_puts(object = nil)
    write_log(string_for(:puts, object))
  end

  AmazingPrint::Colors.methods(false).each do |color|
    define_method("log_puts_#{color}") do |object = nil|
      write_log(AmazingPrint::Colors.public_send(color, string_for(:puts, object)))
    end
  end

  def log_ap(object)
    write_log(string_for(:ap, object))
  end

  def string_for(method_name, object)
    string_io = StringIO.new
    string_io.send(method_name, object)
    string_io.rewind
    string_io.read.rstrip
  end

  def write_log(message)
    pairs =
      if ::Rails.env.test?
        if ::Rails.logger.respond_to?(:clear_tags!)
          ::Rails.logger.clear_tags!
        end
        [[::Rails.logger, :info]].tap do |pair_list|
          if Runger.config.log_to_stdout?
            pair_list << [self, :puts]
          end
        end
      else
        [[self, :puts]]
      end

    pairs.each do |(recipient, write_method)|
      recipient.send(write_method, message)
    end

    nil
  end

  extend self
end

if ENV.key?("RUNGER_DEBUG_EXCON")
  class ExconToRailsInstrumentor
    KEYS_TO_IGNORE = %i[
      ciphers
      connection
      cookies
      middlewares
      retry_errors
      stack
    ].freeze
    INTERESTING_HEADERS = %i[
      headers
      host
      path
      method
      status
      body
    ].freeze

    def self.instrument(name, datum, &block)
      namespace, *event = name.split(".")
      rails_name = [event, namespace].flatten.join(".")
      ActiveSupport::Notifications.instrument(rails_name, datum, &block)
    end
  end

  ActiveSupport::Notifications.
    subscribe(/excon/) do |event_name, _start_at, _end_at, _some_string, params|
      if caller.any? { _1.include?("/webmock/") }
        next
      end

      Runger.log_puts
      Runger.log_puts(AmazingPrint::Colors.green("~~~ #{event_name.upcase} ~~~"))
      neatened_params =
        params.
          except(*ExconToRailsInstrumentor::KEYS_TO_IGNORE).
          select do |key, _value|
            ExconToRailsInstrumentor::INTERESTING_HEADERS.include?(key)
          end.
          sort_by do |key, _value|
            [
              ExconToRailsInstrumentor::INTERESTING_HEADERS.index(key) || -1,
              key,
            ]
          end.to_h.map do |key, value|
            unless key == :body
              next [key, value]
            end

            if MIME::Types[params[:headers]["Content-Type"]].first&.simplified == "application/json"
              [key, JSON.parse(value)]
            else
              [key, value]
            end
          end.to_h
      Runger.log_ap(neatened_params)

      if event_name == "request.excon"
        Runger.log_puts(AmazingPrint::Colors.yellow("^^^"))
        Runger.print_caller
      end

      Runger.log_puts
    end

  module RungerExconConnectionPatches
    def initialize(...)
      super

      @data[:instrumentor] = ExconToRailsInstrumentor
    end
  end
  if !Excon::Connection.ancestors.include?(RungerExconConnectionPatches)
    Excon::Connection.prepend(RungerExconConnectionPatches)
  end
end

if defined?(Rails::Console)
  module RungerIrbConfPatches
    formatted_env =
      if ENV["COMMONLIT_NAMESPACE"].present?
        fail("Why are you running z.rb when COMMONLIT_NAMESPACE is present?")
      elsif ENV["DEVELOPMENT_DATABASE_URL"].present?
        "dev #{AmazingPrint::Colors.red('REMOTE DB')}"
      elsif Rails.env.development?
        "dev"
      else
        Rails.env
      end

    endpoint_name = ActiveRecord::Base.connection_db_config.host.to_s.split(".").first || "unknown"
    db_endpoint =
      if endpoint_name.include?("production-")
        fail("Why are you running z.rb when connecting to a production database?")
      elsif endpoint_name == "localhost"
        "local"
      else
        AmazingPrint::Colors.cyan(endpoint_name)
      end

    prompt = "[#{formatted_env}][DB:#{db_endpoint}]:%n"

    # rubocop:disable Style/MutableConstant
    PROMPT_CONFIG = {
      RAILS: {
        PROMPT_I: "#{prompt}> ",
        PROMPT_N: "#{prompt}> ",
        PROMPT_S: "#{prompt}%l ",
        PROMPT_C: "#{prompt}* ",
        RETURN: "[overridden in irbrc.rb]",
      }.freeze,
    }
    # rubocop:enable Style/MutableConstant

    # Prevent changes to the config.
    def PROMPT_CONFIG.[]=(key, value)
      # noop
    end

    PROMPT_CONFIG.freeze

    # Ensure that we always return our unmodifiable PROMPT_CONFIG for `IRB.conf[:PROMPT]`.
    def [](key)
      if key == :PROMPT
        PROMPT_CONFIG
      else
        super
      end
    end
  end
  IRB.conf.singleton_class.prepend(RungerIrbConfPatches)

  def save_history!
    IRB.conf[:MAIN_CONTEXT].instance_variable_get(:@io).save_history
  end
end

module RungerApplicationControllerPatches
  def authenticate_admin_user!
    if !Runger.config.current_admin_user
      super
    end
  end

  def current_admin_user
    if Rails.env.development?
      super_current_admin_user = super
      config_admin_user_email = Runger.config.current_admin_user

      if config_admin_user_email.blank?
        super_current_admin_user
      else
        RequestStore.fetch("runger:current_admin_user_by_config") do
          AdminUser.find_by!(email: config_admin_user_email).tap do |admin_user_by_config|
            if admin_user_by_config != super_current_admin_user
              sign_in(admin_user_by_config)
            end
          end
        end
      end
    else
      super
    end
  end

  def current_user
    if Rails.env.development?
      super_current_user = super
      config_user_identifier = Runger.config.current_user

      if config_user_identifier.blank?
        super_current_user
      else
        RequestStore.fetch("runger:current_user_by_config") do
          ube(config_user_identifier).tap do |user_by_config|
            if user_by_config.present? && user_by_config != super_current_user
              sign_in(user_by_config)
            end
          end
        end
      end
    else
      super
    end
  end

  def redirect_to(*args, **kwargs)
    Runger.log_puts(AmazingPrint::Colors.purple("Redirecting to: #{args.first} #{kwargs}"))
    Runger.print_caller
    super
  end

  def sign_in(*args)
    record = args.detect { |arg| arg.respond_to?(:email) }
    Runger.log_puts(AmazingPrint::Colors.purple("Signing in #{record.class.name} #{record.email || record.user_name}"))
    Runger.print_caller
    super
  end
end

$runger_patch_application_controller = lambda do |application_controller|
  application_controller.prepend_before_action(-> { $runger_query_count = 0 })
end

Rails.application.config.after_initialize do
  ApplicationController.prepend(RungerApplicationControllerPatches)
  $runger_patch_application_controller.call(ApplicationController)

  if defined?(StudentDiagnostic)
    class StudentDiagnostic < ApplicationRecord
      def summary
        diagnostic_sequence = diagnostic_lesson_template.diagnostic_sequence
        diagnostic = diagnostic_sequence.diagnostic

        <<~SUMMARY.squish
          #{diagnostic_lesson_template.assessment_type}
          -
          #{diagnostic_sequence.series_type}
          -
          grade #{diagnostic.grade_level}
          -
          #{student.active_user.user_name}
        SUMMARY
      end
    end
  end
end

module Commonlit
  class Application < Rails::Application
    config.to_prepare do
      $runger_patch_application_controller.call(ApplicationController)
    end
  end
end

module RungerPaperclipPatches
  def url(...)
    if (super_value = super).match?(%r{\A/system/\w+/images/\d+|\.(jpe?g|png)(\?\d+)?\z}i)
      "/images/commonlit_library_logo.png"
    else
      super_value
    end
  end
end
Paperclip::Attachment.prepend(RungerPaperclipPatches)

module RungerCapybaraSessionPatches
  # Invoke this via `save_and_open_page`.
  def save_page(...)
    super(...).tap do |html_path|
      html = File.read(html_path)
      File.write(
        html_path,
        html.
          sub(
            <<~HTML,
              <head>
            HTML
            <<~HTML,
              <head>
              <base href="http://localhost:3000/">
            HTML
          ),
      )
    end
  end
end
Capybara::Session.prepend(RungerCapybaraSessionPatches) if Rails.env.test?

module RungerActiveKmsPatches
  def decryption_keys(encrypted_message)
    if encrypted_message.headers.encrypted_data_key_id != key_id_header
      return []
    end

    encrypted_data_key = encrypted_message.headers.encrypted_data_key
    data_key =
      ActiveSupport::Notifications.instrument("decrypt.active_kms") do
        decrypt(key_id, encrypted_data_key)
      end
    [ActiveRecord::Encryption::Key.new(data_key)]
  end
end

class RungerDatabaseStateSaver
  DB_VIEWS = %w[
    clever_districts_matching_school_district_by_lea_ids
    roster_teachers
    activity_display_permutations
    classlink_school_merge_candidates
    clever_school_merge_candidates
  ].map(&:freeze).freeze
  TABLES_TO_SKIP = %w[
    texts
    references
    activities
    activity_questions
    question_answer_options
    questions
    answer_options
    audio_lines
    excerpts
  ].map(&:freeze).freeze

  def save
    Rails.application.eager_load!
    save_database_state
    Runger.log_ap("Done.")
  end

  private

  attr_reader :temp_location

  def save_database_state
    if Rails.env.development? && !ActiveKms::BaseKeyProvider.ancestors.include?(RungerActiveKmsPatches)
      ActiveKms::BaseKeyProvider.prepend(RungerActiveKmsPatches)
    end

    directory = "tmp/database_states/#{Time.current.iso8601}"
    FileUtils.mkdir_p(directory)

    ar_model_classes.
      each do |model_class|
        puts("MODEL CLASS: #{model_class}.")

        hashes =
          begin
            if (skip_reason = skip_reason(model_class))
              [{ "id" => nil, skip_reason => true }]
            else
              model_class.find_each.map(&:attributes)
            end
          rescue StandardError => exception
            [{ "id" => nil, exception.class.to_s => true }]
          end

        file_path = File.join(directory, "#{model_class.table_name}.json")
        File.open(file_path, "w") do |file|
          file.puts(hashes.to_json)
        end
      end
  end

  def skip_reason(model_class)
    if model_class.to_s.start_with?("Backup")
      "It starts with 'Backup'."
    elsif (table_name = model_class.table_name).in?(DB_VIEWS)
      "It's a database view."
    elsif table_name.in?(TABLES_TO_SKIP)
      "It's a table to skip."
    end
  end
end

if Rails.env.test? && Runger.config.walk_through_system_specs?
  module Capybara
    module DSL
      Session::DSL_METHODS.each do |method|
        class_eval <<~METHOD, __FILE__, __LINE__ + 1
          def #{method}(*args, **kwargs, &block)
            p(["#{method}", args, kwargs])
            puts("Hit enter.")
            if !$stop_skipping_at || (Time.now >= $stop_skipping_at)
              if $stdin.gets.rstrip == "s"
                skip!
              end
            end
            page.method("#{method}").call(*args, **kwargs, &block)
          end
        METHOD
      end
    end
  end
end

module RungerSprocketsPatches
  def javascript_include_tag(*sources)
    if sources[0] == "/statusPageV2.js"
      ""
    else
      super
    end
  end
end
Sprockets::Rails::Helper.prepend(RungerSprocketsPatches)

if Rails.env.development?
  # This monkeypatch makes it easy to restore the DB w/ `dbrest` without having to
  # shut down and then restart all running Rails processes.
  # Inspired by https://github.com/dafalcon/pgreset.
  class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
    private

    def exec_no_cache(sql, name, binds, async:, allow_retry:, materialize_transactions:)
      retries ||= 0
      mark_transaction_written_if_write(sql)

      # make sure we carry over any changes to ActiveRecord.default_timezone that have been
      # made since we established the connection
      update_typemap_for_default_timezone

      type_casted_binds = type_casted_binds(binds)
      log(sql, name, binds, type_casted_binds, async:) do
        with_raw_connection do |conn|
          result = conn.exec_params(sql, type_casted_binds)
          verified!
          result
        end
      end
    rescue ActiveRecord::ConnectionFailed, ActiveRecord::NoDatabaseError
      retries += 1

      if retries <= 10
        $stdout.puts("DB connection failed. Re-establishing...")
        sleep(0.08)
        ActiveRecord::Base.establish_connection
        retry
      end
    end
  end

  # Silence the above method in backtraces, so that not every query is
  # attributed to it.
  Rails.backtrace_cleaner.add_silencer { |line| line =~ /exec_no_cache/ }
end
