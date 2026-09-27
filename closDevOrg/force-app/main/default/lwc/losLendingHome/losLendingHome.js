import { LightningElement, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import getApplications from "@salesforce/apex/LOS_WorkspaceService.getApplications";
import APPLICATION_OBJECT from "@salesforce/schema/LOS_Credit_Application__c";
import { applicationStateKey, errorMessage } from "c/losUiUtils";
const STATE_KEY = applicationStateKey(APPLICATION_OBJECT.objectApiName);
const COLUMNS = [
  {
    label: "Application",
    fieldName: "applicationNumber",
    type: "button",
    typeAttributes: {
      label: { fieldName: "applicationNumber" },
      name: "open",
      variant: "base"
    }
  },
  { label: "Relationship", fieldName: "relationship" },
  { label: "Type", fieldName: "applicationType" },
  { label: "Stage", fieldName: "stage" },
  { label: "Status", fieldName: "status" },
  { label: "Work assignee", fieldName: "assignee" },
  { label: "Rework", fieldName: "reworkNumber", type: "number" }
];
export default class LosLendingHome extends NavigationMixin(LightningElement) {
  columns = COLUMNS;
  rows = [];
  loading = true;
  error;
  creating = false;
  applicationId;
  wiredList;
  @wire(CurrentPageReference) page(ref) {
    this.applicationId = ref?.state?.[STATE_KEY];
    this.currentPage = ref;
  }
  @wire(getApplications) applications(result) {
    this.wiredList = result;
    const { data, error } = result;
    if (data) {
      this.rows = data;
      this.error = undefined;
      this.loading = false;
    }
    if (error) {
      this.error = errorMessage(error);
      this.loading = false;
    }
  }
  get empty() {
    return !this.loading && !this.error && !this.rows.length;
  }
  get isHome() {
    return !this.applicationId;
  }
  newApplication() {
    this.creating = true;
  }
  closeCreate() {
    this.creating = false;
  }
  openRow(event) {
    this.open(event.detail.row.id);
  }
  created(event) {
    this.creating = false;
    this.open(event.detail.applicationId);
  }
  open(id) {
    this[NavigationMixin.Navigate]({
      ...this.currentPage,
      state: { ...this.currentPage?.state, [STATE_KEY]: id }
    });
  }
  async back() {
    this[NavigationMixin.Navigate]({
      ...this.currentPage,
      state: { ...this.currentPage?.state, [STATE_KEY]: undefined }
    });
    await this.refresh();
  }
  async refresh() {
    this.loading = true;
    try {
      await refreshApex(this.wiredList);
    } catch (e) {
      this.error = errorMessage(e);
    } finally {
      this.loading = false;
    }
  }
}
