require_relative "../test_helper"

class DaisyuiTest < TemplateTestCase
  def test_daisyui
    create_rails_app
    apply_template("daisyui", env: {"TEMPLATES_BASE_URL" => "file://#{TEMPLATES_DIR}"})

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "tailwindcss-rails"/, gemfile)

    assert File.exist?("#{@app_dir}/lib/tasks/daisyui.rake")
    rake_content = File.read("#{@app_dir}/lib/tasks/daisyui.rake")
    assert_match(/namespace :daisyui/, rake_content)

    assert_rails_boots
  end
end
