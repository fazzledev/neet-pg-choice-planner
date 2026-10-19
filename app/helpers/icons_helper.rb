module IconsHelper
  def icon(name, size: nil, label: nil)
    attrs = { class: ["icon", ("icon-#{size}" if size)].compact.join(" ") }
    attrs.merge!(label ? { role: "img", "aria-label": label } : { "aria-hidden": "true" })
    content_tag(:svg, tag.use(href: "#{asset_path("icons.svg")}##{name}"), attrs)
  end
end
