#!/usr/bin/env ruby

# StandardRB Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/standard-rb/template
# Usage: rails app:template LOCATION=https://railstemplates.org/standard-rb/template

say "railstemplates.org"
say "Replacing Omakase linting with StandardRB...", :green

# Remove omakase gem (handles inline comments and indentation)
gsub_file "Gemfile", /^\s*gem\s+["']rubocop-rails-omakase["'][^\n]*\n/, ""

# Add standard gem
gem_group :development, :test do
  gem "standard", require: false
end

after_bundle do
  remove_file ".rubocop_todo.yml"

  create_file ".rubocop.yml", <<~YAML, force: true
    require: standard

    inherit_gem:
      standard: config/base.yml
  YAML

  say "StandardRB installed. Run: bundle exec rubocop -A", :green
end
