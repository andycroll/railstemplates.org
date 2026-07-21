require_relative "../test_helper"

class EmailImageTagTest < TemplateTestCase
  def test_email_image_tag
    create_rails_app
    apply_template("email-image-tag")

    assert File.exist?("#{@app_dir}/app/helpers/email_helper.rb")
    helper = File.read("#{@app_dir}/app/helpers/email_helper.rb")
    assert_match(/email_image_tag/, helper)
    assert_match(/attachments\.inline/, helper)

    assert_rails_boots
  end
end
