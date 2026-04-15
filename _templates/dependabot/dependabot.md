---
layout: template
title: Dependabot with Automerge
description: Configure Dependabot with grouped updates, supply chain cooldowns, and safe automerging for Rails apps
---

Sets up Dependabot with sensible defaults: grouped updates to reduce PR noise, cooldowns to defend against supply chain attacks, and a GitHub Actions workflow that automerges low-risk updates after CI passes.

## What It Does

- Configures Dependabot for `bundler` (always) and `npm` (if `package.json` exists)
- Adds `github-actions` ecosystem to keep your CI actions up to date
- Groups patch and minor updates together so you get fewer, larger PRs
- Adds cooldowns that delay PRs for newly-published packages
- Creates an automerge workflow gated on CI status checks

## Update Strategy

| Category | Automerge? | Rationale |
|----------|-----------|-----------|
| Production deps (patch) | Yes | Low risk, high volume |
| Production deps (minor) | No | Can contain breaking changes; common attack vector |
| Dev deps (patch + minor) | Yes | Not in production bundle |
| GitHub Actions (patch + minor) | Yes | Run in CI, not production |
| Major versions | Never | Always require manual review |

## Supply Chain Protection

The template uses [cooldowns](https://github.blog/changelog/2025-07-01-dependabot-supports-configuration-of-a-minimum-package-age/) to delay version update PRs until packages have been published for several days. This gives the community time to detect and report compromised releases before Dependabot creates PRs in your repo.

- Bundler: 3-day default, 7 days for major, 5 for minor, 3 for patch
- npm: 5-day default, 10 days for major, 7 for minor, 5 for patch (longer due to larger attack surface)

**Security updates (CVE patches) bypass cooldowns entirely** and are delivered immediately.

## Prerequisites

For automerge to work, you need to:

1. **Enable auto-merge** in your repo settings (Settings → General → Pull Requests → "Allow auto-merge")
2. **Add a branch protection rule** for your default branch
3. **Require status checks to pass** (select your CI test job)

Without branch protection and required status checks, `gh pr merge --auto` will merge PRs immediately with no CI gate.
