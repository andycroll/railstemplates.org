---
layout: template
title: Litestream
description: Stream SQLite backups to object storage — with a sane sync-interval that avoids racking up millions of storage operations
---

Installs [Litestream](https://github.com/fractaledmind/litestream-ruby) (via the `litestream` gem) and runs its install generator to create `config/litestream.yml` and `config/initializers/litestream.rb`. Litestream continuously replicates your SQLite database to S3-compatible object storage (R2, Backblaze B2, DigitalOcean Spaces, GCS, etc.), giving you point-in-time recovery for a production SQLite app.

The one non-default this template adds — and the entire reason it exists — is `sync-interval: 10s` on each replica.

## What It Does

- Adds the `litestream` gem to your `Gemfile`
- Runs `litestream:install` to generate the two canonical files:
  - `config/litestream.yml` — the Litestream config (databases + replicas)
  - `config/initializers/litestream.rb` — wires the gem's `config.litestream.*` settings to ENV / Rails credentials
- Injects `sync-interval: 10s` into every replica in `config/litestream.yml`, with an inline comment explaining the trade-off

## Why `sync-interval: 10s` — The Whole Point

`sync-interval` is both the **replication latency** and the **write frequency**. Litestream's default is `1s`: it writes to your object store roughly once per second, per replica, forever.

That default is a cost trap. One second between syncs means **~86,400 writes per day per replica**, and each is a billable **Class A operation**. One engineer left the default on Cloudflare R2 and ran up **~20 million operations in a month — nearing $100** — for a small SQLite app that generated almost no actual data. See the post-mortem: [Remember to set the frequency for replication to Litestream](https://notes.ghinda.com/post/remember-to-the-frequency-for-replication-to-litestream).

Setting `sync-interval` to `10s`–`1m` trades a few seconds (or a minute) of *potential* data loss on a hard crash for **~10–60× fewer, cheaper writes**. For most apps that is an obvious win: the WAL still captures every committed transaction, you just ship it to the replica slightly less often.

```yaml
dbs:
  - path: storage/production.sqlite3
    replicas:
      - type: s3
        bucket: $LITESTREAM_REPLICA_BUCKET
        path: production
        endpoint: <your-s3-endpoint>
        access-key-id: $LITESTREAM_ACCESS_KEY_ID
        secret-access-key: $LITESTREAM_SECRET_ACCESS_KEY
        sync-interval: 10s     # ← the tuning this template exists to add
```

Bump it lower only if your recovery-point objective genuinely demands second-level freshness — and only after you've looked at what that costs on your provider's Class A pricing.

## The Single-Writer Rule

Exactly **one** process may replicate to a given bucket path at a time. Litestream's replica is a single-writer log; two writers pointed at the same path will corrupt it.

The classic way to break this is a migration: you spin up a new server while the old one is still running, and for a few minutes **two** Litestream processes are replicating to the same bucket. Don't. Stop replication on the old host before you start it on the new one, or replicate to a distinct path and cut over deliberately.

## Two Run Patterns

Litestream has to run as a process alongside your app. There are two common shapes; pick one.

### Puma plugin (single-server)

Run Litestream inside the Puma master process as a plugin. In `config/puma.rb`:

```ruby
plugin :litestream if ENV["LITESTREAM_IN_PUMA"]
```

This gives you a **mutual watchdog**: if Puma dies, Litestream stops; if Litestream dies, Puma is taken down too. It's the simplest setup for a single-server deployment where web and replication share a machine. Gate it behind an ENV flag so it only runs where you want it (i.e. not in dev/test or on hosts that shouldn't replicate).

### Standalone process

Run replication as its own long-lived background process, isolated from the web server:

```sh
bin/rails litestream:replicate
```

This keeps replication independent of request traffic — a slow or hung web process can't stall replication, and vice versa. It's the right shape when the web and replication run as separate processes/containers.

Either way, the replica **bucket and credentials** are read from `config/initializers/litestream.rb`, which pulls them from ENV variables (`LITESTREAM_REPLICA_BUCKET`, `LITESTREAM_ACCESS_KEY_ID`, `LITESTREAM_SECRET_ACCESS_KEY`) or Rails encrypted credentials. Edit that initializer to point at your storage provider.

## Re-running Safely

The template is idempotent. If `config/litestream.yml` already exists it skips every step — it won't re-run the generator and won't inject a second `sync-interval`. Tweak the generated `config/litestream.yml` and `config/initializers/litestream.rb` directly; the template will not overwrite your edits.
