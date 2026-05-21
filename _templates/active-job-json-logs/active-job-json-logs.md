---
layout: template
title: ActiveJob JSON Logs
description: One structured JSON line per Active Job execution — replaces Rails' multi-line `Performing…`/`Performed…` output and the `[ActiveJob]` tag prefix
---

Installs a single `config/initializers/active_job_logging.rb` that collapses Rails' verbose multi-line Active Job logs into one JSON line per job execution. Active in `production` and `staging`; dev and test keep Rails' default Active Job logger.

No gem is added — this uses stdlib `ActiveSupport::Notifications`.

## What It Does

- Subscribes to `perform.active_job` and emits a single JSON line per job execution
- Filters job arguments through `Rails.application.config.filter_parameters` (records become GlobalIDs)
- Prepends `ActiveJob::Base#tag_logger` with a no-op so the `[ActiveJob] [JobClass] [job_id]` TaggedLogging prefix is gone from every line the job emits
- Detaches the default `ActiveJob::LogSubscriber` in production/staging so the classic `Performing… / Performed…` lines don't double up
- Wraps the detach/prepend in a `Rails.env.production? || Rails.env.staging?` guard so dev/test boot cleanly and you can still read the default logs when debugging locally

## Payload Shape

A typical job execution logs as one line:

```json
{
  "event": "job.perform",
  "job": "WelcomeEmailJob",
  "queue": "default",
  "attempt": 1,
  "job_id": "8d3a…",
  "request_id": "b1d2e5c6-…",
  "args": ["gid://app/User/42"],
  "duration_ms": 187,
  "status": "ok",
  "ready_backlog": 12
}
```

Fields that aren't applicable get dropped via `.compact`:

- `request_id` only appears when a `Current` model with `request_id` is set (see the Request-ID context template, [#31](https://github.com/andycroll/railstemplates.org/issues/31))
- `ready_backlog` only appears when SolidQueue is installed — `SolidQueue::ReadyExecution.count rescue nil`
- `error_class` only appears when the job raised — `status` flips to `"error"` in that case
- `args` is dropped when the job has no arguments

## Why These Defaults

- **One subscriber, one line.** The default Active Job logger emits a `Performing…` line, then any user log lines, then a `Performed…` line — three lines minimum per job. A single subscriber line is easier to parse, easier to count, and survives log aggregation cleanly.
- **No `[ActiveJob]` tag prefix.** Tagged logging prepends `[ActiveJob] [JobClass] [job_id]` to every line a job emits. That breaks JSON parsing for any structured line your job code writes. The no-op `tag_logger` prepend removes the prefix without losing context — the same fields appear in the subscriber line.
- **Production/staging only.** The detach + prepend run inside a `Rails.env.production? || Rails.env.staging?` guard so dev/test see the familiar default logs when you're debugging a job locally. The subscriber itself is registered in all environments — it's a no-op when no jobs fire.
- **`after_initialize` for the detach.** `ActiveJob::LogSubscriber` is loaded lazily; detaching it at boot before it's attached is a no-op. `after_initialize` makes the detach reliable.
- **Filtered args.** Hash arguments go through `ActiveSupport::ParameterFilter` so secrets in job payloads (`password`, `token`, `api_key`) are scrubbed using your existing `filter_parameters` config.
- **GlobalID for records.** ActiveRecord arguments serialize as `gid://app/Model/id` rather than dumping the whole object, keeping the line small and stable.

## Composition

- Soft prereq: the [Request-ID context template (#31)](https://github.com/andycroll/railstemplates.org/issues/31). Without it, `request_id` is dropped via `.compact` and you lose web↔job correlation.
- Coordinates with the [Rails.event JSON bridge template (#32)](https://github.com/andycroll/railstemplates.org/issues/32) on Rails 8.1+. That template's `JsonLogSubscriber` filters out Rails 8.1's `ActiveJob::StructuredEventSubscriber` events so they don't double-emit alongside this subscriber's line.

## Rails Version

Rails **8.1+** recommended (for clean framework-subscriber coordination with the Rails.event bridge). Works on earlier Rails — the framework filter just becomes irrelevant.

## Re-running Safely

The template is idempotent: if `config/initializers/active_job_logging.rb` already exists, it skips every step. Tweak the initializer directly — the template will not overwrite your edits.
