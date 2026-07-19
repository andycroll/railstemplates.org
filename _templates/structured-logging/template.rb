#!/usr/bin/env ruby

# Structured Logging Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/structured-logging/template
# Usage: rails app:template LOCATION=https://railstemplates.org/structured-logging/template

say "railstemplates.org"
say "🪵 Configuring structured JSON logging...", :green

if File.exist?("config/initializers/structured_logging.rb")
  say "Structured logging initializer already present, skipping.", :yellow
  return
end

after_bundle do
  initializer_body = <<~'RUBY'
    # Structured logging: one bare JSON object per line to STDOUT (journalctl)
    # and, when the `appsignal` gem is present, to AppSignal Logs too.
    #
    # This pairs with the lograge template
    # (https://railstemplates.org/lograge/template), which already emits one
    # JSON line per HTTP request. This file is COMPLEMENTARY: it composes the
    # broadcast logger those request lines flow through, plus subscribers that
    # turn NON-request events (Active Jobs, outgoing HTTP, `Rails.event`,
    # exceptions) into matching JSON lines. It does not re-configure lograge.
    #
    # Active in production (and staging, if that environment exists). Dev/test
    # keep Rails' default human-readable logger.

    if Rails.env.production? || Rails.env.staging?
      # Compose a JSON-lines logger, reconfiguring Rails.logger.
      #
      #   1. STDOUT logger gets a RAW formatter (no `I, [ts #pid] INFO -- :`
      #      prefix) so every line is a bare, valid JSON object straight to
      #      journalctl.
      #   2. If the `appsignal` gem is present, `Appsignal::Logger#broadcast_to`
      #      fans the same lines out to AppSignal Logs. This is NOT
      #      `ActiveSupport::BroadcastLogger`, which conflicts with
      #      TaggedLogging when one leg is an `Appsignal::Logger`. AppSignal's
      #      default `format: AUTODETECT` sniffs each line as JSON.
      #   3. `ActiveSupport::TaggedLogging.new(...)` so callers can still use
      #      `Rails.logger.tagged(...)`.
      #
      # `stdout.level` MUST be set explicitly. `Appsignal::Logger#add` writes to
      # broadcast targets BEFORE applying its own level filter, so
      # `config.log_level` only filters the AppSignal leg. Without an explicit
      # STDOUT level, `Logger.new` defaults to :debug and SolidQueue's polling
      # lines flood journalctl every poll cycle.
      log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
      raw_formatter = ->(_severity, _time, _progname, msg) { "#{msg}\n" }
      stdout_logger = Logger.new($stdout, level: log_level).tap { |l| l.formatter = raw_formatter }

      logger =
        if defined?(Appsignal::Logger)
          appsignal_logger = Appsignal::Logger.new("rails")
          appsignal_logger.broadcast_to(stdout_logger)
          appsignal_logger
        else
          stdout_logger
        end

      Rails.logger = ActiveSupport::TaggedLogging.new(logger)
    end

    # Parameter filter shared by the subscribers below. Routes sensitive values
    # (`:password`, `:token`, ...) through
    # `Rails.application.config.filter_parameters` so they become `[FILTERED]`
    # before they reach a log line.
    def structured_logging_param_filter
      @structured_logging_param_filter ||=
        ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end

    # 1. `perform.active_job` — one JSON line per Active Job execution with
    #    queue/attempt/duration/status and the serialized argument list.
    #    Argument records are emitted as GlobalIDs; hash args are funnelled
    #    through the parameter filter. `ready_backlog` is a cheap SolidQueue
    #    snapshot, guarded so apps without SolidQueue log cleanly.
    ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      job = event.payload[:job]
      err = event.payload[:exception_object]

      serialized_args = Array(job.arguments).map do |arg|
        if arg.respond_to?(:to_global_id)
          arg.to_global_id.to_s
        elsif arg.is_a?(Hash)
          structured_logging_param_filter.filter(arg)
        else
          arg
        end
      end

      request_id = defined?(Current) && Current.respond_to?(:request_id) ? Current.request_id : nil

      ready_backlog =
        begin
          defined?(SolidQueue::ReadyExecution) ? SolidQueue::ReadyExecution.count : nil
        rescue StandardError
          nil
        end

      fields = {
        event: "job.perform",
        job: job.class.name,
        queue: job.queue_name,
        attempt: job.executions,
        job_id: job.job_id,
        request_id: request_id,
        args: serialized_args.presence,
        duration_ms: event.duration.to_i,
        status: err ? "error" : "ok",
        error_class: err&.class&.name,
        ready_backlog: ready_backlog
      }.compact

      Rails.logger.info(fields.to_json)
    end

    # 2. `request.application_client` — one JSON line per outgoing external HTTP
    #    request from an `ApplicationClient`-derived client. A no-op in apps
    #    without an `ApplicationClient` (nothing instruments this event), but
    #    kept so the subscriber is ready the moment one is added. URL query
    #    strings, request bodies, and headers are intentionally NOT logged.
    ActiveSupport::Notifications.subscribe("request.application_client") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      err = event.payload[:exception_object]

      request_id = defined?(Current) && Current.respond_to?(:request_id) ? Current.request_id : nil

      fields = {
        event: "external_api.request",
        klass: event.payload[:klass],
        method: event.payload[:method],
        host: event.payload[:host],
        path: event.payload[:path],
        status: event.payload[:status],
        duration_ms: event.duration.to_i,
        attempt: event.payload[:attempt],
        request_id: request_id,
        error_class: err&.class&.name
      }.compact

      Rails.logger.info(fields.to_json)
    end

    # 3. `Rails.event` (Active Support's structured event reporter, Rails 8.1+)
    #    — bridges every `Rails.event.notify(name, **fields)` call from app code
    #    into a single flat JSON line. `Rails.event` auto-applies
    #    `Rails.application.config.filter_parameters` before this subscriber
    #    sees the payload.
    #
    #    `emit` early-returns for events in the Rails 8.1 framework
    #    `StructuredEventSubscriber` namespaces (`action_controller.*`,
    #    `active_job.*`, etc.). Those subscribers auto-attach at gem load and
    #    republish framework `ActiveSupport::Notifications` events through
    #    `Rails.event`; without the early-return, every HTTP request would emit
    #    duplicate `action_controller.*` lines alongside lograge's per-request
    #    line, every Active Storage op would emit `active_storage.*` lines, etc.
    #    Filtering inside the subscriber (rather than `detach_from`-ing the
    #    framework subscribers) leaves the `Rails.event` plumbing intact for any
    #    other consumer.
    if defined?(Rails.event) && Rails.event.respond_to?(:subscribe)
      class StructuredLoggingEventSubscriber
        RAILS_EVENT_NAMESPACES = %w[
          action_controller action_dispatch action_view action_mailer
          active_record active_storage active_job active_support
        ].freeze

        def emit(event)
          return if framework_event?(event)

          fields = {event: event[:name]}
          fields.merge!(event[:payload]) if event[:payload].is_a?(Hash)
          fields.merge!(event[:tags]) if event[:tags].is_a?(Hash) && event[:tags].any?
          fields.merge!(event[:context]) if event[:context].is_a?(Hash) && event[:context].any?
          fields[:source_location] = event[:source_location] if event[:source_location]
          Rails.logger.info(fields.to_json)
        end

        private

        def framework_event?(event)
          event[:name].to_s.split(".").first.in?(RAILS_EVENT_NAMESPACES)
        end
      end

      Rails.event.subscribe(StructuredLoggingEventSubscriber.new)
    end

    # 4. `DebugExceptionsJson` — one JSON line per unhandled exception (including
    #    `ActionController::RoutingError` for unmatched paths). Replaces the
    #    default multi-line `Class (message):` + annotated source + backtrace
    #    output, which breaks JSON parsing in log aggregators. Backtraces are
    #    still captured by error trackers (e.g. AppSignal Errors) via their own
    #    instrumentation.
    module StructuredLoggingDebugExceptionsJson
      def log_error(request, wrapper)
        Rails.logger.info({
          event: "request.exception",
          method: request.method,
          path: request.filtered_path,
          remote_ip: request.remote_ip,
          request_id: request.request_id,
          exception: wrapper.exception_class_name,
          message: wrapper.message,
          status: wrapper.status_code
        }.compact.to_json)
      end
    end

    # `ActiveJobNoTagging` — no-ops `ActiveJob::Base#tag_logger` so the
    # `[ActiveJob] [JobClass] [job_id]` TaggedLogging prefix doesn't precede the
    # `job.perform` JSON line above (the bracket prefix breaks JSON parsing).
    # The same context is already in the line as `job`/`job_id` fields.
    module StructuredLoggingActiveJobNoTagging
      private def tag_logger(*_tags, &block) = block.call
    end

    # Only rewire the framework's own subscribers in production. In production
    # we detach `ActiveJob::LogSubscriber` so jobs don't emit the classic
    # multi-line `Performing`/`Performed` output alongside our JSON line, and
    # prepend the two modules above.
    if Rails.env.production?
      Rails.application.config.after_initialize do
        require "active_job/log_subscriber"
        ActiveJob::LogSubscriber.detach_from(:active_job)
        ActiveJob::Base.prepend(StructuredLoggingActiveJobNoTagging)
        ActionDispatch::DebugExceptions.prepend(StructuredLoggingDebugExceptionsJson)
      end
    end
  RUBY

  create_file "config/initializers/structured_logging.rb", initializer_body, skip: true

  environments = ["production"]
  environments << "staging" if File.exist?("config/environments/staging.rb")
  say "✅ Structured JSON logging configured for #{environments.join(" and ")}.", :green
  say "Pairs with the lograge template for per-request JSON lines.", :blue
  say "Dev/test continue using Rails' default logger.", :blue
end
