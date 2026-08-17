#!/usr/bin/env ruby

# DebugExceptions JSON Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/debug-exceptions-json/template
# Usage: rails app:template LOCATION=https://railstemplates.org/debug-exceptions-json/template

say "railstemplates.org"
say "🪵 Configuring single-line JSON logging for unhandled exceptions...", :green

if File.exist?("config/initializers/debug_exceptions_json.rb")
  say "debug_exceptions_json initializer already present, skipping.", :yellow
  return
end

initializer_body = <<~'RUBY'
  # Emit one JSON line per unhandled exception (including
  # ActionController::RoutingError for unmatched paths) instead of the
  # default multi-line "Class (message):" + annotated source + backtrace.
  # Backtraces are intentionally elided here — capture them via an APM.

  module DebugExceptionsJson
    def log_error(request, wrapper)
      Rails.logger.info({
        event:      "request.exception",
        method:     request.method,
        path:       request.filtered_path,
        remote_ip:  request.remote_ip,
        request_id: request.request_id,
        exception:  wrapper.exception_class_name,
        message:    wrapper.message,
        status:     wrapper.status_code
      }.compact.to_json)
    end
  end

  if Rails.env.production? || Rails.env.staging?
    Rails.application.config.after_initialize do
      ActionDispatch::DebugExceptions.prepend(DebugExceptionsJson)
    end
  end
RUBY

create_file "config/initializers/debug_exceptions_json.rb", initializer_body, skip: true

environments = ["production"]
environments << "staging" if File.exist?("config/environments/staging.rb")
say "✅ DebugExceptions JSON logging configured for #{environments.join(" and ")}.", :green
say "Dev/test keep Rails' multi-line exception output for debug-friendliness.", :blue
say "Reminder: backtraces are not in the log line — capture them via an APM.", :blue
