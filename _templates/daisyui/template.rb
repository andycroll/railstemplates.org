#!/usr/bin/env ruby

# DaisyUI Rails Application Template
# Usage: rails new myapp -m https://railstemplates.org/daisyui/template
# Usage: rails app:template LOCATION=https://railstemplates.org/daisyui/template

say "railstmplates.org"
say "🌼 Installing DaisyUI for Rails...", :green

# Check if Tailwind CSS is installed
def tailwind_installed?
  File.exist?("app/assets/stylesheets/application.tailwind.css") ||
    File.exist?("app/assets/tailwind/application.css") ||
    File.exist?("config/tailwind.config.js")
end

# Install Tailwind CSS if needed
unless tailwind_installed?
  say "Installing Tailwind CSS...", :blue
  gem "tailwindcss-rails"

  after_bundle do
    generate "tailwindcss:install"
    say "✓ Tailwind CSS installed", :green
  end
end

after_bundle do
  # Download and run DaisyUI installation
  create_daisyui_rake_task

  say "\n🎉 Setup complete! DaisyUI is ready to use.", :green
end

def create_daisyui_rake_task
  require 'net/http'
  require 'uri'
  
  rake_url = "https://railstemplates.org/daisyui/daisyui.rake"
  rake_path = "lib/tasks/daisyui.rake"
  
  say "📥 Downloading DaisyUI rake tasks...", :blue
  
  begin
    uri = URI(rake_url)
    response = Net::HTTP.get_response(uri)
    
    if response.code == "200"
      create_file rake_path, response.body, skip: true
      say "✅ Downloaded DaisyUI rake tasks to #{rake_path}", :green
      
      # Run the install task
      say "🚀 Running DaisyUI installation...", :blue
      run "bin/rails daisyui:install"
    else
      say "❌ Failed to download rake tasks (HTTP #{response.code})", :red
      say "   You can manually download from: #{rake_url}", :yellow
      say "   And save it to: #{rake_path}", :yellow
    end
  rescue => e
    say "❌ Error downloading rake tasks: #{e.message}", :red
    say "   You can manually download from: #{rake_url}", :yellow
    say "   And save it to: #{rake_path}", :yellow
  end
end
