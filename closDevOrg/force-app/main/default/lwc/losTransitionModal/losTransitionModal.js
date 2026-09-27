import { LightningElement, api } from "lwc";
import transitionApplication from "@salesforce/apex/LOS_LifecycleService.transitionApplication";
import { dialogKey, errorMessage, isStale } from "c/losUiUtils";
export default class LosTransitionModal extends LightningElement {
  focused = false;
  renderedCallback() {
    if (!this.focused) {
      this.focused = true;
      this.template
        .querySelector("lightning-input,lightning-textarea")
        ?.focus();
    }
  }
  keydown(event) {
    dialogKey(event, this.template, () => this.cancel());
  }

  @api applicationId;
  @api action;
  reason = "";
  comments = "";
  confirmed = false;
  saving = false;
  error;
  get disabled() {
    return (
      this.saving ||
      (this.action.requiresReason && !this.reason.trim()) ||
      (this.action.requiresConfirmation && !this.confirmed)
    );
  }
  change(e) {
    if (e.target.name === "reason") this.reason = e.target.value;
    else if (e.target.name === "comments") this.comments = e.target.value;
    else this.confirmed = e.target.checked;
  }
  cancel() {
    if (!this.saving) this.dispatchEvent(new CustomEvent("cancel"));
  }
  async submit() {
    if (this.disabled) return;
    this.saving = true;
    this.error = undefined;
    try {
      await transitionApplication({
        applicationId: this.applicationId,
        transitionCode: this.action.transitionCode,
        expectedVersion: this.action.expectedVersion,
        reason: this.reason.trim() || null,
        comments: this.comments.trim() || null
      });
      this.dispatchEvent(new CustomEvent("completed"));
    } catch (e) {
      if (isStale(e)) {
        this.dispatchEvent(new CustomEvent("stale"));
      } else this.error = errorMessage(e);
    } finally {
      this.saving = false;
    }
  }
}
