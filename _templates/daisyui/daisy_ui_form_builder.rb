class DaisyUiFormBuilder < ActionView::Helpers::FormBuilder
  def text_field(method, options = {})
    options[:class] = merge_classes("input", options[:class])

    if options[:size]
      size_class = "input-#{options.delete(:size)}"
      options[:class] = merge_classes(options[:class], size_class)
    end

    if options[:color]
      color_class = "input-#{options.delete(:color)}"
      options[:class] = merge_classes(options[:class], color_class)
    end

    if object && object.errors[method].any?
      options[:class] = merge_classes(options[:class], "input-error")
    end

    field = super(method, options)

    if object && object.errors[method].any?
      error_message = @template.content_tag(:p, object.errors[method].first, class: "text-error text-sm mt-1")
      field + error_message
    else
      field
    end
  end

  def email_field(method, options = {})
    text_field(method, options.merge(type: :email))
  end

  def password_field(method, options = {})
    text_field(method, options.merge(type: :password))
  end

  def number_field(method, options = {})
    text_field(method, options.merge(type: :number))
  end

  def search_field(method, options = {})
    text_field(method, options.merge(type: :search))
  end

  def telephone_field(method, options = {})
    text_field(method, options.merge(type: :tel))
  end
  alias phone_field telephone_field

  def url_field(method, options = {})
    text_field(method, options.merge(type: :url))
  end

  def date_field(method, options = {})
    text_field(method, options.merge(type: :date))
  end

  def time_field(method, options = {})
    text_field(method, options.merge(type: :time))
  end

  def datetime_field(method, options = {})
    text_field(method, options.merge(type: :datetime))
  end

  def datetime_local_field(method, options = {})
    text_field(method, options.merge(type: "datetime-local"))
  end

  def month_field(method, options = {})
    text_field(method, options.merge(type: :month))
  end

  def week_field(method, options = {})
    text_field(method, options.merge(type: :week))
  end

  def color_field(method, options = {})
    text_field(method, options.merge(type: :color))
  end

  def select(method, choices = nil, options = {}, html_options = {}, &block)
    html_options[:class] = merge_classes("select", html_options[:class])

    if html_options[:size]
      size_class = "select-#{html_options.delete(:size)}"
      html_options[:class] = merge_classes(html_options[:class], size_class)
    end

    if html_options[:color]
      color_class = "select-#{html_options.delete(:color)}"
      html_options[:class] = merge_classes(html_options[:class], color_class)
    end

    if object && object.errors[method].any?
      html_options[:class] = merge_classes(html_options[:class], "select-error")
    end

    field = super(method, choices, options, html_options, &block)

    if object && object.errors[method].any?
      error_message = @template.content_tag(:p, object.errors[method].first, class: "text-error text-sm mt-1")
      field + error_message
    else
      field
    end
  end

  def radio_button(method, tag_value, options = {})
    options[:class] = merge_classes("radio", options[:class])

    if options[:size]
      size_class = "radio-#{options.delete(:size)}"
      options[:class] = merge_classes(options[:class], size_class)
    end

    if options[:color]
      color_class = "radio-#{options.delete(:color)}"
      options[:class] = merge_classes(options[:class], color_class)
    end

    super(method, tag_value, options)
  end

  def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
    options[:class] = merge_classes("checkbox", options[:class])

    if options[:size]
      size_class = "checkbox-#{options.delete(:size)}"
      options[:class] = merge_classes(options[:class], size_class)
    end

    if options[:color]
      color_class = "checkbox-#{options.delete(:color)}"
      options[:class] = merge_classes(options[:class], color_class)
    end

    super(method, options, checked_value, unchecked_value)
  end

  def label(method, text = nil, options = {}, &block)
    options[:class] = merge_classes("label", options[:class])

    if object && object.errors[method].any?
      options[:class] = merge_classes(options[:class], "text-error")
    end

    super(method, text, options, &block)
  end

  def submit(value = nil, options = {})
    options[:class] = merge_classes("btn btn-primary", options[:class])

    if options[:size]
      size_class = "btn-#{options.delete(:size)}"
      options[:class] = merge_classes(options[:class], size_class)
    end

    if options[:color]
      color_class = "btn-#{options.delete(:color)}"
      options[:class] = merge_classes(options[:class], color_class).gsub("btn-primary", "")
    end

    super(value, options)
  end

  def textarea(method, options = {})
    options[:class] = merge_classes("textarea", options[:class])

    if options[:size]
      size_class = "textarea-#{options.delete(:size)}"
      options[:class] = merge_classes(options[:class], size_class)
    end

    if options[:color]
      color_class = "textarea-#{options.delete(:color)}"
      options[:class] = merge_classes(options[:class], color_class)
    end

    if object && object.errors[method].any?
      options[:class] = merge_classes(options[:class], "textarea-error")
    end

    field = super(method, options)

    if object && object.errors[method].any?
      error_message = @template.content_tag(:p, object.errors[method].first, class: "text-error text-sm mt-1")
      field + error_message
    else
      field
    end
  end

  def file_field(method, options = {})
    options[:class] = merge_classes("file-input", options[:class])

    if options[:size]
      size_class = "file-input-#{options.delete(:size)}"
      options[:class] = merge_classes(options[:class], size_class)
    end

    if options[:color]
      color_class = "file-input-#{options.delete(:color)}"
      options[:class] = merge_classes(options[:class], color_class)
    end

    if object && object.errors[method].any?
      options[:class] = merge_classes(options[:class], "file-input-error")
    end

    field = super(method, options)

    if object && object.errors[method].any?
      error_message = @template.content_tag(:p, object.errors[method].first, class: "text-error text-sm mt-1")
      field + error_message
    else
      field
    end
  end

  def range_field(method, options = {})
    options[:class] = merge_classes("range", options[:class])

    if options[:size]
      size_class = "range-#{options.delete(:size)}"
      options[:class] = merge_classes(options[:class], size_class)
    end

    if options[:color]
      color_class = "range-#{options.delete(:color)}"
      options[:class] = merge_classes(options[:class], color_class)
    end

    if object && object.errors[method].any?
      options[:class] = merge_classes(options[:class], "range-error")
    end

    super(method, options)
  end

  def hidden_field(method, options = {})
    super(method, options)
  end

  def fieldset(legend = nil, options = {}, &block)
    options[:class] = merge_classes("fieldset", options[:class])

    content = @template.capture(&block)

    if legend
      legend_tag = @template.content_tag(:legend, legend, class: "fieldset-legend")
      @template.content_tag(:fieldset, legend_tag + content, options)
    else
      @template.content_tag(:fieldset, content, options)
    end
  end

  def form_group(method = nil, &block)
    content = @template.capture(&block)

    classes = [ "form-control" ]
    if method && object && object.errors[method].any?
      classes << "has-error"
    end

    @template.content_tag(:div, content, class: classes.join(" "))
  end

  private

  def merge_classes(default_classes, custom_classes)
    classes = default_classes.to_s.split(" ")
    classes += custom_classes.to_s.split(" ")
    classes.uniq.join(" ")
  end
end