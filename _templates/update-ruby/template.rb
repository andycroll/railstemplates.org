#!/usr/bin/env ruby

# Update Ruby Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/update-ruby/template
# Usage: rails app:template LOCATION=https://railstemplates.org/update-ruby/template

say "railstemplates.org"
say "💎 Adding a weekly Ruby auto-update workflow...", :green

unless File.exist?(".ruby-version")
  say "No .ruby-version found — the workflow bumps .ruby-version, so add one for it to do anything.", :yellow
end

# Single-quoted heredoc: the workflow's own ${{ ... }} and ${SHELL} expansions
# are written verbatim, never evaluated by this Ruby script.
workflow = <<~'YAML'
  name: Update Ruby

  # Weekly check for a newer Ruby. If one is available, open a PR that bumps
  # .ruby-version (and the Dockerfile build arg / Gemfile.lock) after proving
  # the app installs and its tests pass on the new version.
  #
  # "Latest" means the newest stable CRuby that ruby/setup-ruby can actually
  # install — read from the versions manifest at the SAME @v1 ref pinned below.
  # A Ruby can be released days before its prebuilt CI binary exists; proposing
  # one CI can't install just yields a red, unmergeable PR. Reading the pinned
  # ref's manifest avoids that.

  on:
    schedule:
      - cron: "0 6 * * 1" # Mondays 06:00 UTC
    workflow_dispatch:

  permissions:
    contents: write
    pull-requests: write

  concurrency:
    group: update-ruby
    cancel-in-progress: true

  jobs:
    update-ruby:
      runs-on: ubuntu-latest

      steps:
        - name: Checkout code
          uses: actions/checkout@v4

        - name: Determine latest installable Ruby
          id: detect
          run: |
            set -euo pipefail
            current=$(tr -d '[:space:]' < .ruby-version)
            latest=$(curl -fsSL "https://raw.githubusercontent.com/ruby/setup-ruby/v1/ruby-builder-versions.json" \
              | jq -r '.ruby[]' \
              | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
              | sort -V | tail -1)

            echo "Current: ${current} | Latest installable: ${latest}"
            {
              echo "current=${current}"
              echo "latest=${latest}"
            } >> "$GITHUB_OUTPUT"

            newest=$(printf '%s\n%s\n' "${current}" "${latest}" | sort -V | tail -1)
            if [ "${newest}" = "${latest}" ] && [ "${latest}" != "${current}" ]; then
              echo "update=true" >> "$GITHUB_OUTPUT"
              echo "::notice::Ruby ${latest} available (current ${current}) — preparing PR."
            else
              echo "update=false" >> "$GITHUB_OUTPUT"
              echo "::notice::Already on the latest installable Ruby (${current})."
            fi

        - name: Bump Ruby version files
          if: steps.detect.outputs.update == 'true'
          env:
            LATEST: ${{ steps.detect.outputs.latest }}
          run: |
            set -euo pipefail
            printf '%s\n' "${LATEST}" > .ruby-version
            if [ -f Dockerfile ]; then
              sed -i -E "s/^ARG RUBY_VERSION=.*/ARG RUBY_VERSION=${LATEST}/" Dockerfile
            fi

        - name: Set up the new Ruby
          if: steps.detect.outputs.update == 'true'
          uses: ruby/setup-ruby@v1 # reads the freshly bumped .ruby-version

        - name: Install gems (rewrites Gemfile.lock RUBY VERSION)
          if: steps.detect.outputs.update == 'true'
          run: |
            set -euo pipefail
            bundle config set --local frozen false
            bundle install --jobs 4

        - name: Run tests on the new Ruby
          if: steps.detect.outputs.update == 'true'
          env:
            RAILS_ENV: test
            RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
          run: bin/rails db:test:prepare test

        - name: Open pull request
          if: steps.detect.outputs.update == 'true'
          uses: peter-evans/create-pull-request@v7
          with:
            # Works out of the box with the default GITHUB_TOKEN (the steps above
            # already validated the bump). Add a RUBY_UPDATE_TOKEN PAT if you also
            # want the PR to trigger your normal CI — no other change needed.
            token: ${{ secrets.RUBY_UPDATE_TOKEN || secrets.GITHUB_TOKEN }}
            branch: automation/update-ruby
            delete-branch: true
            # Candidate paths — create-pull-request only stages what actually
            # changed, so an absent Dockerfile or unchanged Gemfile.lock is ignored.
            add-paths: |
              .ruby-version
              Dockerfile
              Gemfile.lock
            commit-message: "build: bump Ruby to ${{ steps.detect.outputs.latest }}"
            title: "build: bump Ruby ${{ steps.detect.outputs.current }} → ${{ steps.detect.outputs.latest }}"
            labels: |
              dependencies
              ruby
            body: |
              Bumps Ruby **${{ steps.detect.outputs.current }} → ${{ steps.detect.outputs.latest }}** — the latest stable version installable by `ruby/setup-ruby@v1`.

              Updates `.ruby-version`, `Gemfile.lock` (`RUBY VERSION`), and the `Dockerfile` build arg (if present).

              Validated in this workflow on ${{ steps.detect.outputs.latest }}: `bundle install` + `bin/rails db:test:prepare test`.
YAML

empty_directory ".github/workflows"
create_file ".github/workflows/update-ruby.yml", workflow, skip: true

say ""
say "✅ Update Ruby workflow added at .github/workflows/update-ruby.yml", :green
say ""
say "📋 It runs weekly (and on demand) and opens a PR only after the app installs", :blue
say "   and `bin/rails test` passes on the new Ruby (swap that command if you use RSpec)."
say ""
say "⚙️  One prerequisite:", :yellow
say "   Settings → Actions → General → allow GitHub Actions to create and approve"
say "   pull requests. Without it the workflow can't open the bump PR."
