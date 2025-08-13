# Technical Stack

> Last Updated: 2025-08-13
> Version: 1.0.0

## Core Technologies

- **Site Generator:** Jekyll (latest)
- **Hosting:** GitHub Pages
- **Version Control:** GitHub
- **Content Format:** Markdown
- **Template Language:** Liquid

## Frontend

- **CSS Framework:** TailwindCSS 4.0+ with DaisyUI
- **JavaScript:** Minimal vanilla JS for search/filtering
- **Syntax Highlighting:** Rouge (for Ruby/Rails code blocks)
- **Icons:** Boxicons (self-hosted)
- **Fonts:** Google Fonts (self-hosted for performance)

## Content & Data

- **Template Storage:** YAML data files
- **Categories:** YAML-based taxonomy
- **Search:** Client-side JavaScript search
- **Template Metadata:** Frontmatter in Markdown files

## Development Tools

- **Build Tool:** Jekyll's built-in build system
- **CSS Processing:** Jekyll PostCSS plugin for Tailwind
- **Local Development:** Jekyll serve with livereload
- **Testing Rails Templates:** Embedded Rails app in /test-rails-app (for CI testing)

## Deployment & Infrastructure

- **Hosting Platform:** GitHub Pages
- **Domain:** railstemplates.org
- **SSL:** GitHub Pages automatic SSL
- **CDN:** GitHub Pages CDN
- **Analytics:** Simple Analytics or Plausible
- **Monitoring:** GitHub Pages status

## CI/CD

- **CI Platform:** GitHub Actions
- **Deployment Trigger:** Push to main branch
- **Build Process:** Jekyll build
- **Template Validation:** Automated testing against test Rails app
- **Link Checking:** HTML-proofer for broken links

## Repository

- **Code Repository:** https://github.com/andycroll/railstemplates.org
- **Issue Tracking:** GitHub Issues
- **Template Submissions:** GitHub Pull Requests