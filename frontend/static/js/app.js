import { initializeDownloads } from "./features/downloads.js";
import { initializeNoShowNotifications } from "./features/no-show-notifications.js";

function initializePage() {
  initializeDownloads();
  initializeNoShowNotifications();
}

document.addEventListener("DOMContentLoaded", initializePage);

document.body.addEventListener("htmx:afterSwap", (event) => {
  if (event.detail.target.id === "table-container") {
    initializeNoShowNotifications();
  }
});
