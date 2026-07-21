overview_gps_heatmap_mock_observers <- function() {
  data.table(
    gps_id = c(1L, 2L),
    gps_label = c("MOCK_GPS_A", "MOCK_GPS_B"),
    observer = c("MOCK_OBS_1", "MOCK_OBS_2"),
    name = c("Mock Observer 1", "Mock Observer 2")
  )
}


overview_gps_heatmap_mock_observer_choices <- function() {
  x <- overview_gps_heatmap_mock_observers()

  stats::setNames(
    x$observer,
    glue("{x$observer} ({x$gps_label})")
  )
}


overview_gps_heatmap_mock_tracks <- function(refdate = get_reference_date()) {
  refdate <- as.Date(refdate)

  rbindlist(
    list(
      data.table(
        gps_id = 1L,
        datetime_ = as.POSIXct(
          paste(refdate - 1, c("08:10:00", "08:12:00", "08:14:00", "08:16:00")),
          tz = preferred_timezone
        ),
        # Deliberately fake projected meter coordinates for mock-only testing.
        x_m = c(2500000, 2500024, 2500048, 2500072),
        y_m = c(7500000, 7500020, 7500040, 7500060)
      ),
      data.table(
        gps_id = 1L,
        datetime_ = as.POSIXct(
          paste(refdate - 5, c("09:00:00", "09:02:00", "09:04:00")),
          tz = preferred_timezone
        ),
        x_m = c(2500100, 2500120, 2500140),
        y_m = c(7500060, 7500085, 7500110)
      ),
      data.table(
        gps_id = 2L,
        datetime_ = as.POSIXct(
          paste(refdate - 2, c("10:00:00", "10:02:00", "10:04:00", "10:06:00")),
          tz = preferred_timezone
        ),
        x_m = c(2500040, 2500065, 2500090, 2500115),
        y_m = c(7500140, 7500165, 7500190, 7500215)
      ),
      data.table(
        gps_id = 2L,
        datetime_ = as.POSIXct(
          paste(refdate - 10, c("11:00:00", "11:02:00")),
          tz = preferred_timezone
        ),
        x_m = c(2500200, 2500240),
        y_m = c(7500240, 7500280)
      )
    ),
    use.names = TRUE
  )
}


overview_gps_heatmap_mock_cells <- function(
  refdate = get_reference_date(),
  days_back = 7,
  selected_observers = NULL,
  cell_size = 50
) {
  refdate <- as.Date(refdate)
  days_back <- as.integer(days_back)[1]
  cell_size <- as.numeric(cell_size)[1]

  tracks <- overview_gps_heatmap_mock_tracks(refdate)
  observers <- overview_gps_heatmap_mock_observers()

  x <- merge(
    tracks,
    observers,
    by = "gps_id",
    all.x = TRUE,
    sort = FALSE
  )

  window_start <- as.POSIXct(refdate - days_back, tz = preferred_timezone)
  window_end <- as.POSIXct(refdate, tz = preferred_timezone)

  x <- x[
    datetime_ >= window_start &
      datetime_ < window_end
  ]

  if (!is.null(selected_observers)) {
    if (!length(selected_observers)) {
      x <- x[0]
    } else {
      x <- x[observer %in% selected_observers]
    }
  }

  if (!nrow(x)) {
    return(
      st_sf(
        n_points = integer(),
        observers = character(),
        gps_ids = character(),
        geometry = st_sfc(crs = 4326)
      )
    )
  }

  x[, cell_x := floor(x_m / cell_size) * cell_size]
  x[, cell_y := floor(y_m / cell_size) * cell_size]

  cells <- x[
    ,
    .(
      n_points = .N,
      observers = paste(sort(unique(observer)), collapse = ", "),
      gps_ids = paste(sort(unique(gps_label)), collapse = ", ")
    ),
    by = .(cell_x, cell_y)
  ]

  cell_polygons <- lapply(seq_len(nrow(cells)), function(i) {
    x0 <- cells$cell_x[i]
    y0 <- cells$cell_y[i]

    st_polygon(list(matrix(
      c(
        x0, y0,
        x0 + cell_size, y0,
        x0 + cell_size, y0 + cell_size,
        x0, y0 + cell_size,
        x0, y0
      ),
      ncol = 2,
      byrow = TRUE
    )))
  })

  cells <- st_sf(
    cells[, .(n_points, observers, gps_ids)],
    geometry = st_sfc(cell_polygons, crs = 2193)
  )

  st_transform(cells, 4326)
}


overview_gps_heatmap_leaflet_mock <- function(
  refdate = get_reference_date(),
  days_back = 7,
  selected_observers = NULL
) {
  cells <- overview_gps_heatmap_mock_cells(
    refdate = refdate,
    days_back = days_back,
    selected_observers = selected_observers
  )
  overlay_groups <- character()

  m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |>
    addProviderTiles(providers$CartoDB.PositronNoLabels, group = "Print Map") |>
    addProviderTiles(providers$OpenStreetMap, group = "Street Map") |>
    addProviderTiles(providers$Esri.WorldImagery, group = "Satellite")

  finish_map <- function(map, overlay_groups = character()) {
    map |>
      addLayersControl(
        baseGroups = c("Print Map", "Street Map", "Satellite"),
        overlayGroups = overlay_groups,
        options = layersControlOptions(collapsed = TRUE)
      )
  }

  m <- m |>
    addControl(
      html = tags$div(
        class = "small font-weight-bold",
        HTML("Mock data only.<br>Fake GPS tracks and fake observers.")
      ),
      position = "topright"
    )

  if (!nrow(cells)) {
    m <- m |>
      setView(lng = 0, lat = 0, zoom = 2) |>
      addControl(
        html = tags$div(
          class = "small",
          "No mock track points in the selected window."
        ),
        position = "topright"
      )

    return(finish_map(m, overlay_groups))
  }

  pal <- colorNumeric(
    palette = c("#eef6fb", "#9fd0ea", "#4da6d9", "#1d6fa5", "#0f3d5e"),
    domain = cells$n_points
  )

  cells[, popup := glue(
    "<strong>Mock 50 m cell</strong><br>",
    "Track points: {n_points}<br>",
    "Observers: {htmlEscape(observers)}<br>",
    "GPS units: {htmlEscape(gps_ids)}"
  )]

  m <- m |>
    addPolygons(
      data = cells,
      group = "50 m cells",
      fillColor = ~pal(n_points),
      fillOpacity = 0.78,
      color = "#1d3658",
      weight = 1,
      opacity = 0.9,
      popup = ~popup
    )
  overlay_groups <- c(overlay_groups, "50 m cells")

  plot_bounds <- st_bbox(cells)

  m <- m |>
    fitBounds(
      lng1 = plot_bounds[["xmin"]],
      lat1 = plot_bounds[["ymin"]],
      lng2 = plot_bounds[["xmax"]],
      lat2 = plot_bounds[["ymax"]]
    ) |>
    addLegend(
      position = "bottomright",
      pal = pal,
      values = cells$n_points,
      title = HTML("Mock GPS points<br>per 50 m cell"),
      opacity = 0.85
    )

  finish_map(m, overlay_groups)
}
