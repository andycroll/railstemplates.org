require_relative "../test_helper"

class ApplicationClientTest < TemplateTestCase
  def test_application_client
    create_rails_app
    apply_template("application-client")

    client_path = "#{@app_dir}/app/clients/application_client.rb"
    initializer_path = "#{@app_dir}/config/initializers/application_client_logging.rb"

    assert File.exist?(client_path), "Expected app/clients/application_client.rb to be created"
    assert File.exist?(initializer_path), "Expected config/initializers/application_client_logging.rb to be created"

    client = File.read(client_path)
    assert_match(/class ApplicationClient/, client)
    assert_match(/NETWORK_ERRORS\s*=/, client)
    assert_match(/class RateLimit < Transient/, client)
    assert_match(/class QuotaExceeded < RateLimit/, client)
    assert_match(/JSON_OBJECT_CLASS\s*=\s*nil/, client)

    # Header comment must cite jumpstart-pro upstream and the two divergences
    assert_match(%r{jumpstart-pro/jumpstart-pro-rails}, client,
      "Header comment must cite the jumpstart-pro-rails upstream")
    assert_match(/Divergences from upstream:/, client,
      "Header comment must list the divergences")
    assert_match(/OpenStruct/, client,
      "Header comment must call out the OpenStruct → nil divergence")
    assert_match(/non-greedy/, client,
      "Header comment must call out the link_header non-greedy divergence")
    # The non-greedy link_header regex itself must be present
    assert_match(/<\(\.\+\?\)>/, client,
      "link_header must use the non-greedy regex <(.+?)>")

    initializer = File.read(initializer_path)
    assert_match(/ActiveSupport::Notifications\.subscribe\("request\.application_client"\)/, initializer)
    assert_match(/event:\s*"external_api\.request"/, initializer)
    assert_match(/Current\.request_id/, initializer)
    assert_match(/\.compact/, initializer,
      "Subscriber must .compact so request_id drops when Current is absent")

    # Idempotency: re-applying must leave both files byte-identical
    client_before = File.read(client_path)
    initializer_before = File.read(initializer_path)
    apply_template("application-client")
    assert_equal client_before, File.read(client_path),
      "Re-running the template must not modify application_client.rb"
    assert_equal initializer_before, File.read(initializer_path),
      "Re-running the template must not modify application_client_logging.rb"

    # Subclassing must work at boot — ApplicationClient is auto-loaded by Rails,
    # so a sibling class that inherits and sets BASE_URI exercises the
    # `self.inherited` hook during eager-load.
    File.write("#{@app_dir}/app/clients/foo_client.rb", <<~RUBY)
      class FooClient < ApplicationClient
        BASE_URI = "https://example.com"
      end
    RUBY

    assert_rails_boots
  end
end
