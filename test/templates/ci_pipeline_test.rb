require_relative "../test_helper"

class CiPipelineTest < TemplateTestCase
  def test_ci_pipeline
    create_rails_app
    apply_template("ci-pipeline")

    # bin/ci exists and is executable
    bin_ci_path = "#{@app_dir}/bin/ci"
    assert File.exist?(bin_ci_path), "bin/ci should exist"
    bin_ci = File.read(bin_ci_path)
    assert_match(%r{require_relative "../config/boot"}, bin_ci)
    assert_match(/active_support\/continuous_integration/, bin_ci)
    assert_equal 0, File.stat(bin_ci_path).mode & 0o700 ^ 0o700,
      "bin/ci should be owner-executable (got mode #{File.stat(bin_ci_path).mode.to_s(8)})"
    assert((File.stat(bin_ci_path).mode & 0o100) != 0, "bin/ci should have the user-exec bit set")

    # config/ci.rb exists with ActiveSupport::ContinuousIntegration pipeline
    ci_rb_path = "#{@app_dir}/config/ci.rb"
    assert File.exist?(ci_rb_path), "config/ci.rb should exist"
    ci_rb = File.read(ci_rb_path)
    assert_match(/CI\.run do/, ci_rb)
    assert_match(/step "Tests: Rails", "bin\/rails test"/, ci_rb)

    # Template-exclusive steps — absent from the barer config/ci.rb that Rails 8.1
    # scaffolds, so they prove the template's richer pipeline actually replaced the
    # default rather than being skipped.
    assert_match(/step "Security: Brakeman code analysis"/, ci_rb,
      "config/ci.rb must carry the Brakeman step, not the barer Rails default")
    assert_match(/step "Tests: Seeds", "env RAILS_ENV=test bin\/rails db:seed:replant"/, ci_rb,
      "config/ci.rb must carry the seeds check")
    # System tests get their own parallel job in the workflow; locally they're
    # the slowest step, so bin/ci ships them commented out.
    assert_match(/^  # step "Tests: System", "bin\/rails test:system"$/, ci_rb,
      "config/ci.rb must ship the system-test step commented out")

    # .github/workflows/ci.yml exists with five jobs
    workflow_path = "#{@app_dir}/.github/workflows/ci.yml"
    assert File.exist?(workflow_path), ".github/workflows/ci.yml should exist"
    workflow = File.read(workflow_path)
    assert_match(/^  scan_ruby:$/, workflow)
    assert_match(/^  scan_js:$/, workflow)
    assert_match(/^  lint:$/, workflow)
    assert_match(/^  test:$/, workflow)
    assert_match(/^  system-test:$/, workflow)

    # Current action majors, so a fresh app doesn't open a Dependabot PR on day one
    assert_match(/uses: actions\/checkout@v7$/, workflow)
    assert_match(/uses: actions\/cache@v6$/, workflow)
    assert_match(/uses: actions\/upload-artifact@v7$/, workflow)

    # Rubocop cache keyed on .ruby-version + rubocop configs + Gemfile.lock
    assert_match(/hashFiles\('\.ruby-version', '\*\*\/\.rubocop\.yml', '\*\*\/\.rubocop_todo\.yml', 'Gemfile\.lock'\)/, workflow)

    # Screenshot artifact upload on system-test failure
    assert_match(/if: failure\(\)/, workflow)
    assert_match(/name: screenshots/, workflow)

    # Idempotency: re-applying the template produces byte-identical files
    bin_ci_before = File.read(bin_ci_path)
    ci_rb_before = File.read(ci_rb_path)
    workflow_before = File.read(workflow_path)

    apply_template("ci-pipeline")

    assert_equal bin_ci_before, File.read(bin_ci_path),
      "Re-running the template must not modify bin/ci"
    assert_equal ci_rb_before, File.read(ci_rb_path),
      "Re-running the template must not modify config/ci.rb"
    assert_equal workflow_before, File.read(workflow_path),
      "Re-running the template must not modify .github/workflows/ci.yml"

    assert_rails_boots
  end
end
