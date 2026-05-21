#!/usr/bin/env ruby

# Prosopite Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/prosopite/template
# Usage: rails app:template LOCATION=https://railstemplates.org/prosopite/template

say "railstemplates.org"
say "🔎 Installing Prosopite for N+1 detection...", :green

if File.exist?("config/initializers/prosopite.rb")
  say "Prosopite initializer already present, skipping.", :yellow
  return
end

# Detect Postgres adapter from config/database.yml. We inspect the file
# (rather than connecting) so the template works before a DB exists.
postgres_detected =
  if File.exist?("config/database.yml")
    database_yml = File.read("config/database.yml")
    database_yml.include?("adapter: postgresql") || database_yml.include?("postgresql")
  else
    false
  end

# Add gems to a single :development, :test group block when one exists,
# otherwise fall back to gem_group. This keeps the Gemfile tidy and
# matches the convention used by other templates in this repo.
def add_dev_test_gem(name, version: nil)
  gemfile = File.read("Gemfile")
  return if gemfile.include?(%(gem "#{name}"))

  gem_line = version ? %(  gem "#{name}", "#{version}"\n) : %(  gem "#{name}"\n)

  if gemfile.match?(/^group :development, :test do/)
    inject_into_file "Gemfile", gem_line, after: "group :development, :test do\n"
  else
    gem_group :development, :test do
      version ? gem(name, version) : gem(name)
    end
  end
end

add_dev_test_gem("prosopite")

if postgres_detected
  add_dev_test_gem("pg_query")
else
  say "Postgres not detected in config/database.yml — skipping pg_query.", :blue
end

after_bundle do
  initializer_body = <<~'RUBY'
    # Prosopite: catch N+1 queries automatically.
    #   - development: log warnings + auto-scan every request via Rack middleware
    #   - test:        raise Prosopite::NPlusOneQueriesError on first N+1
    #   - production:  no-op
    #
    # Tests still need to wrap work in `Prosopite.scan` / `Prosopite.finish`.
    # The simplest way is a setup/teardown pair in your base test case:
    #
    #   class ActiveSupport::TestCase
    #     setup    { Prosopite.scan }
    #     teardown { Prosopite.finish }
    #   end

    if Rails.env.development?
      require "prosopite/middleware/rack"

      Rails.application.config.after_initialize do
        Prosopite.rails_logger = true
        Prosopite.prosopite_logger = true
      end

      Rails.application.config.middleware.use(Prosopite::Middleware::Rack)
    elsif Rails.env.test?
      Rails.application.config.after_initialize do
        Prosopite.rails_logger = true
        Prosopite.raise = true
      end
    end
  RUBY

  create_file "config/initializers/prosopite.rb", initializer_body, skip: true

  say "✅ Prosopite installed. N+1s will warn in development and raise in test.", :green
  say "Wrap test work in Prosopite.scan / Prosopite.finish to enforce in CI.", :blue
end
