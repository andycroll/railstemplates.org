require_relative "../test_helper"
require "yaml"

class LitestreamTest < TemplateTestCase
  def test_litestream
    create_rails_app

    # A --minimal app has no Solid Queue and so no config/recurring.yml. Write
    # one with a production: key so the verification schedule has somewhere to go.
    recurring_path = "#{@app_dir}/config/recurring.yml"
    File.write(recurring_path, <<~YAML)
      production:
        existing_entry:
          command: "Rails.logger.info('untouched')"
          schedule: every hour
    YAML

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

    # The gem's own verification job, scheduled daily under the existing
    # production: key. An unread replica isn't a backup, and the 10s
    # sync-interval widens the window a silent replication failure hides in.
    recurring = File.read(recurring_path)
    assert_match(/class: Litestream::VerificationJob/, recurring)
    assert_match(/schedule: every day at 1am UTC/, recurring)
    assert_match(/^  litestream_backup_verification:$/, recurring,
      "entry should be indented as a child of production:")
    assert_match(/existing_entry:/, recurring,
      "existing recurring entries must be preserved")
    assert_equal 1, recurring.scan(/^production:$/).count,
      "must reuse the existing production: key rather than adding a second"

    # Both entries must parse as siblings under production: — a mis-indented
    # injection would still match the regexes above while nesting one inside
    # the other.
    parsed = YAML.safe_load(recurring)
    assert_equal %w[litestream_backup_verification existing_entry].sort,
      parsed["production"].keys.sort
    assert_equal "Litestream::VerificationJob",
      parsed.dig("production", "litestream_backup_verification", "class")
    assert_equal "every day at 1am UTC",
      parsed.dig("production", "litestream_backup_verification", "schedule")

    # Idempotency: re-applying the template produces no further diff
    gemfile_before = File.read("#{@app_dir}/Gemfile")
    config_before = File.read(config_path)
    recurring_before = File.read(recurring_path)
    apply_template("litestream")
    assert_equal recurring_before, File.read(recurring_path),
      "Re-running the template must not modify config/recurring.yml"
    assert_equal 1, File.read(recurring_path).scan(/Litestream::VerificationJob/).count,
      "Re-running the template must not schedule a second verification job"
    assert_equal gemfile_before, File.read("#{@app_dir}/Gemfile"),
      "Re-running the template must not modify the Gemfile"
    assert_equal config_before, File.read(config_path),
      "Re-running the template must not modify config/litestream.yml (no double sync-interval)"
    assert_equal 1, File.read(config_path).scan(/sync-interval: 10s/).count,
      "Re-running the template must not inject a second sync-interval"

    assert_rails_boots
  end
end
