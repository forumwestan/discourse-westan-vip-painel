# frozen_string_literal: true

# name: discourse-westan-vip-painel
# about: Ajustes do Premium: cores, selo, títulos e badges personalizados
# meta_topic_id: 0
# version: 0.2.1
# authors: Westan
# url: https://github.com/forumwestan/discourse-westan-vip-painel
# required_version: 3.2.0

enabled_site_setting :westan_vip_painel_enabled

register_asset "stylesheets/westan-vip-painel/painel.scss"
register_asset "stylesheets/westan-vip-painel/premium.scss"

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
    verified_enabled: "westan_vip_verified_enabled",
    custom_logo_url: "westan_vip_custom_logo_url",
    custom_background_url: "westan_vip_custom_background_url",
    custom_title: "westan_vip_custom_title"
  }.freeze

  def self.vip_member?(user)
    Preferences.can_use?(user)
  end

  def self.post_render_payload(user)
    Preferences.payload(user)
  end
end

require_relative "lib/westan_vip_painel/engine"
require_relative "lib/westan_vip_painel/preferences"
require_relative "lib/westan_vip_painel/colors"

after_initialize do
  require_relative "app/controllers/westan_vip_painel/painel_controller"
  require_relative "lib/westan_vip_painel/badge_image"

  add_to_serializer(:post, :westan_vip_painel) do
    WestanVipPainel.post_render_payload(object.user)
  end

  add_to_serializer(:post, :user_vip_color) { WestanVipPainel::Colors.selected(object.user) }
  %i[user user_card].each do |serializer|
    add_to_serializer(serializer, :user_vip_color) { WestanVipPainel::Colors.selected(object) }
    add_to_serializer(serializer, :westan_vip_painel) { WestanVipPainel::Preferences.payload(object) }
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
    WestanVipPainel::Preferences.can_use?(object)
  end
  add_to_serializer(:current_user, :westan_vip_painel_premium) do
    WestanVipPainel::Preferences.premium?(object)
  end
end
