library(testthat)

advisory_guard_source <- function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

extract_advisory_guard <- function(sql) {
  start <- regexpr(
    "SET @todo_schema_lock_name :=",
    sql,
    fixed = TRUE
  )[[1L]]
  end_marker <- "DEALLOCATE PREPARE todo_schema_lock_guard_stmt;"
  end_relative <- regexpr(
    end_marker,
    substring(sql, start),
    fixed = TRUE
  )[[1L]]
  expect_gt(start, 0L)
  expect_gt(end_relative, 0L)
  end <- start + end_relative + nchar(end_marker) - 2L
  substring(sql, start, end)
}

test_that("views and refresh use the same fail-closed advisory guard", {
  sources <- list(
    views = advisory_guard_source(app_file("DATABASE", "views.SQL")),
    refresh = advisory_guard_source(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL")
    )
  )
  guards <- lapply(sources, extract_advisory_guard)

  expect_equal(guards$views, guards$refresh)
  for (guard in guards) {
    expect_match(
      guard,
      "FIELD_2026_BADOatNZ.todo_schema_refresh",
      fixed = TRUE
    )
    expect_match(guard, "IS_USED_LOCK(@todo_schema_lock_name)", fixed = TRUE)
    expect_match(guard, "CONNECTION_ID()", fixed = TRUE)
    expect_match(guard, "GET_LOCK(@todo_schema_lock_name, 0)", fixed = TRUE)
    expect_match(
      guard,
      "COALESCE(@todo_schema_lock_result, 0) = 1",
      fixed = TRUE
    )
    expect_match(guard, "'DO 0'", fixed = TRUE)
    expect_match(guard, "SIGNAL SQLSTATE ''45000''", fixed = TRUE)
    expect_match(guard, "MYSQL_ERRNO = 30001", fixed = TRUE)
    expect_match(guard, "PREPARE todo_schema_lock_guard_stmt", fixed = TRUE)
  }
  expect_no_match(sources$views, "BEGIN NOT ATOMIC", fixed = TRUE)
  expect_no_match(sources$refresh, "BEGIN NOT ATOMIC", fixed = TRUE)
})

test_that("advisory guard placement and release surround each batch", {
  views_sql <- advisory_guard_source(app_file("DATABASE", "views.SQL"))
  refresh_sql <- advisory_guard_source(
    app_file("DATABASE", "refresh_todo_list_snapshot.SQL")
  )

  views_guard <- regexpr(
    "SET @todo_schema_lock_name :=",
    views_sql,
    fixed = TRUE
  )[[1L]]
  views_first_ddl <- regexpr(
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW",
      "  FIELD_2026_BADOatNZ.TODO_RAW_ENCOUNTER_NEST_CONSENSUS AS",
      sep = "\n"
    ),
    views_sql,
    fixed = TRUE
  )[[1L]]
  views_release <- regexpr(
    "RELEASE_LOCK(@todo_schema_lock_name)",
    views_sql,
    fixed = TRUE
  )[[1L]]
  views_last_statement <- regexpr(
    ") overview;",
    views_sql,
    fixed = TRUE
  )[[1L]]

  refresh_guard <- regexpr(
    "SET @todo_schema_lock_name :=",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  refresh_first_ddl <- regexpr(
    "CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS (",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  refresh_release <- regexpr(
    "RELEASE_LOCK(@todo_schema_lock_name)",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  refresh_last_status_write <- regexpr(
    "WHERE refresh_id = @todo_refresh_id;",
    refresh_sql,
    fixed = TRUE
  )[[1L]]

  expect_true(views_guard > 0L)
  expect_true(views_first_ddl > views_guard)
  expect_gt(views_last_statement, 0L)
  expect_true(views_release > views_last_statement)
  expect_true(refresh_guard > 0L)
  expect_true(refresh_first_ddl > refresh_guard)
  expect_true(refresh_release > refresh_last_status_write)
})
