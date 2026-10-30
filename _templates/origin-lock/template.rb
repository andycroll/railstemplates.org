#!/usr/bin/env ruby

# Origin Lock Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/origin-lock/template
# Usage: rails app:template LOCATION=https://railstemplates.org/origin-lock/template

say "railstemplates.org"
say "🔒 Locking the origin to Cloudflare traffic...", :green

if File.exist?("config/initializers/origin_lock.rb")
  say "origin_lock initializer already present, skipping.", :yellow
  return
end

create_file "config/initializers/origin_lock.rb", <<~'RUBY'
  # Rejects requests that did not come through Cloudflare.
  # Setup and rotation: https://railstemplates.org/origin-lock/
  class OriginLock
    OPEN_PATHS = %w[/up].freeze

    def initialize(app, secrets)
      @app = app
      @secrets = Array(secrets)

      raise ArgumentError, "OriginLock secrets must not be blank" if @secrets.empty? || @secrets.any?(&:blank?)
    end

    def call(env)
      sent = env.delete("HTTP_X_ORIGIN_LOCK").to_s

      if OPEN_PATHS.include?(env["PATH_INFO"]) || @secrets.any? { |secret| ActiveSupport::SecurityUtils.secure_compare(sent, secret) }
        @app.call(env)
      else
        [ 403, { "content-type" => "text/plain" }, [ "Forbidden" ] ]
      end
    end
  end

  if ENV["ORIGIN_LOCK_SECRET"].present?
    Rails.application.config.middleware.insert_before 0, OriginLock, ENV["ORIGIN_LOCK_SECRET"].split(",")
  end
RUBY

if File.exist?("test/test_helper.rb")
  create_file "test/initializers/origin_lock_test.rb", <<~'RUBY', skip: true
    require "test_helper"

    class OriginLockTest < ActiveSupport::TestCase
      SECRET = "s3cret"

      setup do
        @app = OriginLock.new(->(env) { [ 200, {}, [ env["HTTP_X_ORIGIN_LOCK"].to_s ] ] }, SECRET)
      end

      test "passes a request carrying the secret" do
        status, = call("/", "HTTP_X_ORIGIN_LOCK" => SECRET)

        assert_equal 200, status
      end

      test "strips the secret before the app sees it" do
        _, _, body = call("/", "HTTP_X_ORIGIN_LOCK" => SECRET)

        assert_equal [ "" ], body
      end

      test "passes a request carrying any accepted secret" do
        app = OriginLock.new(->(_env) { [ 200, {}, [] ] }, [ "old", "new" ])

        %w[old new].each do |key|
          status, = app.call(Rack::MockRequest.env_for("/", "HTTP_X_ORIGIN_LOCK" => key))

          assert_equal 200, status, key
        end
      end

      test "refuses to build with an empty secret" do
        [ "", " ", [ "old", "" ] ].each do |secrets|
          assert_raises(ArgumentError) { OriginLock.new(->(_env) { }, secrets) }
        end
      end

      test "rejects a request without the secret" do
        status, = call("/")

        assert_equal 403, status
      end

      test "rejects a request with the wrong secret" do
        status, = call("/", "HTTP_X_ORIGIN_LOCK" => "nope")

        assert_equal 403, status
      end

      test "lets health checks through without the secret" do
        OriginLock::OPEN_PATHS.each do |path|
          status, = call(path)

          assert_equal 200, status, path
        end
      end

      private

      def call(path, env = {})
        @app.call(Rack::MockRequest.env_for(path, env))
      end
    end
  RUBY
end

say "✅ OriginLock installed. It stays off until ORIGIN_LOCK_SECRET is set.", :green
say "Add the Cloudflare Transform Rule BEFORE setting ORIGIN_LOCK_SECRET, or every request gets a 403.", :blue
say "Setup steps: https://railstemplates.org/origin-lock/", :blue
