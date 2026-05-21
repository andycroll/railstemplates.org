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
  #   2. Copies Rails credential keys from the main worktree if missing locally.
  #   3. Runs `bundle install` and `bin/rails db:prepare`.
  #   4. Derives a deterministic port (3001-3999) and Redis DB (1-15) from the name.
  #   5. Writes those values into `.env.development.local` between sentinel markers,
  #      leaving any of your own lines outside the markers untouched.
  #   6. Drops a `conductor.json` stub when running under Conductor.
  #
  # Re-running is safe: same name in, same values out, same managed block written.

  require "digest"
  require "fileutils"

  MANAGED_START = "# === workspace-setup managed start ===".freeze
  MANAGED_END   = "# === workspace-setup managed end ===".freeze
  ENV_FILE      = ".env.development.local".freeze

  def workspace_name
    ENV["WORKSPACE_NAME"] ||
      ENV["CONDUCTOR_WORKSPACE_NAME"] ||
      File.basename(Dir.pwd)
  end

  def conductor?
    !ENV["CONDUCTOR_WORKSPACE_NAME"].to_s.empty? ||
      !ENV["CONDUCTOR_ROOT_PATH"].to_s.empty? ||
      !ENV["CONDUCTOR_WORKSPACE_PATH"].to_s.empty?
  end

  def derived_port(name)
    3001 + (Digest::SHA1.hexdigest(name).to_i(16) % 999)
  end

  def derived_redis_db(name)
    Digest::SHA1.hexdigest(name).to_i(16) % 15 + 1
  end

  def main_worktree_path
    output = `git worktree list --porcelain 2>/dev/null`
    return nil if output.empty?

    paths = output.lines.grep(/\Aworktree /).map { |l| l.sub(/\Aworktree /, "").strip }
    current = File.expand_path(Dir.pwd)
    # The first worktree returned by git is the main one.
    main = paths.first
    return nil if main.nil? || File.expand_path(main) == current
    main
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

  def run_bundle_install
    system("bundle", "install") || abort("bundle install failed")
  end

  def run_db_prepare
    return unless File.exist?("bin/rails")
    system("bin/rails", "db:prepare") ||
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

  def write_conductor_stub(name, port)
    stub = <<~JSON
      {
        "name": #{name.inspect},
        "port": #{port},
        "managed_by": "bin/workspace-setup"
      }
    JSON
    File.write("conductor.json", stub) unless File.exist?("conductor.json")
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

  run_bundle_install
  run_db_prepare

  managed = <<~ENVBODY
    # Managed by bin/workspace-setup. Edits inside this block are overwritten.
    WORKSPACE_NAME=#{name}
    PORT=#{port}
    REDIS_DB=#{redis}
    REDIS_URL=redis://localhost:6379/#{redis}
  ENVBODY

  upsert_managed_block(ENV_FILE, managed)
  puts "wrote #{ENV_FILE} (managed block)"

  if conductor?
    write_conductor_stub(name, port)
    puts "wrote conductor.json"
  end

  puts "done."
RUBY

create_file "bin/workspace-setup", script_body, skip: true
chmod "bin/workspace-setup", 0755

say ""
say "bin/workspace-setup installed.", :green
say "Run `bin/workspace-setup` from any worktree to:", :blue
say "  - copy config/master.key + config/credentials/*.key from the main worktree"
say "  - bundle install + bin/rails db:prepare"
say "  - derive a deterministic PORT (3001-3999) and REDIS_DB (1-15)"
say "  - write them into .env.development.local between sentinel markers"
say ""
say "Override the workspace name with $WORKSPACE_NAME if you want stable ports", :yellow
say "across renamed directories. Conductor's $CONDUCTOR_WORKSPACE_NAME is honoured", :yellow
say "automatically.", :yellow
