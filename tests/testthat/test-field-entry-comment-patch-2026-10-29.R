library(testthat)

test_that("field-entry comment patch is metadata-only and guarded", {
  sql <- paste(
    readLines(
      app_file("DATABASE", "update_field_entry_hints_2026-10-29.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  code <- paste(
    strsplit(sql, "\n", fixed = TRUE)[[1L]][
      !grepl("^\\s*(--|/\\*|\\*)", strsplit(sql, "\n", fixed = TRUE)[[1L]])
    ],
    collapse = "\n"
  )

  expect_match(sql, "information_schema.COLUMNS", fixed = TRUE)
  expect_match(sql, "COALESCE(DATABASE(), '') <> 'FIELD_2026_BADOatNZ'", fixed = TRUE)
  expect_match(sql, "c.COLUMN_TYPE", fixed = TRUE)
  expect_match(sql, "c.CHARACTER_SET_NAME", fixed = TRUE)
  expect_match(sql, "c.COLLATION_NAME", fixed = TRUE)
  expect_match(sql, "c.IS_NULLABLE <> 'YES'", fixed = TRUE)
  expect_match(
    sql,
    "c.COLUMN_DEFAULT IS NULL\n              OR UPPER(TRIM(CAST(c.COLUMN_DEFAULT AS CHAR))) = 'NULL'",
    fixed = TRUE
  )
  expect_match(sql, "c.EXTRA, '') <> ''", fixed = TRUE)
  expect_match(sql, "c.IS_GENERATED, 'NEVER') <> 'NEVER'", fixed = TRUE)

  expected_targets <- c(
    "CAPTURES.*nest_id",
    "CAPTURES.*gps_id",
    "CAPTURES.*gps_point",
    "EGGS.*nest_id",
    "NESTS.*nest_id",
    "RESIGHTINGS.*gps_id",
    "RESIGHTINGS.*gps_point",
    "RESIGHTINGS.*rclass",
    "RESIGHTINGS.*UR",
    "RESIGHTINGS.*ring",
    "RESIGHTINGS.*nest_id",
    "RESIGHTINGS.*photo_start",
    "RESIGHTINGS.*photo_end"
  )
  for (target in expected_targets) {
    expect_match(sql, target)
  }

  expect_match(sql, ", ALGORITHM=INSTANT, LOCK=NONE", fixed = TRUE)
  expect_match(sql, "rollback_sql", fixed = TRUE)
  expect_match(sql, "field_entry_comment_verification_bad", fixed = TRUE)
  expect_match(sql, "metadata verification did not match all 13 expected comments", fixed = TRUE)
  expect_match(sql, "ALTER TABLE is not transactional", fixed = TRUE)
  expect_match(sql, "T?</b> (geolocator tag with unreadable spacer colour; RESIGHTINGS only; bare <b>T</b> is invalid)", fixed = TRUE)
  expect_match(sql, "A new age-C H event must have a valid nest_id explicitly", fixed = TRUE)
  expect_match(sql, "historical derived-association compatibility", fixed = TRUE)

  expect_false(grepl("^\\s*(CREATE|DROP|INSERT|UPDATE|DELETE)\\s", code, perl = TRUE))
  expect_false(grepl("CREATE (OR REPLACE )?VIEW", code, fixed = FALSE))

  guard_position <- regexpr(
    "PREPARE field_entry_comment_guard_stmt",
    sql,
    fixed = TRUE
  )[[1L]]
  alter_position <- regexpr(
    "PREPARE field_entry_comment_captures_stmt",
    sql,
    fixed = TRUE
  )[[1L]]
  rollback_position <- regexpr(
    "SELECT\n  CONCAT(\n    'ALTER TABLE",
    sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(guard_position, 0L)
  expect_gt(alter_position, guard_position)
  expect_gt(rollback_position, guard_position)
})
