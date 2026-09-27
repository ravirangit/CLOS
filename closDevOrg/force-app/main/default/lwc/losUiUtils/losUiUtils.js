export const STALE_MESSAGE =
  "The application changed. Refresh before retrying.";
export function isStale(error) {
  return error?.body?.message === STALE_MESSAGE;
}
export function errorMessage(error) {
  const body = error?.body;
  if (
    body?.message &&
    !body.stackTrace &&
    !/SELECT |SOQL|Class\.|Exception:|__c/.test(body.message)
  )
    return body.message;
  return "The request could not be completed. Check your access or contact your LOS administrator.";
}
// Keys are product capabilities, not business sections or arbitrary executable names.
export const COMPONENT_KEYS = Object.freeze({
  OVERVIEW: "overview",
  LIFECYCLE: "lifecycle",
  TAT: "tat"
});
export const HANDLER_KEYS = Object.freeze(["TRANSITION", "REFRESH"]);

// SLDS dialogs trap keyboard focus and support Escape without bypassing pending saves.
export function dialogKey(event, root, cancel) {
  if (event.key === "Escape") {
    event.preventDefault();
    cancel();
    return;
  }
  if (event.key !== "Tab") return;
  const controls = Array.from(
    root.querySelectorAll(
      "lightning-input,lightning-combobox,lightning-textarea,lightning-button"
    )
  ).filter((control) => !control.disabled);
  if (!controls.length) {
    event.preventDefault();
    return;
  }
  const first = controls[0];
  const last = controls[controls.length - 1];
  if (event.shiftKey && root.activeElement === first) {
    event.preventDefault();
    last.focus();
  }
  if (!event.shiftKey && root.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
}
export function applicationStateKey(objectApiName) {
  const parts = objectApiName.split("__");
  return `${parts.length > 2 ? parts[0] : "c"}__applicationId`;
}
