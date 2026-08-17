require_relative "../test_helper"

class LitestreamTest < TemplateTestCase
  def test_litestream
    create_rails_app
    apply_template("litestream")

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "litestream"/, gemfile)
    assert_equal 1, gemfile.scan(/gem "litestream"/).count,
      "Expected exactly one litestream gem entry in Gemfile"

    config_path = "#{@app_dir}/config/litestream.yml"
    assert File.exist?(config_path), "litestream:install generator should create config/litestream.yml"

    initializer_path = "#{@app_dir}/config/initializers/litestream.rb"
    assert File.exist?(initializer_path), "litestream:install generator should create the initializer"

    config = File.read(config_path)
    assert_match(/sync-interval: 10s/, config,
      "Template must inject the non-default sync-interval: 10s")
    assert_equal 1, config.scan(/sync-interval: 10s/).count,
      "Expected exactly one sync-interval per replica (the generator scaffolds one replica)"
    # The injected line is indented deeper than its `- type:` replica header,
    # so it stays inside the replica mapping and the YAML remains valid.
    assert_match(/^ {8}sync-interval: 10s/, config,
      "sync-interval should be indented to sit inside the replica mapping")

    # Idempotency: re-applying the template produces no further diff
    gemfile_before = File.read("#{@app_dir}/Gemfile")
    config_before = File.read(config_path)
    apply_template("litestream")
    assert_equal gemfile_before, File.read("#{@app_dir}/Gemfile"),
      "Re-running the template must not modify the Gemfile"
    assert_equal config_before, File.read(config_path),
      "Re-running the template must not modify config/litestream.yml (no double sync-interval)"
    assert_equal 1, File.read(config_path).scan(/sync-interval: 10s/).count,
      "Re-running the template must not inject a second sync-interval"

    assert_rails_boots
  end
end
