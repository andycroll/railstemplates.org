#!/usr/bin/env ruby

# Rails.event JSON Bridge Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/rails-event-json/template
# Usage: rails app:template LOCATION=https://railstemplates.org/rails-event-json/template
#
# Requires Rails 8.1+ (Rails.event was introduced in 8.1).

say "railstemplates.org"
say "🪵 Wiring Rails.event to one JSON line per notify...", :green

if File.exist?("config/initializers/rails_event_json_logging.rb")
  say "Rails.event JSON initializer already present, skipping.", :yellow
  return
end

initializer_body = <<~'RUBY'
  # config/initializers/rails_event_json_logging.rb
  #
  # Renders every Rails.event.notify(...) as a single flat JSON line.
  # `Rails.application.config.filter_parameters` redaction is applied
  # by `Rails.event` *before* this subscriber sees the payload.

  class JsonLogSubscriber
    # Namespaces of Rails 8.1 framework StructuredEventSubscribers.
    # Their events are filtered out here to avoid duplicating
    # action_controller/active_job/active_record/active_storage lines that
    # are already produced by lograge / the active_job subscriber / etc.
    RAILS_EVENT_NAMESPACES = %w[
      action_controller action_dispatch action_view action_mailer
      active_record active_storage active_job active_support
    ].freeze

    def emit(event)
      return if framework_event?(event)

      fields = { event: event[:name] }
      fields.merge!(event[:payload]) if event[:payload].is_a?(Hash)
      fields.merge!(event[:tags])    if event[:tags].is_a?(Hash) && event[:tags].any?
      fields.merge!(event[:context]) if event[:context].is_a?(Hash) && event[:context].any?
      fields[:source_location] = event[:source_location] if event[:source_location]
      Rails.logger.info(fields.to_json)
    end

    private

    def framework_event?(event)
      event[:name].to_s.split(".").first.in?(RAILS_EVENT_NAMESPACES)
    end
  end

  Rails.event.subscribe(JsonLogSubscriber.new)
RUBY

create_file "config/initializers/rails_event_json_logging.rb", initializer_body, skip: true

say "✅ Rails.event JSON subscriber installed.", :green
say "Framework namespaces (action_controller, active_record, …) are filtered to avoid double-emission.", :blue
