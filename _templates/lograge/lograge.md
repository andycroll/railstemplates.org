---
layout: template
title: Lograge
description: Structured JSON production logs with request_id, workspace_id, remote_ip, and an event constant — one line per request
---

Installs [Lograge](https://github.com/roidrage/lograge) and a single `config/initializers/lograge.rb` that collapses Rails' verbose multi-line request logs into one JSON line per request. Active in `production` (and `staging`, if that environment exists); dev and test keep the default Rails logger.

## What It Does

- Adds the `lograge` gem to your `Gemfile` (default group, so it's loadable everywhere but only enabled where you want it)
- Creates `config/initializers/lograge.rb` with:
  - `Lograge::Formatters::Json.new` — the format every modern log aggregator expects
  - A runtime guard: the whole file short-circuits outside of `production` / `staging`
  - A `custom_payload` with `request_id`, `user_id`, `workspace_id`, and `remote_ip`
  - A `custom_options` lambda that stamps `event: "request"` on every line and includes `filtered_params` on 4xx/5xx responses
  - `ignore_actions: ["Rails::HealthController#show"]` so `/up` stops dominating your logs
  - `config.lograge.logger = Rails.application.config.logger` so request lines flow through a composed `Rails.logger` (e.g., AppSignal broadcasts) rather than lograge's own STDOUT logger

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
  "event": "request",
  "request_id": "b1d2e5c6-…",
  "user_id": 42,
  "workspace_id": 7,
  "remote_ip": "203.0.113.10"
}
```

`user_id` and `workspace_id` only appear when the corresponding `current_*` accessor returns a value — apps without those concepts continue to log cleanly without them. `params` is added automatically when the response status is `>= 400` so you can debug bad requests without flooding successful traffic.

## Why These Defaults

- **JSON, not KeyValue.** Log aggregators (Datadog, CloudWatch, Loki, Papertrail, Axiom) parse JSON natively. `KeyValue` ends up as one giant unparseable field.
- **`event: "request"` constant.** Pairs with `event=job.perform`, `event=external_api.request`, and `event=request.exception` from sibling templates so log queries can filter by `event:*` regardless of which subscriber produced the line.
- **`workspace_id` alongside `user_id`.** Multi-tenant log queries don't need to JOIN through `user_id`. The template tries `current_workspace`, `current_account`, then `current_organization` and uses whichever the app exposes.
- **`remote_ip`.** Without it, every production request looks like it came from Cloudflare's edge. If `cloudflare-rails` is installed, `request.remote_ip` is already corrected; otherwise it's the raw remote address.
- **`ignore_actions: Rails::HealthController#show`.** Uptime monitors and edge healthchecks hit `/up` every few seconds. Logging each one drowns real traffic. `ignore_actions` short-circuits inside `RequestLogSubscriber` before the formatter or logger run, so this works even when `Rails.logger` is composed with broadcast legs that keep their own levels.
- **`filtered_params` only on errors.** The lambda adds `params` to the payload only when `status >= 400` — already redacted by `filter_parameter_logging` so secrets don't leak.
- **`config.lograge.logger = Rails.application.config.logger`.** Without this, lograge writes to its own STDOUT logger and bypasses any composed `Rails.logger` (e.g., the AppSignal broadcast template).
- **`.compact` + `.try` everywhere.** The initializer boots cleanly when `Current`, `current_user`, or `current_workspace` are absent — missing keys are dropped, not nil-ed into the JSON.

## Re-running Safely

The template is idempotent:

- If `config/initializers/lograge.rb` is absent, it installs fresh.
- If the file matches the shape this template last shipped (including the prior #22 shape), it upgrades in place.
- If the file has been hand-edited away from any known shape, the template warns and leaves it alone. Diff against this template's source if you want to pull the new fields in by hand.
