overview_graph <- function() {
  x <- OVERVIEW()

  ggplot(x, aes(x = date_std, y = n)) +
    geom_col(width = 0.9) +
    facet_wrap(
      ~year,
      ncol = 1,
      strip.position = "right"
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
      title = "Cass River",
      x = NULL,
      y = "N individuals captured"
    ) +
    theme_bw(base_size = 22) +
    theme(
      strip.placement = "outside",
      strip.background = element_blank(),

      panel.spacing.y = unit(1.5, "mm"),

      panel.grid.minor = element_blank()
    )
}
