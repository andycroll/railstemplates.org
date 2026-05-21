---
layout: template
title: Prosopite N+1 Detection
description: Catch N+1 queries automatically — warn in development, raise in test, no-op in production
---

Installs [Prosopite](https://github.com/charkost/prosopite) and a single `config/initializers/prosopite.rb` that turns N+1 detection into a build-time signal. N+1s become test failures in CI, log warnings in local development, and stay out of the way in production.

## What It Does

- Adds the `prosopite` gem to your `Gemfile` (development + test groups)
- Adds the `pg_query` gem (also dev + test) when `config/database.yml` indicates Postgres — Prosopite needs it to deduplicate queries on PG; SQLite and MySQL skip this
- Creates `config/initializers/prosopite.rb` with:
  - **Development:** loads the Rack middleware (`Prosopite::Middleware::Rack`) so every request is scanned, and writes warnings to a dedicated log
  - **Test:** raises `Prosopite::NPlusOneQueriesError` the moment an N+1 is seen — your test suite is the enforcement layer
  - **Production:** no-op. Prosopite is never auto-scanning live traffic.

## Why These Defaults

- **Raise in test, warn in dev.** A noisy warning is easy to ignore; a red test is not. The whole point of the template is to make N+1s impossible to merge.
- **Rack middleware in dev only.** Auto-scanning every request is great for catching incidental N+1s while you click around, but it has measurable overhead. Production traffic never pays it.
- **`pg_query` gated on adapter.** Prosopite's Postgres backend requires `pg_query` to fingerprint queries. Bundling it on SQLite/MySQL apps wastes a native extension build and confuses the dependency graph.
- **Adapter detected from `config/database.yml`.** No runtime database connection needed — the template inspects the file Rails ships with.

## Catching N+1s in Tests

The initializer sets `Prosopite.rails_logger = true` and `Prosopite.raise = true` under `Rails.env.test?`, but tests still need to opt in per case (or globally) by wrapping the work in `Prosopite.scan` / `Prosopite.finish`. The simplest way is a `setup` / `teardown` pair in your base test case:

```ruby
class ActiveSupport::TestCase
  setup    { Prosopite.scan }
  teardown { Prosopite.finish }
end
```

Any N+1 inside a test now raises `Prosopite::NPlusOneQueriesError` with the offending queries and the backtrace.

## Re-running Safely

The template is idempotent. If `config/initializers/prosopite.rb` already exists, it skips every step. If the `prosopite` gem is already in your `Gemfile`, it skips the gem additions. Edit the initializer freely — the template will not overwrite your changes.
