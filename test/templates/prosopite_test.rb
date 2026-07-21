require_relative "../test_helper"

class ProsopiteTest < TemplateTestCase
  def test_prosopite
    create_rails_app
    apply_template("prosopite")

    gemfile = File.read("#{@app_dir}/Gemfile")
    assert_match(/gem "prosopite"/, gemfile)
    assert_equal 1, gemfile.scan(/gem "prosopite"/).count,
      "Expected exactly one prosopite gem entry in Gemfile"

    # Default --minimal Rails app uses SQLite, so pg_query must NOT be added
    refute_match(/gem "pg_query"/, gemfile,
      "pg_query must not be added when Postgres is not detected")

    initializer_path = "#{@app_dir}/config/initializers/prosopite.rb"
    assert File.exist?(initializer_path)

    initializer = File.read(initializer_path)
    assert_match(/Rails\.env\.development\?/, initializer)
    assert_match(/Rails\.env\.test\?/, initializer)
    assert_match(/Prosopite\.raise = true/, initializer,
      "test environment must raise on N+1")
    assert_match(/Prosopite::Middleware/, initializer,
      "development must register the Rack middleware")
    assert_match(/Prosopite\.rails_logger = true/, initializer,
      "development must log via Rails logger")

    # Idempotency: re-applying the template produces no further diff
    initializer_before = File.read(initializer_path)
    apply_template("prosopite")
    gemfile_after = File.read("#{@app_dir}/Gemfile")
    assert_equal 1, gemfile_after.scan(/gem "prosopite"/).count,
      "Re-running the template must not add prosopite again"
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify the initializer"

    assert_rails_boots
  end
end
