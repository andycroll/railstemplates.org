---
layout: template
title: Structured Logging
description: One bare JSON object per log line to STDOUT/journalctl — jobs, external HTTP, Rails.event, and exceptions — optionally broadcast to AppSignal Logs
---

Creates a single `config/initializers/structured_logging.rb` that turns your **non-request** logs into one bare JSON object per line — Active Job executions, outgoing external HTTP requests, `Rails.event` app events, and unhandled exceptions. Each line goes to STDOUT (journalctl) and, when the `appsignal` gem is present, is broadcast to AppSignal Logs too. Active in `production` (and `staging`, if that environment exists); dev and test keep the default Rails logger.

## Umbrella — Use Instead of the À La Carte Templates

This template is an **umbrella**: it bundles the same subscribers that several single-purpose templates install on their own. Installing both doubles the output, because each initializer registers its own subscriber. Choose **either** this umbrella **or** the individual templates below — not both:

- [active-job-json-logs](https://railstemplates.org/active-job-json-logs/template) — its `perform.active_job` subscriber is already included here.
- [rails-event-json](https://railstemplates.org/rails-event-json/template) — its `Rails.event` subscriber is already included here.
- [debug-exceptions-json](https://railstemplates.org/debug-exceptions-json/template) — its JSON exception prepend is already included here.

If you also run [application-client](https://railstemplates.org/application-client/template), keep its `ApplicationClient` base class but delete the `config/initializers/application_client_logging.rb` it ships — this template already subscribes to `request.application_client`, so keeping both doubles the external-API lines.

## Pairs With Lograge

This template is **complementary** to the [Lograge template](https://railstemplates.org/lograge/template), which already emits one JSON line per HTTP request. It assumes lograge (or an equivalent) owns the per-request line and does **not** re-configure it. What this adds on top:

- A **broadcast logger** that both lograge's request lines and the subscribers below flow through — STDOUT plus, optionally, AppSignal Logs.
- **Structured subscribers** for the events lograge doesn't cover: background jobs, external API calls, `Rails.event`, and exceptions.

Install both for full-coverage JSON logs. Lograge already ignores `/up` via `ignore_actions`, so health-check noise is handled there.

## What It Does

- Creates `config/initializers/structured_logging.rb` with:
  - A **JSON-lines logger** composed in `production`/`staging`: a raw-formatted STDOUT logger, optionally wrapped in an `Appsignal::Logger` broadcast, then `ActiveSupport::TaggedLogging`.
  - A `perform.active_job` subscriber — one JSON line per job execution with `queue`, `attempt`, `duration_ms`, `status`, and a filtered `args` list (records as GlobalIDs, hashes routed through `filter_parameters`), plus a cheap `ready_backlog` snapshot when SolidQueue is present.
  - A `request.application_client` subscriber — one JSON line per outgoing external HTTP request (a no-op until the app has an `ApplicationClient`).
  - A `Rails.event` subscriber — bridges every `Rails.event.notify(name, **fields)` into a JSON line, with a Rails 8.1 framework-namespace early-return to avoid duplicate lines.
  - A `DebugExceptionsJson` prepend (production only) — one JSON line per unhandled exception instead of the default multi-line backtrace dump.

## Payload Shape

A background job logs as one line:

```json
{
  "event": "job.perform",
  "job": "DeliverEmailJob",
  "queue": "default",
  "attempt": 1,
  "job_id": "a1b2c3d4-…",
  "args": ["gid://app/User/42"],
  "duration_ms": 128,
  "status": "ok",
  "ready_backlog": 3
}
```

An unhandled exception logs as:

```json
{
  "event": "request.exception",
  "method": "GET",
  "path": "/orders/999",
  "request_id": "b1d2e5c6-…",
  "exception": "ActiveRecord::RecordNotFound",
  "message": "Couldn't find Order with 'id'=999",
  "status": 404
}
```

## The Silent Gotchas It Encodes

Four non-obvious decisions the initializer bakes in — each of which silently breaks JSON logs if you get it wrong by hand:

- **Raw STDOUT formatter.** `Logger`'s default formatter prepends `I, [2026-07-19T…#pid] INFO -- :` to every line, which turns each line into invalid JSON. The template installs a formatter that emits only `"#{msg}\n"`, so every line is a bare JSON object your aggregator can parse.
- **`Appsignal::Logger#broadcast_to`, not `ActiveSupport::BroadcastLogger`.** `BroadcastLogger` conflicts with `TaggedLogging` when one leg is an `Appsignal::Logger`. `broadcast_to` fans the same lines out to both STDOUT and AppSignal Logs cleanly; AppSignal's default `AUTODETECT` format sniffs each line as JSON.
- **Explicit STDOUT `level:`.** `Appsignal::Logger#add` writes to broadcast targets *before* applying its own level filter, so `config.log_level` only filters the AppSignal leg. Without an explicit level on the STDOUT logger, it defaults to `:debug` and SolidQueue's polling lines flood journalctl every poll cycle. The template sets it from `RAILS_LOG_LEVEL` (default `info`).
- **Ignoring `/up`.** Health checks would otherwise dominate the request log — but that's handled by the **lograge** template's `ignore_actions`, not here. (In this broadcast setup, `config.silence_healthcheck_path` and `Rails.logger.silence` only silence the AppSignal leg, not STDOUT — `ignore_actions` short-circuits before the logger runs, which is why lograge owns it.)

## Optional AppSignal Logs Broadcast

The broadcast is **auto-detected**: if `Appsignal::Logger` is defined (i.e. the `appsignal` gem is loaded), lines are broadcast to AppSignal Logs in addition to STDOUT. If it isn't, the logger is a plain STDOUT logger and everything still works. There's nothing to configure — add the `appsignal` gem and the broadcast leg turns on. If `APPSIGNAL_PUSH_API_KEY` is unset, AppSignal silently no-ops and STDOUT still reaches journalctl.

## Guarded Couplings

The template applies cleanly to a **vanilla** Rails app — every integration is optional and guarded:

- `SolidQueue::ReadyExecution.count` is guarded with `defined?` + `rescue` — apps without SolidQueue log without `ready_backlog`.
- `Current.request_id` is guarded with `defined?`/`respond_to?` — apps without a `Current` class log without `request_id`.
- The `request.application_client` subscriber is registered but is a no-op until the app has an `ApplicationClient` that instruments the event.
- `Rails.event` is guarded, so pre-8.1 apps skip that subscriber.
- `ActiveJob::LogSubscriber.detach_from` and the tagging/exception prepends only apply in `production`.

## Re-running Safely

The template is idempotent: if `config/initializers/structured_logging.rb` already exists, it skips every step. Tweak the initializer directly — the template will not overwrite your edits.
