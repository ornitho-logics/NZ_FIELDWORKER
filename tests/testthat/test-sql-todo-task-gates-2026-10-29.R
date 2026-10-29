library(testthat)

task_gate_refresh_source <- function() {
  paste(readLines(
    app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
    warn = FALSE
  ), collapse = "\n")
}

task_gate_extract_cte <- function(sql, name, next_name) {
  start <- regexpr(paste0(name, " AS ("), sql, fixed = TRUE)[1L]
  stopifnot(start > 0L)
  remaining <- substring(sql, start)
  end <- regexpr(
    paste0("),\n", next_name, " AS ("), remaining, fixed = TRUE
  )[1L]
  stopifnot(end > 0L)
  substr(remaining, 1L, end)
}

task_gate_extract_target_parent_case <- function(sql) {
  start_marker <- paste0(
    "    CASE\n",
    "      WHEN active_nests.nest_id = 'B2203'\n",
    "       AND UPPER(TRIM(COALESCE(adult_parent_status.F_parent_mark, ''))) = 'YY-TB.BL'\n",
    "      THEN 'F'\n",
    "      WHEN tag_deployment_plan.geo_tag_target"
  )
  start <- regexpr(start_marker, sql, fixed = TRUE)[1L]
  stopifnot(start > 0L)
  end_marker <- "\n    END AS target_parent"
  end <- regexpr(end_marker, sql, fixed = TRUE)[1L]
  stopifnot(end > 0L)
  substr(
    sql,
    start,
    end + nchar(end_marker) - 1L
  )
}

task_gate_disposable_query <- function(sql) {
  socket <- Sys.getenv("THREAD2_TEST_MARIADB_SOCKET", unset = "")
  if (
    Sys.getenv("THREAD2_TEST_MARIADB_DISPOSABLE", unset = "") != "1"
      || !grepl("^(/private)?/tmp/[^/]+\\.sock$", socket)
      || !file.exists(socket)
      || !nzchar(Sys.which("mariadb"))
  ) {
    skip("requires the explicitly selected disposable local MariaDB socket")
  }
  result <- system2(
    Sys.which("mariadb"),
    args = c(
      "--no-defaults", "--batch", "--skip-column-names",
      "--socket", socket, "--user", "root"
    ),
    input = sql, stdout = TRUE, stderr = TRUE
  )
  if (!is.null(attr(result, "status"))) {
    stop(paste(result, collapse = "\n"))
  }
  result
}

task_gate_values_cte <- function(name, rows) {
  literal <- function(value) {
    if (is.na(value)) return("NULL")
    if (is.numeric(value)) return(as.character(value))
    paste0("'", gsub("'", "''", as.character(value), fixed = TRUE), "'")
  }
  selects <- vapply(seq_len(nrow(rows)), function(i) {
    cells <- vapply(names(rows), function(column) {
      paste(literal(rows[[column]][i]), "AS", column)
    }, character(1))
    paste("SELECT", paste(cells, collapse = ", "))
  }, character(1))
  paste0(name, " AS (", paste(selects, collapse = "\nUNION ALL\n"), ")")
}

test_that("actual shared flagging gate uses latest identities and safe fallback", {
  rows <- data.frame(
    nest_id = c(
      "TEST_CLOSED", "TEST_TWO", "TEST_UNFLAGGED", "TEST_NO_LATEST",
      "TEST_UNRESOLVED", "TEST_DEAD_ONLY", "TEST_FALLBACK_DONE"
    ),
    latest_encounter_availability = c(
      "available", "available", "available", NA,
      "conservative", "unavailable", "unavailable"
    ),
    latest_encounter_count = c(1, 2, 1, NA, 1, 0, NA),
    latest_encounter_flagged_count = c(1, 1, 0, NA, 1, 0, NA),
    latest_encounter_unflagged_count = c(0, 1, 1, NA, 0, 0, NA),
    latest_encounter_unresolved_count = c(0, 0, 0, NA, 1, 0, NA),
    n_operational_brood_size = c(3, 3, 3, 3, 3, 2, 1),
    n_active_flagged_chick_rings = rep(1, 7),
    stringsAsFactors = FALSE
  )
  gate <- task_gate_extract_cte(
    task_gate_refresh_source(), "flagging_context", "hiding_spot_photos"
  )
  observed <- task_gate_disposable_query(paste(
    "WITH", task_gate_values_cte("chick_captures", rows), ",", gate,
    "SELECT CONCAT_WS('|', nest_id, flagging_work_pending,",
    "flagging_pending_count) FROM flagging_context ORDER BY nest_id;"
  ))
  expect_identical(observed, c(
    "TEST_CLOSED|0|0", "TEST_DEAD_ONLY|1|1", "TEST_FALLBACK_DONE|0|0",
    "TEST_NO_LATEST|1|2", "TEST_TWO|1|1", "TEST_UNFLAGGED|1|1",
    "TEST_UNRESOLVED|1|0"
  ))
})

test_that("both flagging branches retain shared gate and uncertainty guards", {
  sql <- task_gate_refresh_source()
  block <- task_gate_extract_cte(
    sql, "todo_broods_to_recapture_for_flagging", "todo_hiding_spot_photos"
  )
  expect_equal(length(gregexpr(
    "LEFT JOIN flagging_context chick_captures", block, fixed = TRUE
  )[[1L]]), 2L)
  expect_equal(length(gregexpr(
    "COALESCE(chick_captures.flagging_work_pending, 0) = 1",
    block, fixed = TRUE
  )[[1L]]), 2L)
  expect_match(block, "n_unringed_chick_captures", fixed = TRUE)
  expect_match(block, "n_unresolved_dead_chick_events", fixed = TRUE)
})

test_that("actual authoritative resolution includes captures and scoped X-X", {
  rows <- data.frame(
    nest_id = c(
      "TEST_TN", "TEST_FEMALE", "TEST_ORDINARY", "TEST_MM_PENDING",
      "TEST_AMBIG", "TEST_NO_KEY", "TEST_NO_MARK", "TEST_DEAD",
      "TEST_XX_M", "TEST_XX_F"
    ),
    reference_date = rep("2026-10-29", 10),
    M_selected_identity_key = rep("ring:TEST_M", 10),
    F_selected_identity_key = rep(NA_character_, 10),
    M_selected_mark = rep("AB-CD", 10),
    F_selected_mark = rep(NA_character_, 10),
    M_parent_mark = rep("AB-CD", 10),
    F_parent_mark = rep(NA_character_, 10),
    M_resight_association_pending = rep(0, 10),
    F_resight_association_pending = rep(1, 10),
    M_resight_association_ambiguous = rep(0, 10),
    F_resight_association_ambiguous = rep(0, 10),
    M_mm_resight_pending = rep(0, 10),
    F_mm_resight_pending = rep(0, 10),
    M_is_dead = rep(0, 10), F_is_dead = rep(0, 10),
    M_identity_is_dead = rep(0, 10), F_identity_is_dead = rep(0, 10),
    M_confirmed_unbanded = rep(0, 10), F_confirmed_unbanded = rep(0, 10),
    stringsAsFactors = FALSE
  )
  rows$M_resight_association_pending[3] <- 1
  rows$M_mm_resight_pending[4] <- 1
  rows$M_resight_association_ambiguous[5] <- 1
  rows$M_selected_identity_key[6] <- NA_character_
  rows$M_selected_mark[7] <- " "
  rows$M_parent_mark[7] <- " "
  rows$M_is_dead[8] <- 1
  rows$M_identity_is_dead[8] <- 1
  rows$M_selected_identity_key[9] <- "XX:TEST_XX_M:M"
  rows$M_selected_mark[9] <- rows$M_parent_mark[9] <- "X-X"
  rows$M_confirmed_unbanded[9] <- 1
  rows$M_selected_identity_key[c(2, 10)] <- NA_character_
  rows$M_selected_mark[c(2, 10)] <- rows$M_parent_mark[c(2, 10)] <- NA_character_
  rows$F_selected_identity_key[c(2, 10)] <- c("ring:TEST_F", "XX:TEST_XX_F:F")
  rows$F_selected_mark[c(2, 10)] <- rows$F_parent_mark[c(2, 10)] <- c("EF-GH", "X-X")
  rows$F_resight_association_pending[c(2, 10)] <- 0
  rows$F_confirmed_unbanded[10] <- 1

  source <- task_gate_refresh_source()
  resolution <- task_gate_extract_cte(
    source, "parent_resolution_status", "adult_capture_interval_status"
  )
  first_union <- substring(source, regexpr(
    "todo_parent_resighting_existing AS (", source, fixed = TRUE
  )[1L])
  first_union <- substr(first_union, 1L, regexpr(
    "\n  UNION ALL", first_union, fixed = TRUE
  )[1L] - 1L)
  first_union <- paste0(first_union, "\n)")
  candidates <- data.frame(
    nest_id = rows$nest_id, reference_date = rows$reference_date,
    parent_task_class = rep("Parent resighting", nrow(rows)),
    notes = rep("resight F; 36hr rule", nrow(rows)),
    days_overdue = 0, priority = 1, min_days_to_hatch = 5,
    last_visit_days_ago = 0, nest_state = "I", clutch_size = 3,
    brood_size = 0, M_mark = rows$M_parent_mark, F_mark = rows$F_parent_mark,
    lat = NA_real_, lon = NA_real_, stringsAsFactors = FALSE
  )
  observed <- task_gate_disposable_query(paste(
    "WITH", task_gate_values_cte("adult_parent_status", rows), ",",
    task_gate_values_cte("todo_untrapped_parent", candidates), ",",
    resolution, ",", first_union,
    "SELECT CONCAT_WS('|', resolved.nest_id, M_authoritative_resolved,",
    "F_authoritative_resolved, task.notes) FROM parent_resolution_status resolved",
    "JOIN todo_parent_resighting_existing task ON task.nest_id=resolved.nest_id",
    "ORDER BY resolved.nest_id;"
  ))
  fields <- strsplit(observed, "|", fixed = TRUE)
  bits <- vapply(fields, function(x) paste(x[1:3], collapse = "|"), character(1))
  expect_identical(bits, c(
    "TEST_AMBIG|0|0", "TEST_DEAD|0|0", "TEST_FEMALE|0|1",
    "TEST_MM_PENDING|0|0", "TEST_NO_KEY|0|0", "TEST_NO_MARK|0|0",
    "TEST_ORDINARY|0|0", "TEST_TN|1|0", "TEST_XX_F|0|1", "TEST_XX_M|1|0"
  ))
  pdf_env <- new.env(parent = globalenv())
  sys.source(app_file("main", "R", "pdf_todo.R"), envir = pdf_env)
  tn_note <- fields[[which(vapply(fields, function(x) x[1] == "TEST_TN", logical(1)))]]
  expect_identical(
    pdf_env$todo_pdf_parent_resighting_rule_note(tn_note[4], 0, 0),
    "M resolved; 36hr rule"
  )
  female_note <- fields[[which(vapply(fields, function(x) x[1] == "TEST_FEMALE", logical(1)))]]
  expect_identical(
    pdf_env$todo_pdf_parent_resighting_rule_note(female_note[4], 0, 0),
    "F resolved; 36hr rule"
  )
})

test_that("selected-death consumer guard preserves living-parent work", {
  sql <- task_gate_refresh_source()
  parent_tasks <- task_gate_extract_cte(
    sql, "todo_untrapped_parent", "todo_parent_capture"
  )
  candidates <- data.frame(
    nest_id = c(
      "LIVE_COMPETITOR_DEAD", "DEAD_SELECTED_M", "DEAD_SELECTED_F",
      "DEAD_M_LIVE_F_BOTH_XX", "DEAD_F_LIVE_M_BOTH_XX", "DEAD_BOTH"
    ),
    reference_date = rep("2026-10-29", 6),
    todo = rep("Untrapped parent", 6),
    duplicate_correction = rep(0, 6),
    geo_instruction = rep(NA_character_, 6),
    geo_tag_target = rep(NA_character_, 6),
    geo_band_target = rep(NA_character_, 6),
    is_pair_completion = rep(0, 6),
    capture_allowed_after_completion = rep(1, 6),
    capture_interval_open = rep(1, 6),
    M_confirmed_unbanded = c(1, 1, 0, 1, 1, 1),
    F_confirmed_unbanded = c(0, 0, 1, 1, 1, 1),
    M_identity_is_dead = c(0, 1, 0, 1, 0, 1),
    F_identity_is_dead = c(0, 0, 1, 0, 1, 1),
    M_unknown_status = rep(0, 6),
    F_unknown_status = rep(0, 6),
    M_has_geo = rep(0, 6),
    F_has_geo = rep(0, 6),
    M_single_colour_recruit = rep(0, 6),
    F_single_colour_recruit = rep(0, 6),
    F_mark = rep("AB-CD", 6),
    M_mark = rep("X-X", 6),
    target_parent = c("M", "M", "F", "F", "M", "A"),
    resight_only_when_capture_blocked = rep(0, 6),
    notes = rep("synthetic candidate", 6),
    days_overdue = rep(0, 6),
    priority = rep(1, 6),
    min_days_to_hatch = rep(5, 6),
    last_visit_days_ago = rep(0, 6),
    nest_state = rep("I", 6),
    clutch_size = rep(3, 6),
    brood_size = rep(0, 6),
    lat = rep(NA_real_, 6),
    lon = rep(NA_real_, 6),
    stringsAsFactors = FALSE
  )
  observed <- task_gate_disposable_query(paste(
    "WITH",
    task_gate_values_cte("todo_untrapped_parent_candidate", candidates), ",",
    parent_tasks,
    "SELECT CONCAT_WS('|', nest_id, parent_task_class, notes)",
    "FROM todo_untrapped_parent ORDER BY nest_id;"
  ))
  expect_identical(observed, c(
    "DEAD_F_LIVE_M_BOTH_XX|Parent capture|band X-X M",
    "DEAD_M_LIVE_F_BOTH_XX|Parent capture|band X-X F",
    "LIVE_COMPETITOR_DEAD|Parent capture|band X-X M"
  ))
})

test_that("actual target selector retargets one living parent in two-X-X cases", {
  status <- data.frame(
    nest_id = c("DEAD_M", "DEAD_F", "LIVE_BOTH", "MISSING"),
    M_parent_mark = rep("X-X", 4), F_parent_mark = rep("X-X", 4),
    M_confirmed_unbanded = c(1, 1, 1, 0),
    F_confirmed_unbanded = c(1, 1, 1, 0),
    M_identity_is_dead = c(1, 0, 0, NA),
    F_identity_is_dead = c(0, 1, 0, NA),
    M_unknown_status = rep(0, 4), F_unknown_status = rep(0, 4),
    M_has_geo = rep(0, 4), F_has_geo = rep(0, 4),
    M_mm_resight_pending = rep(0, 4), F_mm_resight_pending = rep(0, 4),
    M_single_colour_recruit = rep(0, 4), F_single_colour_recruit = rep(0, 4),
    stringsAsFactors = FALSE
  )
  nests <- data.frame(nest_id = status$nest_id, stringsAsFactors = FALSE)
  plan <- data.frame(
    nest_id = status$nest_id,
    geo_tag_target = NA_character_,
    geo_target = NA_character_,
    geo_band_target = NA_character_,
    stringsAsFactors = FALSE
  )
  target_case <- sub(
    " AS target_parent$", "",
    task_gate_extract_target_parent_case(task_gate_refresh_source()),
    perl = TRUE
  )
  observed <- task_gate_disposable_query(paste(
    "WITH",
    task_gate_values_cte("active_nests", nests), ",",
    task_gate_values_cte("adult_parent_status", status), ",",
    task_gate_values_cte("tag_deployment_plan", plan),
    "SELECT CONCAT_WS('|', active_nests.nest_id, COALESCE(",
    target_case, ", 'NULL')) FROM active_nests",
    "JOIN adult_parent_status ON adult_parent_status.nest_id = active_nests.nest_id",
    "LEFT JOIN tag_deployment_plan ON tag_deployment_plan.nest_id = active_nests.nest_id",
    "ORDER BY active_nests.nest_id;"
  ))
  expect_identical(observed, c(
    "DEAD_F|M", "DEAD_M|F", "LIVE_BOTH|A", "MISSING|NULL"
  ))
})

test_that("actual pair-completion SQL requires current same-nest deployment proof", {
  n <- 8L
  ids <- sprintf("C_T%03d", seq_len(n))
  status <- data.frame(
    nest_id = ids, M_parent_mark = "X-X", F_parent_mark = "AB-TW.CD (2)",
    M_selected_mark = "X-X", F_selected_mark = "AB-TW.CD",
    M_selected_identity_key = paste0("XX:", ids, ":M"),
    F_selected_identity_key = paste0("ring:TEST_F", seq_len(n)),
    M_has_geo = 0, F_has_geo = 1,
    M_confirmed_unbanded = 1, F_confirmed_unbanded = 0,
    M_unknown_status = 0, F_unknown_status = 0,
    M_resight_association_pending = 0, F_resight_association_pending = 0,
    M_resight_association_ambiguous = 0, F_resight_association_ambiguous = 0,
    M_is_dead = 0, F_is_dead = 0,
    M_identity_is_dead = 0, F_identity_is_dead = 0,
    M_is_au_migrant = 0, F_is_au_migrant = 0,
    stringsAsFactors = FALSE
  )
  for (field in c(
    "parent_mark", "selected_mark", "selected_identity_key", "has_geo",
    "confirmed_unbanded"
  )) {
    male <- paste0("M_", field)
    female <- paste0("F_", field)
    temporary <- status[[male]][2]
    status[[male]][2] <- status[[female]][2]
    status[[female]][2] <- temporary
  }
  status$F_has_geo[6] <- 0
  # A sex-wide death must not suppress a different, selected live identity.
  status$M_is_dead[1] <- 1
  status$M_identity_is_dead[1] <- 0
  status$F_is_dead[2] <- 1
  status$F_identity_is_dead[2] <- 0

  # These two rows exercise genuine selected-dead exclusion symmetrically.
  status$M_is_dead[3] <- 1
  status$M_identity_is_dead[3] <- 1
  status$F_is_dead[4] <- 1
  status$F_identity_is_dead[4] <- 1
  status$M_unknown_status[8] <- 1
  status$M_confirmed_unbanded[8] <- 0
  status$M_selected_identity_key[8] <- NA_character_
  status$M_selected_mark[8] <- status$M_parent_mark[8] <- NA_character_

  history <- data.frame(
    nest_id = ids, capture_sex = c("F", "M", rep("F", 6)),
    identity_key = paste0("ring:TEST_F", seq_len(n)),
    display_mark = "AB-TW.CD",
    capture_date = "2026-10-20", capture_datetime = "2026-10-20 10:00:00",
    has_geo = 1, tag_type = "GEO", tag_action = "D",
    tag_id = paste0("TEST_DEVICE_", seq_len(n)), stringsAsFactors = FALSE
  )
  history$nest_id[3] <- "C_T003"
  history$capture_date[4] <- "2026-10-20"
  history$capture_datetime[4] <- "2026-10-20 10:00:00"
  history$tag_action[5] <- "R"
  history$identity_key[7] <- "ring:DIFFERENT_TEST_BIRD"
  history$display_mark[7] <- "EF-TG.HI"
  nests <- data.frame(nest_id = ids, reference_date = "2026-10-29")
  timing <- data.frame(
    nest_id = ids, clutch_completion_basis_date = "2026-10-01"
  )
  sql <- task_gate_refresh_source()
  history_sql <- task_gate_extract_cte(
    sql, "tag_deployment_history", "tag_deployment_candidates"
  )
  history_sql <- gsub(
    "FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL", "capture_history",
    history_sql, fixed = TRUE
  )
  candidate_sql <- task_gate_extract_cte(
    sql, "tag_deployment_candidates", "tag_deployment_plan"
  )
  plan <- substring(sql, regexpr("tag_deployment_plan AS (", sql, fixed = TRUE)[1])
  end <- regexpr("END AS geo_instruction", plan, fixed = TRUE)[1] +
    nchar("END AS geo_instruction") - 1L
  prefix <- substr(plan, 1L, end)
  starts <- gregexpr("\n    CASE", prefix, fixed = TRUE)[[1L]]
  instruction <- substring(prefix, tail(starts, 1L))
  observed <- task_gate_disposable_query(paste(
    "WITH sr AS (SELECT CAST('2026-10-29' AS DATE) AS reference_date),",
    task_gate_values_cte("capture_history", history), ",",
    task_gate_values_cte("adult_parent_status", status), ",",
    task_gate_values_cte("parent_task_nests", nests), ",",
    task_gate_values_cte("adult_capture_age_status", timing), ",",
    history_sql, ",", candidate_sql, ", instructions AS (",
    "SELECT candidates.nest_id,", instruction,
    "FROM tag_deployment_candidates candidates)",
    "SELECT CONCAT_WS('|', parent_task_nests.nest_id,",
    "COALESCE(instructions.geo_instruction,'NULL'))",
    "FROM parent_task_nests LEFT JOIN instructions",
    "ON instructions.nest_id = parent_task_nests.nest_id",
    "ORDER BY parent_task_nests.nest_id;"
  ))
  expect_identical(observed, c(
    "C_T001|tag X-X M (pair completion)",
    "C_T002|tag X-X F (pair completion)",
    "C_T003|NULL", "C_T004|NULL", "C_T005|NULL", "C_T006|NULL",
    "C_T007|NULL", "C_T008|resight/tag M (status ?; pair completion)"
  ))
})
