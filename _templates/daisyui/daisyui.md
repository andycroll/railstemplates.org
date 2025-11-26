---
title: DaisyUI
description: Sets up a Rails application with Tailwind CSS and DaisyUI component library for beautiful, responsive UI components
layout: template
---

Installs [DaisyUI](https://daisyui.com/) into your Rails app. Handles both Tailwind v3 and v4 configurations automatically.

If Tailwind CSS isn't installed, it will be added first using `tailwindcss-rails`.

## Rake Tasks

The template adds several tasks under the `daisyui` namespace:

- `rake daisyui:install` - Downloads DaisyUI plugin, updates Tailwind config, rebuilds CSS
- `rake daisyui:status` - Shows current installation status
- `rake daisyui:download` - Re-downloads the plugin (useful for updates)
- `rake daisyui:form_builder` - Installs a Rails form builder with DaisyUI styling

## Form Builder

The optional form builder (`rake daisyui:form_builder`) provides:

- Automatic DaisyUI styling for all Rails form helpers
- Error state handling with visual indicators
- Size variants: `size: :xs`, `size: :sm`, `size: :lg`
- Color variants: `color: :primary`, `color: :secondary`, etc.

```erb
<%= form_with model: @user do |f| %>
  <%= f.text_field :name, size: :lg %>
  <%= f.email_field :email %>
  <%= f.submit "Save", color: :primary %>
<% end %>
```
