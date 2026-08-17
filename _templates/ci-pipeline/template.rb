#!/usr/bin/env ruby

# CI Pipeline Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/ci-pipeline/template
# Usage: rails app:template LOCATION=https://railstemplates.org/ci-pipeline/template
#
# Wires Rails 8.1's ActiveSupport::ContinuousIntegration into a working
# GitHub Actions pipeline (scan_ruby, scan_js, lint, test, system-test).

say "railstemplates.org"
say "⚙️  Wiring bin/ci + config/ci.rb + GitHub Actions workflow...", :green

# 1. bin/ci — Ruby wrapper that boots Rails and loads config/ci.rb
bin_ci = <<~'RUBY'
  #!/usr/bin/env ruby
  require_relative "../config/boot"
  require "active_support/continuous_integration"

  CI = ActiveSupport::ContinuousIntegration
  require_relative "../config/ci.rb"
RUBY

create_file "bin/ci", bin_ci, skip: true
chmod "bin/ci", 0755

# 2. config/ci.rb — pipeline definition via ActiveSupport::ContinuousIntegration
ci_rb = <<~'RUBY'
  # Run using bin/ci

  CI.run do
    step "Setup", "bin/setup --skip-server"

    step "Style: Ruby", "bin/rubocop"

    step "Security: Gem audit", "bin/bundler-audit"
    step "Security: Importmap vulnerability audit", "bin/importmap audit"
    step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

    step "Tests: Rails", "bin/rails test"
    # Catches a seeds file that has drifted from the schema — a break you'd
    # otherwise only find the next time you set up a fresh machine.
    step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

    # System tests get their own parallel job in .github/workflows/ci.yml,
    # where the wall-clock is free. Locally they're the slowest thing in the
    # pipeline, so bin/ci leaves them out. Uncomment to run them here too.
    # step "Tests: System", "bin/rails test:system"

    # Optional: set a green GitHub commit status to unblock PR merge.
    # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
    # if success?
    #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
    # else
    #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
    # end
  end
RUBY

# Rails 8.1's `rails new` scaffolds a minimal config/ci.rb (setup + tests only).
# Replace it with the fuller pipeline — security scans and a seeds check — that
# mirrors the workflow below. Guarded so a re-run (and any file already carrying
# our Brakeman step) is left untouched.
if File.exist?("config/ci.rb") && File.read("config/ci.rb").include?('step "Security: Brakeman code analysis"')
  say "config/ci.rb already carries the full pipeline, skipping.", :yellow
else
  remove_file "config/ci.rb"
  create_file "config/ci.rb", ci_rb
end

# 3. .github/workflows/ci.yml — five parallel jobs
empty_directory ".github/workflows"

ci_yml = <<~'YAML'
  name: CI

  on:
    pull_request:
    push:
      branches: [ main ]

  jobs:
    scan_ruby:
      runs-on: ubuntu-latest

      steps:
        - name: Checkout code
          uses: actions/checkout@v7

        - name: Set up Ruby
          uses: ruby/setup-ruby@v1
          with:
            bundler-cache: true

        - name: Scan for common Rails security vulnerabilities using static analysis
          run: bin/brakeman --no-pager

        - name: Scan for known security vulnerabilities in gems used
          run: bin/bundler-audit

    scan_js:
      runs-on: ubuntu-latest

      steps:
        - name: Checkout code
          uses: actions/checkout@v7

        - name: Set up Ruby
          uses: ruby/setup-ruby@v1
          with:
            bundler-cache: true

        - name: Scan for security vulnerabilities in JavaScript dependencies
          run: bin/importmap audit

    lint:
      runs-on: ubuntu-latest
      env:
        RUBOCOP_CACHE_ROOT: tmp/rubocop
      steps:
        - name: Checkout code
          uses: actions/checkout@v7

        - name: Set up Ruby
          uses: ruby/setup-ruby@v1
          with:
            bundler-cache: true

        - name: Prepare RuboCop cache
          uses: actions/cache@v6
          env:
            DEPENDENCIES_HASH: ${{ hashFiles('.ruby-version', '**/.rubocop.yml', '**/.rubocop_todo.yml', 'Gemfile.lock') }}
          with:
            path: ${{ env.RUBOCOP_CACHE_ROOT }}
            key: rubocop-${{ runner.os }}-${{ env.DEPENDENCIES_HASH }}-${{ github.ref_name == github.event.repository.default_branch && github.run_id || 'default' }}
            restore-keys: |
              rubocop-${{ runner.os }}-${{ env.DEPENDENCIES_HASH }}-

        - name: Lint code for consistent style
          run: bin/rubocop -f github

    test:
      runs-on: ubuntu-latest

      # services:
      #  redis:
      #    image: valkey/valkey:8
      #    ports:
      #      - 6379:6379
      #    options: --health-cmd "redis-cli ping" --health-interval 10s --health-timeout 5s --health-retries 5
      steps:
        - name: Checkout code
          uses: actions/checkout@v7

        - name: Set up Ruby
          uses: ruby/setup-ruby@v1
          with:
            bundler-cache: true

        - name: Run tests
          env:
            RAILS_ENV: test
            # RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
            # REDIS_URL: redis://localhost:6379/0
          run: bin/rails db:test:prepare test

    system-test:
      runs-on: ubuntu-latest

      # services:
      #  redis:
      #    image: valkey/valkey:8
      #    ports:
      #      - 6379:6379
      #    options: --health-cmd "redis-cli ping" --health-interval 10s --health-timeout 5s --health-retries 5
      steps:
        - name: Checkout code
          uses: actions/checkout@v7

        - name: Set up Ruby
          uses: ruby/setup-ruby@v1
          with:
            bundler-cache: true

        - name: Run System Tests
          env:
            RAILS_ENV: test
            # RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
            # REDIS_URL: redis://localhost:6379/0
          run: bin/rails db:test:prepare test:system

        - name: Keep screenshots from failed system tests
          uses: actions/upload-artifact@v7
          if: failure()
          with:
            name: screenshots
            path: ${{ github.workspace }}/tmp/screenshots
            if-no-files-found: ignore
YAML

# A full `rails new` scaffolds a four-job ci.yml (no system-test job). Replace it
# with our five-job workflow, guarded so a re-run leaves the installed file alone.
if File.exist?(".github/workflows/ci.yml") && File.read(".github/workflows/ci.yml").include?("system-test:")
  say ".github/workflows/ci.yml already carries the five-job workflow, skipping.", :yellow
else
  remove_file ".github/workflows/ci.yml"
  create_file ".github/workflows/ci.yml", ci_yml
end

say ""
say "✅ CI pipeline installed.", :green
say ""
say "📋 What's next:", :blue
say "   • Run locally:           bin/ci"
say "   • Push to GitHub:        the five-job workflow runs on PRs and pushes to main"
say "   • Add services (Redis, Postgres) by uncommenting the services: blocks in ci.yml"
say ""
say "⚠️  Requires Rails 8.1+ (ActiveSupport::ContinuousIntegration).", :yellow
