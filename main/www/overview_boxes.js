(function() {
  $(function() {
    // Use the existing collapse button so AdminLTE and Shiny track visibility.
    $('[id^="overview_"][id$="_show"]').each(function() {
      var header = $(this).closest(".card").children(".card-header");
      var toggle = header.find('[data-card-widget="collapse"]');

      if (!toggle.length) return;

      header.addClass("overview-graph-header");
      header.attr("title", "Click or tap to open or close this graph");
      header.on("click", function(event) {
        // Let existing controls handle their own clicks, without toggling twice.
        if ($(event.target).closest("button, a, input, select, textarea").length) {
          return;
        }
        toggle.trigger("click");
      });
    });
  });
})();
