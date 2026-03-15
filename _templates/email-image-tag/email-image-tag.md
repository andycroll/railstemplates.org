---
layout: template
title: Email Image Tag
description: Add a helper for inline image attachments in Action Mailer views
---

Adds an `email_image_tag` helper that simplifies inline image attachments in mailer views.

## What It Does

- Creates `app/helpers/email_helper.rb` with an `email_image_tag` method
- Reads images from `app/assets/images/` and attaches them inline
- Returns an `image_tag` referencing the inline attachment URL

## Usage

Place images in `app/assets/images/`, then use the helper in your mailer views:

    <%= email_image_tag("logo.png", alt: "Company Logo", width: 200) %>

This replaces the manual approach of attaching images in your mailer and referencing them in views:

    # Before (in mailer)
    attachments.inline["logo.png"] = File.binread("app/assets/images/logo.png")

    # Before (in view)
    <%= image_tag attachments["logo.png"].url, alt: "Company Logo", width: 200 %>

## How It Works

Action Mailer supports [inline attachments](https://guides.rubyonrails.org/action_mailer_basics.html#making-inline-attachments) via `attachments.inline`. The helper reads the image file, attaches it inline, and returns an `image_tag` pointing to the attachment's content URL — all in one call.

Any additional keyword arguments (`alt:`, `width:`, `class:`, etc.) are passed through to `image_tag`.
