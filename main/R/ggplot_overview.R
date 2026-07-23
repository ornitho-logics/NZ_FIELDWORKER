overview_histogram_base <- function(ylab) {
  ggplot() +
    labs(
      x = NULL,
      y = ylab
    ) +
    theme_bw(base_size = 22) +
    theme(
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 30, hjust = 1)
    )
}


overview_histogram_plot <- function(x, ylab) {
  x <- data.table(x)

  if (!nrow(x)) {
    return(overview_histogram_base(ylab))
  }

  x <- x[!is.na(datetime)]

  if (!nrow(x)) {
    return(overview_histogram_base(ylab))
  }

  setorder(x, datetime)

  overview_histogram_base(ylab) +
    geom_histogram(
      data = x,
      mapping = aes(x = datetime),
      binwidth = 60 * 60 * 24,
      fill = "#6d7577",
      color = "white"
    ) +
    scale_x_datetime(
      date_labels = "%d %b",
      date_breaks = "3 days"
    )
}


overview_graph <- function(refdate = get_reference_date()) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    SELECT
      pk,
      nest_id,
      CAST(CONCAT(date, ' ', COALESCE(time_visit, '00:00:00')) AS DATETIME) AS datetime
    FROM NESTS
    WHERE nest_state = 'F'
      AND date IS NOT NULL
      AND date <= ?
    ORDER BY date, time_visit, pk
    ",
    params = list(as.character(refdate))
  )

  x <- data.table(x)

  if (nrow(x)) {
    setorder(x, datetime, pk)
    x <- x[, .SD[1], by = nest_id]
  }

  overview_histogram_plot(
    x = x,
    ylab = "N found nests"
  )
}


overview_geolocator_graph <- function(refdate = get_reference_date()) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    SELECT
      pk,
      tag_id,
      CAST(CONCAT(date, ' 00:00:00') AS DATETIME) AS datetime
    FROM CAPTURES
    WHERE tag_type = 'GEO'
      AND tag_action = 'D'
      AND date IS NOT NULL
      AND date <= ?
      AND NULLIF(TRIM(tag_id), '') IS NOT NULL
    ORDER BY date, pk
    ",
    params = list(as.character(refdate))
  )

  x <- data.table(x)

  if (nrow(x)) {
    setorder(x, datetime, pk)
    x <- x[, .SD[1], by = tag_id]
  }

  overview_histogram_plot(
    x = x,
    ylab = "Number of geolocators deployed"
  )
}


overview_lay_date_graph <- function(refdate = get_reference_date()) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    SELECT
      nest_id,
      CAST(
        CONCAT(
          DATE_SUB(
            MAX(float_date),
            INTERVAL ROUND(AVG(predicted_days_since_laying)) DAY
          ),
          ' 00:00:00'
        ) AS DATETIME
      ) AS datetime
    FROM EGGS_HATCH_PREDICTION
    WHERE float_date IS NOT NULL
      AND predicted_days_since_laying IS NOT NULL
      AND float_date <= ?
    GROUP BY nest_id
    ORDER BY datetime, nest_id
    ",
    params = list(as.character(refdate))
  )

  overview_histogram_plot(
    x = x,
    ylab = "N estimated lay dates"
  )
}
