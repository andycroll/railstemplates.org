# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

railstemplates.org is a Jekyll site that both **documents and serves** single-task Rails
application templates. Each template is a Ruby script a user runs against a Rails app via
`rails new myapp -m https://railstemplates.org/<name>/template` or
`rails app:template LOCATION=...`. The site's job is to host those raw scripts at stable
URLs and render a docs page for each.

## Commands

Ruby is pinned by `.ruby-version` (4.0.1); run everything through your version manager so
that Ruby is active (this environment uses mise, e.g. `mise x -- bundle exec …`).

- `bundle exec rake test` — full test suite (what CI runs).
- `bundle exec ruby -Itest test/templates_test.rb -n test_<name>` — run one template's test
  (e.g. `-n test_appsignal`). Prefer this while iterating: each test spins up a real Rails
  app, so the full suite is slow (tens of seconds per template).
- `bundle exec jekyll build` — build the site into `_site/`. **Run before shipping** — tests
  don't catch Liquid parse errors or stray publishable files.
- `bundle exec jekyll serve` — local preview.

## Architecture

**Each template lives in `_templates/<name>/` and has a dual identity:**

- `template.rb` — the Rails application template script (runs in the user's app via Thor's
  template DSL: `gem`, `after_bundle`, `create_file`, `gsub_file`, `inject_into_file`, `say`).
- `<name>.md` — a Jekyll page with front matter `title`, `description`, `layout: template`.
  The `templates` collection (defined in `_config.yml`) auto-lists every such page on the
  index (`index.md` iterates `site.templates`); no registration step.

**`_plugins/raw_templates.rb`** is the bridge between the two worlds. It's a Jekyll
`post_write` hook that, after each build, copies `_templates/<name>/template.rb` to
`_site/<name>/template` (served as the raw script), and copies any *other* `.rb`/`.rake`
support files in a template dir to `_site/<name>/<file>`. This is why a template is reached
at `/<name>/template` even though no such file exists in the source tree.

**Multi-file templates** (e.g. `daisyui`, `coverage-comments`) fetch their support files at
apply time from a base URL, defaulting to the production site. Tests override this with
`TEMPLATES_BASE_URL` pointed at a local `file://` path — so a template that pulls extra files
must read `ENV["TEMPLATES_BASE_URL"]` and be tested with that env passed to `apply_template`.

**Test harness (`test/templates_test.rb`, one `test_<name>` per template):** `create_rails_app`
runs `rails new --minimal -q`; `apply_template` runs `bundle exec rails app:template` inside
`Bundler.with_unbundled_env` + `Dir.chdir(app_dir)` (so the app's own bundle is used, not this
repo's); `assert_rails_boots` shells out to `rails runner` to confirm the generated app boots.
A template test asserts the gem is added exactly once, the generated files' content, an
idempotency re-apply (second apply produces no further diff), and that the app boots.

## Template authoring conventions

- **Generate config with the gem, don't hand-write it.** When a gem ships its own
  installer/generator, invoke it to produce the base config file, then insert only our
  opinionated defaults on top — don't commit a hand-maintained copy that drifts from the gem.
  A gem added earlier in the same template run is **not** on the template process's load path
  (Bundler freezes it at process start), so run the generator in a fresh `bundle exec`
  subprocess inside `after_bundle`.
- **One template, one job.** Scope each to "install X and set good required defaults."
  Host- or platform-specific concerns (e.g. a Hatchbox release env var) belong in a separate
  companion template, not bundled into the base install.
- **Cut figments of the generative source.** Templates derived from a reference app or an LLM
  tend to carry speculative config that isn't actually needed — staging-environment detection
  when no staging env exists, pinning an option that's already the gem's default, credentials
  plumbing that adds friction. Ship only real, required defaults.
- **Secrets via ENV, not credentials.** Follow the gem's own recommendation for keys (e.g.
  `APPSIGNAL_PUSH_API_KEY`). Don't write keys, or Rails-credentials wiring for them, into
  generated config.
- **Idempotency.** Guard with an early `return` when the template's marker file already
  exists, gate `gem` on `File.read("Gemfile").include?`, and use `create_file … skip: true`.

## Tests

- **Assert what the template produces, not the absence of things.** No "test-for-absence" /
  "how I built this" assertions guarding against config that was removed or never present.
  Stick to positive assertions on the generated output, the idempotency re-apply, and
  `assert_rails_boots`.

## PRs

- **Keep planning docs out of template PRs** — `docs/plans/` holds planning artifacts (and is
  excluded from the build); don't add them to a template's branch.
