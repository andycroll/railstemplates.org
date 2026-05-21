require_relative "../test_helper"

class ProcfileDevTest < TemplateTestCase
  def test_procfile_dev
    create_rails_app
    apply_template("procfile-dev")

    procfile_path = "#{@app_dir}/Procfile.dev"
    assert File.exist?(procfile_path), "Procfile.dev should be created"

    contents = File.read(procfile_path)
    assert_match(/RUBY_DEBUG_OPEN=true/, contents)
    assert_match(/^web: RUBY_DEBUG_OPEN=true bin\/rails server -p \$\{PORT:-3000\}/, contents)
    assert_match(/rdbg -A/, contents,
      "Header comment must document the rdbg -A attach command")

    # A fresh --minimal Rails app has neither tailwindcss-rails nor solid_queue,
    # so only the web process should be managed.
    refute_match(/^css:/, contents, "css: should be omitted without tailwindcss-rails")
    refute_match(/^jobs:/, contents, "jobs: should be omitted without solid_queue / bin/jobs")

    web_lines_before = contents.scan(/^web:/).count
    css_lines_before = contents.scan(/^css:/).count
    jobs_lines_before = contents.scan(/^jobs:/).count
    debug_env_before = contents.scan(/RUBY_DEBUG_OPEN=true/).count

    # Idempotency: re-applying the template must not duplicate any managed line.
    apply_template("procfile-dev")

    contents_after = File.read(procfile_path)
    assert_equal contents, contents_after,
      "Re-running the template must not modify Procfile.dev"
    assert_equal web_lines_before, contents_after.scan(/^web:/).count
    assert_equal css_lines_before, contents_after.scan(/^css:/).count
    assert_equal jobs_lines_before, contents_after.scan(/^jobs:/).count
    assert_equal debug_env_before, contents_after.scan(/RUBY_DEBUG_OPEN=true/).count

    assert_rails_boots
  end
end
