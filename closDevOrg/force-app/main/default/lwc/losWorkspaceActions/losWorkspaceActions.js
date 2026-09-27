import { LightningElement, api } from "lwc";
import { HANDLER_KEYS } from "c/losUiUtils";
export default class LosWorkspaceActions extends LightningElement {
  @api actions = [];
  @api selectedSection;
  @api disabled;
  get visibleActions() {
    return this.actions.filter(
      (x) =>
        HANDLER_KEYS.includes(x.handlerKey) &&
        (!x.sectionCode || x.sectionCode === this.selectedSection)
    );
  }
  execute(e) {
    this.dispatchEvent(
      new CustomEvent("action", { detail: { code: e.target.dataset.code } })
    );
  }
}
