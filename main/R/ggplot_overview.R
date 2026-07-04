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

  if (!nrow(x)) {
    return(
      ggplot() +
        labs(
          x = NULL,
          y = "N found nests"
        ) +
        theme_bw(base_size = 22) +
        theme(
          panel.grid.minor = element_blank()
        )
    )
  }

  setorder(x, datetime, pk)

  x <- x[, .SD[1], by = nest_id]

  setorder(x, datetime)

  ggplot(x, aes(x = datetime)) +
    geom_histogram(
      binwidth = 60 * 60 * 24,

      fill = "#6d7577",
      color = "white"
    ) +
    scale_x_datetime(
      date_labels = "%d %b",
      date_breaks = "3 days"
    ) +

    labs(
      x = NULL,
      y = "N found nests"
    ) +
    theme_bw(base_size = 22) +
    theme(
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 30, hjust = 1)
    )
}
