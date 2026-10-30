---
layout: template
title: Origin Lock
description: Refuse requests that did not come through Cloudflare, so the origin IP can't be used to skip your WAF rules and rate limits
---

Adds a small Rack middleware that answers `403` to any request missing a secret header that only Cloudflare sends. Without it, anyone who finds your server's IP can send the right `Host` header and skip every Cloudflare rule in front of your app.

## What It Does

- **`config/initializers/origin_lock.rb`** — defines `OriginLock` and inserts it at the top of the middleware stack when `ORIGIN_LOCK_SECRET` is set
- **`test/initializers/origin_lock_test.rb`** — Minitest coverage for the middleware (only if `test/test_helper.rb` exists)
- Adds no gem

The middleware:

- passes a request whose `X-Origin-Lock` header matches any accepted secret, compared with `ActiveSupport::SecurityUtils.secure_compare`
- strips the header before your app sees it
- leaves `/up` open so monitors and your host's health checks can reach the origin directly
- raises at boot if any secret is blank, instead of accepting empty headers

## Why These Defaults

- **Off until `ORIGIN_LOCK_SECRET` is set.** Dev, test and CI are unaffected. You turn it on per environment.
- **A header, not an IP allowlist.** Cloudflare WARP traffic also comes from Cloudflare IPs, so an IP allowlist lets anyone on WARP through. A shared secret does not.
- **A comma-separated list of secrets.** Lets you rotate with no 403s (see below).
- **`insert_before 0`.** Rejected requests never reach host authorization, logging or your app.

If your app has other health check paths (e.g. `/health_check`), add them to `OriginLock::OPEN_PATHS`.

## Setup (order matters)

1. Generate a secret: `openssl rand -hex 32`.
2. Cloudflare → **Rules → Transform Rules → Modify Request Header → Create rule**:
   - **Expression**: all incoming requests
   - **Action**: Set static → header `X-Origin-Lock` = the secret
3. Same page, second rule: **Remove** header `X-Forwarded-Host`, all incoming requests. Rails trusts that header for URL generation; never accept it from outside.
4. Set `ORIGIN_LOCK_SECRET` = the secret in your host's environment. Deploy.

Do step 2 before step 4, or the site returns `403` to everyone until the rule exists.

## Verify

```sh
curl -sI https://example.com/ | head -1                                         # → 200 (via Cloudflare)
curl -skI --resolve example.com:443:<origin-ip> https://example.com/ | head -1   # → 403 (direct)
curl -skI --resolve example.com:443:<origin-ip> https://example.com/up | head -1 # → 200
```

## Rotating

`ORIGIN_LOCK_SECRET` takes a comma-separated list. Any listed secret passes.

1. Make `NEW`. Set `ORIGIN_LOCK_SECRET` = `OLD,NEW`. Deploy.
2. Change the Cloudflare rule's header value to `NEW`.
3. Set `ORIGIN_LOCK_SECRET` = `NEW`. Deploy.

## Re-running Safely

Idempotent: if `config/initializers/origin_lock.rb` already exists, the template skips every step. Edit the initializer directly — the template will not overwrite your changes.
