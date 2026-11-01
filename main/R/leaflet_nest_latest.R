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
    x[.display_has_nest_id(nest_id)]
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


.nest_map_snapshot_query <- function(table) {
  # Read small published tables, never the expanded association pipeline.
  # SELECT * tolerates older snapshots without the new display columns.
  table <- match.arg(table, c("TODO_PARENT_STATUS_SNAPSHOT", "TODO_LIST_SNAPSHOT"))
  paste(
    "SELECT snapshot_rows.* FROM", table, "snapshot_rows",
    "JOIN (SELECT reference_date, state, completed_at FROM TODO_REFRESH_STATUS",
    "      ORDER BY refresh_id DESC LIMIT 1) published",
    "  ON snapshot_rows.reference_date = published.reference_date",
    "JOIN settings ON settings.variable = 'reference_date'",
    "  AND snapshot_rows.reference_date = settings.value",
    "WHERE published.state = 'succeeded' AND published.completed_at IS NOT NULL"
  )
}


.nest_map_parent_status_query <- function() {
  .nest_map_snapshot_query("TODO_PARENT_STATUS_SNAPSHOT")
}


.nest_map_add_hatch_timing <- function(n, todo, hatch_prediction) {
  n <- copy(as.data.table(n))
  set(n, j = "hatch_timing", value = rep("Unknown", nrow(n)))
  if (!nrow(n) || !all(c("nest_id", "reference_date") %in% names(n)) ||
      "error" %in% names(todo) || "error" %in% names(hatch_prediction)) return(n)

  # Reuse the PDF's fieldworker-facing Est. Hatch formatter, including its
  # flotation safeguards, published task override and negative-brood proxy.
  # No second hatch algorithm, database access or PDF rendering occurs here.
  reference_dates <- unique(as.character(n$reference_date))
  for (reference in reference_dates[!is.na(reference_dates)]) {
    refdate <- suppressWarnings(as.Date(reference, format = "%Y-%m-%d"))
    if (is.na(refdate)) next
    rows <- which(as.character(n$reference_date) == reference)
    tasks <- copy(as.data.table(todo))
    prediction <- copy(as.data.table(hatch_prediction))
    if ("reference_date" %in% names(tasks)) {
      tasks <- tasks[as.character(reference_date) == reference]
    }
    if ("nest_id" %in% names(tasks)) tasks <- tasks[nest_id %in% n$nest_id[rows]]
    if ("reference_date" %in% names(prediction)) {
      prediction <- prediction[as.character(reference_date) == reference]
    }
    summary <- todo_pdf_prepare_nest_summary(
      copy(n[rows]), refdate, todo = tasks, hatch_prediction = prediction,
      broods_authoritative = TRUE
    )
    timing <- as.character(summary[["Est. Hatch"]][match(n$nest_id[rows], summary$Nest)])
    valid <- !is.na(timing) & nzchar(trimws(timing))
    set(n, i = rows[valid], j = "hatch_timing", value = timing[valid])
  }
  n
}


.nest_map_add_parent_associations <- function(n, parents) {
  n <- copy(as.data.table(n))
  parents <- as.data.table(parents)
  required <- c("nest_id", "reference_date", "M_association_display", "F_association_display")
  if (!all(c("nest_id", "reference_date") %in% names(n)) ||
      !all(required %in% names(parents))) return(n)

  # Match reference date as well as nest; duplicate cached keys fail closed.
  keys <- function(x) paste(trimws(x$nest_id), as.character(x$reference_date), sep = "|")
  parent_keys <- keys(parents)
  unique_key <- !duplicated(parent_keys) & !duplicated(parent_keys, fromLast = TRUE)
  parents <- parents[unique_key]
  index <- match(keys(n), parent_keys[unique_key])
  index[is.na(n$reference_date)] <- NA_integer_
  for (sex in c("M", "F")) {
    display_column <- paste0(sex, "_association_display")
    mark_column <- paste0(sex, "_mark")
    parent_mark_column <- paste0(sex, "_parent_mark")
    display <- as.character(parents[[display_column]][index])
    # Live map data can be newer than the snapshot. Never attach cached
    # evidence to a different currently displayed individual. Pending parent
    # marks use the existing SQL ' & ' list, not counts combined across birds.
    if (mark_column %in% names(n)) {
      current <- toupper(trimws(as.character(n[[mark_column]])))
      cached <- if (parent_mark_column %in% names(parents)) {
        as.character(parents[[parent_mark_column]][index])
      } else rep(NA_character_, nrow(n))
      selected_mark_column <- paste0(sex, "_selected_mark")
      selected <- if (selected_mark_column %in% names(parents)) {
        as.character(parents[[selected_mark_column]][index])
      } else rep(NA_character_, nrow(n))
      agrees <- vapply(seq_len(nrow(n)), function(i) {
        candidates <- c(selected[i], if (!is.na(cached[i])) {
          strsplit(cached[i], " & ", fixed = TRUE)[[1L]]
        })
        candidates <- toupper(trimws(candidates[!is.na(candidates)]))
        is.na(current[i]) || !nzchar(current[i]) ||
          current[i] %in% candidates
      }, logical(1))
      display[!agrees] <- NA_character_
    }
    set(n, j = display_column, value = display)
  }
  n
}


.nest_map_popups <- function(n) {
  # Presentation only: reuse the SQL encounter date for broods and the last
  # nest visit for other points. Never substitute today's date or an older
  # nest visit when a brood encounter date is unavailable.
  n <- copy(as.data.table(n))
  for (sex in c("M", "F")) {
    display_column <- paste0(sex, "_association_display")
    if (!display_column %in% names(n)) next
    display <- as.character(n[[display_column]])
    has_display <- !is.na(display) & nzchar(trimws(display))
    mark_column <- paste0(sex, "_mark")
    if (!mark_column %in% names(n)) set(n, j = mark_column, value = NA_character_)
    set(n, i = which(has_display), j = mark_column, value = display[has_display])
  }
  date_column <- function(name) {
    value <- if (name %in% names(n)) n[[name]] else rep(NA_character_, nrow(n))
    suppressWarnings(as.Date(substr(as.character(value), 1, 10), format = "%Y-%m-%d"))
  }
  encounter_date <- date_column("last_visit_datetime")
  is_brood <- if ("map_category" %in% names(n)) {
    !is.na(n$map_category) & n$map_category == "brood"
  } else {
    rep(FALSE, nrow(n))
  }
  encounter_date[is_brood] <- date_column("latest_encounter_date")[is_brood]
  days_since <- as.integer(date_column("reference_date") - encounter_date)
  last_encounter <- rep("Unknown", nrow(n))
  valid <- !is.na(days_since) & days_since >= 0L
  last_encounter[valid] <- paste(days_since[valid], "days ago")
  last_encounter[valid & days_since == 0L] <- "today"
  last_encounter[valid & days_since == 1L] <- "1 day ago"
  set(n, j = "last_encounter", value = last_encounter)

  popup_labels <- c(
    nest_id = "Nest / brood",
    map_category = "State",
    M_mark = "Male",
    F_mark = "Female",
    hatch_state = "Hatching status",
    hatch_timing = "Hatch timing (days)",
    clutch_size = "Clutch size",
    brood_size = "Brood size",
    last_encounter = "Last encounter",
    last_observer = "Last observer"
  )
  popup_cols <- intersect(names(popup_labels), names(n))
  vapply(seq_len(nrow(n)), function(i) {
    row <- as.list(n[i, ..popup_cols])
    keep <- vapply(row, function(value) {
      !is.na(value[1]) && nzchar(as.character(value[1]))
    }, logical(1))
    row <- row[keep]
    rows <- Map(function(field, value) {
      glue(
        "<tr><th>{htmlEscape(popup_labels[[field]])}</th>",
        "<td>{htmlEscape(as.character(value[1]))}</td></tr>"
      )
    }, names(row), row)
    glue(
      "<table class='table table-sm table-striped mb-0'>",
      "{glue_collapse(rows)}",
      "</table>"
    )
  }, character(1))
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
  if ("nest_id" %in% names(n)) {
    n <- n[.display_has_nest_id(nest_id)]
  }

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

  n[, popup := .nest_map_popups(n)]

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
