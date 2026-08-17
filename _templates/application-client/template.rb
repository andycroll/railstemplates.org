#!/usr/bin/env ruby

# ApplicationClient Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/application-client/template
# Usage: rails app:template LOCATION=https://railstemplates.org/application-client/template

say "railstemplates.org"
say "🌐 Installing ApplicationClient + outgoing-API JSON logs...", :green

application_client_body = <<~'RUBY'
  # Based on https://github.com/jumpstart-pro/jumpstart-pro-rails/blob/main/app/clients/application_client.rb
  #
  # Divergences from upstream:
  # - JSON_OBJECT_CLASS changed from OpenStruct to nil (Hash) — OpenStruct deprecated in Ruby 3.4+
  # - Greedy regex in link_header tightened to non-greedy

  require "net/http"

  class ApplicationClient
    # A basic API client with HTTP methods
    #
    # The Authorization Bearer token header for authentication is included by default
    # Override `authorization_header` to change this.
    #
    # Content Type is application/json by default — override `content_type` to change.
    #
    # An example API client:
    #
    #   class DigitalOceanClient < ApplicationClient
    #     BASE_URI = "https://api.digitalocean.com/v2"
    #
    #     def account
    #       get("/account").account
    #     rescue *NETWORK_ERRORS
    #       raise Error, "Unable to load your account"
    #     end
    #   end

    # Common HTTP Errors.
    # See `handle_response` for the status-code → class mapping.
    #
    # Two retry-semantics groupings sit between `Error` and the concrete
    # status classes:
    #
    # - `Inaccessible` — 4xx responses where retry won't change the outcome.
    #   The resource is unreachable under our auth/permissions (or doesn't
    #   exist). Callers typically rescue this and mark the record terminal.
    #
    # - `Transient` — responses where retry IS useful. Upstream is rate-
    #   limiting us, having a wobble, or timing out. Callers typically
    #   `retry_on Transient` in a job and let backoff handle it.
    class Error < StandardError; end

    class MovedPermanently < Error; end
    class BadRequest < Error; end
    class UnprocessableEntity < Error; end

    class Inaccessible < Error; end
    class Forbidden < Inaccessible; end
    class Unauthorized < Inaccessible; end
    class NotFound < Inaccessible; end

    class Transient < Error; end

    class RateLimit < Transient
      def initialize(message, reset_at = nil)
        @reset_at = reset_at
        super(message)
      end

      def reset_at = @reset_at&.to_i
    end

    # Distinct from RateLimit: daily/long-window quota exhaustion where
    # the right action is to stop retrying within the job and rely on the
    # next recurring poll. Polynomial backoff of ~10 minutes can't bridge
    # a 24-hour quota window.
    class QuotaExceeded < RateLimit; end

    class InternalError < Transient; end
    class BadGateway < Transient; end
    class ServiceUnavailable < Transient; end
    class GatewayTimeout < Transient; end

    BASE_URI = "https://example.org"

    # Transport-layer errors that can surface from Net::HTTP and friends.
    NETWORK_ERRORS = [
      Timeout::Error,              # parent of Net::OpenTimeout / Net::ReadTimeout
      Errno::EINVAL,               # OS: invalid argument on a socket call
      Errno::ECONNRESET,           # peer RST during an in-flight request
      Errno::ECONNREFUSED,         # no listener on the target port
      EOFError,                    # server closed mid-response
      Net::HTTPBadResponse,        # malformed status line from server
      Net::HTTPHeaderSyntaxError,  # malformed header from server
      Net::ProtocolError,          # Net::HTTP catch-all parent
      SocketError,                 # DNS failure / unresolvable host
      OpenSSL::SSL::SSLError       # TLS handshake or cert verification failure
    ].freeze
    RATE_LIMIT_HEADERS = [ "x_ratelimit_reset", "x_rate_limit_reset", "ratelimit_reset" ].freeze

    # Daily/monthly plan-quota headers (RapidAPI standard: `X-RateLimit-Requests-*`).
    QUOTA_REMAINING_HEADERS = %i[x_ratelimit_requests_remaining].freeze
    QUOTA_LIMIT_HEADERS     = %i[x_ratelimit_requests_limit].freeze
    QUOTA_RESET_HEADERS     = %i[x_ratelimit_requests_reset].freeze
    QUOTA_LOW_THRESHOLD     = 0.10

    attr_reader :auth, :basic_auth, :token

    def self.inherited(client)
      response = client.const_set(:Response, Class.new(Response))
      response.const_set(:PARSER, Response::PARSER.dup)
    end

    # Initializes an API client.
    # Supply either `auth` (object responding to `token`) or `token` (String).
    def initialize(auth: nil, basic_auth: nil, token: nil)
      @auth, @basic_auth, @token = auth, basic_auth, token
    end

    # Override to customize default headers.
    # Content-Type will be removed on GET requests.
    def default_headers
      {
        "Accept" => content_type,
        "Content-Type" => content_type
      }.merge(authorization_header)
    end

    def content_type = "application/json"

    # Override to customize the authorization header.
    #
    # Examples:
    #   { "X-API-Key" => token }
    #   { "AccessKey" => token }
    def authorization_header = { "Authorization" => "Bearer #{auth&.token || token}" }

    # Override to customize default query params.
    def default_query_params = {}

    # Loops through a URL with pagination.
    # The block should return a String URL or Hash of query parameters for the next page.
    # Return nil to stop paginating.
    def with_pagination(path, headers: {}, query: nil)
      page_query = (query || {}).dup

      loop do
        next_page = yield get(path, headers: headers, query: page_query)

        case next_page
        when String
          path = next_page
        when Hash
          page_query.merge!(next_page)
        else
          break
        end
      end
    end

    def get(path, **)    = make_request(klass: Net::HTTP::Get,    path: path, **)
    def post(path, **)   = make_request(klass: Net::HTTP::Post,   path: path, **)
    def patch(path, **)  = make_request(klass: Net::HTTP::Patch,  path: path, **)
    def put(path, **)    = make_request(klass: Net::HTTP::Put,    path: path, **)
    def delete(path, **) = make_request(klass: Net::HTTP::Delete, path: path, **)

    def base_uri = self.class::BASE_URI
    def rate_limit_headers = self.class::RATE_LIMIT_HEADERS.map(&:to_sym)

    # Override to set timeouts for all requests.
    def open_timeout  = nil
    def read_timeout  = nil
    def write_timeout = nil

    def make_request(klass:, path:, headers: {}, body: nil, query: nil, form_data: nil, http_options: {})
      raise ArgumentError, "Cannot pass both body and form_data" if body.present? && form_data.present?

      uri = path.start_with?("http") ? URI(path) : URI("#{base_uri}#{path}")

      query_params = Rack::Utils.parse_query(uri.query).with_defaults(default_query_params)
      case query
      when String
        query_params.merge! Rack::Utils.parse_query(query)
      when Hash
        query_params.merge! query
      end
      uri.query = Rack::Utils.build_query(query_params) if query_params.present?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.instance_of? URI::HTTPS

      http.open_timeout  = http_options[:open_timeout]  || open_timeout  || http.open_timeout
      http.read_timeout  = http_options[:read_timeout]  || read_timeout  || http.read_timeout
      http.write_timeout = http_options[:write_timeout] || write_timeout || http.write_timeout

      all_headers = default_headers.merge(headers)
      all_headers.delete("Content-Type") if klass == Net::HTTP::Get

      request = klass.new(uri.request_uri, all_headers)
      request.basic_auth(basic_auth[:username], basic_auth[:password]) if basic_auth.present?

      if body.present?
        request.body = build_body(body)
      elsif form_data.present?
        request.set_form(form_data, "multipart/form-data")
      end

      # `request.application_client` is consumed by the subscriber in
      # `config/initializers/application_client_logging.rb`. URL query
      # strings, request bodies, and headers are intentionally NOT in the
      # payload. Subclasses MUST extend via the `get`/`post`/etc. helpers,
      # not by overriding `make_request`, or the URL-query-stripping below
      # would be silently bypassed.
      response = ActiveSupport::Notifications.instrument(
        "request.application_client",
        klass: self.class.name,
        method: klass.name.split("::").last.upcase,
        host: uri.host,
        path: uri.path,
        attempt: 1
      ) do |payload|
        raw = http.request(request)
        payload[:status] = raw.code.to_i
        quota = extract_plan_quota(raw)
        if quota
          payload[:quota_remaining] = quota[:remaining]
          payload[:quota_limit]     = quota[:limit]
          payload[:quota_reset]     = quota[:reset]
        end
        raw
      end

      handle_response self.class::Response.new(response)
    end

    # Returns `{remaining:, limit:, reset:}` from the plan-quota response
    # headers, or nil if no `remaining` header is present.
    def extract_plan_quota(raw_response)
      headers = raw_response.each_header.to_h.transform_keys { |k| k.underscore.to_sym }
      remaining = pick_int(headers, self.class::QUOTA_REMAINING_HEADERS)
      return unless remaining
      {
        remaining: remaining,
        limit:     pick_int(headers, self.class::QUOTA_LIMIT_HEADERS),
        reset:     pick_int(headers, self.class::QUOTA_RESET_HEADERS)
      }
    end

    def pick_int(headers, candidate_keys)
      key = candidate_keys.find { headers.key?(it) }
      return unless key
      Integer(headers[key], exception: false)
    end

    # Handles an HTTP response
    # - Parse the response code
    # - Raise an error if not 20X
    # - If response body, parses and returns
    # - Otherwise returns nil
    def handle_response(response)
      case response.code
      when "200", "201", "202", "203", "204"
        response
      when "301"
        raise MovedPermanently, response.body
      when "400"
        raise BadRequest, response.body
      when "401"
        raise Unauthorized, response.body
      when "403"
        raise Forbidden, response.body
      when "404"
        raise NotFound, response.body
      when "420", "429"
        rate_limit_header = rate_limit_headers.find { response.headers.key?(it) }
        raise RateLimit.new(response.body, response.headers[rate_limit_header])
      when "422"
        raise UnprocessableEntity, response.body
      when "500"
        raise InternalError, response.body
      when "502"
        raise BadGateway, response.body
      when "503"
        raise ServiceUnavailable, response.body
      when "504"
        raise GatewayTimeout, response.body
      else
        raise Error, "#{response.code} - #{response.body}"
      end
    end

    # Converts a body to the matching ContentType
    # Override to convert request bodies to other content types.
    def build_body(body)
      case body
      when String then body
      else body.to_json
      end
    end

    class Response
      # Provides access to the parsed response body, headers, and status code.
      #
      # To add a custom content type parser, register it in the PARSER hash:
      #
      #   class MyClient < ApplicationClient
      #     Response::PARSER["text/html"] = ->(response) { Nokogiri::HTML(response.body) }
      #   end
      JSON_OBJECT_CLASS = nil
      PARSER = {
        "application/json" => ->(response) { JSON.parse(response.body, object_class: JSON_OBJECT_CLASS) },
        "application/xml"  => ->(response) { Nokogiri::XML(response.body) }
      }
      FALLBACK_PARSER = ->(response) { response.body }

      attr_reader :original_response

      delegate :code, :body, to: :original_response
      delegate_missing_to :parsed_body

      def initialize(original_response)
        @original_response = original_response
      end

      # Returns a hash of headers with underscored names as symbols
      def headers
        @headers ||= original_response.each_header.to_h.transform_keys { |k| k.underscore.to_sym }
      end

      # Returns a hash of the Link header (or empty hash).
      def link_header
        @link_header ||= headers[:link]&.split(", ")&.map do |link|
          rel = link[/rel="(.+?)"/, 1].to_sym
          url = link[/<(.+?)>/, 1]
          [ rel, url ]
        end.to_h
      end

      # Removes charset and boundary and returns the mime type.
      def content_type = headers[:content_type]&.split(";")&.first

      def parsed_body
        @parsed_body ||= PARSER.fetch(content_type, FALLBACK_PARSER).call(self)
      end

      def body_h
        @body_h ||= JSON.parse(body)
      end
    end
  end
RUBY

create_file "app/clients/application_client.rb", application_client_body, skip: true

subscriber_body = <<~'RUBY'
  ActiveSupport::Notifications.subscribe("request.application_client") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    err = event.payload[:exception_object]

    fields = {
      event:           "external_api.request",
      klass:           event.payload[:klass],
      method:          event.payload[:method],
      host:            event.payload[:host],
      path:            event.payload[:path],
      status:          event.payload[:status],
      duration_ms:     event.duration.to_i,
      attempt:         event.payload[:attempt],
      quota_remaining: event.payload[:quota_remaining],
      quota_limit:     event.payload[:quota_limit],
      quota_reset:     event.payload[:quota_reset],
      request_id:      (Current.request_id if defined?(Current) && Current.respond_to?(:request_id)),
      error_class:     err&.class&.name
    }.compact

    Rails.logger.info(fields.to_json)
  end
RUBY

create_file "config/initializers/application_client_logging.rb", subscriber_body, skip: true

say ""
say "✅ ApplicationClient installed!", :green
say ""
say "📋 Next steps:", :blue
say "   • Subclass ApplicationClient per integration (see app/clients/application_client.rb header)"
say "   • One JSON log line per outgoing request goes to Rails.logger as event:'external_api.request'"
say "   • URL query strings, request bodies, and response headers are intentionally NOT logged"
say ""
say "🔗 Pairs with the request-id-context template for web↔API correlation.", :blue
