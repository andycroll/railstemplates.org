---
layout: template
title: Rails.event JSON Bridge
description: One JSON line per Rails.event.notify, with the Rails 8.1 framework events filtered out so they don't double-log
---

Installs a single `config/initializers/rails_event_json_logging.rb` that subscribes to [`Rails.event`](https://api.rubyonrails.org/classes/Rails/Event.html) (new in Rails 8.1) and writes every `Rails.event.notify(...)` call as one flat JSON line on `Rails.logger`. The framework's own `StructuredEventSubscriber` namespaces are filtered out so a request, SQL query, or background job doesn't produce a duplicate JSON line on top of what `lograge` (or the default Rails logger) already emits.

## Requirements

- **Rails 8.1+** (`Rails.event` was introduced in 8.1). No gem is added — `Rails.event` ships with the framework.

## What It Does

- Creates `config/initializers/rails_event_json_logging.rb` defining a `JsonLogSubscriber` class
- Calls `Rails.event.subscribe(JsonLogSubscriber.new)` so every `Rails.event.notify("name", **payload)` in your app code becomes a single JSON line
- Skips any event whose name starts with one of the Rails framework's own `StructuredEventSubscriber` namespaces:

  ```
  action_controller  action_dispatch  action_view  action_mailer
  active_record      active_storage   active_job   active_support
  ```

After applying:

```ruby
Rails.event.notify("avatar.fetched", id: 42, bytes: 18_321)
```

logs:

```json
{"event":"avatar.fetched","id":42,"bytes":18321}
```

## Why The Framework-Namespace Filter Matters

Rails 8.1 ships `StructuredEventSubscriber` classes for `action_controller`, `action_dispatch`, `action_view`, `action_mailer`, `active_record`, `active_storage`, `active_job`, and `active_support`. They auto-attach at gem load and **republish every `ActiveSupport::Notifications` event through `Rails.event`**.

Without the namespace filter, every request, every SQL statement, every Active Storage upload, and every Active Job perform would emit a second JSON line on top of whatever Rails (or lograge) is already writing. The signal you care about — your own `Rails.event.notify` calls — would drown in framework noise.

The filter lives **inside** the subscriber rather than detaching the framework subscribers. That keeps third-party listeners (e.g. AppSignal's `Appsignal::Hooks::ActiveSupportEventReporterHook`, which subscribes separately) untouched.

## Payload Shape

The subscriber merges, in order:

1. `event: <name>`
2. `event[:payload]` (your `notify` kwargs)
3. `event[:tags]` when non-empty
4. `event[:context]` when non-empty
5. `source_location:` when Rails 8.1 attaches one (on by default in dev/test, off in production)

`Rails.application.config.filter_parameters` redaction is applied by `Rails.event` *before* this subscriber sees the payload, so sensitive keys like `token` or `password` show up as `[FILTERED]` without any work from you.

## Composition

- **Stacks with [Lograge](/lograge/).** Lograge writes request lines via `ActiveSupport::Notifications` directly, not through `Rails.event`, so they aren't filtered by this subscriber and don't double-emit.
- **Stacks with `Request-ID` context** (issue #31). When `ApplicationController` / `ApplicationJob` call `Rails.event.set_context(request_id: ...)`, that context is automatically merged into every JSON line.
- **Stacks with ActiveJob / outgoing-API JSON loggers** (issue #34). Those templates call `Rails.logger.info(hash.to_json)` directly, not via `Rails.event`, so they aren't routed through this subscriber and don't duplicate.

## Re-running Safely

The template is idempotent: if `config/initializers/rails_event_json_logging.rb` already exists, it skips. Tweak the initializer directly — the template will not overwrite your edits.
