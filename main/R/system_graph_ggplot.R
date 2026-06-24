sys_graph <- function() {
  ggplot() +
    annotate(
      "text",
      x = 0,
      y = 0,
      label = "There are no data available to plot!"
    ) +
    theme_void()
}
