---
layout: template
title: Update Ruby
description: A weekly GitHub Actions workflow that opens a validated PR bumping Ruby to the latest version CI can actually install
---

Adds a single `.github/workflows/update-ruby.yml`. Once a week (and any time you trigger it by hand) it checks for a newer Ruby, and if one exists it opens a pull request that bumps your Ruby version — but only after proving the app installs and its tests pass on that version. No gems, no secrets, nothing else to configure.

## What It Does

- Creates `.github/workflows/update-ruby.yml` — one self-contained workflow, nothing else
- Runs weekly (Mondays 06:00 UTC) and on demand via `workflow_dispatch`
- Opens a PR labelled `dependencies` / `ruby` that updates:
  - `.ruby-version` (the source of truth)
  - `Gemfile.lock` (the `RUBY VERSION` stanza, via `bundle install`)
  - the `Dockerfile` build arg — **only if a `Dockerfile` is present**
- Validates the bump in the workflow (`bundle install` + `bin/rails db:test:prepare test`) before opening the PR, so the PR is safe to merge as-is

## Why "latest installable"

A new Ruby can be published days before `ruby/setup-ruby` has a prebuilt binary for it. Bumping to a version CI can't install just produces a red, unmergeable PR. To avoid that, the workflow reads the versions manifest **at the exact `ruby/setup-ruby@v1` ref it uses to validate** and only ever proposes a version from that list. The version it suggests is, by construction, a version it can install.

## What It Touches

| File | When | How |
|------|------|-----|
| `.ruby-version` | always | overwritten with the new version |
| `Gemfile.lock` | always | `RUBY VERSION` updated by `bundle install` |
| `Dockerfile` | if present | `ARG RUBY_VERSION=` line updated |

It deliberately does **not** rewrite your `README`, `.tool-versions`, or any other secondary reference — `.ruby-version` is what `ruby/setup-ruby` reads, so it's the one that matters.

## Simpler by Default

This template is a deliberately trimmed-down take on a workflow that had grown app-specific. Left out on purpose:

- **No PAT required.** It validates the bump inside the job and opens the PR with the built-in `GITHUB_TOKEN`. If you *also* want the PR to trigger your normal CI, add a `RUBY_UPDATE_TOKEN` personal access token — the workflow picks it up automatically, no edit needed.
- **No system tests, no browser setup.** It runs `bin/rails db:test:prepare test`. Native gems compiling and your suite passing is the signal that matters for a Ruby bump. Add a `test:system` step yourself if you want it.
- **No CI-file parsing.** It pins `ruby/setup-ruby@v1` and reads that same ref's manifest, so it doesn't care how (or whether) your `ci.yml` is structured.

## Prerequisites

Enable **Settings → Actions → General → "Allow GitHub Actions to create and approve pull requests."** Without it the workflow runs but can't open the PR.

## Re-running Safely

The template is idempotent: `.github/workflows/update-ruby.yml` is created only if it does not already exist, so re-applying the template leaves an existing workflow untouched.
