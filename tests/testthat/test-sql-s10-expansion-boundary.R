library(testthat)

s10_source_sql <- function() {
  sql <- paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
  start <- regexpr(
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW",
      "  FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_RESIGHTING_ASSOCIATIONS AS",
      sep = "\n"
    ),
    sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(start, 0L)

  remainder <- substring(sql, start)
  finish <- regexpr(
    "/*\n  Ordinary positive-brood family evidence",
    remainder,
    fixed = TRUE
  )[[1L]]
  expect_gt(finish, 0L)
  substring(remainder, 1L, finish - 1L)
}

test_that("persistent S10 has one bounded parent-proof expansion", {
  sql <- s10_source_sql()

  expect_match(sql, "selected_parent_status AS (", fixed = TRUE)
  expect_match(sql, "parent_sexes AS (", fixed = TRUE)
  expect_match(sql, "CROSS JOIN parent_sexes sexes", fixed = TRUE)
  expect_match(sql, "CASE sexes.sex", fixed = TRUE)
  expect_match(sql, "WHEN 'M' THEN status.M_selected_identity_key", fixed = TRUE)
  expect_match(sql, "ELSE status.F_selected_identity_key", fixed = TRUE)
  expect_no_match(
    sql,
    "  SELECT\n    status.nest_id,\n    'M' AS sex",
    fixed = TRUE
  )
  expect_no_match(
    sql,
    "  SELECT\n    status.nest_id,\n    'F' AS sex",
    fixed = TRUE
  )

  expect_match(
    sql,
    "GROUP BY selected.nest_id, selected.sex, selected.identity_key",
    fixed = TRUE
  )
  expect_match(sql, "selected_parent_proof_with_summary AS (", fixed = TRUE)
  expect_match(
    sql,
    "MAX(proof.association_proof_date)\n      OVER (PARTITION BY proof.nest_id) AS all_parent_proof_date",
    fixed = TRUE
  )
  expect_match(sql, "AS has_M_proof", fixed = TRUE)
  expect_match(sql, "AS has_F_proof", fixed = TRUE)
  expect_match(
    sql,
    "JOIN selected_parent_proof_with_summary proof",
    fixed = TRUE
  )
  expect_match(sql, "proof.nest_id,", fixed = TRUE)
  expect_match(sql, "proof.has_M_proof = 1", fixed = TRUE)
  expect_match(sql, "proof.has_F_proof = 1", fixed = TRUE)
  expect_no_match(sql, "JOIN selected_parent_identities selected", fixed = TRUE)
  expect_no_match(sql, "selected_parent_proof_summary", fixed = TRUE)
  expect_no_match(sql, "resolved_negative_nests", fixed = TRUE)
  expect_no_match(sql, "proof[[:space:]]*\\.[[:space:]]*\\*")
})
