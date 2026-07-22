require_relative "../test_helper"

class LogrageTest < TemplateTestCase
  def test_lograge
    create_rails_app
    apply_template("lograge")

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "lograge"/, gemfile)
    assert_equal 1, gemfile.scan(/gem "lograge"/).count, "Expected exactly one lograge gem entry in Gemfile"

    initializer_path = "#{@app_dir}/config/initializers/lograge.rb"
    assert File.exist?(initializer_path)

    initializer = File.read(initializer_path)
    assert_match(/Rails\.env\.production\?/, initializer)
    assert_match(/Rails\.env\.staging\?/, initializer)
    assert_match(/Lograge::Formatters::Json\.new/, initializer)
    assert_match(/custom_payload/, initializer)
    assert_match(/filtered_parameters/, initializer)
    assert_match(/filtered_path/, initializer)
    assert_match(/request_id/, initializer)
    assert_match(/user_id/, initializer)
    assert_match(/Current/, initializer)
    assert_match(/Rails::HealthController#show/, initializer)
    refute_match(/event\.payload\[:params\]/, initializer,
      "Must not log unfiltered event.payload[:params] — leaks secrets")

    # Idempotency: re-applying the template produces no further diff
    initializer_before = File.read(initializer_path)
    apply_template("lograge")
    gemfile_after = File.read("#{@app_dir}/Gemfile")
    assert_equal 1, gemfile_after.scan(/gem "lograge"/).count,
      "Re-running the template must not add lograge again"
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify the initializer"

    assert_rails_boots
  end
end
