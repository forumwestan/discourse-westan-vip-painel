import Component from "@glimmer/component";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/helpers/d-icon";

export default class WestanPremiumBanner extends Component {
  @service currentUser;
  @service router;
  @service siteSettings;

  get visible() {
    const path = (this.router.currentURL || "").split(/[?#]/)[0].replace(/\/$/, "");
    const homePaths = [getURL("/"), getURL("/latest")].map(url => url.replace(/\/$/, ""));
    return Boolean(this.siteSettings.westan_vip_painel_enabled &&
      this.currentUser?.westan_vip_painel_premium &&
      !this.args.outletArgs?.category && !this.args.outletArgs?.tag && homePaths.includes(path));
  }

  get settingsUrl() { return getURL("/vip-painel"); }

  <template>
    {{#if this.visible}}
      <aside class="westan-premium-home-banner" aria-label="Westan Premium">
        <span>{{dIcon "crown"}} <strong>Você agora é premium</strong></span>
        <a href={{this.settingsUrl}}>Ir para ajustes</a>
      </aside>
    {{/if}}
  </template>
}
