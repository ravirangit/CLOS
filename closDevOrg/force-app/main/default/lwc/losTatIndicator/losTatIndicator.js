import { LightningElement, api } from "lwc";
export default class LosTatIndicator extends LightningElement {
  @api timing;
  get pauseLabel() {
    return this.timing.hasVisiblePause
      ? "Active pause visible"
      : "No active pause visible";
  }
  get target() {
    return this.timing.targetMinutes ?? "Not configured";
  }
  get business() {
    return (
      this.timing.businessMinutes ?? "Unavailable — business calendar deferred"
    );
  }
}
