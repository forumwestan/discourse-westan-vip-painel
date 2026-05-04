# frozen_string_literal: true

module WestanVipPainel
  class PainelController < ::ApplicationController
    requires_plugin WestanVipPainel::PLUGIN_NAME

    before_action :ensure_logged_in, only: [:show, :update]
    before_action :ensure_vip_member, only: [:update]
    before_action :ensure_staff, only: [:admin_catalog, :admin_update_catalog]

    def show
      can_use = vip_member?(current_user)
      render json: {
        can_use: can_use,
        user: current_user_payload,
        themes: enabled_themes,
        nickname_styles: enabled_nickname_styles,
        selection: user_selection(current_user),
        primary_group_name: primary_group_name(current_user)
      }
    end

    def update
      themes = enabled_themes
      nickname_styles = enabled_nickname_styles
      theme = themes.find { |item| item["id"] == params[:theme_id].to_s } || themes.first
      nickname_style =
        nickname_styles.find { |item| item["id"] == params[:nickname_style_id].to_s } ||
        nickname_styles.first

      fields = WestanVipPainel::CUSTOM_FIELDS
      current_user.custom_fields[fields[:theme_id]] = theme&.dig("id").to_s
      current_user.custom_fields[fields[:nickname_style_id]] = nickname_style&.dig("id").to_s
      current_user.custom_fields[fields[:nickname_color]] = nickname_style&.dig("from").to_s
      current_user.custom_fields[fields[:badge_enabled]] = truthy_param?(params[:badge_enabled]) ? "true" : "false"
      current_user.custom_fields[fields[:custom_card_enabled]] = truthy_param?(params[:custom_card_enabled]) ? "true" : "false"
      current_user.custom_fields[fields[:custom_title]] = params[:custom_title].to_s.strip.first(40)
      current_user.save_custom_fields

      render json: {
        success: true,
        selection: user_selection(current_user)
      }
    end

    def post_users
      ids = params[:ids].to_s.split(",").map(&:to_i).select(&:positive?).uniq.first(80)
      usernames = params[:usernames].to_s.split(",").map(&:strip).reject(&:blank?).uniq.first(80)
      users = User
        .where("id IN (:ids) OR username_lower IN (:usernames)", ids: ids.presence || [0], usernames: usernames.map(&:downcase).presence || [""])
        .includes(:groups)
        .to_a

      render json: {
        users: users.each_with_object({}) do |user, hash|
          next unless vip_member?(user)

          hash[user.id] = post_user_payload(user)
        end,
        users_by_username: users.each_with_object({}) do |user, hash|
          next unless vip_member?(user)

          hash[user.username] = post_user_payload(user)
        end
      }
    end

    def admin_catalog
      render json: {
        themes: normalize_theme_catalog,
        nickname_styles: normalize_nickname_catalog
      }
    end

    def admin_update_catalog
      themes = params[:themes]
      themes = themes.values if themes.is_a?(ActionController::Parameters) || themes.is_a?(Hash)
      nickname_styles = params[:nickname_styles]
      nickname_styles = nickname_styles.values if nickname_styles.is_a?(ActionController::Parameters) || nickname_styles.is_a?(Hash)

      raise Discourse::InvalidParameters.new(:themes) unless themes.is_a?(Array)
      raise Discourse::InvalidParameters.new(:nickname_styles) unless nickname_styles.is_a?(Array)

      normalized_themes = normalize_theme_payload(themes)
      normalized_styles = normalize_nickname_payload(nickname_styles)

      SiteSetting.westan_vip_painel_themes_json = JSON.generate(normalized_themes)
      SiteSetting.westan_vip_painel_nickname_styles_json = JSON.generate(normalized_styles)

      @enabled_themes = nil
      @enabled_nickname_styles = nil

      render json: {
        success: true,
        themes: normalize_theme_catalog,
        nickname_styles: normalize_nickname_catalog
      }
    end

    private

    def ensure_staff
      raise Discourse::InvalidAccess unless current_user&.staff?
    end

    def ensure_vip_member
      raise Discourse::InvalidAccess unless vip_member?(current_user)
    end

    def vip_member?(user)
      return false unless user

      group_name = SiteSetting.westan_vip_painel_group.to_s.downcase
      user.groups.any? { |group| group.name.to_s.downcase == group_name }
    end

    def current_user_payload
      {
        id: current_user.id,
        username: current_user.username,
        name: current_user.name.presence || current_user.username,
        avatar_url: current_user.avatar_template&.gsub("{size}", "128")
      }
    end

    def post_user_payload(user)
      selection = user_selection(user)
      {
        id: user.id,
        username: user.username,
        custom_title: selection[:custom_title],
        primary_group_name: primary_group_name(user),
        badge_enabled: selection[:badge_enabled],
        custom_card_enabled: selection[:custom_card_enabled],
        nickname_style: nickname_styles_by_id[selection[:nickname_style_id]],
        theme: themes_by_id[selection[:theme_id]]
      }
    end

    def user_selection(user)
      fields = WestanVipPainel::CUSTOM_FIELDS
      default_theme = enabled_themes.first
      default_style = enabled_nickname_styles.first

      {
        theme_id: user.custom_fields[fields[:theme_id]].presence || default_theme&.dig("id").to_s,
        nickname_style_id: user.custom_fields[fields[:nickname_style_id]].presence || default_style&.dig("id").to_s,
        nickname_color: user.custom_fields[fields[:nickname_color]].presence || default_style&.dig("from").to_s,
        badge_enabled: user.custom_fields[fields[:badge_enabled]] != "false",
        custom_card_enabled: user.custom_fields[fields[:custom_card_enabled]] != "false",
        custom_title: user.custom_fields[fields[:custom_title]].to_s
      }
    end

    def primary_group_name(user)
      user.primary_group&.name.presence || SiteSetting.westan_vip_painel_group.to_s
    end

    def enabled_themes
      @enabled_themes ||= normalize_theme_catalog.select { |theme| theme["enabled"] != false }
    end

    def enabled_nickname_styles
      @enabled_nickname_styles ||= normalize_nickname_catalog.select { |style| style["enabled"] != false }
    end

    def themes_by_id
      @themes_by_id ||= enabled_themes.index_by { |theme| theme["id"] }
    end

    def nickname_styles_by_id
      @nickname_styles_by_id ||= enabled_nickname_styles.index_by { |style| style["id"] }
    end

    def normalize_theme_catalog
      parse_json_array(SiteSetting.westan_vip_painel_themes_json).map.with_index do |theme, index|
        {
          "id" => theme["id"].presence || "theme-#{index + 1}",
          "name" => theme["name"].presence || "Tema #{index + 1}",
          "enabled" => theme.key?("enabled") ? theme["enabled"] : true,
          "badgeText" => theme["badgeText"].presence || "VIP",
          "logoUrl" => theme["logoUrl"].to_s,
          "badgeBackgroundUrl" => theme["badgeBackgroundUrl"].to_s,
          "badgeBackgroundIsVideo" => video_url?(theme["badgeBackgroundUrl"].to_s),
          "nicknameFrom" => color_or(theme["nicknameFrom"], "#9333EA"),
          "nicknameTo" => color_or(theme["nicknameTo"], "#EC4899"),
          "borderFrom" => color_or(theme["borderFrom"], "#C084FC"),
          "borderTo" => color_or(theme["borderTo"], "#EC4899"),
          "surfaceFrom" => color_or(theme["surfaceFrom"], "#F3E8FF"),
          "surfaceTo" => color_or(theme["surfaceTo"], "#FDF2F8"),
          "cardFilterColor" => theme["cardFilterColor"].presence || "#fff1ffcc"
        }
      end
    end

    def normalize_nickname_catalog
      parse_json_array(SiteSetting.westan_vip_painel_nickname_styles_json).map.with_index do |style, index|
        {
          "id" => style["id"].presence || "style-#{index + 1}",
          "name" => style["name"].presence || "Estilo #{index + 1}",
          "enabled" => style.key?("enabled") ? style["enabled"] : true,
          "from" => color_or(style["from"], "#9333EA"),
          "to" => color_or(style["to"], "#EC4899")
        }
      end
    end

    def normalize_theme_payload(themes)
      themes.map.with_index do |raw, index|
        theme = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
        {
          "id" => theme["id"].presence || "theme-#{index + 1}",
          "name" => theme["name"].presence || "Tema #{index + 1}",
          "enabled" => truthy_param?(theme["enabled"]),
          "badgeText" => theme["badgeText"].presence || "VIP",
          "logoUrl" => theme["logoUrl"].to_s,
          "badgeBackgroundUrl" => theme["badgeBackgroundUrl"].to_s,
          "nicknameFrom" => color_or(theme["nicknameFrom"], "#9333EA"),
          "nicknameTo" => color_or(theme["nicknameTo"], "#EC4899"),
          "borderFrom" => color_or(theme["borderFrom"], "#C084FC"),
          "borderTo" => color_or(theme["borderTo"], "#EC4899"),
          "surfaceFrom" => color_or(theme["surfaceFrom"], "#F3E8FF"),
          "surfaceTo" => color_or(theme["surfaceTo"], "#FDF2F8"),
          "cardFilterColor" => theme["cardFilterColor"].presence || "#fff1ffcc"
        }
      end
    end

    def normalize_nickname_payload(styles)
      styles.map.with_index do |raw, index|
        style = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
        {
          "id" => style["id"].presence || "style-#{index + 1}",
          "name" => style["name"].presence || "Estilo #{index + 1}",
          "enabled" => truthy_param?(style["enabled"]),
          "from" => color_or(style["from"], "#9333EA"),
          "to" => color_or(style["to"], "#EC4899")
        }
      end
    end

    def parse_json_array(raw)
      parsed = JSON.parse(raw.to_s)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end

    def color_or(value, fallback)
      value = value.to_s.strip
      value.match?(/\A#[0-9a-fA-F]{3,8}\z/) ? value : fallback
    end

    def truthy_param?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def video_url?(url)
      url.match?(/\.(mp4|webm|ogg)(\?|#|\z)/i)
    end
  end
end
