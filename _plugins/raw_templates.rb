Jekyll::Hooks.register :site, :post_write do |site|
  # Copy template.rb files to the site output directory
  Dir.glob("_templates/*/template.rb").each do |template_file|
    # Extract template name from path
    template_name = File.dirname(template_file).split('/').last
    
    # Copy to new URL structure: /{template_name}/template
    new_dest_dir = File.join(site.dest, template_name)
    FileUtils.mkdir_p(new_dest_dir)
    
    new_dest_file_clean = File.join(new_dest_dir, "template")
    FileUtils.cp(template_file, new_dest_file_clean)
    
    puts "Copied #{template_file} to #{new_dest_file_clean}"
  end
  
  # Copy additional template support files
  Dir.glob("_templates/*/*.rb").each do |support_file|
    next if support_file.end_with?("template.rb") # Skip main template files
    
    # Extract template name and file name
    parts = support_file.split('/')
    template_name = parts[-2]
    file_name = parts[-1]
    
    # Create destination directory in _site/{template_name}
    dest_dir = File.join(site.dest, template_name)
    FileUtils.mkdir_p(dest_dir)
    
    # Copy support file
    dest_file = File.join(dest_dir, file_name)
    FileUtils.cp(support_file, dest_file)
    
    puts "Copied #{support_file} to #{dest_file}"
  end
end