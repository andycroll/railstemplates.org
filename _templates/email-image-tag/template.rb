#!/usr/bin/env ruby

# Email Image Tag Rails Application Template
# Inspired by https://github.com/bullet-train-co/bullet_train-core/blob/main/bullet_train/app/helpers/email_helper.rb
# Usage: rails new myapp -m https://railstemplates.org/email-image-tag/template
# Usage: rails app:template LOCATION=https://railstemplates.org/email-image-tag/template

say "railstemplates.org"
say "Adding email_image_tag helper...", :green

create_file "app/helpers/email_helper.rb", <<~RUBY, force: true
  module EmailHelper
    def email_image_tag(image, **)
      attachments.inline[image] = File.binread(Rails.root.join("app/assets/images", image))
      image_tag(attachments.inline[image].url, **)
    end
  end
RUBY

say "EmailHelper installed. Use email_image_tag in your mailer views.", :green
