let controls = null;

function fillSelectedMonth() {
  const [year, month] = controls.month.value.split("-").map(Number);
  if (!year || !month) return;

  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const prefix = controls.month.value;
  controls.start.value = `${prefix}-01`;
  controls.end.value = `${prefix}-${String(lastDay).padStart(2, "0")}`;
}

function updateRange() {
  const { start, end, preview } = controls;
  end.min = start.value;
  const reversed = start.value && end.value && start.value > end.value;
  end.setCustomValidity(reversed ? "종료일은 시작일과 같거나 이후여야 합니다." : "");

  if (reversed) {
    preview.textContent = "종료일은 시작일과 같거나 이후여야 합니다.";
  } else if (start.value && end.value) {
    preview.textContent = `${start.value.replaceAll("-", ".")} ~ ${end.value.replaceAll("-", ".")}`;
  } else {
    preview.textContent = "시작일과 종료일을 모두 선택해 주세요.";
  }
}

function updateMode() {
  const isRange = controls.toggle.checked;
  controls.monthField.hidden = isRange;
  controls.month.disabled = isRange;
  controls.range.hidden = !isRange;
  controls.start.disabled = !isRange;
  controls.end.disabled = !isRange;
  controls.start.required = isRange;
  controls.end.required = isRange;
  updateRange();
}

export function initializeExportPeriod() {
  if (controls) return;
  const toggle = document.getElementById("export-range-toggle");
  if (!toggle) return;

  controls = {
    toggle,
    month: document.getElementById("month-picker"),
    monthField: document.getElementById("export-month-field"),
    range: document.getElementById("export-date-range"),
    start: document.getElementById("export-start-date"),
    end: document.getElementById("export-end-date"),
    preview: document.getElementById("export-period-preview"),
  };

  fillSelectedMonth();
  toggle.addEventListener("change", updateMode);
  controls.month.addEventListener("change", () => {
    fillSelectedMonth();
    updateRange();
  });
  controls.start.addEventListener("input", updateRange);
  controls.end.addEventListener("input", updateRange);
  updateMode();
}

export function getExportQuery() {
  if (!controls) return null;

  if (controls.toggle.checked) {
    updateRange();
    if (!controls.start.reportValidity() || !controls.end.reportValidity()) return null;
    return new URLSearchParams({
      start_date: controls.start.value,
      end_date: controls.end.value,
    });
  }

  if (!controls.month.reportValidity()) return null;
  const [year, month] = controls.month.value.split("-");
  return new URLSearchParams({ year, month: String(Number.parseInt(month, 10)) });
}
