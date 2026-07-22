require_relative "../test_helper"

class CoverageCommentsTest < TemplateTestCase
  def test_coverage_comments
    create_rails_app
    # First apply simplecov (prerequisite)
    apply_template("simplecov-rails")

    apply_template("coverage-comments", env: {"TEMPLATES_BASE_URL" => "file://#{TEMPLATES_DIR}"})

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "simplecov-json"/, gemfile)

    test_helper = File.read("#{@app_dir}/test/test_helper.rb")
    assert_match(/require "simplecov-json"/, test_helper)
    assert_match(/JSONFormatter/, test_helper)

    assert File.exist?("#{@app_dir}/.github/scripts/analyze_coverage.rb")

    assert_rails_boots
  end
end
