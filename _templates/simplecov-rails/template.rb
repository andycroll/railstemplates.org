#!/usr/bin/env ruby

# SimpleCov Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/simplecov-rails/template
# Usage: rails app:template LOCATION=https://railstemplates.org/simplecov-rails/template

say "railstemplates.org"
say "📊 Installing SimpleCov with Minitest parallelism support...", :green

# Add SimpleCov to Gemfile
gem_group :test do
  gem "simplecov", require: false
end

after_bundle do
  say "⚙️  Configuring SimpleCov in test_helper.rb...", :blue
  
  # Configure SimpleCov in test_helper.rb
  inject_into_file "test/test_helper.rb", before: "ENV[\"RAILS_ENV\"] ||= \"test\"" do
    <<~'RUBY'
      if ENV["CI"] || ENV["COVERAGE"]
        require "simplecov"
        SimpleCov.start "rails" do
          # Add custom groups
          # e.g. add_group "Services", "app/services"

          # Exclude files from coverage
          add_filter "/test/"
          add_filter "/config/"
          add_filter "/vendor/"
          add_filter "/lib/generators/"

          # Enable branch coverage
          enable_coverage :branch
        end
      end

    RUBY
  end

  # Add parallelization support for SimpleCov
  if File.read("test/test_helper.rb").include?("parallelize(workers: :number_of_processors)")
    say "⚙️  Adding Minitest parallelization support...", :blue
    inject_into_file "test/test_helper.rb", after: "parallelize(workers: :number_of_processors)\n" do
      <<~'RUBY'

      if ENV["CI"] || ENV["COVERAGE"]
        parallelize_setup do |worker|
          SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
        end

        parallelize_teardown do |worker|
          SimpleCov.result
        end
      end
    RUBY
    end
    say "✓ Minitest parallelization support added", :green
  end

  # Add .gitignore entry for coverage reports
  append_to_file ".gitignore" do
    <<~TEXT

      # SimpleCov coverage reports
      /coverage/
    TEXT
  end

  say "\n🎉 Setup complete! SimpleCov is ready to use.", :green
  say "Run tests with coverage using: COVERAGE=true rails test", :blue
  say "Coverage reports will be generated in /coverage/index.html", :blue
end