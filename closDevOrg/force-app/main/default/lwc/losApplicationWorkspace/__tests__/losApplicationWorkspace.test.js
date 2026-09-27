import { createElement } from "lwc";
import Workspace from "c/losApplicationWorkspace";
import getWorkspace from "@salesforce/apex/LOS_WorkspaceService.getWorkspace";
import { refreshApex } from "@salesforce/apex";
jest.mock(
  "@salesforce/apex/LOS_WorkspaceService.getWorkspace",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex",
  () => ({ refreshApex: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
const flush = () => Promise.resolve().then(() => Promise.resolve());
const context = {
  application: {
    applicationNumber: "APP-TEST",
    stageCode: "STAGE_CODE",
    status: "Business status",
    version: 3,
    reworkNumber: 1
  },
  relationshipName: "Test relationship",
  stageLabel: "Configured stage",
  personas: [],
  health: ["Configured"],
  navigationSections: [
    {
      code: "TEST_OVERVIEW",
      label: "Configured overview",
      componentKey: "OVERVIEW"
    },
    {
      code: "TEST_HISTORY",
      label: "Configured history",
      componentKey: "LIFECYCLE"
    }
  ],
  actions: [
    {
      code: "EDGE_ACTION",
      transitionCode: "EDGE",
      label: "Configured action",
      handlerKey: "TRANSITION",
      expectedVersion: 3
    }
  ],
  lifecycleHistory: [],
  tat: { availability: "No visible interval" }
};
function mount() {
  const el = createElement("c-los-application-workspace", { is: Workspace });
  el.applicationId = "test-id";
  document.body.appendChild(el);
  return el;
}
afterEach(() => {
  while (document.body.firstChild)
    document.body.removeChild(document.body.firstChild);
  jest.clearAllMocks();
});
it("shows loading then typed workspace and metadata navigation", async () => {
  const el = mount();
  expect(el.shadowRoot.querySelector("lightning-spinner")).not.toBeNull();
  getWorkspace.emit(context);
  await flush();
  expect(
    el.shadowRoot.querySelector("c-los-application-header").context.stageLabel
  ).toBe("Configured stage");
  const nav = el.shadowRoot.querySelector("c-los-workspace-navigation");
  expect(nav.sections).toHaveLength(2);
  expect(
    el.shadowRoot.querySelector("c-los-application-overview")
  ).not.toBeNull();
  nav.dispatchEvent(
    new CustomEvent("sectionselect", { detail: { code: "TEST_HISTORY" } })
  );
  await flush();
  expect(el.shadowRoot.querySelector("c-los-lifecycle-history")).not.toBeNull();
  expect(refreshApex).not.toHaveBeenCalled();
});
it("shows safe server errors without stale context", async () => {
  const el = mount();
  getWorkspace.error({ message: "Access unavailable" });
  await flush();
  expect(el.shadowRoot.querySelector('[role="alert"]').textContent).toContain(
    "Access unavailable"
  );
  expect(el.shadowRoot.querySelector("c-los-application-header")).toBeNull();
});
it("refreshes complete context after success", async () => {
  const el = mount();
  getWorkspace.emit(context);
  await flush();
  el.shadowRoot
    .querySelector("c-los-workspace-actions")
    .dispatchEvent(
      new CustomEvent("action", { detail: { code: "EDGE_ACTION" } })
    );
  await flush();
  const modal = el.shadowRoot.querySelector("c-los-transition-modal");
  expect(modal.action.expectedVersion).toBe(3);
  modal.dispatchEvent(new CustomEvent("completed"));
  await flush();
  expect(refreshApex).toHaveBeenCalledTimes(1);
  expect(el.shadowRoot.querySelector("c-los-transition-modal")).toBeNull();
});
it("refreshes stale context and requires a fresh user action", async () => {
  const el = mount();
  getWorkspace.emit(context);
  await flush();
  el.shadowRoot
    .querySelector("c-los-workspace-actions")
    .dispatchEvent(
      new CustomEvent("action", { detail: { code: "EDGE_ACTION" } })
    );
  await flush();
  el.shadowRoot
    .querySelector("c-los-transition-modal")
    .dispatchEvent(new CustomEvent("stale"));
  await flush();
  expect(refreshApex).toHaveBeenCalledTimes(1);
  expect(el.shadowRoot.querySelector('[role="status"]').textContent).toContain(
    "Review the latest"
  );
  expect(el.shadowRoot.querySelector("c-los-transition-modal")).toBeNull();
});
it("does not render arbitrary component names", async () => {
  const el = mount();
  getWorkspace.emit({
    ...context,
    navigationSections: [
      { code: "BAD", label: "Bad", componentKey: "c-arbitrary" }
    ]
  });
  await flush();
  expect(el.shadowRoot.querySelector("c-arbitrary")).toBeNull();
  expect(el.shadowRoot.querySelector("c-los-application-overview")).toBeNull();
});
