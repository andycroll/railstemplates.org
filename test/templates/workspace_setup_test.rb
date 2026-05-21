require_relative "../test_helper"

class WorkspaceSetupTest < TemplateTestCase
  def test_workspace_setup
    create_rails_app
    apply_template("workspace-setup")

    script_path = "#{@app_dir}/bin/workspace-setup"
    assert File.exist?(script_path), "bin/workspace-setup should be created"

    mode = File.stat(script_path).mode
    assert_equal 0700, mode & 0700,
      "bin/workspace-setup should be executable (mode bits include 0700)"

    script = File.read(script_path)

    # Env-var fallback chain (literal references)
    assert_match(/WORKSPACE_NAME/, script)
    assert_match(/CONDUCTOR_WORKSPACE_NAME/, script)
    assert_match(/File\.basename\(Dir\.pwd\)/, script)

    # Sentinel markers around the managed block
    assert_match(/workspace-setup managed start/, script)
    assert_match(/workspace-setup managed end/, script)

    # Deterministic port and Redis derivation
    assert_match(/SHA1/, script)
    assert_match(/3001/, script)

    # Idempotency: re-applying produces a byte-identical file
    script_before = File.read(script_path)
    apply_template("workspace-setup")
    assert_equal script_before, File.read(script_path),
      "Re-running the template must not modify bin/workspace-setup"

    assert_rails_boots
  end
end
