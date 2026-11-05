field_resightings_normalize_combo <- function(combo) {
  if (length(combo) != 1L || is.na(combo)) {
    stop("Use four colour letters, e.g. RROR.")
  }

  combo <- toupper(trimws(as.character(combo)))
  if (!grepl("^[BGROWLY]{2}-?[BGROWLY]{2}$", combo)) {
    stop("Use four colour letters, e.g. RROR.")
  }

  gsub("-", "", combo, fixed = TRUE)
}


field_resightings_behaviours <- function() {
  c(
    "FA — Foraging alone" = "FA",
    "FM — Foraging with mate" = "FM",
    "FF — Foraging in flock" = "FF",
    "FC — Foraging with chicks" = "FC",
    "IN — Incubating" = "IN",
    "BC — Brooding chicks" = "BC",
    "AC — Alert with chicks" = "AC",
    "BW — Broken-wing display" = "BW",
    "NM — Nest maintenance" = "NM",
    "SC — Scraping" = "SC",
    "CO — Courtship" = "CO",
    "PR — Preening" = "PR",
    "RS — Roosting" = "RS",
    "LF — Loafing" = "LF",
    "AT — Alert" = "AT",
    "FT — Fighting" = "FT",
    "OB — Other behaviour" = "OB"
  )
}


field_resightings_save_resighting <- function(combo, behaviours, location = NULL,
    db_write = DBx, now = Sys.time(), browser_id = NULL) {
  combo <- field_resightings_normalize_combo(combo)
  # Nested input arrays from Shiny arrive as lists of scalar strings.
  if (is.list(behaviours) && is.null(names(behaviours)) &&
      all(vapply(behaviours, function(value) {
        is.character(value) && length(value) == 1L && !is.na(value)
      }, logical(1)))) {
    behaviours <- unlist(behaviours, use.names = FALSE)
  }
  if (!is.character(behaviours) || !length(behaviours) ||
      anyNA(behaviours) || !all(behaviours %in% field_resightings_behaviours())) {
    stop("Choose a behaviour from the list.", call. = FALSE)
  }
  behaviours <- unique(behaviours)
  lat <- lon <- accuracy <- NA_real_
  number <- function(value) {
    if (!is.numeric(value) || length(value) != 1L || !is.finite(value)) {
      return(NA_real_)
    }
    as.numeric(value)
  }
  if (is.list(location)) {
    timestamp <- number(location$timestamp)
    age <- as.numeric(now) * 1000 - timestamp
    latitude <- number(location$latitude)
    longitude <- number(location$longitude)
    if (!is.na(age) && age >= -5000 && age <= 30000 &&
        !is.na(latitude) && abs(latitude) <= 90 &&
        !is.na(longitude) && abs(longitude) <= 180) {
      lat <- latitude
      lon <- longitude
      error <- number(location$accuracy)
      if (!is.na(error) && error >= 0) accuracy <- error
    }
  }
  if (is.na(lat) || is.na(lon)) {
    stop("GPS unavailable.", call. = FALSE)
  }
  if (!is.character(browser_id) || length(browser_id) != 1L || is.na(browser_id) ||
      !grepl("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        browser_id, ignore.case = TRUE)) {
    stop("Browser ID unavailable.", call. = FALSE)
  }
  timestamp_ms <- round(timestamp)
  gps_timestamp <- paste0(
    format(as.POSIXct(timestamp_ms %/% 1000, origin = "1970-01-01", tz = "UTC"),
      "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    sprintf(".%03d", as.integer(timestamp_ms %% 1000))
  )
  # The search input supplies canonical left/right colour pairs, not observed
  # upper-leg positions. Leave those positions unknown rather than invent marks.
  isTRUE(db_write(
    paste(
      "INSERT INTO RESIGHTINGS_field",
      "(UL, LL, UR, LR, latitude, longitude, location_error, gps_timestamp, behav, browser_id)",
      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ),
    params = list(
      NA_character_, substr(combo, 1L, 2L), NA_character_, substr(combo, 3L, 4L),
      lat, lon, accuracy, gps_timestamp, paste(behaviours, collapse = ", "),
      tolower(browser_id)
    )
  ))
}


field_resightings_has_matches <- function(result) {
  any(vapply(result$sources, function(found) {
    !found$failed && nrow(found$rows) > 0L
  }, logical(1))) || !is.null(result$nest_ids) || isTRUE(result$first_capture$found)
}


field_resightings_server <- function(input, output, refdate,
    session = shiny::getDefaultReactiveDomain()) {
  search_number <- 0L
  saved_token <- NULL
  result <- shiny::eventReactive(input$field_resightings_request, {
    search_number <<- search_number + 1L
    combo <- tryCatch(
      field_resightings_normalize_combo(input$field_resightings_request$combo),
      error = function(error) NULL
    )
    if (is.null(combo)) {
      return(list(message = "Not found"))
    }

    found <- field_resightings_fetch(combo, refdate())
    found$save_token <- as.character(search_number)
    found
  })

  shiny::observeEvent(input$field_resightings_save_request, {
    request <- input$field_resightings_save_request
    found <- result()
    reply <- function(message, saved = FALSE) {
      session$sendCustomMessage("field_resightings_save_result", list(
        token = request$token, message = message, saved = saved
      ))
    }
    if (!is.null(found$message) || !field_resightings_has_matches(found) ||
        !identical(request$token, found$save_token) ||
        !identical(as.Date(found$refdate), as.Date(refdate()))) {
      reply("Search again before saving.")
      return()
    }
    entered_combo <- tryCatch(
      field_resightings_normalize_combo(request$combo), error = function(error) NULL
    )
    if (!identical(entered_combo, found$combo)) {
      reply("Search this combo first.")
      return()
    }
    if (identical(saved_token, found$save_token)) {
      reply("Saved", saved = TRUE)
      return()
    }
    saved <- tryCatch(
      field_resightings_save_resighting(found$combo, request$behaviours, request$location,
        browser_id = request$browser_id),
      error = function(error) {
        reply(if (conditionMessage(error) %in% c("Choose a behaviour from the list.",
            "GPS unavailable.", "Browser ID unavailable.")) {
          conditionMessage(error)
        } else "Couldn’t save. Try again.")
        NULL
      }
    )
    if (is.null(saved)) return()
    if (saved) {
      saved_token <<- found$save_token
      reply("Saved", saved = TRUE)
    } else {
      reply("Couldn’t save. Try again.")
    }
  }, ignoreInit = TRUE)

  output$field_resightings_results <- shiny::renderUI({
    tags <- htmltools::tags
    if (is.null(input$field_resightings_request)) {
      return(NULL)
    }

    found <- result()
    if (!is.null(found$message)) {
      return(tags$p(role = "alert", class = "text-danger px-2", found$message))
    }
    if (!identical(as.Date(found$refdate), as.Date(refdate()))) {
      return(tags$p(
        role = "status",
        class = "text-muted px-2",
        "Date changed. Search again."
      ))
    }

    field_resightings_results_ui(found)
  })

  invisible(result)
}


field_resightings_combo_sql <- function(suffix = "") {
  # Match USED_COMBOS_DETAIL's classic and tag/spacer representation rules.
  # The caller supplies uppercased, trimmed band fields with blanks as NULL.
  ul <- paste0("UL", suffix)
  ll <- paste0("LL", suffix)
  ur <- paste0("UR", suffix)
  lr <- paste0("LR", suffix)

  paste0(
    "CONCAT(\n",
    "  CASE\n",
    "    WHEN ",
    ul,
    " REGEXP '^[BGROWLY]$' AND ",
    ll,
    " REGEXP '^[BGROWLY]$' THEN CONCAT(",
    ul,
    ", ",
    ll,
    ")\n",
    "    WHEN COALESCE(",
    ul,
    ", 'X') IN ('X', 'M') AND ",
    ll,
    " REGEXP '^[BGROWLY]{2}$' THEN ",
    ll,
    "\n",
    "    WHEN COALESCE(",
    ll,
    ", 'X') IN ('X', 'M') AND ",
    ul,
    " REGEXP '^[BGROWLY]{2}$' THEN ",
    ul,
    "\n",
    "    ELSE NULL END,\n",
    "  CASE\n",
    "    WHEN ",
    ur,
    " REGEXP '^T[A-Z0-9]*[BGROWLY]$' AND ",
    lr,
    " REGEXP '^[BGROWLY]{2}$' THEN ",
    lr,
    "\n",
    "    WHEN ",
    ur,
    " REGEXP '^T[A-Z0-9]*[BGROWLY]$' AND ",
    lr,
    " REGEXP '^[BGROWLY]$' THEN CONCAT(RIGHT(",
    ur,
    ", 1), ",
    lr,
    ")\n",
    "    WHEN ",
    ur,
    " REGEXP '^[BGROWLY]$' AND ",
    lr,
    " REGEXP '^[BGROWLY]$' THEN CONCAT(",
    ur,
    ", ",
    lr,
    ")\n",
    "    WHEN COALESCE(",
    ur,
    ", 'X') IN ('X', 'XX', 'M') AND ",
    lr,
    " REGEXP '^[BGROWLY]{2}$' THEN ",
    lr,
    "\n",
    "    WHEN COALESCE(",
    lr,
    ", 'X') IN ('X', 'M') AND ",
    ur,
    " REGEXP '^[BGROWLY]{2}$' THEN ",
    ur,
    "\n",
    "    ELSE NULL END\n",
    ")"
  )
}


field_resightings_queries <- function(combo, refdate) {
  combo <- field_resightings_normalize_combo(combo)
  refdate <- as.Date(refdate)
  if (length(refdate) != 1L || is.na(refdate)) {
    stop("Set a reference date.")
  }

  sources <- list(
    CAPTURES_ARCHIVE = list(
      label = "Historical captures",
      fields = c("date", "ring", "field_sex", "gen_sex", "tag_id", "tag_type")
    ),
    CAPTURES = list(
      label = "Captures",
      fields = c(
        "pk",
        "date",
        "site",
        "ring",
        "field_sex",
        "nest_id",
        "gps_id",
        "gps_point",
        "tag_id",
        "tag_id_in",
        "tag_type",
        "tag_action"
      )
    ),
    RESIGHTINGS = list(
      label = "Latest field resighting",
      fields = c(
        "pk",
        "date",
        "site",
        "ring",
        "nest_id"
      )
    )
  )

  queries <- lapply(names(sources), function(table) {
    spec <- sources[[table]]
    incoming <- identical(table, "CAPTURES")
    resighting <- identical(table, "RESIGHTINGS")
    bands <- c("UL", "LL", "UR", "LR")
    if (incoming) {
      bands <- c(bands, paste0(bands, "_in"))
    }
    band_fields <- paste0(
      "UPPER(NULLIF(TRIM(",
      bands,
      "), '')) AS ",
      bands
    )
    fields <- sub(".* AS ", "", spec$fields)
    fields <- c(
      fields,
      if (incoming) paste0(c("UL", "LL", "UR", "LR"), "_in"),
      "release_combo"
    )
    if (incoming) {
      fields <- c(fields, "incoming_combo")
    }

    sql <- paste0(
      "WITH search_rows AS (\n  SELECT ",
      paste(c(spec$fields, band_fields), collapse = ", "),
      "\n  FROM ",
      table,
      "\n  WHERE date <= CAST(? AS DATE) OR date IS NULL\n",
      "), search_marks AS (\n  SELECT search_rows.*,\n    ",
      field_resightings_combo_sql(),
      " AS release_combo",
      if (incoming) {
        paste0(
          ",\n    ",
          field_resightings_combo_sql("_in"),
          " AS incoming_combo"
        )
      } else {
        ""
      },
      "\n  FROM search_rows\n)\n",
      "SELECT ",
      paste(fields, collapse = ", "),
      if (resighting) {
        ", MIN(date) OVER () AS first_seen, MAX(date) OVER () AS last_seen"
      } else {
        ""
      },
      "\nFROM search_marks\n",
      "WHERE release_combo = ?",
      if (incoming) " OR incoming_combo = ?" else "",
      if (table == "CAPTURES_ARCHIVE") {
        "\nORDER BY date DESC, ring ASC"
      } else {
        "\nORDER BY date DESC, pk DESC"
      },
      if (incoming) "\nLIMIT 51" else "\nLIMIT 1"
    )

    list(
      label = spec$label,
      sql = sql,
      params = c(list(as.character(refdate), combo), if (incoming) list(combo))
    )
  })

  queries <- stats::setNames(queries, names(sources))
  queries$NESTS <- field_resightings_partner_query(combo, refdate)
  queries
}


field_resightings_partner_query <- function(combo, refdate, focal_nests = NULL) {
  combo <- field_resightings_normalize_combo(combo)
  # Shared-nest capture records supply this quick lookup independently of the
  # task-association pipeline. Keep nest IDs scoped to their site and species.
  bands <- c("UL", "LL", "UR", "LR", "UL_in", "LL_in", "UR_in", "LR_in")
  band_fields <- paste0("UPPER(NULLIF(TRIM(", bands, "), '')) AS ", bands)
  nest_anchors <- ""
  nest_params <- list()
  context_columns <- c("nest_id", "site", "species")
  if (!is.null(focal_nests) && all(context_columns %in% names(focal_nests))) {
    contexts <- unique(as.data.frame(focal_nests)[context_columns])
    contexts[] <- lapply(contexts, function(x) toupper(trimws(as.character(x))))
    valid <- Reduce(`&`, lapply(contexts, function(x) !is.na(x) & nzchar(x))) &
      !contexts$nest_id %in% c("NA", "N/A", "NULL", "NO_NEST")
    contexts <- contexts[valid, , drop = FALSE]
    if (nrow(contexts)) {
      nest_anchors <- paste(rep(
        "UNION ALL SELECT NULL AS pk, ? AS nest_id, ? AS site, ? AS species, NULL AS ring_key",
        nrow(contexts)
      ), collapse = "\n")
      for (i in seq_len(nrow(contexts))) {
        nest_params <- c(nest_params, unname(as.list(contexts[i, , drop = FALSE])))
      }
    }
  }
  has_mark <- function(suffix) {
    paste0(
      "COALESCE(",
      paste0(c("UL", "LL", "UR", "LR"), suffix),
      ", 'X') NOT IN ('X', 'XX', 'M')",
      collapse = " OR "
    )
  }
  display_mark <- function(suffix, canonical) {
    paste0(
      "CASE WHEN ",
      canonical,
      " IS NOT NULL THEN CONCAT(LEFT(",
      canonical,
      ", 2), '-', RIGHT(",
      canonical,
      ", 2)) ELSE format_mark(",
      paste(paste0(c("UL", "LL", "UR", "LR"), suffix), collapse = ", "),
      ") END"
    )
  }
  sql <- paste0(
    "WITH capture_rows AS (\n",
    "  SELECT pk, UPPER(NULLIF(TRIM(nest_id), '')) AS nest_id,\n",
    "    UPPER(NULLIF(TRIM(site), '')) AS site, UPPER(NULLIF(TRIM(species), '')) AS species,\n",
    "    CASE WHEN UPPER(TRIM(ring)) IN ('', 'NA', 'N/A', 'NULL') THEN NULL\n",
    "      ELSE REPLACE(UPPER(TRIM(ring)), '-', '') END AS ring_key,\n    ",
    paste(band_fields, collapse = ", "),
    "\n",
    "  FROM CAPTURES\n",
    "  WHERE (date <= CAST(? AS DATE) OR date IS NULL) AND UPPER(TRIM(age)) = 'A'\n",
    "), capture_marks AS (\n",
    "  SELECT capture_rows.*, ",
    field_resightings_combo_sql(),
    " AS release_combo,\n",
    field_resightings_combo_sql("_in"),
    " AS incoming_combo FROM capture_rows\n",
    "), marked AS (\n",
    "  SELECT capture_marks.*, CASE\n",
    "    WHEN ",
    has_mark(""),
    " THEN ",
    display_mark("", "release_combo"),
    "\n",
    "    WHEN ",
    has_mark("_in"),
    " THEN ",
    display_mark("_in", "incoming_combo"),
    "\n",
    "    ELSE NULL END AS display_combo FROM capture_marks\n",
    "), matched_captures AS (\n",
    "  SELECT pk, nest_id, site, species, ring_key FROM marked\n",
    "  WHERE (release_combo = ? OR incoming_combo = ?)\n",
    "), focal AS (\nSELECT pk, nest_id, site, species, ring_key FROM matched_captures\n",
    "WHERE nest_id NOT IN ('NA', 'N/A', 'NULL', 'NO_NEST')\n",
    nest_anchors, "\n",
    ")\nSELECT DISTINCT partner.display_combo AS partner FROM focal\n",
    "JOIN marked partner ON partner.nest_id = focal.nest_id\n",
    "  AND partner.site = focal.site AND partner.species = focal.species\n",
    "  AND (focal.pk IS NULL OR partner.pk <> focal.pk)\n",
    "  AND (partner.ring_key IS NULL OR focal.ring_key IS NULL OR partner.ring_key <> focal.ring_key)\n",
    "WHERE partner.display_combo IS NOT NULL AND partner.display_combo NOT LIKE '%?%'\n",
    "  AND COALESCE(partner.release_combo, '') <> ? AND COALESCE(partner.incoming_combo, '') <> ?\n",
    "  AND NOT EXISTS (SELECT 1 FROM matched_captures own\n",
    "    WHERE own.ring_key IS NOT NULL AND own.ring_key = partner.ring_key)\n",
    "ORDER BY partner LIMIT 51"
  )

  list(
    label = "Partners",
    sql = sql,
    params = c(list(as.character(as.Date(refdate))), rep(list(combo), 2L), nest_params, rep(list(combo), 2L))
  )
}


field_resightings_nest_query <- function(combo, refdate) {
  combo <- field_resightings_normalize_combo(combo)
  source_sql <- function(table, suffix = "") {
    bands <- c("UL", "LL", "UR", "LR")
    paste0(
      "SELECT date, UPPER(NULLIF(TRIM(nest_id), '')) AS nest_id, ",
      "UPPER(NULLIF(TRIM(site), '')) AS site, UPPER(NULLIF(TRIM(species), '')) AS species, ",
      paste0(
        "UPPER(NULLIF(TRIM(",
        bands,
        suffix,
        "), '')) AS ",
        bands,
        collapse = ", "
      ),
      " FROM ",
      table,
      " WHERE date <= CAST(? AS DATE) OR date IS NULL"
    )
  }
  list(
    sql = paste0(
      "WITH band_rows AS (\n",
      source_sql("CAPTURES"),
      "\nUNION ALL\n",
      source_sql("CAPTURES", "_in"),
      "\nUNION ALL\n",
      source_sql("RESIGHTINGS"),
      "\n)\n",
      "SELECT nest_id, site, species, MIN(date) AS first_seen FROM band_rows\n",
      "WHERE ",
      field_resightings_combo_sql(),
      " = ?\n",
      "  AND nest_id NOT IN ('NA', 'N/A', 'NULL', 'NO_NEST')\n",
      "GROUP BY nest_id, site, species\nORDER BY MIN(date) IS NULL, MIN(date), nest_id, site, species"
    ),
    params = c(rep(list(as.character(as.Date(refdate))), 3L), list(combo))
  )
}


field_resightings_latest_nest_query <- function(nest_id, site, species, refdate) {
  list(
    sql = paste(
      "SELECT date, time_visit, nest_state, hatch_state, bird_inc, clutch_size, brood_size",
      "FROM NESTS",
      "WHERE UPPER(TRIM(nest_id)) = ? AND UPPER(TRIM(site)) = ?",
      "AND UPPER(TRIM(species)) = ?",
      "AND (date <= CAST(? AS DATE) OR date IS NULL)",
      "ORDER BY date DESC, time_visit DESC, pk DESC LIMIT 1"
    ),
    params = list(nest_id, site, species, as.character(as.Date(refdate)))
  )
}


field_resightings_nest_location_query <- function(nest_id, site, species, refdate) {
  # Match the nest_coordinates ordering in NESTS_LATEST, with explicit scope
  # and reference date so this also works outside the map's Cass River filter.
  list(
    sql = paste(
      "SELECT g.lat, g.lon FROM NESTS n",
      "JOIN GPS_POINTS g ON n.gps_id = g.gps_id AND n.gps_point = g.gps_point",
      "WHERE UPPER(TRIM(n.nest_id)) = ? AND UPPER(TRIM(n.site)) = ?",
      "AND UPPER(TRIM(n.species)) = ? AND n.date <= CAST(? AS DATE)",
      "ORDER BY CASE WHEN n.nest_state = 'S' THEN 1",
      "WHEN n.nest_state = 'F' THEN 2 ELSE 3 END,",
      "n.date, n.time_visit, n.pk, g.datetime_, g.pk LIMIT 1"
    ),
    params = list(nest_id, site, species, as.character(as.Date(refdate)))
  )
}


field_resightings_first_capture_query <- function(
  combo,
  refdate,
  tables = c("CAPTURES", "CAPTURES_ARCHIVE")
) {
  combo <- field_resightings_normalize_combo(combo)
  tables <- match.arg(
    tables,
    c("CAPTURES", "CAPTURES_ARCHIVE"),
    several.ok = TRUE
  )
  source_sql <- function(table, incoming) {
    bands <- c("UL", "LL", "UR", "LR")
    fields <- paste0("UPPER(NULLIF(TRIM(", bands, "), '')) AS ", bands)
    incoming_fields <- if (incoming) {
      paste0("UPPER(NULLIF(TRIM(", bands, "_in), '')) AS ", bands, "_in")
    } else {
      paste0("NULL AS ", bands, "_in")
    }
    paste0(
      "SELECT date, CASE WHEN UPPER(TRIM(ring)) IN ('', 'NA', 'N/A', 'NULL') THEN NULL ",
      "ELSE REPLACE(UPPER(TRIM(ring)), '-', '') END AS ring_key, ",
      paste(c(fields, incoming_fields), collapse = ", "),
      " FROM ",
      table,
      " WHERE date <= CAST(? AS DATE) OR date IS NULL"
    )
  }
  list(
    sql = paste0(
      "WITH first_capture_rows AS (\n",
      paste(
        vapply(
          tables,
          function(table) {
            source_sql(table, identical(table, "CAPTURES"))
          },
          character(1)
        ),
        collapse = "\nUNION ALL\n"
      ),
      "\n), first_capture_marks AS (\n",
      "SELECT date, ring_key, ",
      field_resightings_combo_sql(),
      " AS release_combo,\n",
      field_resightings_combo_sql("_in"),
      " AS incoming_combo FROM first_capture_rows\n",
      "), matched_rings AS (\n",
      "SELECT DISTINCT ring_key FROM first_capture_marks\n",
      "WHERE release_combo = ? OR incoming_combo = ?\n",
      ")\nSELECT MIN(c.date) AS first_capture, COUNT(*) AS n FROM first_capture_marks c\n",
      "WHERE c.release_combo = ? OR c.incoming_combo = ?\n",
      "OR EXISTS (SELECT 1 FROM matched_rings r WHERE r.ring_key = c.ring_key)"
    ),
    params = c(
      rep(list(as.character(as.Date(refdate))), length(tables)),
      rep(list(combo), 4L)
    )
  )
}


field_resightings_db_get <- function(sql, params = NULL) {
  # Missing optional sources are handled by the combined search result UI.
  # Avoid DBq's SQL-prefix toast before that handling can run.
  DBq(sql, params = params, notify = FALSE)
}


field_resightings_fetch <- function(combo, refdate, db_get = field_resightings_db_get) {
  queries <- field_resightings_queries(combo, refdate)
  # Use all matching current-season nest links, including resightings, as
  # anchors when the focal bird has no capture at a particular nest.
  nest_query <- field_resightings_nest_query(combo, refdate)
  nests <- tryCatch(
    db_get(nest_query$sql, params = nest_query$params),
    error = function(error) NULL
  )
  nests_failed <- is.null(nests) || "error" %in% names(nests)
  if (!nests_failed && nrow(nests)) {
    queries$NESTS <- field_resightings_partner_query(combo, refdate, focal_nests = nests)
  }
  sources <- lapply(names(queries), function(source) {
    query <- queries[[source]]
    rows <- tryCatch(
      db_get(query$sql, params = query$params),
      error = function(error) NULL
    )
    failed <- is.null(rows) || "error" %in% names(rows)
    if (!failed && source == "NESTS") {
      rows <- as.data.frame(rows)
      rows <- rows[!is.na(rows$partner), , drop = FALSE]
    }
    limit <- if (source %in% c("RESIGHTINGS", "CAPTURES_ARCHIVE")) 1L else 50L

    list(
      label = query$label,
      failed = failed,
      more = !failed &&
        !source %in% c("RESIGHTINGS", "CAPTURES_ARCHIVE") &&
        nrow(rows) > limit,
      rows = if (failed) {
        data.frame()
      } else {
        as.data.frame(utils::head(rows, limit))
      }
    )
  })

  # Read full nest chronology independently of the per-source display limits,
  # so earlier nests remain available alongside recent event details.
  nest_ids <- if (!nests_failed && nrow(nests)) {
    ids <- as.character(nests$nest_id)
    ids <- unique(ids[!is.na(ids) & nzchar(trimws(ids))])
    if (length(ids)) paste(ids, collapse = ", ") else NULL
  } else {
    NULL
  }
  last_nest <- NULL
  nest_visit <- NULL
  nest_location <- NULL
  if (!is.null(nest_ids)) {
    last_nest <- utils::tail(ids, 1L)
    context <- utils::tail(
      as.data.frame(nests[nests$nest_id == last_nest, ]),
      1L
    )
    site <- field_resightings_value(context, "site")
    species <- field_resightings_value(context, "species")
    nest_visit <- list(rows = data.frame(), failed = FALSE)
    if (!startsWith(last_nest, "-")) {
      if (is.null(site) || is.null(species)) {
        nest_visit$failed <- TRUE
      } else {
        query <- field_resightings_latest_nest_query(
          last_nest,
          site,
          species,
          refdate
        )
        rows <- tryCatch(
          db_get(query$sql, params = query$params),
          error = function(error) NULL
        )
        nest_visit$failed <- is.null(rows) || "error" %in% names(rows)
        if (!nest_visit$failed) nest_visit$rows <- as.data.frame(rows)
        query <- field_resightings_nest_location_query(last_nest, site, species, refdate)
        location <- tryCatch(
          db_get(query$sql, params = query$params),
          error = function(error) NULL
        )
        if (!is.null(location) && !"error" %in% names(location) &&
            nrow(location) && all(c("lat", "lon") %in% names(location))) {
          lat <- suppressWarnings(as.numeric(location$lat[[1L]]))
          lon <- suppressWarnings(as.numeric(location$lon[[1L]]))
          if (is.finite(lat) && abs(lat) <= 90 &&
              is.finite(lon) && abs(lon) <= 180) {
            nest_location <- list(lat = lat, lon = lon)
          }
        }
      }
    }
  }

  query <- field_resightings_first_capture_query(combo, refdate)
  first <- tryCatch(
    db_get(query$sql, params = query$params),
    error = function(error) NULL
  )
  first_failed <- is.null(first) || "error" %in% names(first)
  capture_tables <- c("CAPTURES", "CAPTURES_ARCHIVE")
  available_tables <- capture_tables[
    !vapply(
      sources[match(capture_tables, names(queries))],
      function(source) source$failed,
      logical(1)
    )
  ]
  if (first_failed && length(available_tables) == 1L) {
    query <- field_resightings_first_capture_query(
      combo,
      refdate,
      tables = available_tables
    )
    first <- tryCatch(
      db_get(query$sql, params = query$params),
      error = function(error) NULL
    )
    first_failed <- is.null(first) || "error" %in% names(first)
  }
  first_found <- !first_failed &&
    nrow(first) > 0L &&
    all(c("first_capture", "n") %in% names(first)) &&
    !is.na(first$n[[1L]]) &&
    first$n[[1L]] > 0

  list(
    combo = field_resightings_normalize_combo(combo),
    refdate = as.Date(refdate),
    sources = stats::setNames(sources, names(queries)),
    nest_ids = nest_ids,
    nests_failed = nests_failed,
    last_nest = last_nest,
    nest_visit = nest_visit,
    nest_location = nest_location,
    first_capture = list(
      date = if (first_found) first$first_capture[[1L]] else NULL,
      found = first_found,
      failed = first_failed
    )
  )
}


field_resightings_value <- function(row, column) {
  value <- row[[column]]
  if (is.null(value) || !length(value) || is.na(value[[1L]])) {
    return(NULL)
  }
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value) || toupper(value) %in% c("NA", "N/A", "NULL")) {
    return(NULL)
  }
  value
}


field_resightings_date_label <- function(date, refdate, time = NULL) {
  date <- suppressWarnings(as.Date(as.character(date), format = "%Y-%m-%d"))
  if (length(date) != 1L || is.na(date)) {
    return("—")
  }

  days <- as.integer(as.Date(refdate) - date)
  unit <- if (abs(days) == 1L) "day" else "days"
  relative <- if (days < 0L) {
    paste("in", abs(days), unit)
  } else {
    paste(days, unit, "ago")
  }

  clock <- NULL
  if (length(time) == 1L && !is.na(time)) {
    if (inherits(time, "difftime")) {
      seconds <- as.numeric(time, units = "secs")
      if (is.finite(seconds) && seconds >= 0 && seconds < 86400) {
        clock <- sprintf("%02d:%02d", as.integer(seconds %/% 3600),
          as.integer(seconds %/% 60 %% 60))
      }
    } else {
      time <- trimws(as.character(time))
      if (grepl("^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9](\\.[0-9]+)?)?$", time)) {
        clock <- substr(time, 1L, 5L)
      }
    }
  }
  paste0(format(date, "%Y-%m-%d"), if (!is.null(clock)) paste0(" ", clock),
    " (", relative, ")")
}


field_resightings_record_ui <- function(row, source, combo, refdate, exclude_columns = character()) {
  value <- function(column) field_resightings_value(row, column)
  field <- function(column, text = value(column)) {
    if (is.null(text)) {
      text <- "—"
    }
    label <- if (column == "date") {
      switch(
        source,
        CAPTURES = "capture_date",
        CAPTURES_ARCHIVE = "last season capt.",
        NEST_VISIT = "last_nest_visit",
        column
      )
    } else if (
      source == "NEST_VISIT" &&
        column %in% c("nest_state", "clutch_size", "brood_size")
    ) {
      paste0("last_", column)
    } else {
      column
    }
    htmltools::tags$tr(
      htmltools::tags$th(scope = "row", gsub("_", " ", label, fixed = TRUE)),
      htmltools::tags$td(text)
    )
  }
  if (source == "NESTS") {
    partners <- trimws(as.character(row$partner))
    partners <- partners[
      !is.na(partners) & nzchar(partners) &
        !toupper(partners) %in% c("NA", "N/A", "NULL")
    ]
    partners <- unique(gsub("-", "", partners, fixed = TRUE))
    return(htmltools::tags$tbody(
      class = "field-resightings-record",
      field(
        "partner",
        if (length(partners)) paste(partners, collapse = ", ") else NULL
      )
    ))
  }
  columns <- if (source == "CAPTURES") {
    c("ring", "field_sex", "tag_id")
  } else if (source == "CAPTURES_ARCHIVE") {
    c("ring", "field_sex", "tag_id")
  } else if (source == "NEST_VISIT") {
    c(
      "nest_state",
      "hatch_state",
      "bird_inc",
      "clutch_size",
      "brood_size"
    )
  } else {
    "ring"
  }

  htmltools::tags$tbody(
    class = "field-resightings-record",
    if (source == "RESIGHTINGS") {
      htmltools::tagList(
        field(
          "first_seen",
          field_resightings_date_label(value("first_seen"), refdate)
        ),
        field("last_seen", field_resightings_date_label(value("last_seen"), refdate))
      )
    } else {
      field("date", field_resightings_date_label(value("date"), refdate,
        time = if (source == "NEST_VISIT") row$time_visit else NULL))
    },
    lapply(setdiff(columns, exclude_columns), field)
  )
}


field_resightings_results_ui <- function(result) {
  tags <- htmltools::tags
  behaviour_groups <- list(
    Feeding = c("FA", "FM", "FF", "FC"),
    Mating = c("CO", "FT"),
    `Nest/chicks` = c("IN", "BC", "AC", "BW", "NM", "SC"),
    Chilling = c("RS", "PR", "LF"),
    Other = c("AT", "OB")
  )
  nest_ids <- field_resightings_value(list(nest_id = result$nest_ids), "nest_id")
  has_first_capture <- isTRUE(result$first_capture$found) &&
    length(result$first_capture$date) == 1L &&
    !is.na(result$first_capture$date)
  has_matches <- field_resightings_has_matches(result)
  # Combine shared bird details once, preferring current captures, then archive
  # captures, and finally resightings. Each query already sorts newest first.
  summary <- data.frame(date = NA_character_)
  captures <- result$sources$CAPTURES
  if (!is.null(captures) && !captures$failed && nrow(captures$rows)) {
    summary <- captures$rows[1L, , drop = FALSE]
  }
  shared_columns <- c("ring", "field_sex", "tag_id")
  for (column in shared_columns) {
    summary[[column]] <- NA_character_
    for (source in c("CAPTURES", "CAPTURES_ARCHIVE", "RESIGHTINGS")) {
      found <- result$sources[[source]]
      if (is.null(found) || found$failed) next
      for (i in seq_len(nrow(found$rows))) {
        value <- field_resightings_value(found$rows[i, , drop = FALSE], column)
        if (!is.null(value)) {
          summary[[column]] <- value
          break
        }
      }
      if (!is.na(summary[[column]])) break
    }
  }
  records <- lapply(c("CAPTURES_ARCHIVE", "CAPTURES", "RESIGHTINGS"), function(source) {
    found <- result$sources[[source]]
    row <- if (source == "CAPTURES") {
      summary
    } else if (!is.null(found) && !found$failed && nrow(found$rows)) {
      found$rows[1L, , drop = FALSE]
    } else {
      data.frame()
    }
    field_resightings_record_ui(
      row, source, result$combo, result$refdate,
      exclude_columns = if (source == "CAPTURES") character() else shared_columns
    )
  })
  limits <- lapply(names(result$sources), function(source) {
    found <- result$sources[[source]]
    if (source == "NESTS" && !found$failed && found$more) {
      tags$p(
        class = "small text-muted",
        "First 50 partners"
      )
    }
  })

  tags$div(
    class = "field-resightings-results",
    `aria-live` = "polite",
    if (!has_matches) {
      tags$p(
        class = "text-muted",
        "Not found"
      )
    },
    limits,
    if (has_matches) {
      tags$table(
        class = "field-resightings-table",
        tags$thead(tags$tr(
          tags$th(scope = "col", "column"),
          tags$th(scope = "col", "value")
        )),
        tags$tbody(
          class = "field-resightings-record",
          tags$tr(
            tags$th(scope = "row", "first capture"),
            tags$td(
              if (has_first_capture) field_resightings_date_label(
                result$first_capture$date,
                result$refdate
              ) else "—"
            )
          )
        ),
        tags$tbody(
          class = "field-resightings-record",
          tags$tr(
            tags$th(scope = "row", "nest id"),
            tags$td(if (is.null(nest_ids)) "—" else nest_ids)
          )
        ),
        field_resightings_record_ui(
          if (
            !is.null(result$sources$NESTS) &&
              !result$sources$NESTS$failed &&
              nrow(result$sources$NESTS$rows)
          ) result$sources$NESTS$rows else data.frame(),
          "NESTS",
          result$combo,
          result$refdate
        ),
        tags$tbody(
          class = "field-resightings-record",
          tags$tr(
            class = "field-resightings-distance-row",
            tags$th(scope = "row", "your dist to nest"),
            tags$td(
              class = "field-resightings-distance",
              `data-nest-lat` = result$nest_location$lat,
              `data-nest-lon` = result$nest_location$lon,
              "—"
            )
          )
        ),
        field_resightings_record_ui(
          if (
            !is.null(result$nest_visit) &&
              !result$nest_visit$failed &&
              nrow(result$nest_visit$rows)
          ) result$nest_visit$rows else data.frame(),
          "NEST_VISIT",
          result$combo,
          result$refdate
        ),
        records
      )
    },
    if (has_matches && !is.null(result$save_token)) {
      tags$form(
        class = "field-resightings-save-form mt-3",
        `data-search-token` = result$save_token,
        `data-combo` = result$combo,
        tags$fieldset(
          class = "field-resightings-behaviours",
          tags$legend("Behaviour"),
          tags$button(
            type = "button", class = "btn btn-outline-primary field-resightings-behaviour-open",
            `aria-haspopup` = "dialog", `aria-controls` = "field_resightings_behaviour_sheet",
            htmltools::HTML("Choose behaviour<strong>s</strong>")
          ),
          tags$div(class = "field-resightings-behaviour-selected"),
          tags$dialog(
            id = "field_resightings_behaviour_sheet", class = "field-resightings-behaviour-sheet",
            `aria-labelledby` = "field_resightings_behaviour_title",
            tags$div(class = "field-resightings-behaviour-header",
              tags$h3(id = "field_resightings_behaviour_title", "Behaviour")),
            tags$div(
              class = "field-resightings-behaviour-options",
              lapply(names(behaviour_groups), function(group) {
                choices <- field_resightings_behaviours()
                choices <- choices[match(behaviour_groups[[group]], choices)]
                tags$section(
                  tags$h4(group),
                  tags$div(
                    class = "field-resightings-behaviour-grid",
                    lapply(names(choices), function(label) {
                      tags$label(
                        class = "field-resightings-behaviour",
                        tags$input(type = "checkbox", name = "field_resightings_behav",
                          value = unname(choices[[label]]), `data-label` = label),
                        tags$span(label)
                      )
                    })
                  )
                )
              })
            ),
            tags$div(class = "field-resightings-behaviour-footer",
              tags$button(type = "button",
                class = "btn btn-primary btn-lg btn-block field-resightings-behaviour-done", "Done"))
          )
        ),
        tags$button(
          type = "submit", class = "btn btn-primary btn-lg btn-block",
          "Save resighting"
        ),
        tags$div(class = "field-resightings-save-status mt-2", role = "status",
          `aria-live` = "polite")
      )
    }
  )
}
