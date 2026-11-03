quick_search_normalize_combo <- function(combo) {
  if (length(combo) != 1L || is.na(combo)) {
    stop("Use four colour letters, e.g. RROR.")
  }

  combo <- toupper(trimws(as.character(combo)))
  if (!grepl("^[BGROWLY]{2}-?[BGROWLY]{2}$", combo)) {
    stop("Use four colour letters, e.g. RROR.")
  }

  gsub("-", "", combo, fixed = TRUE)
}


quick_search_server <- function(input, output, refdate) {
  result <- shiny::eventReactive(input$quick_search_request, {
    combo <- tryCatch(
      quick_search_normalize_combo(input$quick_search_request$combo),
      error = function(error) NULL
    )
    if (is.null(combo)) {
      return(list(message = "Not found"))
    }

    quick_search_fetch(combo, refdate())
  })

  output$quick_search_results <- shiny::renderUI({
    tags <- htmltools::tags
    if (is.null(input$quick_search_request)) {
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

    quick_search_results_ui(found)
  })

  invisible(result)
}


quick_search_combo_sql <- function(suffix = "") {
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


quick_search_queries <- function(combo, refdate) {
  combo <- quick_search_normalize_combo(combo)
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
      quick_search_combo_sql(),
      " AS release_combo",
      if (incoming) {
        paste0(
          ",\n    ",
          quick_search_combo_sql("_in"),
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
  queries$NESTS <- quick_search_partner_query(combo, refdate)
  queries
}


quick_search_partner_query <- function(combo, refdate, focal_nests = NULL) {
  combo <- quick_search_normalize_combo(combo)
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
    quick_search_combo_sql(),
    " AS release_combo,\n",
    quick_search_combo_sql("_in"),
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


quick_search_nest_query <- function(combo, refdate) {
  combo <- quick_search_normalize_combo(combo)
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
      quick_search_combo_sql(),
      " = ?\n",
      "  AND nest_id NOT IN ('NA', 'N/A', 'NULL', 'NO_NEST')\n",
      "GROUP BY nest_id, site, species\nORDER BY MIN(date) IS NULL, MIN(date), nest_id, site, species"
    ),
    params = c(rep(list(as.character(as.Date(refdate))), 3L), list(combo))
  )
}


quick_search_latest_nest_query <- function(nest_id, site, species, refdate) {
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


quick_search_first_capture_query <- function(
  combo,
  refdate,
  tables = c("CAPTURES", "CAPTURES_ARCHIVE")
) {
  combo <- quick_search_normalize_combo(combo)
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
      quick_search_combo_sql(),
      " AS release_combo,\n",
      quick_search_combo_sql("_in"),
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


quick_search_db_get <- function(sql, params = NULL) {
  # Missing optional sources are handled by the combined search result UI.
  # Avoid DBq's SQL-prefix toast before that handling can run.
  DBq(sql, params = params, notify = FALSE)
}


quick_search_fetch <- function(combo, refdate, db_get = quick_search_db_get) {
  queries <- quick_search_queries(combo, refdate)
  # Use all matching current-season nest links, including resightings, as
  # anchors when the focal bird has no capture at a particular nest.
  nest_query <- quick_search_nest_query(combo, refdate)
  nests <- tryCatch(
    db_get(nest_query$sql, params = nest_query$params),
    error = function(error) NULL
  )
  nests_failed <- is.null(nests) || "error" %in% names(nests)
  if (!nests_failed && nrow(nests)) {
    queries$NESTS <- quick_search_partner_query(combo, refdate, focal_nests = nests)
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
  if (!is.null(nest_ids)) {
    last_nest <- utils::tail(ids, 1L)
    context <- utils::tail(
      as.data.frame(nests[nests$nest_id == last_nest, ]),
      1L
    )
    site <- quick_search_value(context, "site")
    species <- quick_search_value(context, "species")
    nest_visit <- list(rows = data.frame(), failed = FALSE)
    if (!startsWith(last_nest, "-")) {
      if (is.null(site) || is.null(species)) {
        nest_visit$failed <- TRUE
      } else {
        query <- quick_search_latest_nest_query(
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
      }
    }
  }

  query <- quick_search_first_capture_query(combo, refdate)
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
    query <- quick_search_first_capture_query(
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
    combo = quick_search_normalize_combo(combo),
    refdate = as.Date(refdate),
    sources = stats::setNames(sources, names(queries)),
    nest_ids = nest_ids,
    nests_failed = nests_failed,
    last_nest = last_nest,
    nest_visit = nest_visit,
    first_capture = list(
      date = if (first_found) first$first_capture[[1L]] else NULL,
      found = first_found,
      failed = first_failed
    )
  )
}


quick_search_value <- function(row, column) {
  value <- row[[column]]
  if (is.null(value) || !length(value) || is.na(value[[1L]])) {
    return(NULL)
  }
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value) || toupper(value) %in% c("NA", "NULL")) {
    return(NULL)
  }
  value
}


quick_search_date_label <- function(date, refdate) {
  date <- suppressWarnings(as.Date(as.character(date), format = "%Y-%m-%d"))
  if (length(date) != 1L || is.na(date)) {
    return("No date")
  }

  days <- as.integer(as.Date(refdate) - date)
  unit <- if (abs(days) == 1L) "day" else "days"
  relative <- if (days < 0L) {
    paste("in", abs(days), unit)
  } else {
    paste(days, unit, "ago")
  }

  paste0(format(date, "%Y-%m-%d"), " (", relative, ")")
}


quick_search_record_ui <- function(row, source, combo, refdate) {
  value <- function(column) quick_search_value(row, column)
  field <- function(column, text = value(column)) {
    if (is.null(text)) {
      return(NULL)
    }
    label <- if (column == "date") {
      switch(
        source,
        CAPTURES = "capture_date",
        CAPTURES_ARCHIVE = "archive_capture_date",
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
      htmltools::tags$th(scope = "row", label),
      htmltools::tags$td(text)
    )
  }
  if (source == "NESTS") {
    partners <- trimws(as.character(row$partner))
    partners <- partners[!is.na(partners) & nzchar(partners)]
    partners <- unique(gsub("-", "", partners, fixed = TRUE))
    return(htmltools::tags$tbody(
      class = "quick-search-record",
      field(
        "partner",
        if (length(partners)) paste(partners, collapse = ", ") else NULL
      )
    ))
  }
  columns <- if (source == "CAPTURES") {
    c(
      "ring",
      "field_sex",
      "UL_in",
      "LL_in",
      "UR_in",
      "LR_in",
      "tag_id",
      "tag_action",
      "tag_id_in",
      "gps_id",
      "gps_point"
    )
  } else if (source == "CAPTURES_ARCHIVE") {
    c("ring", "field_sex", "gen_sex", "tag_id")
  } else if (source == "NEST_VISIT") {
    c(
      "time_visit",
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
    class = "quick-search-record",
    if (source == "RESIGHTINGS") {
      htmltools::tagList(
        field(
          "first_seen",
          quick_search_date_label(value("first_seen"), refdate)
        ),
        field("last_seen", quick_search_date_label(value("last_seen"), refdate))
      )
    } else if (source != "CAPTURES_ARCHIVE" || !is.null(value("date"))) {
      field("date", quick_search_date_label(value("date"), refdate))
    },
    lapply(columns, field)
  )
}


quick_search_results_ui <- function(result) {
  tags <- htmltools::tags
  has_first_capture <- isTRUE(result$first_capture$found) &&
    length(result$first_capture$date) == 1L &&
    !is.na(result$first_capture$date)
  has_matches <- any(vapply(
    result$sources,
    function(found) {
      !found$failed && nrow(found$rows) > 0L
    },
    logical(1)
  )) ||
    !is.null(result$nest_ids) ||
    has_first_capture
  records <- lapply(names(result$sources), function(source) {
    found <- result$sources[[source]]
    n <- nrow(found$rows)
    if (found$failed) {
      return(NULL)
    }
    if (!n) {
      return(NULL)
    }
    if (source == "NESTS") {
      return(NULL)
    }
    lapply(seq_len(n), function(i) {
      quick_search_record_ui(
        found$rows[i, , drop = FALSE],
        source,
        result$combo,
        result$refdate
      )
    })
  })
  limits <- lapply(names(result$sources), function(source) {
    found <- result$sources[[source]]
    if (!found$failed && found$more) {
      tags$p(
        class = "small text-muted",
        if (source == "NESTS") {
          "First 50 partners"
        } else {
          "Latest 50 records"
        }
      )
    }
  })

  tags$div(
    class = "quick-search-results",
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
        class = "quick-search-table",
        tags$thead(tags$tr(
          tags$th(scope = "col", "column"),
          tags$th(scope = "col", "value")
        )),
        if (has_first_capture) {
          tags$tbody(
            class = "quick-search-record",
            tags$tr(
              tags$th(scope = "row", "first_capture"),
              tags$td(quick_search_date_label(
                result$first_capture$date,
                result$refdate
              ))
            )
          )
        },
        if (!is.null(result$nest_ids)) {
          tags$tbody(
            class = "quick-search-record",
            tags$tr(tags$th(scope = "row", "nest_id"), tags$td(result$nest_ids))
          )
        },
        if (
          !is.null(result$sources$NESTS) &&
            !result$sources$NESTS$failed &&
            nrow(result$sources$NESTS$rows)
        ) {
          quick_search_record_ui(
            result$sources$NESTS$rows,
            "NESTS",
            result$combo,
            result$refdate
          )
        },
        if (
          !is.null(result$nest_visit) &&
            !result$nest_visit$failed &&
            nrow(result$nest_visit$rows)
        ) {
          quick_search_record_ui(
            result$nest_visit$rows,
            "NEST_VISIT",
            result$combo,
            result$refdate
          )
        },
        records
      )
    }
  )
}
