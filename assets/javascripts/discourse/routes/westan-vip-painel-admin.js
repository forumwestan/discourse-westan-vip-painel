import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class WestanVipPainelAdminRoute extends DiscourseRoute {
  beforeModel() {
    if (!this.currentUser?.staff) {
      this.router.transitionTo("discovery.latest");
    }
  }

  async model() {
    return await ajax("/westan/vip-painel/admin/catalog");
  }
}
