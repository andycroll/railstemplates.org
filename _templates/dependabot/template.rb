#!/usr/bin/env ruby

# Dependabot Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/dependabot/template
# Usage: rails app:template LOCATION=https://railstemplates.org/dependabot/template

say "railstemplates.org"
say "🤖 Configuring Dependabot with automerge...", :green

if File.exist?(".github/dependabot.yml")
  say "⚠️  .github/dependabot.yml already exists, skipping.", :yellow
  say "Remove it first if you want to regenerate it.", :yellow
  return
end

# Build dependabot.yml content
dependabot_yml = <<~YAML
  version: 2
  updates:
    - package-ecosystem: bundler
      directory: /
      schedule:
        interval: weekly
        day: monday
      open-pull-requests-limit: 10
      labels:
        - dependencies
      groups:
        patch-updates:
          applies-to: version-updates
          update-types:
            - "patch"
        minor-updates:
          applies-to: version-updates
          update-types:
            - "minor"
        security-patches:
          applies-to: security-updates
          update-types:
            - "patch"
            - "minor"
      cooldown:
        default-days: 3
        semver-major-days: 7
        semver-minor-days: 5
        semver-patch-days: 3
YAML

if File.exist?("package.json")
  say "📦 Detected package.json, adding npm ecosystem...", :blue
  dependabot_yml += <<~YAML

      - package-ecosystem: npm
        directory: /
        schedule:
          interval: weekly
          day: monday
        open-pull-requests-limit: 10
        labels:
          - dependencies
        groups:
          patch-updates:
            applies-to: version-updates
            update-types:
              - "patch"
          minor-updates:
            applies-to: version-updates
            update-types:
              - "minor"
          security-patches:
            applies-to: security-updates
            update-types:
              - "patch"
              - "minor"
        cooldown:
          default-days: 5
          semver-major-days: 10
          semver-minor-days: 7
          semver-patch-days: 5
  YAML
end

# Create the automerge workflow first so .github/workflows/ exists
empty_directory ".github/workflows"

automerge_yml = <<~YAML
  name: Dependabot auto-merge
  on: pull_request_target

  permissions:
    contents: write
    pull-requests: write

  jobs:
    dependabot:
      runs-on: ubuntu-latest
      if: github.event.pull_request.user.login == 'dependabot[bot]'
      steps:
        - name: Fetch Dependabot metadata
          id: metadata
          uses: dependabot/fetch-metadata@v3
          with:
            github-token: "${{ secrets.GITHUB_TOKEN }}"

        - name: Auto-merge production patch updates
          if: >
            steps.metadata.outputs.dependency-type == 'direct:production' &&
            steps.metadata.outputs.update-type == 'version-update:semver-patch'
          run: gh pr merge --auto --squash "$PR_URL"
          env:
            PR_URL: ${{ github.event.pull_request.html_url }}
            GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

        - name: Auto-merge dev dependency patch and minor updates
          if: >
            steps.metadata.outputs.dependency-type == 'direct:development' &&
            steps.metadata.outputs.update-type != 'version-update:semver-major'
          run: gh pr merge --auto --squash "$PR_URL"
          env:
            PR_URL: ${{ github.event.pull_request.html_url }}
            GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

        - name: Auto-merge GitHub Actions patch and minor updates
          if: >
            steps.metadata.outputs.package-ecosystem == 'github_actions' &&
            steps.metadata.outputs.update-type != 'version-update:semver-major'
          run: gh pr merge --auto --squash "$PR_URL"
          env:
            PR_URL: ${{ github.event.pull_request.html_url }}
            GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
YAML

create_file ".github/workflows/dependabot-auto-merge.yml", automerge_yml, skip: true

# Now check for .github/workflows to add github-actions ecosystem
if Dir.exist?(".github/workflows")
  dependabot_yml += <<~YAML

      - package-ecosystem: github-actions
        directory: /
        schedule:
          interval: weekly
          day: monday
        open-pull-requests-limit: 5
        labels:
          - dependencies
        groups:
          patch-updates:
            applies-to: version-updates
            update-types:
              - "patch"
          minor-updates:
            applies-to: version-updates
            update-types:
              - "minor"
          security-patches:
            applies-to: security-updates
            update-types:
              - "patch"
              - "minor"
        cooldown:
          default-days: 3
          semver-major-days: 7
          semver-minor-days: 5
          semver-patch-days: 3
  YAML
end

create_file ".github/dependabot.yml", dependabot_yml, skip: true

say ""
say "✅ Dependabot configured!", :green
say ""
say "📋 Automerge policy:", :blue
say "   • Production dependencies: patch versions only"
say "   • Dev dependencies: patch and minor versions"
say "   • GitHub Actions: patch and minor versions"
say "   • Major versions: always require manual review"
say ""
say "⚠️  Prerequisites for automerge to work:", :yellow
say "   1. Enable auto-merge in repo settings (Settings → General → Pull Requests)"
say "   2. Add a branch protection rule for your default branch"
say "   3. Require status checks to pass (e.g. your CI test job)"
say "   Without these, automerge PRs will not merge automatically."
say ""
say "🛡️  Supply chain protection:", :blue
say "   Cooldowns delay PRs for newly-published packages, giving the"
say "   community time to detect compromised releases."
say "   Security updates (CVE patches) bypass cooldowns entirely."
