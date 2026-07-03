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

$(function() {
  updateReferenceDateDistance();

  new MutationObserver(updateReferenceDateDistance).observe(document.body, {
    childList: true,
    subtree: true
  });
});
