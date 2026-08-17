---
layout: template
title: ApplicationClient + outgoing-API JSON logs
description: A reusable base class for outgoing HTTP integrations with one JSON log line per request — host, path, status, duration, attempt, and optional plan-quota headers
---

Installs a single `ApplicationClient` base class (based on the [jumpstart-pro-rails `ApplicationClient`](https://github.com/jumpstart-pro/jumpstart-pro-rails/blob/main/app/clients/application_client.rb)) plus an `ActiveSupport::Notifications` subscriber that emits one JSON line per outgoing HTTP request. Subclass it once per integration; get parseable logs for free.

## What It Installs

Two files, both idempotent:

- `app/clients/application_client.rb` — the base class. Wraps `Net::HTTP`, normalises errors into a small retry-friendly hierarchy (`Inaccessible`, `Transient`, `RateLimit`, `QuotaExceeded`), and instruments every request with `ActiveSupport::Notifications.instrument("request.application_client", …)`.
- `config/initializers/application_client_logging.rb` — subscribes to `request.application_client` and writes one JSON line to `Rails.logger` per outgoing request.

No gem is added — `Net::HTTP` ships with Ruby.

## Example Client

```ruby
class DigitalOceanClient < ApplicationClient
  BASE_URI = "https://api.digitalocean.com/v2"

  def account
    get("/account").account
  rescue *NETWORK_ERRORS
    raise Error, "Unable to load your account"
  end

  def droplets(per_page: 50)
    with_pagination("/droplets", query: { per_page: per_page }) do |response|
      yield response.droplets
      response.links.dig(:pages, :next)
    end
  end
end

# Usage:
client = DigitalOceanClient.new(token: ENV["DIGITAL_OCEAN_TOKEN"])
client.account
```

The base class handles:

- JSON parsing of response bodies (override `Response::PARSER` for XML or HTML)
- Bearer-token auth by default (override `authorization_header` for `X-API-Key`, `AccessKey`, etc.)
- Link-header pagination via `with_pagination`
- A normalised error hierarchy: rescue `NETWORK_ERRORS` for transport failures, `Transient` for retry-worthy responses, `Inaccessible` for terminal 4xx, `RateLimit` for 420/429 (with `reset_at`), and `QuotaExceeded` (a `RateLimit` subclass) for daily/monthly plan exhaustion.

## Log Line Shape

One JSON line is emitted per request to `Rails.logger.info`:

```json
{
  "event": "external_api.request",
  "klass": "DigitalOceanClient",
  "method": "GET",
  "host": "api.digitalocean.com",
  "path": "/v2/account",
  "status": 200,
  "duration_ms": 142,
  "attempt": 1,
  "quota_remaining": 4998,
  "quota_limit": 5000,
  "quota_reset": 1700000000,
  "request_id": "b1d2e5c6-…"
}
```

`quota_*` only appear when the upstream sends RapidAPI-style `X-RateLimit-Requests-Remaining` / `*-Limit` / `*-Reset` headers. `request_id` only appears when [Request-ID context]({{ '/request-id-context/' | relative_url }}) is installed — otherwise it's dropped from the line via `.compact`. `error_class` is added on exceptions.

## What's NOT in the Line

Intentionally:

- **No URL query string.** Query params commonly contain API tokens, user identifiers, or filter criteria that are noisy and sometimes sensitive.
- **No request body.** Bodies can contain PII, credentials, or large blobs that swamp your log line.
- **No response body.** Same reason. Also: response bodies are often large.
- **No request or response headers.** They contain auth tokens and rarely tell you anything aggregating logs by `klass + status + host` doesn't already.

For request-body debugging, use an APM (Datadog, New Relic, Honeybadger Insights) — they sample request bodies safely and let you opt into per-request capture. This template gives you the high-volume, queryable signal; APM gives you the deep, sampled signal. They compose.

## Two Refinements from Upstream

This template tracks the [jumpstart-pro-rails source](https://github.com/jumpstart-pro/jumpstart-pro-rails/blob/main/app/clients/application_client.rb) with two divergences:

1. **`JSON_OBJECT_CLASS = nil`** (was `OpenStruct`). `OpenStruct` is [deprecated in Ruby 3.4+](https://docs.ruby-lang.org/en/3.4/OpenStruct.html); `nil` returns a plain `Hash`. Subclasses that want method-style access can opt back in with `Response::PARSER["application/json"] = ->(r) { JSON.parse(r.body, object_class: OpenStruct) }`.
2. **Tighter `link_header` regex** (`<(.+?)>` not `<(.+)>`). The greedy version mis-parses multi-link responses; the non-greedy version matches each `<…>` separately.

## Querying Your Logs

With every outgoing call shaped identically you can ask things like:

- "Show me every 429 from `stripe.com` in the last hour, grouped by `klass`."
- "Which integration is closest to its quota right now?" (`quota_remaining / quota_limit < 0.10`)
- "What's the p95 `duration_ms` for `OpenAIClient` GET requests this week?"
- "For request `request_id=xyz`, what external calls did we make?"

Without a structured client base, those queries require grepping multiple log shapes or scraping APM samples.

## Out of Scope

- **Connection pooling.** `Net::HTTP` defaults are fine for most apps. If you're saturating a single host, drop in `net-http-persistent` and tune from there.
- **Quota-low alerting.** The base class captures `quota_remaining` / `quota_limit` / `quota_reset` in the log line. Routing those to an alert is your app's call — bolt on a `Rails.event.notify("external_api.quota_low", …)` subscriber when `quota_remaining / quota_limit < 0.10`.
- **Body redaction.** This template doesn't log request or response bodies at all, so there's nothing to redact.

## Composition

- Soft pairs with [Request-ID context]({{ '/request-id-context/' | relative_url }}). Without it, `request_id` is absent from the log line — you lose the web↔external-API correlation but everything else still works.
- Independent of other templates. The subscriber writes to `Rails.logger` directly; no `Rails.event` involvement.

## Re-running Safely

The template is idempotent. If `app/clients/application_client.rb` or `config/initializers/application_client_logging.rb` already exists, that file is skipped — your edits survive. Each file is checked independently, so re-running after deleting one of them re-installs only the missing piece.
