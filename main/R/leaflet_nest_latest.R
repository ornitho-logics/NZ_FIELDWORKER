.prepare_plots <- function(plots) {
  empty_plots <- st_sf(
    plot_name = character(),
    geometry = st_sfc(crs = 4326)
  )

  tryCatch(
    {
      plot_wkt <- eval(parse(text = plots$value[1]))

      st_sf(
        plot_name = names(plot_wkt),
        geometry = st_as_sfc(unlist(plot_wkt), crs = 4326)
      )
    },
    error = function(e) empty_plots
  )
}


live_nest_leaflet <- function(
  n = DBq("SELECT * FROM NESTS_LATEST"),
  plots = DBq("SELECT * FROM spatial_objects where variable = 'study_area' "),
  nest_size = 4
) {
  marker_radius <- pmax(nest_size + 1, 4)
  label_font_size <- pmax(nest_size + 8, 12)
  label_offset <- pmax(round(marker_radius + 4), 8)
  plots <- .prepare_plots(plots)
  overlay_groups <- character()

  m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |>
    addProviderTiles(providers$CartoDB.PositronNoLabels, group = "Print Map") |>
    addProviderTiles(providers$OpenStreetMap, group = "Street Map") |>
    addProviderTiles(providers$Esri.WorldImagery, group = "Satellite")

  finish_map <- function(map, overlay_groups = character()) {
    map <- map |>
      addLayersControl(
        baseGroups = c("Print Map", "Street Map", "Satellite"),
        overlayGroups = overlay_groups,
        options = layersControlOptions(collapsed = TRUE)
      )

    onRender(map, "window.liveNestLeafletRender")
  }

  if (nrow(plots)) {
    m <- m |>
      addPolygons(
        data = plots,
        group = "Plots",
        label = ~plot_name,
        labelOptions = labelOptions(
          permanent = TRUE,
          direction = "center",
          textOnly = TRUE,
          opacity = 0.55,
          style = list(
            "color" = "#64748b",
            "font-size" = "10px",
            "font-weight" = "500",
            "letter-spacing" = "0.03em",
            "pointer-events" = "none",
            "text-shadow" = "0 0 3px rgba(255, 255, 255, 0.95)"
          )
        ),
        color = "#d70427",
        weight = 1,
        opacity = 0.65,
        dashArray = "4 4",
        fill = FALSE,
        options = pathOptions(className = "plot-boundary")
      )

    overlay_groups <- c(overlay_groups, "Plots")
  }

  n <- data.table(n)

  if (nrow(n) == 0) {
    if (nrow(plots)) {
      plot_bounds <- st_bbox(plots)
      m <- m |>
        fitBounds(
          lng1 = plot_bounds[["xmin"]],
          lat1 = plot_bounds[["ymin"]],
          lng2 = plot_bounds[["xmax"]],
          lat2 = plot_bounds[["ymax"]]
        )
    }

    return(finish_map(m, overlay_groups))
  }

  n <- n[!is.na(lat) & !is.na(lon)]

  if (nrow(n) == 0) {
    if (nrow(plots)) {
      plot_bounds <- st_bbox(plots)
      m <- m |>
        fitBounds(
          lng1 = plot_bounds[["xmin"]],
          lat1 = plot_bounds[["ymin"]],
          lng2 = plot_bounds[["xmax"]],
          lat2 = plot_bounds[["ymax"]]
        )
    }

    return(finish_map(m, overlay_groups))
  }

  n[, marker_col := nest_state_cols[as.character(nest_state)]]
  n[is.na(marker_col), marker_col := "#999999"]
  n[,
    label_text := fifelse(
      is.na(nest_id) | !nzchar(as.character(nest_id)),
      "unknown nest",
      as.character(nest_id)
    )
  ]

  popup_cols <- setdiff(names(n), c("lat", "lon", "marker_col", "label_text"))

  n[,
    popup := vapply(
      seq_len(.N),
      function(i) {
        row <- as.list(.SD[i])
        keep <- vapply(
          row,
          function(value) {
            !is.na(value[1]) &&
              nzchar(as.character(value[1]))
          },
          logical(1)
        )

        row <- row[keep]

        if (!length(row)) {
          return("")
        }

        rows <- Map(
          function(field, value) {
            glue(
              "<tr><th>{htmlEscape(field)}</th>",
              "<td>{htmlEscape(as.character(value[1]))}</td></tr>"
            )
          },
          names(row),
          row
        )

        glue(
          "<table class='table table-sm table-striped mb-0'>",
          "{glue_collapse(rows)}",
          "</table>"
        )
      },
      character(1)
    ),
    .SDcols = popup_cols
  ]

  state_cols <- n[
    !is.na(nest_state),
    .(col = marker_col[1]),
    by = nest_state
  ]
  state_cols[, state_order := match(nest_state, names(nest_state_cols))]
  state_cols[is.na(state_order), state_order := .Machine$integer.max]
  setorder(state_cols, state_order, nest_state)

  m <- m |>
    addCircleMarkers(
      data = n,
      group = "Nests",
      lng = ~lon,
      lat = ~lat,
      label = ~label_text,
      labelOptions = labelOptions(
        permanent = TRUE,
        className = "nest-label",
        direction = "right",
        offset = c(label_offset, 0),
        textOnly = TRUE,
        style = list(
          "font-weight" = "700",
          "font-size" = glue("{label_font_size}px"),
          "color" = "#1f2933",
          "text-shadow" = "0 1px 2px #ffffff"
        )
      ),
      popup = ~popup,
      radius = marker_radius,
      stroke = TRUE,
      weight = 1,
      color = "#1d3658",
      fillColor = ~marker_col,
      fillOpacity = 0.8,
      options = pathOptions(className = "nest-circle-marker")
    )
  overlay_groups <- c(overlay_groups, "Nests")

  if (nrow(n) == 1) {
    m <- m |>
      setView(
        lng = n$lon[1],
        lat = n$lat[1],
        zoom = 15
      )
  } else {
    m <- m |>
      fitBounds(
        lng1 = min(n$lon),
        lat1 = min(n$lat),
        lng2 = max(n$lon),
        lat2 = max(n$lat)
      )
  }

  if (nrow(state_cols) > 0) {
    legend_html <- tags$details(
      class = "nest-legend",
      tags$summary(
        tags$span(class = "nest-legend-title", "State")
      ),
      tags$div(
        class = "nest-legend-items",
        Map(
          function(label, col) {
            tags$div(
              class = "nest-legend-item",
              tags$span(
                class = "nest-legend-swatch",
                style = css(background = col)
              ),
              tags$span(
                class = "nest-legend-label",
                as.character(label)
              )
            )
          },
          state_cols$nest_state,
          state_cols$col
        )
      )
    )

    m <- m |>
      addControl(
        html = legend_html,
        position = "topleft",
        layerId = "nest_state_legend",
        className = "nest-legend-control"
      )
  }

  finish_map(m, overlay_groups)
}
