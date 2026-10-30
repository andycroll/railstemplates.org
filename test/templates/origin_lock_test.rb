require_relative "../test_helper"

class OriginLockTest < TemplateTestCase
  def test_origin_lock
    create_rails_app
    apply_template("origin-lock")

    initializer_path = "#{@app_dir}/config/initializers/origin_lock.rb"
    assert File.exist?(initializer_path)

    initializer = File.read(initializer_path)
    assert_match(/class OriginLock/, initializer)
    assert_match(/OPEN_PATHS = %w\[\/up\]/, initializer)
    assert_match(/env\.delete\("HTTP_X_ORIGIN_LOCK"\)/, initializer)
    assert_match(/ActiveSupport::SecurityUtils\.secure_compare/, initializer)
    assert_match(/if ENV\["ORIGIN_LOCK_SECRET"\]\.present\?/, initializer)
    assert_match(/middleware\.insert_before 0, OriginLock, ENV\["ORIGIN_LOCK_SECRET"\]\.split\(","\)/, initializer)

    assert File.exist?("#{@app_dir}/test/initializers/origin_lock_test.rb")

    # Idempotency: re-applying the template produces no further diff
    initializer_before = File.read(initializer_path)
    apply_template("origin-lock")
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify the initializer"

    assert_rails_boots
    assert_generated_tests_pass
    assert_middleware_installed_when_secret_set
  end

  private

  def assert_generated_tests_pass
    Bundler.with_unbundled_env do
      Dir.chdir(@app_dir) do
        output = `bundle exec rails test test/initializers/origin_lock_test.rb 2>&1`
        assert_match(/7 runs, \d+ assertions, 0 failures, 0 errors/, output, "Generated tests failed: #{output}")
      end
    end
  end

  def assert_middleware_installed_when_secret_set
    Bundler.with_unbundled_env do
      Dir.chdir(@app_dir) do
        output = `ORIGIN_LOCK_SECRET=old,new bundle exec rails runner "puts Rails.application.middleware.first.klass" 2>&1`
        assert_includes output, "OriginLock", "OriginLock must sit first in the stack: #{output}"
      end
    end
  end
end
