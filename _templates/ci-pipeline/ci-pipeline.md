---
layout: template
title: CI Pipeline
description: bin/ci wrapper, config/ci.rb pipeline DSL, and a five-job GitHub Actions workflow built on Rails 8.1's ActiveSupport::ContinuousIntegration
---

Wires Rails 8.1's [`ActiveSupport::ContinuousIntegration`](https://api.rubyonrails.org/classes/ActiveSupport/ContinuousIntegration.html) DSL into a working GitHub Actions pipeline. Installs a `bin/ci` runner that mirrors what your CI executes, a `config/ci.rb` that declares the pipeline once for both local and CI use, and a `.github/workflows/ci.yml` with parallel jobs for scans, lint, tests, and system tests.

## Requires Rails 8.1+

`ActiveSupport::ContinuousIntegration` ships in Rails 8.1. Earlier Rails versions will fail to boot `bin/ci`.

## What It Does

- Creates `bin/ci` — an executable Ruby wrapper that boots Rails and loads the pipeline.
- Creates `config/ci.rb` — pipeline definition using `CI.run do step "name", "command" end`: setup, RuboCop, three security scans, `bin/rails test`, and a `db:seed:replant` seeds check.
- Creates `.github/workflows/ci.yml` with five parallel jobs:
  - `scan_ruby` — Brakeman static analysis + `bundler-audit` for gem CVEs.
  - `scan_js` — `bin/importmap audit` for JavaScript dependency CVEs.
  - `lint` — `bin/rubocop`, with a RuboCop cache keyed on `.ruby-version`, `**/.rubocop.yml`, `**/.rubocop_todo.yml`, and `Gemfile.lock`.
  - `test` — `bin/rails db:test:prepare test`.
  - `system-test` — `bin/rails db:test:prepare test:system`, uploading `tmp/screenshots` as an artifact on failure.

## Why bin/ci + config/ci.rb

A single declaration of "what CI does" lives in `config/ci.rb` and gets executed both ways:

- **Locally**, you run `bin/ci` before pushing — same steps, same order, same exit codes.
- **On GitHub Actions**, each job runs the relevant `bin/...` command directly so they parallelise. The workflow and `config/ci.rb` stay in sync because both call the same `bin/` scripts.

## Two Deliberate Asymmetries

- **System tests run in CI, not in `bin/ci`.** In the workflow they're their own job, so their wall-clock overlaps everything else and costs you nothing. Locally they're the slowest step by a wide margin, and a pre-push check you avoid running is worse than one that skips a job. The step ships commented out in `config/ci.rb` — uncomment it if you want it locally.
- **A seeds check that CI doesn't run.** `env RAILS_ENV=test bin/rails db:seed:replant` catches a `db/seeds.rb` that has drifted from the schema, which otherwise only surfaces the next time someone sets up a fresh machine. It's cheap locally and needs a writable test database, so it lives in `bin/ci`.

## Idempotency

Rails 8.1's `rails new` already scaffolds a minimal `config/ci.rb` (setup + tests only), and a full app also writes a four-job `.github/workflows/ci.yml` with no system-test job. This template replaces both with the fuller versions described above, then leaves them alone on a re-run — detected via the Brakeman step in `config/ci.rb` and the `system-test` job in the workflow. `bin/ci` is byte-identical to the Rails default, so it's created with `skip: true`. Tweak `config/ci.rb` to add steps; modify the workflow to add services (Redis, Postgres) or environment variables.

## Dogfooding

[railstemplates.org](https://github.com/andycroll/railstemplates.org) itself uses this pipeline.
