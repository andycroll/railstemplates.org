#!/usr/bin/env ruby

# Strong Migrations Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/strong-migrations/template
# Usage: rails app:template LOCATION=https://railstemplates.org/strong-migrations/template

say "railstemplates.org"
say "🛡  Configuring Strong Migrations safety net...", :green

unless File.read("Gemfile").include?('"strong_migrations"')
  gem "strong_migrations"
end

after_bundle do
  initializer_path = "config/initializers/strong_migrations.rb"

  if File.exist?(initializer_path)
    say "Strong Migrations initializer already present, skipping.", :yellow
  else
    migration_files = Dir.glob("db/migrate/*.rb")
    start_after = migration_files
      .map { |path| File.basename(path)[/\A(\d+)/, 1].to_i }
      .max || 0

    initializer_body = <<~RUBY
      # Strong Migrations guards against risky schema changes (adding NOT NULL
      # columns to large tables, renaming columns, blocking locks, backfilling
      # inside the same migration, etc.) before they reach production.
      #
      # start_after pins the cutoff to the highest migration version that
      # existed when this initializer was generated. Migrations at or below
      # this timestamp are treated as pre-existing and skipped; new migrations
      # are checked. Bump this value only when you intentionally want to
      # silence checks on a freshly added migration.
      StrongMigrations.start_after = #{start_after}
    RUBY

    create_file initializer_path, initializer_body
    say "✅ Strong Migrations configured (start_after = #{start_after}).", :green
  end
end
