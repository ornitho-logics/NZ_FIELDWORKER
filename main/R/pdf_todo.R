todo_pdf_prepare_team_marks <- function(available_combos = NULL) {
  if (is.null(available_combos)) {
    available_combos <- tryCatch(
      DBq("
        SELECT mark
        FROM AVAILABLE_COMBOS
        WHERE site_code = 'CR'
        ORDER BY
          CASE
            WHEN UPPER(TRIM(LL)) = 'GY' THEN 1
            ELSE 0
          END,
          CASE
            WHEN LEFT(LL, 1) = 'Y' THEN 0
            ELSE 1
          END,
          CASE
            WHEN CONCAT(LL, LR) NOT REGEXP '[LR]' THEN 0
            WHEN CONCAT(LL, LR) REGEXP 'R' THEN 2
            WHEN CONCAT(LL, LR) REGEXP 'L' THEN 1
            ELSE 0
          END,
          LL,
          LR
      "),
      error = function(e) {
        stop(
          "Could not load AVAILABLE_COMBOS for the Team marks table.",
          call. = FALSE
        )
      }
    )
  }

  combos_dt <- data.table(available_combos)
  if ("mark" %in% names(combos_dt)) {
    combos_dt[, mark := trimws(as.character(mark))]
    combos_dt <- combos_dt[!is.na(mark) & nzchar(mark)]
  }
  marks <- if ("mark" %in% names(combos_dt)) {
    marks <- as.character(combos_dt$mark)
    is_gy <- if ("LL" %in% names(combos_dt)) {
      toupper(trimws(as.character(combos_dt$LL))) == "GY"
    } else {
      grepl("^GY-", toupper(marks))
    }
    marks[order(is_gy, seq_along(marks))]
  } else {
    character()
  }

  if (!length(marks)) {
    stop(
      "No available combinations were returned for the Team marks table.",
      call. = FALSE
    )
  }
  marks <- head(marks, 30)

  n_teams <- 3L
  team_sizes <- rep(length(marks) %/% n_teams, n_teams)
  remainder <- length(marks) %% n_teams
  if (remainder) {
    team_sizes[seq_len(remainder)] <-
      team_sizes[seq_len(remainder)] + 1L
  }

  n_columns <- max(team_sizes)
  team_rows <- vector("list", n_teams)
  next_mark <- 1L
  for (team_index in seq_len(n_teams)) {
    team_size <- team_sizes[[team_index]]
    team_row <- if (team_size) {
      marks[seq.int(next_mark, length.out = team_size)]
    } else {
      character()
    }
    team_rows[[team_index]] <- c(
      team_row,
      rep("", n_columns - team_size)
    )
    next_mark <- next_mark + team_size
  }

  team_marks <- as.data.table(do.call(rbind, team_rows))

  setnames(team_marks, as.character(seq_len(ncol(team_marks))))
  team_marks[, Team := c("Team 1", "Team 2", "Team 3")]
  setcolorder(team_marks, c("Team", as.character(seq_len(n_columns))))

  team_marks
}


todo_pdf_as_numeric <- function(x) {
  if (inherits(x, "integer64")) {
    if (!requireNamespace("bit64", quietly = TRUE)) {
      stop("Package {bit64} is required to format 64-bit database values.")
    }
    return(as.numeric(bit64::as.integer64(x)))
  }
  suppressWarnings(as.numeric(as.character(x)))
}


todo_pdf_normalize_chick_encounters <- function(
  chick_encounters,
  reference_date = NULL
) {
  empty_output <- data.table(
    nest_id = character()
  )
  if (
    is.null(chick_encounters)
      || !nrow(chick_encounters)
      || !all(c("nest_id", "date") %in% names(chick_encounters))
  ) {
    return(empty_output)
  }

  encounters <- data.table(chick_encounters)
  encounters[, nest_id := trimws(as.character(nest_id))]
  encounters[, encounter_date := suppressWarnings(as.Date(as.character(date)))]
  encounters <- encounters[
    !is.na(nest_id)
      & nzchar(nest_id)
      & !is.na(encounter_date)
  ]
  if (!is.null(reference_date) && !is.na(reference_date)) {
    encounters <- encounters[encounter_date <= as.Date(reference_date)]
  }
  if (!nrow(encounters)) {
    return(data.table())
  }

  if (!"ring" %in% names(encounters)) {
    encounters[, ring := NA_character_]
  }
  encounters[, ring_key := toupper(trimws(as.character(ring)))]
  encounters[
    is.na(ring_key)
      | !nzchar(ring_key)
      | ring_key %chin% c("NA", "NULL", "N/A"),
    ring_key := NA_character_
  ]
  if (!"source" %in% names(encounters)) {
    encounters[, source := "encounter"]
  }
  encounters[, source := tolower(trimws(as.character(source)))]
  if (!"event_id" %in% names(encounters)) {
    encounters[, event_id := seq_len(.N)]
  }

  # A ring is the stable chick identity across captures and resightings.  A
  # ringless event is retained only when it cannot be matched to a ringed
  # event from the same brood on the same date.  This prevents one chick from
  # being counted twice when a capture and a ringless resighting describe the
  # same occasion, while preserving genuinely ringless encounters.
  ringed_dates <- unique(
    encounters[!is.na(ring_key), .(nest_id, encounter_date)]
  )
  if (nrow(ringed_dates)) {
    ringed_date_keys <- paste(
      ringed_dates$nest_id,
      ringed_dates$encounter_date,
      sep = "\u001f"
    )
    encounters[, nest_date_key := paste(
      nest_id,
      encounter_date,
      sep = "\u001f"
    )]
    encounters <- encounters[
      !is.na(ring_key)
        | !(nest_date_key %chin% ringed_date_keys)
    ]
    encounters[, nest_date_key := NULL]
  }

  encounters[, event_key := fifelse(
    !is.na(ring_key),
    paste0("ring:", ring_key),
    paste0(source, ":", as.character(event_id))
  )]

  encounters[]
}


todo_pdf_latest_chick_encounter_counts <- function(
  chick_encounters,
  reference_date = NULL
) {
  empty_output <- data.table(
    nest_id = character(),
    latest_encounter_date = as.Date(character()),
    latest_chick_count = integer(),
    latest_chick_ring_list = character()
  )
  encounters <- todo_pdf_normalize_chick_encounters(
    chick_encounters,
    reference_date
  )
  if (!nrow(encounters)) {
    return(empty_output)
  }

  encounters[, latest_encounter_date := max(encounter_date), by = nest_id]
  # A same-date capture is the authoritative in-hand encounter when it is
  # accompanied by a resighting row.  Prefer capture rows for that date so
  # one chick is not counted twice for a single field occasion; if there is
  # no capture on the latest date, use the latest resighting rows.
  latest <- encounters[
    encounter_date == latest_encounter_date,
  ]
  latest[, capture_on_latest_date := any(source == "capture"), by = nest_id]
  latest <- latest[
    !capture_on_latest_date | source == "capture"
  ]
  latest <- latest[
    , .(
        latest_encounter_date = latest_encounter_date[1L],
        latest_chick_count = uniqueN(event_key),
        latest_chick_ring_list = paste(
          sort(unique(ring_key[!is.na(ring_key)])),
          collapse = ", "
        )
      ),
    by = nest_id
  ]
  latest[]
}


todo_pdf_captured_chick_ring_lists <- function(chick_captures) {
  empty_output <- data.table(
    nest_id = character(),
    captured_chick_ring_list = character()
  )
  if (
    is.null(chick_captures)
      || !nrow(chick_captures)
      || !all(c("nest_id", "ring") %in% names(chick_captures))
  ) {
    return(empty_output)
  }

  captures <- data.table(chick_captures)
  captures[, nest_id := trimws(as.character(nest_id))]
  captures[, ring_key := toupper(trimws(as.character(ring)))]
  captures[
    is.na(ring_key)
      | !nzchar(ring_key)
      | ring_key %chin% c("NA", "NULL", "N/A"),
    ring_key := NA_character_
  ]
  captures <- captures[
    !is.na(nest_id)
      & nzchar(nest_id)
      & !is.na(ring_key)
  ]
  if (!nrow(captures)) {
    return(empty_output)
  }

  captures[
    , .(
      captured_chick_ring_list = paste(
        sort(unique(ring_key)),
        collapse = ", "
      )
    ),
    by = nest_id
  ][]
}


todo_pdf_chick_event_context_sql <- function(reference_date = NULL) {
  reference_date <- as.Date(reference_date)
  reference_date_sql <- if (!is.na(reference_date)) {
    paste0(
      "CAST('",
      format(reference_date, "%Y-%m-%d"),
      "' AS DATE)"
    )
  } else {
    "(SELECT value FROM settings WHERE variable = 'reference_date' LIMIT 1)"
  }

  glue::glue(
  "
  WITH
  adult_nest_events AS (
    SELECT
      r.date AS event_date,
      r.gps_id,
      r.gps_point,
      TRIM(r.nest_id) AS nest_id
    FROM RESIGHTINGS r
    WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
      AND r.age = 'A'
      AND r.nest_id IS NOT NULL
      AND TRIM(r.nest_id) <> ''
      AND UPPER(TRIM(r.nest_id)) <> 'NO_NEST'
      AND r.date <= {reference_date_sql}

    UNION ALL

    SELECT
      c.date AS event_date,
      c.gps_id,
      c.gps_point,
      TRIM(c.nest_id) AS nest_id
    FROM CAPTURES c
    WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
      AND c.age = 'A'
      AND c.nest_id IS NOT NULL
      AND TRIM(c.nest_id) <> ''
      AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
      AND c.date <= {reference_date_sql}
  ),
  same_occasion_chick_gps_candidates AS (
    SELECT
      chick.pk AS resighting_pk,
      adult.nest_id AS adult_nest_id
    FROM RESIGHTINGS chick
    JOIN adult_nest_events adult
      ON adult.event_date = chick.date
     AND adult.gps_id = chick.gps_id
     AND adult.gps_point = chick.gps_point
    WHERE UPPER(TRIM(COALESCE(chick.site, ''))) = 'CR'
      AND chick.age = 'C'
      AND UPPER(TRIM(COALESCE(chick.rclass, ''))) <> 'H'
      AND chick.date <= {reference_date_sql}
      AND chick.gps_id IS NOT NULL
      AND chick.gps_point IS NOT NULL
      AND (
        chick.nest_id IS NULL
        OR TRIM(chick.nest_id) = ''
        OR UPPER(TRIM(chick.nest_id)) = 'NO_NEST'
      )
  ),
  same_occasion_chick_gps_summary AS (
    SELECT
      resighting_pk,
      CASE
        WHEN COUNT(DISTINCT adult_nest_id) = 1
        THEN MIN(adult_nest_id)
        ELSE NULL
      END AS resolved_nest_id
    FROM same_occasion_chick_gps_candidates
    GROUP BY resighting_pk
  ),
  raw_capture_events AS (
    SELECT
      c.pk AS capture_pk,
      c.date AS event_date,
      CASE
        WHEN UPPER(TRIM(COALESCE(c.nest_id, ''))) IN ('', 'NO_NEST')
        THEN NULL
        ELSE UPPER(TRIM(c.nest_id))
      END AS recorded_nest_id,
      NULLIF(
        NULLIF(UPPER(TRIM(COALESCE(c.ring, ''))), ''),
        'NA'
      ) AS ring_key,
      c.site,
      c.gps_id,
      c.gps_point,
      c.caught,
      c.age,
      c.LL,
      c.LR
    FROM CAPTURES c
    WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
      AND c.age = 'C'
      AND c.date <= {reference_date_sql}
  ),
  known_ring_nest_history AS (
    SELECT
      capture_pk,
      event_date,
      ring_key,
      recorded_nest_id AS nest_id
    FROM raw_capture_events
    WHERE ring_key IS NOT NULL
      AND recorded_nest_id IS NOT NULL
  ),
  latest_prior_ring_date AS (
    SELECT
      e.capture_pk,
      MAX(h.event_date) AS latest_prior_event_date
    FROM raw_capture_events e
    JOIN known_ring_nest_history h
      ON h.ring_key = e.ring_key
     AND h.event_date <= e.event_date
    WHERE e.ring_key IS NOT NULL
      AND e.recorded_nest_id IS NULL
    GROUP BY e.capture_pk
  ),
  latest_prior_ring_nests AS (
    SELECT DISTINCT
      e.capture_pk,
      h.nest_id
    FROM raw_capture_events e
    JOIN latest_prior_ring_date d
      ON d.capture_pk = e.capture_pk
    JOIN known_ring_nest_history h
      ON h.ring_key = e.ring_key
     AND h.event_date = d.latest_prior_event_date
  ),
  resolved_prior_ring_nests AS (
    SELECT
      capture_pk,
      MAX(nest_id) AS inferred_nest_id
    FROM latest_prior_ring_nests
    GROUP BY capture_pk
    HAVING COUNT(*) = 1
  ),
  capture_events AS (
    SELECT
      COALESCE(e.recorded_nest_id, inferred.inferred_nest_id) AS nest_id,
      e.event_date AS date,
      'capture' AS source,
      CAST(e.capture_pk AS CHAR(64)) AS event_id,
      e.ring_key AS ring,
      e.site,
      e.gps_id,
      e.gps_point,
      e.caught,
      e.age,
      e.LL,
      e.LR
    FROM raw_capture_events e
    LEFT JOIN resolved_prior_ring_nests inferred
      ON inferred.capture_pk = e.capture_pk
    WHERE COALESCE(e.recorded_nest_id, inferred.inferred_nest_id) IS NOT NULL
  ),
  resighting_events AS (
    SELECT DISTINCT
      COALESCE(
        h_assoc.resolved_nest_id,
        gps_assoc.resolved_nest_id,
        NULLIF(
          NULLIF(TRIM(r.nest_id), ''),
          'NO_NEST'
        )
      ) AS nest_id,
      r.date,
      'resighting' AS source,
      CAST(r.pk AS CHAR(64)) AS event_id,
      NULLIF(
        NULLIF(UPPER(TRIM(COALESCE(r.ring, ''))), ''),
        'NA'
      ) AS ring,
      r.site,
      r.gps_id,
      r.gps_point,
      CAST(NULL AS CHAR(32)) AS caught,
      r.age,
      r.LL,
      r.LR
    FROM RESIGHTINGS r
    LEFT JOIN RESIGHTINGS_H_BROOD_ASSOCIATIONS h_assoc
      ON r.pk = h_assoc.resighting_pk
    LEFT JOIN same_occasion_chick_gps_summary gps_assoc
      ON r.pk = gps_assoc.resighting_pk
    WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
      AND r.age = 'C'
      AND r.date <= {reference_date_sql}
      AND (
        (
          r.nest_id IS NOT NULL
          AND TRIM(r.nest_id) <> ''
          AND UPPER(TRIM(r.nest_id)) <> 'NO_NEST'
        )
        OR h_assoc.resolved_nest_id IS NOT NULL
        OR gps_assoc.resolved_nest_id IS NOT NULL
      )
  )
  SELECT * FROM capture_events
  UNION ALL
  SELECT * FROM resighting_events
  ")
}


todo_pdf_hatch_prediction_status <- function(hatch_prediction) {
  empty_output <- data.table(
    nest_id = character(),
    has_float_data = logical(),
    no_float_complete = logical()
  )
  if (
    is.null(hatch_prediction)
      || !nrow(hatch_prediction)
      || !all(c("nest_id", "calibration_match_type") %in% names(hatch_prediction))
  ) {
    return(empty_output)
  }

  prediction <- data.table(hatch_prediction)
  prediction[, nest_id := trimws(as.character(nest_id))]
  prediction[, calibration_match_type := trimws(as.character(
    calibration_match_type
  ))]
  prediction <- prediction[
    !is.na(nest_id) & nzchar(nest_id)
  ]
  if (!nrow(prediction)) {
    return(empty_output)
  }

  if ("float_date" %in% names(prediction)) {
    float_raw <- trimws(as.character(prediction$float_date))
    prediction[, has_float_data := !is.na(float_date) &
      nzchar(float_raw) &
      !(toupper(float_raw) %chin% c("NA", "NULL"))]
  } else {
    prediction[, has_float_data := FALSE]
  }
  prediction[, no_float_complete := calibration_match_type ==
    "complete clutch chronology" & !has_float_data]

  prediction[, .(
    has_float_data = any(has_float_data),
    no_float_complete = any(no_float_complete) & !any(has_float_data)
  ), by = nest_id]
}


todo_pdf_query_tasks <- function() {
  # Keep every PDF entry point on the same bounded query plan. TODO_LIST is a
  # complex operational view, so avoid SELECT * and discourage MariaDB from
  # merging its CTE graph into this outer projection.
  DBq(
    "
    SELECT
      nest_id,
      reference_date,
      todo,
      notes,
      days_overdue,
      priority,
      min_days_to_hatch,
      last_visit_days_ago,
      nest_state,
      clutch_size,
      brood_size,
      M_mark,
      F_mark,
      authoritative_M_mark,
      authoritative_F_mark,
      M_resighting_identity_count,
      F_resighting_identity_count,
      M_resight_association_pending,
      F_resight_association_pending,
      lat,
      lon,
      geo_priority_rank
    FROM TODO_LIST
    ",
    derived_merge_off = TRUE
  )
}


todo_pdf_version_footer <- function(version = NULL) {
  if (is.null(version)) {
    version <- get0("git_version", ifnotfound = NULL, inherits = TRUE)
  }
  if (is.null(version) || !is.list(version)) {
    version <- list(id = "unknown")
  }

  commit_id <- version$id
  if (is.null(commit_id) || !length(commit_id) || is.na(commit_id[[1L]])) {
    commit_id <- "unknown"
  } else {
    commit_id <- as.character(commit_id[[1L]])
  }

  if (isTRUE(version$local)) {
    dirty_suffix <- if (isTRUE(version$dirty)) "-dirty" else ""
    return(glue("version local-{commit_id}{dirty_suffix}"))
  }

  glue("version {commit_id}")
}


todo_pdf_parent_task_marks <- function(todo) {
  output_columns <- c("Nest", "M_todo_mark", "F_todo_mark")
  empty_output <- function() {
    data.table(
      Nest = character(),
      M_todo_mark = character(),
      F_todo_mark = character()
    )
  }

  todo_dt <- data.table(todo)
  parent_todos <- c("Parent capture", "Parent resighting")
  parent_mark_columns <- c("M_mark", "F_mark")
  if (
    !nrow(todo_dt)
      || !all(c("nest_id", "todo", parent_mark_columns) %in% names(todo_dt))
  ) {
    return(empty_output())
  }

  # New TODO_LIST rows expose the canonical adult_parent_status result. Use it
  # for the summary rather than selecting a mark from whichever task branch
  # happens to be present. Keep the older task-row fallback for local callers
  # and archived snapshots that predate these columns.
  authoritative_columns <- c(
    "authoritative_M_mark",
    "authoritative_F_mark"
  )
  if (all(authoritative_columns %in% names(todo_dt))) {
    authoritative <- todo_dt[
      !is.na(nest_id)
        & nzchar(trimws(as.character(nest_id))),
      .(
        M_todo_mark = {
          values <- trimws(as.character(authoritative_M_mark))
          values[
            is.na(values)
              | !nzchar(values)
              | toupper(values) %chin% c("NULL", "NA")
          ] <- NA_character_
          values <- values[!is.na(values)]
          if (length(values)) values[1L] else NA_character_
        },
        F_todo_mark = {
          values <- trimws(as.character(authoritative_F_mark))
          values[
            is.na(values)
              | !nzchar(values)
              | toupper(values) %chin% c("NULL", "NA")
          ] <- NA_character_
          values <- values[!is.na(values)]
          if (length(values)) values[1L] else NA_character_
        }
      ),
      by = .(Nest = trimws(as.character(nest_id)))
    ]
    if (nrow(authoritative)) {
      return(authoritative[])
    }
  }

  parent_marks <- todo_dt[
    todo %chin% parent_todos
      & !is.na(nest_id)
      & nzchar(trimws(as.character(nest_id))),
    c(
      list(Nest = trimws(as.character(nest_id))),
      lapply(.SD, function(x) {
        x <- trimws(as.character(x))
        x[
          is.na(x)
            | !nzchar(x)
            | toupper(x) %chin% c("NULL", "NA")
        ] <- NA_character_
        x
      })
    ),
    .SDcols = parent_mark_columns
  ]
  if (!nrow(parent_marks)) {
    return(empty_output())
  }

  # Parent task rows already contain the resolved adult_parent_status result.
  # Prefer a resolved single identity over a composite mark that still records
  # an unresolved MM alternative. Keep the composite when no single identity
  # is available so the summary retains the operational uncertainty.
  parent_marks <- melt(
    parent_marks,
    id.vars = "Nest",
    variable.name = "sex_mark",
    value.name = "mark",
    na.rm = TRUE
  )
  parent_marks[, mark_rank := fifelse(
    grepl("&", mark, fixed = TRUE),
    1L,
    2L
  )]
  parent_marks[, mark_length := nchar(mark)]
  setorder(parent_marks, Nest, sex_mark, -mark_rank, -mark_length, mark)
  parent_marks <- parent_marks[, .SD[1L], by = .(Nest, sex_mark)]
  parent_marks <- dcast(
    parent_marks,
    Nest ~ sex_mark,
    value.var = "mark"
  )
  setnames(
    parent_marks,
    old = intersect(parent_mark_columns, names(parent_marks)),
    new = sub(
      "_mark$",
      "_todo_mark",
      intersect(parent_mark_columns, names(parent_marks))
    )
  )
  parent_marks[]
}


todo_pdf_prepare_nest_summary <- function(
  nests_latest,
  reference_date,
  todo = NULL,
  chick_captures = NULL,
  hatch_prediction = NULL,
  parent_status = NULL,
  chick_context = NULL
) {
  nests <- data.table(nests_latest)
  if ("species" %in% names(nests)) {
    nests <- nests[
      is.na(species) |
        toupper(trimws(as.character(species))) != "WRYB"
    ]
  }
  todo_dt <- data.table(todo)

  # BROODS_LATEST is the authoritative source for negative broods. Local
  # snapshot renders may only provide positive NESTS_LATEST rows, however;
  # retain negative IDs visible in the task/chick inputs so the parent summary
  # cannot silently omit mobile broods while the derived brood view is absent.
  negative_ids <- character()
  if (nrow(todo_dt) && "nest_id" %in% names(todo_dt)) {
    task_ids <- trimws(as.character(todo_dt$nest_id))
    negative_ids <- c(negative_ids, task_ids[grepl("^-", task_ids)])
  }
  chick_dt <- data.table(chick_captures)
  if (nrow(chick_dt) && "nest_id" %in% names(chick_dt)) {
    chick_ids <- trimws(as.character(chick_dt$nest_id))
    negative_ids <- c(negative_ids, chick_ids[grepl("^-", chick_ids)])
  }
  negative_ids <- unique(negative_ids[!is.na(negative_ids) & nzchar(negative_ids)])
  if (length(negative_ids)) {
    existing_ids <- if ("nest_id" %in% names(nests)) {
      trimws(as.character(nests$nest_id))
    } else {
      character()
    }
    missing_negative_ids <- negative_ids[!negative_ids %in% existing_ids]
    if (length(missing_negative_ids)) {
      nests <- rbind(
        nests,
        data.table(
          nest_id = missing_negative_ids,
          nest_state = NA_character_,
          min_days_to_hatch = NA_real_,
          M_mark = NA_character_,
          F_mark = NA_character_,
          brood_size = NA_real_,
          is_negative_brood = TRUE,
          has_hatch_evidence = TRUE,
          task_fallback = TRUE
        ),
        fill = TRUE
      )
    }
  }
  required_columns <- c(
    "nest_id",
    "nest_state",
    "min_days_to_hatch",
    "M_mark",
    "F_mark"
  )

  # BROODS_LATEST intentionally omits failed terminal notA nests. Retain a
  # task-row fallback for those IDs without broadening BROODS_LATEST.
  not_a_fallback <- data.table()
  if (
    nrow(todo_dt)
      && all(c("nest_id", "todo") %in% names(todo_dt))
  ) {
    not_a_fallback <- todo_dt[
      todo == "notA nest-check"
        & !is.na(nest_id)
        & nzchar(trimws(as.character(nest_id))),
      .(
        nest_id = trimws(as.character(nest_id)),
        nest_state = if ("nest_state" %in% names(todo_dt)) {
          as.character(nest_state)
        } else {
          "notA"
        },
        min_days_to_hatch = if ("min_days_to_hatch" %in% names(todo_dt)) {
          todo_pdf_as_numeric(min_days_to_hatch)
        } else {
          NA_real_
        },
        M_mark = if ("M_mark" %in% names(todo_dt)) {
          as.character(M_mark)
        } else {
          NA_character_
        },
        F_mark = if ("F_mark" %in% names(todo_dt)) {
          as.character(F_mark)
        } else {
          NA_character_
        },
        brood_size = NA_real_,
        is_negative_brood = FALSE,
        has_hatch_evidence = FALSE,
        task_fallback = TRUE
      )
    ]
    not_a_fallback <- not_a_fallback[!duplicated(nest_id)]
  }

  if (!nrow(nests) || !all(required_columns %in% names(nests))) {
    if (!nrow(not_a_fallback)) {
      return(data.table(
        Nest = character(),
        `Est. Hatch` = character(),
        Male = character(),
        Female = character(),
        Symbol = character(),
        SymbolColor = character(),
        LabelFill = character(),
        LabelText = character()
      ))
    }
    nests <- not_a_fallback
  } else {
    nests[, task_fallback := FALSE]
    if (nrow(not_a_fallback)) {
      not_a_fallback <- not_a_fallback[
        !nest_id %chin% as.character(nests$nest_id)
      ]
      nests <- rbind(nests, not_a_fallback, fill = TRUE)
    }
  }

  for (column in setdiff(c("is_negative_brood", "has_hatch_evidence"), names(nests))) {
    nests[, (column) := FALSE]
  }
  for (column in setdiff(c("hatch_evidence_date", "discovery_date"), names(nests))) {
    nests[, (column) := as.Date(NA)]
  }
  if (!"task_fallback" %in% names(nests)) {
    nests[, task_fallback := FALSE]
  }

  if (!all(required_columns %in% names(nests))) {
    return(data.table(
      Nest = character(),
      `Est. Hatch` = character(),
      Male = character(),
      Female = character(),
      Symbol = character(),
      SymbolColor = character(),
      LabelFill = character(),
      LabelText = character()
    ))
  }

  state <- if ("nest_state" %in% names(nests)) {
    toupper(trimws(as.character(nests$nest_state)))
  } else {
    rep(NA_character_, nrow(nests))
  }
  is_negative_brood <- if ("is_negative_brood" %in% names(nests)) {
    as.logical(as.integer(nests$is_negative_brood))
  } else {
    grepl("^-", trimws(as.character(nests$nest_id)))
  }
  has_hatch_evidence <- if ("has_hatch_evidence" %in% names(nests)) {
    as.logical(as.integer(nests$has_hatch_evidence))
  } else if ("brood_size" %in% names(nests)) {
    state == "H" | todo_pdf_as_numeric(nests$brood_size) > 0
  } else {
    state == "H"
  }
  nests <- nests[
    !(
      state == "NOTA"
        & !has_hatch_evidence
        & !is_negative_brood
        & !task_fallback
    )
  ]
  nests[, min_days_to_hatch := todo_pdf_as_numeric(min_days_to_hatch)]
  nests[, hatch_display_date := as.Date(as.character(hatch_evidence_date))]
  nests[as.logical(nests$is_negative_brood), hatch_display_date := as.Date(as.character(discovery_date))]
  nests[, hatch_display_days := min_days_to_hatch]
  brood_mask <- as.logical(nests$is_negative_brood) | as.logical(nests$has_hatch_evidence)
  if (length(reference_date) && !is.na(reference_date[1])) {
    nests[brood_mask, hatch_display_days := as.numeric(
      hatch_display_date - as.Date(reference_date[1])
    )]
  }

  # A complete clutch with no qualifying EGGS float record still has a
  # chronology-based prediction upstream, but that prediction is not a
  # fieldworker-facing hatch estimate until flotation has been recorded.
  # Keep explicit flotation-exempt predictions (found-incomplete and stable
  # one-egg/no-increase) available for the PDF.
  prediction_status <- todo_pdf_hatch_prediction_status(hatch_prediction)
  no_float_complete_nests <- prediction_status[
    no_float_complete == TRUE,
    nest_id
  ]
  no_float_complete_summary_nests <- character()
  if (length(no_float_complete_nests)) {
    no_hatch_evidence <- is.na(has_hatch_evidence) | !has_hatch_evidence
    nest_ids <- trimws(as.character(nests$nest_id))
    no_float_complete_summary_nests <- unique(nest_ids[
      !is_negative_brood &
        no_hatch_evidence &
        nest_ids %chin% no_float_complete_nests
    ])
  }

  summary <- nests[
    !is.na(nest_id) & nzchar(trimws(as.character(nest_id))),
    .(
      Nest = trimws(as.character(nest_id)),
      `Est. Hatch` = fifelse(
        is.na(hatch_display_days),
        "",
        format(hatch_display_days, trim = TRUE, scientific = FALSE)
      ),
      Male = as.character(M_mark),
      Female = as.character(F_mark)
    )
  ]

  # The refresh-time chick context is the authoritative ring-level source for
  # flag completion. In particular, it includes flags on R/C captures whose
  # nest_id was inferred from prior ring history, which cannot be recovered
  # from the PDF's direct CAPTURES input alone. This marker is presentation
  # only: it does not alter task eligibility or brood status.
  summary[, Flagged := FALSE]
  if (
    !is.null(chick_context)
      && nrow(chick_context)
      && all(c("nest_id", "n_flagged_chick_rings") %in% names(chick_context))
  ) {
    flagged <- data.table(chick_context)
    flagged[, Nest := trimws(as.character(nest_id))]
    flagged[, n_flagged_chick_rings := todo_pdf_as_numeric(
      n_flagged_chick_rings
    )]
    flagged <- flagged[
      !is.na(Nest)
        & nzchar(Nest)
        & !is.na(n_flagged_chick_rings)
        & n_flagged_chick_rings > 0,
      .(Nest, Flagged = TRUE)
    ]
    flagged <- flagged[!duplicated(Nest)]
    if (nrow(flagged)) {
      flagged_rows <- match(flagged$Nest, summary$Nest)
      flagged_rows <- flagged_rows[!is.na(flagged_rows)]
      if (length(flagged_rows)) {
        summary[flagged_rows, Flagged := TRUE]
      }
    }
  }

  # Reuse no-float chronology predictions from EGGS_HATCH_PREDICTION for
  # summary rows that are not represented by a current TODO_LIST task.
  if (
    !is.null(hatch_prediction)
      && nrow(hatch_prediction)
      && all(c(
        "nest_id", "calibration_match_type", "days_to_hatch"
      ) %in% names(hatch_prediction))
  ) {
    prediction <- data.table(hatch_prediction)
    prediction[, nest_id := trimws(as.character(nest_id))]
    prediction <- prediction[
      calibration_match_type %chin% c(
        "found as incomplete",
        "complete clutch chronology",
        "stable one-egg/no increase"
      )
        & !is.na(nest_id)
        & nzchar(nest_id)
        & !is.na(todo_pdf_as_numeric(days_to_hatch))
    ]
    if (nrow(prediction)) {
      prediction <- prediction[
        , .(prediction_hatch = todo_pdf_as_numeric(days_to_hatch)[1L]),
        by = nest_id
      ]
      setnames(prediction, "nest_id", "Nest")
      summary <- merge(summary, prediction, by = "Nest", all.x = TRUE, sort = FALSE)
      summary[
        !is.na(prediction_hatch),
        `Est. Hatch` := format(
          prediction_hatch,
          trim = TRUE,
          scientific = FALSE
        )
      ]
      summary[, prediction_hatch := NULL]
    }
  }

  # Task rows already carry the authoritative reference-date hatch interval.
  # Reuse it for matching summary rows so the PDF does not show conflicting
  # values when BROODS_LATEST was calculated from an older snapshot.
  if (
    nrow(todo_dt)
      && all(c("nest_id", "min_days_to_hatch") %in% names(todo_dt))
  ) {
    task_hatch <- todo_dt[
      !is.na(nest_id)
        & nzchar(trimws(as.character(nest_id)))
        & !is.na(todo_pdf_as_numeric(min_days_to_hatch)),
      .(task_hatch = todo_pdf_as_numeric(min_days_to_hatch)[1L]),
      by = .(Nest = trimws(as.character(nest_id)))
    ]
    if (nrow(task_hatch)) {
      summary <- merge(summary, task_hatch, by = "Nest", all.x = TRUE, sort = FALSE)
      summary[
        !is.na(task_hatch),
        `Est. Hatch` := format(task_hatch, trim = TRUE, scientific = FALSE)
      ]
      summary[, task_hatch := NULL]
    }
  }

  # Task rows can reintroduce the chronology-only value after the prediction
  # merge above. Apply the flotation gate after all hatch-value sources so
  # every PDF table uses the same fieldworker-facing rule.
  if (length(no_float_complete_summary_nests)) {
    summary[
      Nest %chin% no_float_complete_summary_nests,
      `Est. Hatch` := ""
    ]
  }

  # BROODS_LATEST supplies the operational nest/brood rows, but its parent
  # marks can be stale or derived by a different identity path. Replace them
  # with the same authoritative four-gate status used by task rows, including
  # nests that have no task today and therefore never appear in TODO_LIST.
  if (
    !is.null(parent_status)
      && nrow(parent_status)
      && all(c(
        "nest_id", "M_parent_mark", "F_parent_mark"
      ) %in% names(parent_status))
  ) {
    status <- data.table(parent_status)
    status[, Nest := trimws(as.character(nest_id))]
    status <- status[
      !is.na(Nest) & nzchar(Nest),
      .(
        Nest,
        M_status_mark = as.character(M_parent_mark),
        F_status_mark = as.character(F_parent_mark)
      )
    ]
    status <- status[!duplicated(Nest)]
    if (nrow(status)) {
      summary <- merge(summary, status, by = "Nest", all.x = TRUE, sort = FALSE)
      has_status <- !is.na(summary$M_status_mark) |
        !is.na(summary$F_status_mark)
      summary[has_status, `:=`(
        Male = fifelse(
          is.na(M_status_mark) | !nzchar(trimws(M_status_mark)),
          "",
          M_status_mark
        ),
        Female = fifelse(
          is.na(F_status_mark) | !nzchar(trimws(F_status_mark)),
          "",
          F_status_mark
        )
      )]
      summary[, c("M_status_mark", "F_status_mark") := NULL]
    }
  }

  summary[, c("Male", "Female") := lapply(.SD, function(x) {
    x[is.na(x)] <- ""
    x[toupper(trimws(x)) == "NULL"] <- ""
    gsub("[\r\n]+", " ", x)
  }), .SDcols = c("Male", "Female")]

  check_todos <- c(
    "Clutch check",
    "Unprocessed nest",
    "Re-process nest",
    "take scrape photos",
    "nest check"
  )
  if (nrow(todo_dt) && all(c("nest_id", "todo") %in% names(todo_dt))) {
    parent_marks <- todo_pdf_parent_task_marks(todo_dt)
    if (nrow(parent_marks)) {
      summary <- merge(summary, parent_marks, by = "Nest", all.x = TRUE, sort = FALSE)
      if ("M_todo_mark" %in% names(summary)) {
        summary[!is.na(M_todo_mark), Male := M_todo_mark]
        summary[, M_todo_mark := NULL]
      }
      if ("F_todo_mark" %in% names(summary)) {
        summary[!is.na(F_todo_mark), Female := F_todo_mark]
        summary[, F_todo_mark := NULL]
      }
    }

    task_symbols <- todo_dt[,
      .(
        Symbol = if (any(todo == "notA nest-check")) {
          "notA"
        } else if (any(todo %chin% check_todos)) {
          "triangle"
        } else {
          "circle"
        },
        SymbolColor = fcase(
          any(todo == "notA nest-check"), "#7b858b",
          any(todo == "Parent capture"), "#d32f2f",
          any(todo == "Parent resighting"), "#1976d2",
          default = "#7b858b"
        )
      ),
      by = nest_id
    ]
    summary <- merge(
      summary,
      task_symbols,
      by.x = "Nest",
      by.y = "nest_id",
      all.x = TRUE,
      sort = FALSE
    )
  } else {
    summary[, let(Symbol = "circle", SymbolColor = "#7b858b")]
  }

  chick_bands <- .todo_pdf_map_prepare_chick_bands(
    chick_captures,
    reference_date
  )
  if (nrow(chick_bands)) {
    chick_bands <- chick_bands[, .(
      Nest = nest_id,
      LabelFill = label_fill,
      LabelText = label_text
    )]
    summary <- merge(summary, chick_bands, by = "Nest", all.x = TRUE, sort = FALSE)
  } else {
    summary[, let(LabelFill = NA_character_, LabelText = NA_character_)]
  }

  summary[is.na(Symbol), let(Symbol = "circle")]
  summary[is.na(SymbolColor), let(SymbolColor = "#7b858b")]
  setcolorder(
    summary,
    c(
      "Nest", "Est. Hatch", "Male", "Female", "Symbol", "SymbolColor",
      "Flagged",
      "LabelFill", "LabelText"
    )
  )
  summary[order(Nest)]
}


todo_pdf_parent_resighting_rule_note <- function(
  notes,
  male_identity_counts = NULL,
  female_identity_counts = NULL,
  male_association_pending = NULL,
  female_association_pending = NULL
) {
  notes <- as.character(notes)
  male_identity_counts <- suppressWarnings(as.numeric(male_identity_counts))
  female_identity_counts <- suppressWarnings(as.numeric(female_identity_counts))
  male_association_pending <- suppressWarnings(
    as.numeric(male_association_pending)
  )
  female_association_pending <- suppressWarnings(
    as.numeric(female_association_pending)
  )
  if (!length(male_identity_counts)) {
    male_identity_counts <- rep(NA_real_, length(notes))
  }
  if (!length(female_identity_counts)) {
    female_identity_counts <- rep(NA_real_, length(notes))
  }
  if (!length(male_association_pending)) {
    male_association_pending <- rep(NA_real_, length(notes))
  }
  if (!length(female_association_pending)) {
    female_association_pending <- rep(NA_real_, length(notes))
  }
  male_identity_counts <- rep(male_identity_counts, length.out = length(notes))
  female_identity_counts <- rep(female_identity_counts, length.out = length(notes))
  male_association_pending <- rep(
    male_association_pending,
    length.out = length(notes)
  )
  female_association_pending <- rep(
    female_association_pending,
    length.out = length(notes)
  )

  unname(vapply(
    seq_along(notes),
    function(i) {
      note <- notes[[i]]
      note <- tolower(ifelse(is.na(note), "", note))
      has_7d <- grepl("7d", note, fixed = TRUE)
      has_36hr <- grepl("36hr", note, fixed = TRUE)
      rule_note <- if (has_7d && has_36hr) {
        "7d+36hr"
      } else if (has_7d) {
        "7d rule"
      } else if (has_36hr) {
        "36hr rule"
      } else {
        ""
      }

      if (grepl("not yet floated", note, fixed = TRUE)) {
        return(trimws(as.character(notes[[i]])))
      }

      seen_note <- character()
      male_count <- male_identity_counts[[i]]
      female_count <- female_identity_counts[[i]]
      if (!is.na(male_count) && male_count > 0) {
        seen_note <- c(
          seen_note,
          if (!is.na(male_association_pending[[i]])
              && male_association_pending[[i]] == 0) {
            "M resolved"
          } else {
            paste(
              as.integer(male_count),
              if (male_count == 1) "male seen" else "males seen"
            )
          }
        )
      }
      if (!is.na(female_count) && female_count > 0) {
        seen_note <- c(
          seen_note,
          if (!is.na(female_association_pending[[i]])
              && female_association_pending[[i]] == 0) {
            "F resolved"
          } else {
            paste(
              as.integer(female_count),
              if (female_count == 1) "female seen" else "females seen"
            )
          }
        )
      }

      rendered_note <- paste(
        c(seen_note, rule_note[nzchar(rule_note)]),
        collapse = "; "
      )
      if (!nzchar(rendered_note) && grepl(
        "not yet floated|identity unknown",
        note,
        perl = TRUE
      )) {
        rendered_note <- trimws(as.character(notes[[i]]))
      }
      rendered_note
    },
    character(1)
  ))
}

todo_pdf_collapse_annotated_marks <- function(values) {
  values <- as.character(values)
  unname(vapply(
    values,
    function(value) {
      if (is.na(value) || !nzchar(trimws(value))) {
        return("")
      }
      marks <- trimws(unlist(strsplit(value, "&", fixed = TRUE)))
      marks <- unique(marks[nzchar(marks)])
      if (!length(marks)) {
        return("")
      }

      has_count <- grepl(
        "\\s+\\((?:MM\\s*,\\s*)?[0-9]+\\)$",
        marks,
        perl = TRUE
      )
      base_mark <- sub(
        "\\s+\\((?:MM\\s*,\\s*)?[0-9]+\\)$",
        "",
        marks,
        perl = TRUE
      )
      keep <- !(!has_count & vapply(
        seq_along(marks),
        function(i) any(has_count & base_mark == base_mark[[i]]),
        logical(1)
      ))
      paste(marks[keep], collapse = " & ")
    },
    character(1)
  ))
}


todo_pdf_prepare <- function(
  todo = NULL,
  available_combos = NULL,
  nests_latest = NULL,
  chick_captures = NULL,
  hatch_prediction = NULL,
  parent_status = NULL,
  chick_encounters = NULL,
  chick_context = NULL
) {
  if (is.null(todo)) {
    todo <- todo_pdf_query_tasks()
  }

  todo_dt <- data.table(todo)
  refdate <- as.Date(todo_dt$reference_date[1])

  if ("priority" %in% names(todo_dt)) {
    todo_dt[, let(priority = todo_pdf_as_numeric(priority))]
  } else {
    todo_dt[, let(priority = NA_real_)]
  }

  if ("days_overdue" %in% names(todo_dt)) {
    todo_dt[, let(days_overdue = todo_pdf_as_numeric(days_overdue))]
  } else {
    todo_dt[, let(days_overdue = NA_real_)]
  }

  if ("min_days_to_hatch" %in% names(todo_dt)) {
    todo_dt[, let(min_days_to_hatch = todo_pdf_as_numeric(min_days_to_hatch))]
  } else {
    todo_dt[, let(min_days_to_hatch = NA_real_)]
  }

  if ("last_visit_days_ago" %in% names(todo_dt)) {
    todo_dt[, let(last_visit_days_ago = todo_pdf_as_numeric(last_visit_days_ago))]
  } else {
    todo_dt[, let(last_visit_days_ago = NA_real_)]
  }

  if ("geo_priority_rank" %in% names(todo_dt)) {
    todo_dt[, let(geo_priority_rank = todo_pdf_as_numeric(geo_priority_rank))]
  } else {
    todo_dt[, let(geo_priority_rank = NA_real_)]
  }

  # All ordinary PDF task rows use the canonical parent-status identity. The
  # parent-resighting row may retain its richer pending-association display
  # (for example, an identity followed by a resighting count), but that detail
  # is generated from the same SQL status pipeline and is not used to override
  # the summary identity.
  for (column in c("authoritative_M_mark", "authoritative_F_mark")) {
    if (!column %in% names(todo_dt)) {
      todo_dt[, (column) := NA_character_]
    }
  }
  if (all(c("M_mark", "F_mark") %in% names(todo_dt))) {
    ordinary_task <- todo_dt$todo != "Parent resighting"
    has_authoritative_M <- !is.na(todo_dt$authoritative_M_mark) &
      nzchar(trimws(as.character(todo_dt$authoritative_M_mark)))
    has_authoritative_F <- !is.na(todo_dt$authoritative_F_mark) &
      nzchar(trimws(as.character(todo_dt$authoritative_F_mark)))
    todo_dt[ordinary_task & has_authoritative_M, M_mark := authoritative_M_mark]
    todo_dt[ordinary_task & has_authoritative_F, F_mark := authoritative_F_mark]
  }

  parent_todos <- c("Parent capture", "Parent resighting")
  nest_check_hatch_text <- trimws(sub(
    ";.*$",
    "",
    sub(
      "^.*Last visit:[[:space:]]*",
      "",
      as.character(todo_dt$notes)
    )
  ))
  todo_dt[, let(
    pdf_geo_sort_group = fcase(
      todo == "Parent capture", 0,
      default = 3
    ),
    pdf_hatching_sort_group = fcase(
      todo == "Parent capture" & toupper(trimws(as.character(nest_state))) == "H", 0,
      todo == "Parent capture"
        & !is.na(nest_id)
        & grepl("^-", trimws(as.character(nest_id))), 1,
      todo == "Parent capture", 2,
      default = 0
    ),
    pdf_geo_priority = fifelse(
      todo == "Parent capture",
      geo_priority_rank,
      NA_real_
    ),
    pdf_nest_check_unhatched = fifelse(
      todo == "nest check"
        & grepl(
          "unhatched egg(s)",
          as.character(notes),
          fixed = TRUE
        ),
      0,
      NA_real_
    ),
    pdf_nest_check_hatch_state = fifelse(
      todo == "nest check",
      fifelse(
        grepl("[CS]", toupper(nest_check_hatch_text)),
        0,
        1
      ),
      NA_real_
    ),
    pdf_nest_check_hatch = fifelse(
      todo == "nest check",
      min_days_to_hatch,
      NA_real_
    ),
    pdf_sort_primary = fifelse(
      todo %chin% parent_todos,
      min_days_to_hatch,
      -priority
    ),
    pdf_sort_secondary = fifelse(
      todo %chin% parent_todos,
      -last_visit_days_ago,
      -days_overdue
    )
  )]

  todo_dt <- todo_dt[
    order(
      todo,
      pdf_geo_sort_group,
      pdf_hatching_sort_group,
      pdf_nest_check_unhatched,
      pdf_nest_check_hatch_state,
      pdf_nest_check_hatch,
      pdf_sort_primary,
      pdf_sort_secondary,
      pdf_geo_priority,
      nest_id,
      na.last = TRUE
    )
  ]

  # A single operational instruction should occupy one PDF row even when
  # diagnostic joins have repeated the same nest/task/note combination.
  dedup_columns <- c("nest_id", "reference_date", "todo", "notes")
  if (all(dedup_columns %in% names(todo_dt))) {
    todo_dt <- todo_dt[
      !duplicated(todo_dt[, ..dedup_columns])
    ]
  }

  # Negative IDs represent mobile broods without a nest history. Display
  # their state/clutch as NA and use age-C captures to report brood size.
  todo_dt[, let(
    pdf_state = as.character(nest_state),
    pdf_clutch_size = as.character(clutch_size),
    pdf_brood_size = as.character(brood_size)
  )]
  is_negative_brood <- grepl("^-", trimws(as.character(todo_dt$nest_id)))
  todo_dt[is_negative_brood, let(
    pdf_state = "NA",
    pdf_clutch_size = "?",
    pdf_brood_size = "?"
  )]

  # H with no clutch is operationally a mobile brood, while negative IDs are
  # broods by definition. A positive terminal record with no clutch and a
  # recorded brood is also displayed as a brood rather than as notA.
  is_h_zero_clutch <- (
    !is_negative_brood
      & toupper(trimws(as.character(todo_dt$nest_state))) == "H"
      & todo_pdf_as_numeric(todo_dt$clutch_size) == 0
  )
  is_zero_clutch_with_brood <- (
    !is_negative_brood
      & todo_pdf_as_numeric(todo_dt$clutch_size) == 0
      & todo_pdf_as_numeric(todo_dt$brood_size) > 0
  )
  todo_dt[
    is_negative_brood | is_h_zero_clutch | is_zero_clutch_with_brood,
    pdf_state := "brood"
  ]

  # Avoid displaying database sentinel values for unknown negative-brood
  # clutch/brood values.
  negative_clutch <- trimws(as.character(todo_dt$pdf_clutch_size))
  negative_brood <- trimws(as.character(todo_dt$pdf_brood_size))
  todo_dt[
    is_negative_brood & (
      is.na(negative_clutch)
        | !nzchar(negative_clutch)
        | toupper(negative_clutch) %chin% c("NA", "NULL")
    ),
    pdf_clutch_size := "?"
  ]
  todo_dt[
    is_negative_brood & (
      is.na(negative_brood)
        | !nzchar(negative_brood)
        | toupper(negative_brood) %chin% c("NA", "NULL")
    ),
    pdf_brood_size := "?"
  ]

  # A hatch-record or terminal notA row without an entered brood size remains
  # uncertain until valid age-C capture rings provide an observed brood count.
  brood_size_text <- trimws(as.character(todo_dt$pdf_brood_size))
  h_brood_needs_observed_count <- !is_negative_brood &
    (
      toupper(trimws(as.character(todo_dt$nest_state))) == "H" |
        (
          toupper(trimws(as.character(todo_dt$nest_state))) == "NOTA" &
            todo_pdf_as_numeric(todo_dt$clutch_size) == 0
        )
    ) & (
      is.na(brood_size_text)
        | !nzchar(brood_size_text)
        | toupper(brood_size_text) %chin% c("0", "NA", "NULL", "?")
    )
  unknown_h_brood <- h_brood_needs_observed_count & (
    is.na(brood_size_text)
      | !nzchar(brood_size_text)
      | toupper(brood_size_text) %chin% c("NA", "NULL", "?")
  )
  todo_dt[unknown_h_brood, pdf_brood_size := "?"]

  if (!is.null(chick_captures)) {
    chick_dt <- data.table(chick_captures)
    if (all(c("nest_id", "age") %in% names(chick_dt))) {
      chick_dt <- chick_dt[
        toupper(trimws(as.character(age))) == "C"
          & !is.na(nest_id)
      ]
      if ("site" %in% names(chick_dt)) {
        chick_dt <- chick_dt[
          toupper(trimws(as.character(site))) == "CR"
        ]
      }
      if ("date" %in% names(chick_dt) && !is.na(refdate)) {
        capture_dates <- suppressWarnings(
          as.Date(as.character(chick_dt$date))
        )
        chick_dt <- chick_dt[
          !is.na(capture_dates) & capture_dates <= refdate
        ]
      }
      if ("ring" %in% names(chick_dt)) {
        chick_dt[, ring_key := toupper(trimws(as.character(ring)))]
        chick_dt[
          is.na(ring_key)
            | !nzchar(ring_key)
            | ring_key %chin% c("NA", "NULL"),
          ring_key := NA_character_
        ]
        chick_dt <- chick_dt[!is.na(ring_key)]
        chick_counts <- chick_dt[, .(N = uniqueN(ring_key)), by = nest_id]
      } else {
        # Keep older local preview callers working when they provide only
        # the historical nest_id/age columns.
        chick_counts <- chick_dt[, .(N = .N), by = nest_id]
      }
      chick_count_brood_candidate <- is_negative_brood |
        h_brood_needs_observed_count |
        (
          !is_negative_brood
            & toupper(trimws(as.character(todo_dt$nest_state))) %chin% c("H", "NOTA")
            & todo_pdf_as_numeric(todo_dt$clutch_size) == 0
        )
      for (i in seq_len(nrow(chick_counts))) {
        todo_dt[
          nest_id == chick_counts$nest_id[i]
            & chick_count_brood_candidate
            & (
              is_negative_brood
                | is.na(todo_pdf_as_numeric(pdf_brood_size))
                | todo_pdf_as_numeric(pdf_brood_size) < chick_counts$N[i]
            ),
          pdf_brood_size := as.character(chick_counts$N[i])
        ]
      }
    }
  }

  # Brood-work tables should describe the latest linked chick encounter, not
  # the original hatch/brood estimate.  This can reduce a three-chick brood
  # to one when the latest adult-linked encounter records only one chick.
  # Keep this PDF-only: SQL task eligibility and biological source fields stay
  # unchanged for other application consumers.
  latest_chick_counts <- todo_pdf_latest_chick_encounter_counts(
    chick_encounters,
    refdate
  )
  captured_ring_lists <- todo_pdf_captured_chick_ring_lists(chick_captures)
  if (nrow(latest_chick_counts)) {
    for (i in seq_len(nrow(latest_chick_counts))) {
      brood_id <- latest_chick_counts$nest_id[[i]]
      latest_count <- latest_chick_counts$latest_chick_count[[i]]
      if (is.na(latest_count)) {
        next
      }
      todo_dt[
        nest_id == brood_id,
        pdf_brood_size := as.character(latest_count)
      ]
      todo_dt[
        todo == "Broods to recapture for flagging"
          & nest_id == brood_id,
        notes := {
          ring_list <- captured_ring_lists[
            nest_id == brood_id,
            captured_chick_ring_list
          ]
          if (length(ring_list) && nzchar(ring_list[[1L]])) {
            paste0(latest_count, " seen from: ", ring_list[[1L]])
          } else {
            paste0(latest_count, " seen; no metal-ring IDs available")
          }
        }
      ]
    }
  }

  # Re-evaluate the display state after age-C captures have filled an
  # otherwise missing/zero brood size for a terminal hatched nest.
  final_zero_clutch_with_brood <- (
    !is_negative_brood
      & todo_pdf_as_numeric(todo_dt$pdf_clutch_size) == 0
      & todo_pdf_as_numeric(todo_dt$pdf_brood_size) > 0
  )
  todo_dt[final_zero_clutch_with_brood, pdf_state := "brood"]

  # These are PDF-only wording changes; the SQL task notes remain stable for
  # other consumers of TODO_LIST.
  todo_dt[
    todo == "notA nest-check",
    notes := gsub("do notA", "enter 'notA'", as.character(notes), fixed = TRUE)
  ]
  parent_capture_notes <- as.character(todo_dt$notes)
  parent_capture_notes[todo_dt$todo == "Parent capture"] <- gsub(
    "resight/band ([MF])(?! \\(status \\?\\))",
    "resight/band \\1 (status ?)",
    parent_capture_notes[todo_dt$todo == "Parent capture"],
    perl = TRUE
  )
  parent_resighting_idx <- todo_dt$todo == "Parent resighting"
  parent_capture_notes[parent_resighting_idx] <-
    todo_pdf_parent_resighting_rule_note(
      parent_capture_notes[parent_resighting_idx],
      todo_dt$M_resighting_identity_count[parent_resighting_idx],
      todo_dt$F_resighting_identity_count[parent_resighting_idx],
      todo_dt$M_resight_association_pending[parent_resighting_idx],
      todo_dt$F_resight_association_pending[parent_resighting_idx]
    )
  todo_dt[, notes := parent_capture_notes]

  # A processing task that still requires flotation should not display a
  # hatch interval. The hatch prediction remains available upstream for
  # other consumers; this is only the fieldworker-facing PDF value.
  processing_without_float <- todo_dt$todo %chin% c(
    "Unprocessed nest",
    "Re-process nest"
  ) &
    !is.na(todo_dt$notes) &
    grepl("float", tolower(as.character(todo_dt$notes)), fixed = TRUE)
  hatch_display <- todo_dt$min_days_to_hatch
  hatch_display[processing_without_float] <- NA_real_

  # Keep chronology predictions out of every task-table hatch column when the
  # nest still needs its first flotation record. Broods and explicit
  # flotation-exempt prediction types retain their existing values.
  prediction_status <- todo_pdf_hatch_prediction_status(hatch_prediction)
  no_float_complete_nests <- prediction_status[
    no_float_complete == TRUE,
    nest_id
  ]
  if (length(no_float_complete_nests)) {
    task_nest_ids <- trimws(as.character(todo_dt$nest_id))
    task_has_hatch_evidence <- toupper(trimws(as.character(
      todo_dt$nest_state
    ))) == "H" | todo_pdf_as_numeric(todo_dt$brood_size) > 0
    hatch_display[
      !is_negative_brood &
        !task_has_hatch_evidence &
        task_nest_ids %chin% no_float_complete_nests
    ] <- NA_real_
  }

  todo_dt[, let(clutch_brood = fifelse(
    is.na(pdf_clutch_size) & is.na(pdf_brood_size),
    "",
    paste0(
      fifelse(is.na(pdf_clutch_size), "", pdf_clutch_size),
      "–",
      fifelse(is.na(pdf_brood_size), "", pdf_brood_size)
    )
  ))]

  rows <- todo_dt[,
    .(
      Todo = todo,
      Nest = nest_id,
      State = pdf_state,
      `Clutch–Brood` = clutch_brood,
      Hatch = hatch_display,
      `Last Visit` = last_visit_days_ago,
      Male = M_mark,
      Female = F_mark,
      Notes = notes
    )
  ]

  rows <- rows[, lapply(.SD, function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    x <- gsub("[\r\n]+", " ", x)
    x
  })]
  rows[, c("Male", "Female") := lapply(.SD, function(x) {
    x[toupper(trimws(x)) == "NULL"] <- ""
    x
  }), .SDcols = c("Male", "Female")]
  for (column in c("Male", "Female")) {
    rows[Todo == "Parent resighting", (column) := todo_pdf_collapse_annotated_marks(
      get(column)
    )]
  }

  list(
    title = glue("Cass To-Dos for {refdate}"),
    rows = rows,
    team_marks = todo_pdf_prepare_team_marks(available_combos),
    nest_summary = todo_pdf_prepare_nest_summary(
      nests_latest,
      refdate,
      todo_dt,
      chick_captures,
      hatch_prediction,
      parent_status,
      chick_context
    )
  )
}

todo_pdf_heading <- function(todo_name) {
  switch(
    todo_name,
    "Hiding spot photos needed" = list(
      title = "Broods to photograph",
      subtitle = paste(
        "Find each brood; take in-situ and tent photos before chicks are 7 days old.",
        "Notes show H-photo rings / captured chick-ring identities."
      )
    ),
    "Broods to recapture for flagging" = list(
      title = "Broods to recapture for flagging",
      subtitle = paste(
        "Recapture chicks aged 21 days or more; assign unique engraved UL flags.",
        "The 3-week cutoff is a guide: decide in hand using morphometrics.",
        "Notes list metal rings of banded chicks; 'N seen' is the number encountered at the latest visit."
      ),
      subtitle_typst = paste(
        "Recapture chicks aged 21 days or more; assign unique engraved UL flags.",
        "The 3-week cutoff is a guide: decide in hand using morphometrics.",
        "Notes list metal rings of banded chicks; 'N seen' is the number encountered at the latest visit.",
        "#strong[Do not flag chicks if weight < 22 g or tarsus < 27 mm.]"
      ),
      subtitle_markdown = paste(
        "Recapture chicks aged 21 days or more; assign unique engraved UL flags.",
        "The 3-week cutoff is a guide: decide in hand using morphometrics.",
        "Notes list metal rings of banded chicks; 'N seen' is the number encountered at the latest visit.",
        "**Do not flag chicks if weight < 22 g or tarsus < 27 mm.**"
      )
    ),
    "Unprocessed nest" = list(
      title = "Nests to process",
      subtitle = "Complete required egg, nest/tent, or scrape photos; float where needed."
    ),
    "Re-process nest" = list(
      title = "Nests to process",
      subtitle = "Complete required egg, nest/tent, or scrape photos; float where needed."
    ),
    "Parent capture" = list(
      title = "Parents to capture",
      subtitle = "Follow the row notes: deploy a GEO only when the nest is eligible; otherwise band or resight as instructed."
    ),
    "Parent resighting" = list(
      title = "Parents to resight for nest association",
      subtitle = "Association resolves after 3 nest-linked resightings or 1 confirming behaviour (IN, NM, BW, BC, FC, AC). MM, n = MM capture plus n non-confirming resightings."
    ),
    "Untrapped brood" = list(
      title = "Broods to band",
      subtitle = "Band chicks at hatched nests/broods with no chick captures."
    ),
    "nest check" = list(
      title = "Nests to check for potential hatch",
      subtitle = "Revisit to check hatch status and update the nest record."
    ),
    "take scrape photos" = list(
      title = "Take scrape photos",
      subtitle = NULL
    ),
    "Clutch check" = list(
      title = "Nests to check for additional eggs",
      subtitle = "Revisit to check for additional eggs."
    ),
    "notA nest-check" = list(
      title = "Nests requiring a 'notA' closure visit",
      subtitle = "Confirm closure and enter notA; H-state nests may still be active mobile broods."
    ),
    stop(
      glue("Unexpected TODO task value in PDF renderer: {todo_name}"),
      call. = FALSE
    )
  )
}

todo_pdf_reprocess_note <- function(note) {
  note <- trimws(as.character(note))
  if (is.na(note) || !nzchar(note)) {
    return("re-process")
  }

  switch(
    note,
    "float + photos" = "float + nest/tent photos; re-process",
    "photos only" = "nest/tent photos only; re-process",
    paste0(note, "; re-process")
  )
}

todo_pdf_table_task_order <- c(
  "Untrapped brood",
  "Hiding spot photos needed",
  "Broods to recapture for flagging",
  "nest check",
  "Clutch check",
  "Unprocessed nest",
  "Parent capture",
  "Parent resighting",
  "notA nest-check"
)

todo_pdf_note_key <- function(notes = character()) {
  definitions <- list(
    list(
      label = "Last visit",
      always = TRUE,
      text = "Days since the latest qualifying nest or brood encounter, including a nest visit, chick capture, chick resighting, or resolved GPS-linked observation."
    ),
    list(
      label = "Est. Hatch",
      always = TRUE,
      text = "For active nests, days until estimated hatch (negative = overdue); for broods, negative values are days since hatch."
    ),
    list(
      label = "7d rule",
      pattern = "7d rule",
      text = "Resighting only. Capture is not allowed until at least 7 days after estimated clutch completion."
    ),
    list(
      label = "36hr rule",
      pattern = "36hr rule",
      text = "Resighting only. Another parent cannot be captured until 08:00 on the reference day is at least 36 hours after the previous parent capture at that nest."
    ),
    list(
      label = "MM cap",
      pattern = "MM cap",
      text = "Captured with mobile mist net. Three subsequent nest-linked resightings with matching sex and identity confirms association OR a single nest-linked resighting with behav 'IN', 'NM', 'BW', 'BC', 'FC', or 'AC'."
    ),
    list(
      label = "Pair completion",
      pattern = "pair completion",
      text = "After an eligible first deployment, tag the authoritative untagged mate so that both pair members are tagged."
    ),
    list(
      label = "Tag deployment",
      pattern = "tag any",
      text = "Deploy only on Plot B/C nests completed after 9 October; initial deployment requires a confirmed authoritative X-X parent. A guarded unknown-status note requires confirmation before tagging."
    ),
    list(
      label = "FO marker",
      pattern = "FO marker",
      text = "Orange-flagged AU migrant; never deploy a GEO."
    ),
    list(
      label = "Band only",
      # Avoid treating the generic brood-band task note ("band") as a
      # parent-specific band-only instruction.
      pattern = "band ",
      text = "Capture and fully colour-band the stated parent; do not deploy a GEO."
    ),
    list(
      label = "M/F w/GEO",
      pattern = "w/GEO",
      text = "The confirmed male/female carries a geolocator."
    ),
    list(
      label = "Status ?",
      pattern = "status ?",
      text = "Identity or X-X status is unknown."
    )
  )

  notes <- as.character(notes)
  notes <- notes[!is.na(notes)]
  used <- vapply(
    definitions,
    function(definition) {
      if (isTRUE(definition$always)) {
        return(TRUE)
      }
      any(grepl(
        tolower(definition$pattern),
        tolower(notes),
        fixed = TRUE
      ))
    },
    logical(1)
  )
  definitions <- definitions[used]
  if (!length(definitions)) {
    return(character())
  }

  cells <- vapply(
    definitions,
    function(definition) {
      glue(
        "[*{definition$label}:* {definition$text}]"
      )
    },
    character(1)
  )

  c(
    "```{=typst}",
    "#v(-0.4em)",
    "#block(",
    "  width: 100%,",
    "  fill: rgb(\"#f4f7f7\"),",
    "  stroke: 0.45pt + rgb(\"#71858a\"),",
    "  radius: 2pt,",
    "  inset: (x: 6pt, y: 3pt),",
    ")[",
    "  #set text(size: 7.4pt)",
    "  #set par(leading: 0.32em)",
    "  *Note key* \\",
    "  #grid(",
    "    columns: (1fr, 1fr),",
    "    gutter: 9pt,",
    paste0("    ", paste(cells, collapse = ",\n    "), ","),
    "  )",
    "]",
    "#v(0.2em)",
    "```",
    ""
  )
}

todo_pdf_nest_summary_table <- function(
  nest_summary,
  n_blocks = 3L,
  raw = FALSE
) {
  summary <- data.table(nest_summary)
  if (!nrow(summary)) {
    return(character())
  }

  n_blocks <- min(as.integer(n_blocks), nrow(summary))
  block_sizes <- rep(nrow(summary) %/% n_blocks, n_blocks)
  remainder <- nrow(summary) %% n_blocks
  if (remainder) {
    block_sizes[seq_len(remainder)] <- block_sizes[seq_len(remainder)] + 1L
  }
  block_ends <- cumsum(block_sizes)
  block_starts <- c(1L, head(block_ends, -1L) + 1L)
  blocks <- Map(
    function(first, last) summary[first:last],
    block_starts,
    block_ends
  )
  rows_per_block <- max(block_sizes)

  max_font_size <- 8.5
  label_inset_y <- 2
  max_inset_y <- 4.5
  target_table_height <- 330
  if (rows_per_block <= 12L) {
    font_size <- max_font_size
    inset_y <- max_inset_y
  } else {
    font_size <- min(
      max_font_size * sqrt(12 / rows_per_block),
      target_table_height * 0.75 / (rows_per_block + 2)
    )
    inset_y <- max(
      0,
      (
        target_table_height - (rows_per_block + 2) * font_size
      ) / (2 * (rows_per_block + 1)) - label_inset_y
    )
  }
  font_size <- format(round(font_size, 2), trim = TRUE)
  inset_y <- format(round(inset_y, 2), trim = TRUE)

  typst_content <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    x <- gsub("\\", "\\\\", x, fixed = TRUE)
    x <- gsub("#", "\\#", x, fixed = TRUE)
    x <- gsub("[", "\\[", x, fixed = TRUE)
    x <- gsub("]", "\\]", x, fixed = TRUE)
    x <- gsub("*", "\\*", x, fixed = TRUE)
    x <- gsub("_", "\\_", x, fixed = TRUE)
    x <- gsub("$", "\\$", x, fixed = TRUE)
    x
  }

  typst_table <- function(block) {
    header_fill <- '#dfe5e7'
    stripe_fill <- '#f1f3f3'
    white_fill <- '#ffffff'
    cells <- c(
      glue('table.cell(fill: rgb("{header_fill}"))[#strong[Nest/Brood]]'),
      glue('table.cell(fill: rgb("{header_fill}"))[#strong[Est.#linebreak()Hatch]]'),
      glue('table.cell(fill: rgb("{header_fill}"))[#strong[Male]]'),
      glue('table.cell(fill: rgb("{header_fill}"))[#strong[Female]]')
    )

    for (row in seq_len(nrow(block))) {
      row_fill <- if (row %% 2L == 0L) stripe_fill else white_fill
      glyph <- switch(
        block$Symbol[row],
        notA = "▼",
        triangle = "▲",
        "●"
      )
      symbol_size <- format(
        round(as.numeric(font_size) * 2, 2),
        trim = TRUE
      )
      has_chick_label <- !is.na(block$LabelFill[row]) &&
        nzchar(block$LabelFill[row])
      flagged_marker <- if (
        "Flagged" %in% names(block) && isTRUE(block$Flagged[row])
      ) {
        "  #h(2pt)  #strong[F]"
      } else {
        ""
      }
      nest_cell <- if (nzchar(block$Nest[row])) {
        if (has_chick_label) {
          glue(
            '#box[',
            '  #text(size: {symbol_size}pt, fill: rgb("{block$SymbolColor[row]}"))[{glyph}]',
            '  #h(1pt)',
            '  #box(',
            '    fill: rgb("{block$LabelFill[row]}"),',
            '    stroke: 0.25pt + rgb("#17242d"),',
            '    radius: 1.8pt,',
            glue('    inset: (x: 3pt, y: {label_inset_y}pt),'),
            '  )[#text(fill: rgb("{block$LabelText[row]}"))',
            '[#strong[{typst_content(block$Nest[row])}]]]',
            flagged_marker,
            ']'
          )
        } else {
          glue(
            '#box[',
            '  #text(size: {symbol_size}pt, fill: rgb("{block$SymbolColor[row]}"))[{glyph}]',
            '  #h(1pt)',
            '  #strong[{typst_content(block$Nest[row])}]',
            flagged_marker,
            ']'
          )
        }
      } else {
        typst_content("")
      }

      cells <- c(
        cells,
        glue(
          'table.cell(fill: rgb("{row_fill}"))',
          '[{nest_cell}]'
        ),
        glue(
          'table.cell(fill: rgb("{row_fill}"))',
          '[{typst_content(block[["Est. Hatch"]][row])}]'
        ),
        glue(
          'table.cell(fill: rgb("{row_fill}"))',
          '[{typst_content(block$Male[row])}]'
        ),
        glue(
          'table.cell(fill: rgb("{row_fill}"))',
          '[{typst_content(block$Female[row])}]'
        )
      )
    }

    c(
      "[",
      "#table(",
      "  columns: (1.1fr, 0.8fr, 1.125fr, 1.125fr),",
      "  align: center + horizon,",
      glue("  inset: (x: 2.2pt, y: {inset_y}pt),"),
      '  stroke: 0.25pt + rgb("#aeb8ba"),',
      paste0("  ", paste(cells, collapse = ",\n  "), ","),
      ")",
      "]"
    )
  }

  tables <- lapply(blocks, typst_table)

  table_body <- c(
    "```{=typst}",
    "#v(-0.7em)",
    glue("#set text(size: {font_size}pt)"),
    "#grid(",
    glue("  columns: ({paste(rep('1fr', n_blocks), collapse = ', ')}),"),
    "  gutter: 9pt,",
    paste0(vapply(tables, paste, "", collapse = "\n"), collapse = ",\n"),
    ")",
    "#set text(size: 9pt)",
    "```",
    ""
  )

  if (isTRUE(raw)) {
    return(table_body[2:(length(table_body) - 2L)])
  }

  table_body
}


todo_pdf_summary_block <- function(
  nest_summary,
  keep_tables_together = FALSE
) {
  summary <- data.table(nest_summary)
  if (!nrow(summary)) {
    return(character())
  }

  title <- "#align(left)[#text(size: 10pt, weight: \"bold\")[Summary of currently active nests and broods]]"
  subtitle <- "#align(left)[#emph[#text(size: 8pt)[Brood labels use chick band colour; an F after a brood label means at least one chick has an engraved flag. Symbols match the map. For active nests, \"Est. Hatch\" is days until hatch (negative = overdue); for broods, negative values are days since hatch.]]]"

  if (isTRUE(keep_tables_together)) {
    return(c(
      "```{=typst}",
      "#block(breakable: false)[",
      title,
      "#v(-0.15em)",
      subtitle,
      todo_pdf_nest_summary_table(summary, raw = TRUE),
      "]",
      "```",
      ""
    ))
  }

  c(
    "```{=typst}",
    "#v(-0.35em)",
    title,
    "#v(-0.15em)",
    subtitle,
    "```",
    "",
    todo_pdf_nest_summary_table(summary)
  )
}


todo_pdf_task_table <- function(
  todo_rows,
  nest_summary = NULL,
  column_widths = NULL,
  align = NULL,
  raw = FALSE
) {
  todo_rows <- as.data.frame(todo_rows, stringsAsFactors = FALSE)
  if (!nrow(todo_rows) || !ncol(todo_rows)) {
    return(character())
  }

  typst_content <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    x <- gsub("\\", "\\\\", x, fixed = TRUE)
    x <- gsub("#", "\\#", x, fixed = TRUE)
    x <- gsub("[", "\\[", x, fixed = TRUE)
    x <- gsub("]", "\\]", x, fixed = TRUE)
    x <- gsub("*", "\\*", x, fixed = TRUE)
    x <- gsub("_", "\\_", x, fixed = TRUE)
    x <- gsub("$", "\\$", x, fixed = TRUE)
    x
  }

  labels <- data.table(
    Nest = character(),
    LabelFill = character(),
    LabelText = character()
  )
  if (!is.null(nest_summary) && nrow(nest_summary)) {
    summary <- data.table(nest_summary)
    if (all(c("Nest", "LabelFill", "LabelText") %in% names(summary))) {
      labels <- unique(summary[, .(
        Nest = as.character(Nest),
        LabelFill = as.character(LabelFill),
        LabelText = as.character(LabelText)
      )])
      labels <- labels[!duplicated(Nest)]
    }
  }

  header_fill <- "#dfe5e7"
  stripe_fill <- "#f1f3f3"
  white_fill <- "#ffffff"
  label_inset_y <- 3
  nest_column <- names(todo_rows)[1]

  label_cell <- function(nest_id, row_fill) {
    nest_id <- as.character(nest_id)
    if (is.na(nest_id)) {
      nest_id <- ""
    }
    label_row <- labels[Nest == nest_id][1L]
    has_label <- nrow(label_row) == 1L &&
      !is.na(label_row$LabelFill) &&
      grepl("^#[0-9A-Fa-f]{6}$", label_row$LabelFill) &&
      !is.na(label_row$LabelText) &&
      nzchar(label_row$LabelText)

    if (has_label) {
      glue(
        'table.cell(fill: rgb("{row_fill}"))[',
        '  #box(',
        '    fill: rgb("{label_row$LabelFill}"),',
        '    stroke: 0.25pt + rgb("#17242d"),',
        '    radius: 1.8pt,',
        glue('    inset: (x: 3pt, y: {label_inset_y}pt),'),
        '  )[',
        '    #text(fill: rgb("{label_row$LabelText}"))',
        glue('[#strong[{typst_content(nest_id)}]]'),
        '  ]',
        ']'
      )
    } else {
      glue(
        'table.cell(fill: rgb("{row_fill}"))',
        glue('[{typst_content(nest_id)}]')
      )
    }
  }

  cells <- vapply(
    names(todo_rows),
    function(column) {
      glue(
        'table.cell(fill: rgb("{header_fill}"))',
        glue('[#strong[{typst_content(column)}]]')
      )
    },
    character(1)
  )

  for (row in seq_len(nrow(todo_rows))) {
    row_fill <- if (row %% 2L == 0L) stripe_fill else white_fill
    row_cells <- vapply(
      names(todo_rows),
      function(column) {
        if (identical(column, nest_column)) {
          return(label_cell(todo_rows[[column]][row], row_fill))
        }
        glue(
          'table.cell(fill: rgb("{row_fill}"))',
          glue('[{typst_content(todo_rows[[column]][row])}]')
        )
      },
      character(1)
    )
    cells <- c(cells, row_cells)
  }

  if (is.null(column_widths)) {
    column_widths <- c(8, 6, 10, 9, 10, 14, 14, 29)
  }
  if (is.null(align)) {
    align <- c(
      "center", "center", "center", "center",
      "center", "center", "center", "left"
    )
  }
  columns <- paste0(column_widths, "fr", collapse = ", ")
  align_text <- paste(
    vapply(
      align,
      function(value) paste0(value, " + horizon"),
      character(1)
    ),
    collapse = ", "
  )

  table_body <- c(
    "#set text(size: 8.5pt)",
    "#table(",
    glue("  columns: ({columns}),"),
    glue("  align: ({align_text}),"),
    "  inset: (x: 2.2pt, y: 3pt),",
    "  stroke: none,",
    paste0("  ", paste(cells, collapse = ",\n  "), ","),
    ")",
    "#set text(size: 9pt)"
  )

  if (isTRUE(raw)) {
    return(table_body)
  }

  c("```{=typst}", table_body, "```", "")
}


todo_pdf_simple_table <- function(
  table_data,
  column_widths = NULL,
  raw = FALSE
) {
  table_data <- as.data.frame(table_data, stringsAsFactors = FALSE)
  if (!nrow(table_data) || !ncol(table_data)) {
    return(character())
  }

  typst_content <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    x <- gsub("\\", "\\\\", x, fixed = TRUE)
    x <- gsub("#", "\\#", x, fixed = TRUE)
    x <- gsub("[", "\\[", x, fixed = TRUE)
    x <- gsub("]", "\\]", x, fixed = TRUE)
    x <- gsub("*", "\\*", x, fixed = TRUE)
    x <- gsub("_", "\\_", x, fixed = TRUE)
    x <- gsub("$", "\\$", x, fixed = TRUE)
    x
  }

  header_fill <- "#dfe5e7"
  stripe_fill <- "#f1f3f3"
  white_fill <- "#ffffff"
  cells <- vapply(
    names(table_data),
    function(column) {
      glue(
        'table.cell(fill: rgb("{header_fill}"))',
        glue('[#strong[{typst_content(column)}]]')
      )
    },
    character(1)
  )

  for (row in seq_len(nrow(table_data))) {
    row_fill <- if (row %% 2L == 0L) stripe_fill else white_fill
    cells <- c(
      cells,
      vapply(
        table_data[row, , drop = FALSE],
        function(value) {
          glue(
            'table.cell(fill: rgb("{row_fill}"))',
            glue('[{typst_content(value)}]')
          )
        },
        character(1)
      )
    )
  }

  if (is.null(column_widths)) {
    column_widths <- rep(1, ncol(table_data))
  } else if (length(column_widths) != ncol(table_data)) {
    stop(
      "column_widths must contain one value per table column.",
      call. = FALSE
    )
  }
  columns <- paste0(column_widths, "fr", collapse = ", ")

  table_body <- c(
    "#set text(size: 8.5pt)",
    "#table(",
    glue("  columns: ({columns}),"),
    "  align: center + horizon,",
    "  inset: (x: 2.2pt, y: 3pt),",
    "  stroke: none,",
    paste0("  ", paste(cells, collapse = ",\n  "), ","),
    ")",
    "#set text(size: 9pt)"
  )

  if (isTRUE(raw)) {
    return(table_body)
  }

  c("```{=typst}", table_body, "```", "")
}


todo_pdf_body <- function(
  rows,
  team_marks = NULL,
  map_file = NULL,
  nest_summary = NULL,
  keep_tables_together = FALSE
) {
  # Re-process nest, take scrape photos, and Unprocessed nest are distinct SQL
  # evidence branches, but they share the Nests to process field action. Keep
  # this normalization local to the rendering copy so TODO_LIST remains the
  # stable source for other consumers.
  rows <- data.table::copy(rows)
  if ("Todo" %in% names(rows)) {
    task_values <- as.character(rows$Todo)
    reprocess <- !is.na(task_values) & task_values == "Re-process nest"
    scrape <- !is.na(task_values) & task_values == "take scrape photos"

    if ("Notes" %in% names(rows)) {
      if (any(reprocess)) {
        reprocess_notes <- vapply(
          rows$Notes[reprocess],
          todo_pdf_reprocess_note,
          character(1)
        )
        rows[reprocess, Notes := reprocess_notes]
      }
      if (any(scrape)) {
        rows[scrape, Notes := "scrape photos"]
      }
    }

    rows[reprocess | scrape, Todo := "Unprocessed nest"]
  }

  out <- todo_pdf_note_key(rows$Notes)
  if (!nrow(rows)) {
    out <- c(out, "No to-do items.", "")
  } else {
    table_cols <- setdiff(names(rows), "Todo")
    task_values <- unique(as.character(rows$Todo))
    unexpected <- setdiff(task_values, todo_pdf_table_task_order)
    if (length(unexpected)) {
      # Preserve the existing fail-fast behavior for stale or mixed task
      # values rather than silently dropping them from the PDF.
      todo_pdf_heading(unexpected[[1L]])
    }

    for (todo in todo_pdf_table_task_order) {
      if (!any(rows$Todo == todo, na.rm = TRUE)) {
        next
      }
      todo_rows <- as.data.frame(rows[Todo == todo, ..table_cols])
      heading <- todo_pdf_heading(todo)

      if (todo %in% c(
        "Untrapped brood",
        "Hiding spot photos needed",
        "Broods to recapture for flagging"
      )) {
        names(todo_rows)[names(todo_rows) == "Nest"] <- "Brood"
        if (todo == "Broods to recapture for flagging") {
          todo_rows[["Clutch–Brood"]] <- sub(
            "^.*–",
            "",
            as.character(todo_rows[["Clutch–Brood"]])
          )
          names(todo_rows)[names(todo_rows) == "Clutch–Brood"] <- "N chicks"
        }
      } else if (todo %in% c(
        "Parent capture",
        "Parent resighting",
        "Untrapped brood"
      )) {
        names(todo_rows)[names(todo_rows) == "Nest"] <- "Nest/Brood"
      }

      parent_resighting_table <- todo == "Parent resighting"

      if (!(todo %in% c(
        "notA nest-check",
        "Hiding spot photos needed",
        "Broods to recapture for flagging"
      ))) {
        names(todo_rows)[names(todo_rows) == "Hatch"] <- "Est. Hatch"
      }

      # Use one borderless, striped renderer for every operational task table.
      # This keeps label-aware and ordinary task tables visually consistent.
      task_table <- todo_pdf_task_table(
        todo_rows,
        nest_summary,
        column_widths = if (parent_resighting_table) {
          c(7, 5, 8, 8, 8, 21, 23, 20)
        },
        align = if (parent_resighting_table) {
          c(
            "center", "center", "center", "center", "center",
            "center", "center", "left"
          )
        },
        raw = isTRUE(keep_tables_together)
      )

      # Keep the heading, subtitle, and table as one visual unit when the
      # three-page task-table budget can accommodate it.
      if (isTRUE(keep_tables_together)) {
        out <- c(
          out,
          "```{=typst}",
          "#block(breakable: false)[",
          glue("#heading(level: 2)[{heading$title}]"),
          if (!is.null(heading$subtitle)) {
            glue(
              "#emph[{heading$subtitle_typst %||% heading$subtitle}]"
            )
          },
          task_table,
          "]",
          "```",
          ""
        )
      } else {
        out <- c(
          out,
          glue("## {heading$title}"),
          "",
          if (!is.null(heading$subtitle)) {
            c(
              glue(
                "*{heading$subtitle_markdown %||% heading$subtitle}*"
              ),
              ""
            )
          },
          task_table
        )
      }
    }
  }

  if (!is.null(team_marks) && nrow(team_marks)) {
    if (isTRUE(keep_tables_together)) {
      out <- c(
        out,
        "```{=typst}",
        "#v(0.9em)",
        "```",
        "```{=typst}",
        "#block(breakable: false)[",
        "#heading(level: 2)[Team marks]",
        "#emph[Use non-Lime 1.5x bands for the geolocator spacer on the tibia; use 2x bands on the tarsi.]",
        todo_pdf_simple_table(
          team_marks,
          column_widths = c(12, rep(8, ncol(team_marks) - 1L)),
          raw = TRUE
        ),
        "]",
        "```",
        "```{=typst}",
        "#v(0.9em)",
        "```",
        ""
      )
    } else {
      out <- c(
        out,
        "```{=typst}",
        "#v(0.9em)",
        "```",
        "## Team marks",
        "",
        "*Use non-Lime 1.5x bands for the geolocator spacer on the tibia; use 2x bands on the tarsi.*",
        "",
        todo_pdf_simple_table(
          team_marks,
          column_widths = c(12, rep(8, ncol(team_marks) - 1L))
        ),
        "```{=typst}",
        "#v(0.9em)",
        "```",
        ""
      )
    }
  }

  if (!is.null(map_file)) {
    out <- c(
      out,
      todo_pdf_summary_block(
        nest_summary,
        keep_tables_together = keep_tables_together
      ),
      "```{=typst}",
      "#set page(margin: (x: 1cm, y: 1cm))",
      "#pagebreak()",
      "#align(left)[#text(size: 10pt, weight: \"bold\")[Map of tasks needed on active nests and broods]]",
      "#align(left)[#emph[#text(size: 8.5pt)[All active nests and broods are shown. Black labels are nests; coloured labels are broods (chick band colour). Nest points are stationary; brood points show the latest location. White point outline = parent tag deployment; white label outline + italic text = brood photo, flagging, or banding work.]]]",
      "#v(-0.2em)",
      glue('#align(center)[#image("{map_file}", width: 100%)]'),
      "#v(-0.4em)",
      "```"
    )
  }

  out
}

todo_pdf_qmd <- function(
  pdf,
  map_file = NULL,
  template = file.path("templates", "todo_pdf.qmd"),
  keep_tables_together = FALSE
) {
  body <- todo_pdf_body(
    pdf$rows,
    pdf$team_marks,
    map_file,
    pdf$nest_summary,
    keep_tables_together = keep_tables_together
  )
  out <- character()

  for (line in readLines(template)) {
    out <- c(
      out,
      switch(
        line,
        "{{ header }}" = glue(
          '#set page(header: context [#align(center)[#text(size: 12pt, weight: "bold", fill: rgb("#5f6b70"))[{pdf$title}]]])'
        ),
        "{{ footer }}" = glue(
          paste0(
            '#set page(footer: context [#grid(columns: (1fr, 1fr), ',
            '[#align(left)[#text(size: 6pt, fill: rgb("#7b858b"))',
            '[#counter(page).display()]]], ',
            '[#align(right)[#text(size: 6pt, fill: rgb("#7b858b"))',
            '[', todo_pdf_version_footer(), ']]])])'
          )
        ),
        "{{ body }}" = body,
        line
      )
    )
  }

  out
}


todo_pdf_page_count_fallback <- function(file) {
  if (!file.exists(file)) {
    return(NA_integer_)
  }

  file_size <- file.info(file)$size
  if (is.na(file_size) || file_size <= 0 || file_size > 128 * 1024^2) {
    return(NA_integer_)
  }

  raw_pdf <- tryCatch(
    readBin(file, what = "raw", n = file_size),
    error = function(e) raw()
  )
  if (!length(raw_pdf)) {
    return(NA_integer_)
  }

  # PDF page-tree dictionaries are ASCII even when the rest of the file
  # contains compressed or binary streams. Strip non-ASCII bytes so base R
  # can inspect the dictionaries without requiring a PDF package.
  raw_values <- as.integer(raw_pdf)
  ascii_pdf <- raw_pdf[raw_values > 0L & raw_values < 128L]
  pdf_text <- rawToChar(ascii_pdf)
  page_nodes <- gregexpr(
    "/Type[[:space:]]*/Pages\\b",
    pdf_text,
    perl = TRUE,
    useBytes = TRUE
  )[[1L]]
  if (identical(page_nodes, -1L)) {
    return(NA_integer_)
  }

  counts <- vapply(
    page_nodes,
    function(position) {
      node <- substr(
        pdf_text,
        position,
        min(nchar(pdf_text, type = "bytes"), position + 4096L)
      )
      object_end <- regexpr(">>", node, fixed = TRUE, useBytes = TRUE)[[1L]]
      if (object_end > 0L) {
        node <- substr(node, 1L, object_end + 1L)
      }
      count_match <- regexec(
        "/Count[[:space:]]+([0-9]+)",
        node,
        perl = TRUE,
        useBytes = TRUE
      )
      count_parts <- regmatches(node, count_match)[[1L]]
      if (length(count_parts) < 2L) {
        return(NA_integer_)
      }
      suppressWarnings(as.integer(count_parts[[2L]]))
    },
    integer(1)
  )
  counts <- counts[!is.na(counts)]
  if (!length(counts)) {
    return(NA_integer_)
  }

  max(counts)
}


todo_pdf_page_count <- function(file) {
  pdfinfo <- Sys.which("pdfinfo")
  if (!nzchar(pdfinfo) || !file.exists(file)) {
    return(todo_pdf_page_count_fallback(file))
  }

  info <- tryCatch(
    suppressWarnings(system2(pdfinfo, file, stdout = TRUE, stderr = TRUE)),
    error = function(e) character()
  )
  page_line <- info[grepl("^Pages:", trimws(info))]
  if (!length(page_line)) {
    return(todo_pdf_page_count_fallback(file))
  }

  pages <- suppressWarnings(as.integer(sub("^Pages:\\s*", "", trimws(page_line[[1L]]))))
  if (is.na(pages)) {
    return(todo_pdf_page_count_fallback(file))
  }
  pages
}

todo_pdf_save <- function(
  file,
  todo = NULL,
  available_combos = NULL,
  spatial_objects = NULL,
  nests_latest = NULL,
  chick_captures = NULL,
  broods_latest = NULL,
  hatch_prediction = NULL,
  chick_encounters = NULL
) {
  if (is.null(todo)) {
    todo <- todo_pdf_query_tasks()
  }

  if (is.null(broods_latest)) {
    if (is.null(nests_latest)) {
      # TODO_BROODS_FOR_PDF applies the published presumed-dead brood status
      # to the map and summary source while leaving BROODS_LATEST unchanged
      # for other application consumers.
      broods_latest <- DBq(
        "SELECT * FROM TODO_BROODS_FOR_PDF",
        derived_merge_off = TRUE
      )
      if ("error" %in% names(broods_latest)) {
        stop(
          paste0(
            "TODO_BROODS_FOR_PDF could not be loaded for the to-do PDF: ",
            as.character(broods_latest$error[[1L]])
          ),
          call. = FALSE
        )
      }
    } else {
      # Keep the legacy argument working for older local preview scripts.
      broods_latest <- nests_latest
    }
  }

  workdir <- tempfile("todo_pdf_")
  dir.create(workdir)
  on.exit(unlink(workdir, recursive = TRUE), add = TRUE)

  qmd <- file.path(workdir, "todo.qmd")
  output <- file.path(workdir, "todo.pdf")
  keep_qmd <- file.path(workdir, "todo_keep_tables.qmd")
  keep_output <- file.path(workdir, "todo_keep_tables.pdf")
  map_file <- file.path(workdir, "todo_map.png")

  if (is.null(spatial_objects)) {
    spatial_objects <- DBq(
      "SELECT * FROM spatial_objects WHERE variable = 'study_area'"
    )
  }
  pdf_reference_date <- if (
    "reference_date" %in% names(todo) && nrow(todo)
  ) {
    as.Date(todo$reference_date[[1L]])
  } else {
    get_reference_date()
  }
  if (is.null(chick_captures) || is.null(chick_encounters)) {
    chick_event_context <- DBq(
      todo_pdf_chick_event_context_sql(pdf_reference_date),
      derived_merge_off = TRUE
    )
    if ("error" %in% names(chick_event_context)) {
      stop(
        paste0(
          "Could not load linked chick encounters for the to-do PDF: ",
          as.character(chick_event_context$error[[1L]])
        ),
        call. = FALSE
      )
    }
    chick_event_context <- data.table(chick_event_context)
    if (is.null(chick_captures)) {
      chick_captures <- chick_event_context[source == "capture"]
    }
    if (is.null(chick_encounters)) {
      chick_encounters <- chick_event_context[, .(
        nest_id,
        date,
        source,
        event_id,
        ring,
        site,
        gps_id,
        gps_point
      )]
    }
  }
  if (is.null(hatch_prediction)) {
    hatch_prediction <- DBq(
      "SELECT * FROM EGGS_HATCH_PREDICTION"
    )
  }
  parent_status <- DBq(
    "
    SELECT nest_id, M_parent_mark, F_parent_mark
    FROM TODO_PARENT_STATUS
    "
  )
  if ("error" %in% names(parent_status)) {
    parent_status <- NULL
  }
  chick_context <- DBq(
    "
    SELECT nest_id, n_flagged_chick_rings
    FROM TODO_CHICK_CAPTURE_CONTEXT_INPUT
    ",
    derived_merge_off = TRUE
  )
  if ("error" %in% names(chick_context)) {
    chick_context <- NULL
  }
  pdf <- todo_pdf_prepare(
    todo,
    available_combos,
    broods_latest,
    chick_captures,
    hatch_prediction,
    parent_status,
    chick_encounters,
    chick_context
  )

  todo_pdf_map_save(
    file = map_file,
    todo = todo,
    spatial_objects = spatial_objects,
    chick_captures = chick_captures,
    nests_latest = broods_latest
  )

  render_pdf <- function(qmd_file, output_file, keep_tables) {
    writeLines(
      todo_pdf_qmd(
        pdf,
        basename(map_file),
        keep_tables_together = keep_tables
      ),
      qmd_file
    )
    quarto_render(
      input = qmd_file,
      output_format = "typst",
      output_file = basename(output_file),
      quarto_args = c("--output-dir", workdir),
      execute = TRUE,
      quiet = FALSE
    )
    if (!file.exists(output_file)) {
      stop("Quarto did not produce the requested to-do PDF.", call. = FALSE)
    }
    invisible(output_file)
  }

  keep_rendered <- tryCatch(
    {
      render_pdf(keep_qmd, keep_output, keep_tables = TRUE)
      TRUE
    },
    error = function(e) {
      message(
        "Could not render the keep-together PDF; using the compact layout."
      )
      FALSE
    }
  )
  keep_pages <- if (keep_rendered) {
    todo_pdf_page_count(keep_output)
  } else {
    NA_integer_
  }

  # The map and active-summary page is deliberately last. Accept the
  # keep-together render only when it leaves the task content within three
  # pages; otherwise retain the compact layout rather than creating page 5.
  if (isTRUE(keep_rendered) && !is.na(keep_pages) && keep_pages <= 4L) {
    selected_output <- keep_output
  } else {
    if (isTRUE(keep_rendered) && !is.na(keep_pages)) {
      message(
        glue(
          "Keeping tables together would produce {keep_pages} pages; " ,
          "using the compact three-page task layout."
        )
      )
    }
    render_pdf(qmd, output, keep_tables = FALSE)
    selected_output <- output
  }

  file.copy(selected_output, file, overwrite = TRUE)
  invisible(file)
}
