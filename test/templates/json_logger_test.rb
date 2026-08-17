require_relative "../test_helper"

class JsonLoggerTest < TemplateTestCase
  def test_json_logger
    create_rails_app
    apply_template("json-logger")

    initializer_path = "#{@app_dir}/config/initializers/json_logger.rb"
    assert File.exist?(initializer_path)

    initializer = File.read(initializer_path)

    # Environment gate
    assert_match(/return unless Rails\.env\.production\? \|\| Rails\.env\.staging\?/, initializer)

    # Raw formatter, so each line is a bare JSON object
    assert_match(/raw_formatter = ->\(_severity, _time, _progname, msg\) \{ "#\{msg\}\\n" \}/, initializer)
    assert_match(/l\.formatter = raw_formatter/, initializer)

    # Explicit STDOUT level from RAILS_LOG_LEVEL
    assert_match(/ENV\.fetch\("RAILS_LOG_LEVEL", "info"\)/, initializer)
    assert_match(/Logger\.new\(\$stdout, level: log_level\)/, initializer)

    # Optional AppSignal broadcast leg, guarded on the gem being loaded
    assert_match(/defined\?\(Appsignal::Logger\)/, initializer)
    assert_match(/broadcast_to\(stdout_logger\)/, initializer)

    # TaggedLogging wrapper, assigned to both Rails.logger and config.logger
    assert_match(/ActiveSupport::TaggedLogging\.new\(logger\)/, initializer)
    assert_match(/Rails\.logger = composed_logger/, initializer)
    assert_match(/Rails\.application\.config\.logger = composed_logger/, initializer)

    # Idempotency: re-applying the template produces no further diff
    initializer_before = File.read(initializer_path)
    apply_template("json-logger")
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify the initializer"

    assert_rails_boots
  end
end
