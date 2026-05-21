---
layout: template
title: Strong Migrations
description: Catch unsafe migrations before they hit production — adds strong_migrations with start_after pinned to your current schema
---

Installs [strong_migrations](https://github.com/ankane/strong_migrations) and a `config/initializers/strong_migrations.rb` that pins `start_after` to the highest existing migration version. New migrations are checked for risky operations (adding `NOT NULL` columns to large tables, renaming columns, blocking locks, backfilling in the same migration, and more); your existing migrations stay untouched.

## What It Does

- Adds the `strong_migrations` gem to your `Gemfile` (default group, so it runs in development and CI)
- Creates `config/initializers/strong_migrations.rb` with:
  - `StrongMigrations.start_after = <current max migration version>` — every migration timestamp at or below this value is treated as "pre-existing" and never re-checked

## Why `start_after`

Strong Migrations runs its safety checks on every migration in your `db/migrate` directory. Without `start_after`, retrofitting it onto an existing app lights up your history with errors that you can't fix without rewriting committed migrations. Setting `start_after` to the largest current timestamp tells strong_migrations: "trust everything up to and including this point; police everything new from here on."

The template computes the value by scanning `db/migrate/*.rb` and taking the largest numeric prefix. A fresh app with no migrations gets `start_after = 0`.

## What You'll See

Once installed, generating a risky migration fails fast with an actionable message:

```
=== Dangerous operation detected #strong_migrations ===

Adding a NOT NULL column without a default is not safe. Use safer steps:
  1. Add the column without NOT NULL
  2. Backfill the column
  3. Add the NOT NULL constraint
```

Each warning links to a remediation recipe in the [strong_migrations README](https://github.com/ankane/strong_migrations#checks).

## Re-running Safely

The template is idempotent:

- The gem is added only if `strong_migrations` is not already in your `Gemfile`.
- The initializer is created only if `config/initializers/strong_migrations.rb` does not already exist.

Tweak `start_after` directly after install — the template will not overwrite your edits.
