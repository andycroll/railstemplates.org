#!/usr/bin/env ruby

# Lograge Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/lograge/template
# Usage: rails app:template LOCATION=https://railstemplates.org/lograge/template

say "railstemplates.org"
say "📝 Configuring Lograge for structured production logs...", :green

if File.exist?("config/initializers/lograge.rb")
  say "Lograge initializer already present, skipping.", :yellow
  return
end

unless File.read("Gemfile").include?('"lograge"')
  gem "lograge"
end

after_bundle do
  initializer_body = <<~'RUBY'
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

  create_file "config/initializers/lograge.rb", initializer_body, skip: true

  environments = ["production"]
  environments << "staging" if File.exist?("config/environments/staging.rb")
  say "✅ Lograge configured for #{environments.join(" and ")}.", :green
  say "Dev/test continue using Rails' default logger.", :blue
end
