import { LightningElement, api } from "lwc";
const COLUMNS = [
  {
    label: "Date/time",
    fieldName: "occurredAt",
    type: "date",
    typeAttributes: {
      year: "numeric",
      month: "short",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit"
    }
  },
  { label: "From stage", fieldName: "fromStage" },
  { label: "To stage", fieldName: "toStage" },
  { label: "Type", fieldName: "transitionType" },
  { label: "Performed by", fieldName: "performedBy" },
  { label: "Rework", fieldName: "reworkNumber", type: "number" },
  { label: "Reason", fieldName: "reason", wrapText: true },
  { label: "Comments", fieldName: "comments", wrapText: true }
];
export default class LosLifecycleHistory extends LightningElement {
  @api history = [];
  @api hasMore;
  columns = COLUMNS;
  get empty() {
    return !this.history.length;
  }
}
