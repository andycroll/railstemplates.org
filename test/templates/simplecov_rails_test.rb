require_relative "../test_helper"

class SimplecovRailsTest < TemplateTestCase
  def test_simplecov_rails
    create_rails_app
    apply_template("simplecov-rails")

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "simplecov"/, gemfile)
    assert_equal 1, gemfile.scan(/group :test do/).count, "Expected exactly one group :test block in Gemfile"

    test_helper = File.read("#{@app_dir}/test/test_helper.rb")
    assert_match(/require "simplecov"/, test_helper)
    assert_match(/SimpleCov\.start/, test_helper)
    assert_match(/enable_coverage :branch/, test_helper)

    # Verify parallelization hooks are indented to match class TestCase
    assert_match(/^    if ENV\["CI"\].*\n      parallelize_setup/m, test_helper,
      "parallelize_setup should be indented inside class TestCase")
    assert_match(/^      parallelize_teardown/, test_helper,
      "parallelize_teardown should be indented inside class TestCase")

    gitignore = File.read("#{@app_dir}/.gitignore")
    assert_match(%r{/coverage/}, gitignore)

    assert_rails_boots
  end
end
