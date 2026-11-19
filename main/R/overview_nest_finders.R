overview_nest_finders_included_codes <- c("BK", "LEH", "ADO", "KD", "KM", "BJ", "KT", "P3", "EK", "MV", "AW")


overview_nest_finders_data <- function(refdate = get_reference_date()) {
  # Aggregate in SQL: repeated Found records credit only the first finder.
  x <- data.table(db_get(
    "
    WITH discoveries AS (
      SELECT
        CASE WHEN observer IS NULL OR UPPER(TRIM(observer)) IN ('', 'NA', 'NULL', 'N/A')
          THEN 'Unrecorded' ELSE UPPER(TRIM(observer)) END AS observer_code,
        date AS found_date,
        ROW_NUMBER() OVER (
          PARTITION BY UPPER(TRIM(nest_id))
          ORDER BY date, COALESCE(time_visit, '00:00:00'), pk
        ) AS discovery_rank
      FROM NESTS
      WHERE UPPER(TRIM(site)) = 'CR'
        AND nest_state = 'F'
        AND date IS NOT NULL AND date <= ?
        AND NULLIF(TRIM(nest_id), '') IS NOT NULL
        AND UPPER(TRIM(nest_id)) NOT IN ('NA', 'NULL', 'N/A', 'NO_NEST')
        AND TRIM(nest_id) NOT LIKE '-%'
    ), counts AS (
      SELECT observer_code, COUNT(*) AS n_found,
        MIN(found_date) AS first_found, MAX(found_date) AS last_found
      FROM discoveries WHERE discovery_rank = 1
      GROUP BY observer_code
    ), contributors AS (
      SELECT UPPER(TRIM(observer)) AS observer_code,
        MIN(NULLIF(TRIM(name), '')) AS contributor_name,
        MIN(start) AS field_start,
        CASE WHEN COUNT(*) > COUNT(stop) THEN NULL ELSE MAX(stop) END AS field_stop
      FROM OBSERVERS
      WHERE NULLIF(TRIM(observer), '') IS NOT NULL
        AND UPPER(TRIM(observer)) NOT IN ('NA', 'NULL', 'N/A')
      GROUP BY UPPER(TRIM(observer))
    ), all_codes AS (
      SELECT observer_code FROM contributors
      UNION
      SELECT observer_code FROM counts
    )
    SELECT a.observer_code,
      CASE WHEN o.contributor_name IS NOT NULL
        THEN CONCAT(o.contributor_name, ' (', a.observer_code, ')')
        ELSE a.observer_code END AS contributor,
      COALESCE(c.n_found, 0) AS n_found,
      c.first_found, c.last_found, o.field_start, o.field_stop
    FROM all_codes a
    LEFT JOIN contributors o ON o.observer_code = a.observer_code
    LEFT JOIN counts c ON c.observer_code = a.observer_code
    ORDER BY n_found DESC, contributor, a.observer_code
    ",
    params = list(as.character(as.Date(refdate)))
  ))

  required <- c("observer_code", "contributor", "n_found", "first_found", "last_found",
                "field_start", "field_stop")
  if (!all(required %in% names(x)) || "error" %in% names(x)) {
    stop("Nest-finding data could not be loaded.", call. = FALSE)
  }
  x[, observer_code := toupper(trimws(as.character(observer_code)))]
  x <- x[observer_code %in% overview_nest_finders_included_codes]
  roster <- data.table(observer_code = overview_nest_finders_included_codes)
  x <- merge(roster, x, by = "observer_code", all.x = TRUE, sort = FALSE)
  x[is.na(n_found), n_found := 0]
  x[is.na(contributor) | !nzchar(trimws(contributor)), contributor := observer_code]
  x
}


overview_nest_finders_plot <- function(x, refdate = get_reference_date()) {
  x <- copy(as.data.table(x))
  x[, observer_code := toupper(trimws(as.character(observer_code)))]
  x[, n_found := as.numeric(n_found)]
  x <- x[!is.na(n_found) & n_found >= 0 &
    observer_code %in% overview_nest_finders_included_codes]
  if (!nrow(x)) {
    return(ggplot() +
      annotate("text", x = 0, y = 0, label = "No contributors to show yet", size = 5) +
      theme_void())
  }
  for (column in c("field_start", "field_stop", "first_found", "last_found")) {
    x[, (column) := as.Date(as.character(get(column)))]
  }
  x[, end_date := pmin(field_stop, as.Date(refdate), na.rm = TRUE)]
  x[, field_days := as.numeric(end_date - field_start) + 1]
  # Dates must cover the discoveries; incomplete/inconsistent stints cannot
  # provide a defensible daily rate. Count both arrival and departure days.
  x[is.na(field_start) | field_days <= 0 |
      (n_found > 0 & (is.na(first_found) | is.na(last_found) |
        first_found < field_start | last_found > end_date)),
    field_days := NA_real_]
  x[, nests_per_day := n_found / field_days]
  setorder(x, -nests_per_day, -n_found, contributor, observer_code, na.last = TRUE)
  x[, podium_rank := NA_real_]
  x[!is.na(nests_per_day) & nests_per_day > 0,
    podium_rank := data.table::frank(-nests_per_day, ties.method = "min")]
  x[, display_name := contributor]
  x[, display_name := factor(display_name, levels = rev(unique(display_name)))]
  x[, bar_value := nests_per_day]
  x[is.na(bar_value), bar_value := 0]
  x[, total_label := paste(n_found, ifelse(n_found == 1, "nest", "nests"))]
  x[!is.na(nests_per_day), total_label := paste(
    total_label, "/", field_days, ifelse(field_days == 1, "day", "days")
  )]
  x[is.na(nests_per_day), total_label := paste0(total_label, " (rate unavailable)")]
  x[, bar_colour := "#53a89a"]
  x[podium_rank == 1, bar_colour := "#e8b62c"]
  x[podium_rank == 2, bar_colour := "#9aaabb"]
  x[podium_rank == 3, bar_colour := "#c68850"]

  # Draw medals from shapes and ordinary digits, avoiding emoji font support.
  medals <- x[!is.na(podium_rank) & podium_rank <= 3]
  medal_scale <- max(c(x$bar_value, 0.1))
  medals[, `:=`(
    medal_x = -0.12 * medal_scale,
    ribbon_left = -0.15 * medal_scale,
    ribbon_right = -0.09 * medal_scale,
    ribbon_y = as.numeric(display_name) - 0.28
  )]

  ggplot(x, aes(x = bar_value, y = display_name)) +
    geom_col(aes(fill = bar_colour), width = 0.65, show.legend = FALSE) +
    geom_segment(data = medals,
      aes(x = medal_x, y = display_name, xend = ribbon_left, yend = ribbon_y,
          colour = bar_colour), inherit.aes = FALSE, linewidth = 2.5, show.legend = FALSE) +
    geom_segment(data = medals,
      aes(x = medal_x, y = display_name, xend = ribbon_right, yend = ribbon_y,
          colour = bar_colour), inherit.aes = FALSE, linewidth = 2.5, show.legend = FALSE) +
    geom_point(data = medals, aes(x = medal_x, y = display_name, fill = bar_colour),
      inherit.aes = FALSE, shape = 21, size = 9, stroke = 0.8, colour = "#66502b",
      show.legend = FALSE) +
    geom_text(data = medals, aes(x = medal_x, y = display_name, label = podium_rank),
      inherit.aes = FALSE, size = 4, fontface = "bold", colour = "#302719") +
    scale_fill_identity() +
    scale_colour_identity() +
    geom_text(aes(label = total_label), hjust = -0.15, size = 4.5, fontface = "bold") +
    scale_x_continuous(
      breaks = function(limits) {
        ticks <- pretty(c(0, max(limits)), n = 5)
        ticks[ticks >= 0]
      },
      expand = expansion(mult = c(0.06, 0.45))
    ) +
    labs(title = "The Great Cass Nest Quest",
         x = "Nests / day in field", y = NULL,
         subtitle = paste("Nests found through", format(as.Date(refdate), "%d %b %Y"))) +
    theme_minimal(base_size = 16) +
    theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
          plot.background = element_rect(fill = "#fffaf0", colour = NA),
          plot.title = element_text(face = "bold", colour = "#c62828"),
          axis.text.y = element_text(face = "bold", colour = "#26443f"))

}


overview_nest_finders_graph <- function(refdate = get_reference_date()) {
  overview_nest_finders_plot(overview_nest_finders_data(refdate), refdate)
}
