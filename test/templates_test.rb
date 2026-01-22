require_relative "test_helper"

class TemplatesTest < Minitest::Test
  def setup
    FileUtils.mkdir_p(TMP_DIR)
    @app_dir = File.join(TMP_DIR, "app_#{Process.pid}_#{Time.now.to_i}")
  end

  def teardown
    FileUtils.rm_rf(@app_dir) if @app_dir && File.exist?(@app_dir)
  end

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

  def test_simplecov_rails
    create_rails_app
    apply_template("simplecov-rails")

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "simplecov"/, gemfile)

    test_helper = File.read("#{@app_dir}/test/test_helper.rb")
    assert_match(/require "simplecov"/, test_helper)
    assert_match(/SimpleCov\.start/, test_helper)
    assert_match(/enable_coverage :branch/, test_helper)

    gitignore = File.read("#{@app_dir}/.gitignore")
    assert_match(%r{/coverage/}, gitignore)

    assert_rails_boots
  end

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
