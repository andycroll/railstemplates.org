---
title: Basic API
description: Sets up a Rails application configured for API-only mode with common gems
layout: template
---

```ruby
# Rails Template: Basic API Setup
# Usage: rails new myapp -m <(curl -s https://railstemplates.org/templates/basic-api/)

# Configure for API mode
gsub_file "config/application.rb", "# config.api_only = true", "config.api_only = true"

# Add useful gems for API development
gem 'rack-cors', '~> 1.1'
gem 'jsonapi-serializer', '~> 2.2'

gem_group :development, :test do
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails', '~> 6.2'
  gem 'faker', '~> 3.0'
end

gem_group :development do
  gem 'annotate', '~> 3.2'
end

# Run bundle install
run 'bundle install'

# Generate RSpec configuration
generate 'rspec:install'

# Configure CORS
create_file 'config/initializers/cors.rb' do <<~RUBY
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'localhost:3000', '127.0.0.1:3000'
    
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
RUBY
end

# Create a basic API controller
create_file 'app/controllers/api/v1/base_controller.rb' do <<~RUBY
class Api::V1::BaseController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  def not_found
    render json: { error: 'Not found' }, status: :not_found
  end
end
RUBY
end

# Update routes for API versioning
gsub_file 'config/routes.rb', /Rails\.application\.routes\.draw do\s*\n/, <<~RUBY
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Add your API routes here
    end
  end
RUBY

say "Basic API template applied successfully!"
say "Your Rails API is ready with CORS, RSpec, and basic structure."
say "Add your API endpoints in config/routes.rb under the api/v1 namespace."
```