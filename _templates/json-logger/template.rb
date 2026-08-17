#!/usr/bin/env ruby

# JSON Logger Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/json-logger/template
# Usage: rails app:template LOCATION=https://railstemplates.org/json-logger/template

say "railstemplates.org"
say "🪵 Composing a JSON-lines logger (raw STDOUT + optional AppSignal broadcast)...", :green

if File.exist?("config/initializers/json_logger.rb")
  say "JSON logger initializer already present, skipping.", :yellow
  return
end

initializer_body = <<~'RUBY'
  # Composes `Rails.logger` so every line reaches STDOUT as a bare, valid JSON
  # object — and, when the `appsignal` gem is present, AppSignal Logs too.
  #
  # This template installs the *pipe*, not the lines. The templates that emit
  # JSON lines flow through it:
  #
  #   lograge                — one line per HTTP request
  #   active-job-json-logs   — one line per Active Job execution
  #   application-client     — one line per outgoing external HTTP request
  #   rails-event-json       — one line per `Rails.event.notify`
  #   debug-exceptions-json  — one line per unhandled exception
  #
  # Active in production (and staging, if that environment exists). Dev and test
  # keep Rails' default human-readable logger.

  return unless Rails.env.production? || Rails.env.staging?

  # 1. The STDOUT logger gets a RAW formatter. `Logger`'s default prepends
  #    `I, [2026-07-19T12:00:00#42] INFO -- : ` to every line, which turns an
  #    otherwise-valid JSON object into something no aggregator can parse.
  #
  # 2. `level:` MUST be set explicitly here. `Appsignal::Logger#add` writes to
  #    its broadcast targets BEFORE applying its own level filter, so
  #    `config.log_level` ends up filtering only the AppSignal leg. Without an
  #    explicit level, `Logger.new` defaults to `:debug` and debug-level chatter
  #    floods journalctl.
  log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  raw_formatter = ->(_severity, _time, _progname, msg) { "#{msg}\n" }
  stdout_logger = Logger.new($stdout, level: log_level).tap { |l| l.formatter = raw_formatter }

  # 3. If the `appsignal` gem is loaded, `Appsignal::Logger#broadcast_to` fans
  #    the same lines out to AppSignal Logs. This is deliberately NOT
  #    `ActiveSupport::BroadcastLogger`, which conflicts with `TaggedLogging`
  #    when one leg is an `Appsignal::Logger`. AppSignal's default
  #    `format: AUTODETECT` sniffs each line as JSON. With no
  #    `APPSIGNAL_PUSH_API_KEY` set, AppSignal silently no-ops and STDOUT still
  #    reaches journalctl.
  logger =
    if defined?(Appsignal::Logger)
      Appsignal::Logger.new("rails").tap { |l| l.broadcast_to(stdout_logger) }
    else
      stdout_logger
    end

  # 4. `TaggedLogging` so callers can still use `Rails.logger.tagged(...)`.
  composed_logger = ActiveSupport::TaggedLogging.new(logger)

  Rails.logger = composed_logger
  # Also assign `config.logger` so anything reading it during the rest of the
  # boot picks up the composed logger rather than nil — the lograge template's
  # `config.lograge.logger = config.logger` relies on this.
  Rails.application.config.logger = composed_logger
RUBY

create_file "config/initializers/json_logger.rb", initializer_body, skip: true

environments = ["production"]
environments << "staging" if File.exist?("config/environments/staging.rb")
say "✅ JSON logger composed for #{environments.join(" and ")}.", :green
say "Dev/test continue using Rails' default logger.", :blue
say "Set RAILS_LOG_LEVEL to change the STDOUT level (default: info).", :blue
say "Add the appsignal gem to turn on the AppSignal Logs broadcast leg.", :blue
