---
layout: template
title: Procfile.dev
description: Standard Procfile.dev with attachable debugger, plus optional Tailwind watch and Solid Queue jobs runner
---

Writes a canonical `Procfile.dev` so `bin/dev` boots web, CSS, and background jobs together — and lets you attach a debugger to the running web process with one command.

## What It Does

- Writes `Procfile.dev` with:
  - **`web:`** — always included, prefixed with `env RUBY_DEBUG_OPEN=true` so [`debug`](https://github.com/ruby/debug) opens a remote console you can attach to.
  - **`css:`** — added when `tailwindcss-rails` is present (in `Gemfile.lock` or `Gemfile`).
  - **`jobs:`** — added when Solid Queue is detected (gem present, or `bin/jobs` exists).
- Adds a header comment documenting how to attach the debugger.

## The Resulting File

A fresh `--minimal` app gets just the web process:

```
# Procfile.dev — managed by railstemplates.org/procfile-dev
#
# Start every dev process with: bin/dev
# Attach the debugger to the running web process with: rdbg -A

web: env RUBY_DEBUG_OPEN=true bin/rails server -p ${PORT:-3000}
```

An app with Tailwind and Solid Queue gets all three:

```
# Procfile.dev — managed by railstemplates.org/procfile-dev
#
# Start every dev process with: bin/dev
# Attach the debugger to the running web process with: rdbg -A

web: env RUBY_DEBUG_OPEN=true bin/rails server -p ${PORT:-3000}
css: bin/rails tailwindcss:watch[always]
jobs: bin/jobs
```

## Attaching the Debugger

With `RUBY_DEBUG_OPEN=true` on the web process, `debug` exposes a UNIX socket on first request. Drop a `debugger` (or `binding.break`) in your code, then from another shell:

```
rdbg -A
```

You get a full interactive console at the breakpoint — no need to restart, no detour through `bin/rails console`.

This relies on the [`debug`](https://github.com/ruby/debug) gem, which ships in Rails' default `Gemfile` (`group :development, :test`). The template assumes it's there rather than adding it — if you've removed `debug`, add it back before using `rdbg -A`.

## Why These Defaults

- **`RUBY_DEBUG_OPEN=true` on web only.** The debugger socket belongs on the request-handling process. Adding it to background workers usually just confuses things — attach to the worker explicitly when you need to.
- **`env VAR=value`, not a bare `VAR=value` prefix.** Only a shell honours a bare leading assignment, and a Procfile line isn't guaranteed to be run through one. `env` is a real executable, so the variable reaches the server under every process manager (foreman, overmind, hivemind).
- **`tailwindcss:watch[always]`, not plain `tailwindcss:watch`.** Under a process manager stdout is a pipe, not a TTY, and the watcher exits immediately without the `always` argument — you get one build and then silence, with no error to explain it.
- **Conditional `css:` and `jobs:`.** Hard-coding processes the app doesn't have means `bin/dev` crashes on boot. Only managed lines for tools that are actually installed get written.
- **Header comment.** The `rdbg -A` incantation is easy to forget. The Procfile is where you'll be looking when you want it.

## Re-running Safely

The template is idempotent:

- An existing `web:` line is preserved verbatim, except `env RUBY_DEBUG_OPEN=true` is prepended if missing.
- Existing custom `css:` or `jobs:` lines are left alone.
- Re-applying produces no new lines and no duplicates.

You can hand-edit any line later — only the managed process names (`web:`, `css:`, `jobs:`) are touched, and only when something needs to change.
