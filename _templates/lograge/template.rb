#!/usr/bin/env ruby

# Lograge Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/lograge/template
# Usage: rails app:template LOCATION=https://railstemplates.org/lograge/template

say "railstemplates.org"
say "📝 Configuring Lograge for structured production logs...", :green

# The initializer body shipped by the prior #22 version of this template.
# We use this to detect "untouched #22 installs" so we can safely upgrade
# them in place. Hand-edited files differ from this string and are left
# alone.
PRIOR_INITIALIZER_SHAPE = <<~'RUBY'
  # Lograge: one structured JSON line per request in production (and staging
  # if that environment exists). Dev/test keep Rails' default logger.
  return unless Rails.env.production? || Rails.env.staging?

  Rails.application.configure do
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::Json.new
    config.lograge.ignore_actions = ["Rails::HealthController#show"]

    if Rails.application.config.api_only
      config.lograge.base_controller_class = "ActionController::API"
    end

    config.lograge.custom_payload do |controller|
      user_id =
        begin
          defined?(Current) && Current.respond_to?(:user) ? Current.user&.id : nil
        rescue StandardError
          nil
        end

      {
        params: controller.request.filtered_parameters.except("controller", "action"),
        path: controller.request.filtered_path,
        request_id: controller.request.request_id,
        user_id: user_id
      }.compact
    end
  end
RUBY

# The enhanced initializer body this version of the template installs.
NEW_INITIALIZER_SHAPE = <<~'RUBY'
  # Lograge: one structured JSON line per request in production (and staging
  # if that environment exists). Dev/test keep Rails' default logger.
  return unless Rails.env.production? || Rails.env.staging?

  Rails.application.config.lograge.enabled = true

  # Skip noisy healthcheck paths. `silence_healthcheck_path` is ineffective
  # under broadcast loggers (each leg keeps its own level); `ignore_actions`
  # short-circuits inside RequestLogSubscriber before the formatter or
  # logger run.
  Rails.application.config.lograge.ignore_actions = %w[
    Rails::HealthController#show
  ]

  Rails.application.config.lograge.formatter = Lograge::Formatters::Json.new

  Rails.application.config.lograge.custom_payload do |controller|
    {
      request_id: controller.request.request_id,
      user_id:    controller.try(:current_user)&.id,
      # Common tenant accessor names; the helper picks the first one that
      # exists. Override by editing this file if the app uses something else.
      workspace_id: controller.try(:current_workspace)&.id ||
                    controller.try(:current_account)&.id   ||
                    controller.try(:current_organization)&.id,
      remote_ip:  controller.request.remote_ip
    }.compact
  end

  Rails.application.config.lograge.custom_options = ->(event) {
    base = { event: "request" }
    # On 4xx/5xx, include `filtered_params` so we can debug bad requests
    # without leaking secrets. Already redacted by filter_parameter_logging.
    base[:params] = event.payload[:filtered_params] if event.payload[:status].to_i >= 400
    base
  }

  # Route lograge through the composed Rails.logger so request lines reach
  # the same destinations as other JSON lines (relevant when the AppSignal
  # broadcast template composes Rails.logger). Without this, lograge writes
  # to its own STDOUT logger and bypasses any broadcast.
  Rails.application.config.lograge.logger = Rails.application.config.logger
RUBY

# Normalize whitespace per line so trivial diffs (trailing spaces, CRLF)
# don't block the upgrade.
def normalize_initializer(content)
  content.to_s.lines.map { |line| line.rstrip }.join("\n").strip
end

initializer_path = "config/initializers/lograge.rb"

unless File.read("Gemfile").include?('"lograge"')
  gem "lograge"
end

after_bundle do
  if File.exist?(initializer_path)
    current = normalize_initializer(File.read(initializer_path))
    prior   = normalize_initializer(PRIOR_INITIALIZER_SHAPE)
    new_one = normalize_initializer(NEW_INITIALIZER_SHAPE)

    if current == new_one
      say "Lograge initializer already up to date, skipping.", :blue
    elsif current == prior
      say "Upgrading lograge initializer from prior shape...", :green
      remove_file initializer_path
      create_file initializer_path, NEW_INITIALIZER_SHAPE
    else
      say "Lograge initializer has been hand-edited, leaving it alone.", :yellow
      say "Diff against the new template manually if you want the new fields.", :yellow
    end
  else
    create_file initializer_path, NEW_INITIALIZER_SHAPE
  end

  environments = ["production"]
  environments << "staging" if File.exist?("config/environments/staging.rb")
  say "✅ Lograge configured for #{environments.join(" and ")}.", :green
  say "Dev/test continue using Rails' default logger.", :blue
end
