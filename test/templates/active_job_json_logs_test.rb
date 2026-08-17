require_relative "../test_helper"

class ActiveJobJsonLogsTest < TemplateTestCase
  def test_active_job_json_logs
    create_rails_app
    apply_template("active-job-json-logs")

    initializer_path = "#{@app_dir}/config/initializers/active_job_logging.rb"
    assert File.exist?(initializer_path)

    initializer = File.read(initializer_path)
    assert_match(/ActiveSupport::Notifications\.subscribe\("perform\.active_job"\)/, initializer)
    assert_match(/event:\s+"job\.perform"/, initializer)
    assert_match(/module ActiveJobNoTagging/, initializer)
    assert_match(/tag_logger/, initializer)
    assert_match(/ActiveJob::LogSubscriber\.detach_from\(:active_job\)/, initializer)
    assert_match(/ActiveJob::Base\.prepend\(ActiveJobNoTagging\)/, initializer)
    assert_match(/ActiveSupport::ParameterFilter/, initializer)
    assert_match(/to_global_id/, initializer)
    assert_match(/SolidQueue::ReadyExecution\.count rescue nil/, initializer)
    assert_match(/defined\?\(Current\)/, initializer)

    # The detach/prepend must be guarded so dev/test boot cleanly.
    assert_match(
      /if Rails\.env\.production\?[^\n]*Rails\.env\.staging\?.*?ActiveJob::LogSubscriber\.detach_from\(:active_job\).*?ActiveJob::Base\.prepend\(ActiveJobNoTagging\).*?end/m,
      initializer,
      "detach_from + prepend must live inside an `if Rails.env.production? || Rails.env.staging?` guard"
    )

    # Gemfile should not gain a gem entry — uses stdlib ActiveSupport::Notifications.
    gemfile = File.read("#{@app_dir}/Gemfile")
    refute_match(/active_job_logging/, gemfile)

    # Idempotency: re-applying the template produces no further diff
    initializer_before = File.read(initializer_path)
    apply_template("active-job-json-logs")
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify the initializer"

    assert_rails_boots
  end
end
