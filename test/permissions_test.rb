# Standalone unit checks. Rails/Discourse request coverage lives in spec/requests.
require "minitest/autorun"
require "json"
require "ostruct"

# Minimal stand-ins for ActiveSupport and database models, never loaded in production.
class Object
  def blank?; respond_to?(:empty?) ? !!empty? : !self; end
  def present?; !blank?; end
  def presence; self if present?; end
end
class Array
  def filter_map; map { |item| yield(item) }.compact; end unless method_defined?(:filter_map)
end
module Discourse
  class InvalidAccess < StandardError; end
  class InvalidParameters < StandardError; end
end
module UserField
  def self.find_by(**); nil; end
end
SiteSetting = OpenStruct.new
module WestanVipPainel
  CUSTOM_FIELDS = {
    theme_id: "westan_vip_theme_id", nickname_style_id: "westan_vip_nickname_style_id",
    verified_enabled: "westan_vip_verified_enabled", badge_enabled: "westan_vip_badge_enabled",
    custom_card_enabled: "westan_vip_custom_card_enabled", custom_title: "westan_vip_custom_title",
    custom_logo_url: "westan_vip_custom_logo_url", custom_background_url: "westan_vip_custom_background_url"
  }
end
require_relative "../lib/westan_vip_painel/preferences"
require_relative "../lib/westan_vip_painel/colors"

class PremiumPermissionsTest < Minitest::Test
  P = WestanVipPainel::Preferences
  C = WestanVipPainel::Colors
  def setup
    SiteSetting.westan_vip_painel_enabled = true
    SiteSetting.westan_vip_painel_group = "vip"
    SiteSetting.westan_vip_painel_premium_group = "vip_elegivel"
    SiteSetting.westan_vip_painel_color_field_id = 6
    SiteSetting.westan_vip_painel_colors_json = '[{"value":"dourado","from":"#D97706","to":"#FDE68A"}]'
    SiteSetting.westan_vip_painel_themes_json = '[{"id":"gaga","enabled":true,"logoUrl":"https://example.org/logo.png"}]'
    SiteSetting.westan_vip_painel_nickname_styles_json = '[{"id":"orchid","name":"Orchid","from":"#EC4899","to":"#A855F7"}]'
    @user = OpenStruct.new(id: 12, username: "Blair", name: "Blair", groups: [], custom_fields: {})
  end
  def group(name); @user.groups << OpenStruct.new(name: name, id: name == "vip" ? 10 : 20); end
  def test_ordinary_member_has_no_access
    refute P.can_use?(@user)
    assert_nil P.payload(@user)
    assert_raises(Discourse::InvalidAccess) { C.assign!(@user, "dourado") }
  end
  def test_redeemed_vip_has_color_but_no_premium_effects_even_with_old_fields
    group("vip")
    @user.custom_fields.merge!("westan_vip_theme_id" => "gaga", "westan_vip_custom_title" => "Old title", "westan_vip_verified_enabled" => "true")
    C.assign!(@user, "dourado")
    data = P.payload(@user)
    assert P.can_use?(@user)
    refute P.premium?(@user)
    refute data[:verified]
    refute data[:badge_enabled]
    assert_nil data[:theme]
    assert_equal "", data[:custom_title]
    assert_equal "#D97706", data[:nickname_style][:from]
  end
  def test_paid_member_can_use_custom_badge_and_disable_seal
    group("vip_elegivel")
    @user.custom_fields.merge!("westan_vip_theme_id" => "custom", "westan_vip_custom_logo_url" => "https://example.org/a.png", "westan_vip_custom_background_url" => "https://example.org/b.gif")
    assert P.payload(@user)[:verified]
    assert_equal "custom", P.payload(@user)[:theme]["id"]
    @user.custom_fields["westan_vip_verified_enabled"] = "false"
    refute P.payload(@user)[:verified]
  end
  def test_revocation_hides_effects_without_deleting_saved_preferences
    group("vip_elegivel")
    @user.custom_fields["westan_vip_custom_title"] = "Remember me"
    @user.groups.clear
    assert_nil P.payload(@user)
    assert_equal "Remember me", @user.custom_fields["westan_vip_custom_title"]
  end
  def test_preserves_user_field_color_and_legacy_style
    group("vip")
    @user.custom_fields["user_field_6"] = " Dourado "
    assert_equal "dourado", C.selected(@user)
    @user.custom_fields.delete("user_field_6")
    @user.custom_fields["westan_vip_nickname_style_id"] = "orchid"
    assert_equal "#EC4899", C.style(@user)[:from]
    C.assign!(@user, "")
    assert_nil C.style(@user)
  end
  def test_rejects_arbitrary_color_values
    group("vip")
    assert_raises(Discourse::InvalidParameters) { C.assign!(@user, "url(javascript:alert(1))") }
  end
  def test_accepts_group_ids_and_handles_plugin_disabled
    group("vip_elegivel")
    SiteSetting.westan_vip_painel_premium_group = "20"
    assert P.premium?(@user)
    SiteSetting.westan_vip_painel_enabled = false
    assert_nil P.payload(@user)
    assert_nil C.selected(@user)
  end
  def test_url_validation
    ["http://example.org/a.png", "javascript:alert(1)", "https://user:pass@example.org/a.png", "not a URL"].each { |url| assert_equal "", P.media_url(url) }
    assert_equal "https://example.org/a.png", P.media_url("https://example.org/a.png")
  end
end
