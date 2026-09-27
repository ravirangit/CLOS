import { LightningElement, wire } from "lwc";
import getApplicationTypes from "@salesforce/apex/LOS_WorkspaceService.getApplicationTypes";
import searchRelationships from "@salesforce/apex/LOS_WorkspaceService.searchRelationships";
import searchBaselines from "@salesforce/apex/LOS_WorkspaceService.searchBaselines";
import createApplication from "@salesforce/apex/LOS_ApplicationService.createApplication";
import { dialogKey, errorMessage } from "c/losUiUtils";
export default class LosCreateApplication extends LightningElement {
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

  types = [];
  relationshipOptions = [];
  baselineOptions = [];
  typeCode;
  relationshipId;
  baselineId;
  error;
  saving = false;
  searching = false;
  timer;
  sequence = 0;
  @wire(getApplicationTypes) loaded({ data, error }) {
    if (data) this.types = data;
    if (error) this.error = errorMessage(error);
  }
  get baselineRequired() {
    return (
      this.types.find((x) => x.value === this.typeCode)?.baselineRequired ===
      true
    );
  }
  get disabled() {
    return (
      this.saving ||
      !this.relationshipId ||
      !this.typeCode ||
      (this.baselineRequired && !this.baselineId)
    );
  }
  typeChanged(e) {
    this.typeCode = e.detail.value;
    this.baselineId = undefined;
    this.baselineOptions = [];
  }
  relationshipChanged(e) {
    this.relationshipId = e.detail.value;
    this.baselineId = undefined;
    this.baselineOptions = [];
  }
  baselineChanged(e) {
    this.baselineId = e.detail.value;
  }
  search(e) {
    const term = e.target.value;
    const kind = e.target.dataset.kind;
    clearTimeout(this.timer);
    const token = ++this.sequence;
    if (kind === "relationship") {
      this.relationshipId = undefined;
      this.relationshipOptions = [];
      this.baselineId = undefined;
      this.baselineOptions = [];
    } else {
      this.baselineId = undefined;
      this.baselineOptions = [];
    }
    this.searching = false;
    if (term.trim().length < 2) return;
    this.searching = true;
    // Debounce user input; token checks discard superseded responses.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.timer = setTimeout(async () => {
      try {
        const data =
          kind === "relationship"
            ? await searchRelationships({ searchTerm: term })
            : await searchBaselines({
                relationshipId: this.relationshipId,
                searchTerm: term
              });
        if (token !== this.sequence) return;
        if (kind === "relationship") this.relationshipOptions = data;
        else this.baselineOptions = data;
        this.error = data.length
          ? undefined
          : "No matching accessible records found.";
      } catch (err) {
        if (token === this.sequence) this.error = errorMessage(err);
      } finally {
        if (token === this.sequence) this.searching = false;
      }
    }, 300);
  }
  disconnectedCallback() {
    clearTimeout(this.timer);
    this.sequence++;
  }
  cancel() {
    if (!this.saving) this.dispatchEvent(new CustomEvent("cancel"));
  }
  async submit() {
    if (this.disabled) return;
    this.saving = true;
    this.error = undefined;
    try {
      const result = await createApplication({
        relationshipId: this.relationshipId,
        applicationTypeCode: this.typeCode,
        baselineApplicationId: this.baselineRequired ? this.baselineId : null
      });
      this.dispatchEvent(
        new CustomEvent("created", {
          detail: { applicationId: result.applicationId }
        })
      );
    } catch (e) {
      this.error = errorMessage(e);
    } finally {
      this.saving = false;
    }
  }
}
