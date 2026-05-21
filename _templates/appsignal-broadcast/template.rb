#!/usr/bin/env ruby

# AppSignal broadcast-logger Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/appsignal-broadcast/template
# Usage: rails app:template LOCATION=https://railstemplates.org/appsignal-broadcast/template

say "railstemplates.org"
say "📡 Configuring AppSignal broadcast logger...", :green

unless File.read("Gemfile").include?('"appsignal"')
  gem "appsignal"
end

after_bundle do
  appsignal_rb = <<~'RUBY'
    # AppSignal configuration.
    #
    # APPSIGNAL_FILTER_KEYS is the AppSignal-shaped mirror of
    # config/initializers/filter_parameter_logging.rb. AppSignal's filter is
    # exact-string-match — no regexes, no symbols. Keep these two lists in
    # sync manually whenever new sensitive keys are added.
    APPSIGNAL_FILTER_KEYS = %w[
      password password_confirmation
      secret api_key access_token refresh_token bearer_token
      authorization cookie set_cookie x_csrf_token csrftoken
      sessionid session_id client_id client_secret webhook_secret
      signed_id otp totp two_factor_code
      rails_master_key ssn cvv cvc certificate salt
    ].freeze

    Appsignal.configure do |config|
      config.activate_if_environment("development", "production", "staging")
      config.name = Rails.application.class.module_parent_name

      config.instrument_net_http = true

      config.filter_parameters    = APPSIGNAL_FILTER_KEYS
      config.filter_session_data  = APPSIGNAL_FILTER_KEYS

      # Mirror lograge's ignore list to keep healthchecks out of APM samples.
      config.ignore_actions << "Rails::HealthController#show"
    end
  RUBY

  create_file "config/appsignal.rb", appsignal_rb, skip: true

  schema_filter_rb = <<~'RUBY'
    # Rails publishes SCHEMA `sql.active_record` events at two nested
    # instrumentation levels during connection setup; AppSignal reads the
    # duplicate digest as N+1.

    return unless defined?(Appsignal::Integrations::ActiveSupportNotificationsIntegration)

    module AppsignalSchemaEventFilter
      def finish_event(name, payload = {})
        return if name == "sql.active_record" && payload[:name] == "SCHEMA"
        super
      end
    end

    Appsignal::Integrations::ActiveSupportNotificationsIntegration
      .singleton_class.prepend(AppsignalSchemaEventFilter)
  RUBY

  create_file "config/initializers/appsignal_filter_schema_events.rb", schema_filter_rb, skip: true

  production_path = "config/environments/production.rb"

  if File.exist?(production_path) && !File.read(production_path).include?("appsignal-broadcast template start")
    broadcast_block = <<~'RUBY'

      # === appsignal-broadcast template start ===
      # Broadcast Rails.logger to STDOUT *and* AppSignal Logs.
      #
      # `Appsignal::Logger#broadcast_to` (NOT ActiveSupport::BroadcastLogger,
      # which conflicts with TaggedLogging when one leg is Appsignal::Logger).
      # Each leg keeps its own level. Set STDOUT level explicitly to avoid
      # default :debug flooding journalctl.
      log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
      raw_formatter = ->(_severity, _time, _progname, msg) { "#{msg}\n" }
      stdout_logger = Logger.new($stdout, level: log_level).tap { |l| l.formatter = raw_formatter }
      appsignal_logger = Appsignal::Logger.new("rails")
      appsignal_logger.broadcast_to(stdout_logger)
      config.logger = ActiveSupport::TaggedLogging.new(appsignal_logger)
      config.log_level = log_level
      # === appsignal-broadcast template end ===
    RUBY

    # Insert before the final `end` (the closer for Rails.application.configure).
    inject_into_file production_path, broadcast_block, before: /^end\s*\z/
  end

  say ""
  say "✅ AppSignal broadcast logger configured!", :green
  say ""
  say "📋 Next steps:", :blue
  say "   • Set APPSIGNAL_PUSH_API_KEY in production (and staging/dev if you want them reporting)"
  say "   • Keep APPSIGNAL_FILTER_KEYS in sync with config/initializers/filter_parameter_logging.rb"
  say "   • Without APPSIGNAL_PUSH_API_KEY set, AppSignal silently no-ops — STDOUT still works"
  say ""
end
