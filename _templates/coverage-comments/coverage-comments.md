---
layout: template
title: Coverage PR Comments
description: Add coverage reporting to CI that posts results as PR comments with threshold enforcement
---

Adds GitHub Actions integration that analyzes test coverage and posts results as PR comments. Requires the [SimpleCov template](/simplecov-rails/) to be installed first.

## What It Does

- Adds `simplecov-json` gem for JSON coverage output
- Configures SimpleCov to generate JSON reports in CI
- Creates a coverage analysis script that calculates project and PR coverage
- Adds a GitHub Actions workflow job that:
  - Downloads coverage artifacts from your test job
  - Posts/updates a PR comment with coverage summary
  - Fails the build if changed files have less than 90% coverage

## PR Comment Format

The comment shows both overall project coverage and PR-specific metrics:

```
✅ *All New Code Covered*
Pull request coverage is 100.0% (10 of 10 lines across 2 files)
-----
✅ Project coverage is 85.0% (85 of 100 lines)
```

Or when coverage is missing:

```
⚠️ *Coverage Missing*
Pull request coverage is 75.0% (15 of 20 lines across 3 files)
-----
✅ Project coverage is 82.0% (164 of 200 lines)
```

## Prerequisites

1. SimpleCov must be installed (use the [SimpleCov template](/simplecov-rails/) first)
2. Your CI workflow must have a `test` job that runs tests

## Configuration

The coverage threshold (90%) can be adjusted in `.github/scripts/analyze_coverage.rb`:

```ruby
CHANGED_FILES_THRESHOLD = 90
```

## How It Works

The analyzer script:
1. Parses SimpleCov's JSON output for project-wide metrics
2. Uses `git diff` to find Ruby files changed in the PR
3. Cross-references changed files with coverage data
4. Generates a markdown comment summarizing both metrics
5. Outputs GitHub Actions variables for the workflow to use
