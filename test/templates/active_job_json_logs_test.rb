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
    assert_match(/module JobArgumentLogging/, initializer)
    assert_match(/JobArgumentLogging\.render\(job\.arguments\)/, initializer)
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
    assert_records_globalize_at_every_depth
  end

  private

  # Records nested inside a hash or array argument must reduce to GlobalIDs
  # too. A top-level-only conversion leaves them to `to_json`, which renders
  # the whole attribute set — `ActionMailer::MailDeliveryJob` hits this on
  # every `deliver_later` because it nests its record inside a hash.
  def assert_records_globalize_at_every_depth
    probe = File.join(@app_dir, "tmp/job_argument_logging_probe.rb")
    File.write(probe, <<~RUBY)
      record = Class.new { def to_global_id = "gid://app/User/1" }.new
      puts JobArgumentLogging.render([ record, { args: [ record ] }, [ record ] ]).to_json
    RUBY

    Bundler.with_unbundled_env do
      Dir.chdir(@app_dir) do
        output = `bundle exec rails runner tmp/job_argument_logging_probe.rb 2>&1`
        assert_includes output,
          '["gid://app/User/1",{"args":["gid://app/User/1"]},["gid://app/User/1"]]',
          "records must reduce to GlobalIDs at every depth, not just the top level: #{output}"
      end
    end
  end
end
