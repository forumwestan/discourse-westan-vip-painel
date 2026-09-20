import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import dIcon from "discourse/helpers/d-icon";

// Fallbacks mirror the existing VIP theme; its --vip-grad remains authoritative.
const VIP_GRADIENTS = {
  bluegray: "#1985a1,#a9bcd0,#ccdbdc", hotcamp: "#f15bb5,#a7c957,#52ffee",
  purpleglow: "#cfbaf0,#9d4edd,#8338ec", areia: "#bc8a5f,#f3d5b5,#f4d58d",
  esmerald: "#9CDA95,#36D9B9,#DFFFDB", gold: "#ffca3a,#fffd82,#db7c26",
  pink: "#ff0054,#e77a87,#f47043", red: "#c1121f,#880d1e,#dc2f02",
  rose: "#e4b1ab,#ffd6e0,#e39695", orangepowerfurl: "#f15f23,#f8ad9d,#e36414",
  blark: "#0466c8,#001233,#979dac",
};

function mediaUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password ? url.href : "";
  } catch { return ""; }
}

export default class WestanVipPainel extends Component {
  @tracked section = this.args.model.is_premium ? "badges" : "appearance";
  @tracked themeId = this.args.model.selection?.theme_id || "none";
  @tracked nicknameColor = this.args.model.selection?.nickname_color || "";
  @tracked colorChanged = false;
  @tracked verifiedEnabled = this.args.model.selection?.verified_enabled ?? true;
  @tracked customTitle = this.args.model.selection?.custom_title || "";
  @tracked logoUrl = this.args.model.selection?.custom_logo_url || "";
  @tracked backgroundUrl = this.args.model.selection?.custom_background_url || "";
  @tracked saving = false;
  @tracked feedback = "";
  @tracked savedSelection = this.args.model.selection;

  get canUse() { return this.args.model.can_use; }
  get isPremium() { return this.args.model.is_premium; }
  get pageTitle() { return this.isPremium ? "Ajustes do Premium" : "Ajuste do VIP"; }
  get isBadges() { return this.section === "badges"; }
  get isCustom() { return this.section === "custom"; }
  get isAppearance() { return this.section === "appearance"; }
  get userName() { return this.args.model.user?.name || this.args.model.user?.username; }
  get avatarUrl() { return this.args.model.user?.avatar_url; }
  get showVerified() { return this.isPremium && this.verifiedEnabled; }
  get showTitle() { return this.isPremium && this.customTitle.trim(); }
  get previewLogo() { return mediaUrl(this.logoUrl); }
  get previewBackground() { return mediaUrl(this.backgroundUrl); }
  get saveLabel() { return this.saving ? "Salvando…" : this.isCustom ? "Criar e enviar" : "Salvar ajustes"; }
  get badgeRows() {
    const own = this.savedSelection;
    const custom = own?.custom_background_url ? [{ id: "custom", name: "Meu badge", logoUrl: own.custom_logo_url, badgeBackgroundUrl: own.custom_background_url }] : [];
    return [{ id: "none", name: "Nenhum: Padrão", badgeText: "", logoUrl: "", badgeBackgroundUrl: "" }, ...(this.args.model.themes || []), ...custom]
      .map(theme => ({ ...theme, selected: theme.id === this.themeId }));
  }
  get colorRows() {
    const rows = [{ value: "", name: "Padrão", from: null, to: null }, ...(this.args.model.colors || [])]
      .map(color => ({ ...color, selected: color.value === this.nicknameColor }));
    if (this.currentColorUnavailable) {
      rows.unshift({ value: "", name: "Selecione uma cor existente", selected: true, disabled: true });
    }
    return rows;
  }
  get currentColorUnavailable() {
    return Boolean(this.nicknameColor && !(this.args.model.colors || []).some(color => color.value === this.nicknameColor));
  }
  get nicknameStyle() {
    const original = VIP_GRADIENTS[this.nicknameColor];
    if (original) {
      return htmlSafe(`background-image:var(--vip-grad,linear-gradient(90deg,${original}));background-clip:text;-webkit-background-clip:text;color:transparent;-webkit-text-fill-color:transparent;`);
    }
    const color = this.colorRows.find(item => item.selected);
    if (!color?.from || !color?.to || ![color.from, color.to].every(value => /^#[0-9a-f]{6}$/i.test(value))) {
      return htmlSafe("");
    }
    return htmlSafe(`background-image:linear-gradient(120deg,${color.from},${color.to});background-clip:text;-webkit-background-clip:text;color:transparent;`);
  }
  get nicknameClass() {
    const token = this.nicknameColor.toLowerCase().replace(/[^a-z0-9-]/g, "");
    // The original theme spells the orange selector "oragenpowerfurl".
    return `premium-preview-nickname${token ? ` vip-color-${token}` : ""}${token === "orangepowerfurl" ? " vip-color-oragenpowerfurl" : ""}`;
  }
  get selectedLegacyColor() {
    return this.nicknameColor && !VIP_GRADIENTS[this.nicknameColor] && !this.colorRows.find(item => item.selected)?.from;
  }

  @action selectSection(event) { this.section = event.currentTarget.dataset.section; this.feedback = ""; }
  @action selectTheme(event) { this.themeId = event.currentTarget.dataset.themeId; this.feedback = ""; }
  @action updateColor(event) { this.nicknameColor = event.target.value; this.colorChanged = true; this.feedback = ""; }
  @action updateVerified(event) { this.verifiedEnabled = event.target.value === "true"; this.feedback = ""; }
  @action updateTitle(event) { this.customTitle = event.target.value; this.feedback = ""; }
  @action updateLogo(event) { this.logoUrl = event.target.value; this.feedback = ""; }
  @action updateBackground(event) { this.backgroundUrl = event.target.value; this.feedback = ""; }

  @action async save(event) {
    event.preventDefault();
    if (this.saving) { return; }
    let data;
    if (this.isAppearance) {
      data = {};
      if (this.colorChanged || !this.currentColorUnavailable) { data.nickname_color = this.nicknameColor; }
      if (this.isPremium) { data = { ...data, verified_enabled: this.verifiedEnabled, custom_title: this.customTitle }; }
    } else if (this.isCustom) {
      data = { theme_id: "custom", custom_logo_url: this.logoUrl, custom_background_url: this.backgroundUrl };
    } else {
      data = { theme_id: this.themeId };
      if (this.themeId === "custom") { data = { ...data, custom_logo_url: this.logoUrl, custom_background_url: this.backgroundUrl }; }
    }
    this.saving = true;
    this.feedback = "";
    try {
      const result = await ajax("/westan/vip-painel", { type: "PATCH", data });
      this.themeId = result.selection.theme_id;
      this.savedSelection = result.selection;
      this.feedback = "Ajustes salvos.";
      window.dispatchEvent(new CustomEvent("westan-premium-updated", { detail: result.decoration }));
    } catch (error) { popupAjaxError(error); }
    finally { this.saving = false; }
  }

  <template>
    <main class="westan-premium">
      {{#if this.canUse}}
        <h1>{{this.pageTitle}}</h1>
        {{#if this.isPremium}}
          <nav class="westan-premium-tabs" aria-label="Ajustes do Premium">
            <button type="button" aria-pressed={{if this.isBadges "true" "false"}} data-section="badges" {{on "click" this.selectSection}}>Badges disponíveis</button>
            <button type="button" aria-pressed={{if this.isCustom "true" "false"}} data-section="custom" {{on "click" this.selectSection}}>Criar o meu badge</button>
            <button type="button" aria-pressed={{if this.isAppearance "true" "false"}} data-section="appearance" {{on "click" this.selectSection}}>Cor e selo verificado</button>
          </nav>
        {{/if}}

        <form {{on "submit" this.save}}>
          <fieldset disabled={{this.saving}}>
            {{#if this.isBadges}}
              <div class="westan-premium-badges">
                {{#each this.badgeRows as |badge|}}
                  <button type="button" class="westan-premium-badge-option" aria-pressed={{if badge.selected "true" "false"}} data-theme-id={{badge.id}} {{on "click" this.selectTheme}}>
                    <span class="westan-premium-badge-art">
                      {{#if badge.badgeBackgroundUrl}}
                        {{#if badge.badgeBackgroundIsVideo}}<video class="premium-badge-bg" src={{badge.badgeBackgroundUrl}} autoplay loop muted playsinline></video>
                        {{else}}<img class="premium-badge-bg" src={{badge.badgeBackgroundUrl}} alt="" />{{/if}}
                      {{/if}}
                      {{#if badge.logoUrl}}<img class="premium-badge-logo" src={{badge.logoUrl}} alt="" />{{else}}<b>{{badge.badgeText}}</b>{{/if}}
                      {{#if badge.selected}}<span class="premium-badge-check">{{dIcon "check"}}</span>{{/if}}
                    </span>
                    <span>{{badge.name}}</span>
                  </button>
                {{/each}}
              </div>
            {{else}}
              <div class="westan-premium-editor">
                <div class="westan-premium-fields">
                  {{#if this.isCustom}}
                    <label for="premium-logo">URL do Logo (opcional)</label>
                    <p>Formatos aceitos: PNG e WEBP<br />Dimensões mínimas: 230×90px</p>
                    <input id="premium-logo" type="url" placeholder="Cole aqui (opcional)" value={{this.logoUrl}} {{on "input" this.updateLogo}} />
                    <label for="premium-background">URL do Background</label>
                    <p>Formatos aceitos: PNG, JPG ou GIF<br />Dimensões mínimas: 455×120px</p>
                    <input id="premium-background" type="url" required placeholder="Cole aqui" value={{this.backgroundUrl}} {{on "input" this.updateBackground}} />
                    <small>Até 5 MB por imagem. Use links HTTPS.</small>
                  {{else}}
                    {{#if this.isPremium}}<h2>Cor e selo verificado</h2>{{/if}}
                    <label for="premium-color">{{if this.isPremium "Escolha a cor do seu VIP" "Escolha a cor do seu nome de usuário"}}</label>
                    <select id="premium-color" {{on "change" this.updateColor}}>
                      {{#each this.colorRows as |color|}}<option value={{color.value}} selected={{color.selected}} disabled={{color.disabled}}>{{color.name}}</option>{{/each}}
                    </select>
                    {{#if this.currentColorUnavailable}}
                      <small>A cor salva não está mais entre as opções do VIP. Ela será mantida até você escolher outra cor ou Padrão.</small>
                    {{else}}
                      {{#if this.selectedLegacyColor}}<small>Sua cor existente está preservada. A prévia depende do estilo configurado no tema.</small>{{/if}}
                    {{/if}}
                    {{#if this.isPremium}}
                      <label for="premium-verified">Ativar selo verificado no perfil?</label>
                      <select id="premium-verified" {{on "change" this.updateVerified}}><option value="true" selected={{this.verifiedEnabled}}>Sim</option><option value="false" selected={{if this.verifiedEnabled false true}}>Não</option></select>
                      <label for="premium-title">Personalizar título do perfil</label>
                      <input id="premium-title" maxlength="40" placeholder="Insira aqui" value={{this.customTitle}} {{on "input" this.updateTitle}} />
                      <small>Deixe vazio para não exibir.</small>
                    {{/if}}
                  {{/if}}
                </div>
                <aside class="westan-premium-preview">
                  <h2>Pré-visualização</h2>
                  {{#if this.isCustom}}
                    <div class="westan-premium-badge-art">
                      {{#if this.previewBackground}}<img class="premium-badge-bg" src={{this.previewBackground}} alt="" />{{/if}}
                      {{#if this.previewLogo}}<img class="premium-badge-logo" src={{this.previewLogo}} alt="" />{{/if}}
                      <span class="premium-badge-check">{{dIcon "check"}}</span>
                    </div>
                    <p>Meu badge</p>
                  {{else}}
                    <div class="westan-premium-user-preview">
                      <img class="premium-avatar" src={{this.avatarUrl}} alt="" />
                      <div>
                        <div class="premium-preview-name"><a class={{this.nicknameClass}} style={{this.nicknameStyle}}>{{this.userName}}</a>{{#if this.showVerified}}<span class="premium-preview-seal" title="Membro Premium Verificado" role="img" aria-label="Membro Premium Verificado"><svg viewBox="0 0 24 24" aria-hidden="true"><defs><linearGradient id="premium-preview-gold" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#fff1a0"/><stop offset=".5" stop-color="#edb80d"/><stop offset="1" stop-color="#bd7300"/></linearGradient></defs><path fill="url(#premium-preview-gold)" d="M12 1 15 4 19.5 3.5 20 8 23 12 20 16 19.5 20.5 15 20 12 23 9 20 4.5 20.5 4 16 1 12 4 8 4.5 3.5 9 4Z"/><path d="m7 12 3 3 7-7" fill="none" stroke="white" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg></span>{{/if}}</div>
                        {{#if this.showTitle}}<p>{{this.customTitle}}</p>{{/if}}
                      </div>
                    </div>
                  {{/if}}
                </aside>
              </div>
            {{/if}}
            <button class="westan-premium-save" type="submit" disabled={{this.saving}}>{{this.saveLabel}}</button>
          </fieldset>
        </form>
        {{#if this.feedback}}<p class="westan-premium-feedback" role="status">{{this.feedback}}</p>{{/if}}
      {{else}}
        <h1>Ajustes do Premium</h1><p>Esta área está disponível para assinantes Premium e membros com VIP ativo.</p>
      {{/if}}
    </main>
  </template>
}
