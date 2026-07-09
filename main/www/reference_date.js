function fieldworkerLocalDate(value) {
  var parts = String(value || "").split("-").map(Number);

  if (parts.length !== 3 || parts.some(Number.isNaN)) {
    return null;
  }

  return new Date(parts[0], parts[1] - 1, parts[2]);
}

function updateReferenceDateDistance() {
  var todayRaw = new Date();
  var today = new Date(
    todayRaw.getFullYear(),
    todayRaw.getMonth(),
    todayRaw.getDate()
  );

  document.querySelectorAll(".ref-date-relative[data-refdate]").forEach(function(el) {
    var refdate = fieldworkerLocalDate(el.dataset.refdate);

    if (!refdate) {
      return;
    }

    var days = Math.round((refdate - today) / 86400000);
    var absDays = Math.abs(days);
    var label = "";

    if (days === 0) {
      label = "(today)";
    } else if (days < 0) {
      label = "(" + absDays + " day" + (absDays === 1 ? "" : "s") + " ago)";
    } else {
      label = "(in " + absDays + " day" + (absDays === 1 ? "" : "s") + ")";
    }

    if (el.textContent !== label) {
      el.textContent = label;
    }
  });
}

function formatTimezoneNow(timezone) {
  var parts = {};

  try {
    new Intl.DateTimeFormat("en-NZ", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
      hourCycle: "h23"
    }).formatToParts(new Date()).forEach(function(part) {
      parts[part.type] = part.value;
    });
  } catch (error) {
    return "";
  }

  if (!parts.year || !parts.month || !parts.day || !parts.hour || !parts.minute) {
    return "";
  }

  return [
    parts.year,
    parts.month,
    parts.day
  ].join("-") + " " + parts.hour + ":" + parts.minute;
}

function updatePreferredTimezoneClocks() {
  document.querySelectorAll(".preferred-timezone-clock[data-timezone]").forEach(function(el) {
    var timezone = el.dataset.timezone;
    var formatted = formatTimezoneNow(timezone);
    var value = formatted || "unavailable";
    var nameEl = el.querySelector(".preferred-timezone-name");
    var valueEl = el.querySelector(".preferred-timezone-value");

    if (!nameEl || !valueEl) {
      return;
    }

    if (nameEl.textContent.trim() !== timezone) {
      nameEl.textContent = timezone;
    }

    if (valueEl.textContent.trim() !== value) {
      valueEl.textContent = value;
    }
  });
}

function updateReferenceDateDisplays() {
  updateReferenceDateDistance();
  updatePreferredTimezoneClocks();
}

$(function() {
  updateReferenceDateDisplays();

  window.setInterval(updatePreferredTimezoneClocks, 30000);

  new MutationObserver(updateReferenceDateDisplays).observe(document.body, {
    childList: true,
    subtree: true
  });
});
