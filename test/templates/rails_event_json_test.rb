require_relative "../test_helper"

class RailsEventJsonTest < TemplateTestCase
  def test_rails_event_json
    create_rails_app
    apply_template("rails-event-json")

    initializer_path = "#{@app_dir}/config/initializers/rails_event_json_logging.rb"
    assert File.exist?(initializer_path)

    initializer = File.read(initializer_path)
    assert_match(/class JsonLogSubscriber/, initializer)
    assert_match(/RAILS_EVENT_NAMESPACES = %w\[/, initializer)
    assert_match(/action_controller action_dispatch action_view action_mailer/, initializer)
    assert_match(/active_record active_storage active_job active_support/, initializer)
    assert_match(/def emit\(event\)/, initializer)
    assert_match(/return if framework_event\?\(event\)/, initializer)
    assert_match(/Rails\.logger\.info\(fields\.to_json\)/, initializer)
    assert_match(/Rails\.event\.subscribe\(JsonLogSubscriber\.new\)/, initializer)

    # No gem should be added — Rails 8.1 ships Rails.event
    gemfile = File.read("#{@app_dir}/Gemfile")
    refute_match(/rails-event/, gemfile)

    # Idempotency: re-applying the template leaves the initializer byte-identical
    initializer_before = File.read(initializer_path)
    apply_template("rails-event-json")
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify the initializer"

    assert_rails_boots
  end
end
