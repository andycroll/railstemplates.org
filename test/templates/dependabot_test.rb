require_relative "../test_helper"

class DependabotTest < TemplateTestCase
  def test_dependabot_without_npm
    create_rails_app
    apply_template("dependabot")

    dependabot_yml = File.read("#{@app_dir}/.github/dependabot.yml")
    assert_match(/package-ecosystem: bundler/, dependabot_yml)
    refute_match(/package-ecosystem: npm/, dependabot_yml)
    assert_match(/package-ecosystem: github-actions/, dependabot_yml)
    assert_match(/cooldown:/, dependabot_yml)
    assert_match(/groups:/, dependabot_yml)
    assert_match(/interval: weekly/, dependabot_yml)

    assert File.exist?("#{@app_dir}/.github/workflows/dependabot-auto-merge.yml")
    automerge_yml = File.read("#{@app_dir}/.github/workflows/dependabot-auto-merge.yml")
    assert_match(/dependabot\/fetch-metadata/, automerge_yml)
    assert_match(/semver-patch/, automerge_yml)
    assert_match(/dependabot\[bot\]/, automerge_yml)

    assert_rails_boots
  end

  def test_dependabot_with_npm
    create_rails_app
    File.write("#{@app_dir}/package.json", '{"name":"test","version":"1.0.0"}')
    apply_template("dependabot")

    dependabot_yml = File.read("#{@app_dir}/.github/dependabot.yml")
    assert_match(/package-ecosystem: bundler/, dependabot_yml)
    assert_match(/package-ecosystem: npm/, dependabot_yml)
    assert_match(/package-ecosystem: github-actions/, dependabot_yml)

    # npm should have longer cooldowns
    npm_section = dependabot_yml.split("package-ecosystem: npm").last.split("package-ecosystem:").first
    assert_match(/default-days: 5/, npm_section)

    assert_rails_boots
  end
end
