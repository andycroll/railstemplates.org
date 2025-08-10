Jekyll::Hooks.register [:pages, :documents], :pre_render do |page|
  # Check if this is a template page (has layout: template)
  if page.data["layout"] == "template"
    # Try to find the template.rb file
    if page.respond_to?(:path)
      page_dir = File.dirname(page.path)
      template_file = File.join(page_dir, "template.rb")
      
      # If template.rb exists in same directory, read it
      if File.exist?(template_file)
        page.data["template_source"] = File.read(template_file)
      else
        # Try to construct path based on page title
        template_name = page.data["title"]&.downcase&.gsub(" ", "-") || ""
        template_file = File.join(page.site.source, "_templates", template_name, "template.rb")
        
        if File.exist?(template_file)
          page.data["template_source"] = File.read(template_file)
        end
      end
    end
  end
end