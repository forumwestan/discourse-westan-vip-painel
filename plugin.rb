# frozen_string_literal: true

# name: discourse-westan-vip-painel
# about: VIP preference panel for nickname colors, custom badges, and profile titles
# meta_topic_id: 0
# version: 0.1.0
# authors: Westan
# url: https://github.com/forumwestan/discourse-westan-vip-painel
# required_version: 3.2.0

enabled_site_setting :westan_vip_painel_enabled

register_asset "stylesheets/westan-vip-painel/painel.scss"

register_svg_icon "crown"
register_svg_icon "bolt"
register_svg_icon "check"
register_svg_icon "xmark"
register_svg_icon "plus"
register_svg_icon "trash-can"

module ::WestanVipPainel
  PLUGIN_NAME = "discourse-westan-vip-painel"

  CUSTOM_FIELDS = {
    theme_id: "westan_vip_theme_id",
    nickname_style_id: "westan_vip_nickname_style_id",
    nickname_color: "westan_vip_nickname_color",
    badge_enabled: "westan_vip_badge_enabled",
    custom_card_enabled: "westan_vip_custom_card_enabled",
    custom_title: "westan_vip_custom_title"
  }.freeze

  def self.vip_member?(user)
    return false unless user

    group_name = SiteSetting.westan_vip_painel_group.to_s.downcase
    user.groups.any? { |group| group.name.to_s.downcase == group_name }
  end

  def self.post_render_payload(user)
    return unless vip_member?(user)

    fields = CUSTOM_FIELDS
    styles = JSON.parse(SiteSetting.westan_vip_painel_nickname_styles_json.to_s)
    styles = [] unless styles.is_a?(Array)
    styles = styles.select { |style| style["enabled"] != false }
    selected_id = user.custom_fields[fields[:nickname_style_id]].presence
    selected_style =
      styles.find { |style| style["id"].to_s == selected_id.to_s } || styles.first

    color = lambda do |value, fallback|
      candidate = value.to_s.strip
      candidate.match?(/\A#[0-9a-fA-F]{3,8}\z/) ? candidate : fallback
    end

    {
      verified: true,
      nickname_style:
        selected_style && {
          from: color.call(selected_style["from"], "#D97706"),
          to: color.call(selected_style["to"], "#FDE68A")
        },
      custom_title: user.custom_fields[fields[:custom_title]].to_s
    }
  rescue JSON::ParserError
    { verified: true, nickname_style: nil, custom_title: "" }
  end
end

require_relative "lib/westan_vip_painel/engine"

after_initialize do
  require_relative "app/controllers/westan_vip_painel/painel_controller"

  add_to_serializer(:post, :westan_vip_painel) do
    WestanVipPainel.post_render_payload(object.user)
  end

  WestanVipPainel::Engine.routes.draw do
    get   "/"            => "painel#show"
    patch "/"            => "painel#update"
    get   "/post-users"  => "painel#post_users"
    get   "/admin/catalog" => "painel#admin_catalog"
    patch "/admin/catalog" => "painel#admin_update_catalog"
  end

  Discourse::Application.routes.prepend do
    get   "/westan/vip-painel"            => "westan_vip_painel/painel#show"
    patch "/westan/vip-painel"            => "westan_vip_painel/painel#update"
    get   "/westan/vip-painel/post-users" => "westan_vip_painel/painel#post_users"
    get   "/westan/vip-painel/admin/catalog" => "westan_vip_painel/painel#admin_catalog"
    patch "/westan/vip-painel/admin/catalog" => "westan_vip_painel/painel#admin_update_catalog"
  end

  Discourse::Application.routes.append do
    get "/vip-painel" => "list#latest"
    get "/vip-painel/*path" => "list#latest"
    get "/admin/plugins/westan-vip-painel" => "list#latest"
  end

  WestanVipPainel::CUSTOM_FIELDS.values.each do |field|
    User.register_custom_field_type(field, :text)
    DiscoursePluginRegistry.serialized_current_user_fields << field
  end

  add_to_serializer(:current_user, :westan_vip_painel_can_use) do
    group_name = SiteSetting.westan_vip_painel_group.to_s.downcase
    object.groups.any? { |group| group.name.to_s.downcase == group_name }
  end
end
