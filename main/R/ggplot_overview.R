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


overview_quota_pie_plot <- function(title, value, quota, fill = "#6d7577") {
  value <- as.integer(value %||% 0L)
  quota <- as.integer(quota)

  shown_value <- max(value, 0L)
  filled_value <- min(shown_value, quota)

  x <- data.table(
    segment = factor(
      c("filled", "remaining"),
      levels = c("filled", "remaining")
    ),
    n = c(filled_value, quota - filled_value)
  )

  ggplot(
    x,
    aes(x = "", y = n, fill = segment)
  ) +
    geom_col(
      width = 1,
      color = "#8b9395",
      linewidth = 0.35
    ) +
    coord_polar(theta = "y") +
    scale_fill_manual(
      values = c(
        filled = fill,
        remaining = "white"
      )
    ) +
    guides(fill = "none") +
    labs(
      title = title,
      subtitle = glue("{shown_value} / {quota}")
    ) +
    theme_void(base_size = 16) +
    theme(
      plot.title = element_text(
        hjust = 0.5,
        face = "bold",
        size = 16
      ),
      plot.subtitle = element_text(
        hjust = 0.5,
        face = "bold",
        size = 13
      )
    )
}


overview_quota_graph <- function(refdate = get_reference_date()) {
  refdate <- as.Date(refdate)

  geolocators <- db_get(
    "
    SELECT COUNT(DISTINCT pk) AS n
    FROM CAPTURES
    WHERE tag_type = 'GEO'
      AND tag_action = 'D'
      AND date IS NOT NULL
      AND date <= ?
    ",
    params = list(as.character(refdate))
  )

  non_geolocators <- db_get(
    "
    SELECT COUNT(DISTINCT pk) AS n
    FROM CAPTURES
    WHERE age = 'A'
      AND date IS NOT NULL
      AND date <= ?
      AND (
        NULLIF(TRIM(blood_samp), '') IS NOT NULL
        OR breast_samp = '1'
        OR primary_samp = '1'
      )
      AND (
        NULLIF(TRIM(tag_id), '') IS NULL
        OR tag_action = 'O'
      )
    ",
    params = list(as.character(refdate))
  )

  chicks <- db_get(
    "
    SELECT COUNT(DISTINCT pk) AS n
    FROM CAPTURES
    WHERE age = 'C'
      AND date IS NOT NULL
      AND date <= ?
      AND NULLIF(TRIM(blood_samp), '') IS NOT NULL
    ",
    params = list(as.character(refdate))
  )

  eggs <- db_get(
    "
    SELECT COUNT(
      DISTINCT CONCAT(TRIM(nest_id), '|', egg_id)
    ) AS n
    FROM EGGS
    WHERE date IS NOT NULL
      AND date <= ?
      AND NULLIF(TRIM(nest_id), '') IS NOT NULL
      AND egg_id IS NOT NULL
    ",
    params = list(as.character(refdate))
  )

  quota_counts <- data.table(
    title = c(
      "Eggs floated",
      "Geolocators deployed",
      "Non-geolocator captures",
      "Chicks processed"
    ),
    value = c(
      eggs$n[1] %||% 0L,
      geolocators$n[1] %||% 0L,
      non_geolocators$n[1] %||% 0L,
      chicks$n[1] %||% 0L
    ),
    quota = c(450L, 100L, 200L, 500L)
  )

  plots <- lapply(
    seq_len(nrow(quota_counts)),
    function(i) {
      overview_quota_pie_plot(
        title = quota_counts$title[i],
        value = quota_counts$value[i],
        quota = quota_counts$quota[i]
      )
    }
  )

  grid::grid.newpage()
  grid::pushViewport(
    grid::viewport(
      layout = grid::grid.layout(
        nrow = 1,
        ncol = length(plots)
      )
    )
  )

  for (i in seq_along(plots)) {
    print(
      plots[[i]],
      vp = grid::viewport(
        layout.pos.row = 1,
        layout.pos.col = i
      )
    )
  }

  invisible(plots)
}
