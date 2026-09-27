import { createElement } from "lwc";
import Modal from "c/losTransitionModal";
import transitionApplication from "@salesforce/apex/LOS_LifecycleService.transitionApplication";
jest.mock(
  "@salesforce/apex/LOS_LifecycleService.transitionApplication",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
const flush = () => Promise.resolve().then(() => Promise.resolve());
function mount() {
  const el = createElement("c-los-transition-modal", { is: Modal });
  el.applicationId = "app-id";
  el.action = {
    label: "Configured rework",
    transitionCode: "CONFIGURED_EDGE",
    requiresReason: true,
    requiresConfirmation: true,
    expectedVersion: 7
  };
  document.body.appendChild(el);
  return el;
}
function fill(el) {
  const reason = el.shadowRoot.querySelector("lightning-textarea");
  reason.value = "Test reason";
  reason.dispatchEvent(new CustomEvent("change"));
  const confirm = el.shadowRoot.querySelector("lightning-input");
  confirm.checked = true;
  confirm.dispatchEvent(new CustomEvent("change"));
}
function submit(el) {
  el.shadowRoot.querySelectorAll("lightning-button")[1].click();
}
afterEach(() => {
  while (document.body.firstChild)
    document.body.removeChild(document.body.firstChild);
  jest.clearAllMocks();
});
it("requires reason and confirmation before sending narrow versioned command", async () => {
  const el = mount();
  expect(el.shadowRoot.querySelector("lightning-textarea").required).toBe(true);
  expect(el.shadowRoot.querySelectorAll("lightning-button")[1].disabled).toBe(
    true
  );
  fill(el);
  await flush();
  transitionApplication.mockResolvedValue({});
  const completed = jest.fn();
  el.addEventListener("completed", completed);
  submit(el);
  await flush();
  expect(transitionApplication).toHaveBeenCalledWith({
    applicationId: "app-id",
    transitionCode: "CONFIGURED_EDGE",
    expectedVersion: 7,
    reason: "Test reason",
    comments: null
  });
  expect(completed).toHaveBeenCalledTimes(1);
});
it("emits stale once without automatic command retry", async () => {
  const el = mount();
  fill(el);
  await flush();
  transitionApplication.mockRejectedValue({
    body: { message: "The application changed. Refresh before retrying." }
  });
  const stale = jest.fn();
  el.addEventListener("stale", stale);
  submit(el);
  await flush();
  expect(stale).toHaveBeenCalledTimes(1);
  expect(transitionApplication).toHaveBeenCalledTimes(1);
});
it("keeps validation error visible", async () => {
  const el = mount();
  fill(el);
  await flush();
  transitionApplication.mockRejectedValue({
    body: { message: "Enter a reason for this transition." }
  });
  submit(el);
  await flush();
  expect(el.shadowRoot.querySelector('[role="alert"]').textContent).toContain(
    "Enter a reason"
  );
});

it("sends null for blank optional text", async () => {
  const el = mount();
  el.action = {
    label: "Configured forward",
    transitionCode: "EDGE",
    expectedVersion: 0,
    requiresReason: false,
    requiresConfirmation: false
  };
  await flush();
  transitionApplication.mockResolvedValue({});
  submit(el);
  await flush();
  expect(transitionApplication).toHaveBeenCalledWith({
    applicationId: "app-id",
    transitionCode: "EDGE",
    expectedVersion: 0,
    reason: null,
    comments: null
  });
});
