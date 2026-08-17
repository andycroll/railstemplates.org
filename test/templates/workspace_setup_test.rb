require_relative "../test_helper"
require "json"

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

    # The generated script has to be valid Ruby — it's never loaded by the suite
    assert system("ruby", "-c", script_path, out: File::NULL, err: File::NULL),
      "bin/workspace-setup must parse as Ruby"

    # Workspace-name fallback chain (literal references)
    assert_match(/WORKSPACE_NAME/, script)
    assert_match(/CONDUCTOR_WORKSPACE_NAME/, script)
    assert_match(/File\.basename\(Dir\.pwd\)/, script)

    # Main-checkout resolution: workspace manager's own env var, then git
    assert_match(/env_value\("CONDUCTOR_ROOT_PATH"\)/, script)
    assert_match(/env_value\("SUPERSET_ROOT_PATH"\)/, script)
    assert_match(/git worktree list --porcelain/, script)

    # Bundle/db:prepare routed through mise when it manages the repo
    assert_match(/def mise_prefix/, script)
    assert_match(/\["mise", "x", "--"\]/, script)
    assert_match(/system\(\*prefix, "bundle", "install"\)/, script)
    assert_match(/system\(\*prefix, "bin\/rails", "db:prepare"\)/, script)

    # Sentinel markers around the managed block
    assert_match(/workspace-setup managed start/, script)
    assert_match(/workspace-setup managed end/, script)

    # Deterministic port and Redis derivation
    assert_match(/SHA1/, script)
    assert_match(/3001/, script)

    # conductor.json in Conductor's own schema: named scripts it can invoke.
    # Written at apply time because Conductor reads it before a workspace (and
    # so before bin/workspace-setup ever runs) exists.
    conductor_path = "#{@app_dir}/conductor.json"
    assert File.exist?(conductor_path), "conductor.json should be created"

    conductor = JSON.parse(File.read(conductor_path))
    assert_equal "./bin/workspace-setup", conductor.dig("scripts", "setup")
    assert_equal "./bin/dev", conductor.dig("scripts", "run")
    assert_equal "nonconcurrent", conductor["runScriptMode"]

    # Idempotency: re-applying produces byte-identical files
    script_before = File.read(script_path)
    conductor_before = File.read(conductor_path)
    apply_template("workspace-setup")
    assert_equal script_before, File.read(script_path),
      "Re-running the template must not modify bin/workspace-setup"
    assert_equal conductor_before, File.read(conductor_path),
      "Re-running the template must not modify conductor.json"

    assert_rails_boots
  end
end
