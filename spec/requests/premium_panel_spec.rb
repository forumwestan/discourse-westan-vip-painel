# frozen_string_literal: true

require "rails_helper"

RSpec.describe WestanVipPainel::PainelController do
  fab!(:user)
  fab!(:vip) { Fabricate(:group, name: "vip") }
  fab!(:premium) { Fabricate(:group, name: "vip_elegivel") }

  before do
    SiteSetting.westan_vip_painel_enabled = true
    SiteSetting.westan_vip_painel_group = vip.name
    SiteSetting.westan_vip_painel_premium_group = premium.name
    field = UserField.create!(name: "Cor VIP", description: "Cor do nickname", field_type: "dropdown", editable: true)
    field.user_field_options.create!(value: "dourado")
    SiteSetting.westan_vip_painel_color_field_id = field.id
    SiteSetting.vip_color_field_id = field.id if SiteSetting.respond_to?(:vip_color_field_id)
    sign_in(user)
  end

  it "blocks a member without active access" do
    patch "/westan/vip-painel.json", params: { nickname_color: "dourado" }
    expect(response.status).to eq(403)
  end

  it "shows only color controls and refuses all premium writes for redeemed VIP" do
    vip.add(user)
    get "/westan/vip-painel.json"
    expect(response.parsed_body).to include("can_use" => true, "is_premium" => false, "themes" => [])
    %i[theme_id verified_enabled badge_enabled custom_card_enabled custom_title custom_logo_url custom_background_url].each do |key|
      patch "/westan/vip-painel.json", params: { key => "true" }
      expect(response.status).to eq(403)
    end
  end

  it "stores colors in the same field used by vip-westan" do
    vip.add(user)
    patch "/westan/vip-painel.json", params: { nickname_color: "dourado" }
    expect(response.status).to eq(200)
    expect(user.reload.custom_fields["user_field_#{WestanVipPainel::Colors.field_id}"]).to eq("dourado")
    expect(response.parsed_body["decoration"]).to include("verified" => false, "theme" => nil, "custom_title" => "")
  end

  it "allows paid Premium without requiring duplicate group membership" do
    premium.add(user)
    patch "/westan/vip-painel.json", params: { verified_enabled: false, custom_title: "Meu título" }
    expect(response.status).to eq(200)
    expect(response.parsed_body["decoration"]).to include("verified" => false, "custom_title" => "Meu título")
  end

  it "does not expose or accept palette-only colors" do
    vip.add(user)
    SiteSetting.westan_vip_painel_colors_json = '[{"value":"inventada","from":"#123456","to":"#654321"}]'
    get "/westan/vip-painel.json"
    expect(response.parsed_body["colors"].map { |color| color["value"] }).to eq(["dourado"])
    patch "/westan/vip-painel.json", params: { nickname_color: "inventada" }
    expect(response.status).to eq(400)
  end

  it "does not save either image if custom badge validation fails" do
    premium.add(user)
    allow(WestanVipPainel::BadgeImage).to receive(:validate!).with("https://example.org/logo.png", kind: :logo).and_return("https://example.org/logo.png")
    allow(WestanVipPainel::BadgeImage).to receive(:validate!).with("https://example.org/bg.png", kind: :background).and_raise(WestanVipPainel::BadgeImage::Invalid, "Dimensões inválidas")
    patch "/westan/vip-painel.json", params: { theme_id: "custom", custom_logo_url: "https://example.org/logo.png", custom_background_url: "https://example.org/bg.png" }
    expect(response.status).to eq(422)
    expect(user.reload.custom_fields["westan_vip_custom_logo_url"]).to be_nil
  end

  it "requires staff for catalog changes" do
    premium.add(user)
    patch "/westan/vip-painel/admin/catalog.json", params: { themes: [] }
    expect(response.status).to eq(403)
  end

  it "accepts a background-only badge and clears an old logo" do
    premium.add(user)
    user.custom_fields["westan_vip_custom_logo_url"] = "https://example.org/old.png"
    user.save_custom_fields
    expect(WestanVipPainel::BadgeImage).not_to receive(:validate!).with(anything, kind: :logo)
    allow(WestanVipPainel::BadgeImage).to receive(:validate!).with("https://example.org/bg.png", kind: :background).and_return("https://example.org/bg.png")
    patch "/westan/vip-painel.json", params: { theme_id: "custom", custom_logo_url: "", custom_background_url: "https://example.org/bg.png" }
    expect(response.status).to eq(200)
    expect(response.parsed_body["decoration"]["theme"]).to include("id" => "custom", "logoUrl" => "", "badgeBackgroundUrl" => "https://example.org/bg.png")
    expect(user.reload.custom_fields["westan_vip_custom_logo_url"].to_s).to eq("")
  end
end
