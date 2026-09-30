import { showToast } from "../components/toast.js";

const ALERT_DELAY_MINUTES = 20;
const alertedReservationIds = new Set();
const timerByReservationId = new Map();

function readJsonElement(id) {
  const element = document.getElementById(id);
  if (!element) return null;

  try {
    return JSON.parse(element.textContent);
  } catch (error) {
    console.error(`${id} 데이터를 읽지 못했습니다.`, error);
    return null;
  }
}

function notifyNoShow(item) {
  const title = "⚠️ 미입실 알림";
  const body = `${item.rpName}\n${item.rrBooker}님이 ${item.rrStartTime} 예약 후 입실하지 않았습니다.`;

  if ("Notification" in window && Notification.permission === "granted") {
    new Notification(title, { body });
  }
  showToast(title, body);
}

function clearCheckedInTimers(checkedInIds) {
  timerByReservationId.forEach((timerId, reservationId) => {
    if (!checkedInIds.has(reservationId)) return;

    window.clearTimeout(timerId);
    timerByReservationId.delete(reservationId);
    alertedReservationIds.add(reservationId);
  });
}

export function initializeNoShowNotifications() {
  const reservations = readJsonElement("reservation-data");
  const checkinList = readJsonElement("checkin-data");
  if (!reservations || !checkinList) return;

  const checkedInIds = new Set(checkinList.map(String));
  const now = new Date();
  clearCheckedInTimers(checkedInIds);

  reservations.forEach((item) => {
    if (item.rrState !== "예약완료") return;

    const reservationId = String(item.rrSeq);
    if (
      alertedReservationIds.has(reservationId)
      || timerByReservationId.has(reservationId)
      || checkedInIds.has(reservationId)
    ) return;

    const [hour, minute] = item.rrStartTime.split(":").map(Number);
    const deadline = new Date(now);
    deadline.setHours(hour, minute + ALERT_DELAY_MINUTES, 0, 0);
    const delay = deadline.getTime() - now.getTime();
    if (delay <= 0) return;

    const timerId = window.setTimeout(() => {
      timerByReservationId.delete(reservationId);
      alertedReservationIds.add(reservationId);
      notifyNoShow(item);
    }, delay);
    timerByReservationId.set(reservationId, timerId);
  });
}

if ("Notification" in window && Notification.permission === "default") {
  Notification.requestPermission();
}
