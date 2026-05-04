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
end

require_relative "lib/westan_vip_painel/engine"

after_initialize do
  require_relative "app/controllers/westan_vip_painel/painel_controller"

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
