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


.prepare_live_nest_map_data <- function(
  nests_latest = data.table(),
  broods_latest = data.table()
) {
  as_flag <- function(x) {
    value <- toupper(trimws(as.character(x)))
    !is.na(value) & value %in% c("1", "TRUE", "T", "YES", "Y")
  }

  as_coord <- function(x) {
    suppressWarnings(as.numeric(as.character(x)))
  }

  add_column <- function(x, name, value) {
    if (!name %in% names(x)) {
      x[, (name) := value]
    }
    x
  }

  normalize_ids <- function(x) {
    x <- data.table(x)
    x <- add_column(x, "nest_id", NA_character_)
    x[, nest_id := trimws(as.character(nest_id))]
    x[is.na(nest_id), nest_id := ""]
    x[nzchar(nest_id) & nest_id != "NO_NEST"]
  }

  normalize_coords <- function(x) {
    x <- add_column(x, "lat", NA_real_)
    x <- add_column(x, "lon", NA_real_)
    x[, lat := as_coord(lat)]
    x[, lon := as_coord(lon)]
    x
  }

  n <- normalize_coords(normalize_ids(nests_latest))
  b <- normalize_coords(normalize_ids(broods_latest))

  if (nrow(n)) {
    n <- n[!startsWith(nest_id, "-")]
    n <- add_column(n, "nest_state", NA_character_)
    n <- add_column(n, "is_negative_brood", FALSE)
    n[, is_negative_brood := FALSE]

    if ("has_hatch_evidence" %in% names(n)) {
      n[, has_hatch_evidence := fcoalesce(as_flag(has_hatch_evidence), FALSE)]
    } else {
      n[, has_hatch_evidence := FALSE]
    }

    if ("nest_state" %in% names(n)) {
      n[, has_hatch_evidence := has_hatch_evidence | as.character(nest_state) == "H"]
    }

    if ("brood_size" %in% names(n)) {
      n[, has_hatch_evidence := has_hatch_evidence |
        (!is.na(suppressWarnings(as.numeric(as.character(brood_size)))) &
          suppressWarnings(as.numeric(as.character(brood_size))) > 0)]
    }

    n[, map_category := fifelse(
      has_hatch_evidence,
      "brood",
      as.character(fcoalesce(nest_state, "unknown"))
    )]
    n[map_category == "H", map_category := "brood"]
  }

  if (nrow(b)) {
    b <- add_column(b, "is_negative_brood", startsWith(b$nest_id, "-"))
    b[, is_negative_brood := fcoalesce(as_flag(is_negative_brood), FALSE) |
      startsWith(nest_id, "-")]

    if ("has_hatch_evidence" %in% names(b)) {
      b[, has_hatch_evidence := fcoalesce(as_flag(has_hatch_evidence), FALSE)]
    } else {
      b[, has_hatch_evidence := FALSE]
    }

    if ("nest_state" %in% names(b)) {
      b[, has_hatch_evidence := has_hatch_evidence | as.character(nest_state) == "H"]
    }

    if ("brood_size" %in% names(b)) {
      b[, has_hatch_evidence := has_hatch_evidence |
        (!is.na(suppressWarnings(as.numeric(as.character(brood_size)))) &
          suppressWarnings(as.numeric(as.character(brood_size))) > 0)]
    }

    b <- b[is_negative_brood | has_hatch_evidence]
    b[, map_category := "brood"]
  }

  if (nrow(n) && nrow(b)) {
    positive_broods <- b[!b$is_negative_brood, .(nest_id)]

    fallback <- n[
      , .(
        nest_id,
        fallback_lat = lat,
        fallback_lon = lon
      )
    ]

    if (nrow(positive_broods)) {
      n <- n[!nest_id %in% positive_broods$nest_id]
    }

    if (!"location_source" %in% names(b)) {
      b[, location_source := NA_character_]
    }

    b <- merge(b, fallback, by = "nest_id", all.x = TRUE, sort = FALSE)

    use_fallback <- !b$is_negative_brood &
      (is.na(b$lat) | is.na(b$lon)) &
      !is.na(b$fallback_lat) & !is.na(b$fallback_lon)

    b[use_fallback, `:=`(
      lat = fallback_lat,
      lon = fallback_lon,
      location_source = "NESTS_LATEST fallback"
    )]
    b[, c("fallback_lat", "fallback_lon") := NULL]
  }

  if (!nrow(n) && nrow(b) && !"location_source" %in% names(b)) {
    b[, location_source := NA_character_]
  }

  result <- rbindlist(list(n, b), fill = TRUE, use.names = TRUE)

  if (!nrow(result)) {
    return(result)
  }

  result <- result[!duplicated(nest_id)]
  result[, map_category := as.character(map_category)]
  result[is.na(map_category) | !nzchar(map_category), map_category := "unknown"]
  result
}


live_nest_leaflet <- function(
  n = DBq("SELECT * FROM NESTS_LATEST"),
  plots = DBq("SELECT * FROM spatial_objects where variable = 'study_area' "),
  nest_size = 4,
  broods_latest = NULL,
  map_data_prepared = FALSE,
  broods_warning = NULL
) {
  if (!isTRUE(map_data_prepared) && !is.null(broods_latest)) {
    n <- .prepare_live_nest_map_data(n, broods_latest)
  }

  n <- data.table(n)

  if (!"map_category" %in% names(n)) {
    if ("nest_state" %in% names(n)) {
      n[, map_category := as.character(nest_state)]
      n[map_category == "H", map_category := "brood"]
    } else {
      n[, map_category := rep("unknown", .N)]
    }
    n[is.na(map_category) | !nzchar(map_category), map_category := "unknown"]
  }

  marker_radius <- pmax(nest_size + 1, 4)
  label_font_size <- pmax(nest_size + 8, 12)
  label_offset <- pmax(round(marker_radius + 4), 8)
  plots <- .prepare_plots(plots)
  overlay_groups <- character()

  m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |>
    addProviderTiles(providers$OpenStreetMap, group = "Street Map") |>
    addProviderTiles(providers$Esri.WorldImagery, group = "Satellite")

  finish_map <- function(map, overlay_groups = character()) {
    map <- map |>
      addLayersControl(
        baseGroups = c("Street Map", "Satellite"),
        overlayGroups = overlay_groups,
        options = layersControlOptions(collapsed = TRUE)
      )

    if (!is.null(broods_warning) && nzchar(as.character(broods_warning))) {
      map <- map |>
        addControl(
          html = tags$div(
            class = "nest-map-warning",
            as.character(broods_warning)
          ),
          position = "topright",
          layerId = "nest_map_brood_warning",
          className = "nest-map-warning-control"
        )
    }

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

  n[, marker_col := nest_state_cols[as.character(map_category)]]
  n[is.na(marker_col), marker_col := "#999999"]
  n[,
    label_text := fifelse(
      is.na(nest_id) | !nzchar(as.character(nest_id)),
      "unknown nest",
      as.character(nest_id)
    )
  ]

  popup_fields <- c(
    "nest_id",
    "map_category",
    "nest_state",
    "is_negative_brood",
    "has_hatch_evidence",
    "latest_encounter_date",
    "latest_chick_event_date",
    "location_source",
    "location_event_date",
    "location_source_table",
    "M_mark",
    "F_mark",
    "hatch_state",
    "clutch_size",
    "brood_size",
    "days_ago",
    "last_observer"
  )
  popup_cols <- intersect(popup_fields, names(n))
  if (!length(popup_cols)) {
    popup_cols <- setdiff(names(n), c("lat", "lon", "marker_col", "label_text"))
  }

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
    !is.na(map_category) & nzchar(map_category),
    .(col = marker_col[1]),
    by = map_category
  ]
  state_cols[, state_order := match(map_category, names(nest_state_cols))]
  state_cols[is.na(state_order), state_order := .Machine$integer.max]
  setorder(state_cols, state_order, map_category)

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
        tags$span(class = "nest-legend-title", "State / brood")
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
          state_cols$map_category,
          state_cols$col
        )
      )
    )

    m <- m |>
      addControl(
        html = legend_html,
        position = "topleft",
        layerId = "nest_map_legend",
        className = "nest-legend-control"
      )
  }

  finish_map(m, overlay_groups)
}
