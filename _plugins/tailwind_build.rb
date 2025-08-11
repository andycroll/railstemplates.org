Jekyll::Hooks.register :site, :after_init do |site|
  if Jekyll.env == 'development'
    # Start tailwindcss in watch mode for development
    Thread.new do
      system("bundle exec tailwindcss --input assets/tailwind/application.css --output assets/css/main.css --watch")
    end
  else
    # Build once for production
    system("bundle exec tailwindcss --input assets/tailwind/application.css --output assets/css/main.css")
  end
end