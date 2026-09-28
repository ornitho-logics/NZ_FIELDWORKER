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

  expect_match(sql, "IN ('F', 'I', 'H')", fixed = TRUE)
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


test_that("TODO_LIST stays within the known MariaDB CTE limit", {
  sql <- todo_list_view_sql()
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1]]
  cte_lines <- grep("^[A-Za-z0-9_]+ AS \\($", lines, value = TRUE)

  expect_gt(length(cte_lines), 0L)
  expect_lte(length(cte_lines), 63L)
})
