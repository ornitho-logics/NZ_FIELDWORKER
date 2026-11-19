# Compare each previous year's adult Cass cohort with this year's captures.
overview_recapture_cohorts_data <- function(
  refdate = get_reference_date(), include_resightings = FALSE,
  pool_years = FALSE
) {
  refdate <- as.Date(refdate)
  year <- as.integer(format(refdate, "%Y"))
  start <- as.Date(paste0(year, "-01-01"))
  history_start <- as.Date(paste0(year - 2L, "-01-01"))

  resighting_ctes <- if (include_resightings) "
    , mark_history AS (
      SELECT REPLACE(UPPER(TRIM(ring)), '-', '') AS ring_key,
        UPPER(TRIM(COALESCE(UL, ''))) AS ul_key,
        UPPER(TRIM(COALESCE(LL, ''))) AS ll_key,
        UPPER(TRIM(COALESCE(UR, ''))) AS ur_key,
        UPPER(TRIM(COALESCE(LR, ''))) AS lr_key
      FROM CAPTURES_ARCHIVE
      WHERE UPPER(TRIM(site_code)) = 'CR' AND date < ?
      UNION
      SELECT REPLACE(UPPER(TRIM(ring)), '-', ''),
        UPPER(TRIM(COALESCE(UL, ''))), UPPER(TRIM(COALESCE(LL, ''))),
        UPPER(TRIM(COALESCE(UR, ''))), UPPER(TRIM(COALESCE(LR, '')))
      FROM CAPTURES
      WHERE UPPER(TRIM(site)) = 'CR' AND date <= ?
    ), unique_marks AS (
      SELECT ul_key, ll_key, ur_key, lr_key, MIN(ring_key) AS ring_key
      FROM mark_history
      WHERE ring_key IS NOT NULL AND ring_key NOT IN ('', 'NA')
        AND ll_key NOT IN ('', 'X', 'NA') AND lr_key NOT IN ('', 'X', 'NA')
        AND CONCAT(ul_key, ll_key, ur_key, lr_key) NOT LIKE '%?%'
      GROUP BY ul_key, ll_key, ur_key, lr_key
      HAVING COUNT(DISTINCT ring_key) = 1
    ), sighted_birds AS (
      SELECT DISTINCT
        CASE WHEN REPLACE(UPPER(TRIM(r.ring)), '-', '') NOT IN ('', 'NA')
          THEN REPLACE(UPPER(TRIM(r.ring)), '-', '')
          ELSE m.ring_key END AS ring_key
      FROM RESIGHTINGS r
      LEFT JOIN unique_marks m
        ON UPPER(TRIM(COALESCE(r.UL, ''))) = m.ul_key
        AND UPPER(TRIM(COALESCE(r.LL, ''))) = m.ll_key
        AND UPPER(TRIM(COALESCE(r.UR, ''))) = m.ur_key
        AND UPPER(TRIM(COALESCE(r.LR, ''))) = m.lr_key
      WHERE UPPER(TRIM(r.site)) = 'CR' AND UPPER(TRIM(r.age)) = 'A'
        AND r.date >= ? AND r.date <= ?
    ), encountered_birds AS (
      SELECT ring_key FROM current_birds
      UNION
      SELECT ring_key FROM sighted_birds
    )
  " else ""

  params <- list(
    as.character(start), as.character(start),
    as.character(history_start), as.character(start),
    as.character(history_start), as.character(start),
    as.character(start), as.character(refdate)
  )
  if (include_resightings) {
    params <- c(params, as.list(as.character(c(start, refdate, start, refdate))))
  }

  # Retrieve aggregate counts only; UNION removes repeated captures and overlap
  # between the archive and current table within each year's cohort.
  data.table(db_get(
    paste0("
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
    )", resighting_ctes, "
    SELECT ", if (pool_years) {
      paste0("'", year - 2L, "–", year - 1L, "'")
    } else "y.cohort_year", " AS cohort_year,
      COUNT(DISTINCT h.ring_key) AS n_previous,
      COUNT(DISTINCT c.ring_key) AS n_recaptured
    FROM ", if (pool_years) {
      "(SELECT MIN(cohort_year) AS cohort_year FROM years) y"
    } else "years y", "
    LEFT JOIN history h ON h.cohort_year ", if (pool_years) ">=" else "=", " y.cohort_year
      AND h.ring_key IS NOT NULL AND h.ring_key NOT IN ('', 'NA')
    LEFT JOIN ", if (include_resightings) "encountered_birds" else "current_birds", " c ON c.ring_key = h.ring_key
    ", if (!pool_years) "GROUP BY y.cohort_year ORDER BY y.cohort_year" else "", "
    "),
    params = params
  ))
}


overview_recapture_cohorts_plot <- function(
  x, refdate = get_reference_date(), include_resightings = FALSE
) {
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

  plot <- ggplot(x) +
    geom_col(data = slices, aes(x = "", y = fraction, fill = status),
             width = 1, colour = "white", linewidth = 0.6) +
    facet_wrap(vars(cohort_label), nrow = 1, drop = FALSE) +
    coord_polar(theta = "y") +
    scale_y_continuous(limits = c(0, 1), expand = expansion(mult = 0)) +
    scale_fill_manual(values = c("Recaptured" = "#3480be",
                                 "Not yet recaptured" = "#e2e8f0"),
                      limits = c("Recaptured", "Not yet recaptured"),
                      labels = if (include_resightings) {
                        c("Captured or resighted", "Not yet encountered")
                      } else {
                        c("Recaptured", "Not yet recaptured")
                      }, drop = FALSE) +
    labs(
      x = NULL, y = NULL, fill = NULL,
      subtitle = paste("Adult Cass recaptures through", format(as.Date(refdate), "%d %b %Y"))
    ) +
    theme_void(base_size = 18) +
    theme(strip.text = element_text(size = 15, face = "bold"),
          legend.position = "bottom", legend.text = element_text(size = 13))
  if (include_resightings) {
    plot <- plot +
      labs(subtitle = paste("Adult Cass captures or resightings through",
                            format(as.Date(refdate), "%d %b %Y")),
           caption = paste("CAPTURES + RESIGHTINGS only; each bird counts once per cohort.",
             "Resightings matched by metal ring or an unambiguous complete colour-band combination.")) +
      theme(plot.caption = element_text(size = 10))
  }
  plot
}


overview_recapture_cohorts_graph <- function(refdate = get_reference_date()) {
  overview_recapture_cohorts_plot(overview_recapture_cohorts_data(refdate), refdate)
}


overview_encounter_cohorts_graph <- function(refdate = get_reference_date()) {
  overview_recapture_cohorts_plot(
    overview_recapture_cohorts_data(
      refdate, include_resightings = TRUE, pool_years = TRUE
    ),
    refdate, include_resightings = TRUE
  )
}
