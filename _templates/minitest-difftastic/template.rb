#!/usr/bin/env ruby

# minitest-difftastic Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/minitest-difftastic/template
# Usage: rails app:template LOCATION=https://railstemplates.org/minitest-difftastic/template

say "railstemplates.org"
say "🌈 Installing minitest-difftastic for structural test diffs...", :green

# Add minitest-difftastic to the test group. Inject into an existing
# `group :test do` block when one is present (matching the convention used
# by the other test-only templates here), otherwise create the block.
gemfile = File.read("Gemfile")
if gemfile.include?('gem "minitest-difftastic"')
  say "minitest-difftastic already in Gemfile, skipping.", :yellow
elsif gemfile.match?(/^group :test do/)
  inject_into_file "Gemfile", %(  gem "minitest-difftastic"\n), after: "group :test do\n"
else
  gem_group :test do
    gem "minitest-difftastic"
  end
end

after_bundle do
  test_helper = "test/test_helper.rb"

  load_line = <<~'RUBY'
    # minitest-difftastic renders failed-assertion diffs with difftastic's
    # syntax-aware, structural diffing instead of Minitest's line-based output.
    # Minitest 6 no longer auto-loads plugins, so load it explicitly. The guard
    # is a no-op on Minitest 5, which still auto-loads plugins from the bundle.
    Minitest.load(:difftastic) if Minitest.respond_to?(:load)
  RUBY

  if !File.exist?(test_helper)
    say "No test/test_helper.rb found — add `Minitest.load(:difftastic)` yourself.", :yellow
  elsif File.read(test_helper).include?("Minitest.load(:difftastic)")
    say "minitest-difftastic already loaded in test_helper.rb, skipping.", :yellow
  elsif File.read(test_helper).include?('require "rails/test_help"')
    inject_into_file test_helper, "\n#{load_line}", after: %(require "rails/test_help"\n)
    say "✅ minitest-difftastic loaded in test/test_helper.rb.", :green
  else
    append_to_file test_helper, "\n#{load_line}"
    say "✅ minitest-difftastic load line appended to test/test_helper.rb.", :green
  end
end
