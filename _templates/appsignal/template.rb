#!/usr/bin/env ruby

# AppSignal Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/appsignal/template
# Usage: rails app:template LOCATION=https://railstemplates.org/appsignal/template

say "railstemplates.org"
say "📈 Installing AppSignal for APM + error monitoring...", :green

if File.exist?("config/appsignal.rb")
  say "AppSignal config already present, skipping.", :yellow
  return
end

unless File.read("Gemfile").include?('"appsignal"')
  gem "appsignal"
end

# Resolve the application name at template-apply time so the generated
# config/appsignal.rb ships with a concrete `config.name`. In the Thor template
# context `app_name` is the underscored app name for both `rails new -m` and
# `rails app:template`; camelize it for a readable AppSignal app name
# (e.g. "my_app" -> "MyApp").
app_display_name = app_name.camelize

after_bundle do
  # Generate config/appsignal.rb with the gem's own installer, so the base file
  # always matches whatever the installed appsignal version ships. `appsignal
  # install` proper is interactive and needs a network-validated Push API key,
  # so we drive its file-writer directly. It has to run in a fresh `bundle exec`
  # subprocess: the gem was only just added to the Gemfile, so it isn't on the
  # load path of the process running this template. We pass an empty Push API
  # key and read the real one from APPSIGNAL_PUSH_API_KEY at runtime instead.
  run %(bundle exec ruby -r appsignal/cli -e 'Appsignal::CLI::Install.write_ruby_config_file(:push_api_key => "", :app_name => #{app_display_name.inspect}, :environments => ["production"])')

  # Drop the empty push_api_key the installer writes — the key comes from the
  # APPSIGNAL_PUSH_API_KEY environment variable. Replace the whole commented
  # block for a clean result; the narrow second pass is a safety net in case the
  # gem changes that comment's wording.
  gsub_file "config/appsignal.rb",
    /^  # The application's Push API key\n(?:  #.*\n)*  config\.push_api_key = ""\n/,
    %(  # The Push API key is read from the APPSIGNAL_PUSH_API_KEY environment variable.\n)
  gsub_file "config/appsignal.rb", /^  config\.push_api_key = ""\n/, ""

  # Insert our "required" defaults into the generated Appsignal.configure block,
  # just before its closing `end`. These belong in this file, not a
  # config/initializers/*.rb file: AppSignal starts before Rails initializers
  # run, so ignore_actions/filter_parameters set in an initializer are read too
  # late to take effect.
  defaults = <<~RUBY
    # Keep Rails' healthcheck endpoint out of APM samples — it's high-volume
    # load-balancer noise with no diagnostic value.
    config.ignore_actions << "Rails::HealthController#show"

    # Redact sensitive params/headers/session data/job args before they leave
    # the app. AppSignal's filter does EXACT string match (no regex/symbols) —
    # full key names are required.
    # https://docs.appsignal.com/ruby/configuration/parameter-filtering.html
    config.filter_parameters = %w[
      password password_confirmation
      secret api_key access_token refresh_token bearer_token
      authorization cookie set_cookie x_csrf_token csrftoken
      sessionid session_id client_id client_secret webhook_secret
      signed_id otp totp two_factor_code
      appsignal_push_api_key rails_master_key
      ssn cvv cvc certificate salt
    ]
    config.filter_session_data = config.filter_parameters
  RUBY

  # Indent every non-blank line two spaces to sit inside the configure block.
  indented = defaults.gsub(/^(?=.)/, "  ")
  inject_into_file "config/appsignal.rb", "\n#{indented}", before: /^end\n/

  # Suppress AppSignal's false N+1 flag on Rails' SCHEMA queries. Rails
  # publishes SCHEMA `sql.active_record` events at two nested instrumentation
  # levels during connection setup; AppSignal reads the duplicate digest as an
  # N+1. Drop the SCHEMA event so it never counts. This is a module prepend
  # (a code patch, not config), so it correctly lives in an initializer.
  schema_filter_body = <<~'RUBY'
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

  create_file "config/initializers/appsignal_filter_schema_events.rb", schema_filter_body, skip: true

  say "✅ AppSignal configured for production.", :green
  say "Set APPSIGNAL_PUSH_API_KEY in your production environment to start reporting.", :blue
end
