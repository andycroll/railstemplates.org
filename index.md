---
layout: home
title: Rails Templates
---

# Rails Application Templates

Simple, focused Rails application templates that you can install directly with `curl`.

## Available Templates

{% for template in site.templates %}
- **[{{ template.title }}]({{ template.url }})** - {{ template.description }}
  ```bash
  rails new myapp -m <(curl -s {{ site.url }}/templates/{{ template.title | slugify }}.rb)
  ```
{% endfor %}

## How to Use

Each template can be applied to a new Rails application using the `-m` flag with `curl`:

```bash
rails new your_app_name -m <(curl -s https://railstemplates.org/templates/template-name.rb)
```

## What are Rails Templates?

Rails application templates are Ruby scripts that run during the `rails new` command to customize your new application. They can add gems, generate files, run commands, and set up your application exactly how you want it.

Learn more about Rails templates in the [official Rails guides](https://guides.rubyonrails.org/rails_application_templates.html).