require_relative "../test_helper"

class MinitestDifftasticTest < TemplateTestCase
  def test_minitest_difftastic
    create_rails_app
    apply_template("minitest-difftastic")

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "minitest-difftastic"/, gemfile)
    assert_equal 1, gemfile.scan(/gem "minitest-difftastic"/).count,
      "Expected exactly one minitest-difftastic gem entry in Gemfile"

    test_helper = File.read("#{@app_dir}/test/test_helper.rb")
    assert_match(/Minitest\.load\(:difftastic\) if Minitest\.respond_to\?\(:load\)/, test_helper,
      "test_helper must load the difftastic plugin guarded for Minitest 5/6")
    # The load line must come after Minitest is required, or it raises NameError
    assert_match(/require "rails\/test_help".*Minitest\.load\(:difftastic\)/m, test_helper,
      "Minitest.load must appear after require \"rails/test_help\"")

    # Idempotency: re-applying the template produces no further diff
    gemfile_before = File.read("#{@app_dir}/Gemfile")
    test_helper_before = File.read("#{@app_dir}/test/test_helper.rb")
    apply_template("minitest-difftastic")
    assert_equal gemfile_before, File.read("#{@app_dir}/Gemfile"),
      "Re-running the template must not modify the Gemfile"
    assert_equal test_helper_before, File.read("#{@app_dir}/test/test_helper.rb"),
      "Re-running the template must not modify test_helper.rb"

    assert_rails_boots
  end
end
