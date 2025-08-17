---
layout: default
title: Rails Templates
---

<section class="py-8 px-4">
  <div>
    <p class="text-lg text-base-content/80 mb-8">
      Rails application templates are Ruby scripts that run during the <code class="badge badge-outline">rails new</code> 
      command to customize your new application. They can add gems, generate files, run commands, and set up your 
      application exactly how you want it. You can also apply templates to existing Rails applications using 
      <code class="badge badge-outline">rails app:template</code>.
    </p>
    
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
      <div>
        <h3 class="text-xl font-semibold mb-3 text-base-content">For new applications:</h3>
        <div class="mockup-code bg-neutral text-neutral-content">
          <pre data-prefix="$"><code>rails new myapp -m https://railstemplates.org/name/template</code></pre>
        </div>
      </div>
      
      <div>
        <h3 class="text-xl font-semibold mb-3 text-base-content">For existing applications:</h3>
        <div class="mockup-code bg-neutral text-neutral-content">
          <pre data-prefix="$"><code>rails app:template LOCATION=https://railstemplates.org/name/template</code></pre>
        </div>
      </div>
    </div>
    
    <a href="https://guides.rubyonrails.org/rails_application_templates.html" 
       class="btn btn-outline btn-lg" target="_blank" rel="noopener">
      Read the Official Guide
    </a>
  </div>
</section>

<section id="templates" class="py-8 px-4">  
  <div class="grid gap-6 sm:gap-8 grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
    {% for template in site.templates %}
      <div class="card bg-base-100 shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-105">
        <div class="card-body p-4 md:p-6">
          <h3 class="card-title text-primary mb-3 text-lg md:text-xl">
            <a href="{{ template.url }}" class="hover:underline">{{ template.title }}</a>
          </h3>
          <p class="text-base-content/80 mb-6 text-sm md:text-base leading-relaxed">{{ template.description }}</p>
          
          <div class="card-actions">
            <div class="w-full space-y-3">
              <div class="flex flex-col sm:flex-row gap-2">
                <a href="{{ template.url }}" class="btn btn-primary btn-sm flex-1 text-xs md:text-sm">
                  Learn More
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    {% endfor %}
  </div>
</section>



<script>
function copyToClipboard(button) {
  const text = button.getAttribute('data-text');
  navigator.clipboard.writeText(text).then(() => {
    const originalText = button.textContent;
    button.textContent = 'Copied!';
    button.classList.add('btn-success');
    button.classList.remove('btn-outline');
    setTimeout(() => {
      button.textContent = originalText;
      button.classList.remove('btn-success');
      button.classList.add('btn-outline');
    }, 2000);
  });
}
</script>