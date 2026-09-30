export function initializeDialog(dialogId, triggerId) {
  const dialog = document.getElementById(dialogId);
  const trigger = document.getElementById(triggerId);
  if (!dialog || !trigger || dialog.dataset.initialized) return;

  trigger.addEventListener("click", () => {
    if (dialog.open) return;
    dialog.showModal();
    document.documentElement.classList.add("dialog-open");
  });

  dialog.querySelectorAll("[data-dialog-close]").forEach((button) => {
    button.addEventListener("click", () => dialog.close());
  });

  dialog.addEventListener("click", (event) => {
    if (event.target !== dialog) return;
    const bounds = dialog.getBoundingClientRect();
    const outside = event.clientX < bounds.left || event.clientX > bounds.right
      || event.clientY < bounds.top || event.clientY > bounds.bottom;
    if (outside) dialog.close();
  });

  dialog.addEventListener("close", () => {
    document.documentElement.classList.remove("dialog-open");
    trigger.focus({ preventScroll: true });
  });

  dialog.dataset.initialized = "true";
}
