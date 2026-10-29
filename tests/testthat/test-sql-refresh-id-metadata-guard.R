library(testthat)

refresh_id_guard_source <- function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

test_that("views and refresh guard canonical refresh_id metadata", {
  sources <- list(
    views = refresh_id_guard_source(app_file("DATABASE", "views.SQL")),
    refresh = refresh_id_guard_source(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL")
    )
  )

  for (source_sql in sources) {
    expect_match(
      source_sql,
      "SET @todo_status_refresh_id_is_canonical := (",
      fixed = TRUE
    )
    expect_match(source_sql, "LOWER(DATA_TYPE) = 'bigint'", fixed = TRUE)
    expect_match(
      source_sql,
      "INSTR(LOWER(COLUMN_TYPE), 'unsigned') > 0",
      fixed = TRUE
    )
    expect_match(source_sql, "IS_NULLABLE = 'NO'", fixed = TRUE)
    expect_match(
      source_sql,
      "INSTR(LOWER(COALESCE(EXTRA, '')), 'auto_increment') > 0",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "SET @todo_status_refresh_id_type_sql := IF(",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "SET @todo_status_refresh_id_auto_sql := IF(",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "PREPARE todo_status_refresh_id_type_stmt",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "PREPARE todo_status_refresh_id_auto_stmt",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "UPDATE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS",
      fixed = TRUE
    )
    expect_match(source_sql, "@todo_status_primary_key_exists", fixed = TRUE)
    expect_match(source_sql, "@todo_status_index_exists", fixed = TRUE)
    expect_no_match(
      source_sql,
      paste(
        "ALTER TABLE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS",
        "  MODIFY refresh_id BIGINT UNSIGNED NOT NULL;",
        sep = "\n"
      ),
      fixed = TRUE
    )
    expect_no_match(
      source_sql,
      paste(
        "ALTER TABLE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS",
        "  MODIFY refresh_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT;",
        sep = "\n"
      ),
      fixed = TRUE
    )
  }
})

test_that("refresh documentation distinguishes public views from local resolver", {
  sql <- refresh_id_guard_source(
    app_file("DATABASE", "refresh_todo_list_snapshot.SQL")
  )

  expect_match(
    sql,
    "public compatibility views retain their live",
    fixed = TRUE
  )
  expect_match(
    sql,
    "connection-local canonical family resolver",
    fixed = TRUE
  )
  expect_no_match(
    sql,
    "same-occasion family resolver is never",
    fixed = TRUE
  )
})
