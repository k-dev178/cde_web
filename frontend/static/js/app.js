import { initializeDownloads } from "./features/downloads.js";
import { initializeDialog } from "./components/dialog.js";
import { initializeNoShowNotifications } from "./features/no-show-notifications.js";

function initializePage() {
  initializeDownloads();
  initializeDialog("export-dialog", "open-export-dialog");
  initializeNoShowNotifications();
}

document.addEventListener("DOMContentLoaded", initializePage);

document.body.addEventListener("htmx:afterSwap", (event) => {
  if (event.detail.target.id === "table-container") {
    initializeNoShowNotifications();
  }
});
