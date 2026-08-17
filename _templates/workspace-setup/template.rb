#!/usr/bin/env ruby

# Workspace Setup Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/workspace-setup/template
# Usage: rails app:template LOCATION=https://railstemplates.org/workspace-setup/template

say "railstemplates.org"
say "Installing bin/workspace-setup for parallel worktrees...", :green

script_body = <<~'RUBY'
  #!/usr/bin/env ruby

  # bin/workspace-setup
  #
  # Bootstraps a Rails worktree (Conductor, plain `git worktree`, dev containers,
  # Superset, etc.) so it can run alongside the main checkout without colliding.
  #
  # What it does:
  #   1. Picks a stable workspace name (env vars first, then the directory).
  #   2. Copies Rails credential keys from the main checkout if missing locally.
  #   3. Runs `bundle install` and `bin/rails db:prepare`, through `mise x --`
  #      when mise manages this repo.
  #   4. Derives a deterministic port (3001-3999) and Redis DB (1-15) from the name.
  #   5. Writes those values into `.env.development.local` between sentinel markers,
  #      leaving any of your own lines outside the markers untouched.
  #
  # Re-running is safe: same name in, same values out, same managed block written.
  #
  # Conductor invokes this via the committed `conductor.json` in the repo root.

  require "digest"
  require "fileutils"

  MANAGED_START = "# === workspace-setup managed start ===".freeze
  MANAGED_END   = "# === workspace-setup managed end ===".freeze
  ENV_FILE      = ".env.development.local".freeze

  def workspace_name
    env_value("WORKSPACE_NAME") ||
      env_value("CONDUCTOR_WORKSPACE_NAME") ||
      File.basename(Dir.pwd)
  end

  def derived_port(name)
    3001 + (Digest::SHA1.hexdigest(name).to_i(16) % 999)
  end

  def derived_redis_db(name)
    Digest::SHA1.hexdigest(name).to_i(16) % 15 + 1
  end

  # Path to the main checkout, or nil if we're already in it.
  #
  # The workspace manager's own env var wins over `git worktree list`. Conductor
  # and Superset both hand us the path outright, and they know their own layout
  # better than we can infer it — the git fallback assumes the main checkout is
  # the first entry, which holds for plain `git worktree` but isn't guaranteed.
  def main_worktree_path
    main = env_value("CONDUCTOR_ROOT_PATH") ||
      env_value("SUPERSET_ROOT_PATH") ||
      first_git_worktree
    return nil if main.nil? || File.expand_path(main) == File.expand_path(Dir.pwd)
    main
  end

  # This is a plain Ruby script, so no ActiveSupport `presence`. An env var set
  # to the empty string is as good as unset.
  def env_value(key)
    value = ENV[key]
    (value.nil? || value.empty?) ? nil : value
  end

  def first_git_worktree
    output = `git worktree list --porcelain 2>/dev/null`
    return nil if output.empty?
    output.lines.grep(/\Aworktree /).map { |l| l.sub(/\Aworktree /, "").strip }.first
  end

  def copy_credentials_from(main_path)
    return unless main_path && Dir.exist?(main_path)

    sources = []
    master_key = File.join(main_path, "config", "master.key")
    sources << master_key if File.exist?(master_key)
    sources.concat(Dir[File.join(main_path, "config", "credentials", "*.key")])

    sources.each do |src|
      rel = src.sub(/\A#{Regexp.escape(main_path)}\/?/, "")
      dest = File.join(Dir.pwd, rel)
      next if File.exist?(dest)

      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(src, dest)
      puts "  copied #{rel}"
    end
  end

  # A fresh worktree usually has no Ruby activated for it yet, so a bare
  # `bundle install` can run under whatever Ruby happens to be on PATH — the
  # system one, or the last project's. When mise manages this repo, route both
  # commands through `mise x --` so they get the Ruby `.ruby-version` asks for.
  # Other version managers (rbenv, chruby, asdf) hook the shell and need no
  # help here.
  def mise_prefix
    return [] unless File.exist?(".ruby-version") || File.exist?("mise.toml") || File.exist?(".mise.toml")
    return [] unless system("command -v mise > /dev/null 2>&1")
    system("mise", "install") # no-op when the Ruby is already installed
    ["mise", "x", "--"]
  end

  def run_bundle_install(prefix)
    system(*prefix, "bundle", "install") || abort("bundle install failed")
  end

  def run_db_prepare(prefix)
    return unless File.exist?("bin/rails")
    system(*prefix, "bin/rails", "db:prepare") ||
      warn("bin/rails db:prepare failed (continuing)")
  end

  def upsert_managed_block(path, body)
    lines = File.exist?(path) ? File.read(path).lines : []

    in_block = false
    preserved = lines.reject do |line|
      stripped = line.chomp
      if stripped == MANAGED_START
        in_block = true
        true
      elsif stripped == MANAGED_END
        in_block = false
        true
      else
        in_block
      end
    end

    preserved.pop while preserved.last && preserved.last.strip.empty?

    block = [MANAGED_START, *body.lines.map(&:chomp), MANAGED_END].join("\n") + "\n"
    output = preserved.join
    output << "\n" unless output.empty? || output.end_with?("\n")
    output << "\n" unless output.empty?
    output << block

    File.write(path, output)
  end

  name  = workspace_name
  port  = derived_port(name)
  redis = derived_redis_db(name)

  puts "workspace-setup"
  puts "  name:     #{name}"
  puts "  port:     #{port}"
  puts "  redis db: #{redis}"

  main = main_worktree_path
  copy_credentials_from(main) if main

  prefix = mise_prefix
  run_bundle_install(prefix)
  run_db_prepare(prefix)

  managed = <<~ENVBODY
    # Managed by bin/workspace-setup. Edits inside this block are overwritten.
    WORKSPACE_NAME=#{name}
    PORT=#{port}
    REDIS_DB=#{redis}
    REDIS_URL=redis://localhost:6379/#{redis}
  ENVBODY

  upsert_managed_block(ENV_FILE, managed)
  puts "wrote #{ENV_FILE} (managed block)"

  puts "done."
RUBY

create_file "bin/workspace-setup", script_body, skip: true
chmod "bin/workspace-setup", 0755

# conductor.json is how Conductor finds the script — it reads a committed file in
# the repo root and runs the named scripts. It has to exist before a workspace is
# created, so it's written here at apply time rather than by the setup script
# itself (which only ever runs *inside* an already-created workspace).
#
# `runScriptMode: nonconcurrent` so setup finishes before run starts; two
# concurrent `bundle install`s on the same gem home fight each other.
conductor_json = <<~'JSON'
  {
    "scripts": {
      "setup": "./bin/workspace-setup",
      "run": "./bin/dev"
    },
    "runScriptMode": "nonconcurrent"
  }
JSON

create_file "conductor.json", conductor_json, skip: true

say ""
say "bin/workspace-setup installed.", :green
say "Run `bin/workspace-setup` from any worktree to:", :blue
say "  - copy config/master.key + config/credentials/*.key from the main checkout"
say "  - bundle install + bin/rails db:prepare (through mise when it manages this repo)"
say "  - derive a deterministic PORT (3001-3999) and REDIS_DB (1-15)"
say "  - write them into .env.development.local between sentinel markers"
say ""
say "conductor.json wires Conductor's setup/run scripts to bin/workspace-setup", :blue
say "and bin/dev. Superset and plain `git worktree` need no config — the script", :blue
say "resolves the main checkout from $CONDUCTOR_ROOT_PATH, $SUPERSET_ROOT_PATH,", :blue
say "then `git worktree list`.", :blue
say ""
say "Override the workspace name with $WORKSPACE_NAME if you want stable ports", :yellow
say "across renamed directories. Conductor's $CONDUCTOR_WORKSPACE_NAME is honoured", :yellow
say "automatically.", :yellow
