---
title: Bootstrap UI
description: Sets up a Rails application with Bootstrap 5, Stimulus, and a basic layout
layout: template
---

```ruby
# Rails Template: Bootstrap UI Setup
# Usage: rails new myapp -m <(curl -s https://railstemplates.org/templates/bootstrap-ui/)

# Add gems for UI
gem 'bootstrap', '~> 5.2'
gem 'jquery-rails', '~> 4.5'

gem_group :development, :test do
  gem 'rspec-rails', '~> 6.0'
  gem 'capybara', '~> 3.39'
  gem 'selenium-webdriver', '~> 4.0'
end

# Run bundle install
run 'bundle install'

# Configure importmap for Bootstrap and jQuery
run 'bin/importmap pin bootstrap'
run 'bin/importmap pin @popperjs/core --from jsdelivr'
run 'bin/importmap pin jquery --from jsdelivr'

# Update application.js to include Bootstrap
inject_into_file 'app/javascript/application.js', after: '// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails' do <<~JS

import "bootstrap"
import jquery from "jquery"
window.jQuery = jquery
window.$ = jquery
JS
end

# Add Bootstrap to application.scss
create_file 'app/assets/stylesheets/application.bootstrap.scss' do <<~SCSS
@import "bootstrap";

body {
  padding-top: 70px;
}

.navbar-brand {
  font-weight: bold;
}
SCSS
end

# Update application layout with Bootstrap navbar
gsub_file 'app/views/layouts/application.html.erb', 
  '<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>', 
  '<%= stylesheet_link_tag "application.bootstrap", "data-turbo-track": "reload" %>'

inject_into_file 'app/views/layouts/application.html.erb', after: '<body>' do <<~HTML

    <nav class="navbar navbar-expand-lg navbar-dark bg-primary fixed-top">
      <div class="container">
        <%= link_to "My App", root_path, class: "navbar-brand" %>
        
        <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
          <span class="navbar-toggler-icon"></span>
        </button>
        
        <div class="collapse navbar-collapse" id="navbarNav">
          <ul class="navbar-nav ms-auto">
            <li class="nav-item">
              <%= link_to "Home", root_path, class: "nav-link" %>
            </li>
          </ul>
        </div>
      </div>
    </nav>

    <div class="container">
HTML
end

inject_into_file 'app/views/layouts/application.html.erb', before: '</body>' do <<~HTML
    </div>
HTML
end

# Generate a home controller and view
generate 'controller', 'Home', 'index'

# Update routes
route "root 'home#index'"

# Create a Bootstrap-styled home page
create_file 'app/views/home/index.html.erb' do <<~HTML
<div class="jumbotron bg-light p-5 rounded-lg mb-4">
  <h1 class="display-4">Welcome to Your Rails App!</h1>
  <p class="lead">This application has been set up with Bootstrap 5 for beautiful, responsive UI components.</p>
  <hr class="my-4">
  <p>Get started by editing this page in <code>app/views/home/index.html.erb</code></p>
  <a class="btn btn-primary btn-lg" href="#" role="button">Get Started</a>
</div>

<div class="row">
  <div class="col-md-4">
    <h3>Bootstrap Components</h3>
    <p>Your app includes Bootstrap 5 with all components available for building modern web interfaces.</p>
  </div>
  <div class="col-md-4">
    <h3>Stimulus JS</h3>
    <p>Stimulus is already configured and ready for adding JavaScript behavior to your HTML.</p>
  </div>
  <div class="col-md-4">
    <h3>Responsive Design</h3>
    <p>Bootstrap's grid system ensures your app looks great on all devices.</p>
  </div>
</div>
HTML
end

# Generate RSpec configuration
generate 'rspec:install'

say "Bootstrap UI template applied successfully!"
say "Your Rails app now includes Bootstrap 5, jQuery, and a responsive layout."
say "Visit the home page to see the Bootstrap styling in action."
```