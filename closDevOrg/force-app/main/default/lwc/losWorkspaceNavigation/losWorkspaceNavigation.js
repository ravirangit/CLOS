import { LightningElement, api } from "lwc";
export default class LosWorkspaceNavigation extends LightningElement {
  @api sections = [];
  @api selected;
  select(e) {
    this.dispatchEvent(
      new CustomEvent("sectionselect", { detail: { code: e.detail.name } })
    );
  }
}
