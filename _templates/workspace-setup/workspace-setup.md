---
layout: template
title: Workspace Setup
description: Bootstrap parallel git worktrees (Conductor, plain git worktree, dev containers) with deterministic ports, Redis DBs, and copied credentials
---

Installs a single `bin/workspace-setup` script that makes parallel worktrees boot cleanly. Runs anywhere `git worktree` does — Conductor, plain `git worktree add`, dev containers, Superset — without colliding on ports, Redis databases, or missing credentials.

## What It Does

Running `bin/workspace-setup` from inside a worktree:

1. Picks a stable workspace name from the first of: `$WORKSPACE_NAME`, `$CONDUCTOR_WORKSPACE_NAME`, then the directory basename.
2. Resolves the main checkout from the first of: `$CONDUCTOR_ROOT_PATH`, `$SUPERSET_ROOT_PATH`, then the first entry of `git worktree list --porcelain`. Copies `config/master.key` and `config/credentials/*.key` from it if those files are missing locally.
3. Runs `bundle install` and `bin/rails db:prepare` — through `mise x --` when mise manages this repo, so a brand-new worktree doesn't bundle under the wrong Ruby.
4. Derives a deterministic port (3001–3999) and Redis DB (1–15) from a SHA1 of the workspace name.
5. Writes those values into `.env.development.local` between sentinel markers, leaving lines outside the block untouched.

The template also writes a `conductor.json` in the repo root, which is how Conductor finds the script.

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

The template is idempotent: re-applying it produces byte-identical `bin/workspace-setup` and `conductor.json` files (both `create_file` calls use `skip: true`). Running the script itself is idempotent too — same workspace name in, same port and Redis DB out, same managed block written.

## Use With Conductor

The template writes a `conductor.json` in the repo root:

```json
{
  "scripts": {
    "setup": "./bin/workspace-setup",
    "run": "./bin/dev"
  },
  "runScriptMode": "nonconcurrent"
}
```

Conductor reads this committed file to decide what to run when it creates a workspace, so it has to exist *before* any workspace does — which is why the template writes it at apply time rather than having `bin/workspace-setup` write it. A script that only ever runs inside an already-created workspace can't bootstrap the file that causes it to be run.

`runScriptMode: nonconcurrent` makes setup finish before run starts. Without it, two concurrent `bundle install`s share a gem home and fight.

## Use With Superset, Or Plain git worktree

Nothing to configure. `bin/workspace-setup` resolves the main checkout from `$SUPERSET_ROOT_PATH` when Superset sets it, and otherwise falls back to `git worktree list`. Run it yourself after `git worktree add`.

The workspace manager's own env var wins over the git fallback deliberately: Conductor and Superset hand you the path outright and know their layout better than we can infer it. The git fallback assumes the main checkout is the first entry, which holds for plain `git worktree` but isn't guaranteed everywhere.
