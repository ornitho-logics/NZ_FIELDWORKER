ggplot_map <- function() {
  stusi <- study_site_loader()

  g <- ggplot()

  g <- g + geom_sf(data = stusi, fill = NA, color = "#cacaca")

  g +
    theme_minimal() +
    theme(
      panel.border = element_blank(),
      panel.grid = element_line(colour = "#ffffff", linewidth = 0),
      panel.spacing = unit(c(0, 0, 0, 0), "cm"),
      axis.text.x = element_blank(),
      axis.text.y = element_blank()
    ) +
    ggspatial::annotation_scale(
      location = "bl",
      width_hint = 0.2,
      tick_height = 0.1,
      height = unit(0.1, "cm")
    )
}
