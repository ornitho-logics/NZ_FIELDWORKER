live_nest_leaflet <- function(n = DBq("SELECT * FROM NESTS_LATEST")) {
  study_site <- study_site_loader()

  center <- study_site |>
    sf::st_union() |>
    sf::st_centroid() |>
    sf::st_coordinates() |>
    as.numeric()

  m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |>
    addProviderTiles(providers$OpenStreetMap, group = "Street Map") |>
    addProviderTiles(providers$Esri.WorldImagery, group = "Satellite") |>
    addPolygons(
      data = study_site,
      group = "Study site",
      label = ~ as.character(id),
      fillOpacity = 0,
      color = "#e24c4c",
      weight = 2
    ) |>
    setView(
      lng = center[1],
      lat = center[2],
      zoom = 15
    )

  n <- data.table(n)

  if (nrow(n) == 0 || !"lat" %in% names(n) || !"lon" %in% names(n)) {
    return(
      m |>
        addLayersControl(
          baseGroups = c("Street Map", "Satellite"),
          overlayGroups = "Study site",
          options = layersControlOptions(collapsed = TRUE)
        )
    )
  }

  n <- n[!is.na(lat) & !is.na(lon)]

  if (nrow(n) == 0) {
    return(
      m |>
        addLayersControl(
          baseGroups = c("Street Map", "Satellite"),
          overlayGroups = "Study site",
          options = layersControlOptions(collapsed = TRUE)
        )
    )
  }

  n[, marker_col := nest_state_cols[as.character(nest_state)]]
  n[is.na(marker_col), marker_col := "#999999"]
  n[, label_text := fifelse(
    is.na(nest_id) | !nzchar(as.character(nest_id)),
    "unknown nest",
    as.character(nest_id)
  )]

  popup_cols <- setdiff(names(n), c("lat", "lon", "marker_col", "label_text"))

  n[, popup := vapply(seq_len(.N), function(i) {
    row <- as.list(.SD[i])
    keep <- vapply(row, function(value) {
      length(value) > 0 &&
        !is.na(value[1]) &&
        nzchar(as.character(value[1]))
    }, logical(1))

    row <- row[keep]

    if (!length(row)) {
      return("")
    }

    rows <- Map(function(field, value) {
      glue(
        "<tr><th>{htmltools::htmlEscape(field)}</th>",
        "<td>{htmltools::htmlEscape(as.character(value[1]))}</td></tr>"
      )
    }, names(row), row)

    glue(
      "<table class='table table-sm table-striped mb-0'>",
      "{paste(rows, collapse = '')}",
      "</table>"
    )
  }, character(1)), .SDcols = popup_cols]

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
        direction = "right",
        offset = c(8, 0),
        textOnly = TRUE,
        style = list(
          "font-weight" = "700",
          "font-size" = "12px",
          "color" = "#1f2933",
          "text-shadow" = "0 1px 2px #ffffff"
        )
      ),
      popup = ~popup,
      radius = 5,
      stroke = TRUE,
      weight = 1,
      color = "#1d3658",
      fillColor = ~marker_col,
      fillOpacity = 0.8
    )

  if (nrow(state_cols) > 0) {
    m <- m |>
      addLegend(
        position = "topleft",
        colors = state_cols$col,
        labels = state_cols$nest_state,
        title = "Nest state",
        opacity = 0.8
      )
  }

  m |>
    addLayersControl(
      baseGroups = c("Street Map", "Satellite"),
      overlayGroups = c("Study site", "Nests"),
      options = layersControlOptions(collapsed = TRUE)
    )
}
