require_relative "../test_helper"

class UpdateRubyTest < TemplateTestCase
  def test_update_ruby
    create_rails_app
    apply_template("update-ruby")

    workflow_path = "#{@app_dir}/.github/workflows/update-ruby.yml"
    assert File.exist?(workflow_path), "Expected .github/workflows/update-ruby.yml to be created"

    workflow = File.read(workflow_path)
    # Core behaviour markers
    assert_match(/name: Update Ruby/, workflow)
    assert_match(/workflow_dispatch:/, workflow, "must support manual runs")
    assert_match(%r{ruby/setup-ruby@v1}, workflow)
    assert_match(/ruby-builder-versions\.json/, workflow,
      "must read the installable-versions manifest")
    assert_match(%r{peter-evans/create-pull-request}, workflow)
    assert_match(/\.ruby-version/, workflow)
    assert_match(/labels:\s*\|\s*\n\s*dependencies\s*\n\s*ruby/m, workflow,
      "PR must be labelled dependencies/ruby")

    # Simplifications: none of the upstream app-specific baggage should survive
    refute_match(/sqlpkg/, workflow, "SQLite extension steps must be dropped")
    refute_match(/test:system/, workflow, "system tests must be dropped")
    refute_match(/README/, workflow, "README rewriting must be dropped")
    refute_match(/build-essential/, workflow, "apt package install must be dropped")

    # Idempotency: re-applying the template produces no further diff
    workflow_before = File.read(workflow_path)
    apply_template("update-ruby")
    assert_equal workflow_before, File.read(workflow_path),
      "Re-running the template must not modify the workflow"

    assert_rails_boots
  end
end
