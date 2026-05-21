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

  def test_email_image_tag
    create_rails_app
    apply_template("email-image-tag")

    assert File.exist?("#{@app_dir}/app/helpers/email_helper.rb")
    helper = File.read("#{@app_dir}/app/helpers/email_helper.rb")
    assert_match(/email_image_tag/, helper)
    assert_match(/attachments\.inline/, helper)

    assert_rails_boots
  end

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

  def test_lograge
    create_rails_app
    apply_template("lograge")

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "lograge"/, gemfile)
    assert_equal 1, gemfile.scan(/gem "lograge"/).count, "Expected exactly one lograge gem entry in Gemfile"

    initializer_path = "#{@app_dir}/config/initializers/lograge.rb"
    assert File.exist?(initializer_path)

    initializer = File.read(initializer_path)
    assert_match(/Rails\.env\.production\?/, initializer)
    assert_match(/Rails\.env\.staging\?/, initializer)
    assert_match(/Lograge::Formatters::Json\.new/, initializer)
    assert_match(/custom_payload/, initializer)
    assert_match(/filtered_parameters/, initializer)
    assert_match(/filtered_path/, initializer)
    assert_match(/request_id/, initializer)
    assert_match(/user_id/, initializer)
    assert_match(/Current/, initializer)
    assert_match(/Rails::HealthController#show/, initializer)
    refute_match(/event\.payload\[:params\]/, initializer,
      "Must not log unfiltered event.payload[:params] — leaks secrets")

    # Idempotency: re-applying the template produces no further diff
    initializer_before = File.read(initializer_path)
    apply_template("lograge")
    gemfile_after = File.read("#{@app_dir}/Gemfile")
    assert_equal 1, gemfile_after.scan(/gem "lograge"/).count,
      "Re-running the template must not add lograge again"
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify the initializer"

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

  def test_appsignal_broadcast
    create_rails_app
    apply_template("appsignal-broadcast")

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "appsignal"/, gemfile)
    assert_equal 1, gemfile.scan(/gem "appsignal"/).count,
      "Expected exactly one appsignal gem entry in Gemfile"

    appsignal_rb_path = "#{@app_dir}/config/appsignal.rb"
    assert File.exist?(appsignal_rb_path), "config/appsignal.rb missing"
    appsignal_rb = File.read(appsignal_rb_path)
    assert_match(/APPSIGNAL_FILTER_KEYS\s*=/, appsignal_rb)
    assert_match(/Appsignal\.configure do \|config\|/, appsignal_rb)
    assert_match(/activate_if_environment/, appsignal_rb)
    assert_match(/filter_parameters\s*=\s*APPSIGNAL_FILTER_KEYS/, appsignal_rb)
    assert_match(/filter_session_data\s*=\s*APPSIGNAL_FILTER_KEYS/, appsignal_rb)
    assert_match(/Rails::HealthController#show/, appsignal_rb)

    schema_filter_path = "#{@app_dir}/config/initializers/appsignal_filter_schema_events.rb"
    assert File.exist?(schema_filter_path), "appsignal_filter_schema_events.rb missing"
    schema_filter = File.read(schema_filter_path)
    assert_match(/module AppsignalSchemaEventFilter/, schema_filter)
    assert_match(/sql\.active_record/, schema_filter)
    assert_match(/SCHEMA/, schema_filter)
    assert_match(/singleton_class\.prepend\(AppsignalSchemaEventFilter\)/, schema_filter)

    production_path = "#{@app_dir}/config/environments/production.rb"
    production_rb = File.read(production_path)
    assert_match(/# === appsignal-broadcast template start ===/, production_rb)
    assert_match(/# === appsignal-broadcast template end ===/, production_rb)
    assert_match(/Appsignal::Logger\.new\("rails"\)/, production_rb)
    assert_match(/broadcast_to\(stdout_logger\)/, production_rb)
    assert_match(/ActiveSupport::TaggedLogging\.new\(appsignal_logger\)/, production_rb)
    assert_equal 1, production_rb.scan(/appsignal-broadcast template start/).count,
      "Sentinel start marker should appear exactly once"

    # Idempotency: re-applying produces no further diff
    appsignal_rb_before = File.read(appsignal_rb_path)
    schema_filter_before = File.read(schema_filter_path)
    production_rb_before = File.read(production_path)

    apply_template("appsignal-broadcast")

    gemfile_after = File.read("#{@app_dir}/Gemfile")
    assert_equal 1, gemfile_after.scan(/gem "appsignal"/).count,
      "Re-running the template must not add appsignal again"
    assert_equal appsignal_rb_before, File.read(appsignal_rb_path),
      "Re-running the template must not modify config/appsignal.rb"
    assert_equal schema_filter_before, File.read(schema_filter_path),
      "Re-running the template must not modify the schema-event filter initializer"
    production_rb_after = File.read(production_path)
    assert_equal production_rb_before, production_rb_after,
      "Re-running the template must not modify config/environments/production.rb"
    assert_equal 1, production_rb_after.scan(/appsignal-broadcast template start/).count,
      "Re-running the template must not duplicate the sentinel block"

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
