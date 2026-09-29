todo_list_view_sql <- function() {
  sql <- paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
  start_marker <- paste(
    "CREATE OR REPLACE VIEW",
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

  substring(remainder, 1L, finish - 1L)
}


test_that("TODO_LIST contains the bounded operational rules", {
  sql <- todo_list_view_sql()

  expect_match(sql, "IN ('F', 'I', 'H', 'PP', 'PD')", fixed = TRUE)
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
  expect_no_match(sql, "RESIGHTINGS_H_BROOD_ASSOCIATIONS", fixed = TRUE)
})


test_that("MM parent follow-up accepts qualifying behaviour or three matching resightings", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "n_matching_post_mm_resightings",
    fixed = TRUE
  )
  expect_match(
    sql,
    "COALESCE(followup.n_matching_post_mm_resightings, 0) < 3",
    fixed = TRUE
  )
  expect_match(
    sql,
    "association.association_date >= mm.mm_capture_date",
    fixed = TRUE
  )
  expect_match(
    sql,
    "'(^|[^A-Z])(BW|NM|IN)([^A-Z]|$)'",
    fixed = TRUE
  )
  expect_match(sql, "post_mm_xx_seen", fixed = TRUE)

  matching_followup_resolved <- function(
    resightings,
    reference_date,
    capture_date = "2026-09-01"
  ) {
    post_mm <- resightings[
      resightings$date >= as.Date(capture_date) &
        resightings$date <= as.Date(reference_date),
    ]
    matching <- toupper(trimws(post_mm$mark)) == "BY-YY"
    has_nest_behaviour <- grepl(
      "(^|[^A-Z])(BW|NM|IN)([^A-Z]|$)",
      toupper(trimws(post_mm$behav)),
      perl = TRUE
    )
    sum(matching) >= 1 && (
      any(matching & has_nest_behaviour) || sum(matching) >= 3
    )
  }

  mock_resightings <- data.frame(
    date = as.Date(c(
      "2026-09-02", "2026-09-03", "2026-09-04", "2026-09-05"
    )),
    mark = c("X-X", "BY-YY", "BY-YY", "BY-YY"),
    behav = c("AT", "AT", "AT", "AT"),
    stringsAsFactors = FALSE
  )

  expect_false(matching_followup_resolved(mock_resightings, "2026-09-04"))
  expect_true(matching_followup_resolved(mock_resightings, "2026-09-05"))

  same_day_behaviour <- data.frame(
    date = as.Date("2026-09-01"),
    mark = "BY-YY",
    behav = "AT, BW",
    stringsAsFactors = FALSE
  )
  expect_true(
    matching_followup_resolved(same_day_behaviour, "2026-09-01")
  )

  one_matching_resighting <- data.frame(
    date = as.Date(c("2026-09-02", "2026-09-03")),
    mark = c("BY-YY", "YO-OR"),
    behav = c("AT", "BW"),
    stringsAsFactors = FALSE
  )
  expect_false(
    matching_followup_resolved(one_matching_resighting, "2026-09-05")
  )
})


test_that("hatched brood task Hatch values use the recorded H date", {
  sql <- todo_list_view_sql()

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
    "OR active_nests.hatch_signs_present = 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "ELSE COALESCE(capture_age.capture_allowed_after_completion, 0)",
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


test_that("pending MM parents stay in resighting rather than capture work", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "WHEN COALESCE(adult_mm_followup_status.M_mm_resight_pending, 0) = 1\n      THEN 0",
    fixed = TRUE
  )
  expect_match(
    sql,
    "(mm.sex = 'M' AND COALESCE(adult_parent_status.M_mm_resight_pending, 0) = 1)",
    fixed = TRUE
  )
  expect_match(
    sql,
    "(mm.sex = 'F' AND COALESCE(adult_parent_status.F_mm_resight_pending, 0) = 1)",
    fixed = TRUE
  )
  expect_no_match(sql, "AND followup.nest_id IS NULL", fixed = TRUE)
  expect_no_match(sql, "'resight/band M (MM cap)'", fixed = TRUE)
  expect_match(sql, "' had MM cap'", fixed = TRUE)
  expect_match(sql, "has_xx_nest_behav", fixed = TRUE)
  expect_match(sql, "M_mm_xx_parent_confirmed", fixed = TRUE)
  expect_match(
    sql,
    "WHEN COALESCE(\n             adult_mm_followup_status.M_mm_xx_parent_confirmed,\n             0\n           ) = 1\n      THEN 'X-X'",
    fixed = TRUE
  )

  mm_followup_pending <- function(n_matching, has_nest_behaviour) {
    n_matching == 0L ||
      (!isTRUE(has_nest_behaviour) && n_matching < 3L)
  }

  capture_candidate <- function(mm_pending, unknown_status) {
    isTRUE(unknown_status) && !isTRUE(mm_pending)
  }

  xx_parent_confirmed <- function(is_xx, has_nest_behaviour) {
    isTRUE(is_xx) && isTRUE(has_nest_behaviour)
  }

  expect_true(mm_followup_pending(1L, FALSE))
  expect_false(mm_followup_pending(1L, TRUE))
  expect_false(mm_followup_pending(3L, FALSE))
  expect_false(capture_candidate(TRUE, TRUE))
  expect_true(capture_candidate(FALSE, TRUE))
  expect_true(xx_parent_confirmed(TRUE, TRUE))
  expect_false(xx_parent_confirmed(TRUE, FALSE))
})


test_that("pair completion requires a confirmed GEO association", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "COALESCE(base.F_captured_has_geo, 0) = 1\n                   AND COALESCE(base.F_mm_resight_pending, 0) = 0",
    fixed = TRUE
  )
  expect_match(
    sql,
    "COALESCE(base.M_captured_has_geo, 0) = 1\n                   AND COALESCE(base.M_mm_resight_pending, 0) = 0",
    fixed = TRUE
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
        (
          female_has_geo ||
            (female_captured_has_geo && !female_mm_pending)
        )
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
    NULL
  )
})


test_that("resolved MM follow-up uses the canonical captured parent mark", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "COALESCE(adult_mm_followup_status.F_mm_resight_pending, 0) = 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "adult_parent_identity_status.F_identity_mark",
    fixed = TRUE
  )

  displayed_female_mark <- function(
    followup_pending,
    mm_capture_mark,
    identity_mark,
    post_mm_xx_seen
  ) {
    if (isTRUE(followup_pending) && !is.null(mm_capture_mark)) {
      if (isTRUE(post_mm_xx_seen)) {
        return(paste(mm_capture_mark, "& X-X"))
      }
      return(mm_capture_mark)
    }
    identity_mark
  }

  expect_identical(
    displayed_female_mark(TRUE, "BY-YY", "BY-YY", TRUE),
    "BY-YY & X-X"
  )
  expect_identical(
    displayed_female_mark(FALSE, "BY-YY", "BY-YY", TRUE),
    "BY-YY"
  )
})


test_that("TODO_LIST stays within the known MariaDB CTE limit", {
  sql <- todo_list_view_sql()
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1]]
  cte_lines <- grep("^[A-Za-z0-9_]+ AS \\($", lines, value = TRUE)

  expect_gt(length(cte_lines), 0L)
  expect_lte(length(cte_lines), 63L)
})
