---
title: "feat: Add Lograge template for structured production logs"
type: feat
status: completed
date: 2026-04-19
origin: https://github.com/andycroll/railstemplates.org/issues/22
---

# Add Lograge Template for Structured Production Logs

## Overview

Add a new Rails application template under `_templates/lograge/` that installs the `lograge` gem and drops a single `config/initializers/lograge.rb`. The initializer converts Rails' multi-line request logs into one JSON line per request, is gated to `production` and `staging` at runtime, and adds `params`, `request_id`, and `user_id` to the log payload — with `user_id` harvested defensively from `Current.user` so apps without that concept continue to boot. The template is idempotent: re-running it produces no additional diff.

## Problem Frame

Rails' default per-request logging is a multi-line block that log aggregators (Datadog, CloudWatch, Loki, Papertrail, Axiom) cannot parse cleanly. Two of four reference apps on railstemplates.org already install lograge by hand, re-deriving the same initializer each time. A template removes that toil and encodes the non-obvious decisions (params filtering, `Current.user` guards, staging detection) that a copy-paste from the lograge README gets wrong.

## Requirements Trace

- **R1.** `_templates/lograge/` is created following site conventions: `template.rb` + Jekyll page, tests added to `test/templates_test.rb`. (Issue AC 1)
- **R2.** Template adds the `lograge` gem to the target app's `Gemfile`.
- **R3.** Template creates `config/initializers/lograge.rb` containing a JSON formatter, enablement gated to `production` (and `staging` when that environment exists), and a custom payload with `params`, `request_id`, and `user_id`.
- **R4.** After apply, production logs output one JSON line per request. (Issue AC 2)
- **R5.** `user_id` key appears when `Current.user` is set; absent otherwise; never raises. (Issue AC 3)
- **R6.** Running the template twice produces no additional diff — skip when the initializer is already present. (Issue AC 4)
- **R7.** Tests cover: gem added, initializer created, Rails boots, and idempotency on second apply.

## Scope Boundaries

- Does **not** install a log shipper (Vector, Fluent Bit, `rails_semantic_logger` etc.).
- Does **not** touch `config/environments/production.rb` — all lograge config lives in the one initializer file so re-runs and removals are clean.
- Does **not** add a `category: maintenance` front matter field to the Jekyll page — no category convention exists across the site yet, and introducing one for a single template is premature.
- Does **not** auto-generate a `Current` class for apps that lack one — the runtime guard handles absence gracefully.
- Does **not** configure `Rails::HealthController#show` beyond the single `ignore_actions` entry; further tuning is app-specific.

## Context & Research

### Relevant Code and Patterns

- `_templates/simplecov-rails/template.rb` — closest analogue: gem + file creation + idempotency checks (`File.read("Gemfile").include?`). Uses `inject_into_file` for Gemfile, heredoc for file bodies.
- `_templates/standard-rb/template.rb` — minimal `gem_group` + `create_file` pattern; shows `after_bundle` usage.
- `_templates/dependabot/template.rb` — idiomatic heredoc + `create_file ..., skip: true` for idempotency.
- `test/templates_test.rb` — test harness: `create_rails_app` (minimal), `apply_template`, file/content assertions, `assert_rails_boots`. Each test spins a real Rails app (~30–60s).
- `_plugins/raw_templates.rb` — copies `template.rb` to `_site/<name>/template`; no change required for a new template.
- `_config.yml` — `templates` collection defaults apply `layout: template`; the new `.md` auto-appears on the index page.

### Institutional Learnings

- The dependabot plan (`docs/plans/2026-04-15-001-feat-dependabot-template-plan.md`) is the closest prior art: same 3-unit shape (template → docs → tests), same `skip: true` idempotency choice, same ~2-minute test-suite cost per added test.
- No existing references to `lograge`, `Current.user`, or custom logging initializers in the repo — this is a greenfield addition, no existing pattern to align to beyond the template shape itself.

### External References

- `lograge` is maintained (0.14.0 latest on RubyGems, Aug 2024) and Rails 8.x compatible. Remains the idiomatic default for "one JSON line per request" in 2026.
- Canonical 2026 initializer shape: enablement gated per-env, `Lograge::Formatters::Json.new` (not `KeyValue`), split between `custom_options` (event metadata) and `custom_payload` (controller access).
- **Params filtering footgun:** `event.payload[:params]` is **unfiltered** — logging it directly leaks passwords (lograge issue #28, open 10+ years). The safe path is `controller.request.filtered_parameters` via `custom_payload`, which respects `Rails.application.config.filter_parameters`.
- **`Current.user` guarding:** Per-request defensive check (inside the lambda) is more robust than a boot-time `defined?(Current)` check. Autoloading means boot-time lookups are unreliable; per-request is cheap and correct in both eager-loaded production and lazy-loaded dev.
- **API-only apps:** `base_controller_class` must be set to `'ActionController::API'` when `Rails.application.config.api_only` is true; otherwise lograge silently no-ops on requests.

## Key Technical Decisions

- **Single initializer, no edits to `config/environments/production.rb`.** One file the template owns means re-runs and removals are trivial. Gate the whole file with `return unless Rails.env.production? || Rails.env.staging?` at the top.
- **Staging detection at runtime, not apply-time.** `Rails.env.staging?` is the source of truth and survives a staging env added *after* the template is applied. Template-apply-time file detection (`config/environments/staging.rb`) is used only for a friendlier post-install message.
- **Gem in the default group, not `:production`.** Lograge is only *enabled* in prod/staging (via the initializer's runtime guard), so the gem only needs to be *loadable* there. Keeping it in the default group means `bundle install` behaves the same everywhere and local "run production mode" experiments (`RAILS_ENV=production rails s`) work without re-bundling. Also matches how 2 of 4 reference apps already install it.
- **`custom_payload` (not `custom_options`) for all three fields.** `custom_payload` provides `controller`, which gives safe access to `request.filtered_parameters`, `request.request_id`, and `Current.user`. Using `event.payload[:params]` would leak unfiltered params.
- **Per-request `Current.user` guard, not boot-time.** The issue describes "a boot-time check for a Current.user concept"; the research strongly prefers a per-request guard because autoloading makes `defined?(Current)` at initializer time unreliable. The behavior promised by AC 3 ("user_id appears when set, absent otherwise, no raises") is satisfied either way; per-request is strictly more robust. Use `.compact` on the returned hash so `user_id` is absent when nil rather than `null`.
- **API-only apps get `base_controller_class = 'ActionController::API'`.** Detect via `Rails.application.config.api_only` at initializer load time and set conditionally. Wrong on API-only apps is a silent footgun.
- **`ignore_actions: ['Rails::HealthController#show']` default.** Rails 8's default `/up` health endpoint otherwise dominates production logs. Keep the list minimal; do not add `ActiveStorage::*` or `PwaController::*` by default (too app-specific).
- **Idempotency by initializer existence.** `return` early with a friendly `say` when `File.exist?("config/initializers/lograge.rb")` — avoids both a double-gem insertion *and* overwriting a user-customized initializer. Also use `skip: true` on `create_file` as a belt-and-suspenders.
- **JSON formatter only.** Do not ship a `KeyValue` option. Every modern log pipeline parses JSON; `KeyValue` leads to one giant unparseable field in the aggregator.

## Open Questions

### Resolved During Planning

- **`user_id` guard: boot-time or per-request?** Per-request. Issue wording suggests boot-time, but research shows boot-time `defined?(Current)` is unreliable under autoloading. Per-request satisfies the acceptance criterion more robustly at negligible cost. See Key Technical Decisions.
- **Should the gem go in `:production` group?** No — default group. See Key Technical Decisions.
- **Include `request.filtered_path` to strip tokens from URL query strings?** Yes. Same filter-leak class as params. Cheap addition.
- **Support `KeyValue` formatter?** No. JSON only.
- **Category front matter field?** Not added. No existing category system on the site.
- **`say_status` emoji prefix?** Follow existing style (`say "railstemplates.org"` then a descriptive green line, optional emoji). Match `dependabot`/`simplecov-rails` tone.

### Deferred to Implementation

- Exact `say` copy for the "already installed, skipping" idempotency branch and the post-install staging-environment hint.
- Whether the `.md` page should include a "Customization" section showing how to add extra keys to `custom_payload`. Decide once the page exists and a reviewer can eyeball length.
- Exact Minitest assertion choice for JSON-shape validation (regex on initializer content vs actually booting `RAILS_ENV=production` and parsing a log line). Start with content-level assertions; only escalate if a real logging regression slips through.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

**Initializer shape (`config/initializers/lograge.rb`):**

```
# Guard: only active in production + staging.
return unless Rails.env.production? || Rails.env.staging?

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.ignore_actions = ['Rails::HealthController#show']
  # Conditional: only set when api_only, to avoid silent no-op on API apps.
  if Rails.application.config.api_only
    config.lograge.base_controller_class = 'ActionController::API'
  end

  config.lograge.custom_payload do |controller|
    user_id =
      begin
        defined?(Current) && Current.respond_to?(:user) ? Current.user&.id : nil
      rescue StandardError
        nil
      end

    {
      params:     controller.request.filtered_parameters.except('controller', 'action'),
      path:       controller.request.filtered_path,
      request_id: controller.request.request_id,
      user_id:    user_id
    }.compact
  end
end
```

**Template flow (`_templates/lograge/template.rb`):**

```
say "railstemplates.org"
say "Configuring Lograge for structured production logs…", :green

return if File.exist?("config/initializers/lograge.rb")  # idempotency

unless File.read("Gemfile").include?('"lograge"')
  gem "lograge"
end

after_bundle do
  create_file "config/initializers/lograge.rb", <<~RUBY, skip: true
    # ...canonical initializer body above...
  RUBY

  say "✅ Lograge configured for production" + (File.exist?("config/environments/staging.rb") ? " and staging." : "."), :green
end
```

Pseudo-code only. Real implementation handles indentation, heredoc quoting, and the exact `gem` / `gem_group` invocation per existing template conventions.

## Implementation Units

- [ ] **Unit 1: Template script**

  **Goal:** Create `_templates/lograge/template.rb` that installs lograge and drops the initializer.

  **Requirements:** R1, R2, R3, R6

  **Dependencies:** None

  **Files:**
  - Create: `_templates/lograge/template.rb`

  **Approach:**
  - Standard header: `#!/usr/bin/env ruby`, usage comment, `say "railstemplates.org"`, `say "… structured logs", :green`.
  - Early return if `File.exist?("config/initializers/lograge.rb")` with a yellow "already installed" `say`.
  - Add gem only if `Gemfile` does not already reference lograge (`File.read("Gemfile").include?('"lograge"')`). Use a top-level `gem "lograge"` — it lands in the default group.
  - Wrap filesystem work in `after_bundle`.
  - `create_file "config/initializers/lograge.rb", <<~RUBY, skip: true` with the initializer body from the High-Level Technical Design.
  - Post-install `say` branches: mention staging when `File.exist?("config/environments/staging.rb")`, otherwise mention production only.

  **Patterns to follow:**
  - `_templates/simplecov-rails/template.rb` for gem-presence detection via `File.read("Gemfile").include?`.
  - `_templates/standard-rb/template.rb` for the minimal `gem_group` + `after_bundle` + `create_file` shape.
  - `_templates/dependabot/template.rb` for heredoc + `create_file path, content, skip: true` and multi-line post-install `say` messaging.

  **Technical design:** See High-Level Technical Design section. The initializer body is the substantive artifact; the template.rb itself is almost entirely boilerplate.

  **Test scenarios:** Covered by Unit 3.

  **Verification:** File exists, matches site conventions (shebang, `say "railstemplates.org"`, `after_bundle` wrapping), re-apply produces no change.

- [ ] **Unit 2: Documentation page**

  **Goal:** Create the Jekyll markdown page so the template appears on the site index and has its own `/lograge/` page with installation snippets.

  **Requirements:** R1

  **Dependencies:** None (can run in parallel with Unit 1)

  **Files:**
  - Create: `_templates/lograge/lograge.md`

  **Approach:**
  - Front matter: `layout: template`, `title: Lograge`, `description:` tight one-liner about structured JSON production logs.
  - Intro paragraph: why lograge (one JSON line per request, log aggregators) and when it activates (production + staging).
  - "What It Does" bullet list: installs the gem, creates the initializer, JSON formatter, params/request_id/user_id payload, health check ignored.
  - "Payload Shape" subsection: small JSON example of a logged request.
  - "Notes" or "How It Behaves" subsection: the `Current.user` guard is defensive — apps without a `Current` class still boot cleanly; `user_id` just never appears.
  - "Why these defaults" paragraph: JSON over KeyValue, params filtering via `request.filtered_parameters`, health-check suppression, base_controller_class for API apps.

  **Patterns to follow:**
  - `_templates/dependabot/dependabot.md` for length, table usage, and section headings.
  - `_templates/simplecov-rails/simplecov-rails.md` for a more minimal shape.

  **Test scenarios:** None (doc page).

  **Verification:** Jekyll builds without error; page appears on the index grid; installation snippets render with the correct `/lograge/template` URL.

- [ ] **Unit 3: Tests**

  **Goal:** Extend `test/templates_test.rb` with a `test_lograge` case that verifies gem installation, initializer creation, content shape, idempotency, and successful Rails boot.

  **Requirements:** R4, R5, R6, R7

  **Dependencies:** Units 1 and 2 must exist.

  **Files:**
  - Modify: `test/templates_test.rb`

  **Approach:**
  - Single test method `test_lograge`: `create_rails_app`, `apply_template("lograge")`, then assert:
    - `Gemfile` contains `gem "lograge"` exactly once (`gemfile.scan(/gem "lograge"/).count == 1`).
    - `config/initializers/lograge.rb` exists.
    - Initializer content contains: `Rails.env.production?`, `Rails.env.staging?`, `Lograge::Formatters::Json.new`, `custom_payload`, `filtered_parameters`, `request_id`, `user_id`, `Current`.
    - Initializer content does **not** contain `event.payload[:params]` (the canonical footgun).
    - `assert_rails_boots` succeeds — confirms the initializer does not raise in the default `development` env (the `return unless` guard short-circuits it).
  - Idempotency sub-case: call `apply_template("lograge")` a second time in the same test; assert `gem "lograge"` still appears exactly once in the Gemfile and the initializer file's mtime / content is unchanged (snapshot content before second apply, compare after).
  - Do not add a separate "api-only" test unless the first test is flaky — the `Rails.application.config.api_only` branch is static and exercised at load time.

  **Patterns to follow:**
  - `test_simplecov_rails` for gem-count assertion pattern (`assert_equal 1, gemfile.scan(...).count`).
  - `test_dependabot_without_npm` for multi-assertion file-content checks.
  - Existing `create_rails_app` / `apply_template` / `assert_rails_boots` helpers — do not modify the harness.

  **Test scenarios:**
  - Happy path: new Rails app, apply once, everything lands.
  - Idempotency: apply twice, no second-run diff.
  - Boot safety: app boots in `RAILS_ENV=development` despite the initializer present (guard short-circuits).

  **Verification:** `bundle exec rake test` passes, including both existing tests and the new `test_lograge`. Adds ~30–60s to the suite.

## System-Wide Impact

- **Plugin interaction:** `_plugins/raw_templates.rb` automatically copies `_templates/lograge/template.rb` to `_site/lograge/template`. No plugin edits required.
- **Jekyll collection:** `_config.yml` templates collection picks up `_templates/lograge/lograge.md` automatically with the default `layout: template`.
- **Index page:** `index.md`'s `{% for template in site.templates %}` loop shows the new card once the page is committed. Visual order depends on Jekyll's default collection ordering — no manual sort required.
- **Target app integration graph:** The initializer hooks into `ActionController` request logging via lograge's `ActiveSupport::Notifications` subscribers. No interaction with Action Cable, background jobs, or mailers (lograge intentionally ignores those).
- **Error propagation:** The per-request `user_id` lookup is double-guarded (`defined?` check + `rescue StandardError`), so a broken `Current.user` method cannot take down request logging for the whole app.
- **State lifecycle:** None — the initializer is load-once, no mutable state beyond lograge's own subscribers.

## Risks & Dependencies

- **Lograge gem maintenance.** Currently maintained but slow-moving (last major release Aug 2024). A Rails 8.x compatibility break would force re-evaluation. Mitigation: `assert_rails_boots` in the test catches this on every CI run.
- **Params-filtering regression in lograge.** If a future lograge release changes how `custom_payload` receives the controller, the `request.filtered_parameters` call could break. Mitigation: explicit test assertion that the string `event.payload[:params]` never appears in the initializer keeps us on the safe path.
- **API-only branch not tested.** The `Rails.application.config.api_only` branch is not exercised by the test (which uses `rails new --minimal`, not `--api`). Low risk — it's a 3-line static conditional — but worth flagging. Can be added later if a real bug surfaces.
- **Test suite runtime.** Adds one more `create_rails_app` (~30–60s). Consistent with existing template tests.
- **No staging env in tests.** The staging branch of the post-install `say` message is not asserted. Low value to test; the conditional is trivial.

## Documentation / Operational Notes

- No site-wide documentation changes required beyond the new `lograge.md` page.
- No runbook or operational rollout concerns — this is a template consumed by other projects, not production code for the site itself.

## Sources & References

- **Origin issue:** [GitHub issue #22](https://github.com/andycroll/railstemplates.org/issues/22)
- **Closest prior plan:** [`docs/plans/2026-04-15-001-feat-dependabot-template-plan.md`](./2026-04-15-001-feat-dependabot-template-plan.md)
- **Pattern references:** `_templates/simplecov-rails/template.rb`, `_templates/standard-rb/template.rb`, `_templates/dependabot/template.rb`
- **Test harness:** `test/templates_test.rb`, `test/test_helper.rb`
- **Jekyll plumbing:** `_plugins/raw_templates.rb`, `_plugins/template_source.rb`, `_layouts/template.html`, `_config.yml`
- **Lograge docs:** [roidrage/lograge README](https://github.com/roidrage/lograge)
- **Params-filter footgun:** [lograge issue #28](https://github.com/roidrage/lograge/issues/28), [issue #229](https://github.com/roidrage/lograge/issues/229)
- **Query-string filtering background:** [Logging URI query params with lograge — Bibliographic Wilderness](https://bibwild.wordpress.com/2021/08/04/logging-uri-query-params-with-lograge/)
