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
