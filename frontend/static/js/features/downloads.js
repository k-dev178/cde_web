import { getExportQuery, initializeExportPeriod } from "./export-period.js";

let initialized = false;

export function initializeDownloads() {
  if (initialized) return;
  initializeExportPeriod();

  document.querySelectorAll(".js-download-button").forEach((button) => {
    button.addEventListener("click", () => {
      const path = button.dataset.downloadPath;
      const query = getExportQuery();
      if (!path || !query) return;
      window.location.assign(`/${path}?${query.toString()}`);
    });
  });

  initialized = true;
}
