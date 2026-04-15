---
title: "feat: Add Dependabot configuration template for Rails apps"
type: feat
status: active
date: 2026-04-15
---

# Add Dependabot Configuration Template

## Overview

Add a new Rails application template that generates a sensible `.github/dependabot.yml` and a `.github/workflows/dependabot-auto-merge.yml` workflow. The template auto-detects whether npm/yarn is needed, uses cooldowns to mitigate supply chain attacks, groups updates to reduce PR noise, and sets up conservative automerging for patch versions only.

## Problem Frame

Rails developers need a secure-by-default Dependabot setup. The default Dependabot config (no grouping, no cooldowns, no automerge) produces excessive PR noise and lacks supply chain protections. Setting up automerge safely requires understanding branch protection prerequisites, the `dependabot/fetch-metadata` action, and the security distinction between production and development dependencies.

## Requirements Trace

- R1. Auto-detect ecosystems: always `bundler`, conditionally `npm` (if `package.json` exists), always `github-actions` (if `.github/workflows/` exists)
- R2. Use cooldowns to delay PRs for newly-published packages (supply chain defense)
- R3. Group patch and minor updates to reduce PR noise; leave majors ungrouped for individual review
- R4. Create automerge workflow that only merges patch versions of production deps, patch+minor for dev deps and GitHub Actions
- R5. Print clear messaging about prerequisites (branch protection, required status checks, enable auto-merge in repo settings)
- R6. Template follows existing project conventions (create_file, say, after_bundle pattern)
- R7. Tests cover bundler-only and bundler+npm scenarios

## Scope Boundaries

- Does NOT configure branch protection rules (that's a repo settings concern, not a file)
- Does NOT install Dependabot itself (it's a GitHub-native feature)
- Does NOT handle monorepo/multi-directory setups
- Does NOT configure `ignore` rules (too app-specific)

## Context & Research

### Relevant Code and Patterns

- `_templates/simplecov-rails/template.rb` — best example of `create_file` with heredoc content, conditional logic based on file existence
- `_templates/coverage-comments/template.rb` — example of creating GHA workflow files, the `create_file path, content, skip: true` pattern
- `test/templates_test.rb` — test pattern: `create_rails_app`, `apply_template`, assert file contents, `assert_rails_boots`

### Key Research Findings

- **Cooldowns** (GA since July 2025) delay version update PRs until packages have been published for N days. Critical defense — the axios supply chain attack of 2025 compromised 895+ repos within minutes because Dependabot created PRs immediately. Cooldowns do NOT apply to security updates (CVE patches still flow immediately).
- **Security updates vs version updates are separate systems** — `open-pull-requests-limit: 0` only disables version updates; security updates still work independently.
- **`dependabot/fetch-metadata@v2`** extracts `update-type`, `dependency-type`, and `package-ecosystem` — the standard way to gate automerge decisions.
- **`pull_request_target`** is required (not `pull_request`) for the automerge workflow to have write permissions on Dependabot PRs.
- **`gh pr merge --auto --squash`** requires branch protection with required status checks — without it, the merge happens immediately with no CI gate.
- npm should have longer cooldowns than bundler due to larger attack surface and post-install scripts.

## Key Technical Decisions

- **Patch-only automerge for production deps**: Minor versions can contain breaking changes and are a common supply chain attack vector. Dev deps and GitHub Actions get patch+minor automerge since they don't run in production.
- **Cooldowns: 3 days default, 7 for major, 5 for minor, 3 for patch**: Conservative defaults that give the community time to detect compromised packages. npm gets longer cooldowns (5/10/7/5).
- **Single template, not two**: Dependabot without automerge is incomplete. Bundling both files avoids the friction of a prerequisite chain.
- **Inline YAML generation, no `fetch_file`**: Both generated files are static YAML with conditional sections. No need for the download pattern used by daisyui/coverage-comments.
- **`create_file ... skip: true`**: Don't overwrite existing dependabot.yml or automerge workflow — respect existing configuration.
- **Always suggest `github-actions` ecosystem**: Check for `.github/workflows/` directory existence. Since this template itself creates a workflow file, the directory will exist by the time dependabot.yml is read.

## Open Questions

### Resolved During Planning

- **Should npm and yarn be detected separately?** No — Dependabot uses the `npm` ecosystem identifier for both npm and yarn. It auto-detects the lockfile.
- **Should we group security updates?** Yes — group security patch+minor updates to reduce noise from batch CVE fixes. Security updates bypass cooldowns regardless.
- **Weekly or daily schedule?** Weekly on Monday. Daily is too noisy for most projects.

### Deferred to Implementation

- Exact emoji choices for `say` messages (follow existing template style)
- Whether the `.md` page needs a "Customization" section showing how to adjust cooldown values

## Implementation Units

- [ ] **Unit 1: Template script**

  **Goal:** Create `_templates/dependabot/template.rb` that generates both config files

  **Requirements:** R1, R2, R3, R4, R5, R6

  **Dependencies:** None

  **Files:**
  - Create: `_templates/dependabot/template.rb`

  **Approach:**
  - Standard template header with `say "railstemplates.org"` and description
  - Build `dependabot.yml` content as a string, starting with the bundler ecosystem block (always present)
  - Check `File.exist?("package.json")` to conditionally append npm ecosystem block with longer cooldowns
  - Check `Dir.exist?(".github/workflows")` to conditionally append github-actions ecosystem block
  - Use `create_file ".github/dependabot.yml", content, skip: true`
  - Build automerge workflow YAML as a second heredoc string
  - Use `create_file ".github/workflows/dependabot-auto-merge.yml", content, skip: true`
  - Print prerequisite messaging about branch protection and enabling auto-merge in repo settings

  **dependabot.yml structure per ecosystem:**
  - `schedule: { interval: weekly, day: monday }`
  - `open-pull-requests-limit: 10` (5 for github-actions)
  - `labels: ["dependencies"]`
  - `groups:` with `patch-updates` and `minor-updates` groups (both `version-updates` and `security-updates`)
  - `cooldown:` with ecosystem-appropriate values (bundler: 3/7/5/3, npm: 5/10/7/5, github-actions: 3/7/5/3)

  **automerge workflow structure:**
  - Trigger: `pull_request_target`
  - Condition: `github.event.pull_request.user.login == 'dependabot[bot]'`
  - Step 1: `dependabot/fetch-metadata@v2`
  - Step 2: Auto-merge production patch updates
  - Step 3: Auto-merge dev dependency patch+minor updates
  - Step 4: Auto-merge GitHub Actions patch+minor updates

  **Patterns to follow:**
  - `_templates/simplecov-rails/template.rb` for heredoc + create_file pattern
  - `_templates/coverage-comments/template.rb` for GHA workflow creation and `skip: true`

  **Test scenarios:** Covered by Unit 3

  **Verification:** Template file exists and follows project conventions

- [ ] **Unit 2: Documentation page**

  **Goal:** Create the Jekyll markdown page for the template

  **Requirements:** R5

  **Dependencies:** None (can be done in parallel with Unit 1)

  **Files:**
  - Create: `_templates/dependabot/dependabot.md`

  **Approach:**
  - Frontmatter: `layout: template`, `title: Dependabot with Automerge`, descriptive `description`
  - Brief intro explaining what the template does
  - "What It Does" section: ecosystem detection, grouping, cooldowns, automerge
  - "Update Strategy" section: table showing automerge policy by category (prod patch, dev patch+minor, major manual, GHA patch+minor)
  - "Security" section: explain cooldowns, why patch-only for production, prerequisites
  - "Prerequisites" section: branch protection requirements for automerge to work

  **Patterns to follow:**
  - `_templates/simplecov-rails/simplecov-rails.md` for length and style

  **Verification:** Page renders correctly in Jekyll (visual check)

- [ ] **Unit 3: Tests**

  **Goal:** Add tests covering both bundler-only and bundler+npm scenarios

  **Requirements:** R1, R7

  **Dependencies:** Units 1 and 2 must exist

  **Files:**
  - Modify: `test/templates_test.rb`

  **Approach:**
  - `test_dependabot`: Create minimal Rails app (no package.json), apply template, assert:
    - `.github/dependabot.yml` exists and contains `bundler` ecosystem
    - `.github/dependabot.yml` does NOT contain `npm` ecosystem
    - `.github/dependabot.yml` contains `github-actions` ecosystem (because the automerge workflow creates the `.github/workflows/` dir)
    - `.github/dependabot.yml` contains `cooldown` configuration
    - `.github/dependabot.yml` contains `groups` configuration
    - `.github/workflows/dependabot-auto-merge.yml` exists
    - Automerge workflow contains `dependabot/fetch-metadata`
    - Automerge workflow contains `semver-patch` check
    - App still boots
  - `test_dependabot_with_npm`: Create minimal Rails app, add a `package.json` file, apply template, assert:
    - `.github/dependabot.yml` contains both `bundler` and `npm` ecosystems
    - npm section has its own cooldown values
    - App still boots

  **Patterns to follow:**
  - Existing tests in `test/templates_test.rb` — same setup/teardown, `create_rails_app`, `apply_template`, `assert_rails_boots`

  **Verification:** `bundle exec rake test` passes with new tests

## System-Wide Impact

- **Plugin interaction:** `_plugins/raw_templates.rb` will automatically pick up `_templates/dependabot/template.rb` and serve it at `/dependabot/template` — no plugin changes needed
- **Jekyll collection:** `_config.yml` templates collection will include the new `.md` file automatically
- **No gem dependencies:** This template doesn't add gems, so no Gemfile or bundle interaction

## Risks & Dependencies

- **Cooldown syntax may evolve**: The `cooldown` key in dependabot.yml was GA'd in July 2025 — verify the exact YAML syntax is current
- **Tests create real Rails apps**: Each test takes 30-60 seconds. Adding two tests adds ~2 minutes to the test suite. This is consistent with existing test approach.
- **Branch protection prerequisite**: The automerge workflow silently does nothing without branch protection. The template prints warnings but can't enforce this. Clear messaging is the mitigation.

## Sources & References

- [GitHub Docs: Dependabot options reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)
- [GitHub Docs: Automating Dependabot with GitHub Actions](https://docs.github.com/en/code-security/tutorials/secure-your-dependencies/automating-dependabot-with-github-actions)
- [dependabot/fetch-metadata](https://github.com/dependabot/fetch-metadata)
- [GitHub Blog: Dependabot cooldown support](https://github.blog/changelog/2025-07-01-dependabot-supports-configuration-of-a-minimum-package-age/)
