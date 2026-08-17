#!/usr/bin/env ruby

# Request-ID Context Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/request-id-context/template
# Usage: rails app:template LOCATION=https://railstemplates.org/request-id-context/template

say "railstemplates.org"
say "🆔 Installing request-id context (Current + ApplicationJob + filter_parameters)...", :green

# --- 1. app/models/current.rb -------------------------------------------------

current_path = "app/models/current.rb"

if File.exist?(current_path)
  if File.read(current_path).include?("attribute :request_id")
    say "✓ Current already has request_id attribute, skipping.", :yellow
  else
    inject_into_class current_path, "Current" do
      "  attribute :request_id\n"
    end
    say "✓ Added attribute :request_id to Current.", :green
  end
else
  create_file current_path, <<~'RUBY'
    class Current < ActiveSupport::CurrentAttributes
      attribute :request_id
    end
  RUBY
  say "✓ Created Current with request_id attribute.", :green
end

# --- 2. app/jobs/application_job.rb -------------------------------------------

application_job_path = "app/jobs/application_job.rb"

application_job_methods = <<~'RUBY'
  attr_accessor :request_id

  before_enqueue { self.request_id ||= Current.request_id || SecureRandom.uuid }

  def serialize
    super.merge("request_id" => request_id)
  end

  def deserialize(job_data)
    super
    self.request_id = job_data["request_id"]
  end

  def perform_now
    self.request_id ||= SecureRandom.uuid

    Current.set(request_id: request_id) do
      Rails.event.set_context(request_id: request_id) if Rails.respond_to?(:event)
      super
    end
  end
RUBY

if File.exist?(application_job_path)
  if File.read(application_job_path).include?("attr_accessor :request_id")
    say "✓ ApplicationJob already propagates request_id, skipping.", :yellow
  else
    indented = application_job_methods.lines.map { |l| l.strip.empty? ? "\n" : "  #{l}" }.join
    inject_into_file application_job_path,
      "#{indented}\n",
      after: "class ApplicationJob < ActiveJob::Base\n"
    say "✓ Added request_id propagation to ApplicationJob.", :green
  end
else
  indented = application_job_methods.lines.map { |l| l.strip.empty? ? "\n" : "  #{l}" }.join
  create_file application_job_path, "class ApplicationJob < ActiveJob::Base\n#{indented}end\n"
  say "✓ Created ApplicationJob with request_id propagation.", :green
end

# --- 3. app/controllers/application_controller.rb -----------------------------

application_controller_path = "app/controllers/application_controller.rb"
concern_path = "app/controllers/concerns/set_current_request_id.rb"

# The setter lives in a concern rather than as an anonymous `before_action do`
# block injected into ApplicationController. ApplicationController is a file
# users edit constantly, so anything we inject there has to be recognised again
# on the next run by matching a string inside it — fragile, and it silently
# stops working the moment someone reformats the block. A concern reduces our
# footprint in that file to a single `include` line, and makes both the
# idempotency check and the undo obvious.
create_file concern_path, <<~'RUBY', skip: true
  module SetCurrentRequestId
    extend ActiveSupport::Concern

    included do
      before_action :set_current_request_id
    end

    private

    # `Rails.event.set_context` makes request_id flow into Rails.event lines
    # emitted from controllers. The same setter runs inside
    # ApplicationJob#perform_now for jobs. Guarded so pre-8.1 apps skip it.
    def set_current_request_id
      Current.request_id = request.request_id
      Rails.event.set_context(request_id: request.request_id) if Rails.respond_to?(:event)
    end
  end
RUBY

if File.exist?(application_controller_path)
  if File.read(application_controller_path).include?("include SetCurrentRequestId")
    say "✓ ApplicationController already includes SetCurrentRequestId, skipping.", :yellow
  else
    inject_into_class application_controller_path, "ApplicationController",
      "  include SetCurrentRequestId\n"
    say "✓ Included SetCurrentRequestId in ApplicationController.", :green
  end
else
  create_file application_controller_path, <<~'RUBY'
    class ApplicationController < ActionController::Base
      include SetCurrentRequestId
    end
  RUBY
  say "✓ Created ApplicationController including SetCurrentRequestId.", :green
end

# --- 4. config/initializers/filter_parameter_logging.rb -----------------------

filter_path = "config/initializers/filter_parameter_logging.rb"

filter_body = <<~'RUBY'
  # Be sure to restart your server when you modify this file.
  #
  # Configure parameters to be partially matched (e.g. passw matches password)
  # and filtered from the log file. See ActiveSupport::ParameterFilter for the
  # supported notations and behaviors.
  #
  # Three layers:
  #  1. Short keyword fragments (substring match, broad).
  #  2. Common explicit full names for typical integrations.
  #  3. Default-deny regex: any key ending in token/secret/key/password/
  #     cookie/authorization is filtered automatically.
  Rails.application.config.filter_parameters += [
    :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate,
    :otp, :ssn, :cvv, :cvc, :authorization, :api_key, :access_token,
    :refresh_token, :webhook_secret, :sessionid, :csrftoken,
    :client_secret, :client_id, :bearer, :cookie, :set_cookie,
    :x_csrf_token, :signed_id, :totp, :two_factor_code,
    :rails_master_key,
    /(_|\A)(token|secret|key|password|cookie|authorization)\z/i
  ]
RUBY

if File.exist?(filter_path)
  if File.read(filter_path).include?(":webhook_secret")
    say "✓ filter_parameter_logging.rb already has the baseline, skipping.", :yellow
  else
    remove_file filter_path
    create_file filter_path, filter_body
    say "✓ Replaced filter_parameter_logging.rb with the baseline.", :green
  end
else
  create_file filter_path, filter_body
  say "✓ Created filter_parameter_logging.rb with the baseline.", :green
end

say "\n🎉 Request-ID context installed.", :green
say "Controllers set Current.request_id from request.request_id.", :blue
say "Jobs propagate request_id through enqueue → serialize → perform.", :blue
say "filter_parameters now redacts common secret-shaped keys by default.", :blue
