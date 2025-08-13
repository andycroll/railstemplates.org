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
    Jekyll.logger.info "Tailwind:", "Building CSS after HTML generation..."
    
    # Ensure the tailwindcss binary is available
    unless system("bundle exec tailwindcss --version > /dev/null 2>&1")
      Jekyll.logger.error "Tailwind:", "tailwindcss binary not found"
      exit 1
    end
    
    # Build the CSS after HTML is generated (so Tailwind can scan it)
    success = system("bundle exec tailwindcss --input assets/tailwind/application.css --output assets/css/main.css --minify")
    
    if success
      Jekyll.logger.info "Tailwind:", "CSS built successfully"
      
      # Copy the generated CSS to _site
      css_source = File.join(site.source, "assets/css/main.css")
      css_dest = File.join(site.dest, "assets/css/main.css")
      
      # Ensure destination directory exists
      FileUtils.mkdir_p(File.dirname(css_dest))
      
      # Copy the CSS file
      FileUtils.cp(css_source, css_dest)
      Jekyll.logger.info "Tailwind:", "CSS copied to _site"
    else
      Jekyll.logger.error "Tailwind:", "Failed to build CSS"
      exit 1
    end
  end
end