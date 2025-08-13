# Build CSS before Jekyll processes files
Jekyll::Hooks.register :site, :after_init do |site|
  Jekyll.logger.info "Tailwind:", "Initializing CSS build..."
  
  if Jekyll.env == 'development'
    # Start tailwindcss in watch mode for development
    Thread.new do
      system("bundle exec tailwindcss --input assets/tailwind/application.css --output assets/css/main.css --watch")
    end
  else
    # Build once for production
    Jekyll.logger.info "Tailwind:", "Building CSS for production..."
    
    # First ensure the tailwindcss binary is available
    unless system("bundle exec tailwindcss --version > /dev/null 2>&1")
      Jekyll.logger.error "Tailwind:", "tailwindcss binary not found. Installing..."
      system("bundle install")
    end
    
    # Build the CSS
    success = system("bundle exec tailwindcss --input assets/tailwind/application.css --output assets/css/main.css --minify")
    
    if success
      Jekyll.logger.info "Tailwind:", "CSS built successfully"
      # Force Jekyll to recognize the new file
      site.static_files << Jekyll::StaticFile.new(site, site.source, "assets/css", "main.css")
    else
      Jekyll.logger.error "Tailwind:", "Failed to build CSS"
      exit 1
    end
  end
end