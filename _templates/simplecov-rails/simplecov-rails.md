---
layout: template
title: SimpleCov with Minitest Parallelism
description: Set up SimpleCov code coverage with proper support for Minitest parallel test execution
---

Configures SimpleCov for Rails with Minitest, including proper parallel test support (which doesn't work out of the box).

Coverage runs automatically in CI or when you set `COVERAGE=true`. Reports are generated in `/coverage/index.html`.

## What It Does

- Installs SimpleCov with the Rails preset and branch coverage
- Adds parallelization hooks so coverage works with Minitest's parallel workers
- Excludes test, config, vendor, and generator files

## Parallel Test Fix

The template adds hooks based on [this SimpleCov issue comment](https://github.com/simplecov-ruby/simplecov/issues/1082#issuecomment-2496040512):

```ruby
if ENV["CI"] || ENV["COVERAGE"]
  parallelize_setup do |worker|
    SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
  end

  parallelize_teardown do |worker|
    SimpleCov.result
  end
end
```

Each parallel worker writes its own coverage data, which SimpleCov then merges into a single report.
