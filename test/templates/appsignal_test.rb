require_relative "../test_helper"

class AppsignalTest < TemplateTestCase
  def test_appsignal
    create_rails_app
    apply_template("appsignal")

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "appsignal"/, gemfile)
    assert_equal 1, gemfile.scan(/gem "appsignal"/).count, "Expected exactly one appsignal gem entry in Gemfile"

    config_path = "#{@app_dir}/config/appsignal.rb"
    assert File.exist?(config_path)

    config = File.read(config_path)
    assert_match(/Appsignal\.configure/, config)
    assert_match(/activate_if_environment\("production"\)/, config)
    assert_match(/config\.name = ".+"/, config, "config.name must be a concrete camelized app name literal")
    assert_match(/ignore_actions << "Rails::HealthController#show"/, config,
      "healthcheck action must be excluded from APM samples")
    assert_match(/filter_parameters/, config)
    assert_match(/filter_session_data/, config)

    # SCHEMA-event filter initializer prevents false N+1 flags on boot
    schema_filter_path = "#{@app_dir}/config/initializers/appsignal_filter_schema_events.rb"
    assert File.exist?(schema_filter_path)
    schema_filter = File.read(schema_filter_path)
    assert_match(/AppsignalSchemaEventFilter/, schema_filter)
    assert_match(/payload\[:name\] == "SCHEMA"/, schema_filter)

    # Idempotency: re-applying the template produces no further diff
    config_before = File.read(config_path)
    schema_filter_before = File.read(schema_filter_path)
    apply_template("appsignal")
    gemfile_after = File.read("#{@app_dir}/Gemfile")
    assert_equal 1, gemfile_after.scan(/gem "appsignal"/).count,
      "Re-running the template must not add appsignal again"
    assert_equal config_before, File.read(config_path),
      "Re-running the template must not modify config/appsignal.rb"
    assert_equal schema_filter_before, File.read(schema_filter_path),
      "Re-running the template must not modify the schema-event filter"

    assert_rails_boots
  end
end
