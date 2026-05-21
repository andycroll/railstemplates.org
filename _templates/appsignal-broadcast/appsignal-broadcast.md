---
layout: template
title: AppSignal broadcast logger
description: Compose Rails.logger to ship to STDOUT and AppSignal Logs at once, with sane filters and APM hygiene
---

Installs the [`appsignal`](https://github.com/appsignal/appsignal-ruby) gem and wires `Rails.logger` to broadcast to both STDOUT and AppSignal Logs in production. Every line lands in `journalctl` on the host **and** in AppSignal Logs as parsed JSON. Includes the operational sharp edges this composition needs to work in practice.

## What It Does

- Adds `gem "appsignal"` to the default group of your `Gemfile`
- Creates `config/appsignal.rb` with:
  - An `APPSIGNAL_FILTER_KEYS` baseline list of sensitive parameter and session keys
  - `Appsignal.configure` activating dev/staging/production, with `instrument_net_http` on
  - `filter_parameters` and `filter_session_data` pointed at `APPSIGNAL_FILTER_KEYS`
  - `ignore_actions << "Rails::HealthController#show"` so `/up` stays out of APM samples
- Creates `config/initializers/appsignal_filter_schema_events.rb` — prepends `AppsignalSchemaEventFilter` onto `Appsignal::Integrations::ActiveSupportNotificationsIntegration` to drop the duplicate `SCHEMA` `sql.active_record` events that AppSignal otherwise reads as N+1
- Appends a sentinel-guarded broadcast block to `config/environments/production.rb` that builds `Appsignal::Logger#broadcast_to(stdout_logger)` and wraps the result in `ActiveSupport::TaggedLogging`

## Why `Appsignal::Logger#broadcast_to`, not `ActiveSupport::BroadcastLogger`

`ActiveSupport::BroadcastLogger` looks like the obvious wrapper, but it conflicts with `TaggedLogging` once one leg is `Appsignal::Logger`. The supported composition is the other way round: AppSignal's logger broadcasts to STDOUT, and the whole thing is wrapped in TaggedLogging.

Each leg keeps its own level. `config.log_level = :info` only filters the AppSignal leg — the STDOUT logger is set explicitly with `level: log_level` (defaulting to `info`) to keep SolidQueue and friends from flooding `journalctl` at `:debug`.

`silence_healthcheck_path` has the same level-independence issue and is not used here. Healthcheck filtering happens via lograge's `ignore_actions` (see the [`lograge`](/lograge/) template) **and** AppSignal's own `ignore_actions` — both lists are needed.

## Filter Keys Sync Warning

AppSignal's parameter filter is **exact string match**. No regexes, no symbols, no fuzzy matching. That means `APPSIGNAL_FILTER_KEYS` in `config/appsignal.rb` has to be kept manually in sync with the matching list in `config/initializers/filter_parameter_logging.rb`. Every time you add an integration-specific key — `r2_secret_access_key`, `aws_secret_access_key`, `appsignal_push_api_key`, a platform-specific session cookie — add it to **both** lists.

The baseline shipped here covers the usual suspects: passwords, tokens, cookies, session ids, OTP/2FA codes, `rails_master_key`, SSN, CVV, salts, certificates.

## SCHEMA Event Filter

During connection setup, Rails publishes `sql.active_record` events at two nested `ActiveSupport::Notifications` levels with `payload[:name] == "SCHEMA"`. AppSignal's N+1 detector compares digests and reads the duplicate as a real N+1, polluting samples. The initializer prepends a module that returns early from `finish_event` for these and lets every other event through.

## Idempotency

Re-running the template is safe:

- `gem "appsignal"` is added only if `Gemfile` does not already include it
- `config/appsignal.rb` uses `create_file ..., skip: true`
- `config/initializers/appsignal_filter_schema_events.rb` uses `create_file ..., skip: true`
- The broadcast block in `config/environments/production.rb` is wrapped in sentinel markers (`# === appsignal-broadcast template start ===` / `# === appsignal-broadcast template end ===`) and is only appended when the start marker is absent

Edit the generated files directly — the template will not overwrite your changes.

## Composition

- Stacks with [`lograge`](/lograge/): lograge's single-line JSON requests flow through the composed logger, so they appear in both `journalctl` and AppSignal Logs.
- Stacks with `filter_parameter_logging.rb` (the matching baseline filter template) — keep `APPSIGNAL_FILTER_KEYS` and the Rails filter list in sync by hand.
- AppSignal silently no-ops without `APPSIGNAL_PUSH_API_KEY` set, so the STDOUT leg still works locally and in environments without an AppSignal key.

## Not Installed by This Template

- `appsignal demo` / push-API-key bootstrapping — AppSignal's own CLI handles that
- Setting `Appsignal.config.push_api_key` in code — use the `APPSIGNAL_PUSH_API_KEY` env var
- Sentry / Honeybadger / Datadog wiring — different add-on, different template
