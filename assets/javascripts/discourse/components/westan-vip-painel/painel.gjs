import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";
import dIcon from "discourse/helpers/d-icon";

function gradientStyle(from, to) {
  return htmlSafe(`--vip-nickname-from:${from};--vip-nickname-to:${to};background-image:linear-gradient(120deg, ${from}, ${to}, ${from});background-size:220% 220%;-webkit-background-clip:text;background-clip:text;color:transparent;`);
}

export default class WestanVipPainel extends Component {
  @service currentUser;

  @tracked themeId = this.args.model.selection?.theme_id || this.args.model.themes?.[0]?.id || "";
  @tracked nicknameStyleId = this.args.model.selection?.nickname_style_id || this.args.model.nickname_styles?.[0]?.id || "";
  @tracked badgeEnabled = this.args.model.selection?.badge_enabled ?? true;
  @tracked customCardEnabled = this.args.model.selection?.custom_card_enabled ?? true;
  @tracked customTitle = this.args.model.selection?.custom_title || "";
  @tracked isSaving = false;
  @tracked isSaved = false;

  get canUse() {
    return this.args.model.can_use;
  }

  get userName() {
    return this.args.model.user?.name || this.currentUser?.name || this.currentUser?.username || "Nugget";
  }

  get primaryGroupName() {
    return this.args.model.primary_group_name || "vip";
  }

  get previewTitle() {
    return this.customTitle.trim() || this.primaryGroupName;
  }

  get saveLabel() {
    if (this.isSaving) {
      return "Salvando...";
    }
    if (this.isSaved) {
      return "Tema salvo";
    }
    return "Salvar tema";
  }

  get themes() {
    return this.args.model.themes || [];
  }

  get nicknameStyles() {
    return this.args.model.nickname_styles || [];
  }

  get themeRows() {
    return this.themes.map((theme) => ({
      ...theme,
      is_selected: theme.id === this.themeId,
      text_style: gradientStyle(theme.nicknameFrom, theme.nicknameTo),
      card_style: htmlSafe(`--vip-surface-from:${theme.surfaceFrom};--vip-surface-to:${theme.surfaceTo};--vip-border-from:${theme.borderFrom};--vip-border-to:${theme.borderTo};`),
    }));
  }

  get nicknameRows() {
    return this.nicknameStyles.map((style) => ({
      ...style,
      is_selected: style.id === this.nicknameStyleId,
      text_style: gradientStyle(style.from, style.to),
      kind: style.from?.toLowerCase?.() === style.to?.toLowerCase?.() ? "Cor sólida" : "Degradê",
    }));
  }

  @action
  selectTheme(event) {
    this.themeId = event.currentTarget.dataset.themeId;
  }

  @action
  selectNicknameStyle(event) {
    this.nicknameStyleId = event.currentTarget.dataset.styleId;
  }

  @action
  toggleBadge(event) {
    event.stopPropagation();
    this.badgeEnabled = event.target.checked;
  }

  @action
  toggleCustomCard(event) {
    event.stopPropagation();
    this.customCardEnabled = event.target.checked;
  }

  @action
  updateTitle(event) {
    this.customTitle = event.target.value.slice(0, 40);
  }

  @action
  async save() {
    this.isSaving = true;
    await ajax("/westan/vip-painel", {
      type: "PATCH",
      data: {
        theme_id: this.themeId,
        nickname_style_id: this.nicknameStyleId,
        badge_enabled: this.badgeEnabled,
        custom_card_enabled: this.customCardEnabled,
        custom_title: this.customTitle,
      },
    });
    this.isSaving = false;
    this.isSaved = true;
    window.setTimeout(() => {
      this.isSaved = false;
    }, 1800);
  }

  <template>
    {{#if this.canUse}}
      <main class="westan-vip-panel">
        <div class="westan-vip-panel__inner">
          <header class="westan-vip-panel__header">
            <div>{{dIcon "crown"}}</div>
            <section>
              <h1>Painel VIP</h1>
              <p>Escolha o tema visual do seu perfil</p>
            </section>
          </header>

          <section class="westan-vip-panel__section">
            <div class="westan-vip-panel__section-title">
              {{dIcon "bolt"}}
              <h2>Temas disponíveis</h2>
            </div>

            <div class="westan-vip-theme-grid">
              {{#each this.themeRows as |theme|}}
                <button
                  type="button"
                  class="westan-vip-theme-card {{if theme.is_selected "is-selected"}}"
                  style={{theme.card_style}}
                  data-theme-id={{theme.id}}
                  {{on "click" this.selectTheme}}
                >
                  <div class="westan-vip-theme-card__copy">
                    <strong style={{theme.text_style}}>{{theme.name}}</strong>
                    <p>Badge animado, borda com efeito liquid metal e card customizado.</p>
                    <div class="westan-vip-theme-card__toggles">
                      <label>
                        <input type="checkbox" checked={{this.badgeEnabled}} {{on "click" this.toggleBadge}} {{on "change" this.toggleBadge}} />
                        Badge/Selo
                      </label>
                      <label>
                        <input type="checkbox" checked={{this.customCardEnabled}} {{on "click" this.toggleCustomCard}} {{on "change" this.toggleCustomCard}} />
                        Card personalizado
                      </label>
                    </div>
                  </div>

                  {{#if this.badgeEnabled}}
                    <div class="westan-vip-badge-preview">
                      {{#if theme.badgeBackgroundUrl}}
                        {{#if theme.badgeBackgroundIsVideo}}
                          <video src={{theme.badgeBackgroundUrl}} autoplay loop muted playsinline></video>
                        {{else}}
                          <img src={{theme.badgeBackgroundUrl}} alt="" />
                        {{/if}}
                      {{/if}}
                      {{#if theme.logoUrl}}
                        <img class="westan-vip-badge-preview__logo" src={{theme.logoUrl}} alt={{theme.name}} />
                      {{else}}
                        <span>{{theme.badgeText}}</span>
                      {{/if}}
                    </div>
                  {{/if}}

                  {{#if theme.is_selected}}
                    <span class="westan-vip-selected">{{dIcon "check"}} Selecionado</span>
                  {{/if}}
                </button>
              {{/each}}
            </div>
          </section>

          <section class="westan-vip-panel__section">
            <div class="westan-vip-panel__section-title">
              {{dIcon "crown"}}
              <h2>Nickname</h2>
            </div>

            <div class="westan-vip-nickname-grid">
              {{#each this.nicknameRows as |style|}}
                <button
                  type="button"
                  class="westan-vip-nickname-card {{if style.is_selected "is-selected"}}"
                  data-style-id={{style.id}}
                  {{on "click" this.selectNicknameStyle}}
                >
                  <div>
                    <p>Estilo do nickname</p>
                    <strong style={{style.text_style}}>{{this.userName}}</strong>
                    <span>{{style.kind}}</span>
                  </div>
                  {{#if style.is_selected}}
                    <em>{{dIcon "check"}}</em>
                  {{/if}}
                </button>
              {{/each}}
            </div>
          </section>

          <section class="westan-vip-title-card">
            <div class="westan-vip-title-card__title">
              {{dIcon "crown"}}
              <h2>Personalizar título do perfil</h2>
            </div>
            <p>Esse texto aparece no lugar do grupo primário nos comentários e no card de usuário. Se deixar em branco, usamos seu grupo principal automaticamente.</p>

            <div class="westan-vip-title-card__body">
              <div>
                <label>Título personalizado</label>
                <input value={{this.customTitle}} placeholder={{this.primaryGroupName}} {{on "input" this.updateTitle}} />
                <small>Grupo primário atual: <strong>{{this.primaryGroupName}}</strong></small>
              </div>
              <aside>
                <span>Prévia</span>
                <strong>{{this.userName}}</strong>
                <em>{{this.previewTitle}}</em>
              </aside>
            </div>
          </section>

          <button type="button" class="westan-vip-save {{if this.isSaved "is-saved"}}" disabled={{this.isSaving}} {{on "click" this.save}}>
            {{this.saveLabel}}
          </button>
        </div>
      </main>
    {{else}}
      <main class="westan-vip-panel westan-vip-panel--locked">
        <div>
          {{dIcon "crown"}}
          <h1>Acesso restrito</h1>
          <p>Esta área aparece apenas para membros do grupo VIP.</p>
        </div>
      </main>
    {{/if}}
  </template>
}
