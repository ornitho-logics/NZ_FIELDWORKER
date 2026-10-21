test_that("TODO task assembly consumes the bounded context input", {
  refresh_sql <- paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  task_start <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD (",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  task_end <- regexpr(
    "SELECT 'TODO_REFRESH_STAGE|publishing'",
    substring(refresh_sql, task_start),
    fixed = TRUE
  )[[1L]]

  expect_gt(task_start, 0L)
  expect_gt(task_end, 0L)

  task_sql <- substring(
    refresh_sql,
    task_start,
    task_start + task_end - 2L
  )

  expect_match(task_sql, "TODO_NEST_CONTEXT_INPUT", fixed = TRUE)
  expect_no_match(task_sql, "TODO_NEST_CONTEXT context", fixed = TRUE)
  expect_no_match(task_sql, "nest_history AS (", fixed = TRUE)
  expect_match(task_sql, "TODO_BROOD_CONTEXT_INPUT", fixed = TRUE)
  expect_match(task_sql, "TODO_CHICK_CAPTURE_CONTEXT_INPUT", fixed = TRUE)
  expect_match(task_sql, "TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT", fixed = TRUE)
  expect_no_match(task_sql, "BROODS_LATEST b", fixed = TRUE)
  expect_no_match(task_sql, "BROODS_LATEST brood_evidence", fixed = TRUE)
  expect_match(task_sql, "brood_context AS (", fixed = TRUE)
  expect_match(
    task_sql,
    "FROM FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_INPUT\n),\nlatest_nests AS",
    fixed = TRUE
  )
  expect_false(
    grepl(
      "FROM FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_INPUT b",
      task_sql,
      fixed = TRUE
    )
  )
  expect_match(task_sql, "task_context AS (", fixed = TRUE)
  expect_match(
    task_sql,
    "FROM FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_INPUT\n),\nbrood_context AS",
    fixed = TRUE
  )
  expect_match(
    task_sql,
    "FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT\n),",
    fixed = TRUE
  )
  expect_match(
    task_sql,
    "FROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT\n),",
    fixed = TRUE
  )
  expect_false(
    grepl(
      "FROM FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_INPUT context",
      task_sql,
      fixed = TRUE
    )
  )

  resighting_start <- regexpr(
    "todo_parent_resighting_existing AS (",
    task_sql,
    fixed = TRUE
  )[[1L]]
  resighting_end <- regexpr(
    "todo_parent_resighting AS (",
    substring(task_sql, resighting_start),
    fixed = TRUE
  )[[1L]]
  expect_gt(resighting_start, 0L)
  expect_gt(resighting_end, 0L)
  resighting_sql <- substring(
    task_sql,
    resighting_start,
    resighting_start + resighting_end - 2L
  )
  expect_equal(
    length(strsplit(resighting_sql, "\n  JOIN adult_parent_status association\n", fixed = TRUE)[[1L]]) - 1L,
    1L
  )
  expect_no_match(
    resighting_sql,
    "LEFT JOIN adult_parent_status\n",
    fixed = TRUE
  )

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
  expect_no_match(
    refresh_sql,
    "INDEX idx_todo_nest_context_nest (nest_id),",
    fixed = TRUE
  )
  expect_match(refresh_sql, "capture_gate_clutch_size", fixed = TRUE)
  expect_match(
    refresh_sql,
    "capture_gate_clutch_start_datetime",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD (",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "CREATE TABLE FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD (",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "INDEX idx_todo_chick_capture_context_nest (nest_id)",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "INDEX idx_todo_brood_context_nest_reference (nest_id, reference_date)",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "TODO_NEST_CONTEXT_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT",
    fixed = TRUE
  )
  for (stage in c(
    "nest_context",
    "brood_context",
    "chick_capture_context",
    "hiding_spot_photos",
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
  expect_gt(context_build, 0L)
  brood_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  chick_capture_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  hiding_photo_build <- regexpr(
    "INSERT INTO FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD",
    refresh_sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(link_build, context_build)
  expect_gt(brood_build, context_build)
  expect_gt(chick_capture_build, brood_build)
  expect_gt(hiding_photo_build, chick_capture_build)
  expect_gt(link_build, brood_build)
  expect_gt(link_build, hiding_photo_build)
  expect_gt(link_build, chick_capture_build)
  expect_gt(parent_build, link_build)
  expect_gt(task_build, parent_build)

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
  expect_match(
    refresh_sql,
    "TODO_BROOD_CONTEXT_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD\n    TO FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT",
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
  expect_match(
    system_utils,
    "TODO_REFRESH_STAGE|chick_capture_context",
    fixed = TRUE
  )
  expect_match(
    system_utils,
    "TODO_REFRESH_STAGE|hiding_spot_photos",
    fixed = TRUE
  )
})
