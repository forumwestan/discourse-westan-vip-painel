import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";
import dIcon from "discourse/helpers/d-icon";

const DEFAULT_THEME = {
  id: "novo-tema",
  name: "Novo tema",
  enabled: true,
  badgeText: "VIP",
  logoUrl: "",
  badgeBackgroundUrl: "",
  nicknameFrom: "#9333EA",
  nicknameTo: "#EC4899",
  borderFrom: "#C084FC",
  borderTo: "#EC4899",
  surfaceFrom: "#F3E8FF",
  surfaceTo: "#FDF2F8",
  cardFilterColor: "#fff1ffcc",
};

const DEFAULT_STYLE = {
  id: "novo-estilo",
  name: "Novo estilo",
  enabled: true,
  from: "#9333EA",
  to: "#EC4899",
};

function clone(items) {
  return (items || []).map((item) => ({ ...item }));
}

function gradientStyle(from, to) {
  return htmlSafe(`background-image:linear-gradient(120deg, ${from}, ${to}, ${from});background-size:220% 220%;-webkit-background-clip:text;background-clip:text;color:transparent;`);
}

export default class WestanVipPainelAdminCatalog extends Component {
  @tracked themes = clone(this.args.model.themes);
  @tracked nicknameStyles = clone(this.args.model.nickname_styles);
  @tracked activeThemeIndex = 0;
  @tracked activeStyleIndex = 0;
  @tracked section = "themes";
  @tracked saving = false;

  get isThemesSection() {
    return this.section === "themes";
  }

  get activeTheme() {
    return this.themes[this.activeThemeIndex] || this.themes[0] || DEFAULT_THEME;
  }

  get activeStyle() {
    return this.nicknameStyles[this.activeStyleIndex] || this.nicknameStyles[0] || DEFAULT_STYLE;
  }

  get themeTabs() {
    return this.themes.map((theme, index) => ({
      ...theme,
      index,
      tabClass: index === this.activeThemeIndex ? "is-active" : "",
      label: theme.name || `Tema ${index + 1}`,
    }));
  }

  get styleTabs() {
    return this.nicknameStyles.map((style, index) => ({
      ...style,
      index,
      tabClass: index === this.activeStyleIndex ? "is-active" : "",
      label: style.name || `Estilo ${index + 1}`,
    }));
  }

  get activeThemeTextStyle() {
    return gradientStyle(this.activeTheme.nicknameFrom, this.activeTheme.nicknameTo);
  }

  get activeStyleTextStyle() {
    return gradientStyle(this.activeStyle.from, this.activeStyle.to);
  }

  get saveLabel() {
    return this.saving ? "Salvando..." : "Salvar catálogo";
  }

  @action
  showThemes() {
    this.section = "themes";
  }

  @action
  showStyles() {
    this.section = "styles";
  }

  @action
  selectTheme(event) {
    this.activeThemeIndex = Number(event.currentTarget.dataset.index);
  }

  @action
  selectStyle(event) {
    this.activeStyleIndex = Number(event.currentTarget.dataset.index);
  }

  @action
  addTheme() {
    this.themes = [...this.themes, { ...DEFAULT_THEME, id: `tema-${Date.now()}` }];
    this.activeThemeIndex = this.themes.length - 1;
    this.section = "themes";
  }

  @action
  addStyle() {
    this.nicknameStyles = [...this.nicknameStyles, { ...DEFAULT_STYLE, id: `estilo-${Date.now()}` }];
    this.activeStyleIndex = this.nicknameStyles.length - 1;
    this.section = "styles";
  }

  @action
  removeTheme() {
    this.themes = this.themes.filter((_, index) => index !== this.activeThemeIndex);
    this.activeThemeIndex = Math.max(0, this.activeThemeIndex - 1);
  }

  @action
  removeStyle() {
    this.nicknameStyles = this.nicknameStyles.filter((_, index) => index !== this.activeStyleIndex);
    this.activeStyleIndex = Math.max(0, this.activeStyleIndex - 1);
  }

  @action
  updateTheme(event) {
    const field = event.currentTarget.dataset.field;
    const value = field === "enabled" ? event.target.checked : event.target.value;
    this.themes = this.themes.map((theme, index) => {
      if (index !== this.activeThemeIndex) {
        return theme;
      }
      return { ...theme, [field]: value };
    });
  }

  @action
  updateStyle(event) {
    const field = event.currentTarget.dataset.field;
    const value = field === "enabled" ? event.target.checked : event.target.value;
    this.nicknameStyles = this.nicknameStyles.map((style, index) => {
      if (index !== this.activeStyleIndex) {
        return style;
      }
      return { ...style, [field]: value };
    });
  }

  @action
  async save() {
    this.saving = true;
    const response = await ajax("/westan/vip-painel/admin/catalog", {
      type: "PATCH",
      data: {
        themes: this.themes,
        nickname_styles: this.nicknameStyles,
      },
    });
    this.themes = clone(response.themes);
    this.nicknameStyles = clone(response.nickname_styles);
    this.activeThemeIndex = Math.min(this.activeThemeIndex, Math.max(0, this.themes.length - 1));
    this.activeStyleIndex = Math.min(this.activeStyleIndex, Math.max(0, this.nicknameStyles.length - 1));
    this.saving = false;
  }

  <template>
    <main class="westan-vip-admin">
      <header class="westan-vip-admin__header">
        <div>
          <h1>Westan VIP Painel</h1>
          <p>Edite temas, badges e estilos de nickname sem mexer em JSON.</p>
        </div>
        <div>
          <button type="button" {{on "click" this.addTheme}}>{{dIcon "plus"}} Novo tema</button>
          <button type="button" {{on "click" this.addStyle}}>{{dIcon "plus"}} Novo nickname</button>
        </div>
      </header>

      <nav class="westan-vip-admin__switch">
        <button type="button" class={{if this.isThemesSection "is-active"}} {{on "click" this.showThemes}}>Temas e badges</button>
        <button type="button" class={{if this.isThemesSection "" "is-active"}} {{on "click" this.showStyles}}>Cores do nickname</button>
      </nav>

      {{#if this.isThemesSection}}
        <section class="westan-vip-admin__tabs">
          {{#each this.themeTabs as |theme|}}
            <button type="button" class={{theme.tabClass}} data-index={{theme.index}} {{on "click" this.selectTheme}}>{{theme.label}}</button>
          {{/each}}
        </section>

        <section class="westan-vip-admin__panel">
          <div class="westan-vip-admin__panel-head">
            <div>
              <strong>{{this.activeTheme.name}}</strong>
              <span>ID: {{this.activeTheme.id}}</span>
            </div>
            <button type="button" class="is-danger" {{on "click" this.removeTheme}}>{{dIcon "trash-can"}} Remover</button>
          </div>

          <div class="westan-vip-admin__theme-preview">
            <div>
              <strong style={{this.activeThemeTextStyle}}>{{this.activeTheme.name}}</strong>
              <p>Badge animado, borda com efeito liquid metal e card customizado.</p>
            </div>
            <aside>
              {{#if this.activeTheme.badgeBackgroundUrl}}
                <img src={{this.activeTheme.badgeBackgroundUrl}} alt="" />
              {{/if}}
              {{#if this.activeTheme.logoUrl}}
                <img class="westan-vip-admin__badge-logo" src={{this.activeTheme.logoUrl}} alt={{this.activeTheme.name}} />
              {{else}}
                <span>{{this.activeTheme.badgeText}}</span>
              {{/if}}
            </aside>
          </div>

          <div class="westan-vip-admin__grid">
            <label>Nome do tema<input value={{this.activeTheme.name}} data-field="name" {{on "input" this.updateTheme}} /></label>
            <label>ID do tema<input value={{this.activeTheme.id}} data-field="id" {{on "input" this.updateTheme}} /></label>
            <label>Texto do badge<input value={{this.activeTheme.badgeText}} data-field="badgeText" {{on "input" this.updateTheme}} /></label>
            <label>Logo do badge (URL)<input value={{this.activeTheme.logoUrl}} data-field="logoUrl" placeholder="https://..." {{on "input" this.updateTheme}} /></label>
            <label>Fundo do badge (URL)<input value={{this.activeTheme.badgeBackgroundUrl}} data-field="badgeBackgroundUrl" placeholder="https://..." {{on "input" this.updateTheme}} /></label>
            <label>Filtro do card<input value={{this.activeTheme.cardFilterColor}} data-field="cardFilterColor" placeholder="#fff1ffcc" {{on "input" this.updateTheme}} /></label>
          </div>

          <div class="westan-vip-admin__colors">
            <label>Nick início<input type="color" value={{this.activeTheme.nicknameFrom}} data-field="nicknameFrom" {{on "input" this.updateTheme}} /></label>
            <label>Nick fim<input type="color" value={{this.activeTheme.nicknameTo}} data-field="nicknameTo" {{on "input" this.updateTheme}} /></label>
            <label>Borda início<input type="color" value={{this.activeTheme.borderFrom}} data-field="borderFrom" {{on "input" this.updateTheme}} /></label>
            <label>Borda fim<input type="color" value={{this.activeTheme.borderTo}} data-field="borderTo" {{on "input" this.updateTheme}} /></label>
            <label>Fundo início<input type="color" value={{this.activeTheme.surfaceFrom}} data-field="surfaceFrom" {{on "input" this.updateTheme}} /></label>
            <label>Fundo fim<input type="color" value={{this.activeTheme.surfaceTo}} data-field="surfaceTo" {{on "input" this.updateTheme}} /></label>
          </div>

          <label class="westan-vip-admin__check">
            <input type="checkbox" checked={{this.activeTheme.enabled}} data-field="enabled" {{on "change" this.updateTheme}} />
            Tema ativo
          </label>
        </section>
      {{else}}
        <section class="westan-vip-admin__tabs">
          {{#each this.styleTabs as |style|}}
            <button type="button" class={{style.tabClass}} data-index={{style.index}} {{on "click" this.selectStyle}}>{{style.label}}</button>
          {{/each}}
        </section>

        <section class="westan-vip-admin__panel">
          <div class="westan-vip-admin__panel-head">
            <div>
              <strong>{{this.activeStyle.name}}</strong>
              <span>ID: {{this.activeStyle.id}}</span>
            </div>
            <button type="button" class="is-danger" {{on "click" this.removeStyle}}>{{dIcon "trash-can"}} Remover</button>
          </div>

          <div class="westan-vip-admin__nickname-preview">
            <p>Estilo do nickname</p>
            <strong style={{this.activeStyleTextStyle}}>Nugget</strong>
            <span>Degradê</span>
          </div>

          <div class="westan-vip-admin__grid">
            <label>Nome do estilo<input value={{this.activeStyle.name}} data-field="name" {{on "input" this.updateStyle}} /></label>
            <label>ID do estilo<input value={{this.activeStyle.id}} data-field="id" {{on "input" this.updateStyle}} /></label>
          </div>

          <div class="westan-vip-admin__colors westan-vip-admin__colors--short">
            <label>Cor início<input type="color" value={{this.activeStyle.from}} data-field="from" {{on "input" this.updateStyle}} /></label>
            <label>Cor fim<input type="color" value={{this.activeStyle.to}} data-field="to" {{on "input" this.updateStyle}} /></label>
          </div>

          <label class="westan-vip-admin__check">
            <input type="checkbox" checked={{this.activeStyle.enabled}} data-field="enabled" {{on "change" this.updateStyle}} />
            Estilo ativo
          </label>
        </section>
      {{/if}}

      <footer class="westan-vip-admin__footer">
        <a href="/admin/site_settings/category/plugins?filter=westan_vip_painel">Settings avançadas</a>
        <button type="button" disabled={{this.saving}} {{on "click" this.save}}>{{this.saveLabel}}</button>
      </footer>
    </main>
  </template>
}
