---
title: "feat: Add update-ruby installable template"
type: feat
status: completed
date: 2026-07-20
---

# feat: Add update-ruby installable template

## Overview

Turn [andycroll/usingrails#299](https://github.com/andycroll/usingrails/pull/299) — a 150-line
GitHub Actions workflow that auto-bumps a Rails app's Ruby version — into an installable
railstemplates.org template served at `https://railstemplates.org/update-ruby/template`.

The upstream workflow was written for one specific app and carries a lot of that app's baggage
(SQLite extension caching, system tests, a Postgres-less master-key dance, a dual PAT/in-job
validation mode, README string-rewriting, and version detection that greps a second workflow
file). The explicit goal of this work is to **attack that complexity**: ship the smallest
workflow that delivers the core value — "open a validated PR when a newer *installable* Ruby
exists" — and let sensible defaults cover the rest.

## Problem Frame

Keeping Ruby current is chore work that slips. The upstream PR automates it well, but its value
is buried under app-specific steps that would either break or add noise in a generic Rails app.
A template must work on *any* Rails app (new or existing) with zero required secrets and no
hand-editing. Every step that doesn't earn its place is a step that makes the template fail or
confuse someone else's repo.

The one genuinely clever idea in the PR is worth preserving: **only ever propose a version that
CI can actually install.** Ruby releases can land upstream days before `ruby/setup-ruby` has a
prebuilt binary (this is the 4.0.6 failure the PR describes). Proposing an uninstallable version
produces a red, unmergeable PR. We keep that safety — but source it more simply.

## Requirements Trace

- R1. Installable via both `rails new -m .../update-ruby/template` and `rails app:template LOCATION=.../update-ruby/template`, following existing template conventions.
- R2. Generates a single self-contained `.github/workflows/update-ruby.yml`; adds no gems and requires no support files.
- R3. Only proposes a Ruby version that `ruby/setup-ruby` can install, with no dependency on the target repo's `ci.yml` existing or being structured a particular way.
- R4. Opens the bump PR with **zero required secrets** — works out of the box with the default `GITHUB_TOKEN`.
- R5. Validates the bump (native gems compile, unit tests pass) before opening the PR, so the PR is trustworthy even when the default token can't trigger the app's own CI.
- R6. Idempotent: re-applying the template does not modify an already-generated workflow file.
- R7. Touches only version-of-record files that are safe defaults: `.ruby-version` (always), `Gemfile.lock` (via bundle), and `Dockerfile` (only if present).
- R8. Documented on its own page (auto-listed on the index) and covered by a test in `test/templates_test.rb`.

## Scope Boundaries

- **Not** bumping `README`, `.tool-versions`, `mise.toml`, or any other cosmetic/secondary version reference. `.ruby-version` is the source of truth setup-ruby reads.
- **Not** running system tests, JS tests, or installing browsers/extensions in the workflow.
- **Not** shipping a mandatory PAT setup, a dual-mode validation branch, or per-repo detection of CI structure.
- **Not** changing any existing template, plugin, layout, or the Jekyll build pipeline.
- **Not** detecting Dockerfile/DB adapter at template-apply time — the generated workflow self-guards at runtime instead.

## Context & Research

### Relevant Code and Patterns

- `_templates/dependabot/template.rb` — the **direct analog**: a template that writes `.github/workflows/*.yml` and `.github/*.yml` with no gem and no Rails-boot dependency. Uses `empty_directory ".github/workflows"` then `create_file ".../*.yml", ..., skip: true`. Mirror this shape (ours is simpler — one static file, no conditional YAML assembly).
- `_templates/strong-migrations/template.rb`, `_templates/prosopite/template.rb` — canonical header/`say`/idempotency conventions: shebang, comment header with both usage lines, `say "railstemplates.org"`, a colored action `say`, guard-before-write, closing summary `say`s.
- `_templates/dependabot/dependabot.md` — doc-page style: `layout: template` + `title` + `description` frontmatter, a lead paragraph, `## What It Does`, and a `## Prerequisites` section. Pages auto-appear on `index.md` via `{% for template in site.templates %}` — no manual registration.
- `_plugins/raw_templates.rb` — copies `_templates/<name>/template.rb` → `_site/<name>/template` (the served URL). Template name = **directory name**, so dir/slug/doc-basename must agree.
- `_plugins/template_source.rb` — reads `template.rb` from the doc's directory into `page.template_source`; the layout renders it inside a `{{ page.template_source }}` variable (variable values are **not** re-parsed by Liquid, so `${{ }}` inside `template.rb` is safe there).
- `_layouts/template.html` — renders the doc body via `{{ content }}` (this **is** Liquid-parsed — see the escaping decision below) and derives install commands from `{{ page.slug }}`.
- `test/templates_test.rb` — per-template `test_<name>` methods: `create_rails_app` (`rails new --minimal`), `apply_template(name)`, file/content assertions, an idempotency re-apply check, and `assert_rails_boots`. Templates with no fetched support files need no `TEMPLATES_BASE_URL` env (dependabot is the precedent).

### Institutional Learnings

- **`docs/plans/2026-04-15-001-feat-dependabot-template-plan.md`** — prior art for a workflow-generating template; confirms the "static YAML via `create_file ... skip: true`, no gem, no boot coupling" shape and the idempotency-test expectation.
- **Memory — Jekyll build verification:** run `bundle exec jekyll build` before shipping; tests alone don't catch Liquid parse errors or stray publishable files. Directly relevant here because GitHub Actions expressions use `${{ … }}`, whose inner `{{ … }}` is a Liquid output tag — see the escaping decision.

### External References

- None consulted. Local patterns are strong (8 existing templates, one a direct analog) and the task is simplification-of-a-known-artifact rather than new-domain work.

## Key Technical Decisions

Each decision below is framed as **what the upstream PR does → what this template does → why**, because the deliverable *is* the set of simplifications.

- **Version detection source → self-hosted pin, not `ci.yml` grep.** The PR greps `.github/workflows/ci.yml` for the pinned `ruby/setup-ruby@vX.Y.Z` tag and reads `ruby-builder-versions.json` at that exact tag. Instead, the template's own workflow pins `ruby/setup-ruby@v1` and reads the manifest from that **same `v1` ref** (`https://raw.githubusercontent.com/ruby/setup-ruby/v1/ruby-builder-versions.json`). This is self-consistent (the manifest we read is the version we validate with) and removes any assumption that the target repo has a `ci.yml`, let alone one shaped a particular way. `@v1` is the canonical moving tag `ruby/setup-ruby` maintains, so it is idiomatic and always current.
- **Zero required secrets → validate in-job, keep a one-line optional PAT upgrade.** The PR branches between a `RUBY_UPDATE_TOKEN` PAT (PR triggers CI) and the default token (validate in-job) and explains the tradeoff in a long PR body. We pick **one** behavior: always validate in-job (`bundle install` + `bin/rails db:test:prepare test`) so the PR is trustworthy with no secret. We keep the single line `token: ${{ secrets.RUBY_UPDATE_TOKEN || secrets.GITHUB_TOKEN }}` because it costs nothing, requires no setup, and silently upgrades to CI-triggering behavior if someone later adds the PAT — a default that works and opts up gracefully. We drop the verbose PR-body explanation.
- **Drop README rewriting.** `sed -i -E "s/Ruby [0-9]+\.[0-9]+\.[0-9]+/Ruby ${LATEST}/g" README.md` clobbers *every* "Ruby x.y.z" mention (badges, changelog entries, prose) and assumes a README exists. It's cosmetic and fragile. `.ruby-version` is the version of record. Removed entirely.
- **Drop SQLite/`sqlpkg` steps and the `actions/cache` step.** 100% specific to the upstream app. Removed.
- **Drop the system-test step.** `bin/rails test:system` needs a browser/headless Chrome and assumes the app has system tests; running it generically adds flakiness and setup for little marginal signal over unit/integration tests. The essential validation is "native gems compile and the suite passes on the new Ruby," which `bundle install` + `bin/rails db:test:prepare test` already prove. Removed (mentioned in docs as an easy add).
- **Drop the `apt-get install build-essential …` step.** `ubuntu-latest` runners already ship build toolchains, and `ruby/setup-ruby` installs prebuilt Ruby. Removed.
- **Dockerfile bump self-guards at runtime, not at apply time.** Rather than detect a Dockerfile when the template is applied, the generated workflow does `[ -f Dockerfile ] && sed -i -E "s/^ARG RUBY_VERSION=.*/ARG RUBY_VERSION=${LATEST}/" Dockerfile || true`. This keeps `template.rb` a single static write, and keeps working if a Dockerfile is added to the repo later.
- **Keep `RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}` passthrough on the test step.** Harmless when the secret is unset; lets real apps that read credentials during test boot succeed. A default that helps without imposing setup.
- **Use major-version action tags** (`actions/checkout@v4`, `ruby/setup-ruby@v1`, `peter-evans/create-pull-request@v7`) instead of exact pins. Lower maintenance for a template that will be copied into many repos; if the user also installs the `dependabot` template, its `github-actions` ecosystem keeps these current. (Repo precedent: the dependabot template uses `dependabot/fetch-metadata@v3`.)
- **Weekly schedule: Monday 06:00 UTC.** Matches the cadence of this repo's own `dependabot` template (`day: monday`) for cross-template consistency. `workflow_dispatch` retained for manual runs.
- **`template.rb` is a single static file write, idempotent via `skip: true`,** with a light `say` warning if `.ruby-version` is absent (the whole workflow hinges on it). No conditional assembly — simpler than dependabot.
- **Slug/dir/workflow naming = `update-ruby`.** Directory `_templates/update-ruby/`, doc `update-ruby.md`, generated workflow `.github/workflows/update-ruby.yml`, workflow `name: Update Ruby`. Directory name drives both the served URL (`/update-ruby/template`) and `page.slug`, so all three must agree.
- **Doc-page Liquid escaping.** Any `${{ … }}` snippet shown in `update-ruby.md` must be wrapped in `{% raw %}…{% endraw %}` (the `{{ … }}` inside a GitHub expression is a Liquid output tag, and expressions like `${{ a || b }}` are invalid Liquid → build error). Preferred: keep the doc prose-only and avoid embedding raw workflow YAML with expressions; if any is shown, wrap it. `template.rb` needs no escaping (it's copied raw and surfaced via a variable).

## Open Questions

### Resolved During Planning

- *Detect Dockerfile/DB at apply time or runtime?* → Runtime self-guard in the YAML (keeps `template.rb` trivial and future-proof).
- *Require a PAT?* → No; validate in-job and keep a zero-cost optional PAT upgrade line.
- *Which files to bump?* → `.ruby-version` + `Gemfile.lock` (always) and `Dockerfile` (if present). Drop README and secondary version files.
- *Exact vs major action tags?* → Major tags.
- *Template slug?* → `update-ruby`.

### Deferred to Implementation

- Exact set of `assert_match`/`refute_match` markers in the test — finalize against the literal YAML string once written (must include positive markers like `name: Update Ruby`, `ruby/setup-ruby@v1`, `ruby-builder-versions.json`, `workflow_dispatch`, `peter-evans/create-pull-request`, and negative markers proving the simplification: no `sqlpkg`, no `test:system`, no `README`, no `build-essential`).
- Whether `create_file` alone creates `.github/workflows/` or whether the explicit `empty_directory` guard (dependabot precedent) is needed — mirror dependabot's belt-and-suspenders order unless proven unnecessary during implementation.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

**Generated workflow shape** (annotated skeleton — steps elided, not copy-paste YAML):

```
name: Update Ruby
on:
  schedule: [ cron "0 6 * * 1" ]     # Mondays 06:00 UTC
  workflow_dispatch:
permissions: { contents: write, pull-requests: write }
concurrency: { group: update-ruby, cancel-in-progress: true }

jobs:
  update-ruby (ubuntu-latest):
    1. checkout@v4
    2. detect: read manifest at the SAME ref we validate with (setup-ruby @v1),
       compare newest installable CRuby vs current .ruby-version → set update=true/false
    3. if update: write .ruby-version; [ -f Dockerfile ] && sed the ARG RUBY_VERSION line
    4. if update: setup-ruby@v1            # reads the just-bumped .ruby-version
    5. if update: bundle install (frozen false)   # compiles native gems, rewrites Gemfile.lock
    6. if update: bin/rails db:test:prepare test  # RAILS_MASTER_KEY passthrough
    7. if update: create-pull-request@v7   # token fallback PAT||GITHUB_TOKEN; labels dependencies/ruby
                                           # add-paths: .ruby-version, Gemfile.lock, Dockerfile
```

**What was removed vs upstream PR #299** (the deliverable-defining diff):

| Upstream step / concern | Fate | Reason |
|---|---|---|
| `apt-get install build-essential …` | removed | runner + setup-ruby already cover it |
| grep `ci.yml` for pinned setup-ruby tag | replaced | read manifest at our own `@v1` pin — no `ci.yml` dependency |
| SQLite `sqlpkg` install + `actions/cache` | removed | app-specific |
| `README.md` version sed | removed | fragile, cosmetic; `.ruby-version` is source of truth |
| `test:system` step | removed | needs browser; not universal |
| dual PAT/in-job validation modes + long PR body | collapsed | one mode (validate in-job) + one-line optional PAT upgrade |
| Dockerfile bump (unconditional) | guarded | `[ -f Dockerfile ]` runtime guard |

**Template flow:** `say` banner → warn if `.ruby-version` absent → `empty_directory ".github/workflows"` → `create_file ".github/workflows/update-ruby.yml", <static YAML>, skip: true` → closing `say` with the one prerequisite (enable "Allow GitHub Actions to create and approve pull requests") and the optional-PAT note.

## Implementation Units

- [ ] **Unit 1: Simplified workflow template script**

**Goal:** Create the installable template that writes the slimmed-down `update-ruby.yml`.

**Requirements:** R1, R2, R3, R4, R5, R6, R7

**Dependencies:** None

**Files:**
- Create: `_templates/update-ruby/template.rb`

**Approach:**
- Follow the header/`say`/idempotency conventions from `strong-migrations`/`prosopite` (shebang, comment header with both usage lines, `say "railstemplates.org"`, colored action `say`).
- Embed the full simplified workflow as a single heredoc. Use a **non-interpolating** heredoc (`<<~'YAML'`) so the workflow's own `${{ … }}` and `${LATEST}` shell expansions survive verbatim — the template writes them literally, it does not evaluate them.
- `empty_directory ".github/workflows"` then `create_file ".github/workflows/update-ruby.yml", yaml, skip: true` (mirror dependabot's order for idempotency).
- Light guard: if `!File.exist?(".ruby-version")`, `say` a yellow warning that the workflow needs a `.ruby-version` to bump (still write the file).
- Closing `say`s: the single prerequisite (repo setting: allow Actions to create/approve PRs) and the optional `RUBY_UPDATE_TOKEN` PAT note (one line).
- Bake in all Key Technical Decisions: `@v1` manifest read matching the setup-ruby pin, Dockerfile runtime self-guard, `RAILS_MASTER_KEY` passthrough, major action tags, Monday cron, `add-paths` limited to `.ruby-version`/`Gemfile.lock`/`Dockerfile`, labels `dependencies`/`ruby`.

**Patterns to follow:** `_templates/dependabot/template.rb` (static-YAML-via-`create_file`, `skip: true`, no gem, no boot coupling).

**Test scenarios:** (covered by Unit 3) file created at the right path; contains positive markers; omits every removed step; idempotent on re-apply.

**Verification:**
- `template.rb` writes exactly one file and adds no gems.
- Heredoc quoting preserves `${{ … }}` and `${LATEST}` literally (no accidental Ruby interpolation).

- [ ] **Unit 2: Documentation page**

**Goal:** Document the template and auto-list it on the index.

**Requirements:** R8

**Dependencies:** Unit 1 (slug/dir must match)

**Files:**
- Create: `_templates/update-ruby/update-ruby.md`

**Approach:**
- Frontmatter: `layout: template`, `title: Update Ruby`, a one-line `description` (e.g. "Weekly workflow that opens a validated PR bumping Ruby to the latest version CI can install").
- Sections mirroring `dependabot.md`: lead paragraph, `## What It Does`, `## Why "latest installable"` (explain the setup-ruby manifest safety succinctly), `## What It Touches` (`.ruby-version`, `Gemfile.lock`, `Dockerfile` if present — and explicitly *not* README), `## Prerequisites` (the one repo setting + optional PAT), and a short `## Simpler by Default` note listing what was intentionally left out (system tests, sqlpkg, README rewrite) so the simplicity is a documented feature.
- **Liquid safety:** keep the body prose-first; if any `${{ … }}` YAML is shown, wrap that block in `{% raw %}…{% endraw %}`.

**Patterns to follow:** `_templates/dependabot/dependabot.md`.

**Verification:**
- Page renders and appears as a card on the home page.
- `bundle exec jekyll build` completes with no Liquid errors and no stray publishable files.

- [ ] **Unit 3: Template test**

**Goal:** Lock in behavior and the simplifications with an automated test.

**Requirements:** R1, R2, R6, R7

**Dependencies:** Unit 1

**Files:**
- Modify: `test/templates_test.rb` (add `test_update_ruby`)

**Approach:**
- Mirror `test_dependabot_without_npm` (no `TEMPLATES_BASE_URL` needed — no fetched support files).
- `create_rails_app`; `apply_template("update-ruby")`.
- Assert `.github/workflows/update-ruby.yml` exists; positive `assert_match` on `name: Update Ruby`, `workflow_dispatch`, `ruby/setup-ruby@v1`, `ruby-builder-versions.json`, `peter-evans/create-pull-request`, `.ruby-version`, and a `labels:` block containing `ruby`.
- Negative `refute_match` proving the simplification: no `sqlpkg`, no `test:system`, no `README`, no `build-essential`.
- Idempotency: capture file contents, re-apply, assert unchanged.
- `assert_rails_boots` (writing a YAML file must not affect boot).

**Patterns to follow:** `test_dependabot_without_npm`, and the idempotency-block style in `test_lograge`/`test_strong_migrations`.

**Test scenarios:**
- Fresh `--minimal` app → workflow file written with all positive markers, none of the removed steps.
- Re-apply → byte-identical file (`skip: true`).
- App still boots.

**Verification:**
- `bundle exec rake test` passes with the new test included (activate Ruby via the version manager first).

## System-Wide Impact

- **Interaction graph:** New template is self-contained. Index listing is automatic via `site.templates`; `raw_templates.rb` serves `/update-ruby/template`; `template_source.rb` surfaces the source on the doc page — all keyed on the `update-ruby` directory name, so the only cross-cutting requirement is that dir/slug/doc-basename agree.
- **Error propagation:** Generated workflow uses `set -euo pipefail` in shell steps and gates every mutating step on `steps.detect.outputs.update == 'true'`, so a no-op run (already latest) does nothing and exits clean.
- **State lifecycle risks:** `create_file … skip: true` guarantees re-apply is a no-op; the workflow itself is a fresh file, so no partial-write risk. `bundle config set --local frozen false` is scoped `--local` to the CI checkout, not the developer's machine.
- **API surface parity:** The generated `.github/workflows/update-ruby.yml` is the external contract. Its `permissions`, `add-paths`, labels, and token fallback are the only knobs; documented in Unit 2.
- **Integration coverage:** The test proves generation + idempotency + boot but *cannot* execute the workflow on GitHub. The in-YAML logic (manifest read, version compare, sed, PR open) is validated by review against PR #299's proven behavior, not by CI here. Called out as a deliberate boundary.

## Risks & Dependencies

- **`ruby/setup-ruby@v1` manifest path stability.** We depend on `ruby-builder-versions.json` existing at the `v1` ref and on the `.ruby[]` key shape. This is the same file PR #299 relies on; low risk, but a broken fetch should fail the detect step loudly (`curl -fsSL` + `set -euo pipefail`) rather than propose garbage.
- **Heredoc interpolation trap.** The workflow contains `${…}` and `#{`-adjacent shell/text; use a single-quoted heredoc (`<<~'YAML'`) to avoid Ruby interpolating them. This is the single most likely implementation bug — verify the written file matches intent byte-for-byte.
- **Liquid parse errors in the doc.** GitHub Actions `${{ }}` expressions contain Liquid output tags. Mitigation: prose-first doc + `{% raw %}` around any shown expressions + mandatory `bundle exec jekyll build` before shipping (per institutional learning).
- **Dependency:** Ruby version-manager activation is required before any `rake test`/`jekyll build` (per session Ruby-project setup).

## Documentation / Operational Notes

- The doc page *is* the user documentation; no external docs to update.
- The `## Simpler by Default` section doubles as the rationale record for what was cut — useful if someone later asks "why doesn't this run system tests?"

## Sources & References

- **Origin PR:** [andycroll/usingrails#299 — "ci: add weekly workflow to auto-bump Ruby to latest installable"](https://github.com/andycroll/usingrails/pull/299)
- Direct analog template: `_templates/dependabot/template.rb`, `_templates/dependabot/dependabot.md`
- Convention references: `_templates/strong-migrations/`, `_templates/prosopite/`, `_plugins/raw_templates.rb`, `_plugins/template_source.rb`, `_layouts/template.html`
- Test harness: `test/templates_test.rb`, `test/test_helper.rb`
- Prior plan: `docs/plans/2026-04-15-001-feat-dependabot-template-plan.md`
