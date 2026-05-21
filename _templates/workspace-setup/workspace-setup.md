---
layout: template
title: Workspace Setup
description: Bootstrap parallel git worktrees (Conductor, plain git worktree, dev containers) with deterministic ports, Redis DBs, and copied credentials
---

Installs a single `bin/workspace-setup` script that makes parallel worktrees boot cleanly. Runs anywhere `git worktree` does — Conductor, plain `git worktree add`, dev containers, Superset — without colliding on ports, Redis databases, or missing credentials.

## What It Does

Running `bin/workspace-setup` from inside a worktree:

1. Picks a stable workspace name from the first of: `$WORKSPACE_NAME`, `$CONDUCTOR_WORKSPACE_NAME`, then the directory basename.
2. Detects the main worktree via `git worktree list --porcelain` and copies `config/master.key` and `config/credentials/*.key` from it if those files are missing locally.
3. Runs `bundle install` and `bin/rails db:prepare`.
4. Derives a deterministic port (3001–3999) and Redis DB (1–15) from a SHA1 of the workspace name.
5. Writes those values into `.env.development.local` between sentinel markers, leaving lines outside the block untouched.
6. Drops a `conductor.json` stub only when Conductor environment variables are present.

## Workspace Name Resolution

The script picks the first non-empty value:

```
$WORKSPACE_NAME → $CONDUCTOR_WORKSPACE_NAME → File.basename(Dir.pwd)
```

Set `WORKSPACE_NAME` explicitly if you want stable ports across renamed directories or shared dev containers. Conductor users get the right behaviour for free via `$CONDUCTOR_WORKSPACE_NAME`.

## Deterministic Port and Redis DB

Both values come from `Digest::SHA1.hexdigest(workspace_name).to_i(16)`:

| Value     | Formula                          | Range     |
|-----------|----------------------------------|-----------|
| Port      | `3001 + (sha1 % 999)`            | 3001–3999 |
| Redis DB  | `(sha1 % 15) + 1`                | 1–15      |

Redis DB `0` is reserved for the main worktree. Two workspaces with the same name will collide; two workspaces with different names almost never will.

## The Managed Block

`.env.development.local` is rewritten between two sentinel lines:

```
# === workspace-setup managed start ===
WORKSPACE_NAME=feature-branch
PORT=3412
REDIS_DB=7
REDIS_URL=redis://localhost:6379/7
# === workspace-setup managed end ===
```

Anything outside the markers is preserved on every re-run. Anything inside is rewritten from scratch. Hand-edit freely above or below the markers; let the script own everything between them.

## Re-running Safely

The template is idempotent: re-applying it produces a byte-identical `bin/workspace-setup` (the `create_file` call uses `skip: true`). Running the script itself is idempotent too — same workspace name in, same port and Redis DB out, same managed block written.

## Use With Conductor

When `$CONDUCTOR_WORKSPACE_NAME`, `$CONDUCTOR_ROOT_PATH`, or `$CONDUCTOR_WORKSPACE_PATH` is set, the script writes a small `conductor.json` stub recording the workspace name and chosen port. Conductor doesn't strictly need it, but it's a convenient place to hang per-workspace metadata.
