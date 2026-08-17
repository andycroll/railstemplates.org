#!/usr/bin/env ruby

# Litestream Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/litestream/template
# Usage: rails app:template LOCATION=https://railstemplates.org/litestream/template

say "railstemplates.org"
say "💧 Configuring Litestream SQLite replication...", :green

if File.exist?("config/litestream.yml")
  say "Litestream config already present, skipping.", :yellow
  return
end

unless File.read("Gemfile").include?('"litestream"')
  gem "litestream"
end

after_bundle do
  # The litestream-ruby gem ships an install generator that writes the two
  # canonical files (config/litestream.yml + config/initializers/litestream.rb).
  # Guard the generator so re-runs don't clobber a hand-edited config: if the
  # yml is already there, the generator has already run.
  if File.exist?("config/litestream.yml")
    say "Litestream config already present, skipping generator.", :yellow
  else
    generate "litestream:install"
  end

  # The whole reason this template exists: Litestream's default sync-interval
  # is 1s, which means one object-storage write per replica per second — that
  # racks up millions of Class A operations a month (one engineer hit ~20M ops,
  # nearing $100, on Cloudflare R2 by leaving the default). sync-interval is
  # both the replication latency *and* the write frequency, so 10s trades a few
  # seconds of potential data loss for ~10x fewer, cheaper writes.
  # See: https://notes.ghinda.com/post/remember-to-the-frequency-for-replication-to-litestream
  litestream_yml = "config/litestream.yml"
  if File.exist?(litestream_yml)
    if File.read(litestream_yml).include?("sync-interval:")
      say "sync-interval already set in config/litestream.yml, leaving it alone.", :yellow
    else
      # Insert a sync-interval line after every `- type:` replica header,
      # matching that line's indentation so the YAML stays valid. The
      # `- type:` marker is two spaces deeper than the replica list item.
      injected = File.read(litestream_yml).gsub(/^(\s*)- type: .*\n/) do
        replica_line = Regexp.last_match(0)
        indent = Regexp.last_match(1) + "  "
        replica_line +
          "#{indent}# Cost/latency tuning: 1s (Litestream's default) writes to\n" \
          "#{indent}# object storage every second — millions of Class A ops/month.\n" \
          "#{indent}# 10s cuts that ~10x for a few seconds of replication lag.\n" \
          "#{indent}# https://notes.ghinda.com/post/remember-to-the-frequency-for-replication-to-litestream\n" \
          "#{indent}sync-interval: 10s\n"
      end
      File.write(litestream_yml, injected)
      say "✅ Injected sync-interval: 10s into config/litestream.yml.", :green
    end
  else
    say "config/litestream.yml not found — run `bin/rails generate litestream:install` first.", :yellow
  end

  # Schedule the replica verification the gem already ships. `Litestream.verify!`
  # restores each configured database from its replica and reads it back, which
  # is the only thing that distinguishes a working backup from a directory of
  # files you have never opened. It matters more here, not less: the 10s
  # sync-interval above widens the window a silent replication failure can hide
  # in.
  # Indent explicitly rather than relying on the heredoc: `<<~` strips the
  # smallest common indentation, which would flatten the entry to column 0 and
  # make the next existing key a child of ours.
  verification_entry = <<~YAML.lines.map { |line| "  #{line}" }.join
    litestream_backup_verification:
      class: Litestream::VerificationJob
      args: []
      schedule: every day at 1am UTC
  YAML

  recurring_yml = "config/recurring.yml"

  if !File.exist?(recurring_yml)
    say "No config/recurring.yml (no Solid Queue?) — skipping the verification schedule.", :yellow
    say "Schedule Litestream::VerificationJob yourself so the replica gets read back.", :yellow
  elsif File.read(recurring_yml).include?("Litestream::VerificationJob")
    say "Litestream::VerificationJob already scheduled, leaving it alone.", :yellow
  elsif File.read(recurring_yml).match?(/^production:\s*$/)
    inject_into_file recurring_yml, "\n#{verification_entry}", after: /^production:\s*\n/
    say "✅ Scheduled Litestream::VerificationJob daily in config/recurring.yml.", :green
  else
    append_to_file recurring_yml, "\nproduction:\n#{verification_entry}"
    say "✅ Added a production: block scheduling Litestream::VerificationJob.", :green
  end

  say ""
  say "✅ Litestream configured.", :green
  say ""
  say "📋 Next steps:", :blue
  say "   1. Set your replica bucket + keys via ENV or Rails credentials"
  say "      (edit config/initializers/litestream.rb)."
  say "   2. Choose ONE run pattern:"
  say "      • Puma plugin — add `plugin :litestream if ENV[\"LITESTREAM_IN_PUMA\"]`"
  say "        to config/puma.rb (mutual watchdog, single-server)."
  say "      • Standalone — run `bin/rails litestream:replicate` as its own"
  say "        background process (isolated from the web dyno)."
  say ""
  say "⚠️  Single-writer rule:", :yellow
  say "   Exactly one process may replicate to a given bucket path. Never run"
  say "   two (e.g. old + new server during a migration) or you corrupt the replica."
end
