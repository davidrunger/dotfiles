class LoadRunner
  include Sidekiq::Worker

  # This doesn't affect anything when enqueueing the job via Sidekiq::Client.
  # `retry: false` must be specified in the Sidekiq::Client invocation.
  sidekiq_options retry: false

  def perform
    system("clear", exception: true)
    load(Rails.root.join("personal/runner.rb"))
  end
end
