require_relative "../test_helper"

class RequestIdContextTest < TemplateTestCase
  def test_request_id_context
    create_rails_app
    apply_template("request-id-context")

    # 1. Current includes request_id
    current_path = "#{@app_dir}/app/models/current.rb"
    assert File.exist?(current_path), "app/models/current.rb should exist after template"
    current_rb = File.read(current_path)
    assert_match(/class Current < ActiveSupport::CurrentAttributes/, current_rb)
    assert_match(/attribute :request_id/, current_rb)

    # 2. ApplicationJob propagates request_id through enqueue/serialize/deserialize/perform
    application_job_path = "#{@app_dir}/app/jobs/application_job.rb"
    assert File.exist?(application_job_path), "app/jobs/application_job.rb should exist after template"
    application_job = File.read(application_job_path)
    assert_match(/attr_accessor :request_id/, application_job)
    assert_match(/before_enqueue \{ self\.request_id \|\|= Current\.request_id \|\| SecureRandom\.uuid \}/, application_job)
    assert_match(/def serialize/, application_job)
    assert_match(/super\.merge\("request_id" => request_id\)/, application_job)
    assert_match(/def deserialize\(job_data\)/, application_job)
    assert_match(/self\.request_id = job_data\["request_id"\]/, application_job)
    assert_match(/def perform_now/, application_job)
    assert_match(/Current\.set\(request_id: request_id\)/, application_job)

    # 3. A SetCurrentRequestId concern holds the setter; ApplicationController
    #    only gains an include line.
    concern_path = "#{@app_dir}/app/controllers/concerns/set_current_request_id.rb"
    assert File.exist?(concern_path), "SetCurrentRequestId concern should be created"
    concern = File.read(concern_path)
    assert_match(/module SetCurrentRequestId/, concern)
    assert_match(/extend ActiveSupport::Concern/, concern)
    assert_match(/before_action :set_current_request_id/, concern)
    assert_match(/Current\.request_id = request\.request_id/, concern)
    assert_match(/Rails\.event\.set_context\(request_id: request\.request_id\) if Rails\.respond_to\?\(:event\)/, concern)

    application_controller_path = "#{@app_dir}/app/controllers/application_controller.rb"
    application_controller = File.read(application_controller_path)
    assert_match(/^  include SetCurrentRequestId$/, application_controller)

    # 4. filter_parameter_logging.rb includes the baseline and default-deny regex
    filter_path = "#{@app_dir}/config/initializers/filter_parameter_logging.rb"
    filter_rb = File.read(filter_path)
    assert_match(/:webhook_secret/, filter_rb)
    assert_match(/:rails_master_key/, filter_rb)
    assert_match(%r{/\(_\|\\A\)\(token\|secret\|key\|password\|cookie\|authorization\)\\z/i}, filter_rb)

    # Idempotency: capture current contents, re-apply, assert nothing changed
    current_before = File.read(current_path)
    application_job_before = File.read(application_job_path)
    application_controller_before = File.read(application_controller_path)
    concern_before = File.read(concern_path)
    filter_before = File.read(filter_path)

    apply_template("request-id-context")

    assert_equal current_before, File.read(current_path),
      "Re-running the template must not modify app/models/current.rb"
    assert_equal application_job_before, File.read(application_job_path),
      "Re-running the template must not modify app/jobs/application_job.rb"
    assert_equal application_controller_before, File.read(application_controller_path),
      "Re-running the template must not modify app/controllers/application_controller.rb"
    assert_equal concern_before, File.read(concern_path),
      "Re-running the template must not modify the SetCurrentRequestId concern"
    assert_equal filter_before, File.read(filter_path),
      "Re-running the template must not modify config/initializers/filter_parameter_logging.rb"

    # Single occurrence of each marker, no duplication
    assert_equal 1, File.read(current_path).scan(/attribute :request_id/).count
    assert_equal 1, File.read(application_job_path).scan(/attr_accessor :request_id/).count
    assert_equal 1, File.read(application_controller_path).scan(/include SetCurrentRequestId/).count
    assert_equal 1, File.read(concern_path).scan(/Current\.request_id = request\.request_id/).count
    assert_equal 1, File.read(filter_path).scan(/:webhook_secret/).count

    assert_rails_boots
  end
end
