#!/usr/bin/env ruby

# Procfile.dev Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/procfile-dev/template
# Usage: rails app:template LOCATION=https://railstemplates.org/procfile-dev/template

say "railstemplates.org"
say "🛠  Configuring Procfile.dev with attachable debugger...", :green

# Detect optional process gates from the current app state.
gemfile_lock = File.exist?("Gemfile.lock") ? File.read("Gemfile.lock") : ""
gemfile_contents = File.exist?("Gemfile") ? File.read("Gemfile") : ""

tailwind_present = gemfile_lock.include?("tailwindcss-rails") ||
  gemfile_contents.include?("tailwindcss-rails")

solid_queue_present = gemfile_lock.include?("solid_queue") ||
  gemfile_contents.include?("solid_queue") ||
  File.exist?("bin/jobs")

header_comment = <<~COMMENT
  # Procfile.dev — managed by railstemplates.org/procfile-dev
  #
  # Start every dev process with: bin/dev
  # Attach the debugger to the running web process with: rdbg -A
COMMENT

managed_processes = {
  "web" => "RUBY_DEBUG_OPEN=true bin/rails server -p ${PORT:-3000}"
}
managed_processes["css"] = "bin/rails tailwindcss:watch" if tailwind_present
managed_processes["jobs"] = "bin/jobs" if solid_queue_present

existing = File.exist?("Procfile.dev") ? File.read("Procfile.dev") : ""
existing_lines = existing.split("\n")

# Split header (leading comments / blank lines) from process lines so we can
# preserve user-added comments above the managed block while still rewriting
# the header to the canonical text.
process_index = existing_lines.index { |line| line.match?(/\A[a-zA-Z0-9_-]+:/) }
existing_process_lines = process_index ? existing_lines[process_index..] : []

merged_lines = existing_process_lines.dup

managed_processes.each do |name, command|
  prefix = "#{name}:"
  index = merged_lines.index { |line| line.start_with?(prefix) }
  new_line = "#{name}: #{command}"

  if index
    current_line = merged_lines[index]
    # Only ever mutate the web line, and only to guarantee RUBY_DEBUG_OPEN is set.
    # Any other existing managed line (a user's `css:`/`jobs:` command, or a web
    # line already carrying the debug env) is left exactly as-is — idempotency.
    if name == "web" && !current_line.include?("RUBY_DEBUG_OPEN=true")
      # Preserve the user's chosen web command but prepend the debug env var.
      command_part = current_line.sub(/\A#{Regexp.escape(prefix)}\s*/, "")
      merged_lines[index] = "#{prefix} RUBY_DEBUG_OPEN=true #{command_part}".rstrip
    end
  else
    merged_lines << new_line
  end
end

# Drop trailing blank lines, then rebuild file with canonical header.
merged_lines = merged_lines.reject(&:empty?) if merged_lines.last.to_s.strip.empty?

body = merged_lines.join("\n")
body += "\n" unless body.empty? || body.end_with?("\n")

new_contents = header_comment + "\n" + body
new_contents += "\n" unless new_contents.end_with?("\n")

if existing == new_contents
  say "Procfile.dev already up to date, skipping.", :yellow
else
  create_file "Procfile.dev", new_contents, force: true
  say "✅ Procfile.dev written.", :green
  say "  • web (always, with RUBY_DEBUG_OPEN=true)", :blue
  say "  • css (tailwindcss-rails detected)", :blue if tailwind_present
  say "  • jobs (solid_queue / bin/jobs detected)", :blue if solid_queue_present
  say "Attach the debugger with: rdbg -A", :blue
end
