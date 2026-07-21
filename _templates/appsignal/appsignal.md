---
layout: template
title: AppSignal
description: APM + error monitoring for Rails — the gem generates config/appsignal.rb, then this template adds a healthcheck filter and a curated redaction list
---

Installs [AppSignal](https://docs.appsignal.com/ruby/) for application performance monitoring and error tracking. The `appsignal` gem generates its own `config/appsignal.rb` — the exact file its installer produces — and this template then inserts a small set of "required" defaults into it. The agent auto-instruments Rails (controllers, ActiveRecord, ActiveJob, ActionView, ActionCable, ActionMailer) and outgoing `Net::HTTP` calls, so you get request/job traces and exception reports with no per-controller work. Active in `production` only; dev and test stay quiet.

## What It Does

- Adds the `appsignal` gem to your `Gemfile` (default group, so it's loadable everywhere but only *active* where you configure it)
- Runs the gem's own config generator to write `config/appsignal.rb` with `activate_if_environment("production")` and your app's `config.name` (e.g. `MyApp`), so the base file always matches the installed gem version
- Drops the empty `push_api_key` line the generator writes — the key is read from the `APPSIGNAL_PUSH_API_KEY` environment variable instead
- Inserts into the generated `Appsignal.configure` block:
  - `config.ignore_actions << "Rails::HealthController#show"` — keeps high-volume healthcheck pings out of your APM samples
  - A curated `filter_parameters` / `filter_session_data` redaction list (see below)
- Creates `config/initializers/appsignal_filter_schema_events.rb`, which drops Rails' duplicated `SCHEMA` query events so AppSignal doesn't flag them as a false N+1 during connection setup

## Setup After Install

AppSignal needs a Push API key to report. Set it in your production environment:

```bash
APPSIGNAL_PUSH_API_KEY=your-push-api-key
```

That's the gem's own recommended approach — no key is written into the repo, and the app boots cleanly everywhere the variable is absent (dev, test, CI). Grab the key from your [AppSignal](https://appsignal.com/) app settings.

## Redaction

AppSignal's parameter filter does an **exact string match** — symbols and regexes do not work, so full key names are required. The template inserts a hand-curated list covering the usual suspects:

```ruby
config.filter_parameters = %w[
  password password_confirmation
  secret api_key access_token refresh_token bearer_token
  authorization cookie set_cookie x_csrf_token csrftoken
  sessionid session_id client_id client_secret webhook_secret
  signed_id otp totp two_factor_code
  appsignal_push_api_key rails_master_key
  ssn cvv cvc certificate salt
]
config.filter_session_data = config.filter_parameters
```

The same list is applied to session data, controller params, captured `Net::HTTP` query strings, and ActiveJob arguments. Add project-specific keys directly — the template will not overwrite your edits.

## Why These Defaults

- **The gem generates the base file.** Rather than shipping a hand-maintained copy of `config/appsignal.rb` that can drift from the gem, the template invokes the gem's own generator so the base config always matches the installed version. It then inserts only the extra defaults every app wants.
- **Everything in `config/appsignal.rb`.** AppSignal starts *before* your Rails initializers run (so it can catch boot-time errors), which means config set in a `config/initializers/*.rb` file is read too late to take effect. The healthcheck filter and the redaction list therefore go into the one config file the gem loads on start, not a separate initializer.
- **`activate_if_environment`, not raw `active`.** AppSignal only starts in the environments you name, so dev and test never phone home or consume quota.
- **Healthcheck ignored.** Load balancers hit `/up` constantly; recording each as an APM sample is pure noise that dilutes your throughput and response-time graphs, so `Rails::HealthController#show` is excluded up front.
- **Curated exact-match redaction.** AppSignal's filter requires full key names, so a copy-paste from the docs that uses symbols or regexes silently redacts nothing. The list here is applied to both params and session data, kept in sync via `filter_session_data = filter_parameters`.
- **Push API key from the environment.** The generator writes an empty `push_api_key`, which the template removes — the key belongs in `APPSIGNAL_PUSH_API_KEY` (the gem's own recommendation), so nothing sensitive lands in the repo.
- **SCHEMA events filtered.** During connection setup Rails emits its `SCHEMA` queries at two nested instrumentation levels; AppSignal reads the duplicate digest as an N+1 and would flag a phantom issue on every boot. The initializer drops the SCHEMA event so the false positive never fires. It's a small module prepend — a code patch, not config — so it correctly lives in an initializer.

## Pairs Well With

AppSignal also has a Logs product: pair this template with the [lograge](/lograge/) template plus a broadcast logger and your structured request logs can ship to AppSignal Logs alongside the APM and error data. This template stays focused on installing AppSignal with sensible required defaults; host-specific extras (like tagging each report with a deploy revision from your platform's release variable) belong in a companion template.

## Re-running Safely

The template is idempotent: if `config/appsignal.rb` already exists, it skips every step, and the `appsignal` gem is only added when it isn't already in the `Gemfile`. Re-running never overwrites your edits.
