let initialized = false;

export function initializeDownloads() {
  if (initialized) return;

  document.querySelectorAll(".js-download-button").forEach((button) => {
    button.addEventListener("click", () => {
      const selectedMonth = document.getElementById("month-picker")?.value;
      const path = button.dataset.downloadPath;
      if (!selectedMonth || !path) return;

      const [year, month] = selectedMonth.split("-");
      const query = new URLSearchParams({
        year,
        month: String(Number.parseInt(month, 10)),
      });
      window.location.assign(`/${path}?${query.toString()}`);
    });
  });

  initialized = true;
}
