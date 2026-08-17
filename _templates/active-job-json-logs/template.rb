#!/usr/bin/env ruby

# ActiveJob JSON Logs Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/active-job-json-logs/template
# Usage: rails app:template LOCATION=https://railstemplates.org/active-job-json-logs/template

say "railstemplates.org"
say "🧾 Configuring ActiveJob JSON logs...", :green

if File.exist?("config/initializers/active_job_logging.rb")
  say "ActiveJob logging initializer already present, skipping.", :yellow
  return
end

initializer_body = <<~'RUBY'
  # One JSON line per Active Job execution, replacing Rails' default
  # `Performing…` / `Performed…` output entirely. Argument records are
  # emitted as GlobalIDs; hash args funnel through filter_parameters.

  ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    job = event.payload[:job]
    err = event.payload[:exception_object]

    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    serialized_args = Array(job.arguments).map do |arg|
      if arg.respond_to?(:to_global_id)
        arg.to_global_id.to_s
      elsif arg.is_a?(Hash)
        filter.filter(arg)
      else
        arg
      end
    end

    fields = {
      event:         "job.perform",
      job:           job.class.name,
      queue:         job.queue_name,
      attempt:       job.executions,
      job_id:        job.job_id,
      request_id:    (Current.request_id if defined?(Current) && Current.respond_to?(:request_id)),
      args:          serialized_args.presence,
      duration_ms:   event.duration.to_i,
      status:        err ? "error" : "ok",
      error_class:   err&.class&.name,
      # Optional. Drop the line if not on SolidQueue.
      ready_backlog: (SolidQueue::ReadyExecution.count rescue nil)
    }.compact

    Rails.logger.info(fields.to_json)
  end

  # Neutralise ActiveJob's `[ActiveJob] [JobClass] [job_id]` TaggedLogging
  # prefix on every line the job emits. The same context is already in
  # the subscriber line as `job` and `job_id` fields.
  module ActiveJobNoTagging
    private def tag_logger(*_tags, &block) = block.call
  end

  if Rails.env.production? || Rails.env.staging?
    Rails.application.config.after_initialize do
      require "active_job/log_subscriber"
      # Detach the multi-line `Performing…`/`Performed…` default subscriber.
      ActiveJob::LogSubscriber.detach_from(:active_job)
      ActiveJob::Base.prepend(ActiveJobNoTagging)
    end
  end
RUBY

create_file "config/initializers/active_job_logging.rb", initializer_body, skip: true

environments = ["production"]
environments << "staging" if File.exist?("config/environments/staging.rb")
say "✅ ActiveJob JSON logging configured for #{environments.join(" and ")}.", :green
say "Dev/test continue using Rails' default ActiveJob logger.", :blue
