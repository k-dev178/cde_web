const TOAST_LIFETIME_MS = 9000;

export function showToast(title, body, variant = "warning") {
  const container = document.getElementById("toasts");
  if (!container) return;

  const toast = document.createElement("div");
  toast.className = `toast toast--${variant}`;

  const titleElement = document.createElement("p");
  titleElement.className = "toast__title";
  titleElement.textContent = title;

  const bodyElement = document.createElement("p");
  bodyElement.className = "toast__body";
  bodyElement.textContent = body;

  toast.append(titleElement, bodyElement);
  container.appendChild(toast);
  window.setTimeout(() => toast.remove(), TOAST_LIFETIME_MS);
}
