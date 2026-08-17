---
layout: template
title: DebugExceptions JSON
description: One JSON line per unhandled controller exception instead of Rails' multi-line "Class (message):" + annotated source + backtrace block
---

Replaces `ActionDispatch::DebugExceptions#log_error`'s default multi-line block with a single structured JSON line in `production` (and `staging`, if that environment exists). Dev and test keep the default multi-line output, which is genuinely useful when you're staring at the exception in your terminal.

## The Problem

When an unhandled exception escapes a controller, Rails' default `log_error` emits something like:

```
NoMethodError (undefined method `foo' for nil:NilClass):

app/controllers/posts_controller.rb:42:in `show'
... 30+ lines of annotated source and backtrace ...
```

Every line-oriented log aggregator — AppSignal Logs, Better Stack, Loki, CloudWatch, Papertrail — misreads the trailing backtrace lines as separate events. Your "one error" becomes thirty malformed log entries, and the JSON formatter you carefully set up for the request log can't parse a single one of them.

## What It Does

- Creates `config/initializers/debug_exceptions_json.rb`
- Defines a `DebugExceptionsJson` module that overrides `log_error(request, wrapper)` to emit one JSON line via `Rails.logger.info`
- Prepends the module onto `ActionDispatch::DebugExceptions` inside `Rails.application.config.after_initialize` — and only when `Rails.env.production?` or `Rails.env.staging?`
- Adds no gem

## Line Shape

```json
{"event":"request.exception","method":"GET","path":"/posts/42","remote_ip":"1.2.3.4","request_id":"abc-123","exception":"NoMethodError","message":"undefined method foo for nil:NilClass","status":500}
```

Fields:

- `event` — always `"request.exception"`, so a single filter pulls every exception line
- `method`, `path` — `request.filtered_path` respects `config.filter_parameters` so query-string tokens don't leak
- `remote_ip`, `request_id` — the same `request_id` you log on the successful request line, for correlation
- `exception`, `message`, `status` — what failed and the HTTP status the user saw

`.compact` strips any nil values (e.g., `remote_ip` from a request that didn't have one) so the line stays clean.

## Why No Backtrace

Backtraces are deliberately not in this line. They belong in an APM — AppSignal Errors, Sentry, Honeybadger, Bugsnag — which is designed for "where in the code did this happen" and groups occurrences by fingerprint. Your log aggregator is for "did this request fail and how"; mixing the two responsibilities is what produced the multi-line mess in the first place.

If you're not running an APM, install one before adopting this template. Otherwise you'll lose visibility into stack traces.

## Why the Production/Staging Gate

The whole point of `DebugExceptions` is that it's _debug-friendly_ in development — you see the annotated source, the backtrace, the surrounding code. Replacing that with a single JSON line in development would be a regression in DX. The template gates the prepend on `Rails.env.production? || Rails.env.staging?` so dev/test keep Rails' default behavior untouched.

## Pairs Well With

- [Lograge](/lograge/) — collapses successful request logs to JSON. This template covers the failing-request case Lograge doesn't.

## Re-running Safely

Idempotent: if `config/initializers/debug_exceptions_json.rb` already exists, the template skips every step. Edit the initializer directly — the template will not overwrite your changes.
