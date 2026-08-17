---
layout: template
title: JSON Logger
description: Compose Rails.logger so every line lands on STDOUT as a bare JSON object — optionally broadcast to AppSignal Logs
---

Creates a single `config/initializers/json_logger.rb` that composes `Rails.logger` into a **JSON-lines logger**: one bare JSON object per line to STDOUT (journalctl) and, when the `appsignal` gem is present, to AppSignal Logs as well. Active in `production` (and `staging`, if that environment exists); dev and test keep Rails' default human-readable logger.

## This Is the Pipe, Not the Lines

This template installs **no subscribers**. It only makes sure that whatever your app logs arrives as parseable JSON. Pair it with the templates that produce the lines:

- [lograge](https://railstemplates.org/lograge/template) — one line per HTTP request
- [active-job-json-logs](https://railstemplates.org/active-job-json-logs/template) — one line per Active Job execution
- [application-client](https://railstemplates.org/application-client/template) — one line per outgoing external HTTP request
- [rails-event-json](https://railstemplates.org/rails-event-json/template) — one line per `Rails.event.notify`
- [debug-exceptions-json](https://railstemplates.org/debug-exceptions-json/template) — one line per unhandled exception

Each is independent. Install the pipe plus whichever lines you want.

## What It Does

- Creates `config/initializers/json_logger.rb`, which in `production`/`staging`:
  - Builds a STDOUT `Logger` with a **raw formatter** and an **explicit level** from `RAILS_LOG_LEVEL` (default `info`)
  - Wraps it in an `Appsignal::Logger` broadcast **when the gem is loaded**, otherwise uses STDOUT alone
  - Wraps the result in `ActiveSupport::TaggedLogging`
  - Assigns it to both `Rails.logger` and `Rails.application.config.logger`

## The Silent Gotchas It Encodes

Three non-obvious decisions, each of which quietly breaks JSON logs if you get it wrong by hand:

- **Raw STDOUT formatter.** `Logger`'s default formatter prepends `I, [2026-07-19T12:00:00#42] INFO -- : ` to every line, which turns a valid JSON object into something no aggregator can parse. The template installs a formatter that emits only `"#{msg}\n"`.
- **`Appsignal::Logger#broadcast_to`, not `ActiveSupport::BroadcastLogger`.** `BroadcastLogger` conflicts with `TaggedLogging` when one leg is an `Appsignal::Logger`. `broadcast_to` fans the same lines out to both destinations cleanly, and AppSignal's default `AUTODETECT` format sniffs each line as JSON.
- **Explicit STDOUT `level:`.** `Appsignal::Logger#add` writes to its broadcast targets *before* applying its own level filter, so `config.log_level` ends up filtering only the AppSignal leg. Without an explicit level, `Logger.new` defaults to `:debug` and debug chatter floods journalctl.

## Why `config.logger` Too

The initializer assigns the composed logger to `Rails.application.config.logger` as well as `Rails.logger`. Anything that reads `config.logger` later in the boot — including the lograge template's `config.lograge.logger = config.logger` — then picks up the composed logger instead of `nil`, so request lines flow through the same pipe as everything else rather than to lograge's own STDOUT logger.

## Optional AppSignal Logs Broadcast

The broadcast is **auto-detected** via `defined?(Appsignal::Logger)`. Add the `appsignal` gem and the AppSignal leg turns on; leave it out and the logger is a plain STDOUT logger. Nothing to configure either way. If `APPSIGNAL_PUSH_API_KEY` is unset, AppSignal silently no-ops and STDOUT still reaches journalctl.

## Health Checks

Health-check noise is **not** handled here. In a broadcast setup, `config.silence_healthcheck_path` and `Rails.logger.silence` only silence the AppSignal leg, not STDOUT — the level of each leg is independent. Filtering has to happen before the logger runs, which is why the [lograge](https://railstemplates.org/lograge/template) template owns it via `ignore_actions`.

## Re-running Safely

The template is idempotent: if `config/initializers/json_logger.rb` already exists, it skips every step. Tweak the initializer directly — the template will not overwrite your edits.
