---
layout: template
title: StandardRB (Replace Omakase)
description: Replace Rails default linting with StandardRB for zero-config Ruby style enforcement
---

Replaces rubocop-rails-omakase with [StandardRB](https://github.com/standardrb/standard), a zero-configuration Ruby style guide enforcer.

## What It Does

- Removes the `rubocop-rails-omakase` gem
- Adds the `standard` gem to your development/test group
- Replaces `.rubocop.yml` with StandardRB configuration
- Removes `.rubocop_todo.yml` for a fresh start

## After Installation

Auto-fix your codebase:

    bundle exec rubocop -A

## Configuration

The generated `.rubocop.yml` uses the [recommended StandardRB configuration](https://github.com/standardrb/standard?tab=readme-ov-file#running-standards-rules-via-rubocop):

    require:
      - standard

    plugins:
      - standard-custom
      - standard-performance
      - rubocop-performance

    inherit_gem:
      standard: config/base.yml
      standard-custom: config/base.yml
      standard-performance: config/base.yml

    AllCops:
      NewCops: enable

You can extend this with additional RuboCop plugins (rubocop-rails, rubocop-rspec, etc.) as needed.

## Why StandardRB?

StandardRB offers:
- **Zero configuration** - no bikeshedding over style rules
- **Community-driven** - based on the popular StandardJS philosophy
- **Consistent** - same rules across all your Ruby projects
