test_that("TODO task assembly consumes the bounded context input", {
  views_sql <- paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
  refresh_sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  task_start <- regexpr(
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW",
      "FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE AS",
      sep = " "
    ),
    views_sql,
    fixed = TRUE
  )[[1L]]
  task_end <- regexpr(
    "/*\n  Refreshable task snapshot",
    substring(views_sql, task_start),
    fixed = TRUE
  )[[1L]]

  expect_gt(task_start, 0L)
  expect_gt(task_end, 0L)

  task_sql <- substring(
    views_sql,
    task_start,
    task_start + task_end - 2L
  )

  expect_match(task_sql, "TODO_NEST_CONTEXT_INPUT", fixed = TRUE)
  expect_no_match(task_sql, "TODO_NEST_CONTEXT context", fixed = TRUE)
  expect_no_match(task_sql, "nest_history AS (", fixed = TRUE)

  expect_match(
    refresh_sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD (",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "INDEX idx_todo_nest_context_nest_reference (nest_id, reference_date)",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "TODO_NEST_CONTEXT_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT",
    fixed = TRUE
  )
  for (stage in c(
    "nest_context",
    "chick_gps_links",
    "parent_status",
    "task_rows",
    "publishing"
  )) {
    expect_match(
      refresh_sql,
      paste0("TODO_REFRESH_STAGE|", stage),
      fixed = TRUE
    )
  }

  context_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  parent_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  link_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  task_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  public_drop <- regexpr(
    "DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST;",
    refresh_sql,
    fixed = TRUE
  )[[1L]]

  expect_gt(context_build, 0L)
  expect_gt(link_build, context_build)
  expect_gt(parent_build, link_build)
  expect_gt(task_build, parent_build)
  expect_gt(public_drop, task_build)

  expect_match(
    refresh_sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD (",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "INDEX idx_parent_chick_gps_capture_nest (capture_pk, nest_id)",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT AS",
      "SELECT *",
      "FROM FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD;",
      sep = "\n"
    ),
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT",
    fixed = TRUE
  )
})


test_that("the refresh worker chooses a configured MariaDB client", {
  app <- load_main_app()

  expect_identical(
    app$env$mariadb_client_command("/custom/bin/mariadb"),
    "/custom/bin/mariadb"
  )
})


test_that("snapshot readiness fails closed when the published table is unavailable", {
  env <- new.env(parent = globalenv())
  env$DBq <- function(...) data.frame(error = "missing snapshot")
  source_app_file(app_file("main", "R", "system_utils.R"), env)

  expect_false(env$todo_snapshot_is_current(as.Date("2026-10-16")))
})


test_that("downloads UI exposes the asynchronous snapshot action", {
  app <- load_main_app()
  html <- as.character(app$ui)

  expect_match(html, "refresh_todo_snapshot", fixed = TRUE)
  expect_match(html, "Build To-do snapshot", fixed = TRUE)
  expect_match(html, "todo_snapshot_status", fixed = TRUE)

  server <- paste(
    readLines(app_file("main", "server.R"), warn = FALSE),
    collapse = "\n"
  )
  system_utils <- paste(
    readLines(app_file("main", "R", "system_utils.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(server, "progress-bar-striped", fixed = TRUE)
  expect_match(server, "This may take several minutes.", fixed = TRUE)
  expect_match(system_utils, "TODO_REFRESH_STAGE|chick_gps_links", fixed = TRUE)
})
