require_relative "../test_helper"

class StandardRbTest < TemplateTestCase
  def test_standard_rb
    create_rails_app
    apply_template("standard-rb")

    gemfile = File.read("#{@app_dir}/Gemfile")
    refute_match(/rubocop-rails-omakase/, gemfile)
    assert_match(/gem "standard"/, gemfile)

    assert File.exist?("#{@app_dir}/.rubocop.yml")
    rubocop_yml = File.read("#{@app_dir}/.rubocop.yml")
    assert_match(/require:/, rubocop_yml)
    assert_match(/- standard/, rubocop_yml)
    assert_match(/inherit_gem:/, rubocop_yml)

    assert_rails_boots
  end
end
