---
title: DaisyUI
description: Sets up a Rails application with Tailwind CSS and DaisyUI component library for beautiful, responsive UI components
layout: template
---

## What This Template Does

### 1. Tailwind CSS Setup
- **Checks for existing Tailwind installation** in your Rails app
- **Automatically installs Tailwind CSS** if not present using the `tailwindcss-rails` gem
- **Configures Tailwind** for optimal performance with Rails

### 2. DaisyUI Integration
- **Downloads the latest DaisyUI plugin** directly from the official GitHub releases
- **Configures your Tailwind setup** to include DaisyUI as a plugin
- **Handles both Tailwind v3 and v4** configurations automatically

### 3. Rake Tasks
The template installs several helpful rake tasks under the `daisyui` namespace:

#### `rake daisyui:install`
- Downloads and installs the DaisyUI plugin
- Updates your Tailwind configuration
- Rebuilds your CSS with DaisyUI components included

#### `rake daisyui:status`
- Shows the current DaisyUI installation status
- Verifies plugin files and configuration
- Helpful for debugging installation issues

#### `rake daisyui:download`
- Re-downloads the DaisyUI plugin from the latest release
- Useful for updating to newer versions

#### `rake daisyui:form_builder`
- Downloads and installs a custom Rails form builder for DaisyUI
- Creates styled form helpers that automatically apply DaisyUI classes
- Optionally configures ApplicationController to use the form builder by default
- Provides automatic error styling and messages for form fields

## Features

### Beautiful Components
Once installed, you have access to all DaisyUI components:
- **Buttons**: `btn`, `btn-primary`, `btn-secondary`, etc.
- **Cards**: `card`, `card-body`, `card-title`
- **Forms**: `input`, `select`, `checkbox`, `radio`
- **Navigation**: `navbar`, `drawer`, `tabs`
- **Feedback**: `alert`, `toast`, `modal`
- **Data Display**: `table`, `badge`, `progress`
- And many more!


### Form Builder Features
The optional form builder provides:
- **Automatic DaisyUI styling** for all Rails form helpers
- **Error state handling** with visual indicators
- **Size variants**: `size: :xs`, `size: :sm`, `size: :lg`
- **Color variants**: `color: :primary`, `color: :secondary`, etc.
- **Consistent styling** across your entire application

## Usage Examples

### Basic Components
```erb
<!-- Button -->
<button class="btn btn-primary">Click me!</button>

<!-- Card -->
<div class="card bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Card title!</h2>
    <p>Card content goes here</p>
  </div>
</div>

<!-- Alert -->
<div class="alert alert-success">
  <span>Your purchase has been confirmed!</span>
</div>
```

### With Form Builder
```erb
<%= form_with model: @user do |f| %>
  <%= f.text_field :name, placeholder: "Enter name", size: :lg %>
  <%= f.email_field :email, placeholder: "Email address" %>
  <%= f.select :role, options_for_select(roles), {}, color: :accent %>
  <%= f.submit "Save", color: :primary %>
<% end %>
```

## Requirements

- Rails 7.0 or higher
- Node.js for asset compilation
- Tailwind CSS (automatically installed if not present)

## Resources

- [DaisyUI Documentation](https://daisyui.com/)
- [Component Examples](https://daisyui.com/components/)
- [Theme Generator](https://daisyui.com/theme-generator/)
- [Tailwind CSS Documentation](https://tailwindcss.com/)

## Troubleshooting

If you encounter issues:

1. **Check installation status**: Run `rake daisyui:status`
2. **Rebuild assets**: Run `bin/rails tailwindcss:build`
3. **Verify Tailwind config**: Check `app/assets/tailwind/application.css` includes `@plugin "./daisyui.js"`
4. **Manual download**: If automatic download fails, the rake task will provide manual download instructions