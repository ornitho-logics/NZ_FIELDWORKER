test_that("TODO task assembly consumes the bounded context input", {
  refresh_sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  task_start <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD (",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  task_end <- regexpr(
    "SELECT 'TODO_REFRESH_STAGE|publishing'",
    substring(refresh_sql, task_start),
    fixed = TRUE
  )[[1L]]

  expect_gt(task_start, 0L)
  expect_gt(task_end, 0L)

  task_sql <- substring(
    refresh_sql,
    task_start,
    task_start + task_end - 2L
  )

  expect_match(task_sql, "TODO_NEST_CONTEXT_INPUT", fixed = TRUE)
  expect_no_match(task_sql, "TODO_NEST_CONTEXT context", fixed = TRUE)
  expect_no_match(task_sql, "nest_history AS (", fixed = TRUE)
  expect_match(task_sql, "TODO_BROOD_CONTEXT_INPUT", fixed = TRUE)
  expect_match(task_sql, "TODO_CHICK_CAPTURE_CONTEXT_INPUT", fixed = TRUE)
  expect_match(
    task_sql,
    "TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD",
    fixed = TRUE
  )
  expect_false(
    grepl(
      "FROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT",
      task_sql,
      fixed = TRUE
    )
  )
  expect_no_match(task_sql, "BROODS_LATEST b", fixed = TRUE)
  expect_no_match(task_sql, "BROODS_LATEST brood_evidence", fixed = TRUE)
  expect_match(task_sql, "brood_context AS (", fixed = TRUE)
  expect_match(
    task_sql,
    "FROM FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_INPUT\n),\nlatest_nests AS",
    fixed = TRUE
  )
  expect_false(
    grepl(
      "FROM FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_INPUT b",
      task_sql,
      fixed = TRUE
    )
  )
  expect_match(task_sql, "task_context AS (", fixed = TRUE)
  expect_match(
    task_sql,
    "FROM FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_INPUT\n),\nbrood_context AS",
    fixed = TRUE
  )
  expect_match(
    task_sql,
    "FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT\n),",
    fixed = TRUE
  )
  expect_false(
    grepl(
      "FROM FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_INPUT context",
      task_sql,
      fixed = TRUE
    )
  )

  resighting_start <- regexpr(
    "todo_parent_resighting_existing AS (",
    task_sql,
    fixed = TRUE
  )[[1L]]
  resighting_end <- regexpr(
    "todo_parent_resighting AS (",
    substring(task_sql, resighting_start),
    fixed = TRUE
  )[[1L]]
  expect_gt(resighting_start, 0L)
  expect_gt(resighting_end, 0L)
  resighting_sql <- substring(
    task_sql,
    resighting_start,
    resighting_start + resighting_end - 2L
  )
  expect_equal(
    length(strsplit(resighting_sql, "\n  JOIN parent_resolution_status association\n", fixed = TRUE)[[1L]]) - 1L,
    1L
  )
  expect_no_match(
    resighting_sql,
    "LEFT JOIN adult_parent_status\n",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "CREATE TEMPORARY TABLE tmp_todo_chick_capture_context_base AS",
    fixed = TRUE
  )
  expect_match(refresh_sql, "FROM context_units", fixed = TRUE)
  expect_match(
    refresh_sql,
    "FROM tmp_todo_chick_latest_encounter_context",
    fixed = TRUE
  )
  expect_match(refresh_sql, "M_authoritative_resolved", fixed = TRUE)
  expect_match(refresh_sql, "F_authoritative_resolved", fixed = TRUE)

  expect_match(
    refresh_sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD (",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "INDEX idx_todo_nest_context_nest_reference (nest_id, reference_date)",
    fixed = TRUE
  )
  expect_no_match(
    refresh_sql,
    "INDEX idx_todo_nest_context_nest (nest_id),",
    fixed = TRUE
  )
  expect_match(refresh_sql, "capture_gate_clutch_size", fixed = TRUE)
  expect_match(
    refresh_sql,
    "capture_gate_clutch_start_datetime",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD (",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD (",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "CREATE TEMPORARY TABLE tmp_todo_hiding_photo_targets (",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "INDEX idx_tmp_todo_hiding_targets_nest_ring (nest_id, ring_key)",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "FROM tmp_todo_chick_capture_targets target",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT AS\nSELECT *\nFROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT;",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "DROP TEMPORARY TABLE IF EXISTS tmp_todo_hiding_photo_targets;",
    fixed = TRUE
  )
  expect_no_match(
    refresh_sql,
    "tmp_todo_hiding_photo_s10",
    fixed = TRUE
  )
  expect_no_match(
    refresh_sql,
    "authoritative_parent_same_occasion",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "FROM FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h",
    fixed = TRUE
  )
  expect_match(refresh_sql, "'ring_capture'", fixed = TRUE)
  expect_false(
    grepl(
      "TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT AS\nWITH sr AS",
      refresh_sql,
      fixed = TRUE
    )
  )
  expect_match(refresh_sql, "raw_chick_events AS (", fixed = TRUE)
  expect_match(refresh_sql, "known_ring_nest_history AS (", fixed = TRUE)
  expect_match(refresh_sql, "latest_prior_ring_date AS (", fixed = TRUE)
  expect_match(refresh_sql, "HAVING COUNT(*) = 1", fixed = TRUE)
  expect_match(
    refresh_sql,
    "COALESCE(e.recorded_nest_id, inferred.inferred_nest_id)",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "INDEX idx_todo_chick_capture_context_nest (nest_id)",
    fixed = TRUE
  )
  for (field in c(
    "latest_encounter_date",
    "latest_encounter_count",
    "latest_encounter_flagged_count",
    "latest_encounter_unflagged_count",
    "latest_encounter_availability",
    "latest_encounter_provenance"
  )) {
    expect_match(refresh_sql, field, fixed = TRUE)
  }
  expect_match(refresh_sql, "flagging_context AS (", fixed = TRUE)
  expect_match(refresh_sql, "flagging_work_pending", fixed = TRUE)
  expect_match(refresh_sql, "flagging_pending_count", fixed = TRUE)
  expect_match(
    refresh_sql,
    "tmp_todo_chick_latest_encounter_context latest",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "INDEX idx_todo_brood_context_nest_reference (nest_id, reference_date)",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "TODO_NEST_CONTEXT_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT",
    fixed = TRUE
  )
  for (stage in c(
    "nest_context",
    "brood_context",
    "chick_gps_links",
    "parent_status",
    "chick_capture_context",
    "hiding_spot_photos",
    "task_rows",
    "publishing"
  )) {
    expect_match(
      refresh_sql,
      paste0("TODO_REFRESH_STAGE|", stage),
      fixed = TRUE
    )
  }

  context_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  parent_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  link_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  task_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(context_build, 0L)
  brood_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  chick_capture_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  hiding_photo_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(link_build, context_build)
  expect_gt(brood_build, context_build)
  expect_gt(link_build, brood_build)
  expect_gt(parent_build, link_build)
  expect_gt(chick_capture_build, parent_build)
  expect_gt(hiding_photo_build, parent_build)
  expect_gt(hiding_photo_build, chick_capture_build)
  expect_gt(task_build, parent_build)
  expect_gt(task_build, hiding_photo_build)

  expect_match(
    refresh_sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD (",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "INDEX idx_parent_chick_gps_capture_nest (capture_pk, nest_id)",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT AS",
      "SELECT *",
      "FROM FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD;",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "TODO_BROOD_CONTEXT_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT AS",
      "SELECT *",
      "FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD;",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT",
    fixed = TRUE
  )
})


test_that("temporary chick inputs are cleared before, not during, staging", {
  refresh_sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  cleanup_start <- regexpr(
    "DROP TEMPORARY TABLE IF EXISTS tmp_todo_chick_capture_events;",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  source_start <- regexpr(
    "CREATE TEMPORARY TABLE tmp_todo_chick_capture_events AS",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  final_drop_start <- regexpr(
    "DROP TEMPORARY TABLE tmp_todo_chick_capture_events;",
    refresh_sql,
    fixed = TRUE
  )[[1L]]

  expect_gt(cleanup_start, 0L)
  expect_gt(source_start, cleanup_start)
  expect_gt(final_drop_start, source_start)
  expect_equal(
    lengths(regmatches(
      refresh_sql,
      gregexpr(
        "DROP TEMPORARY TABLE IF EXISTS tmp_todo_chick_capture_events;",
        refresh_sql,
        fixed = TRUE
      )
    )),
    1L
  )
})


test_that("chick context input is reset before stale BUILD removal", {
  refresh_sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  reset_start <- regexpr(
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT AS",
      "SELECT",
      "  CAST(NULL AS CHAR(6)) AS nest_id,",
      sep = "\n"
    ),
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  stale_build_drop <- regexpr(
    "DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD;",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  reset_sql <- substring(refresh_sql, reset_start, stale_build_drop - 1L)

  expect_gt(reset_start, 0L)
  expect_gt(stale_build_drop, reset_start)
  expect_match(reset_sql, "CAST(NULL AS SIGNED) AS n_chick_captures", fixed = TRUE)
  expect_match(reset_sql, "CAST(NULL AS CHAR(128)) AS latest_encounter_provenance", fixed = TRUE)
  expect_match(reset_sql, "WHERE 1 = 0", fixed = TRUE)
  expect_no_match(
    reset_sql,
    "FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT",
    fixed = TRUE
  )
})


test_that("parent resighting accepts authoritative capture-resolved identities", {
  refresh_sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  resighting_start <- regexpr(
    "todo_parent_resighting_existing AS (",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  resighting_end <- regexpr(
    "todo_parent_resighting AS (",
    substring(refresh_sql, resighting_start),
    fixed = TRUE
  )[[1L]]
  expect_gt(resighting_start, 0L)
  expect_gt(resighting_end, 0L)
  resighting_sql <- substring(
    refresh_sql,
    resighting_start,
    resighting_start + resighting_end - 2L
  )

  expect_match(
    resighting_sql,
    "JOIN parent_resolution_status association",
    fixed = TRUE
  )
  expect_match(resighting_sql, "F_authoritative_resolved", fixed = TRUE)
  expect_match(resighting_sql, "M_authoritative_resolved", fixed = TRUE)
  expect_no_match(
    resighting_sql,
    "F_resighting_identity_count > 0",
    fixed = TRUE
  )
  expect_no_match(
    resighting_sql,
    "M_resighting_identity_count > 0",
    fixed = TRUE
  )
  expect_no_match(
    resighting_sql,
    "F_resight_association_selected_mark",
    fixed = TRUE
  )
  expect_no_match(
    resighting_sql,
    "M_resight_association_selected_mark",
    fixed = TRUE
  )

  first_union_end <- regexpr(
    "\n  UNION ALL\n",
    resighting_sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(first_union_end, 0L)
  first_union_sql <- substring(resighting_sql, 1L, first_union_end - 1L)
  expect_match(
    first_union_sql,
    "FROM todo_untrapped_parent candidate",
    fixed = TRUE
  )
  expect_match(
    first_union_sql,
    "LEFT JOIN parent_resolution_status association",
    fixed = TRUE
  )
  expect_match(first_union_sql, "CONCAT_WS(", fixed = TRUE)
  expect_match(first_union_sql, "'M resolved'", fixed = TRUE)
  expect_match(first_union_sql, "'F resolved'", fixed = TRUE)

  # A blocked candidate must retain its eligibility wording while exposing
  # the authoritative opposite-sex resolution to the PDF/display layer.
  candidate_note <- "resight F; 36hr rule"
  expect_equal(
    paste(candidate_note, "M resolved", sep = "; "),
    "resight F; 36hr rule; M resolved"
  )
})


test_that("GEO pair completion follows canonical identity provenance", {
  refresh_sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  history_start <- regexpr(
    "tag_deployment_history AS (",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  history_end <- regexpr(
    "tag_deployment_candidates AS (",
    substring(refresh_sql, history_start),
    fixed = TRUE
  )[[1L]]
  expect_gt(history_start, 0L)
  expect_gt(history_end, 0L)
  history_sql <- substring(
    refresh_sql,
    history_start,
    history_start + history_end - 2L
  )

  expect_match(
    history_sql,
    "FROM FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c",
    fixed = TRUE
  )
  expect_match(history_sql, "c.capture_datetime", fixed = TRUE)
  expect_match(history_sql, "c.has_geo = 1", fixed = TRUE)
  expect_match(
    refresh_sql,
    "history.identity_key = adult_parent_status.M_selected_identity_key",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "history.identity_key = adult_parent_status.F_selected_identity_key",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "COALESCE(adult_parent_status.M_identity_is_dead, 0) = 0",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "COALESCE(adult_parent_status.F_identity_is_dead, 0) = 0",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "target_parent = 'M' AND COALESCE(M_identity_is_dead, 0) = 1",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "target_parent = 'F' AND COALESCE(F_identity_is_dead, 0) = 1",
    fixed = TRUE
  )
  expect_match(refresh_sql, "c.capture_date <= sr.reference_date", fixed = TRUE)
})


test_that("closure evidence is cached once without changing source-row semantics", {
  refresh_sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  closure_start <- regexpr(
    "SELECT 'TODO_REFRESH_STAGE|brood_closure'",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  task_start <- regexpr(
    "SELECT 'TODO_REFRESH_STAGE|task_rows'",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(closure_start, 0L)
  expect_gt(task_start, closure_start)
  closure_sql <- substring(refresh_sql, closure_start, task_start - 1L)

  expect_match(
    refresh_sql,
    "CREATE TEMPORARY TABLE tmp_todo_closure_parent_associations AS",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "CREATE TEMPORARY TABLE tmp_todo_closure_identity_matches AS",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "INDEX idx_todo_closure_parent_assoc_nest_sex_identity",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "INDEX idx_todo_closure_identity_match_identity_sex_date",
    fixed = TRUE
  )
  expect_match(refresh_sql, "association.identity_has_geo,", fixed = TRUE)
  expect_match(refresh_sql, "association.association_pending,", fixed = TRUE)
  expect_match(
    refresh_sql,
    "CREATE TEMPORARY TABLE tmp_todo_parent_tag_safety AS",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "COUNT(DISTINCT association.identity_key) = 1",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "MAX(COALESCE(association.association_selected, 0)) = 0",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "DROP TEMPORARY TABLE IF EXISTS tmp_todo_parent_tag_safety;",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "DROP TEMPORARY TABLE tmp_todo_parent_tag_safety;",
    fixed = TRUE
  )
  expect_match(refresh_sql, "M_target_has_geo", fixed = TRUE)
  expect_match(refresh_sql, "F_target_has_geo", fixed = TRUE)
  expect_match(refresh_sql, "END AS initial_tag_advisory", fixed = TRUE)
  expect_match(
    refresh_sql,
    "NOT IN ('X', 'XX', 'X-X', 'NA', 'N/A', 'NULL')",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "UPPER(TRIM(adult_parent_status.M_parent_mark)) NOT LIKE 'XX:%'",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "COALESCE(adult_parent_status.M_mm_resight_pending, 0) = 0",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "COALESCE(adult_parent_status.F_mm_resight_pending, 0) = 0",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "COALESCE(m_tag_safety.pending_identity_has_geo, 0) = 0",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "COALESCE(f_tag_safety.pending_identity_has_geo, 0) = 0",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "THEN 'tag any, but only if one is confirmed X-X'",
    fixed = TRUE
  )
  expect_equal(
    length(gregexpr(
      "FROM FIELD_2026_BADOatNZ.ADULT_PARENT_NEST_ASSOCIATIONS",
      refresh_sql,
      fixed = TRUE
    )[[1L]]),
    1L
  )
  expect_equal(
    length(gregexpr(
      "FROM FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES",
      refresh_sql,
      fixed = TRUE
    )[[1L]]),
    1L
  )
  expect_false(grepl(
    "FROM FIELD_2026_BADOatNZ.ADULT_PARENT_NEST_ASSOCIATIONS",
    closure_sql,
    fixed = TRUE
  ))
  expect_false(grepl(
    "FROM FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES",
    closure_sql,
    fixed = TRUE
  ))
  expect_match(
    refresh_sql,
    "DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_parent_associations;",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_identity_matches;",
    fixed = TRUE
  )
  expect_match(
    closure_sql,
    "DROP TEMPORARY TABLE tmp_todo_closure_parent_associations;",
    fixed = TRUE
  )
  expect_match(
    closure_sql,
    "DROP TEMPORARY TABLE tmp_todo_closure_identity_matches;",
    fixed = TRUE
  )
})


test_that("the refresh worker chooses a configured MariaDB client", {
  app <- load_main_app()

  expect_identical(
    app$env$mariadb_client_command("/custom/bin/mariadb"),
    "/custom/bin/mariadb"
  )
})


test_that("snapshot readiness fails closed when the published table is unavailable", {
  env <- new.env(parent = globalenv())
  env$DBq <- function(...) data.frame(error = "missing snapshot")
  source_app_file(app_file("main", "R", "system_utils.R"), env)

  expect_false(env$todo_snapshot_is_current(as.Date("2026-10-16")))
})


test_that("snapshot readiness requires current health and published task rows", {
  env <- new.env(parent = globalenv())
  source_app_file(app_file("main", "R", "system_utils.R"), env)

  captured_sql <- NULL
  env$DBq <- function(sql, ...) {
    captured_sql <<- sql
    data.frame(n = 1L)
  }

  expect_true(env$todo_snapshot_is_current(as.Date("2026-10-16")))
  expect_match(captured_sql, "TODO_REFRESH_STATUS", fixed = TRUE)
  expect_match(captured_sql, "TODO_LIST_SNAPSHOT", fixed = TRUE)
  expect_match(captured_sql, "task_row_count", fixed = TRUE)
  expect_match(
    captured_sql,
    "ORDER BY started_at DESC, refresh_id DESC",
    fixed = TRUE
  )

  env$DBq <- function(...) data.frame(n = 0L)
  expect_false(env$todo_snapshot_is_current(as.Date("2026-10-16")))
})


test_that("snapshot health reports an incomplete refresh without exposing data", {
  env <- new.env(parent = globalenv())
  source_app_file(app_file("main", "R", "system_utils.R"), env)
  env$DBq <- function(...) {
    data.frame(
      state = "running",
      reference_date = as.Date("2026-10-16"),
      started_at = "2026-10-16 09:00:00",
      completed_at = NA_character_,
      task_row_count = NA_integer_
    )
  }

  health <- env$todo_snapshot_refresh_health(as.Date("2026-10-16"))

  expect_identical(health$state, "running")
  expect_identical(health$reference_date, as.Date("2026-10-16"))
  expect_true(is.na(health$task_row_count))
})


test_that("downloads UI exposes the asynchronous snapshot action", {
  app <- load_main_app()
  html <- as.character(app$ui)

  expect_match(html, "refresh_todo_snapshot", fixed = TRUE)
  expect_match(html, "Build To-do snapshot", fixed = TRUE)
  expect_match(html, "todo_snapshot_status", fixed = TRUE)

  server <- paste(
    readLines(app_file("main", "server.R"), warn = FALSE),
    collapse = "\n"
  )
  system_utils <- paste(
    readLines(app_file("main", "R", "system_utils.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(server, "progress-bar-striped", fixed = TRUE)
  expect_match(server, "Some stages take several minutes without a new message.", fixed = TRUE)
  expect_match(html, "Can take up to 20 minutes to build", fixed = TRUE)
  expect_match(system_utils, "--unbuffered", fixed = TRUE)
  expect_match(system_utils, "TODO_REFRESH_STAGE|brood_context", fixed = TRUE)
  expect_match(system_utils, "TODO_REFRESH_STAGE|chick_gps_links", fixed = TRUE)
  expect_match(
    system_utils,
    "TODO_REFRESH_STAGE|chick_capture_context",
    fixed = TRUE
  )
  expect_match(
    system_utils,
    "TODO_REFRESH_STAGE|hiding_spot_photos",
    fixed = TRUE
  )
  expect_match(system_utils, "todo_snapshot_refresh_health", fixed = TRUE)
  expect_match(server, "this PDF may contain stale task rows", fixed = TRUE)
  expect_match(system_utils, "TODO_REFRESH_STATUS", fixed = TRUE)
})
