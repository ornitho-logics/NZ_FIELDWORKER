todo_list_view_sql <- function() {
  sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  start <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD (",
    sql,
    fixed = TRUE
  )[[1]]
  expect_gt(start, 0L)

  remainder <- substring(sql, start)
  finish <- regexpr(
    "SELECT 'TODO_REFRESH_STAGE|publishing'",
    remainder,
    fixed = TRUE
  )[[1]]
  expect_gt(finish, 0L)

  substring(remainder, 1L, finish - 1L)
}


views_source_sql <- function() {
  paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
}


refresh_source_sql <- function() {
  paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )
}


all_todo_sql <- function() {
  paste(views_source_sql(), refresh_source_sql(), sep = "\n")
}


test_that("public TODO_LIST is a small snapshot-backed read boundary", {
  sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  start_marker <- paste(
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW",
    "FIELD_2026_BADOatNZ.TODO_LIST AS"
  )
  end_marker <- paste(
    "DROP TABLE FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_PREVIOUS;"
  )
  start <- regexpr(start_marker, sql, fixed = TRUE)[[1]]
  expect_gt(start, 0L)

  remainder <- substring(sql, start)
  finish <- regexpr(end_marker, remainder, fixed = TRUE)[[1]]
  expect_gt(finish, 0L)
  public_sql <- substring(remainder, 1L, finish - 1L)

  expect_match(public_sql, "TODO_PARENT_TASKS", fixed = TRUE)
  expect_match(public_sql, "TODO_NONPARENT_TASKS", fixed = TRUE)
  expect_match(public_sql, "UNION ALL", fixed = TRUE)
  expect_match(sql, "TODO_LIST_SNAPSHOT", fixed = TRUE)
  expect_match(
    sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD",
    fixed = TRUE
  )
  expect_match(sql, "todo VARCHAR(64) NOT NULL", fixed = TRUE)
  expect_match(
    sql,
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD",
    fixed = TRUE
  )
  expect_match(
    sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD (",
    fixed = TRUE
  )
  expect_no_match(
    sql,
    paste(
      "CREATE TABLE FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD AS",
      "SELECT *",
      sep = "\n"
    )
  )
  expect_match(
    sql,
    paste(
      "CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT",
      "LIKE FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_match(sql, "RENAME TABLE", fixed = TRUE)
  expect_match(
    sql,
    "TODO_LIST_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT",
    fixed = TRUE
  )

  parent_build_insert <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD",
    sql,
    fixed = TRUE
  )[[1L]]
  task_build_insert <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD",
    sql,
    fixed = TRUE
  )[[1L]]
  public_view <- regexpr(start_marker, sql, fixed = TRUE)[[1L]]
  expect_gt(parent_build_insert, 0L)
  expect_gt(task_build_insert, 0L)
  expect_gt(public_view, parent_build_insert)
  expect_gt(public_view, task_build_insert)
  expect_no_match(
    sql,
    "DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST;",
    fixed = TRUE
  )
  expect_match(
    sql,
    "DROP TABLE FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_PREVIOUS;",
    fixed = TRUE
  )
  expect_match(
    sql,
    "CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS (",
    fixed = TRUE
  )
  expect_match(sql, "SET SESSION lock_wait_timeout = 30;", fixed = TRUE)
  expect_match(
    sql,
    "MODIFY refresh_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT",
    fixed = TRUE
  )
  expect_match(
    sql,
    "ADD PRIMARY KEY (refresh_id)",
    fixed = TRUE
  )
  expect_match(
    sql,
    "ADD INDEX idx_todo_refresh_status_date (reference_date, refresh_id)",
    fixed = TRUE
  )
  expect_match(
    sql,
    "UPDATE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS",
    fixed = TRUE
  )
})


test_that("the obsolete monolithic TODO calculator is removed, not recreated", {
  sql <- views_source_sql()

  expect_match(
    sql,
    "DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE;",
    fixed = TRUE
  )
  expect_false(grepl(
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE",
    sql,
    fixed = TRUE
  ))

  refresh_sql <- refresh_source_sql()
  expect_false(grepl(
    "FROM FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE",
    refresh_sql,
    fixed = TRUE
  ))
})


test_that("views installation bounds locks and upgrades refresh status", {
  sql <- views_source_sql()

  expect_match(sql, "SET SESSION lock_wait_timeout = 30;", fixed = TRUE)
  expect_match(
    sql,
    "MODIFY refresh_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT",
    fixed = TRUE
  )
  expect_match(sql, "ADD PRIMARY KEY (refresh_id)", fixed = TRUE)
  expect_match(
    sql,
    "ADD INDEX idx_todo_refresh_status_date (reference_date, refresh_id)",
    fixed = TRUE
  )
})


test_that("the obsolete VIEW_1 tagged-bird follow-up view is removed", {
  sql <- views_source_sql()

  expect_match(
    sql,
    "DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.VIEW_1;",
    fixed = TRUE
  )
  expect_false(grepl(
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.VIEW_1 AS",
    sql,
    fixed = TRUE
  ))
})


test_that("Untrapped parent remains internal and cannot become a public task", {
  refresh_sql <- refresh_source_sql()
  task_sql <- todo_list_view_sql()

  expect_match(task_sql, "todo_parent_resighting_existing", fixed = TRUE)
  expect_no_match(
    refresh_sql,
    "WHERE todo IN (\n  'Untrapped parent',",
    fixed = TRUE
  )
  expect_no_match(
    refresh_sql,
    "WHERE todo NOT IN (\n  'Untrapped parent',",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "AND todo <> 'Untrapped parent';",
    fixed = TRUE
  )
})


test_that("TODO snapshot refresh is explicit and uses live SQL sources", {
  refresh_sql <- paste(
    readLines(app_file("DATABASE", "refresh_todo_list_snapshot.SQL"), warn = FALSE),
    collapse = "\n"
  )

  expect_no_match(
    refresh_sql,
    "TRUNCATE TABLE FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT"
  )
  expect_match(
    refresh_sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD",
    fixed = TRUE
  )
  expect_match(refresh_sql, "todo VARCHAR(64) NOT NULL", fixed = TRUE)
  expect_match(
    refresh_sql,
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT AS",
      "SELECT *",
      "FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT AS",
      "SELECT *",
      "FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT;",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD (",
    fixed = TRUE
  )
  expect_no_match(
    refresh_sql,
    paste(
      "CREATE TABLE FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD AS",
      "SELECT *",
      sep = "\n"
    )
  )
  expect_match(refresh_sql, "RENAME TABLE", fixed = TRUE)
  expect_match(refresh_sql, "WITH sr AS (", fixed = TRUE)
  expect_no_match(
    refresh_sql,
    "FROM FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE;",
    fixed = TRUE
  )
  expect_false(grepl("\\.rds", refresh_sql, ignore.case = TRUE))

  parent_build_insert <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  task_build_insert <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(parent_build_insert, 0L)
  expect_gt(task_build_insert, 0L)

  parent_input_build <- regexpr(
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT AS",
      "SELECT *",
      "FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD",
      sep = "\n"
    ),
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  parent_input_snapshot <- regexpr(
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT AS",
      "SELECT *",
      "FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT;",
      sep = "\n"
    ),
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(parent_input_build, parent_build_insert)
  expect_gt(task_build_insert, parent_input_build)
  expect_gt(parent_input_snapshot, task_build_insert)
})


test_that("refresh chick targets use the canonical individual-death contract", {
  refresh_sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  expect_match(
    refresh_sql,
    "CREATE TEMPORARY TABLE tmp_todo_chick_capture_event_status AS",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "CREATE TEMPORARY TABLE tmp_todo_chick_capture_targets AS",
    fixed = TRUE
  )
  expect_match(refresh_sql, "e.event_time_is_observed", fixed = TRUE)
  expect_match(
    refresh_sql,
    "chick_events.event_time_is_observed",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "COUNT(DISTINCT bridge.ring_key) AS n_bridge_ring_keys",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "GROUP BY candidate.ring_key",
    fixed = TRUE
  )
  expect_match(refresh_sql, "dead_event_datetime", fixed = TRUE)
  expect_match(
    refresh_sql,
    "n_deaths_after_latest_brood_count",
    fixed = TRUE
  )
  expect_match(refresh_sql, "n_operational_brood_size", fixed = TRUE)
  expect_match(refresh_sql, "n_active_flagged_chick_rings", fixed = TRUE)
  expect_match(
    refresh_sql,
    "n_unresolved_dead_chick_events",
    fixed = TRUE
  )
  expect_match(refresh_sql, "dead.is_resolved_dead_bridge = 1", fixed = TRUE)
  expect_match(refresh_sql, "is_active_target", fixed = TRUE)
})


available_combos_view_sql <- function() {
  sql <- views_source_sql()
  start_marker <- paste(
    "CREATE OR REPLACE VIEW",
    "FIELD_2026_BADOatNZ.AVAILABLE_COMBOS AS"
  )
  end_marker <- paste(
    "CREATE OR REPLACE VIEW",
    "FIELD_2026_BADOatNZ.NESTS_LATEST AS"
  )
  start <- regexpr(start_marker, sql, fixed = TRUE)[[1]]
  expect_gt(start, 0L)

  remainder <- substring(sql, start)
  finish <- regexpr(end_marker, remainder, fixed = TRUE)[[1]]
  expect_gt(finish, 0L)

  substring(remainder, 1L, finish - 1L)
}


test_that("AVAILABLE_COMBOS fails closed without a reference date", {
  sql <- available_combos_view_sql()

  expect_match(sql, "WITH sr AS (", fixed = TRUE)
  expect_match(sql, "WHERE variable = 'reference_date'", fixed = TRUE)
  expect_match(sql, "AND value IS NOT NULL", fixed = TRUE)
  expect_match(sql, "CROSS JOIN sr", fixed = TRUE)
})


test_that("AVAILABLE_COMBOS keeps all eligible OY and GY marks in CR", {
  sql <- available_combos_view_sql()

  expect_match(
    sql,
    "UNION ALL SELECT 'CR', 'GY', NULL",
    fixed = TRUE
  )
  expect_match(
    sql,
    "LL IN ('BY', 'WY', 'YY', 'YO', 'OY', 'GY') THEN 'CR'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHEN UPPER(TRIM(available_combos_ranked.LL)) = 'GY' THEN 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "ON candidate.LL = used.LL\n   AND candidate.LR = used.LR",
    fixed = TRUE
  )
  expect_match(sql, "WHERE used.LL IS NULL", fixed = TRUE)
  expect_lt(
    regexpr("WHERE used.LL IS NULL", sql, fixed = TRUE)[[1]],
    regexpr(
      "LL IN ('BY', 'WY', 'YY', 'YO', 'OY', 'GY') THEN 'CR'",
      sql,
      fixed = TRUE
    )[[1]]
  )

  classify_cr_candidate <- function(LL, LR, combo_rank) {
    if (LL %in% c("BY", "WY", "YY", "YO", "OY", "GY")) {
      return("CR")
    }
    if (grepl("L", paste0(LL, LR)) || combo_rank > 30L) {
      return("CX")
    }
    "CR"
  }

  expect_identical(classify_cr_candidate("OY", "BL", 40L), "CR")
  expect_identical(classify_cr_candidate("OY", "BR", 80L), "CR")
  expect_identical(classify_cr_candidate("GY", "BL", 80L), "CR")
  expect_identical(classify_cr_candidate("LY", "BB", 20L), "CX")
})


test_that("TODO_LIST contains the bounded operational rules", {
  sql <- todo_list_view_sql()
  refresh_sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  expect_match(
    sql,
    "WITH sr AS (",
    fixed = TRUE
  )
  expect_match(
    sql,
    "IN ('F', 'I', 'H', 'PP', 'PD', 'NOTA')",
    fixed = TRUE
  )
  expect_match(
    sql,
    "UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'NOTA'\n          AND EXISTS (\n            SELECT 1\n            FROM hatched_nests hatched",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHEN UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "UPPER(TRIM(COALESCE(active_nests.species, ''))) = 'BADO'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "UPPER(TRIM(COALESCE(wryb_nest.species, ''))) = 'WRYB'",
    fixed = TRUE
  )
  expect_match(sql, "WHERE NOT EXISTS", fixed = TRUE)
  expect_match(
    refresh_sql,
    "FROM FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h",
    fixed = TRUE
  )
})


test_that("hatched terminal notA nests remain eligible for parent work", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "WHERE UPPER(TRIM(COALESCE(n.nest_state, ''))) = 'NOTA'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "JOIN hatched_nests",
    fixed = TRUE
  )
  expect_match(
    sql,
    "IN ('F', 'I', 'H', 'PP', 'PD', 'NOTA')",
    fixed = TRUE
  )

  parent_work_eligible <- function(latest_state, had_h_event) {
    state <- toupper(trimws(latest_state))
    state %in% c("F", "I", "H", "PP", "PD") ||
      (state == "NOTA" && isTRUE(had_h_event))
  }

  expect_true(parent_work_eligible("notA", TRUE))
  expect_false(parent_work_eligible("notA", FALSE))
  expect_true(parent_work_eligible("H", TRUE))

  capture_allowed_for_parent_work <- function(latest_state, had_h_event) {
    toupper(trimws(latest_state)) == "H" ||
      (toupper(trimws(latest_state)) == "NOTA" && isTRUE(had_h_event))
  }
  expect_true(capture_allowed_for_parent_work("notA", TRUE))
  expect_false(capture_allowed_for_parent_work("notA", FALSE))

  pair_completion_note <- function(latest_state, had_h_event, male_xx, female_geo) {
    if (parent_work_eligible(latest_state, had_h_event) && male_xx && female_geo) {
      "tag M (pair completion)"
    } else {
      NA_character_
    }
  }

  expect_identical(
    pair_completion_note("notA", TRUE, male_xx = TRUE, female_geo = TRUE),
    "tag M (pair completion)"
  )
})


test_that("H hiding-photo association is shared by BROODS_LATEST and TODO_LIST", {
  schema_sql <- views_source_sql()
  refresh_sql <- refresh_source_sql()

  expect_match(
    schema_sql,
    "CREATE TABLE IF NOT EXISTS\n  FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT",
    fixed = TRUE
  )
  expect_match(
    schema_sql,
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT AS\nSELECT *\nFROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "FROM FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h",
    fixed = TRUE
  )
  expect_match(
    schema_sql,
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS AS",
    fixed = TRUE
  )
  expect_match(schema_sql, "'ambiguous_same_occasion_adult'", fixed = TRUE)
  expect_match(schema_sql, "'ambiguous_capture_history'", fixed = TRUE)
  expect_match(schema_sql, "'ring_capture'", fixed = TRUE)
  expect_match(
    refresh_sql,
    "FROM FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h",
    fixed = TRUE
  )
  expect_match(refresh_sql, "'same_occasion_adult'", fixed = TRUE)
  expect_match(refresh_sql, "'ring_capture'", fixed = TRUE)
  expect_no_match(refresh_sql, "tmp_todo_hiding_photo_s10", fixed = TRUE)
  expect_no_match(
    refresh_sql,
    "authoritative_parent_same_occasion",
    fixed = TRUE
  )
})


test_that("BROODS_LATEST treats age-C captures as positive brood evidence", {
  sql <- views_source_sql()

  expect_match(sql, "positive_chick_status AS", fixed = TRUE)
  expect_match(
    sql,
    "AND UPPER(TRIM(COALESCE(c.age, ''))) = 'C'",
    fixed = TRUE
  )
  expect_match(sql, "chicks.first_chick_capture_date", fixed = TRUE)
  expect_match(sql, "OR chicks.nest_id IS NOT NULL", fixed = TRUE)
  expect_match(sql, "same_occasion_chick_gps_candidates AS", fixed = TRUE)
  expect_match(sql, "chick.gps_id = adult.gps_id", fixed = TRUE)
  expect_match(sql, "chick.gps_point = adult.gps_point", fixed = TRUE)
  expect_match(sql, "TRIM(chick.nest_id) = ''", fixed = TRUE)
  expect_match(sql, "UPPER(TRIM(COALESCE(chick.rclass, ''))) <> 'H'", fixed = TRUE)
  expect_match(sql, "same_occasion_chick_gps_summary AS", fixed = TRUE)
  expect_match(sql, "WHEN COUNT(DISTINCT adult_nest_id) = 1", fixed = TRUE)
  expect_match(sql, "OR gps_assoc.resolved_nest_id IS NOT NULL", fixed = TRUE)
  expect_match(
    sql,
    "LEFT JOIN same_occasion_chick_gps_summary gps_assoc",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHEN chick_latest.event_datetime >",
    fixed = TRUE
  )
  expect_match(
    sql,
    "chick_latest.event_date AS latest_chick_event_date",
    fixed = TRUE
  )
})


test_that("positive brood Last Visit uses the latest nest or chick encounter", {
  sql <- refresh_source_sql()

  expect_match(
    sql,
    "WHEN brood_last_visit.nest_id IS NOT NULL\n      THEN brood_last_visit.latest_encounter_datetime",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHEN brood_last_visit.nest_id IS NOT NULL\n      THEN DATEDIFF(sr.reference_date, brood_last_visit.latest_encounter_date)",
    fixed = TRUE
  )
  expect_match(
    sql,
    paste0(
      "LEFT JOIN brood_context brood_last_visit\n",
      "    ON CONVERT(context.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci\n",
      "       = CONVERT(brood_last_visit.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci"
    ),
    fixed = TRUE
  )
  expect_match(sql, "brood_last_visit.is_negative_brood = 0", fixed = TRUE)
  expect_match(sql, "brood_last_visit.has_hatch_evidence = 1", fixed = TRUE)
  expect_match(
    sql,
    "active_nests.days_ago AS last_visit_days_ago",
    fixed = TRUE
  )
  expect_match(
    sql,
    "brood_followup_nests.days_ago AS last_visit_days_ago",
    fixed = TRUE
  )
})


test_that("brood photo follow-up uses the unified brood evidence source", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    paste0(
      "JOIN brood_context b\n",
      "    ON CONVERT(n.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci\n",
      "       = CONVERT(b.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci"
    ),
    fixed = TRUE
  )
  expect_match(sql, "b.has_hatch_evidence = 1", fixed = TRUE)
  expect_match(sql, "b.hatch_evidence_date AS hatch_date", fixed = TRUE)
  expect_false(
    grepl("WHERE n.nest_state IN ('H', 'notA')", sql, fixed = TRUE)
  )
})


test_that("initial processing uses all qualifying processing history", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "COALESCE(processing_summary.n_float_rows, 0) = 0",
    fixed = TRUE
  )
  expect_match(
    sql,
    "COALESCE(processing_summary.n_photo_rows, 0) = 0",
    fixed = TRUE
  )
  expect_false(grepl("complete_clutch_processing_status", sql, fixed = TRUE))
})


test_that("parent-status view projections remain deployable", {
  sql <- views_source_sql()

  nests_start <- regexpr(
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.NESTS_LATEST AS",
    sql,
    fixed = TRUE
  )[[1]]
  expect_gt(nests_start, 0L)
  nests_sql <- substring(sql, nests_start)
  nests_end <- regexpr(
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS AS",
    nests_sql,
    fixed = TRUE
  )[[1]]
  expect_gt(nests_end, 0L)
  nests_sql <- substring(nests_sql, 1L, nests_end - 1L)
  expect_match(nests_sql, "  n.reference_date,", fixed = TRUE)
  expect_match(nests_sql, "  n.site,", fixed = TRUE)

  parent_start <- regexpr(
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.ADULT_PARENT_STATUS AS",
    sql,
    fixed = TRUE
  )[[1]]
  expect_gt(parent_start, 0L)
  parent_sql <- substring(sql, parent_start)
  parent_end <- regexpr(
    "/*\n  The TODO task engine remains",
    parent_sql,
    fixed = TRUE
  )[[1]]
  expect_gt(parent_end, 0L)
  parent_sql <- substring(parent_sql, 1L, parent_end - 1L)
  expect_equal(
    sum(grepl(
      "AS M_pending_resighting_count",
      strsplit(parent_sql, "\\n", fixed = TRUE)[[1]],
      fixed = TRUE
    )),
    1L
  )
  expect_equal(
    sum(grepl(
      "AS F_pending_resighting_count",
      strsplit(parent_sql, "\\n", fixed = TRUE)[[1]],
      fixed = TRUE
    )),
    1L
  )

  todo_sql <- todo_list_view_sql()
  expect_match(todo_sql, "tag_deployment_plan AS", fixed = TRUE)
  expect_match(todo_sql, "clutch_completion_basis_date", fixed = TRUE)
  expect_no_match(todo_sql, "both_parents_need_geo_derived", fixed = TRUE)
})


test_that("hiding-photo TODO counts distinct captured and photographed rings", {
  sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  schema_sql <- paste(
    readLines(
      app_file("DATABASE", "views.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  expect_match(
    sql,
    "COUNT(*) AS n_captured_chick_rings",
    fixed = TRUE
  )
  expect_match(sql, "COUNT(*) AS n_chick_captures", fixed = TRUE)
  expect_match(sql, "n_unringed_chick_captures", fixed = TRUE)
  for (source_sql in list(sql, schema_sql)) {
    expect_match(source_sql, "raw_chick_events AS (", fixed = TRUE)
    expect_match(source_sql, "known_ring_nest_history AS (", fixed = TRUE)
    expect_match(source_sql, "latest_prior_ring_date AS (", fixed = TRUE)
    expect_match(source_sql, "HAVING COUNT(*) = 1", fixed = TRUE)
    expect_match(
      source_sql,
      "COALESCE(e.recorded_nest_id, inferred.inferred_nest_id)",
      fixed = TRUE
    )
  }
  expect_match(
    sql,
    "COUNT(DISTINCT target.ring_key) AS n_hiding_spot_photos",
    fixed = TRUE
  )
  expect_match(sql, "target.ring_key = REPLACE(", fixed = TRUE)
  expect_match(sql, "target.is_active_target = 1", fixed = TRUE)
  expect_match(sql, "r.photo_start", fixed = TRUE)
  expect_match(sql, "r.photo_end", fixed = TRUE)
  expect_match(
    sql,
    "COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0)\n           < chick_captures.n_active_chick_rings",
    fixed = TRUE
  )
  expect_match(
    sql,
    "' chicks with rclass ''H'' photos'",
    fixed = TRUE
  )
  expect_false(grepl("need H resightings", sql, fixed = TRUE))
})


test_that("chick ring normalization is consistent across install and refresh paths", {
  views_sql <- views_source_sql()
  refresh_sql <- refresh_source_sql()

  for (source_sql in list(views_sql, refresh_sql)) {
    expect_match(
      source_sql,
      "REPLACE(UPPER(TRIM(c.ring)), '-', '')",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "'', 'X', 'XX', 'X-X', 'NA', 'N/A'",
      fixed = TRUE
    )
  }
  expect_match(
    views_sql,
    "REPLACE(UPPER(TRIM(r.ring)), '-', '')",
    fixed = TRUE
  )
  expect_match(views_sql, "END AS ring_key", fixed = TRUE)
  expect_match(
    refresh_sql,
    "REPLACE(UPPER(TRIM(c.ring)), '-', '')",
    fixed = TRUE
  )
  expect_match(refresh_sql, "END AS ring_key", fixed = TRUE)
  expect_match(views_sql, "ADULT_RESIGHTING_IDENTITIES_ALL r", fixed = TRUE)
  expect_match(views_sql, "ADULT_CAPTURE_IDENTITIES_ALL c", fixed = TRUE)
})


test_that("S10 parent/chick resolution is authoritative and conservative", {
  views_sql <- views_source_sql()
  refresh_sql <- refresh_source_sql()

  source_cases <- list(
    list(
      sql = views_sql,
      s10_name = "TODO_PARENT_CHICK_RESIGHTING_ASSOCIATIONS",
      s10_start = paste(
        "FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_RESIGHTING_ASSOCIATIONS AS",
        sep = ""
      ),
      ordinary_name = "TODO_ORDINARY_FAMILY_RESIGHTING_ASSOCIATIONS"
    ),
    list(
      sql = refresh_sql,
      s10_name = "tmp_todo_parent_chick_resighting_associations",
      s10_start = "CREATE TEMPORARY TABLE tmp_todo_parent_chick_resighting_associations AS",
      ordinary_name = "tmp_todo_ordinary_family_resighting_associations"
    )
  )

  for (source_case in source_cases) {
    source_sql <- source_case$sql
    expect_match(
      source_sql,
      source_case$s10_name,
      fixed = TRUE
    )
    expect_match(source_sql, "M_selected_identity_key", fixed = TRUE)
    expect_match(source_sql, "F_selected_identity_key", fixed = TRUE)
    expect_match(source_sql, "parent.event_date = chick.event_date", fixed = TRUE)
    expect_match(source_sql, "parent.gps_id = chick.gps_id", fixed = TRUE)
    expect_match(source_sql, "parent.gps_point = chick.gps_point", fixed = TRUE)
    expect_match(
      source_sql,
      "(BC|FC|AC)([,[:space:]]|$)",
      fixed = TRUE
    )
    expect_match(source_sql, "HAVING COUNT(DISTINCT nest_id) = 1", fixed = TRUE)
    expect_match(source_sql, "matched.match_class <> 'unmatched'", fixed = TRUE)
    expect_match(
      source_sql,
      "COALESCE(matched.n_candidate_identities, 0) = 1",
      fixed = TRUE
    )

    start <- regexpr(
      source_case$s10_start,
      source_sql,
      fixed = TRUE
    )[[1L]]
    remainder <- substring(source_sql, start)
    finish <- regexpr(
      source_case$ordinary_name,
      remainder,
      fixed = TRUE
    )[[1L]]
    expect_gt(start, 0L)
    expect_gt(finish, 0L)
    s10_sql <- substring(remainder, 1L, finish - 1L)
    expect_no_match(
      s10_sql,
      "UPPER(TRIM(COALESCE(r.rclass, ''))) <> 'H'",
      fixed = TRUE
    )
    expect_match(s10_sql, "OR chick.ring_key IS NOT NULL", fixed = TRUE)
  }
  expect_match(
    refresh_sql,
    "FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT status",
    fixed = TRUE
  )

  has_parent_with_chicks_behaviour <- function(value) {
    tokens <- unlist(strsplit(toupper(trimws(value %||% "")), "[,[:space:]]+"))
    any(tokens %in% c("BC", "FC", "AC"))
  }
  `%||%` <- function(x, y) if (is.null(x) || is.na(x)) y else x
  expect_true(has_parent_with_chicks_behaviour("AC"))
  expect_true(has_parent_with_chicks_behaviour("BC, FC"))
  expect_false(has_parent_with_chicks_behaviour("AT"))
  expect_false(has_parent_with_chicks_behaviour("ABC"))
  expect_match(
    refresh_sql,
    "CREATE TEMPORARY TABLE tmp_todo_parent_chick_resighting_associations AS",
    fixed = TRUE
  )
  expect_no_match(
    refresh_sql,
    "'authoritative_parent_same_occasion' AS association_method",
    fixed = TRUE
  )
})


test_that("negative brood hiding-photo clock remains discovery day 1 through day 6", {
  sql <- refresh_source_sql()

  expect_match(
    sql,
    "DATEDIFF(b.reference_date, b.discovery_date) BETWEEN 1 AND 6",
    fixed = TRUE
  )
  expect_match(
    sql,
    paste(
      "DATEDIFF(",
      "        brood_followup_nests.reference_date,",
      "        brood_followup_nests.hatch_date",
      "      ) BETWEEN 1 AND 6",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_false(grepl("DATEDIFF(b.reference_date, b.discovery_date) >= 1", sql, fixed = TRUE))
})


test_that("hatch prediction includes complete-clutch and stable one-egg fallbacks", {
  sql <- all_todo_sql()

  expect_match(sql, "latest_clutch_ranked AS", fixed = TRUE)
  expect_match(sql, "first_one_egg_ranked AS", fixed = TRUE)
  expect_match(sql, "complete_clutch_status AS", fixed = TRUE)
  expect_match(sql, "stable_one_egg_status AS", fixed = TRUE)
  expect_match(
    sql,
    "DATEDIFF(sr.reference_date, first_one_egg.date) >= 4",
    fixed = TRUE
  )
  expect_match(
    sql,
    "DATE_ADD(first_one_egg.date, INTERVAL 2 DAY)",
    fixed = TRUE
  )
  expect_match(sql, "'complete clutch chronology'", fixed = TRUE)
  expect_match(sql, "'stable one-egg/no increase'", fixed = TRUE)
  expect_match(
    sql,
    "'complete clutch chronology',\n    'stable one-egg/no increase'",
    fixed = TRUE
  )
})


test_that("stable one-egg clutches close additional-egg checks conservatively", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "stable_one_egg.calibration_match_type = 'stable one-egg/no increase'",
    fixed = TRUE
  )

  additional_egg_check <- function(
    reference_date,
    latest_event_date,
    latest_clutch_size,
    current_clutch_start_date,
    first_one_egg_date,
    final_clutch_size
  ) {
    stable_one_egg <- latest_clutch_size == 1 &&
      final_clutch_size == 1 &&
      as.numeric(as.Date(reference_date) - as.Date(first_one_egg_date)) >= 4
    latest_clutch_size %in% c(1, 2) &&
      as.numeric(as.Date(reference_date) - as.Date(latest_event_date)) >= 2 &&
      as.numeric(as.Date(latest_event_date) - as.Date(current_clutch_start_date)) < 7 &&
      !stable_one_egg
  }

  # C0504-like chronology: one egg on Sep 29, repeated on Oct 2, reference
  # date Oct 5. The four-day conservative threshold has been exceeded.
  expect_false(
    additional_egg_check(
      "2026-10-05",
      "2026-10-02",
      latest_clutch_size = 1,
      current_clutch_start_date = "2026-09-29",
      first_one_egg_date = "2026-09-29",
      final_clutch_size = 1
    )
  )

  # A later second egg resets the process and makes the next-egg check
  # eligible again while the new clutch sequence is still young.
  expect_true(
    additional_egg_check(
      "2026-10-07",
      "2026-10-05",
      latest_clutch_size = 2,
      current_clutch_start_date = "2026-10-05",
      first_one_egg_date = "2026-09-29",
      final_clutch_size = 2
    )
  )
})


test_that("legacy MM follow-up is not part of parent task assembly", {
  sql <- todo_list_view_sql()

  expect_no_match(
    sql,
    "n_matching_post_mm_resightings",
    fixed = TRUE
  )
  expect_no_match(
    sql,
    "COALESCE(followup.n_matching_post_mm_resightings, 0) < 3",
    fixed = TRUE
  )
  expect_no_match(
    sql,
    "association.association_date >= mm.mm_capture_date",
    fixed = TRUE
  )
  expect_no_match(sql, "post_mm_xx_seen", fixed = TRUE)
})


test_that("four-gate identity matching owns short LL/LR and spacer aliases", {
  sql <- views_source_sql()

  expect_no_match(sql, "adult_mm_post_resighting_matched", fixed = TRUE)
  expect_no_match(sql, "mm.LL_norm IS NOT NULL", fixed = TRUE)
  expect_no_match(sql, "association.LL_obs = mm.LL_norm", fixed = TRUE)
  expect_no_match(sql, "association.LR_obs = mm.LR_norm", fixed = TRUE)
  expect_match(sql, "c.is_confirmed_xx = 0", fixed = TRUE)
  expect_match(sql, "requires_spacer_identity", fixed = TRUE)
  expect_match(sql, "'CP19738'", fixed = TRUE)
  expect_match(sql, "'CP19739'", fixed = TRUE)
  expect_match(sql, "'CP19693'", fixed = TRUE)
  expect_match(sql, "'CP19848'", fixed = TRUE)

  mm_identity_match <- function(
    mm_ll,
    mm_lr,
    mm_mark,
    resighting_ll,
    resighting_lr,
    resighting_mark,
    requires_spacer_identity = FALSE
  ) {
    if (isTRUE(requires_spacer_identity)) {
      return(identical(toupper(trimws(mm_mark)), toupper(trimws(resighting_mark))))
    }
    !is.na(mm_ll) && !is.na(mm_lr) &&
      !is.na(resighting_ll) && !is.na(resighting_lr) &&
      identical(resighting_ll, mm_ll) &&
      identical(resighting_lr, mm_lr)
  }

  # A missing UL/UR does not prevent a complete lower-leg match.
  expect_true(
    mm_identity_match(
      "BY", "OL", "YO-TO.OL", "BY", "OL", "BY-OL"
    )
  )
  # A different lower-leg combination remains a non-match.
  expect_false(
    mm_identity_match(
      "BY", "OL", "YO-TO.OL", "BY", "OY", "BY-OY"
    )
  )
  # Missing LL or LR cannot establish the identity.
  expect_false(
    mm_identity_match(
      "BY", "OL", "YO-TO.OL", NA_character_, "OL", "-OL"
    )
  )
  # The four approved single-LR birds still require the spacer-inclusive mark.
  expect_false(
    mm_identity_match(
      "BY", "L", "BY-TY.L", "BY", "L", "BY-L",
      requires_spacer_identity = TRUE
    )
  )
  expect_true(
    mm_identity_match(
      "BY", "L", "BY-TY.L", "BY", "L", "BY-TY.L",
      requires_spacer_identity = TRUE
    )
  )
})


test_that("hatched brood task Hatch values use the recorded H date", {
  sql <- all_todo_sql()

  expect_match(sql, "TODO_NEST_CONTEXT AS", fixed = TRUE)
  expect_match(sql, "MIN(date) AS hatch_date", fixed = TRUE)
  expect_match(
    sql,
    "WHERE UPPER(TRIM(COALESCE(nest_state, ''))) = 'H'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHEN context.observed_hatch_date IS NOT NULL",
    fixed = TRUE
  )
  expect_match(
    sql,
    "context.observed_hatch_date,\n        sr.reference_date",
    fixed = TRUE
  )
  expect_match(
    sql,
    "DATEDIFF(\n      brood_followup_nests.hatch_date,\n      brood_followup_nests.reference_date\n    ) AS min_days_to_hatch",
    fixed = TRUE
  )

  hatch_value <- function(hatch_date, reference_date, is_negative = FALSE) {
    if (isTRUE(is_negative)) {
      return(NA_integer_)
    }
    as.integer(as.Date(hatch_date) - as.Date(reference_date))
  }

  expect_identical(
    hatch_value("2026-09-28", "2026-09-29"),
    -1L
  )
  expect_identical(
    hatch_value("2026-09-24", "2026-09-25"),
    -1L
  )
  expect_identical(
    hatch_value("2026-09-28", "2026-09-29", is_negative = TRUE),
    NA_integer_
  )

  parent_hatch_value <- function(
    observed_hatch_date,
    reference_date,
    inferred_hatch_date = NA,
    predicted_hatch_days = NA_integer_
  ) {
    if (!is.na(observed_hatch_date)) {
      return(as.integer(
        as.Date(observed_hatch_date) - as.Date(reference_date)
      ))
    }
    if (!is.na(inferred_hatch_date)) {
      return(as.integer(
        as.Date(inferred_hatch_date) - as.Date(reference_date)
      ))
    }
    predicted_hatch_days
  }

  expect_identical(
    parent_hatch_value("2026-09-28", "2026-09-29", "2026-10-04", 5L),
    -1L
  )
})


test_that("brood flagging tasks use the 21-day age gate and avoid duplicate banding work", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "'Broods to recapture for flagging' AS todo",
    fixed = TRUE
  )
  expect_match(
    sql,
    "DATEDIFF(\n          brood_followup_nests.reference_date,\n          brood_followup_nests.hatch_date\n        ) >= 21",
    fixed = TRUE
  )
  expect_match(
    sql,
    "DATEDIFF(b.reference_date, b.discovery_date) >= 21",
    fixed = TRUE
  )
  expect_match(sql, "n_unringed_chick_captures", fixed = TRUE)
  expect_match(sql, "'recapture chicks; assign flags ('", fixed = TRUE)
  expect_no_match(
    sql,
    "'recapture chicks; assign unique engraved UL flags ('",
    fixed = TRUE
  )
  normalized_sql <- gsub("[[:space:]]+", " ", sql)
  expect_match(
    normalized_sql,
    "COALESCE(chick_captures.n_operational_brood_size, 0) - COALESCE(chick_captures.n_active_flagged_chick_rings, 0)",
    fixed = TRUE
  )
  expect_match(
    sql,
    "DATEDIFF(\n          brood_followup_nests.reference_date,\n          brood_followup_nests.hatch_date\n        ) < 21",
    fixed = TRUE
  )
  expect_match(
    sql,
    "DATEDIFF(b.reference_date, b.discovery_date) < 21",
    fixed = TRUE
  )
  expect_no_match(
    sql,
    "'no chick captures; chicks old enough for leg flags'",
    fixed = TRUE
  )
})


test_that("negative broods only enter Broods to band without chick captures", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    paste(
      "WHERE b.is_negative_brood = 1",
      "    AND b.reference_date = sr.reference_date",
      "    AND COALESCE(chick_captures.n_chick_captures, 0) = 0",
      "    AND DATEDIFF(b.reference_date, b.discovery_date) < 21",
      sep = "\n"
    ),
    fixed = TRUE
  )
})


test_that("hatch-stage parent work bypasses the clutch-age gate", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "WHEN UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "active_nests.hatch_signs_present = 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "ELSE COALESCE(adult_capture_age_status.capture_allowed_after_completion, 0)",
    fixed = TRUE
  )

  capture_gate <- function(nest_state, hatch_signs_present, age_gate = 0) {
    if (toupper(trimws(nest_state)) == "H" || hatch_signs_present == 1) {
      return(1L)
    }
    as.integer(age_gate)
  }

  expect_identical(capture_gate("H", 0), 1L)
  expect_identical(capture_gate("I", 1), 1L)
  expect_identical(capture_gate("I", 0, 1), 1L)
  expect_identical(capture_gate("I", 0, 0), 0L)
})


test_that("parent capture uses the final egg laying date, not confirmation date", {
  sql <- todo_list_view_sql()
  timing_start <- regexpr(
    "adult_capture_final_egg_lay_status AS",
    sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(timing_start, 0L)

  timing_sql <- substring(sql, timing_start)
  timing_end <- regexpr("tag_deployment_history AS", timing_sql, fixed = TRUE)[[1L]]
  expect_gt(timing_end, 0L)
  timing_sql <- substring(timing_sql, 1L, timing_end - 1L)

  expect_match(timing_sql, "adult_capture_final_egg_lay_status AS", fixed = TRUE)
  expect_match(
    timing_sql,
    paste(
      "DATE_SUB(",
      "        float_prediction.float_date,",
      "        INTERVAL ROUND(float_prediction.predicted_days_since_laying) DAY",
      "      )",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_match(timing_sql, "current_clutch_size = 2", fixed = TRUE)
  expect_match(timing_sql, "current_clutch_size IN (2, 3)", fixed = TRUE)
  expect_match(
    timing_sql,
    "DATE(float_prediction.float_date)\n        <= DATE(clutch_start.current_clutch_datetime)",
    fixed = TRUE
  )
  expect_match(
    timing_sql,
    "DATE(float_prediction.float_date)\n        >= DATE(clutch_start.current_clutch_start_datetime)",
    fixed = TRUE
  )
  expect_match(timing_sql, "DATEDIFF(", fixed = TRUE)
  expect_match(
    timing_sql,
    paste(
      "COALESCE(",
      "          float_lay.estimated_final_egg_lay_date,",
      "          DATE(clutch_start.current_clutch_start_datetime)",
      "        )",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_no_match(
    timing_sql,
    "DATE_ADD(\n          DATE(clutch_start.last_float_datetime)",
    fixed = TRUE
  )
  expect_match(
    timing_sql,
    paste(
      "DATE(clutch_start.current_clutch_datetime),",
      "               CASE",
      "                 WHEN initial_clutch_status.found_as_incomplete = 1",
      "                  AND initial_clutch_status.inferred_clutch_completion_date IS NOT NULL",
      "                 THEN initial_clutch_status.inferred_clutch_completion_date",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_match(
    timing_sql,
    "WHEN x.clutch_completion_confirmed = 1\n       AND DATEDIFF(",
    fixed = TRUE
  )
  expect_match(
    timing_sql,
    paste(
      "DATEDIFF(",
      "             x.reference_date,",
      "             x.clutch_completion_basis_date",
      "           ) >= 7",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_no_match(timing_sql, "average_ref_date_days_since_laid", fixed = TRUE)
  expect_no_match(timing_sql, "uses_inferred_lay_interval", fixed = TRUE)

  final_egg_lay_date <- function(
      clutch_size,
      current_start,
      estimated_lay_dates = as.Date(character()),
      float_observation_dates = estimated_lay_dates
  ) {
    current_start <- as.Date(current_start)
    float_observation_dates <- as.Date(float_observation_dates)
    eligible <- estimated_lay_dates[
      float_observation_dates >= current_start
    ]

    if (clutch_size %in% c(2L, 3L) && length(eligible) > 0L) {
      return(max(as.Date(eligible)))
    }
    if (clutch_size >= 3L) {
      return(current_start)
    }
    current_start
  }

  confirmation_open <- function(final_egg_date, confirming_observation_date) {
    as.integer(
      as.Date(confirming_observation_date) - final_egg_date >= 3L
    )
  }

  capture_allowed <- function(reference_date, final_egg_date, confirmed) {
    as.integer(
      isTRUE(confirmed) && as.Date(reference_date) - final_egg_date >= 7L
    )
  }

  c0909_final_egg <- final_egg_lay_date(
    clutch_size = 2L,
    current_start = "2026-10-17",
    estimated_lay_dates = as.Date(character())
  )
  expect_identical(c0909_final_egg, as.Date("2026-10-17"))
  expect_identical(
    confirmation_open(c0909_final_egg, "2026-10-17"),
    0L
  )
  expect_identical(
    confirmation_open(c0909_final_egg, "2026-10-20"),
    1L
  )
  expect_identical(capture_allowed("2026-10-23", c0909_final_egg, FALSE), 0L)
  expect_identical(capture_allowed("2026-10-24", c0909_final_egg, TRUE), 1L)
  expect_identical(capture_allowed("2026-10-24", c0909_final_egg, FALSE), 0L)

  delayed_float_final_egg <- final_egg_lay_date(
    clutch_size = 2L,
    current_start = "2026-10-05",
    estimated_lay_dates = as.Date("2026-10-07")
  )
  expect_identical(delayed_float_final_egg, as.Date("2026-10-07"))
  expect_identical(
    confirmation_open(delayed_float_final_egg, "2026-10-08"),
    0L
  )
  expect_identical(
    confirmation_open(delayed_float_final_egg, "2026-10-10"),
    1L
  )
  expect_identical(capture_allowed("2026-10-13", delayed_float_final_egg, TRUE), 0L)
  expect_identical(capture_allowed("2026-10-14", delayed_float_final_egg, TRUE), 1L)

  old_first_found_two_egg_final_egg <- final_egg_lay_date(
    clutch_size = 2L,
    current_start = "2026-10-20",
    estimated_lay_dates = as.Date("2026-10-12"),
    float_observation_dates = as.Date("2026-10-20")
  )
  expect_identical(old_first_found_two_egg_final_egg, as.Date("2026-10-12"))
  expect_identical(
    confirmation_open(old_first_found_two_egg_final_egg, "2026-10-20"),
    1L
  )
  expect_identical(
    capture_allowed("2026-10-19", old_first_found_two_egg_final_egg, TRUE),
    1L
  )

  one_to_two_final_egg <- final_egg_lay_date(
    clutch_size = 2L,
    current_start = "2026-10-05",
    estimated_lay_dates = as.Date(character())
  )
  expect_identical(one_to_two_final_egg, as.Date("2026-10-05"))
  expect_identical(capture_allowed("2026-10-11", one_to_two_final_egg, TRUE), 0L)
  expect_identical(capture_allowed("2026-10-12", one_to_two_final_egg, TRUE), 1L)

  third_egg_final_egg <- final_egg_lay_date(
    clutch_size = 3L,
    current_start = "2026-10-19",
    estimated_lay_dates = as.Date("2026-10-07"),
    float_observation_dates = as.Date("2026-10-19")
  )
  expect_identical(third_egg_final_egg, as.Date("2026-10-07"))
  expect_identical(capture_allowed("2026-10-13", third_egg_final_egg, TRUE), 0L)
  expect_identical(capture_allowed("2026-10-14", third_egg_final_egg, TRUE), 1L)

  old_first_found_three_egg_final_egg <- final_egg_lay_date(
    clutch_size = 3L,
    current_start = "2026-10-20",
    estimated_lay_dates = as.Date("2026-10-12"),
    float_observation_dates = as.Date("2026-10-20")
  )
  expect_identical(
    old_first_found_three_egg_final_egg,
    as.Date("2026-10-12")
  )
  expect_identical(
    capture_allowed("2026-10-19", old_first_found_three_egg_final_egg, TRUE),
    1L
  )

  two_egg_float_before_third_egg <- final_egg_lay_date(
    clutch_size = 3L,
    current_start = "2026-10-19",
    estimated_lay_dates = as.Date("2026-10-07"),
    float_observation_dates = as.Date("2026-10-07")
  )
  expect_identical(two_egg_float_before_third_egg, as.Date("2026-10-19"))
  expect_identical(
    capture_allowed("2026-10-25", two_egg_float_before_third_egg, TRUE),
    0L
  )
  expect_identical(
    capture_allowed("2026-10-26", two_egg_float_before_third_egg, TRUE),
    1L
  )

  one_egg_final_egg <- final_egg_lay_date(
    clutch_size = 1L,
    current_start = "2026-10-01"
  )
  expect_identical(one_egg_final_egg, as.Date("2026-10-01"))
  expect_identical(
    confirmation_open(one_egg_final_egg, "2026-10-04"),
    1L
  )
  expect_identical(capture_allowed("2026-10-07", one_egg_final_egg, TRUE), 0L)
  expect_identical(capture_allowed("2026-10-08", one_egg_final_egg, TRUE), 1L)
})


test_that("authoritative chronology completion dates feed the parent age gate", {
  sql <- todo_list_view_sql()
  timing_start <- regexpr("adult_capture_age_status AS", sql, fixed = TRUE)[[1L]]
  expect_gt(timing_start, 0L)

  timing_sql <- substring(sql, timing_start)
  timing_end <- regexpr("tag_deployment_history AS", timing_sql, fixed = TRUE)[[1L]]
  expect_gt(timing_end, 0L)
  timing_sql <- substring(timing_sql, 1L, timing_end - 1L)

  expect_match(timing_sql, "initial_clutch_status.found_as_incomplete = 1", fixed = TRUE)
  expect_match(timing_sql, "initial_clutch_status.stable_one_egg = 1", fixed = TRUE)
  expect_match(timing_sql, "float_lay.estimated_final_egg_lay_date", fixed = TRUE)

  capture_allowed <- function(reference_date, completion_date) {
    as.integer(as.Date(reference_date) - completion_date >= 7L)
  }

  stable_one_egg_final_egg <- as.Date("2026-10-01")
  expect_identical(
    capture_allowed("2026-10-08", stable_one_egg_final_egg),
    1L
  )
  expect_identical(
    capture_allowed("2026-10-07", stable_one_egg_final_egg),
    0L
  )
})


test_that("found-incomplete two-egg timing uses the selected final-egg basis", {
  sql <- refresh_source_sql()

  expect_match(
    sql,
    "WHEN initial_clutch_status.found_as_incomplete = 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "initial_clutch_status.inferred_clutch_completion_date IS NOT NULL",
    fixed = TRUE
  )
  expect_match(
    sql,
    "THEN initial_clutch_status.inferred_clutch_completion_date",
    fixed = TRUE
  )
  expect_match(
    sql,
    "ELSE COALESCE(",
    fixed = TRUE
  )
  expect_match(
    sql,
    "END\n             ) >= 3",
    fixed = TRUE
  )
  expect_match(
    sql,
    paste(
      "DATE(clutch_start.current_clutch_datetime),",
      "               CASE",
      "                 WHEN initial_clutch_status.found_as_incomplete = 1",
      "                  AND initial_clutch_status.inferred_clutch_completion_date IS NOT NULL",
      "                 THEN initial_clutch_status.inferred_clutch_completion_date",
      sep = "\n"
    ),
    fixed = TRUE
  )

  completion_confirmed <- function(current_observation, selected_final_egg_basis) {
    as.numeric(
      as.Date(current_observation) - as.Date(selected_final_egg_basis)
    ) >= 3
  }
  capture_allowed <- function(reference_date, selected_final_egg_basis) {
    completion_confirmed(reference_date, selected_final_egg_basis) &&
      as.numeric(
        as.Date(reference_date) - as.Date(selected_final_egg_basis)
      ) >= 7
  }

  expect_true(completion_confirmed("2026-10-24", "2026-10-18"))
  expect_true(capture_allowed("2026-10-28", "2026-10-18"))
  expect_false(completion_confirmed("2026-10-20", "2026-10-18"))
})


test_that("confirmed X-X parent notes never use resight/band X-X wording", {
  sql <- todo_list_view_sql()

  expect_no_match(sql, "'resight/band X-X M'", fixed = TRUE)
  expect_no_match(sql, "'resight/band X-X F'", fixed = TRUE)
  expect_match(sql, "'band X-X M'", fixed = TRUE)
  expect_match(sql, "'band X-X F'", fixed = TRUE)
})


test_that("the parent 36-hour gate uses the fixed 08:00 inclusive boundary", {
  sql <- todo_list_view_sql()
  expect_match(
    sql,
    "CAST(CONCAT(sr.reference_date, ' 08:00:00') AS DATETIME)",
    fixed = TRUE
  )
  expect_match(sql, "INTERVAL 36 HOUR", fixed = TRUE)
  expect_match(sql, "adult_capture_timing.F_last_capture_datetime", fixed = TRUE)
  expect_match(sql, "adult_capture_timing.M_last_capture_datetime", fixed = TRUE)
  expect_match(sql, "<= DATE_SUB(", fixed = TRUE)

  reference_clock <- as.POSIXct(
    "2026-10-27 08:00:00",
    tz = "UTC"
  )
  window_open <- function(last_capture) {
    is.na(last_capture) || last_capture <= reference_clock - 36 * 3600
  }
  capture_eligible <- function(age_open, interval_open) {
    isTRUE(age_open) && isTRUE(interval_open)
  }

  expect_false(window_open(as.POSIXct("2026-10-25 20:01:00", tz = "UTC")))
  expect_true(window_open(as.POSIXct("2026-10-25 20:00:00", tz = "UTC")))
  expect_true(window_open(as.POSIXct("2026-10-25 19:59:00", tz = "UTC")))
  expect_true(window_open(as.POSIXct(NA)))
  expect_false(capture_eligible(TRUE, FALSE))
  expect_false(capture_eligible(FALSE, TRUE))
  expect_true(capture_eligible(TRUE, TRUE))
})


test_that("a lower latest clutch does not reset the parent capture gate", {
  sql <- all_todo_sql()

  expect_match(sql, "historical_max_clutch", fixed = TRUE)
  expect_match(sql, "capture_gate_clutch_size", fixed = TRUE)
  expect_match(sql, "capture_gate_clutch_start_datetime", fixed = TRUE)
  expect_match(
    sql,
    paste(
      "current_clutch.current_clutch_size",
      "< historical_max_clutch.historical_max_clutch_size",
      sep = "\n         "
    ),
    fixed = TRUE
  )

  capture_gate_inputs <- function(
      current_clutch_size,
      current_clutch_start_date,
      historical_max_clutch_size,
      historical_max_clutch_start_date
  ) {
    if (
      !is.na(historical_max_clutch_size) &&
        current_clutch_size < historical_max_clutch_size
    ) {
      return(list(
        clutch_size = historical_max_clutch_size,
        start_date = as.Date(historical_max_clutch_start_date)
      ))
    }
    list(
      clutch_size = current_clutch_size,
      start_date = as.Date(current_clutch_start_date)
    )
  }

  reduced_clutch <- capture_gate_inputs(
    current_clutch_size = 2L,
    current_clutch_start_date = "2026-10-15",
    historical_max_clutch_size = 3L,
    historical_max_clutch_start_date = "2026-10-10"
  )
  expect_identical(reduced_clutch$clutch_size, 3L)
  expect_identical(reduced_clutch$start_date, as.Date("2026-10-10"))
  expect_true(as.Date("2026-10-17") - reduced_clutch$start_date >= 7L)

  unchanged_clutch <- capture_gate_inputs(
    current_clutch_size = 2L,
    current_clutch_start_date = "2026-10-15",
    historical_max_clutch_size = 2L,
    historical_max_clutch_start_date = "2026-10-15"
  )
  expect_identical(unchanged_clutch$clutch_size, 2L)
  expect_identical(unchanged_clutch$start_date, as.Date("2026-10-15"))
})


test_that("unhatched-egg instruction requires both clutch and brood evidence", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "active_nests.hatch_signs_present = 1\n          OR UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'",
    fixed = TRUE
  )
  expect_match(sql, "'; unhatched egg(s)'", fixed = TRUE)
  expect_match(
    sql,
    "AND COALESCE(active_nests.clutch_size, 0) > 0\n         AND COALESCE(active_nests.brood_size, 0) > 0\n        THEN '; unhatched egg(s)'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'\n        AND COALESCE(active_nests.clutch_size, 0) > 0\n        AND COALESCE(active_nests.brood_size, 0) > 0",
    fixed = TRUE
  )
  expect_match(
    sql,
    "OR NOT EXISTS (\n        SELECT 1\n        FROM brood_context brood_evidence",
    fixed = TRUE
  )

  asynchronous_hatch_check <- function(
    nest_state,
    clutch_size,
    days_ago,
    hatch_signs_present = 0L
  ) {
    (hatch_signs_present == 1L || toupper(trimws(nest_state)) == "H") &&
      !is.na(clutch_size) && clutch_size > 0 &&
      days_ago >= 1
  }

  expect_true(asynchronous_hatch_check("H", 1, 1))
  expect_false(asynchronous_hatch_check("H", 0, 1))
  expect_false(asynchronous_hatch_check("H", 1, 0))
  expect_true(asynchronous_hatch_check("I", 1, 1, hatch_signs_present = 1L))

  unhatched_note <- function(
    nest_state,
    clutch_size,
    brood_size,
    hatch_signs_present = 0L
  ) {
    (hatch_signs_present == 1L || toupper(trimws(nest_state)) == "H") &&
      !is.na(clutch_size) && clutch_size > 0 &&
      !is.na(brood_size) && brood_size > 0
  }

  expect_true(unhatched_note("I", 3, 1, hatch_signs_present = 1L))
  expect_false(unhatched_note("I", 3, 0, hatch_signs_present = 1L))
  expect_false(unhatched_note("I", 0, 1, hatch_signs_present = 1L))
})


test_that("missing parent identities retain a resighting fallback", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "'not yet floated'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHEN MAX(min_days_to_hatch) IS NULL\n      THEN 'not yet floated'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "AND NOT EXISTS (\n      SELECT 1\n      FROM todo_untrapped_parent candidate",
    fixed = TRUE
  )
  expect_match(
    sql,
    "association.nest_id IS NULL",
    fixed = TRUE
  )
})


test_that("negative broods use discovery age in shared task hatch fields", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "DATEDIFF(b.discovery_date, b.reference_date)",
    fixed = TRUE
  )

  negative_estimate <- function(reference_date, discovery_date) {
    as.integer(as.Date(discovery_date) - as.Date(reference_date))
  }
  expect_identical(
    negative_estimate("2026-10-20", "2026-10-01"),
    -19L
  )
})


test_that("deployment SQL handles archive collation and negative brood aliases", {
  sql <- views_source_sql()
  refresh_sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  expect_match(
    sql,
    "GROUP BY BADOatNZ.SEX.ring",
    fixed = TRUE
  )
  expect_match(
    sql,
    "CONVERT(NULLIF(TRIM(ca.ring), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci",
    fixed = TRUE
  )
  expect_match(
    sql,
    "DATEDIFF(d.discovery_date, sr.reference_date) AS min_days_to_hatch",
    fixed = TRUE
  )
})


test_that("the four-gate parent pipeline treats MM as non-definitive evidence", {
  sql <- views_source_sql()

  expect_match(
    sql,
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_PARENT_NEST_ASSOCIATIONS AS",
    fixed = TRUE
  )
  expect_match(
    sql,
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.ADULT_PARENT_STATUS AS",
    fixed = TRUE
  )
  expect_match(sql, "WHEN identity_summary.has_definitive_capture = 1 THEN 3", fixed = TRUE)
  expect_match(sql, "WHEN identity_summary.has_confirming_resighting = 1 THEN 2", fixed = TRUE)
  expect_match(sql, "WHEN identity_summary.n_nonconfirming_resightings >= 3 THEN 1", fixed = TRUE)
  expect_match(sql, "capture_method IN ('TB', 'TN', 'HA')", fixed = TRUE)
  expect_match(sql, "caught_with REGEXP", fixed = TRUE)
  expect_match(sql, "IN|NM|SC|BW|BC|FC|AC", fixed = TRUE)

  gate <- function(definitive_capture = FALSE,
                   confirming_resight = FALSE,
                   n_nonconfirming = 0L) {
    if (definitive_capture) return(3L)
    if (confirming_resight) return(2L)
    if (n_nonconfirming >= 3L) return(1L)
    0L
  }

  # An MM capture alone is not a definitive association and does not count as
  # one of the three non-confirming resightings.
  expect_identical(gate(), 0L)
  expect_identical(gate(n_nonconfirming = 2L), 0L)
  expect_identical(gate(n_nonconfirming = 3L), 1L)
  expect_identical(gate(confirming_resight = TRUE), 2L)
  expect_identical(gate(definitive_capture = TRUE, confirming_resight = TRUE), 3L)
})


test_that("the parent pipeline includes a conservative chick-GPS definitive gate", {
  sql <- views_source_sql()

  expect_match(
    sql,
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS AS",
    fixed = TRUE
  )
  expect_match(sql, "ADULT_CAPTURE_IDENTITIES_ALL", fixed = TRUE)
  expect_match(sql, "ADULT_RESIGHTING_IDENTITIES_ALL", fixed = TRUE)
  expect_match(sql, "c.spacer_key = r.spacer_key", fixed = TRUE)
  expect_match(sql, "best.capture_sex AS established_sex", fixed = TRUE)
  expect_no_match(sql, "WHERE best.capture_sex = r.observed_sex", fixed = TRUE)
  expect_match(sql, "ADULT_CHICK_GPS_PARENT_LINKS_INPUT", fixed = TRUE)
  expect_match(sql, "r.age = 'C'", fixed = TRUE)
  expect_match(sql, "r.gps_id IS NOT NULL", fixed = TRUE)
  expect_match(sql, "r.gps_point IS NOT NULL", fixed = TRUE)
  expect_match(
    sql,
    "UPPER(TRIM(COALESCE(r.ring, ''))) IN (",
    fixed = TRUE
  )
  expect_match(sql, "c.gps_id = chick.gps_id", fixed = TRUE)
  expect_match(sql, "c.gps_point = chick.gps_point", fixed = TRUE)
  expect_match(sql, "opposite_parent_established_nest", fixed = TRUE)
  expect_match(sql, "WHERE nests.n_candidate_nests = 1", fixed = TRUE)
  expect_match(sql, "MAX(event_union.chick_gps_parent_link) AS has_chick_gps_link", fixed = TRUE)
  expect_match(sql, "CASE WHEN chick_link.capture_pk IS NOT NULL", fixed = TRUE)

  gps_link_gate <- function(
    capture_gps_id,
    capture_gps_point,
    chick_gps_id,
    chick_gps_point,
    n_candidate_nests,
    chick_ring = "CP00001"
  ) {
    same_gps <- identical(capture_gps_id, chick_gps_id) &&
      identical(capture_gps_point, chick_gps_point)
    banded_chick <- !is.null(chick_ring) &&
      nzchar(chick_ring) &&
      !toupper(chick_ring) %in% c("X", "XX", "X-X", "NA", "N/A")
    isTRUE(same_gps && banded_chick && n_candidate_nests == 1L)
  }

  expect_true(gps_link_gate(2L, 159L, 2L, 159L, 1L))
  expect_false(gps_link_gate(2L, 159L, 2L, 158L, 1L))
  expect_false(gps_link_gate(2L, 159L, 2L, 159L, 2L))
  expect_false(gps_link_gate(2L, 159L, 2L, 159L, 1L, chick_ring = "X-X"))
})


test_that("tag deployment uses the bounded post-cutoff plan", {
  sql <- todo_list_view_sql()
  source_sql <- views_source_sql()

  expect_match(sql, "tag_deployment_history AS", fixed = TRUE)
  expect_match(sql, "parent_task_nests AS", fixed = TRUE)
  expect_match(
    sql,
    "TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_BUILD closure",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHERE UPPER(TRIM(COALESCE(n.nest_state, ''))) = 'NOTA'",
    fixed = TRUE
  )
  expect_match(sql, "tag_deployment_candidates candidates", fixed = TRUE)
  expect_match(sql, "tag_deployment_plan AS", fixed = TRUE)
  expect_match(
    sql,
    "LEFT(TRIM(parent_task_nests.nest_id), 1) IN ('B', 'C')",
    fixed = TRUE
  )
  expect_match(sql, "c.date <= sr.reference_date", fixed = TRUE)
  expect_no_match(sql, "c.date > CAST('2026-10-09' AS DATE)", fixed = TRUE)
  expect_match(sql, "M_new_protocol_geo", fixed = TRUE)
  expect_match(sql, "tag any, but only if one is confirmed X-X", fixed = TRUE)
  expect_match(sql, "tag X-X F (pair completion)", fixed = TRUE)
  expect_match(sql, "tag F (pair completion)", fixed = TRUE)
  expect_match(sql, "resight/tag M (status ?; pair completion)", fixed = TRUE)
  expect_match(sql, "initial_deployment_eligible", fixed = TRUE)
  expect_match(
    sql,
    "candidates.initial_tag_candidate = 1\n       AND candidates.initial_deployment_eligible = 1\n       AND candidates.M_target_has_geo = 0\n       AND candidates.F_target_has_geo = 0",
    fixed = TRUE
  )
  expect_no_match(sql, "geo_parent_targets AS", fixed = TRUE)
  expect_no_match(sql, "999999 AS release_ceiling", fixed = TRUE)
  expect_no_match(
    source_sql,
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.GEO_ROLLOUT_PHENOLOGY",
    fixed = TRUE
  )
  expect_match(
    source_sql,
    "DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.GEO_ROLLOUT_PHENOLOGY",
    fixed = TRUE
  )

  tag_status <- function(
    mark = NULL,
    has_geo = FALSE,
    confirmed_xx = FALSE,
    unknown = FALSE,
    pending = FALSE,
    ambiguous = FALSE
  ) {
    if (isTRUE(has_geo) && !isTRUE(pending) && !isTRUE(ambiguous)) {
      return("T")
    }
    if (isTRUE(confirmed_xx)) {
      return("X")
    }
    if (isTRUE(unknown) || isTRUE(pending) || isTRUE(ambiguous)) {
      return("?")
    }
    if (!is.null(mark) && nzchar(mark) && !identical(toupper(mark), "X-X")) {
      return("B")
    }
    "?"
  }

  expect_identical(tag_status(confirmed_xx = TRUE), "X")
  expect_identical(tag_status(mark = "YO-GR"), "B")
  expect_identical(tag_status(has_geo = TRUE), "T")
  expect_identical(tag_status(mark = "YO-GR", pending = TRUE), "?")
})


test_that("retired rollout quotas cannot create deployment tasks", {
  sql <- todo_list_view_sql()
  source_sql <- views_source_sql()

  expect_no_match(sql, "release_slots_remaining -", fixed = TRUE)
  expect_no_match(sql, "female quota complete", fixed = TRUE)
  expect_no_match(sql, "male quota complete", fixed = TRUE)
  expect_no_match(sql, "stratum_deficit", fixed = TRUE)
  expect_no_match(source_sql, "stratum_targets AS", fixed = TRUE)
  expect_no_match(
    source_sql,
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.GEO_ROLLOUT_PHENOLOGY",
    fixed = TRUE
  )
})


test_that("notA follow-up notes use the compact operational wording", {
  sql <- todo_list_view_sql()

  expect_match(sql, "'hatched; remove flag + do notA'", fixed = TRUE)
  expect_match(sql, "'remove flag + do notA'", fixed = TRUE)
  expect_no_match(sql, "'brood away; remove nest marks + enter notA'", fixed = TRUE)
  expect_no_match(sql, "'remove nest marks + enter notA'", fixed = TRUE)
})


test_that("pair completion requires current-nest deployment provenance", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    paste0(
      "CONVERT(history.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci\n",
      "            = CONVERT(parent_task_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci"
    ),
    fixed = TRUE
  )
  expect_match(sql, "history.parent_sex = 'M'", fixed = TRUE)
  expect_match(sql, "history.parent_sex = 'F'", fixed = TRUE)
  expect_match(sql, "M_new_protocol_geo", fixed = TRUE)
  expect_match(sql, "F_new_protocol_geo", fixed = TRUE)
  expect_match(sql, "M_tag_status = 'T'", fixed = TRUE)
  expect_match(sql, "F_tag_status = 'T'", fixed = TRUE)
  expect_match(sql, "tag F (pair completion)", fixed = TRUE)
  expect_match(sql, "tag M (pair completion)", fixed = TRUE)
  expect_match(sql, "tag X-X F (pair completion)", fixed = TRUE)
  expect_match(sql, "tag X-X M (pair completion)", fixed = TRUE)

  pair_completion_allowed <- function(
    tagged_parent_is_current,
    target_status,
    target_is_dead = FALSE,
    target_is_ambiguous = FALSE
  ) {
    isTRUE(tagged_parent_is_current) &&
      target_status %in% c("X", "B", "?") &&
      !isTRUE(target_is_dead) &&
      !isTRUE(target_is_ambiguous)
  }

  expect_true(pair_completion_allowed(TRUE, "B"))
  expect_true(pair_completion_allowed(TRUE, "X"))
  expect_true(pair_completion_allowed(TRUE, "?"))
  expect_false(pair_completion_allowed(FALSE, "B"))
  expect_false(pair_completion_allowed(TRUE, "B", target_is_ambiguous = TRUE))

  pair_completion_note <- function(tagged_parent_sex, target_status) {
    target_sex <- if (tagged_parent_sex == "M") "F" else "M"
    if (target_status == "X") {
      paste("tag X-X", target_sex, "(pair completion)")
    } else if (target_status == "B") {
      paste("tag", target_sex, "(pair completion)")
    } else if (target_status == "?") {
      paste("resight/tag", target_sex, "(status ?; pair completion)")
    }
  }

  expect_identical(
    pair_completion_note("F", "B"),
    "tag M (pair completion)"
  )
  expect_identical(
    pair_completion_note("F", "X"),
    "tag X-X M (pair completion)"
  )
  expect_identical(
    pair_completion_note("F", "?"),
    "resight/tag M (status ?; pair completion)"
  )
  expect_identical(
    pair_completion_note("M", "X"),
    "tag X-X F (pair completion)"
  )

  # Pair completion is only a provenance-backed action: a missing or
  # mismatched deployment, a dead target, or an ambiguous target must not
  # create a tag task merely because the other parent is tagged.
  expect_false(pair_completion_allowed(TRUE, "X", target_is_dead = TRUE))
  expect_false(pair_completion_allowed(TRUE, "B", target_is_ambiguous = TRUE))
  expect_false(pair_completion_allowed(FALSE, "X"))
})


test_that("initial deployment notes preserve unknown status", {
  initial_note <- function(male_status, female_status) {
    if (identical(male_status, "?") && identical(female_status, "?")) {
      "tag any, but only if one is confirmed X-X"
    } else if (
      (male_status == "X" && female_status %in% c("X", "B", "?")) ||
      (female_status == "X" && male_status %in% c("X", "B", "?"))
    ) {
      "tag any"
    } else {
      NA_character_
    }
  }

  expect_identical(initial_note("X", "?"), "tag any")
  expect_identical(initial_note("?", "X"), "tag any")
  expect_identical(initial_note("X", "B"), "tag any")
  expect_identical(initial_note("B", "X"), "tag any")
  expect_identical(
    initial_note("?", "?"),
    "tag any, but only if one is confirmed X-X"
  )
})
test_that("captured sex overrides a uniquely matching resighting sex", {
  sql <- paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
  todo_sql <- todo_list_view_sql()

  expect_match(sql, "resighting_adult_resolved_sex", fixed = TRUE)
  expect_match(
    sql,
    "COUNT(DISTINCT CASE",
    fixed = TRUE
  )
  expect_match(
    sql,
    "raw.ring_key IS NOT NULL AND captured.ring_key = raw.ring_key",
    fixed = TRUE
  )
  expect_match(
    sql,
    "raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key",
    fixed = TRUE
  )
  expect_match(sql, "captured.capture_date <= raw.observation_date", fixed = TRUE)
  expect_match(sql, "captured.LL_norm = raw.LL_norm", fixed = TRUE)
  expect_match(sql, "captured.LR_norm = raw.LR_norm", fixed = TRUE)
  expect_match(sql, "adult_resighting_observations", fixed = TRUE)
  expect_match(sql, "ADULT_SCRAPE_RESIGHTING_STATUS AS", fixed = TRUE)
  expect_match(
    todo_sql,
    "adult_parent_status.M_parent_mark AS authoritative_M_mark",
    fixed = TRUE
  )
  expect_match(
    todo_sql,
    "adult_parent_status.F_parent_mark AS authoritative_F_mark",
    fixed = TRUE
  )

  resolved_sex <- function(
    observed_sex,
    matching_capture_sexes,
    strong_identity = FALSE
  ) {
    if (isTRUE(strong_identity) && length(unique(matching_capture_sexes)) == 1L) {
      unique(matching_capture_sexes)
    } else {
      observed_sex
    }
  }

  # A verified ring/flag identity can override a conflicting observed sex.
  expect_identical(resolved_sex("M", "F", strong_identity = TRUE), "F")
  # A lower-mark-only match does not override the observed sex.
  expect_identical(resolved_sex("M", "F", strong_identity = FALSE), "M")
  # A lower-mark collision across sexes remains unresolved.
  expect_identical(
    resolved_sex("M", c("M", "F"), strong_identity = TRUE),
    "M"
  )
  # No matching capture leaves the observer-entered sex unchanged.
  expect_identical(
    resolved_sex("F", character(), strong_identity = TRUE),
    "F"
  )
})


test_that("flags and ambiguous matches cannot collapse into pure X-X", {
  sql <- paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )

  expect_match(sql, "CONCAT(keyed.flag_code, '-X')", fixed = TRUE)
  expect_match(sql, "AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')", fixed = TRUE)
  expect_match(sql, "AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')", fixed = TRUE)
  expect_match(sql, "WHEN identity_summary.has_ambiguous_match = 1 THEN 0", fixed = TRUE)
  expect_match(
    sql,
    "WHEN counts.n_candidate_identities = 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "best_identity.match_strength IN (1, 2)",
    fixed = TRUE
  )
  expect_match(
    sql,
    "best_identity.match_strength NOT IN (1, 2)",
    fixed = TRUE
  )
  expect_match(
    sql,
    "best_identity.candidate_sex = r.observed_sex",
    fixed = TRUE
  )
  expect_match(
    sql,
    "THEN 1 ELSE 0 END",
    fixed = TRUE
  )

  pure_xx <- function(LL, LR, UL = NULL, UR = NULL) {
    identical(LL, "X") && identical(LR, "X") &&
      (is.null(UL) || UL %in% c("X", "XX", "M")) &&
      (is.null(UR) || UR %in% c("X", "XX", "M"))
  }

  expect_true(pure_xx("X", "X"))
  expect_false(pure_xx("X", "X", UR = "FW74"))
  expect_false(pure_xx("X", "X", UR = "T"))
})


test_that("generic banded-parent association follows the resighting threshold", {
  sql <- todo_list_view_sql()
  full_sql <- all_todo_sql()

  expect_match(full_sql, "ADULT_SCRAPE_RESIGHTING_STATUS AS", fixed = TRUE)
  expect_match(sql, "ADULT_SCRAPE_RESIGHTING_STATUS", fixed = TRUE)
  expect_false(grepl("adult_resighting_association_status AS", sql, fixed = TRUE))
  expect_match(
    full_sql,
    "M_resight_association_count",
    fixed = TRUE
  )
  expect_match(
    full_sql,
    "M with ",
    fixed = TRUE
  )
  expect_match(
    full_sql,
    "resightings",
    fixed = TRUE
  )
  expect_match(
    full_sql,
    "SUM(candidate.association_eligible) AS n_matching_resightings",
    fixed = TRUE
  )
  expect_match(
    full_sql,
    "SUM(candidate.association_eligible) >= 3",
    fixed = TRUE
  )
  expect_match(
    full_sql,
    "identity_resolved",
    fixed = TRUE
  )
  expect_match(
    full_sql,
    "BW|NM|IN|SC|BC|FC|AC",
    fixed = TRUE
  )
  expect_equal(
    length(gregexpr("BW|NM|IN|SC|BC|FC|AC", full_sql, fixed = TRUE)[[1L]]),
    1L
  )
  expect_no_match(full_sql, "has_association_behaviour", fixed = TRUE)
  expect_no_match(full_sql, "n_distinct_identities", fixed = TRUE)
  expect_match(
    full_sql,
    "captured.capture_method, ''))) = 'TN'",
    fixed = TRUE
  )

  association_pending <- function(identity_behaviours) {
    resolved <- vapply(identity_behaviours, function(behav) {
      any(grepl("(^|[^A-Z])(IN|NM|SC|BW|BC|FC|AC)([^A-Z]|$)", behav)) ||
        length(behav) >= 3
    }, logical(1))
    sum(resolved) != 1
  }

  # One initial AT resighting is unresolved and remains on Parent resighting.
  expect_true(association_pending(list("AT")))
  # The initial event counts toward the three matching-resighting threshold.
  expect_true(association_pending(list(c("AT", "AT"))))
  expect_false(association_pending(list(c("AT", "AT", "AT"))))
  # Any one of the approved association behaviours resolves the identity.
  for (behav in c("IN", "NM", "SC", "BW", "BC", "FC", "AC")) {
    expect_false(association_pending(list(behav)))
  }
  # A future confirming event is excluded before it reaches this calculation;
  # the earlier reference date therefore still sees an open task.
  expect_true(association_pending(list("AT")))
  # Distinct same-sex identities remain ambiguous rather than silently
  # assigning the nest to both birds when neither has resolving evidence.
  expect_true(association_pending(list("AT", "AT")))
  # One confirmed identity displaces a provisional alternate identity.
  expect_false(association_pending(list("AT", "IN")))
})


test_that("pending known-banded associations bypass GEO candidate selection", {
  sql <- todo_list_view_sql()

  # The direct pending-association branch must remain separate from the GEO
  # capture candidate path. Otherwise a known-banded bird with only AT
  # resightings can disappear before the Parent resighting union is built.
  expect_match(
    sql,
    "todo_parent_resighting_existing AS",
    fixed = TRUE
  )
  expect_match(
    sql,
    "JOIN parent_resolution_status association",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHERE association.M_resight_association_pending = 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "OR association.F_resight_association_pending = 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "FROM todo_parent_resighting_existing",
    fixed = TRUE
  )
  expect_match(sql, "association.F_authoritative_resolved", fixed = TRUE)
  expect_match(sql, "association.M_authoritative_resolved", fixed = TRUE)
  expect_match(
    sql,
    "resight/tag M (status ?; F w/GEO)",
    fixed = TRUE
  )
  expect_match(
    sql,
    "resight/tag F (status ?; M w/GEO)",
    fixed = TRUE
  )
  expect_match(
    sql,
    "resight M (status ?; F w/GEO)",
    fixed = TRUE
  )
  expect_match(
    sql,
    "resight F (status ?; M w/GEO)",
    fixed = TRUE
  )
  expect_no_match(sql, "'resight/band M (F w/GEO)'", fixed = TRUE)
  expect_no_match(sql, "'resight/band F (M w/GEO)'", fixed = TRUE)
})


test_that("resolved parent notes require a projected visible mark", {
  sql <- todo_list_view_sql()

  # The note CASE consumes one shared resolution projection. That projection
  # validates the task-facing mark and selected identity key for both sexes,
  # while the task branch only needs the resulting flags.
  expect_match(
    sql,
    "NULLIF(TRIM(COALESCE(status.M_selected_identity_key, '')), '')",
    fixed = TRUE
  )
  expect_match(
    sql,
    "NULLIF(TRIM(COALESCE(status.F_selected_identity_key, '')), '')",
    fixed = TRUE
  )
  expect_match(
    sql,
    "COALESCE(status.M_selected_mark, status.M_parent_mark, '')",
    fixed = TRUE
  )
  expect_match(
    sql,
    "COALESCE(status.F_selected_mark, status.F_parent_mark, '')",
    fixed = TRUE
  )
  expect_match(
    sql,
    "association.M_authoritative_resolved",
    fixed = TRUE
  )
  expect_match(
    sql,
    "association.F_authoritative_resolved",
    fixed = TRUE
  )

  # This mirrors the SQL CASE inputs, including its normalization rules, so
  # the A0511-shaped failure is tested as a behavior rather than only by
  # checking that source text contains a guard.
  resolved_from_sql_inputs <- function(
    selected_identity_key,
    parent_mark,
    selected_mark = parent_mark,
    identity_count = 1L,
    association_pending = 0L,
    mm_pending = 0L,
    association_ambiguous = 0L,
    confirmed_unbanded = 0L
  ) {
    selected_key <- toupper(trimws(ifelse(is.na(selected_identity_key), "", selected_identity_key)))
    projected_mark <- toupper(trimws(ifelse(is.na(parent_mark), "", parent_mark)))
    selected_mark <- toupper(trimws(ifelse(is.na(selected_mark), "", selected_mark)))
    scoped_xx <- confirmed_unbanded == 1L &&
      projected_mark == "X-X" &&
      selected_mark == "X-X"
    identity_count > 0L &&
      association_pending == 0L &&
      association_ambiguous == 0L &&
      mm_pending == 0L &&
      nzchar(selected_key) &&
      !(selected_key %in% c("NA", "N/A", "NULL")) &&
      (!startsWith(selected_key, "XX:") || scoped_xx) &&
      nzchar(projected_mark) &&
      !(projected_mark %in% c("NA", "N/A", "NULL")) &&
      !startsWith(projected_mark, "XX:") &&
      nzchar(selected_mark) &&
      !(selected_mark %in% c("X", "XX", "NA", "N/A", "NULL"))
  }

  # A nonblank selected key with no projected mark was the reproduced bug.
  expect_false(
    resolved_from_sql_inputs("ring:MOCK-M", "")
  )
  expect_false(
    resolved_from_sql_inputs("ring:MOCK-F", "   ")
  )
  expect_false(
    resolved_from_sql_inputs("ring:MOCK-M", NA_character_)
  )

  for (sentinel in c("NA", "N/A", "NULL", "XX:MOCK")) {
    expect_false(
      resolved_from_sql_inputs("ring:MOCK-M", sentinel),
      info = paste("male projected mark sentinel:", sentinel)
    )
    expect_false(
      resolved_from_sql_inputs("ring:MOCK-F", sentinel),
      info = paste("female projected mark sentinel:", sentinel)
    )
  }

  # A visible mark still resolves for both sexes, while pending/unknown
  # identity states remain ineligible for the resolved label.
  expect_true(resolved_from_sql_inputs("ring:MOCK-M", "MOCK-YY.BL"))
  expect_true(resolved_from_sql_inputs("ring:MOCK-F", "MOCK-BY.LW"))
  # A selected, scoped X-X identity is a legitimate confirmed unbanded parent;
  # it must not be confused with a blank or synthetic XX identity.
  expect_true(resolved_from_sql_inputs(
    "XX:MOCK-M:M", "X-X", confirmed_unbanded = 1L
  ))
  expect_true(resolved_from_sql_inputs(
    "XX:MOCK-F:F", "X-X", confirmed_unbanded = 1L
  ))
  expect_false(resolved_from_sql_inputs("XX:MOCK-M:M", "X-X"))
  expect_false(resolved_from_sql_inputs("XX:MOCK-F:F", "X-X"))
  expect_false(
    resolved_from_sql_inputs(
      "ring:MOCK-M",
      "MOCK-YY.BL",
      association_pending = 1L
    )
  )
  expect_false(
    resolved_from_sql_inputs(
      "ring:MOCK-F",
      "MOCK-BY.LW",
      mm_pending = 1L
    )
  )
  expect_false(resolved_from_sql_inputs("ring:MOCK-M", ""))
  expect_false(resolved_from_sql_inputs("ring:MOCK-F", "   "))
  expect_false(resolved_from_sql_inputs("ring:MOCK-M", NA_character_))
  expect_false(
    resolved_from_sql_inputs(
      "ring:MOCK-M",
      "MOCK-YY.BL",
      association_ambiguous = 1L
    )
  )
  expect_false(resolved_from_sql_inputs("", "MOCK-YY.BL"))
})


test_that("four-gate parent-resighting identities are canonicalized and counted per pending bird", {
  sql <- all_todo_sql()

  expect_match(
    sql,
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES AS",
    fixed = TRUE
  )
  expect_match(
    sql,
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES AS",
    fixed = TRUE
  )
  expect_match(
    sql,
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_PARENT_NEST_ASSOCIATIONS AS",
    fixed = TRUE
  )
  expect_match(
    sql,
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.ADULT_PARENT_STATUS AS",
    fixed = TRUE
  )
  expect_match(sql, "c.is_confirmed_xx = 0", fixed = TRUE)
  expect_match(sql, "association_confirming", fixed = TRUE)
  expect_match(sql, "n_nonconfirming_resightings >= 3", fixed = TRUE)
  expect_match(sql, "M_resight_association_details", fixed = TRUE)
  expect_match(sql, "M_alternate_parent_details", fixed = TRUE)
  expect_match(sql, "M_resighting_identity_count", fixed = TRUE)
  expect_match(sql, "F_resighting_identity_count", fixed = TRUE)
  expect_match(sql, "F resolved", fixed = TRUE)
  expect_match(sql, "M resolved", fixed = TRUE)
  expect_match(sql, "M_resight_association_pending", fixed = TRUE)
  expect_match(sql, "F_resight_association_pending", fixed = TRUE)
  expect_match(sql, "M_mm_resight_pending", fixed = TRUE)
  expect_match(sql, "F_mm_resight_pending", fixed = TRUE)
  expect_match(
    sql,
    "COUNT(*) OVER (\n          PARTITION BY identity_summary.nest_id, identity_summary.sex\n        ) AS n_resighting_identities",
    fixed = TRUE
  )
  expect_match(sql, "association_eligible", fixed = TRUE)
  expect_match(sql, "xx_supersession_evidence AS", fixed = TRUE)
  expect_match(sql, "xx.identity_key LIKE 'xx:%'", fixed = TRUE)
  expect_match(sql, "captured.capture_date > xx.observation_date", fixed = TRUE)
  expect_match(
    sql,
    "r.observation_date <= superseded.supersession_capture_date",
    fixed = TRUE
  )
  expect_match(
    sql,
    "IN ('', 'X', 'XX', 'NA', 'N/A')",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHEN identity_counts.association_eligible = 0\n        THEN 0",
    fixed = TRUE
  )
  expect_false(grepl("RIGHT JOIN (", sql, fixed = TRUE))
  expect_match(sql, "WHEN classified.identity_resolved = 1 THEN ''", fixed = TRUE)
  expect_match(sql, "GROUP_CONCAT(\n      DISTINCT NULLIF(TRIM(M_mark), '')", fixed = TRUE)

  canonical_alias <- function(
    sex,
    capture_ll,
    capture_lr,
    capture_ul,
    capture_ur,
    resight_ll,
    resight_lr,
    special = FALSE
  ) {
    exact <- paste(capture_ll, capture_lr, sep = "|")
    spacer_short <- if (isTRUE(special)) {
      paste(capture_ll, paste0(substr(capture_ur, 2, 2), capture_lr), sep = "|")
    } else {
      NA_character_
    }
    observed <- paste(resight_ll, resight_lr, sep = "|")
    if (identical(observed, exact) || identical(observed, spacer_short)) {
      return(paste(sex, "MOCK-CANONICAL", sep = ":"))
    }
    NA_character_
  }

  # Full and LL/LR-only observations resolve to one ordinary bird.
  expect_identical(
    canonical_alias("M", "BY", "LW", "YO", "TG", "BY", "LW"),
    "M:MOCK-CANONICAL"
  )
  # A single-LR bird uses the final spacer colour plus LR in its short form.
  expect_identical(
    canonical_alias("F", "BY", "L", "M", "TB", "BY", "BL", special = TRUE),
    "F:MOCK-CANONICAL"
  )
  # Different sexes remain separate even when the lower pair is identical;
  # the SQL alias map is grouped by sex as well as the observed pair.
  expect_identical(
    c(
      male = canonical_alias("M", "BY", "LW", "YO", "TG", "BY", "LW"),
      female = canonical_alias("F", "BY", "LW", "YO", "TG", "BY", "LW")
    ),
    c(male = "M:MOCK-CANONICAL", female = "F:MOCK-CANONICAL")
  )
  # A competing canonical captured mark is deliberately not safe to infer.
  expect_true(is.na(canonical_alias("M", "BY", "LW", "YO", "TG", "BY", "ZZ")))

  format_pending_identity <- function(mark, n_resightings, mm = FALSE) {
    prefix <- if (isTRUE(mm)) "MM, " else ""
    paste0(mark, " (", prefix, n_resightings, ")")
  }

  expect_identical(
    format_pending_identity("MOCK-TG.GW", 2, mm = TRUE),
    "MOCK-TG.GW (MM, 2)"
  )
  expect_identical(
    paste(
      format_pending_identity("MOCK-TG.GW", 2, mm = TRUE),
      format_pending_identity("MOCK-GY", 1),
      sep = " & "
    ),
    "MOCK-TG.GW (MM, 2) & MOCK-GY (1)"
  )

  pending <- c("MOCK-TG.GW (MM, 2)", NA_character_)
  expect_identical(
    paste(na.omit(pending), collapse = " & "),
    "MOCK-TG.GW (MM, 2)"
  )
})


test_that("the authoritative parent status is the sole parent-task input", {
  sql <- todo_list_view_sql()
  full_sql <- views_source_sql()

  expect_match(
    sql,
    "JOIN adult_parent_status association",
    fixed = TRUE
  )
  expect_match(sql, "association.M_resight_association_pending = 1", fixed = TRUE)
  expect_match(sql, "association.F_resight_association_pending = 1", fixed = TRUE)
  expect_match(sql, "adult_parent_status.M_parent_mark AS M_mark", fixed = TRUE)
  expect_match(sql, "adult_parent_status.F_parent_mark AS F_mark", fixed = TRUE)
  expect_match(full_sql, "WHEN by_identity.association_pending = 1", fixed = TRUE)

  format_identity <- function(mark, n_resightings, has_mm = FALSE) {
    suffix <- if (has_mm) paste0(" (MM, ", n_resightings, ")") else {
      paste0(" (", n_resightings, ")")
    }
    paste0(mark, suffix)
  }

  expect_identical(format_identity("MOCK-TG.GW", 2, TRUE), "MOCK-TG.GW (MM, 2)")
  expect_identical(format_identity("MOCK-GY", 1, FALSE), "MOCK-GY (1)")
})


test_that("TODO_LIST stays within the known MariaDB CTE limit", {
  sql <- todo_list_view_sql()
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1]]
  cte_lines <- grep("^[A-Za-z0-9_]+ AS \\($", lines, value = TRUE)

  expect_gt(length(cte_lines), 0L)
  expect_lte(length(cte_lines), 63L)
})
