# Compare each previous year's adult Cass cohort with this year's captures.
overview_recapture_cohorts_data <- function(refdate = get_reference_date()) {
  refdate <- as.Date(refdate)
  year <- as.integer(format(refdate, "%Y"))
  start <- as.Date(paste0(year, "-01-01"))
  history_start <- as.Date(paste0(year - 2L, "-01-01"))

  # Retrieve aggregate counts only; UNION removes repeated captures and overlap
  # between the archive and current table within each year's cohort.
  data.table(db_get(
    "
    WITH years AS (
      SELECT YEAR(CAST(? AS DATE)) - 2 AS cohort_year
      UNION ALL
      SELECT YEAR(CAST(? AS DATE)) - 1
    ), history AS (
      SELECT YEAR(date) AS cohort_year,
        REPLACE(UPPER(TRIM(ring)), '-', '') AS ring_key
      FROM CAPTURES_ARCHIVE
      WHERE UPPER(TRIM(site_code)) = 'CR'
        AND UPPER(TRIM(age)) = 'A'
        AND date >= ? AND date < ?
      UNION
      SELECT YEAR(date) AS cohort_year,
        REPLACE(UPPER(TRIM(ring)), '-', '') AS ring_key
      FROM CAPTURES
      WHERE UPPER(TRIM(site)) = 'CR'
        AND UPPER(TRIM(age)) = 'A'
        AND date >= ? AND date < ?
    ), current_birds AS (
      SELECT DISTINCT REPLACE(UPPER(TRIM(ring)), '-', '') AS ring_key
      FROM CAPTURES
      WHERE UPPER(TRIM(site)) = 'CR'
        AND UPPER(TRIM(age)) = 'A'
        AND date >= ? AND date <= ?
    )
    SELECT y.cohort_year,
      COUNT(DISTINCT h.ring_key) AS n_previous,
      COUNT(DISTINCT c.ring_key) AS n_recaptured
    FROM years y
    LEFT JOIN history h ON h.cohort_year = y.cohort_year
      AND h.ring_key IS NOT NULL AND h.ring_key NOT IN ('', 'NA')
    LEFT JOIN current_birds c ON c.ring_key = h.ring_key
    GROUP BY y.cohort_year
    ORDER BY y.cohort_year
    ",
    params = list(
      as.character(start), as.character(start),
      as.character(history_start), as.character(start),
      as.character(history_start), as.character(start),
      as.character(start), as.character(refdate)
    )
  ))
}


overview_recapture_cohorts_plot <- function(x, refdate = get_reference_date()) {
  x <- copy(as.data.table(x))
  x[, let(
    n_previous = as.numeric(n_previous),
    n_recaptured = as.numeric(n_recaptured)
  )]
  x[, proportion := fifelse(n_previous > 0, n_recaptured / n_previous, NA_real_)]
  x[, label := fifelse(
    n_previous > 0,
    sprintf("%d / %d (%.1f%%)", n_recaptured, n_previous, 100 * proportion),
    "No previous captures"
  )]
  x[, cohort_label := factor(
    paste(cohort_year, label, sep = "\n"),
    levels = paste(cohort_year, label, sep = "\n")
  )]
  slices <- data.table::rbindlist(list(
    x[, .(cohort_label, status = "Recaptured", fraction = proportion)],
    x[, .(cohort_label, status = "Not yet recaptured", fraction = 1 - proportion)]
  ))
  # An empty cohort has no pie: its heading explains the missing denominator.
  slices <- slices[!is.na(fraction)]
  slices[, status := factor(status, levels = c("Recaptured", "Not yet recaptured"))]

  ggplot(x) +
    geom_col(data = slices, aes(x = "", y = fraction, fill = status),
             width = 1, colour = "white", linewidth = 0.6) +
    facet_wrap(vars(cohort_label), nrow = 1, drop = FALSE) +
    coord_polar(theta = "y") +
    scale_y_continuous(limits = c(0, 1), expand = expansion(mult = 0)) +
    scale_fill_manual(values = c("Recaptured" = "#3480be",
                                 "Not yet recaptured" = "#e2e8f0"), drop = FALSE) +
    labs(
      x = NULL, y = NULL, fill = NULL,
      subtitle = paste("Adult Cass recaptures through", format(as.Date(refdate), "%d %b %Y"))
    ) +
    theme_void(base_size = 18) +
    theme(strip.text = element_text(size = 15, face = "bold"),
          legend.position = "bottom", legend.text = element_text(size = 13))
}


overview_recapture_cohorts_graph <- function(refdate = get_reference_date()) {
  overview_recapture_cohorts_plot(overview_recapture_cohorts_data(refdate), refdate)
}
