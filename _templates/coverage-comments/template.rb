#!/usr/bin/env ruby

# Coverage Comments Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/coverage-comments/template
# Usage: rails app:template LOCATION=https://railstemplates.org/coverage-comments/template
#
# Prerequisite: SimpleCov must be installed first
# See: https://railstemplates.org/simplecov-rails/

say "railstemplates.org"
say "Adding coverage PR comments...", :green

# Check if SimpleCov is installed
unless File.read("Gemfile").include?("simplecov")
  say "SimpleCov is not installed.", :red
  say "Please install SimpleCov first: rails app:template LOCATION=https://railstemplates.org/simplecov-rails/template", :yellow
  exit 1
end

# Add simplecov-json gem
gem_group :test do
  gem "simplecov-json", require: false
end

after_bundle do
  say "Configuring SimpleCov JSON formatter...", :blue

  # Add JSON formatter configuration to test_helper.rb
  test_helper = File.read("test/test_helper.rb")

  if test_helper.include?("SimpleCov.start")
    # Add require for simplecov-json after simplecov require
    gsub_file "test/test_helper.rb",
      /require "simplecov"\n/,
      "require \"simplecov\"\n  require \"simplecov-json\"\n"

    # Add JSON formatter configuration inside SimpleCov.start block
    # Look for the end of SimpleCov.start block
    if test_helper.include?("enable_coverage :branch")
      inject_into_file "test/test_helper.rb", after: "enable_coverage :branch\n" do
        <<~'RUBY'

          if ENV["CI"]
            formatter SimpleCov::Formatter::MultiFormatter.new([
              SimpleCov::Formatter::HTMLFormatter,
              SimpleCov::Formatter::JSONFormatter
            ])
          end
        RUBY
      end
    else
      # If no branch coverage, add before the end of the block
      gsub_file "test/test_helper.rb",
        /(\s+)end\nend\n\nENV/,
        "\\1  if ENV[\"CI\"]\n\\1    formatter SimpleCov::Formatter::MultiFormatter.new([\n\\1      SimpleCov::Formatter::HTMLFormatter,\n\\1      SimpleCov::Formatter::JSONFormatter\n\\1    ])\n\\1  end\n\\1end\nend\n\nENV"
    end

    say "SimpleCov JSON formatter configured", :green
  else
    say "Could not find SimpleCov.start block in test_helper.rb", :yellow
    say "Please manually add the JSON formatter configuration", :yellow
  end

  # Create .github/scripts directory
  say "Creating coverage analysis script...", :blue
  empty_directory ".github/scripts"

  # Download analyze_coverage.rb
  download_coverage_script

  # Update CI workflow
  say "Updating CI workflow...", :blue
  update_ci_workflow

  say "\nSetup complete! Coverage comments will appear on PRs.", :green
  say "Make sure your CI workflow has a 'test' job that uploads coverage artifacts.", :blue
end

def download_coverage_script
  require 'net/http'
  require 'uri'

  script_url = "https://railstemplates.org/coverage-comments/analyze_coverage.rb"
  script_path = ".github/scripts/analyze_coverage.rb"

  begin
    uri = URI(script_url)
    response = Net::HTTP.get_response(uri)

    if response.code == "200"
      create_file script_path, response.body, skip: true
      chmod script_path, 0755
      say "Downloaded coverage analysis script", :green
    else
      say "Failed to download script (HTTP #{response.code})", :red
      say "You can manually download from: #{script_url}", :yellow
    end
  rescue => e
    say "Error downloading script: #{e.message}", :red
    say "You can manually download from: #{script_url}", :yellow
  end
end

def update_ci_workflow
  ci_path = ".github/workflows/ci.yml"

  unless File.exist?(ci_path)
    say "CI workflow not found at #{ci_path}", :yellow
    say "Please manually add the coverage job to your CI workflow", :yellow
    create_coverage_workflow_example
    return
  end

  ci_content = File.read(ci_path)

  # Add CI: true to test job env if not present
  unless ci_content.include?("CI: true")
    gsub_file ci_path, /(\s+)RAILS_ENV: test\n/, "\\1RAILS_ENV: test\n\\1CI: true\n"
  end

  # Add coverage artifact upload to test job if not present
  unless ci_content.include?("Upload coverage report")
    # Find the end of the test job's run tests step and add artifact upload
    if ci_content.include?("run: bin/rails") && ci_content.include?("test")
      inject_into_file ci_path, after: /run: bin\/rails.*test.*\n/ do
        <<~YAML

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/
          retention-days: 7
        YAML
      end
      say "Added coverage artifact upload step", :green
    end
  end

  # Add coverage job if not present
  unless ci_content.include?("coverage:")
    append_to_file ci_path do
      <<~YAML

  coverage:
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'pull_request'
    permissions:
      contents: read
      pull-requests: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Download coverage report
        uses: actions/download-artifact@v4
        with:
          name: coverage-report
          path: coverage/

      - name: Analyze coverage
        id: coverage
        env:
          COVERAGE_JSON: coverage/coverage.json
          BASE_REF: ${{ github.base_ref }}
        run: ruby .github/scripts/analyze_coverage.rb

      - name: Post coverage comment
        uses: mshick/add-pr-comment@v2
        with:
          message-id: coverage-report
          message: ${{ steps.coverage.outputs.pr_comment }}

      - name: Check coverage threshold
        run: |
          if [ "${{ steps.coverage.outputs.pr_coverage_success }}" == "false" ]; then
            echo "::error::PR coverage is below 90% threshold"
            exit 1
          fi
      YAML
    end
    say "Added coverage job to CI workflow", :green
  end
end

def create_coverage_workflow_example
  example_path = ".github/workflows/coverage-job-example.yml"

  create_file example_path, <<~YAML
    # Add this job to your CI workflow
    # The test job should upload coverage artifacts:
    #
    #   - name: Upload coverage report
    #     uses: actions/upload-artifact@v4
    #     with:
    #       name: coverage-report
    #       path: coverage/
    #       retention-days: 7

    coverage:
      runs-on: ubuntu-latest
      needs: test
      if: github.event_name == 'pull_request'
      permissions:
        contents: read
        pull-requests: write

      steps:
        - name: Checkout code
          uses: actions/checkout@v4
          with:
            fetch-depth: 0

        - name: Download coverage report
          uses: actions/download-artifact@v4
          with:
            name: coverage-report
            path: coverage/

        - name: Analyze coverage
          id: coverage
          env:
            COVERAGE_JSON: coverage/coverage.json
            BASE_REF: ${{ github.base_ref }}
          run: ruby .github/scripts/analyze_coverage.rb

        - name: Post coverage comment
          uses: mshick/add-pr-comment@v2
          with:
            message-id: coverage-report
            message: ${{ steps.coverage.outputs.pr_comment }}

        - name: Check coverage threshold
          run: |
            if [ "${{ steps.coverage.outputs.pr_coverage_success }}" == "false" ]; then
              echo "::error::PR coverage is below 90% threshold"
              exit 1
            fi
  YAML

  say "Created example coverage job at #{example_path}", :yellow
  say "Please integrate this into your CI workflow", :yellow
end
