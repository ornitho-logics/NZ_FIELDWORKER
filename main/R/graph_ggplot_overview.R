overview_graph <- function(refdate = get_reference_date()) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    SELECT DISTINCT ring, date, study_year AS year
    FROM CAPTURES_ARCHIVE
    WHERE site_code = 'CR'
      AND age = 'A'

    UNION ALL

    SELECT DISTINCT ring, date, YEAR(date) AS year
    FROM CAPTURES
    WHERE site = 'CR'
      AND age = 'A'
      AND date <= ?
    ",
    params = list(as.character(refdate))
  )

  x <- x[,
    .(n = .N),
    by = .(
      year,
      date_std = as.IDate(sprintf("2000-%s", format(date, "%m-%d")))
    )
  ]

  x[,
    year := factor(year, levels = sort(unique(year), decreasing = TRUE))
  ]

  ggplot(x, aes(x = date_std, y = n)) +
    geom_col(width = 0.9) +
    facet_wrap(
      ~year,
      ncol = 1,
      strip.position = "right",
      scales = "free_y"
    ) +
    scale_x_date(
      date_labels = "%d %b",
      date_breaks = "3 days",
      expand = expansion(mult = c(0, 0.01))
    ) +
    scale_y_continuous(
      expand = expansion(mult = c(0, 0.08))
    ) +
    labs(
      x = NULL,
      y = "N individuals captured"
    ) +
    theme_bw(base_size = 22) +
    theme(
      strip.placement = "outside",
      strip.background = element_blank(),

      panel.spacing.y = unit(1.5, "mm"),

      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 30, hjust = 1)
    )
}
