---
layout: template
title: SimpleCov with Minitest Parallelism
description: Set up SimpleCov code coverage with proper support for Minitest parallel test execution
---

# SimpleCov with Minitest Parallelism

This template configures SimpleCov for Rails applications using Minitest, with proper support for parallel test execution. Which weirdly doesn't work out of the box.

## Features

- ✅ Installs SimpleCov gem in test group
- ✅ Configures SimpleCov with Rails preset
- ✅ Enables branch coverage reporting
- ✅ Sets up proper parallelization hooks for accurate coverage when using Minitest's parallel workers
- ✅ Excludes test, config, vendor, and generator files from coverage
- ✅ Adds coverage directory to .gitignore

## Usage

### For a new Rails application:
```bash
rails new myapp -m https://railstemplates.org/simplecov-rails/template.rb
```

### For an existing Rails application:
```bash
rails app:template LOCATION=https://railstemplates.org/simplecov-rails/template.rb
```

## Running Tests with Coverage

After installation, run your tests with coverage enabled:

```bash
COVERAGE=true rails test:all
```

Coverage reports will be generated in `/coverage/index.html`.

## What Gets Configured

### Test Helper Setup

The template adds SimpleCov initialization at the beginning of `test/test_helper.rb`:

```ruby
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails" do
    # Exclude files from coverage
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"
    add_filter "/lib/generators/"

    # Enable branch coverage
    enable_coverage :branch
  end
end
```

### Parallel Test Support

For applications using Minitest's parallel test execution, the template adds:

```ruby
if ENV["COVERAGE"]
  parallelize_setup do |worker|
    SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
  end

  parallelize_teardown do |worker|
    SimpleCov.result
  end
end
```

This ensures each parallel worker writes its own coverage data, which SimpleCov then merges into a single report.

This is based on teh code from a [comment on Issue #1082](https://github.com/simplecov-ruby/simplecov/issues/1082#issuecomment-2496040512)

## Customization

After installation, you can customize SimpleCov by editing the configuration in `test/test_helper.rb`:

### Add Custom Groups
```ruby
SimpleCov.start "rails" do
  add_group "Clients", "app/clients"
  add_group "Services", "app/services"
  add_group "Serializers", "app/serializers"
  # ... existing configuration
end
```

### Set Minimum Coverage
```ruby
SimpleCov.start "rails" do
  minimum_coverage 90
  # ... existing configuration
end
```

## Requirements

- Rails application with Minitest (default Rails test framework)
- Ruby 2.5+ (SimpleCov requirement)

## Learn More

- [SimpleCov Documentation](https://github.com/simplecov-ruby/simplecov)
- [SimpleCov Rails Profile](https://github.com/simplecov-ruby/simplecov#rails)
- [Minitest Parallel Testing](https://guides.rubyonrails.org/testing.html#parallel-testing)