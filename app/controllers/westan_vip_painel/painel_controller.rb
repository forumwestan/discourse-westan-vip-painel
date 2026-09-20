# frozen_string_literal: true

module WestanVipPainel
  class PainelController < ::ApplicationController
    requires_plugin WestanVipPainel::PLUGIN_NAME
    before_action :ensure_logged_in, only: %i[show update]
    before_action :expire_reward_access, only: %i[show update]
    before_action :ensure_staff, only: %i[admin_catalog admin_update_catalog]

    def show
      premium = Preferences.premium?(current_user)
      render json: {
        can_use: Preferences.can_use?(current_user), is_premium: premium,
        user: { id: current_user.id, username: current_user.username,
                name: current_user.name.presence || current_user.username,
                avatar_url: current_user.avatar_template&.gsub("{size}", "128") },
        themes: premium ? Preferences.themes : [],
        colors: Colors.options(current_user), selection: Preferences.selection(current_user)
      }
    end

    def update
      raise Discourse::InvalidAccess unless Preferences.can_use?(current_user)
      premium_fields = %i[theme_id verified_enabled badge_enabled custom_card_enabled custom_title custom_logo_url custom_background_url]
      if !Preferences.premium?(current_user) && premium_fields.any? { |key| params.key?(key) }
        raise Discourse::InvalidAccess
      end

      fields = CUSTOM_FIELDS
      changes = {}
      if params.key?(:theme_id)
        theme_id = params[:theme_id].to_s
        valid = %w[none custom] + Preferences.themes.map { |theme| theme["id"] }
        raise Discourse::InvalidParameters.new(:theme_id) unless valid.include?(theme_id)
        changes[fields[:theme_id]] = theme_id
        changes[fields[:badge_enabled]] = theme_id == "none" ? "false" : "true"
      end
      if params[:theme_id] == "custom"
        RateLimiter.new(current_user, "westan-premium-badge", 5, 1.minute).performed!
        logo = params[:custom_logo_url].to_s.strip
        changes[fields[:custom_logo_url]] = logo.blank? ? "" : BadgeImage.validate!(logo, kind: :logo)
        changes[fields[:custom_background_url]] = BadgeImage.validate!(params[:custom_background_url], kind: :background)
      end
      %i[verified_enabled custom_card_enabled].each do |key|
        next unless params.key?(key)
        changes[fields[key]] = ActiveModel::Type::Boolean.new.cast(params[key]) ? "true" : "false"
      end
      changes[fields[:custom_title]] = params[:custom_title].to_s.strip.first(40) if params.key?(:custom_title)

      current_user.with_lock do
        Colors.assign!(current_user, params[:nickname_color]) if params.key?(:nickname_color)
        changes.each { |key, value| current_user.custom_fields[key] = value }
        current_user.save_custom_fields
      end
      render json: { success: true, selection: Preferences.selection(current_user), decoration: Preferences.payload(current_user) }
    rescue BadgeImage::Invalid => error
      render json: { errors: [error.message] }, status: :unprocessable_entity
    end

    def post_users
      ids = params[:ids].to_s.split(",").map(&:to_i).select(&:positive?).uniq.first(80)
      names = params[:usernames].to_s.split(",").map { |name| name.strip.downcase }.reject(&:blank?).uniq.first(80)
      users = User.where("id IN (:ids) OR username_lower IN (:names)", ids: ids.presence || [0], names: names.presence || [""])
        .includes(:groups).to_a
      payloads = users.map do |user|
        Preferences.payload(user) || { id: user.id, username: user.username, name: user.name.presence || user.username,
                                      verified: false, badge_enabled: false, theme: nil, custom_title: "", nickname_style: nil }
      end
      render json: { users: payloads.index_by { |data| data[:id] }, users_by_username: payloads.index_by { |data| data[:username] } }
    end

    def admin_catalog
      render json: { themes: raw_themes, colors: Colors.palette(include_disabled: true) }
    end

    def admin_update_catalog
      normalized_themes = array_param(:themes).map.with_index do |raw, index|
        item = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
        id = item["id"].to_s.strip.presence || "theme-#{index + 1}"
        raise Discourse::InvalidParameters.new(:themes) if %w[none custom].include?(id)
        item.slice("id", "name", "badgeText", "borderFrom", "borderTo", "surfaceFrom", "surfaceTo", "cardFilterColor").merge(
          "id" => id, "name" => item["name"].to_s.first(80),
          "enabled" => ActiveModel::Type::Boolean.new.cast(item["enabled"]),
          "logoUrl" => Preferences.media_url(item["logoUrl"]),
          "badgeBackgroundUrl" => Preferences.media_url(item["badgeBackgroundUrl"])
        )
      end
      normalized_colors = array_param(:colors).map do |raw|
        item = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
        value = Colors.normalize(item["value"])
        from, to = item.values_at("from", "to")
        unless value.present? && [from, to].all? { |color| color.to_s.match?(/\A#[0-9a-fA-F]{6}\z/) }
          raise Discourse::InvalidParameters.new(:colors)
        end
        { value: value, name: item["name"].to_s.first(80), from: from, to: to,
          enabled: ActiveModel::Type::Boolean.new.cast(item.fetch("enabled", true)) }
      end
      SiteSetting.westan_vip_painel_themes_json = JSON.generate(normalized_themes)
      SiteSetting.westan_vip_painel_colors_json = JSON.generate(normalized_colors)
      render json: { success: true, themes: normalized_themes, colors: Colors.palette(include_disabled: true) }
    end

    private

    def ensure_staff
      raise Discourse::InvalidAccess unless current_user&.staff?
    end

    def expire_reward_access
      if defined?(::WestanPoints::VipAccessService)
        ::WestanPoints::VipAccessService.expire_for_user!(user: current_user)
      end
    end

    def raw_themes
      JSON.parse(SiteSetting.westan_vip_painel_themes_json.to_s)
    rescue JSON::ParserError
      []
    end

    def array_param(key)
      value = params[key]
      value = value.values if value.is_a?(ActionController::Parameters) || value.is_a?(Hash)
      value = [] if value.nil?
      raise Discourse::InvalidParameters.new(key) unless value.is_a?(Array)
      value.first(100)
    end
  end
end
