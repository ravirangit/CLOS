import { createElement } from "lwc";
import Create from "c/losCreateApplication";
import getApplicationTypes from "@salesforce/apex/LOS_WorkspaceService.getApplicationTypes";
import searchRelationships from "@salesforce/apex/LOS_WorkspaceService.searchRelationships";
import createApplication from "@salesforce/apex/LOS_ApplicationService.createApplication";
jest.mock(
  "@salesforce/apex/LOS_WorkspaceService.getApplicationTypes",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LOS_WorkspaceService.searchRelationships",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LOS_WorkspaceService.searchBaselines",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LOS_ApplicationService.createApplication",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
const flush = () => Promise.resolve().then(() => Promise.resolve());
afterEach(() => {
  while (document.body.firstChild)
    document.body.removeChild(document.body.firstChild);
  jest.clearAllMocks();
  jest.useRealTimers();
});
it("debounces bounded server search and creates through the existing facade", async () => {
  jest.useFakeTimers();
  const el = createElement("c-los-create-application", { is: Create });
  document.body.appendChild(el);
  getApplicationTypes.emit([
    { label: "Configured type", value: "CUSTOM_TYPE", baselineRequired: false }
  ]);
  await flush();
  searchRelationships.mockResolvedValue([
    { label: "Test relationship", value: "relationship-id" }
  ]);
  const input = el.shadowRoot.querySelector("lightning-input");
  input.value = "Te";
  input.dispatchEvent(new CustomEvent("change"));
  input.value = "Test";
  input.dispatchEvent(new CustomEvent("change"));
  expect(searchRelationships).not.toHaveBeenCalled();
  jest.advanceTimersByTime(300);
  await flush();
  expect(searchRelationships).toHaveBeenCalledTimes(1);
  const combos = el.shadowRoot.querySelectorAll("lightning-combobox");
  combos[0].dispatchEvent(
    new CustomEvent("change", { detail: { value: "relationship-id" } })
  );
  combos[1].dispatchEvent(
    new CustomEvent("change", { detail: { value: "CUSTOM_TYPE" } })
  );
  await flush();
  createApplication.mockResolvedValue({ applicationId: "created-id" });
  const created = jest.fn();
  el.addEventListener("created", created);
  el.shadowRoot.querySelectorAll("lightning-button")[1].click();
  await flush();
  expect(createApplication).toHaveBeenCalledWith({
    relationshipId: "relationship-id",
    applicationTypeCode: "CUSTOM_TYPE",
    baselineApplicationId: null
  });
  expect(created.mock.calls[0][0].detail.applicationId).toBe("created-id");
});
