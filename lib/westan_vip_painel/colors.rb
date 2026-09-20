# frozen_string_literal: true

module WestanVipPainel
  module Colors
    def self.field_id
      if SiteSetting.respond_to?(:vip_color_field_id)
        SiteSetting.vip_color_field_id
      else
        SiteSetting.westan_vip_painel_color_field_id
      end
    end

    def self.normalize(value)
      value.to_s.strip.downcase
    end

    def self.member?(user)
      return false unless user && SiteSetting.westan_vip_painel_enabled
      if defined?(::WestanVipPainel::Preferences)
        ::WestanVipPainel::Preferences.can_use?(user)
      else
        user.groups.any? { |group| group.name.downcase == "vip" }
      end
    end

    def self.selected(user)
      return nil unless member?(user)
      raw = user.custom_fields["user_field_#{field_id}"]
      return normalize(raw) unless raw.nil?
      legacy = legacy_style(user)
      legacy ? "legacy-#{user.custom_fields['westan_vip_nickname_style_id']}" : nil
    end

    def self.legacy_style(user)
      id = user.custom_fields["westan_vip_nickname_style_id"]
      return nil if id.blank?
      styles = JSON.parse(SiteSetting.westan_vip_painel_nickname_styles_json.to_s)
      style = styles.is_a?(Array) ? styles.find { |item| item["id"] == id } : nil
      return nil unless style && [style["from"], style["to"]].all? { |color| color.to_s.match?(/\A#[0-9a-fA-F]{6}\z/) }
      { value: "legacy-#{id}", name: style["name"], from: style["from"], to: style["to"] }
    rescue JSON::ParserError
      nil
    end

    def self.palette(include_disabled: false)
      raw = JSON.parse(SiteSetting.westan_vip_painel_colors_json.to_s)
      return [] unless raw.is_a?(Array)
      raw.filter_map do |item|
        next unless item.is_a?(Hash) && (include_disabled || item["enabled"] != false)
        value = normalize(item["value"])
        from = item["from"].to_s
        to = item["to"].presence || from
        next if value.empty? || !from.match?(/\A#[0-9a-fA-F]{6}\z/) || !to.match?(/\A#[0-9a-fA-F]{6}\z/)
        { value: value, name: item["name"].presence || value, from: from, to: to, enabled: item["enabled"] != false }
      end.uniq { |item| item[:value] }
    rescue JSON::ParserError
      []
    end

    def self.options(user = nil)
      result = palette
      legacy = user && legacy_style(user)
      result << legacy if legacy && selected(user) == legacy[:value]
      field = UserField.find_by(id: field_id)
      values = field ? field.user_field_options.order(:id).pluck(:value) : []
      values << selected(user) if user
      values.compact.each do |value|
        next if result.any? { |item| item[:value] == normalize(value) }
        result << { value: normalize(value), name: value.to_s, from: nil, to: nil }
      end
      result
    end

    def self.style(user)
      value = selected(user)
      palette.find { |item| item[:value] == value } ||
        (value.to_s.start_with?("legacy-") ? legacy_style(user) : nil)
    end

    def self.assign!(user, value)
      raise Discourse::InvalidAccess unless member?(user)
      normalized = normalize(value)
      unless normalized.empty? || options(user).any? { |option| option[:value] == normalized }
        raise Discourse::InvalidParameters.new(:nickname_color)
      end
      user.custom_fields["user_field_#{field_id}"] = normalized
    end
  end
end
