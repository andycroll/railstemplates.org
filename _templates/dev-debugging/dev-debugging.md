---
layout: template
title: Development Debugging Stack
description: Install debug, debugbar, web-console, and rack-mini-profiler with a sensible development-scoped initializer
---

Installs an opinionated development debugging stack: [`debug`](https://github.com/ruby/debug), [`debugbar`](https://github.com/SaladinoKlein/debugbar), [`web-console`](https://github.com/rails/web-console), and [`rack-mini-profiler`](https://github.com/MiniProfiler/rack-mini-profiler). Adds a `config/initializers/rack_mini_profiler.rb` scoped to development.

## What It Does

- Adds (if not already present) the following gems to the `:development` group:
  - `debug` — Ruby's modern built-in debugger (`binding.break`, remote sessions, breakpoints)
  - `debugbar` — in-browser debug bar showing queries, params, exceptions, and request timing
  - `web-console` — interactive Rails console on error pages
  - `rack-mini-profiler` — request/SQL/render timing badge in the corner of every page
- Creates `config/initializers/rack_mini_profiler.rb` with development-only configuration
- Emits a post-install instruction to mount Debugbar in `app/views/layouts/application.html.erb`

## Why The Layout Edit Is Manual

Debugbar requires `<%= debugbar %>` inside the `<body>` of your application layout. Patching `application.html.erb` automatically is risky — apps customise layouts in dozens of incompatible ways, and a regex-based injection can land in the wrong place or duplicate on re-run. The template prints the exact line to add so you can place it where it belongs.

Add this line just before `</body>` in `app/views/layouts/application.html.erb`:

```erb
<%= debugbar %>
```

See the [Debugbar README](https://github.com/SaladinoKlein/debugbar) for mount details and configuration.

## Why These Defaults

- **All four in `:development` only.** None should ship to production. `web-console` in particular is a remote-code-execution risk if it ever loads in production.
- **`rack-mini-profiler` initializer is guarded by `Rails.env.development?`.** Even if the gem ever leaks into another group, the configuration short-circuits outside development.
- **Idempotent.** Re-running the template detects each gem in the `Gemfile` and skips adds. The initializer is only written when `config/initializers/rack_mini_profiler.rb` is absent, so existing customisations are preserved.

## Re-running Safely

The template is safe to re-run: gems already present in the `Gemfile` are skipped, and the initializer file is created only if it does not already exist.
