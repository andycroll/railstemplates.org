---
layout: template
title: Lograge
description: Structured JSON production logs with request_id, filtered params, and Current.user — one line per request
---

Installs [Lograge](https://github.com/roidrage/lograge) and a single `config/initializers/lograge.rb` that collapses Rails' verbose multi-line request logs into one JSON line per request. Active in `production` (and `staging`, if that environment exists); dev and test keep the default Rails logger.

## What It Does

- Adds the `lograge` gem to your `Gemfile` (default group, so it's loadable everywhere but only enabled where you want it)
- Creates `config/initializers/lograge.rb` with:
  - `Lograge::Formatters::Json.new` — the format every modern log aggregator expects
  - A runtime guard: the whole file short-circuits outside of `production` / `staging`
  - A `custom_payload` that adds `params`, `path`, `request_id`, and `user_id`
  - `ignore_actions: ["Rails::HealthController#show"]` so `/up` stops dominating your logs
  - `base_controller_class = "ActionController::API"` when the app is API-only

## Payload Shape

A typical request logs as one line:

```json
{
  "method": "POST",
  "path": "/messages",
  "format": "html",
  "controller": "MessagesController",
  "action": "create",
  "status": 302,
  "duration": 48.21,
  "view": 0.0,
  "db": 9.87,
  "params": { "message": { "body": "hello" } },
  "request_id": "b1d2e5c6-…",
  "user_id": 42
}
```

`user_id` only appears when `Current.user` is set on the request — apps without a `Current` class continue to log cleanly without it.

## Why These Defaults

- **JSON, not KeyValue.** Log aggregators (Datadog, CloudWatch, Loki, Papertrail, Axiom) parse JSON natively. `KeyValue` ends up as one giant unparseable field.
- **`request.filtered_parameters`, not `event.payload[:params]`.** The raw event payload is _unfiltered_ — logging it directly leaks passwords and other secrets redacted by `Rails.application.config.filter_parameters`. Using the controller's request respects your filter list automatically.
- **`request.filtered_path`.** Same reason, for query-string tokens.
- **Per-request `Current.user` guard.** Autoloading makes boot-time `defined?(Current)` unreliable, so the lookup happens per request, wrapped in `rescue StandardError` so a broken accessor never takes down request logging.
- **`base_controller_class` only for API apps.** Without it, lograge silently no-ops on `ActionController::API` requests.

## Re-running Safely

The template is idempotent: if `config/initializers/lograge.rb` already exists, it skips every step. Tweak the initializer directly — the template will not overwrite your edits.
