#!/usr/bin/env ruby

# Development Debugging Stack Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/dev-debugging/template
# Usage: rails app:template LOCATION=https://railstemplates.org/dev-debugging/template

say "railstemplates.org"
say "🐞 Installing development debugging stack (debug, debugbar, web-console, rack-mini-profiler)...", :green

DEV_DEBUGGING_GEMS = %w[debug debugbar web-console rack-mini-profiler].freeze

gemfile_contents = File.read("Gemfile")
missing_gems = DEV_DEBUGGING_GEMS.reject { |name| gemfile_contents.match?(/^\s*gem ["']#{Regexp.escape(name)}["']/) }

if missing_gems.any?
  if gemfile_contents.match?(/^group :development do/)
    inject_into_file "Gemfile", after: "group :development do\n" do
      missing_gems.map { |name| "  gem \"#{name}\"\n" }.join
    end
  else
    gem_group :development do
      missing_gems.each { |name| gem name }
    end
  end
else
  say "All four debugging gems already present in Gemfile, skipping gem adds.", :yellow
end

after_bundle do
  initializer_path = "config/initializers/rack_mini_profiler.rb"

  if File.exist?(initializer_path)
    say "#{initializer_path} already present, leaving untouched.", :yellow
  else
    initializer_body = <<~'RUBY'
      # rack-mini-profiler: per-request timing badge for SQL, views, and total
      # duration. Scoped to development only — never enable in production
      # without authentication in front of /mini-profiler-resources.
      return unless Rails.env.development?

      require "rack-mini-profiler"

      Rack::MiniProfiler.config.position = "bottom-right"
      Rack::MiniProfiler.config.start_hidden = false
      Rack::MiniProfiler.config.skip_paths ||= []
      Rack::MiniProfiler.config.skip_paths += ["/rails/", "/assets/", "/packs/"]
    RUBY

    create_file initializer_path, initializer_body
  end

  say "\n✅ Development debugging stack installed.", :green
  say "\n📌 One manual step required: mount Debugbar in your application layout.", :yellow
  say "   Add the following line just before </body> in app/views/layouts/application.html.erb:", :yellow
  say "", :yellow
  say "     <%= debugbar %>", :cyan
  say "", :yellow
  say "   See the Debugbar README for details: https://github.com/SaladinoKlein/debugbar", :blue
end
