require_relative "../test_helper"

class DebugExceptionsJsonTest < TemplateTestCase
  def test_debug_exceptions_json
    create_rails_app
    apply_template("debug-exceptions-json")

    initializer_path = "#{@app_dir}/config/initializers/debug_exceptions_json.rb"
    assert File.exist?(initializer_path)

    initializer = File.read(initializer_path)
    assert_match(/module DebugExceptionsJson/, initializer)
    assert_match(/def log_error\(request, wrapper\)/, initializer)
    assert_match(/event:\s+"request\.exception"/, initializer)
    assert_match(/wrapper\.exception_class_name/, initializer)
    assert_match(/wrapper\.status_code/, initializer)
    assert_match(/wrapper\.message/, initializer)
    assert_match(/request\.filtered_path/, initializer)
    assert_match(/request\.request_id/, initializer)
    assert_match(/\.compact\.to_json/, initializer)

    # Production/staging gate must be present so dev/test keep the multi-line default
    assert_match(/Rails\.env\.production\?/, initializer)
    assert_match(/Rails\.env\.staging\?/, initializer)
    assert_match(/Rails\.application\.config\.after_initialize/, initializer)
    assert_match(/ActionDispatch::DebugExceptions\.prepend\(DebugExceptionsJson\)/, initializer)

    # Backtraces are deliberately not logged — APM territory
    initializer_code = initializer.lines.reject { |l| l.strip.start_with?("#") }.join
    refute_match(/backtrace/i, initializer_code,
      "Backtrace must not appear in the logged payload — capture it via an APM")

    # Idempotency: re-applying the template produces no further diff
    initializer_before = File.read(initializer_path)
    apply_template("debug-exceptions-json")
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify the initializer"

    assert_rails_boots
  end
end
