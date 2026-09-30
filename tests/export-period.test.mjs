import assert from "node:assert/strict";

class Input {
  constructor(value = "") {
    this.value = value;
    this.checked = false;
    this.hidden = false;
    this.listeners = {};
  }
  addEventListener(event, listener) { this.listeners[event] = listener; }
  setCustomValidity(message) { this.error = message; }
  reportValidity() { return Boolean(this.value) && !this.error; }
  emit(event) { this.listeners[event](); }
}

const fields = Object.fromEntries([
  "export-range-toggle", "month-picker", "export-month-field", "export-date-range",
  "export-start-date", "export-end-date", "export-period-preview",
].map((id) => [id, new Input()]));
globalThis.document = { getElementById: (id) => fields[id] };
fields["month-picker"].value = "2024-02";

const { initializeExportPeriod, getExportQuery } = await import("../frontend/static/js/features/export-period.js");
initializeExportPeriod();
assert.equal(getExportQuery().toString(), "year=2024&month=2");
assert.equal(fields["export-date-range"].hidden, true);

const toggle = fields["export-range-toggle"];
toggle.checked = true;
toggle.emit("change");
assert.equal(fields["export-month-field"].hidden, true);
assert.equal(fields["export-date-range"].hidden, false);
assert.equal(fields["export-start-date"].disabled, false);
assert.equal(getExportQuery().toString(), "start_date=2024-02-01&end_date=2024-02-29");
assert.equal(fields["export-period-preview"].textContent, "2024.02.01 ~ 2024.02.29");

fields["export-start-date"].value = "2025-12-31";
fields["export-end-date"].value = "2026-01-02";
assert.equal(getExportQuery().toString(), "start_date=2025-12-31&end_date=2026-01-02");
fields["export-end-date"].value = "2025-12-31";
assert.ok(getExportQuery(), "A single day is a valid range");
fields["export-end-date"].value = "2025-12-30";
assert.equal(getExportQuery(), null, "Reversed ranges must not download");
fields["export-end-date"].value = "";
assert.equal(getExportQuery(), null, "Missing end dates must not download");

toggle.checked = false;
toggle.emit("change");
assert.equal(fields["export-date-range"].hidden, true);
assert.equal(fields["export-start-date"].disabled, true);
assert.equal(getExportQuery().toString(), "year=2024&month=2", "Month mode must not send range dates");
fields["month-picker"].value = "2026-09";
fields["month-picker"].emit("change");
toggle.checked = true;
toggle.emit("change");
assert.equal(getExportQuery().toString(), "start_date=2026-09-01&end_date=2026-09-30");

console.log("Export period: month/range switching, leap day, boundaries, validation OK");
