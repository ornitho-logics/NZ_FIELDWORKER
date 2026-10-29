test_that("H-photo input is an explicit snapshot boundary during view installation", {
  sql <- paste(
    readLines(
      app_file("DATABASE", "views.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  start <- regexpr(
    "TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT is the explicit two-column",
    sql,
    fixed = TRUE
  )[[1L]]
  finish <- regexpr(
    "TODO_PARENT_STATUS is the task-facing materialization boundary",
    substring(sql, start),
    fixed = TRUE
  )[[1L]]

  expect_gt(start, 0L)
  expect_gt(finish, 0L)
  h_sql <- substring(sql, start, start + finish - 2L)

  expect_match(
    h_sql,
    paste(
      "CREATE TABLE IF NOT EXISTS",
      "  FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT (",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_match(h_sql, "nest_id VARCHAR(6)", fixed = TRUE)
  expect_match(h_sql, "n_hiding_spot_photos BIGINT NULL", fixed = TRUE)
  expect_match(
    h_sql,
    "INDEX idx_todo_hiding_spot_photo_context_nest (nest_id)",
    fixed = TRUE
  )
  expect_match(
    h_sql,
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT AS",
      "SELECT *",
      "FROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT;",
      sep = "\n"
    ),
    fixed = TRUE
  )

  for (forbidden in c(
    "RESIGHTINGS_H_BROOD_ASSOCIATIONS",
    "TODO_PARENT_CHICK_RESIGHTING_ASSOCIATIONS",
    "TODO_CHICK_CAPTURE_TARGETS_INPUT",
    "GPS_POINTS",
    "WITH sr AS (",
    "COUNT(DISTINCT target.ring_key)"
  )) {
    expect_false(grepl(forbidden, h_sql, fixed = TRUE))
  }
})
