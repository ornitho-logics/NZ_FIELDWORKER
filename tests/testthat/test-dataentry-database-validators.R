test_that("entry apps load all database inspector rows instead of local references", {
  skip_if_not_installed("DataEntry")

  calls <- character()
  testthat::local_mocked_bindings(
    inspectors_table_exists = function() TRUE,
    db_get = function(query, ..., params = NULL) {
      expect_match(query, "WHERE table_name = ?", fixed = TRUE)
      expect_length(params, 1)
      calls <<- c(calls, params[[1]])
      data.frame(inspector = c(
        "list(data.frame(rowid = 1L, variable = 'example', reason = 'DB hard'))",
        "list(data.frame(rowid = 2L, variable = 'example', reason = 'DB warning'))"
      ))
    },
    .package = "DataEntry"
  )

  tables <- names(Filter(function(spec) spec$validation, dataentry_app_specs))
  loader <- getFromNamespace("inspector_loader", "DataEntry")
  for (table in tables) {
    withr::with_dir(app_file("DataEntry", table), {
      expect_false(file.exists("inspector.R"), info = table)
      expect_true(file.exists("inspector_reference.R"), info = table)
      rules <- loader(table)(data.frame(example = "invented"))
      expect_identical(vapply(rules, function(rule) rule$reason, ""),
                       c("DB hard", "DB warning"), info = table)
    })
  }
  expect_identical(calls, tables)
})
