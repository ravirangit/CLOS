import { LightningElement, api } from "lwc";
export default class LosApplicationOverview extends LightningElement {
  @api context;
  get personas() {
    return (
      this.context.personas.join(", ") ||
      "No applicable visible persona assignments"
    );
  }
}
