#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "securerandom"

class CoverageAnalyzer
  CHANGED_FILES_THRESHOLD = 90
  VALID_REF_PATTERN = /\A[a-zA-Z0-9_\-\.\/]+\z/
  VALID_SHA_PATTERN = /\A[a-f0-9]{40}\z/i

  FileCoverage = Data.define(:file, :covered, :total) do
    def percentage
      total.positive? ? (covered.to_f / total * 100).round(1) : 0
    end
  end

  def initialize(coverage_path:, base_ref:)
    @coverage_path = File.expand_path(coverage_path)
    @base_ref = validated_reference(base_ref)
    @data = JSON.parse(File.read(@coverage_path))
  end

  def write_metrics(output_file: nil)
    to_hash.each do |key, value|
      write_output("#{key}=#{value}", output_file:)
    end
  end

  def write_pr_comment(output_file: nil)
    write_output(pr_comment_body)
    return unless output_file

    delimiter = "EOF_#{SecureRandom.hex(8)}"
    File.write(output_file, "pr_comment<<#{delimiter}\n#{pr_comment_body}\n#{delimiter}\n", mode: "a")
  end

  def pr_comment_body
    [
      pr_coverage_summary,
      "-----",
      "✅ Project coverage is #{project_coverage}% (#{project_covered_lines} of #{project_total_lines} lines)"
    ].join("\n")
  end

  def to_hash
    {
      project_coverage: project_coverage,
      project_covered_lines: project_covered_lines,
      project_total_lines: project_total_lines,
      pr_coverage: pr_coverage,
      pr_covered_lines: pr_covered_lines,
      pr_total_lines: pr_total_lines,
      pr_changed_files: pr_changed_files,
      pr_coverage_success: pr_coverage_success
    }
  end

  # Project coverage accessors
  def project_total_lines    = @data["metrics"]["total_lines"]
  def project_covered_lines  = @data["metrics"]["covered_lines"]
  def project_coverage       = (project_covered_lines.to_f / project_total_lines * 100).round(2)

  # PR coverage accessors
  def pr_changed_files   = changed_file_coverages.size
  def pr_total_lines     = changed_file_coverages.sum(&:total)
  def pr_covered_lines   = changed_file_coverages.sum(&:covered)
  def pr_coverage        = pr_total_lines.positive? ? (pr_covered_lines.to_f / pr_total_lines * 100).round(2) : nil
  def pr_coverage_success = pr_coverage.nil? || pr_coverage >= CHANGED_FILES_THRESHOLD

  private

  def write_output(line, output_file: nil)
    puts line
    File.write(output_file, "#{line}\n", mode: "a") if output_file
  end

  def pr_covered?
    pr_covered_lines == pr_total_lines
  end

  def pr_coverage_summary
    if pr_total_lines.positive?
      headline = pr_covered? ? "✅ *All New Code Covered*" : "⚠️ *Coverage Missing*"
      "#{headline}\nPull request coverage is #{pr_coverage}% (#{pr_covered_lines} of #{pr_total_lines} lines across #{pr_changed_files} files)"
    else
      "ℹ️ *No Coverable Lines Changed*"
    end
  end

  def validated_reference(ref)
    return ref if ref.match?(VALID_REF_PATTERN) || ref.match?(VALID_SHA_PATTERN)

    raise ArgumentError, "Invalid git ref: #{ref.inspect}"
  end

  def changed_ruby_files
    @changed_ruby_files ||= begin
      diff, _, status = Open3.capture3(
        "git", "diff",
        "origin/#{@base_ref}...HEAD",
        "--no-color", "-U0",
        "--", "app/**/*.rb", "lib/**/*.rb"
      )
      return Set.new unless status.success?

      current_file = nil
      diff.each_line.with_object(Set.new) do |line, files|
        # Extract filename from diff header: "diff --git a/path b/path"
        if line.start_with?("diff --git")
          current_file = line.match(%r{b/(.+)$})&.[](1)
        # Added lines start with "+", skip diff metadata "+++"
        elsif current_file && line.start_with?("+") && !line.start_with?("+++")
          content = line[1..]
          # Skip blank lines and comments, only track files with meaningful code
          files.add(current_file) unless content.strip.empty? || content.strip.start_with?("#")
        end
      end
    end
  end

  def changed_file_coverages
    @changed_file_coverages ||= changed_ruby_files.filter_map do |file|
      coverable = Array(coverage_by_path.dig(File.expand_path(file), "coverage")).compact
      next if coverable.empty?

      FileCoverage.new(file:, covered: coverable.count(&:positive?), total: coverable.size)
    end
  end

  def coverage_by_path
    @coverage_by_path ||= @data["files"].to_h { |f| [f["filename"], f] }
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    analyzer = CoverageAnalyzer.new(
      coverage_path: ENV.fetch("COVERAGE_JSON", "coverage/coverage.json"),
      base_ref: ENV.fetch("BASE_REF", "main")
    )

    output_file = ENV["GITHUB_OUTPUT"]
    analyzer.write_metrics(output_file:)
    analyzer.write_pr_comment(output_file:)
  rescue ArgumentError => e
    warn "::error::#{e.message}"
    exit 1
  end
end
