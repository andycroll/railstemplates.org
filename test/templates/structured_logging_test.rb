require_relative "../test_helper"

class StructuredLoggingTest < TemplateTestCase
  def test_structured_logging
    create_rails_app
    apply_template("structured-logging")

    initializer_path = "#{@app_dir}/config/initializers/structured_logging.rb"
    assert File.exist?(initializer_path)

    initializer = File.read(initializer_path)
    # Active only in production/staging; dev/test keep the default logger.
    assert_match(/Rails\.env\.production\?/, initializer)
    assert_match(/Rails\.env\.staging\?/, initializer)

    # Silent gotchas the initializer must encode.
    assert_match(/raw_formatter = ->\(_severity, _time, _progname, msg\)/, initializer,
      "Must install a RAW formatter so each line is bare JSON with no severity prefix")
    assert_match(/Logger\.new\(\$stdout, level: log_level\)/, initializer,
      "STDOUT logger must set an explicit level so SolidQueue polling doesn't flood journalctl")
    assert_match(/broadcast_to\(stdout_logger\)/, initializer,
      "AppSignal leg must use Appsignal::Logger#broadcast_to")
    refute_match(/ActiveSupport::BroadcastLogger\.new/, initializer,
      "Must NOT use ActiveSupport::BroadcastLogger — it conflicts with TaggedLogging")
    assert_match(/ActiveSupport::TaggedLogging\.new/, initializer)

    # AppSignal broadcast is optional and auto-detected.
    assert_match(/defined\?\(Appsignal::Logger\)/, initializer,
      "AppSignal broadcast must be guarded so vanilla apps work")

    # The four subscribers.
    assert_match(/subscribe\("perform\.active_job"\)/, initializer)
    assert_match(/subscribe\("request\.application_client"\)/, initializer)
    assert_match(/Rails\.event\.subscribe/, initializer)
    assert_match(/StructuredLoggingDebugExceptionsJson/, initializer)

    # Framework-namespace early-return to avoid duplicate Rails.event lines.
    assert_match(/RAILS_EVENT_NAMESPACES/, initializer)
    assert_match(/framework_event\?/, initializer)

    # Guarded couplings so a vanilla app applies cleanly.
    assert_match(/defined\?\(SolidQueue::ReadyExecution\)/, initializer,
      "SolidQueue must be guarded")
    assert_match(/defined\?\(Current\).*Current\.respond_to\?\(:request_id\)/, initializer,
      "Current.request_id must be guarded")

    # Sensitive values routed through the app's parameter filter.
    assert_match(/Rails\.application\.config\.filter_parameters/, initializer,
      "Job args must be routed through filter_parameters")

    # Only detach the framework ActiveJob subscriber in production.
    assert_match(/ActiveJob::LogSubscriber\.detach_from/, initializer)

    # Idempotency: re-applying the template produces no further diff.
    initializer_before = File.read(initializer_path)
    apply_template("structured-logging")
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify the initializer"

    assert_rails_boots
  end
end
