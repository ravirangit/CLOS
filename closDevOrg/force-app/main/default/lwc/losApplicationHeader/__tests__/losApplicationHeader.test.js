import { createElement } from "lwc";
import Header from "c/losApplicationHeader";
afterEach(() => {
  while (document.body.firstChild)
    document.body.removeChild(document.body.firstChild);
});
it("shows stage and business status as separate values", () => {
  const el = createElement("c-los-application-header", { is: Header });
  el.context = {
    application: {
      applicationNumber: "APP-TEST",
      status: "In Review",
      version: 4,
      reworkNumber: 1
    },
    stageLabel: "Credit Review"
  };
  document.body.appendChild(el);
  expect(el.shadowRoot.querySelector('[data-field="stage"]').textContent).toBe(
    "Credit Review"
  );
  expect(el.shadowRoot.querySelector('[data-field="status"]').textContent).toBe(
    "In Review"
  );
});
