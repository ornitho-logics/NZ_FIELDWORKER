exercise_append_app <- function(app) {
  written <- new.env(parent = emptyenv())
  written$n <- 0
  written$x <- NULL
  written$table <- NULL

  rows <- data.table::data.table(id = 1, value = "ok")
  globals <- app_globals(
    app$env,
    c(
      "table_name",
      "exclude_columns",
      "n_empty_lines",
      "prefilled",
      "dropdowns"
    )
  )

  testthat::local_mocked_bindings(
    dbWriteTable = function(conn, name, value, append, row.names, ...) {
      written$n <- written$n + 1
      written$x <- data.table::copy(value)
      written$table <- name

      expect_true(append)
      expect_false(row.names)

      TRUE
    },
    dbDisconnect = function(conn, ...) TRUE,
    .package = "DBI"
  )

  testthat::local_mocked_bindings(
    app_global = mock_app_globals(globals),
    table_has_nov = function(...) FALSE,
    column_comment = function(...) data.table::data.table(),
    hot_append_table = function(...) rows,
    save_from_hot = function(...) rows,
    validation_issues = empty_validation_issues,
    db_con = function(...) structure(list(), class = "mock_db_connection"),
    appended_rows_feedback = function(...) NULL,
    server_cheatsheet_modal = function(...) NULL,
    runjs = function(...) NULL,
    disable = function(...) NULL,
    addClass = function(...) NULL,
    insertUI = function(...) NULL,
    removeUI = function(...) NULL,
    actionBttn = function(...) NULL,
    br = function(...) NULL,
    icon = function(...) NULL,
    .package = "DataEntry"
  )

  shiny::testServer(app$server, {
    session$setInputs(saveButton = 1)
    session$flushReact()

    expect_identical(written$n, 1)
    expect_identical(written$table, app$env$table_name)
    expect_equal(written$x, rows)
  })
}


exercise_edit_table_app <- function(app) {
  saved <- new.env(parent = emptyenv())
  saved$n <- 0
  saved$x <- NULL
  saved$table <- NULL

  rows <- data.table::data.table(id = 1, value = "ok")
  globals <- app_globals(
    app$env,
    c("table_name", "backupdir", "n_empty_lines")
  )
  globals$exclude_columns <- character()
  globals$fixed_rows_top <- 0

  testthat::local_mocked_bindings(
    app_global = mock_app_globals(globals),
    table_has_nov = function(...) FALSE,
    column_comment = function(...) data.table::data.table(),
    hot_db_table = function(...) rows,
    save_from_hot = function(...) rows,
    validation_issues = empty_validation_issues,
    replace_db_table = function(x, table_name, backupdir) {
      saved$n <- saved$n + 1
      saved$x <- data.table::copy(x)
      saved$table <- table_name
      file.path(backupdir, paste0(table_name, ".csv"))
    },
    updated_table_feedback = function(...) NULL,
    server_cheatsheet_modal = function(...) NULL,
    runjs = function(...) NULL,
    .package = "DataEntry"
  )

  shiny::testServer(app$server, {
    session$setInputs(saveButton = 1)
    session$flushReact()

    expect_identical(saved$n, 1)
    expect_identical(saved$table, app$env$table_name)
    expect_equal(saved$x, rows)
  })
}


exercise_edit_rcode_app <- function(app) {
  saved <- new.env(parent = emptyenv())
  saved$n <- 0
  saved$x <- NULL
  saved$table <- NULL

  rows <- data.table::data.table(
    id = "example",
    code = "list(data.frame(rowid = 1, variable = 'a', reason = 'bad'))"
  )
  data.table::setnames(
    rows,
    c("id", "code"),
    c(app$env$id_column, app$env$code_column)
  )

  globals <- app_globals(
    app$env,
    c(
      "table_name",
      "backupdir",
      "n_empty_lines",
      "id_column",
      "code_column",
      "code_column_width",
      "code_row_height"
    )
  )
  globals$exclude_columns <- if (
    exists(
      "exclude_columns",
      envir = app$env,
      inherits = FALSE
    )
  ) {
    app$env$exclude_columns
  } else {
    character()
  }
  globals$fixed_rows_top <- 0

  testthat::local_mocked_bindings(
    app_global = mock_app_globals(globals),
    column_comment = function(...) data.table::data.table(),
    hot_db_table = function(...) rows,
    save_from_hot = function(...) rows,
    replace_db_table = function(x, table_name, backupdir) {
      saved$n <- saved$n + 1
      saved$x <- data.table::copy(x)
      saved$table <- table_name
      file.path(backupdir, paste0(table_name, ".csv"))
    },
    updated_table_feedback = function(...) NULL,
    server_cheatsheet_modal = function(...) NULL,
    runjs = function(...) NULL,
    .package = "DataEntry"
  )

  shiny::testServer(app$server, {
    session$setInputs(saveButton = 1)
    session$flushReact()

    expect_identical(saved$n, 1)
    expect_identical(saved$table, app$env$table_name)
    expect_equal(saved$x, rows)
  })
}


for (app_name in names(dataentry_app_specs)) {
  local({
    name <- app_name
    spec <- dataentry_app_specs[[name]]

    test_that(paste("DataEntry server flow:", name), {
      app <- load_dataentry_app(name)

      switch(
        spec$kind,
        append = exercise_append_app(app),
        edit_table = exercise_edit_table_app(app),
        edit_rcode = exercise_edit_rcode_app(app)
      )
    })
  })
}
