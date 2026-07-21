require_relative "../test_helper"

class StrongMigrationsTest < TemplateTestCase
  def test_strong_migrations
    create_rails_app
    apply_template("strong-migrations")

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "strong_migrations"/, gemfile)
    assert_equal 1, gemfile.scan(/gem "strong_migrations"/).count,
      "Expected exactly one strong_migrations gem entry in Gemfile"

    initializer_path = "#{@app_dir}/config/initializers/strong_migrations.rb"
    assert File.exist?(initializer_path)

    initializer = File.read(initializer_path)
    assert_match(/StrongMigrations\.start_after = 0/, initializer,
      "Fresh --minimal app has no migrations, so start_after should be 0")

    # Idempotency: re-applying the template produces no further diff
    gemfile_before = File.read("#{@app_dir}/Gemfile")
    initializer_before = File.read(initializer_path)
    apply_template("strong-migrations")
    assert_equal gemfile_before, File.read("#{@app_dir}/Gemfile"),
      "Re-running the template must not modify the Gemfile"
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify the initializer"

    assert_rails_boots
  end
end
