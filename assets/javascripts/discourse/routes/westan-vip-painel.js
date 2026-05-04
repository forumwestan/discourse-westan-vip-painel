import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class WestanVipPainelRoute extends DiscourseRoute {
  beforeModel() {
    if (!this.currentUser) {
      this.router.transitionTo("login");
    }
  }

  async model() {
    return await ajax("/westan/vip-painel");
  }
}
