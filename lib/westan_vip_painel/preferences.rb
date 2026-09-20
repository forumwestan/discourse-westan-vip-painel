# frozen_string_literal: true

require "uri"

module WestanVipPainel
  module Preferences
    def self.in_group?(user, setting)
      return false unless user
      value = setting.to_s.strip.delete_prefix("@").downcase
      user.groups.any? { |group| value == group.name.downcase || value == group.id.to_s }
    end

    def self.premium?(user)
      SiteSetting.westan_vip_painel_enabled && in_group?(user, SiteSetting.westan_vip_painel_premium_group)
    end

    def self.can_use?(user)
      SiteSetting.westan_vip_painel_enabled && (premium?(user) || in_group?(user, SiteSetting.westan_vip_painel_group))
    end

    def self.colors_available?
      SiteSetting.westan_vip_painel_enabled
    end

    def self.media_url(value)
      value = value.to_s.strip
      return "" if value.empty? || value.length > 2_000
      uri = URI.parse(value)
      uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? ? value : ""
    rescue URI::InvalidURIError
      ""
    end

    def self.color(value, fallback)
      value.to_s.match?(/\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\z/) ? value : fallback
    end

    def self.themes
      raw = JSON.parse(SiteSetting.westan_vip_painel_themes_json.to_s)
      return [] unless raw.is_a?(Array)
      raw.filter_map do |theme|
        next unless theme.is_a?(Hash) && theme["enabled"] != false
        next if theme["id"].to_s.blank? || %w[none custom].include?(theme["id"])
        theme.merge(
          "logoUrl" => media_url(theme["logoUrl"]),
          "badgeBackgroundUrl" => media_url(theme["badgeBackgroundUrl"]),
          "badgeBackgroundIsVideo" => theme["badgeBackgroundUrl"].to_s.match?(/\.(mp4|webm|ogg)(\?|#|\z)/i)
        )
      end
    rescue JSON::ParserError
      []
    end

    def self.selection(user)
      fields = CUSTOM_FIELDS
      premium = premium?(user)
      {
        theme_id: premium ? user.custom_fields[fields[:theme_id]].presence || "none" : "none",
        nickname_color: colors_available? ? Colors.selected(user).to_s : "",
        verified_enabled: premium && user.custom_fields[fields[:verified_enabled]] != "false",
        badge_enabled: premium && user.custom_fields[fields[:badge_enabled]] != "false",
        custom_card_enabled: premium && user.custom_fields[fields[:custom_card_enabled]] != "false",
        custom_title: premium ? user.custom_fields[fields[:custom_title]].to_s : "",
        custom_logo_url: premium ? media_url(user.custom_fields[fields[:custom_logo_url]]) : "",
        custom_background_url: premium ? media_url(user.custom_fields[fields[:custom_background_url]]) : ""
      }
    end

    def self.theme(user, selection)
      return nil unless premium?(user) && selection[:badge_enabled]
      if selection[:theme_id] == "custom"
        return nil if selection[:custom_background_url].blank?
        { "id" => "custom", "name" => "Meu badge", "logoUrl" => selection[:custom_logo_url],
          "badgeBackgroundUrl" => selection[:custom_background_url], "badgeBackgroundIsVideo" => false }
      else
        themes.find { |item| item["id"] == selection[:theme_id] }
      end
    end

    def self.payload(user)
      return nil unless can_use?(user)
      selected = selection(user)
      { id: user.id, username: user.username, name: user.name.presence || user.username,
        verified: selected[:verified_enabled], custom_title: selected[:custom_title],
        badge_enabled: selected[:badge_enabled], custom_card_enabled: selected[:custom_card_enabled],
        nickname_style: colors_available? ? Colors.style(user) : nil,
        nickname_color: selected[:nickname_color], theme: theme(user, selected) }
    end
  end
end
