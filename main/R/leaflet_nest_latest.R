live_nest_leaflet <- function(
  n = DBq("SELECT * FROM NESTS_LATEST"),
  nest_size = 4
) {
  marker_radius <- pmax(nest_size + 1, 4)
  label_font_size <- pmax(nest_size + 8, 12)
  label_offset <- pmax(round(marker_radius + 4), 8)

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

    htmlwidgets::onRender(map, "window.liveNestLeafletRender")
  }

  n <- data.table(n)

  if (nrow(n) == 0) {
    return(finish_map(m))
  }

  n <- n[!is.na(lat) & !is.na(lon)]

  if (nrow(n) == 0) {
    return(finish_map(m))
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
              "<tr><th>{htmltools::htmlEscape(field)}</th>",
              "<td>{htmltools::htmlEscape(as.character(value[1]))}</td></tr>"
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
    legend_html <- htmltools::tags$details(
      class = "nest-legend",
      htmltools::tags$summary(
        htmltools::tags$span(class = "nest-legend-title", "Nest state")
      ),
      htmltools::tags$div(
        class = "nest-legend-items",
        Map(
          function(label, col) {
            htmltools::tags$div(
              class = "nest-legend-item",
              htmltools::tags$span(
                class = "nest-legend-swatch",
                style = htmltools::css(background = col)
              ),
              htmltools::tags$span(
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

  finish_map(m, "Nests")
}
