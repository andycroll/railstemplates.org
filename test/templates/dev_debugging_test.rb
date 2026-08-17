require_relative "../test_helper"

class DevDebuggingTest < TemplateTestCase
  def test_dev_debugging
    create_rails_app
    apply_template("dev-debugging")

    gemfile = File.read("#{@app_dir}/Gemfile")
    %w[debug debugbar web-console rack-mini-profiler].each do |name|
      assert_match(/gem "#{Regexp.escape(name)}"/, gemfile,
        "Expected gem #{name.inspect} in Gemfile")
      assert_equal 1, gemfile.scan(/gem "#{Regexp.escape(name)}"/).count,
        "Expected exactly one #{name.inspect} entry in Gemfile"
    end

    initializer_path = "#{@app_dir}/config/initializers/rack_mini_profiler.rb"
    assert File.exist?(initializer_path), "Expected rack_mini_profiler.rb initializer to exist"

    initializer = File.read(initializer_path)
    assert_match(/Rails\.env\.development\?/, initializer)
    assert_match(/Rack::MiniProfiler\.config/, initializer)

    # Layout must NOT be modified by the template — Debugbar mount is a manual step
    layout_path = "#{@app_dir}/app/views/layouts/application.html.erb"
    assert File.exist?(layout_path), "Expected default Rails layout to exist"
    layout = File.read(layout_path)
    refute_match(/debugbar/, layout,
      "Template must not patch application.html.erb — mount instruction is emitted via `say` only")

    # Idempotency: re-applying produces no further diff
    initializer_before = File.read(initializer_path)
    apply_template("dev-debugging")

    gemfile_after = File.read("#{@app_dir}/Gemfile")
    %w[debug debugbar web-console rack-mini-profiler].each do |name|
      assert_equal 1, gemfile_after.scan(/gem "#{Regexp.escape(name)}"/).count,
        "Re-running the template must not add #{name} again"
    end
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify the initializer"
    refute_match(/debugbar/, File.read(layout_path),
      "Re-running the template must not patch the layout")

    assert_rails_boots
  end
end
