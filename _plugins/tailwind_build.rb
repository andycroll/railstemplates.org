Jekyll::Hooks.register :site, :after_init do |site|
  if Jekyll.env == 'development'
    # Start tailwindcss in watch mode for development
    Thread.new do
      system("bundle exec tailwindcss --input assets/tailwind/application.css --output assets/css/main.css --watch")
    end
  end
end

# For production: build CSS AFTER Jekyll generates HTML, then copy to _site
Jekyll::Hooks.register :site, :post_write do |site|
  if Jekyll.env == 'production'
    # Ensure the tailwindcss binary is available
    unless system("bundle exec tailwindcss --version > /dev/null 2>&1")
      Jekyll.logger.error "Tailwind:", "tailwindcss binary not found"
      exit 1
    end
    
    # Build the CSS after HTML is generated (so Tailwind can scan it)
    unless system("bundle exec tailwindcss --input assets/tailwind/application.css --output _site/assets/css/main.css --minify")
      Jekyll.logger.error "Tailwind:", "build failed"
      exit 1
    end

    Jekyll.logger.info "Tailwind:", "CSS built successfully"
  end
end