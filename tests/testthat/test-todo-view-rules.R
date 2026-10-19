todo_list_view_sql <- function() {
  sql <- paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
  start_marker <-
    "CREATE OR REPLACE( ALGORITHM = [A-Z]+)? VIEW FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE AS"
  end_marker <- paste(
    "/*",
    "  Refreshable task snapshot",
    sep = "\n"
  )
  start <- regexpr(start_marker, sql, perl = TRUE)[[1]]
  expect_gt(start, 0L)

  remainder <- substring(sql, start)
  finish <- regexpr(end_marker, remainder, fixed = TRUE)[[1]]
  expect_gt(finish, 0L)

  substring(remainder, 1L, finish - 1L)
}


views_source_sql <- function() {
  paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
}


test_that("public TODO_LIST is a small snapshot-backed read boundary", {
  sql <- views_source_sql()
  start_marker <- paste(
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW",
    "FIELD_2026_BADOatNZ.TODO_LIST AS"
  )
  end_marker <- paste(
    "CREATE OR REPLACE VIEW",
    "FIELD_2026_BADOatNZ.VIEW_1 AS"
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
  public_drop <- regexpr(
    "DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST;",
    sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(parent_build_insert, 0L)
  expect_gt(task_build_insert, 0L)
  expect_gt(public_drop, parent_build_insert)
  expect_gt(public_drop, task_build_insert)
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
  expect_match(refresh_sql, "SELECT *\nFROM FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE", fixed = TRUE)
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
  public_drop <- regexpr(
    "DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST;",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(parent_build_insert, 0L)
  expect_gt(task_build_insert, 0L)
  expect_gt(public_drop, parent_build_insert)
  expect_gt(public_drop, task_build_insert)

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


test_that("AVAILABLE_COMBOS keeps all eligible OY marks in CR", {
  sql <- available_combos_view_sql()

  expect_match(
    sql,
    "LL IN ('BY', 'WY', 'YY', 'YO', 'OY') THEN 'CR'",
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
      "LL IN ('BY', 'WY', 'YY', 'YO', 'OY') THEN 'CR'",
      sql,
      fixed = TRUE
    )[[1]]
  )

  classify_cr_candidate <- function(LL, LR, combo_rank) {
    if (LL %in% c("BY", "WY", "YY", "YO", "OY")) {
      return("CR")
    }
    if (grepl("L", paste0(LL, LR)) || combo_rank > 30L) {
      return("CX")
    }
    "CR"
  }

  expect_identical(classify_cr_candidate("OY", "BL", 40L), "CR")
  expect_identical(classify_cr_candidate("OY", "BR", 80L), "CR")
  expect_identical(classify_cr_candidate("LY", "BB", 20L), "CX")
})


test_that("TODO_LIST contains the bounded operational rules", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE AS",
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
    sql,
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
  sql <- views_source_sql()

  expect_match(
    sql,
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS AS",
    fixed = TRUE
  )
  expect_match(sql, "same_occasion_adult_summary", fixed = TRUE)
  expect_match(sql, "latest_ring_capture_summary", fixed = TRUE)
  expect_match(
    sql,
    "COALESCE(h_assoc.resolved_nest_id, r.nest_id) AS nest_id",
    fixed = TRUE
  )
  expect_match(sql, "'ambiguous_same_occasion_adult'", fixed = TRUE)
  expect_match(sql, "'ambiguous_capture_history'", fixed = TRUE)
  expect_match(
    sql,
    "h.association_method IN (\n      'direct',\n      'same_occasion_adult',\n      'ring_capture'",
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
})


test_that("brood photo follow-up uses the unified brood evidence source", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "JOIN FIELD_2026_BADOatNZ.BROODS_LATEST b\n    ON n.nest_id = b.nest_id",
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
    "CREATE OR REPLACE( ALGORITHM = [A-Z]+)? VIEW FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE AS",
    parent_sql,
    perl = TRUE
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
  expect_match(todo_sql, "END AS both_parents_need_geo_derived", fixed = TRUE)
  expect_match(
    todo_sql,
    "adult_parent_status.both_parents_need_geo_derived AS both_parents_need_geo",
    fixed = TRUE
  )
})


test_that("hiding-photo TODO counts distinct captured and photographed rings", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "COUNT(DISTINCT NULLIF(\n      NULLIF(UPPER(TRIM(COALESCE(c.ring, ''))), ''),\n      'NA'\n    )) AS n_captured_chick_rings",
    fixed = TRUE
  )
  expect_match(sql, "COUNT(*) AS n_chick_captures", fixed = TRUE)
  expect_match(
    sql,
    "COUNT(DISTINCT h.ring) AS n_hiding_spot_photos",
    fixed = TRUE
  )
  expect_match(sql, "r.photo_start", fixed = TRUE)
  expect_match(sql, "r.photo_end", fixed = TRUE)
  expect_match(
    sql,
    "COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0)\n           < chick_captures.n_captured_chick_rings",
    fixed = TRUE
  )
  expect_match(
    sql,
    "' chicks with rclass ''H'' photos'",
    fixed = TRUE
  )
  expect_false(grepl("need H resightings", sql, fixed = TRUE))
})


test_that("hatch prediction includes complete-clutch and stable one-egg fallbacks", {
  sql <- views_source_sql()

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
  sql <- views_source_sql()

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


test_that("brood banding notes identify broods young enough for leg flags", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "DATEDIFF(\n             brood_followup_nests.hatch_date,\n             brood_followup_nests.reference_date\n           ) <= -21",
    fixed = TRUE
  )
  expect_match(
    sql,
    "'no chick captures; chicks old enough for leg flags'",
    fixed = TRUE
  )

  banding_note <- function(hatch_value = NA_integer_, discovery_age = NA_integer_) {
    if (!is.na(hatch_value) && hatch_value <= -21L) {
      return("no chick captures; chicks old enough for leg flags")
    }
    if (!is.na(discovery_age) && discovery_age >= 21L) {
      return("no chick captures; chicks old enough for leg flags")
    }
    "no chick captures"
  }

  expect_identical(
    banding_note(hatch_value = -21L),
    "no chick captures; chicks old enough for leg flags"
  )
  expect_identical(
    banding_note(hatch_value = -20L),
    "no chick captures"
  )
  expect_identical(
    banding_note(discovery_age = 21L),
    "no chick captures; chicks old enough for leg flags"
  )
  expect_identical(
    banding_note(discovery_age = 20L),
    "no chick captures"
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


test_that("two-egg parent capture waits seven days after inferred completion", {
  sql <- todo_list_view_sql()
  timing_start <- regexpr("adult_capture_age_status AS", sql, fixed = TRUE)[[1L]]
  expect_gt(timing_start, 0L)

  timing_sql <- substring(sql, timing_start)
  timing_end <- regexpr("geo_parent_targets AS", timing_sql, fixed = TRUE)[[1L]]
  expect_gt(timing_end, 0L)
  timing_sql <- substring(timing_sql, 1L, timing_end - 1L)

  expect_match(timing_sql, "clutch_start.last_float_datetime", fixed = TRUE)
  expect_match(timing_sql, "current_clutch_size = 2", fixed = TRUE)
  expect_match(timing_sql, "INTERVAL 3 DAY", fixed = TRUE)
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

  completion_basis <- function(
      clutch_size,
      current_start,
      current_datetime,
      last_float_datetime = NA_character_
  ) {
    current_start <- as.Date(current_start)
    current_datetime <- as.Date(current_datetime)
    last_float_datetime <- as.Date(last_float_datetime)

    if (clutch_size >= 3L) {
      return(current_start)
    }
    if (
      clutch_size == 2L &&
        !is.na(last_float_datetime) &&
        last_float_datetime >= current_start
    ) {
      return(last_float_datetime + 3L)
    }
    if (current_datetime - current_start >= 3L) {
      return(current_start)
    }
    current_datetime + 2L * max(0L, 3L - clutch_size)
  }

  capture_allowed <- function(reference_date, completion_date) {
    as.integer(as.Date(reference_date) - completion_date >= 7L)
  }

  c0909_completion <- completion_basis(
    clutch_size = 2L,
    current_start = "2026-10-17",
    current_datetime = "2026-10-17",
    last_float_datetime = "2026-10-17"
  )
  expect_identical(c0909_completion, as.Date("2026-10-20"))
  expect_identical(capture_allowed("2026-10-26", c0909_completion), 0L)
  expect_identical(capture_allowed("2026-10-27", c0909_completion), 1L)

  third_egg_completion <- completion_basis(
    clutch_size = 3L,
    current_start = "2026-10-19",
    current_datetime = "2026-10-19",
    last_float_datetime = "2026-10-17"
  )
  expect_identical(third_egg_completion, as.Date("2026-10-19"))
  expect_identical(capture_allowed("2026-10-25", third_egg_completion), 0L)
  expect_identical(capture_allowed("2026-10-26", third_egg_completion), 1L)
})


test_that("partial hatch signs retain the unhatched-egg instruction", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "active_nests.hatch_signs_present = 1\n          OR UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'",
    fixed = TRUE
  )
  expect_match(sql, "'; unhatched egg(s)'", fixed = TRUE)

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
  expect_match(sql, "r.ring)) NOT IN ('X', 'XX', 'X-X', 'NA', 'N/A')", fixed = TRUE)
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


test_that("pair completion uses the four-gate status without phenology gating", {
  sql <- todo_list_view_sql()
  source_sql <- views_source_sql()

  expect_match(sql, "FROM geo_parent_targets targets", fixed = TRUE)
  expect_match(sql, "FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT", fixed = TRUE)
  expect_match(sql, "is_pair_completion", fixed = TRUE)
  expect_match(sql, "geo_instruction", fixed = TRUE)

  resolved_parent_geo <- function(identity_has_geo, xx_parent_confirmed, pending) {
    if (isTRUE(xx_parent_confirmed) || isTRUE(pending)) 0 else identity_has_geo
  }
  expect_identical(resolved_parent_geo(1, TRUE, FALSE), 0)
  expect_identical(resolved_parent_geo(1, FALSE, TRUE), 0)
  expect_identical(resolved_parent_geo(1, FALSE, FALSE), 1)

  expect_match(sql, "parent_status.F_has_geo", fixed = TRUE)
  expect_match(sql, "parent_status.M_has_geo", fixed = TRUE)

  expect_match(
    source_sql,
    "CASE WHEN by_identity.association_selected = 1",
    fixed = TRUE
  )
  expect_match(source_sql, "AS selected_has_geo", fixed = TRUE)
  expect_match(source_sql, "status_by_sex.selected_has_geo", fixed = TRUE)
  expect_no_match(source_sql, "status_by_sex.any_has_geo", fixed = TRUE)

  selected_geo <- function(identities) {
    selected <- identities[identities$association_selected == 1, , drop = FALSE]
    if (nrow(selected) != 1L) return(0L)
    as.integer(selected$has_geo[[1L]] == 1L)
  }

  # A selected unbanded parent must not inherit GEO from a provisional
  # same-sex identity at the same nest (the C0615 failure mode).
  expect_identical(
    selected_geo(data.frame(
      association_selected = c(1L, 0L),
      has_geo = c(0L, 1L)
    )),
    0L
  )

  # A selected tagged parent remains GEO-eligible even if another identity is
  # untagged or provisional.
  expect_identical(
    selected_geo(data.frame(
      association_selected = c(1L, 0L),
      has_geo = c(1L, 0L)
    )),
    1L
  )

  # Ambiguous same-sex evidence has no authoritative GEO identity.
  expect_identical(
    selected_geo(data.frame(
      association_selected = c(0L, 0L),
      has_geo = c(1L, 0L)
    )),
    0L
  )

  pair_target <- function(
    male_tag_eligible,
    female_quota_remaining,
    male_quota_remaining,
    female_has_geo,
    female_captured_has_geo,
    female_mm_pending
  ) {
    if (
      male_tag_eligible &&
        male_quota_remaining > 0 &&
        (female_has_geo || female_captured_has_geo)
    ) {
      return("M")
    }
    if (female_quota_remaining > 0 && male_quota_remaining >= 0) {
      return(NULL)
    }
    NULL
  }

  expect_identical(
    pair_target(TRUE, 1, 1, TRUE, FALSE, FALSE),
    "M"
  )
  expect_identical(
    pair_target(TRUE, 1, 1, FALSE, TRUE, TRUE),
    "M"
  )
})


test_that("pair completion bypasses the release ceiling but balance does not", {
  sql <- todo_list_view_sql()

  expect_match(sql, "999999 AS release_ceiling", fixed = TRUE)
  expect_match(sql, "CASE WHEN targets.pair_target IS NOT NULL THEN 1 ELSE 0 END", fixed = TRUE)
  expect_match(sql, "CASE WHEN targets.pair_target IS NOT NULL THEN 'pair completion' ELSE NULL END", fixed = TRUE)

  geo_is_actionable <- function(
    is_candidate,
    pair_target,
    geo_rank,
    release_slots_remaining
  ) {
    isTRUE(is_candidate) && (
      !is.null(pair_target) ||
        geo_rank <= max(0, release_slots_remaining)
    )
  }

  expect_true(geo_is_actionable(TRUE, "F", 8, 0))
  expect_false(geo_is_actionable(TRUE, NULL, 1, 0))
  expect_true(geo_is_actionable(TRUE, NULL, 1, 1))
})


test_that("notA follow-up notes use the compact operational wording", {
  sql <- todo_list_view_sql()

  expect_match(sql, "'hatched; remove flag + do notA'", fixed = TRUE)
  expect_match(sql, "'remove flag + do notA'", fixed = TRUE)
  expect_no_match(sql, "'brood away; remove nest marks + enter notA'", fixed = TRUE)
  expect_no_match(sql, "'remove nest marks + enter notA'", fixed = TRUE)
})


test_that("one tagged parent produces pair completion without deployment-date gating", {
  sql <- todo_list_view_sql()

  expect_match(sql, "parent_status.F_has_geo", fixed = TRUE)
  expect_match(sql, "parent_status.M_has_geo", fixed = TRUE)
  expect_no_match(sql, "is_pre25_nest", fixed = TRUE)
  expect_no_match(sql, "geo_deployment_date >=", fixed = TRUE)

  pair_completion_target <- function(
    male_tagged,
    female_tagged,
    male_tag_eligible = TRUE,
    female_tag_eligible = TRUE,
    male_quota_remaining = 1,
    female_quota_remaining = 1,
    male_mm_pending = FALSE,
    female_mm_pending = FALSE
  ) {
    if (
      female_tagged &&
        !male_tagged &&
        male_tag_eligible &&
        male_quota_remaining > 0
    ) {
      return("M")
    }
    if (
      male_tagged &&
        !female_tagged &&
        female_tag_eligible &&
        female_quota_remaining > 0
    ) {
      return("F")
    }
    NULL
  }

  parent_capture_note <- function(pair_target, actionable = TRUE) {
    if (isTRUE(actionable) && !is.null(pair_target)) {
      return(paste0("tag ", pair_target, " (pair completion)"))
    }
    "ordinary parent work"
  }

  # C0217-like: tagged female, untagged/unknown male. The female's
  # deployment date is deliberately absent from this mock.
  expect_identical(
    parent_capture_note(pair_completion_target(FALSE, TRUE)),
    "tag M (pair completion)"
  )
  # C2205-like: tagged male, X-X female. The male's deployment date is
  # deliberately absent from this mock.
  expect_identical(
    parent_capture_note(pair_completion_target(TRUE, FALSE)),
    "tag F (pair completion)"
  )
  # MM uncertainty remains a Parents-to-resight task, but does not suppress
  # the opposite mate's pair-completion capture target.
  expect_identical(
    pair_completion_target(
      FALSE,
      TRUE,
      female_mm_pending = TRUE
    ),
    "M"
  )
  expect_identical(
    pair_completion_target(
      TRUE,
      FALSE,
      male_mm_pending = TRUE
    ),
    "F"
  )
  # Quota and parent eligibility remain authoritative.
  expect_identical(
    pair_completion_target(
      FALSE,
      TRUE,
      male_quota_remaining = 0
    ),
    NULL
  )
})


test_that("confirmed X-X alternate parent can complete a tagged pair", {
  sql <- todo_list_view_sql()

  expect_match(sql, "parent_status.M_has_geo", fixed = TRUE)
  expect_match(sql, "parent_status.F_has_geo", fixed = TRUE)
  expect_match(sql, "tag X-X F (pair completion)", fixed = TRUE)
  expect_match(sql, "THEN '; CORRECT DUPLICATE'", fixed = TRUE)
  expect_match(
    sql,
    "active_nests.nest_id = 'B2203'",
    fixed = TRUE
  )
  expect_match(sql, "'F: CORRECT DUPLICATE'", fixed = TRUE)

  pair_completion_target <- function(
    target_sex,
    target_is_xx,
    opposite_captured_has_geo,
    opposite_mm_pending,
    target_tag_eligible = TRUE,
    target_quota_remaining = 1
  ) {
    alternate_parent_resolves <- target_is_xx && opposite_mm_pending
    if (
      target_sex == "F" &&
        target_tag_eligible &&
        target_quota_remaining > 0 &&
        opposite_captured_has_geo
    ) {
      return("F")
    }
    NULL
  }

  pair_note <- function(target_sex, target_mark) {
    target_label <- if (identical(target_mark, "X-X")) {
      paste("X-X", target_sex)
    } else {
      target_sex
    }
    paste0("tag ", target_label, " (pair completion)")
  }

  corrected_pair_note <- function(nest_id, target_sex, target_mark) {
    note <- pair_note(target_sex, target_mark)
    if (identical(nest_id, "C2208") && identical(target_sex, "M")) {
      paste0(note, "; CORRECT DUPLICATE")
    } else {
      note
    }
  }

  expect_identical(
    pair_completion_target("F", TRUE, TRUE, TRUE),
    "F"
  )
  expect_identical(
    pair_completion_target("F", FALSE, TRUE, TRUE),
    "F"
  )
  expect_identical(
    pair_note("F", "X-X"),
    "tag X-X F (pair completion)"
  )
  expect_identical(
    corrected_pair_note("C2208", "M", "YO-GR"),
    "tag M (pair completion); CORRECT DUPLICATE"
  )
  expect_identical(
    corrected_pair_note("C9999", "M", "YO-GR"),
    "tag M (pair completion)"
  )

  duplicate_correction_note <- function(nest_id, female_mark) {
    if (
      identical(nest_id, "B2203") &&
        identical(female_mark, "YY-TB.BL")
    ) {
      "F: CORRECT DUPLICATE"
    } else {
      NA_character_
    }
  }
  expect_identical(
    duplicate_correction_note("B2203", "YY-TB.BL"),
    "F: CORRECT DUPLICATE"
  )
  expect_true(is.na(duplicate_correction_note("B2203", "YY-TB.BW")))
  expect_null(
    pair_completion_target("F", TRUE, TRUE, TRUE, target_tag_eligible = FALSE)
  )
  expect_null(
    pair_completion_target("F", TRUE, FALSE, TRUE)
  )
})


test_that("live X-X after a dead MM capture remains GEO eligible", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "COALESCE(parent_status.M_is_dead, 0) = 0",
    fixed = TRUE
  )
  expect_match(
    sql,
    "adult_parent_status.M_confirmed_unbanded = 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "adult_parent_status.M_resight_association_pending",
    fixed = TRUE
  )
  expect_match(
    sql,
    "M_confirmed_unbanded",
    fixed = TRUE
  )

  tag_eligible <- function(
    is_dead,
    mm_xx_parent_confirmed,
    confirmed_unbanded,
    mm_resight_pending = FALSE
  ) {
    !isTRUE(mm_resight_pending) &&
      (
        !isTRUE(is_dead) ||
          (
            isTRUE(mm_xx_parent_confirmed) &&
              isTRUE(confirmed_unbanded) &&
              !isTRUE(mm_resight_pending)
          )
      )
  }

  # C0217-like chronology: dead MM capture, then live X-X with IN.
  expect_true(tag_eligible(TRUE, TRUE, TRUE))
  # A dead parent without a later qualifying live X-X remains ineligible.
  expect_false(tag_eligible(TRUE, FALSE, FALSE))
  # Pending MM uncertainty still blocks tag deployment.
  expect_false(tag_eligible(TRUE, TRUE, TRUE, mm_resight_pending = TRUE))
})


test_that("pair completion may target one pending known-banded association", {
  sql <- todo_list_view_sql()

  expect_match(sql, "geo_parent_plan.geo_tag_target", fixed = TRUE)
  expect_match(sql, "geo_parent_plan.geo_band_target", fixed = TRUE)
  expect_match(
    sql,
    "COALESCE(parent_status.M_resight_association_ambiguous, 0) = 0",
    fixed = TRUE
  )
  expect_match(
    sql,
    "COALESCE(parent_status.F_resight_association_ambiguous, 0) = 0",
    fixed = TRUE
  )
  expect_match(sql, "M_resight_association_ambiguous", fixed = TRUE)
  expect_match(sql, "F_resight_association_ambiguous", fixed = TRUE)

  pair_tag_allowed <- function(
    has_geo,
    is_dead = FALSE,
    mm_pending = FALSE,
    association_ambiguous = FALSE,
    plot = "B"
  ) {
    identical(plot, "A") == FALSE &&
      !isTRUE(has_geo) &&
      !isTRUE(is_dead) &&
      !isTRUE(mm_pending) &&
      !isTRUE(association_ambiguous)
  }

  # A single pending known-banded identity can still be the pair-completion
  # target when the opposite parent carries a GEO tag.
  expect_true(pair_tag_allowed(FALSE))
  # Competing same-sex identities, dead status, or MM uncertainty remain gates.
  expect_false(pair_tag_allowed(FALSE, association_ambiguous = TRUE))
  expect_false(pair_tag_allowed(FALSE, is_dead = TRUE))
  expect_false(pair_tag_allowed(FALSE, mm_pending = TRUE))
  expect_false(pair_tag_allowed(FALSE, plot = "A"))
  expect_false(pair_tag_allowed(TRUE))
})


test_that("captured sex overrides a uniquely matching resighting sex", {
  sql <- views_source_sql()
  todo_sql <- todo_list_view_sql()

  expect_match(sql, "resighting_adult_resolved_sex", fixed = TRUE)
  expect_match(sql, "COUNT(DISTINCT captured.sex) = 1", fixed = TRUE)
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

  resolved_sex <- function(observed_sex, matching_capture_sexes) {
    if (length(unique(matching_capture_sexes)) == 1L) {
      unique(matching_capture_sexes)
    } else {
      observed_sex
    }
  }

  # A female capture wins over a mistaken male resighting of the same LL/LR.
  expect_identical(resolved_sex("M", "F"), "F")
  # A lower-mark collision across sexes remains unresolved.
  expect_identical(resolved_sex("M", c("M", "F")), "M")
  # No matching capture leaves the observer-entered sex unchanged.
  expect_identical(resolved_sex("F", character()), "F")
})


test_that("flags and ambiguous matches cannot collapse into pure X-X", {
  sql <- views_source_sql()

  expect_match(sql, "CONCAT(keyed.flag_code, '-X')", fixed = TRUE)
  expect_match(sql, "AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')", fixed = TRUE)
  expect_match(sql, "AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')", fixed = TRUE)
  expect_match(sql, "WHEN identity_summary.has_ambiguous_match = 1 THEN 0", fixed = TRUE)
  expect_match(sql, "CASE WHEN counts.n_candidate_identities = 1 THEN 1 ELSE 0 END", fixed = TRUE)

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
  full_sql <- views_source_sql()

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
    "BW|NM|IN|BC|FC|AC",
    fixed = TRUE
  )
  expect_equal(
    length(gregexpr("BW|NM|IN|BC|FC|AC", full_sql, fixed = TRUE)[[1L]]),
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
      any(grepl("(^|[^A-Z])(IN|NM|BW|BC|FC|AC)([^A-Z]|$)", behav)) ||
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
  for (behav in c("IN", "NM", "BW", "BC", "FC", "AC")) {
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
  sql <- views_source_sql()

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
    "JOIN adult_parent_status association",
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
})


test_that("four-gate parent-resighting identities are canonicalized and counted per pending bird", {
  sql <- views_source_sql()

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
