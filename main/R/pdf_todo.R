todo_pdf_prepare_team_marks <- function(available_combos = NULL) {
  if (is.null(available_combos)) {
    available_combos <- tryCatch(
      DBq("
        SELECT mark
        FROM AVAILABLE_COMBOS
        WHERE site_code = 'CR'
        ORDER BY
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
  marks <- if ("mark" %in% names(combos_dt)) {
    as.character(combos_dt$mark)
  } else {
    character()
  }

  marks <- trimws(marks)
  marks <- marks[!is.na(marks) & nzchar(marks)]
  if (length(marks) < 30) {
    stop(
      sprintf(
        "Team marks requires 30 available combinations; only %d were returned.",
        length(marks)
      ),
      call. = FALSE
    )
  }
  marks <- head(marks, 30)

  team_marks <- as.data.table(
    matrix(marks, nrow = 3, byrow = TRUE)
  )

  setnames(team_marks, as.character(seq_len(ncol(team_marks))))
  team_marks[, Team := c("Team 1", "Team 2", "Team 3")]
  setcolorder(team_marks, c("Team", as.character(seq_len(10))))

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
  glue("version {commit_id}")
}


todo_pdf_prepare_unseen_tagged_birds <- function(view_1) {
  output_columns <- c("Mark", "Sex", "Nest", "Days Since Cap")
  empty_output <- function() {
    as.data.table(setNames(
      rep(list(character()), length(output_columns)),
      output_columns
    ))
  }

  if (is.null(view_1)) {
    return(empty_output())
  }

  birds <- data.table(view_1)
  required_columns <- c(
    "mark",
    "sex",
    "nest_id",
    "days_since_cap",
    "days_since_last_seen"
  )

  if (!all(required_columns %in% names(birds))) {
    missing_columns <- setdiff(required_columns, names(birds))
    stop(
      sprintf(
        "VIEW_1 is missing fields required for tagged-bird follow-up: %s.",
        paste(missing_columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  birds[, let(
    days_since_cap = todo_pdf_as_numeric(days_since_cap),
    days_since_last_seen = todo_pdf_as_numeric(days_since_last_seen)
  )]
  birds <- birds[
    !is.na(days_since_cap)
      & days_since_cap > 7
      & is.na(days_since_last_seen)
  ]

  if (!nrow(birds)) {
    return(empty_output())
  }

  birds[, let(
    mark = trimws(as.character(mark)),
    sex = trimws(as.character(sex)),
    nest_id = trimws(as.character(nest_id))
  )]
  birds <- birds[order(-days_since_cap, mark, nest_id, na.last = TRUE)]

  birds[, .(
    Mark = fifelse(is.na(mark), "", mark),
    Sex = fifelse(is.na(sex), "", sex),
    Nest = fifelse(is.na(nest_id), "", nest_id),
    `Days Since Cap` = as.character(days_since_cap)
  )]
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
  parent_todos <- c("Untrapped parent", "Parent capture", "Parent resighting")
  parent_mark_columns <- c("M_mark", "F_mark")
  if (
    !nrow(todo_dt)
      || !all(c("nest_id", "todo", parent_mark_columns) %in% names(todo_dt))
  ) {
    return(empty_output())
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
  unseen_tagged_birds = NULL,
  hatch_prediction = NULL
) {
  nests <- data.table(nests_latest)
  todo_dt <- data.table(todo)
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

  summary[, c("Male", "Female") := lapply(.SD, function(x) {
    x[is.na(x)] <- ""
    x[toupper(trimws(x)) == "NULL"] <- ""
    gsub("[\r\n]+", " ", x)
  }), .SDcols = c("Male", "Female")]

  check_todos <- c("Clutch check", "Unprocessed nest", "nest check")
  tagged_resight_nests <- .todo_pdf_map_prepare_tagged_resight_nests(
    unseen_tagged_birds
  )
  if (
    (nrow(todo_dt) && all(c("nest_id", "todo") %in% names(todo_dt)))
      || nrow(tagged_resight_nests)
  ) {
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
          ),
          tagged_resight = FALSE
        ),
        by = nest_id
      ]
    } else {
      task_symbols <- data.table(
        nest_id = character(),
        Symbol = character(),
        SymbolColor = character(),
        tagged_resight = logical()
      )
    }
    if (nrow(tagged_resight_nests)) {
      tagged_symbols <- copy(tagged_resight_nests)
      tagged_symbols[, `:=`(
        Symbol = "circle",
        SymbolColor = "#1976d2",
        tagged_resight = TRUE
      )]
      task_symbols <- rbind(task_symbols, tagged_symbols, fill = TRUE)
    }
    task_symbols <- task_symbols[
      , .(
        Symbol = if (any(Symbol == "notA")) {
          "notA"
        } else if (any(Symbol == "triangle")) {
          "triangle"
        } else {
          "circle"
        },
        SymbolColor = if (any(tagged_resight)) {
          "#1976d2"
        } else if (any(Symbol == "notA")) {
          "#7b858b"
        } else if (any(SymbolColor == "#d32f2f")) {
          "#d32f2f"
        } else if (any(SymbolColor == "#1976d2")) {
          "#1976d2"
        } else {
          "#7b858b"
        }
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
      "LabelFill", "LabelText"
    )
  )
  summary[order(Nest)]
}


todo_pdf_prepare <- function(
  todo = DBq("SELECT * FROM TODO_LIST"),
  available_combos = NULL,
  nests_latest = NULL,
  chick_captures = NULL,
  unseen_tagged_birds = NULL,
  hatch_prediction = NULL
) {
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
  todo_dt[, notes := parent_capture_notes]

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
      Hatch = min_days_to_hatch,
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

  list(
    title = glue("Cass To-Dos for {refdate}"),
    rows = rows,
    team_marks = todo_pdf_prepare_team_marks(available_combos),
    unseen_tagged_birds = todo_pdf_prepare_unseen_tagged_birds(
      unseen_tagged_birds
    ),
    nest_summary = todo_pdf_prepare_nest_summary(
      nests_latest,
      refdate,
      todo_dt,
      chick_captures,
      unseen_tagged_birds,
      hatch_prediction
    )
  )
}

todo_pdf_heading <- function(todo_name) {
  switch(
    todo_name,
    "Hiding spot photos needed" = list(
      title = "Broods to photograph",
      subtitle = "find these broods and take in-situ and tent photos before the chicks are 7 days old"
    ),
    "Unprocessed nest" = list(
      title = "Nests to process",
      subtitle = "egg photos and/or floatation needed"
    ),
    "Untrapped parent" = list(
      title = "Nests with parents to capture or resight",
      subtitle = "band unmarked parents or determine identity with resighting"
    ),
    "Parent capture" = list(
      title = "Parents to capture",
      subtitle = "follow notes for tag deployment or band-only instructions"
    ),
    "Parent resighting" = list(
      title = "Parents to resight for nest association",
      subtitle = "Association of MM-cap parent resolved after either 1) three subsequent resightings, or 2) one ‘behav’ “IN”, “NM”, “BW”, “BC”, “FC” resighting"
    ),
    "Untrapped brood" = list(
      title = "Broods to band",
      subtitle = NULL
    ),
    "nest check" = list(
      title = "Nests to check for potential hatch",
      subtitle = "egg floatation data estimates that these nests are within 7 days of hatching"
    ),
    "take scrape photos" = list(
      title = "Take scrape photos",
      subtitle = NULL
    ),
    "Clutch check" = list(
      title = "Nests to check for additional eggs",
      subtitle = "revisit to confirm whether the clutch has increased"
    ),
    "notA nest-check" = list(
      title = "Nests requiring a 'notA' closure visit",
      subtitle = "these nests have finished and can be closed; nest_ids with state \"H\" may still be active mobile broods that require monitoring"
    ),
    list(
      title = todo_name,
      subtitle = NULL
    )
  )
}

todo_pdf_note_key <- function(notes = character()) {
  definitions <- list(
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
      text = "Captured with mobile mist net. Three subsequent nest-linked resightings with matching sex and identity confirms association OR a single nest-linked resighting with behav 'IN', 'NM', 'BW', 'BC', or 'FC'."
    ),
    list(
      label = "Pair completion",
      pattern = "pair completion",
      text = "Prioritize tagging the eligible untagged mate so that both pair members are tagged"
    ),
    list(
      label = "Sex/phenology balance",
      pattern = "sex/phenology balance",
      text = "Deploy to the stated sex to reduce the global sex imbalance and that lay-date stratum's deficit."
    ),
    list(
      label = "FO marker",
      pattern = "FO marker",
      text = "Orange-flagged AU migrant; never deploy a GEO."
    ),
    list(
      label = "Band only",
      pattern = "band",
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

todo_pdf_nest_summary_table <- function(nest_summary, n_blocks = 3L) {
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
  label_inset_y <- 3
  max_inset_y <- 4.2
  target_table_height <- 320
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
      glue('table.cell(fill: rgb("{header_fill}"))[#strong[Nest]]'),
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
            ']'
          )
        } else {
          glue(
            '#box[',
            '  #text(size: {symbol_size}pt, fill: rgb("{block$SymbolColor[row]}"))[{glyph}]',
            '  #h(1pt)',
            '  #strong[{typst_content(block$Nest[row])}]',
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
      "  align: (left, center, center, center),",
      glue("  inset: (x: 2.2pt, y: {inset_y}pt),"),
      '  stroke: 0.25pt + rgb("#aeb8ba"),',
      paste0("  ", paste(cells, collapse = ",\n  "), ","),
      ")",
      "]"
    )
  }

  tables <- lapply(blocks, typst_table)

  c(
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
}


todo_pdf_task_table <- function(todo_rows, nest_summary = NULL) {
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

  c(
    "```{=typst}",
    "#set text(size: 8.5pt)",
    "#table(",
    "  columns: (8fr, 6fr, 10fr, 9fr, 10fr, 14fr, 14fr, 29fr),",
    "  align: (center, center, center, center, center, center, center, left),",
    "  inset: (x: 2.2pt, y: 3pt),",
    "  stroke: none,",
    paste0("  ", paste(cells, collapse = ",\n  "), ","),
    ")",
    "#set text(size: 9pt)",
    "```",
    ""
  )
}


todo_pdf_simple_table <- function(table_data, column_widths = NULL) {
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
  }
  columns <- paste0(column_widths, "fr", collapse = ", ")

  c(
    "```{=typst}",
    "#set text(size: 8.5pt)",
    "#table(",
    glue("  columns: ({columns}),"),
    "  align: center,",
    "  inset: (x: 2.2pt, y: 3pt),",
    "  stroke: none,",
    paste0("  ", paste(cells, collapse = ",\n  "), ","),
    ")",
    "#set text(size: 9pt)",
    "```",
    ""
  )
}


todo_pdf_body <- function(
  rows,
  team_marks = NULL,
  map_file = NULL,
  nest_summary = NULL,
  unseen_tagged_birds = NULL
) {
  out <- todo_pdf_note_key(rows$Notes)
  if (!nrow(rows)) {
    out <- c(out, "No to-do items.", "")
  } else {
    table_cols <- setdiff(names(rows), "Todo")

    for (todo in unique(rows$Todo)) {
      todo_rows <- as.data.frame(rows[Todo == todo, ..table_cols])
      heading <- todo_pdf_heading(todo)

      if (todo == "Hiding spot photos needed") {
        names(todo_rows)[names(todo_rows) == "Nest"] <- "Brood"
      } else if (todo %in% c("Parent capture", "Parent resighting", "Untrapped brood")) {
        names(todo_rows)[names(todo_rows) == "Nest"] <- "Nest/Brood"
      }

      if (!(todo %in% c("notA nest-check", "Hiding spot photos needed"))) {
        names(todo_rows)[names(todo_rows) == "Hatch"] <- "Est. Hatch"
      }

      out <- c(
        out,
        glue("## {heading$title}"),
        ""
      )

      if (!is.null(heading$subtitle)) {
        out <- c(
          out,
          glue("*{heading$subtitle}*"),
          ""
        )
      }

      # Use one borderless, striped renderer for every operational task table.
      # This keeps label-aware and ordinary task tables visually consistent.
      task_table <- todo_pdf_task_table(todo_rows, nest_summary)

      out <- c(out, task_table)
    }
  }

  if (!is.null(unseen_tagged_birds) && nrow(unseen_tagged_birds)) {
    out <- c(
      out,
      "## Tagged birds to resight",
      "",
      "*These birds have not been in seen in over 7 days since tag deployment, please resight and comment either \"no limp\", \"slight limp\", or \"severe limp\".*",
      "",
      todo_pdf_simple_table(
        unseen_tagged_birds,
        column_widths = c(28, 12, 24, 20)
      ),
      ""
    )
  }

  if (!is.null(team_marks) && nrow(team_marks)) {
    out <- c(
      out,
      "## Team marks",
      "",
      "*Use non-Lime 1.5x bands for the geolocator spacer on the tibia, and 2x bands on the tarsi*",
      "",
      todo_pdf_simple_table(
        team_marks,
        column_widths = c(12, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8)
      ),
      ""
    )
  }

  if (!is.null(map_file)) {
    out <- c(
      out,
      "```{=typst}",
      "#set page(margin: (x: 1.5cm, y: 1cm))",
      "#pagebreak()",
      "#align(left)[#emph[#text(size: 8.5pt)[Only nests and broods with to-dos are shown. Nests are labelled in black, broods are labelled according to the band colour assigned to chicks. Nest points are stationary, brood points show the latest recorded location]]]",
      "#v(0.1em)",
      glue('#align(center)[#image("{map_file}", width: 100%)]'),
      "#v(-0.4em)",
      "```",
      "",
      "```{=typst}",
      "#v(-0.35em)",
      "#align(left)[#text(size: 10pt, weight: \"bold\")[Summary of currently active nests and broods]]",
      "#align(left)[#emph[#text(size: 8pt)[Broods are labelled according to the band colour assigned to chicks. Symbols match the task shown on the map. Number in \"Est. Hatch\" is the days until the estimated hatch date for active nests; negative values show days overdue, while negative values for broods show days since hatch.]]]",
      "```",
      "",
      todo_pdf_nest_summary_table(nest_summary)
    )
  }

  out
}

todo_pdf_qmd <- function(
  pdf,
  map_file = NULL,
  template = file.path("templates", "todo_pdf.qmd")
) {
  body <- todo_pdf_body(
    pdf$rows,
    pdf$team_marks,
    map_file,
    pdf$nest_summary,
    pdf$unseen_tagged_birds
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

todo_pdf_save <- function(
  file,
  todo = DBq("SELECT * FROM TODO_LIST"),
  available_combos = NULL,
  spatial_objects = NULL,
  nests_latest = NULL,
  chick_captures = NULL,
  unseen_tagged_birds = NULL,
  broods_latest = NULL,
  hatch_prediction = NULL
) {
  if (is.null(broods_latest)) {
    if (is.null(nests_latest)) {
      broods_latest <- DBq("SELECT * FROM BROODS_LATEST")
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
  map_file <- file.path(workdir, "todo_map.png")

  if (is.null(spatial_objects)) {
    spatial_objects <- DBq(
      "SELECT * FROM spatial_objects WHERE variable = 'study_area'"
    )
  }
  if (is.null(chick_captures)) {
    chick_captures <- DBq("
      SELECT nest_id, date, caught, age, site, ring, LL, LR, pk
      FROM CAPTURES
      WHERE age = 'C'
        AND site = 'CR'
        AND nest_id IS NOT NULL
        AND TRIM(nest_id) NOT IN ('', 'NO_NEST')
    ")
  }
  if (is.null(unseen_tagged_birds)) {
    unseen_tagged_birds <- DBq("
      SELECT mark, sex, nest_id, days_since_cap, days_since_last_seen
      FROM VIEW_1
      WHERE days_since_cap > 7
        AND days_since_last_seen IS NULL
      ORDER BY days_since_cap DESC, mark, nest_id
    ")
  }
  if (is.null(hatch_prediction)) {
    hatch_prediction <- DBq(
      "SELECT * FROM EGGS_HATCH_PREDICTION"
    )
  }
  pdf <- todo_pdf_prepare(
    todo,
    available_combos,
    broods_latest,
    chick_captures,
    unseen_tagged_birds,
    hatch_prediction
  )

  todo_pdf_map_save(
    file = map_file,
    todo = todo,
    spatial_objects = spatial_objects,
    chick_captures = chick_captures,
    nests_latest = broods_latest,
    unseen_tagged_birds = unseen_tagged_birds
  )

  writeLines(todo_pdf_qmd(pdf, basename(map_file)), qmd)
  quarto_render(
    input = qmd,
    output_format = "typst",
    output_file = basename(output),
    quarto_args = c("--output-dir", workdir),
    execute = TRUE,
    quiet = FALSE
  )

  file.copy(output, file, overwrite = TRUE)
  invisible(file)
}
