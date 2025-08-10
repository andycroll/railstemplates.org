Jekyll::Hooks.register :site, :post_write do |site|
  # Copy template.rb files to the site output directory
  Dir.glob("_templates/*/template.rb").each do |template_file|
    # Extract template name from path
    template_name = File.dirname(template_file).split('/').last
    
    # Create destination directory in _site/templates
    dest_dir = File.join(site.dest, "templates")
    FileUtils.mkdir_p(dest_dir)
    
    # Copy template.rb with .rb extension for Rails to consume
    dest_file = File.join(dest_dir, "#{template_name}.rb")
    FileUtils.cp(template_file, dest_file)
    
    puts "Copied #{template_file} to #{dest_file}"
  end
  
  # Copy additional template support files
  Dir.glob("_templates/*/*.rb").each do |support_file|
    next if support_file.end_with?("template.rb") # Skip main template files
    
    # Extract template name and file name
    parts = support_file.split('/')
    template_name = parts[-2]
    file_name = parts[-1]
    
    # Create destination directory in _site/templates/template_name
    dest_dir = File.join(site.dest, "templates", template_name)
    FileUtils.mkdir_p(dest_dir)
    
    # Copy support file
    dest_file = File.join(dest_dir, file_name)
    FileUtils.cp(support_file, dest_file)
    
    puts "Copied #{support_file} to #{dest_file}"
  end
end