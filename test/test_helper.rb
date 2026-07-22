require "bundler"
require "minitest/autorun"
require "fileutils"

TEMPLATES_DIR = File.expand_path("../_templates", __dir__)
TMP_DIR = File.expand_path("../tmp/test_apps", __dir__)

class TemplateTestCase < Minitest::Test
  def setup
    FileUtils.mkdir_p(TMP_DIR)
    @app_dir = File.join(TMP_DIR, "app_#{Process.pid}_#{Time.now.to_i}")
  end

  def teardown
    FileUtils.rm_rf(@app_dir) if @app_dir && File.exist?(@app_dir)
  end

  private

  def create_rails_app
    system("bundle exec rails new #{@app_dir} --minimal -q") or raise "Failed to create Rails app"
  end

  def apply_template(name, env: {})
    template_path = File.join(TEMPLATES_DIR, name, "template.rb")
    raise "Template not found: #{template_path}" unless File.exist?(template_path)

    Bundler.with_unbundled_env do
      Dir.chdir(@app_dir) do
        system(env, "bundle exec rails app:template LOCATION=#{template_path}") or raise "Failed to apply template: #{name}"
      end
    end
  end

  def assert_rails_boots
    Bundler.with_unbundled_env do
      Dir.chdir(@app_dir) do
        output = `bundle exec rails runner "puts 'BOOT_OK'" 2>&1`
        assert_includes output, "BOOT_OK", "Rails failed to boot: #{output}"
      end
    end
  end
end
