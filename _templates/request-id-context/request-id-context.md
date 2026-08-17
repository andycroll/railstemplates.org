---
layout: template
title: Request-ID Context
description: Per-request id propagation through Current, ApplicationJob, and ActiveSupport — plus a sensible filter_parameters baseline
---

Installs the small substrate every structured-log template depends on: a `Current.request_id` slot, request-id propagation through `ApplicationJob` (enqueue → serialize → deserialize → perform), a `SetCurrentRequestId` controller concern that populates both `Current` and `Rails.event` context, and a sensible `config/initializers/filter_parameter_logging.rb` baseline.

## What It Does

- **`app/models/current.rb`** — adds `attribute :request_id` to your `Current` class (creates the class if absent)
- **`app/jobs/application_job.rb`** — adds an `attr_accessor :request_id`, a `before_enqueue` hook capturing the current request id, `serialize`/`deserialize` overrides so the id rides through the job store, and a `perform_now` wrapper that re-establishes `Current.request_id` and `Rails.event` context for the duration of `perform`
- **`app/controllers/concerns/set_current_request_id.rb`** — a concern whose `before_action` copies `request.request_id` into `Current.request_id` and (when present) `Rails.event.set_context`
- **`app/controllers/application_controller.rb`** — gains one line: `include SetCurrentRequestId`
- **`config/initializers/filter_parameter_logging.rb`** — replaces Rails' stock single-line file with a three-layer baseline: short keyword fragments, common explicit names (webhook_secret, rails_master_key, totp, …), and a default-deny regex for any key ending in `token`, `secret`, `key`, `password`, `cookie`, or `authorization`

## Why These Defaults

- **`Current.request_id`, not a thread-local.** `ActiveSupport::CurrentAttributes` is reset between requests and propagates through `Current.set { ... }` blocks — exactly what you want when a job re-establishes the originating request id mid-perform.
- **`before_enqueue` + `serialize`/`deserialize`.** Capturing the id at enqueue time (rather than at perform time) means the id survives a retry: SolidQueue re-deserializes the same payload, and the job's log lines stay joined to the request that triggered it.
- **`perform_now` wrapper, not `around_perform`.** Wrapping `perform_now` rather than using an `around_perform` callback means `Rails.event.set_context` runs even if a subclass overrides `perform_now` directly (rare, but possible) and keeps the `Current.set` block syntactically obvious.
- **A concern, not a `before_action do` block in `ApplicationController`.** `ApplicationController` is a file you edit constantly. Anything injected there has to be recognised again on the next run by matching a string inside it — which stops working the moment someone reformats the block, and then a re-run happily injects a second copy. Putting the setter in `app/controllers/concerns/set_current_request_id.rb` reduces our footprint in your controller to one `include` line, makes the idempotency guard a file-existence check instead of a substring match, and makes removing it obvious.
- **Default-deny regex in `filter_parameters`.** A new gem or integration that adds a `stripe_secret_key` field gets filtered automatically, without anyone updating the list. Belt-and-braces alongside the explicit names.

## Idempotency

The template is safe to re-run. Each file edit uses a distinctive content marker as a guard:

- `Current` — skips if `attribute :request_id` is already present
- `ApplicationJob` — skips if `attr_accessor :request_id` is already present
- `SetCurrentRequestId` — created with `skip: true`, so your edits survive
- `ApplicationController` — skips if `include SetCurrentRequestId` is already present
- `filter_parameter_logging.rb` — skips if `:webhook_secret` is already present (our marker), preserving any hand-edits you made after running the template once

## Re-running Safely

If you've already customised any of these files, the template detects the marker and leaves your file alone. To re-pull the baseline, delete the relevant content (or the whole file in the case of the filter initializer) and re-run.

## Composition

This template is a foundation. The following templates read from `Current.request_id` and/or `Rails.application.config.filter_parameters`:

- ActiveJob JSON logs
- Rails.event JSON bridge
- ApplicationClient + outgoing-API JSON logs
- Lograge enhancements (reads `Current.user`, but pairs naturally with this)
