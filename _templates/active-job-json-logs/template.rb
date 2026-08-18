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
  # `Performing…` / `Performed…` output entirely. Arguments are rendered by
  # `JobArgumentLogging` so records become GlobalIDs and sensitive hash keys
  # become `[FILTERED]` before they reach the line.

  # Renders an Active Job argument list for the log line.
  #
  # `perform.active_job` fires after deserialization, so arguments arrive as
  # live objects — an Active Record instance handed straight to `to_json`
  # renders its whole attribute set (`email`, `password_digest`, …). Records
  # therefore have to be reduced to GlobalIDs at *every* depth, not just at
  # the top level: `ActionMailer::MailDeliveryJob` nests its record argument
  # inside a Hash (`{args: [user], params: nil}`), so a top-level-only pass
  # leaks the whole user row on every `deliver_later`. Any job taking a hash
  # or array of records has the same hole.
  #
  # `globalize` walks the structure first so no record survives to the
  # `filter` pass, then `filter` applies `config.filter_parameters` to what
  # remains — the same redaction controllers get on their params.
  module JobArgumentLogging
    module_function

    def render(arguments)
      filter.filter(args: globalize(Array(arguments)))[:args]
    end

    def globalize(value)
      case value
      when Hash then value.transform_values { globalize(_1) }
      when Array then value.map { globalize(_1) }
      else value.respond_to?(:to_global_id) ? value.to_global_id.to_s : value
      end
    end

    # Built once: `config.filter_parameters` compiles every configured
    # pattern, and this runs on every job execution.
    def filter
      @filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end
  end

  ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    job = event.payload[:job]
    err = event.payload[:exception_object]

    fields = {
      event:         "job.perform",
      job:           job.class.name,
      queue:         job.queue_name,
      attempt:       job.executions,
      job_id:        job.job_id,
      request_id:    (Current.request_id if defined?(Current) && Current.respond_to?(:request_id)),
      args:          JobArgumentLogging.render(job.arguments).presence,
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
