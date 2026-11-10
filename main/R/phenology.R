# Estimate initiation once per nest, using observations up to the reference date.
phenology_data <- function(date = get_reference_date()) {
  sql <- "
    WITH timing AS (
      SELECT
        TRIM(e.nest_id) AS nest_id,
        DATE_SUB(MAX(e.float_date),
          INTERVAL ROUND(AVG(e.predicted_days_since_laying)) DAY) AS laid
      FROM EGGS_HATCH_PREDICTION e
      WHERE e.float_date <= CAST(? AS DATE)
        AND e.predicted_days_since_laying IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM NESTS n
          WHERE UPPER(TRIM(n.site)) = 'CR'
            AND NULLIF(TRIM(n.nest_id), '') IS NOT NULL
            AND n.nest_id = TRIM(e.nest_id)
        )
      GROUP BY TRIM(e.nest_id)
    )
    SELECT nest_id, laid FROM timing
    WHERE laid IS NOT NULL
    ORDER BY laid, nest_id
  "
  day <- date |> as.Date() |> as.character()
  sql |> db_get(params = list(day)) |> as.data.table()
}


# Count each nest once per initiation day.
phenology_counts <- function(dat, width = 1) {
  dat <- dat |> as.data.table() |> copy()
  empty <- data.table(day = as.Date(character()), nests = integer())
  if (!nrow(dat)) return(empty)
  if (!all(c("nest_id", "laid") %in% names(dat))) {
    stop("Missing phenology fields.", call. = FALSE)
  }
  dat[, let(
    nest_id = nest_id |> as.character() |> str_trim(),
    laid = laid |> as.character() |> as.Date()
  )]
  dat <- dat[
    !is.na(laid) & !is.na(nest_id) &
      !(str_to_upper(nest_id) %in% c("", "NA", "NULL", "N/A", "NO_NEST"))
  ]
  if (!nrow(dat)) return(empty)
  dat[, let(day = as.Date(
    floor(as.numeric(laid) / width) * width + (width - 1) / 2,
    origin = "1970-01-01"
  ))]
  dat[, .(nests = uniqueN(nest_id)), by = day] |> setorder(day)
}


phenology_theme <- function() {
  theme_minimal(base_size = 16) +
    theme(
      plot.background = element_rect(fill = "#F5F8F7", colour = NA),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(colour = "#DDE6E3", linewidth = 0.4),
      plot.title = element_text(face = "bold", size = 24, colour = "#16434A"),
      plot.subtitle = element_text(colour = "#526B6C", margin = margin(b = 20)),
      plot.title.position = "plot",
      axis.text = element_text(colour = "#354F52"),
      axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),
      axis.title.y = element_text(margin = margin(r = 12)),
      plot.margin = margin(20, 24, 18, 18)
    )
}


phenology_plot <- function(dat, date = get_reference_date(), deployments = data.table()) {
  nests <- dat |> phenology_counts()
  tags <- deployments |> as.data.table() |> copy()
  if (!nrow(tags)) tags <- data.table(day = as.Date(character()), tags = integer())
  tags[, let(day = day |> as.character() |> as.Date())]
  panels <- c("Nest initiations", "Geolocator deployments")
  counts <- list(
    nests[, .(day, count = as.numeric(nests), panel = panels[1])],
    tags[, .(day, count = as.numeric(tags), panel = panels[2])]
  ) |> rbindlist()
  counts[, let(panel = factor(panel, levels = panels))]
  day <- date |> as.Date()
  span <- if (nrow(counts)) {
    c(min(counts$day) - 1, max(day, counts$day) + 1)
  } else c(day - 30, day + 1)
  blank <- data.table(day = day, count = 0, panel = factor(panels, levels = panels))

  ggplot(counts, aes(day, count)) +
    geom_col(width = 0.82, fill = "black") +
    geom_blank(data = blank) +
    geom_vline(xintercept = day, colour = "#A94E28", linetype = "dashed") +
    facet_wrap(
      vars(panel), ncol = 1, scales = "free_y", drop = FALSE,
      axes = "all_x", axis.labels = "all_x"
    ) +
    scale_x_date(date_labels = "%d %b", date_breaks = "1 day") +
    scale_y_continuous(
      breaks = function(limits) {
        marks <- limits |> pretty(n = 5)
        marks[marks >= 0 & marks == floor(marks)]
      },
      expand = expansion(mult = c(0, 0.12))
    ) +
    coord_cartesian(xlim = span) +
    labs(
      title = "Nest initiation and geolocator deployments",
      subtitle = glue("Cass River  ·  {sum(nests$nests)} nests  ·  {sum(tags$tags)} deployments  ·  {format(day, '%d %b %Y')}"),
      x = NULL, y = "Count / day"
    ) +
    phenology_theme() +
    theme(strip.text = element_text(face = "bold", hjust = 0, colour = "black"))
}


# New deployments and replacement devices, counted by actual handling date.
geo_data <- function(date = get_reference_date()) {
  sql <- "
    SELECT date AS day, COUNT(DISTINCT TRIM(tag_id)) AS tags
    FROM CAPTURES
    WHERE UPPER(TRIM(site)) = 'CR'
      AND UPPER(TRIM(age)) = 'A'
      AND UPPER(TRIM(tag_type)) = 'GEO'
      AND UPPER(TRIM(tag_action)) IN ('D', 'N')
      AND NULLIF(TRIM(tag_id), '') IS NOT NULL
      AND UPPER(TRIM(tag_id)) <> 'NA'
      AND date <= CAST(? AS DATE)
    GROUP BY date
    ORDER BY date
  "
  sql |> db_get(params = list(date |> as.Date() |> as.character())) |> as.data.table()
}


phenology_server <- function(input, output, session, refdate) {
  output$overview_lay_date_show <- renderPlot({
    req(identical(input$main, "overview"))
    day <- refdate()
    try_else(
      day |> phenology_data() |> phenology_plot(date = day, deployments = geo_data(day)),
      fallback_ggplot,
      fail = "Phenology unavailable."
    )
  })
}
