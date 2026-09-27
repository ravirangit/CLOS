import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getWorkspace from "@salesforce/apex/LOS_WorkspaceService.getWorkspace";
import { COMPONENT_KEYS, errorMessage } from "c/losUiUtils";
export default class LosApplicationWorkspace extends LightningElement {
  @api applicationId;
  context;
  error;
  loading = true;
  selected;
  transition;
  notice;
  wiredContext;
  @wire(getWorkspace, { applicationId: "$applicationId" }) loaded(result) {
    this.wiredContext = result;
    const { data, error } = result;
    if (data) {
      this.context = data;
      this.error = undefined;
      this.loading = false;
      if (!data.navigationSections.some((x) => x.code === this.selected))
        this.selected = data.navigationSections[0]?.code;
    }
    if (error) {
      this.context = undefined;
      this.error = errorMessage(error);
      this.loading = false;
    }
  }
  get selectedComponent() {
    return COMPONENT_KEYS[
      this.context?.navigationSections.find((x) => x.code === this.selected)
        ?.componentKey
    ];
  }
  get overview() {
    return this.selectedComponent === "overview";
  }
  get lifecycle() {
    return this.selectedComponent === "lifecycle";
  }
  get tat() {
    return this.selectedComponent === "tat";
  }
  get noSections() {
    return !this.context?.navigationSections.length;
  }
  select(event) {
    this.selected = event.detail.code;
  }
  action(event) {
    const action = this.context.actions.find(
      (x) => x.code === event.detail.code
    );
    if (!action || this.loading) return;
    if (action.handlerKey === "REFRESH") {
      this.refresh();
    } else if (action.handlerKey === "TRANSITION") {
      this.transition = action;
    }
  }
  cancel() {
    this.transition = undefined;
  }
  async completed() {
    this.transition = undefined;
    this.notice = "Transition completed. Latest application state loaded.";
    await this.refresh();
  }
  async stale() {
    this.transition = undefined;
    this.notice =
      "This application changed since you opened it. Review the latest information before taking another action.";
    await this.refresh();
  }
  async refresh() {
    this.loading = true;
    this.transition = undefined;
    try {
      await refreshApex(this.wiredContext);
    } catch (e) {
      this.error = errorMessage(e);
      this.context = undefined;
    } finally {
      this.loading = false;
    }
  }
}
