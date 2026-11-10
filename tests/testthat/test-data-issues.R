data_issues_test_env <- function() {
  env <- new.env(parent = globalenv())
  for (package in c("data.table", "stringr", "shiny", "DT")) {
    library(package, character.only = TRUE)
  }
  sys.source(app_file("main", "R", "data_issues.R"), env)
  env
}


write_issue_inspector <- function(directory, table, code) {
  path <- file.path(directory, table)
  dir.create(path)
  writeLines(code, file.path(path, "inspector.R"))
}


test_that("the reviewed catalog contains only four tables and no missing-data checks", {
  env <- data_issues_test_env()
  catalog <- env$data_issues_catalog()
  expect_identical(names(catalog), c("CAPTURES", "NESTS", "EGGS", "RESIGHTINGS"))
  for (table in names(catalog)) {
    rules <- env$data_issues_rules(
      app_file("DataEntry", table, "inspector.R"), catalog[[table]]
    )
    expect_true(length(rules) > 0)
    text <- paste(vapply(rules, function(rule) paste(deparse(rule), collapse = " "), ""),
                  collapse = " ")
    expect_false(str_detect(text, "CAPTURES_ARCHIVE|NESTS_LATEST|GPS_POINTS"))
    expect_false(any(str_detect(names(rules),
      "^Required|must be present|has been uploaded|^Require linked|^Keep the validation")))
  }
})


test_that("only populated wrong values appear, with the correct observer and key", {
  env <- data_issues_test_env()
  directory <- withr::local_tempdir()
  write_issue_inspector(directory, "CAPTURES", c(
    'list(',
    '  # Required fields.',
    '  is.na_validator(x[, .(ring, rowid)]) |> try_validator(nam = "val1"),',
    '  # Check ring codes.',
    '  is.element_validator(x[, .(ring, rowid)],',
    '    v = data.table(variable = "ring", set = list("FAKE1")),',
    '    reason = "Invalid ring.") |> try_validator(nam = "val900")',
    ')'
  ))
  report <- env$data_issues_run(directory, function(...) {
    data.table(pk = c(31, 74, 85, 96), ring = c("FAKE1", "", "bad", NA),
               observer = c("AA", "BB", "CC", "DD"), date = as.Date("2026-11-10"))
  }, catalog = list(CAPTURES = "Check ring codes."))
  expect_equal(report$issues$pk, "85")
  expect_equal(report$issues$observer, "CC")
  expect_equal(report$issues$date, "2026-11-10")
  expect_equal(report$issues$value, "bad")
  expect_equal(report$issues$issue, "Invalid ring.")
  expect_equal(nrow(report$failures), 0)
})


test_that("lookup failures stay outside the correction table and checking continues", {
  env <- data_issues_test_env()
  directory <- withr::local_tempdir()
  write_issue_inspector(directory, "CAPTURES", c(
    'list(',
    '  # Compare records.',
    '  {',
    '    tryCatch(db_get("SELECT ring FROM MISSING_VIEW"), error = function(e) NULL)',
    '    data.table(rowid = 1, variable = "ring", reason = "Unverified.")',
    '  } |> try_validator(nam = "val1")',
    ')'
  ))
  write_issue_inspector(directory, "NESTS", c(
    'list(',
    '  # Check a value.',
    '  data.table(rowid = 1, variable = "ring", reason = "Wrong value.")',
    ')'
  ))
  read <- function(query, ..., params = NULL) {
    if (str_detect(query, "MISSING_VIEW")) stop("private database error")
    data.table(pk = 7, ring = "FAKE1", observer = "AA", date = "2026-11-10")
  }
  report <- env$data_issues_run(directory, read, catalog = list(
    CAPTURES = "Compare records.", NESTS = "Check a value."
  ))
  expect_equal(nrow(report$failures), 1)
  expect_equal(report$issues$table, "NESTS")
  expect_equal(report$issues$issue, "Wrong value.")
  expect_false(any(str_detect(unlist(report$failures), "private")))
})


test_that("shared lookups are cached without hiding existing records", {
  env <- data_issues_test_env()
  directory <- withr::local_tempdir()
  write_issue_inspector(directory, "EGGS", c(
    'list(',
    '  # Compare egg counts.',
    '  {',
    '    a <- db_get("SELECT clutch_size FROM NESTS")',
    '    b <- db_get("SELECT clutch_size FROM NESTS")',
    '    x[egg_id > a$clutch_size[1], .(rowid, variable = "egg_id", reason = "Too high.")]',
    '  } |> try_validator(nam = "val1")',
    ')'
  ))
  calls <- character()
  read <- function(query, ..., params = NULL) {
    calls <<- c(calls, query)
    if (!str_starts(query, fixed("SELECT * FROM EGGS"))) return(data.table(clutch_size = 2))
    data.table(pk = 88, egg_id = 3, observer = "AA")
  }
  report <- env$data_issues_run(directory, read,
                                catalog = list(EGGS = "Compare egg counts."))
  expect_equal(sum(!str_starts(calls, fixed("SELECT * FROM EGGS"))), 1)
  expect_true(all(str_detect(calls, fixed("site = 'CR'"))))
  expect_equal(report$issues$pk, "88")
  expect_equal(nrow(report$failures), 0)
})


test_that("duplicate egg checks require an identified visit", {
  env <- data_issues_test_env()
  read <- function(query, ..., params = NULL) {
    if (!str_starts(query, fixed("SELECT * FROM EGGS"))) return(data.table(
      nest_id = "A0101", date = "2026-11-10", time_visit = "09:00:00",
      observer = "AA", clutch_size = 3
    ))
    data.table(pk = 1:4, nest_id = c("A0101", "A0101", NA, NA),
               date = "2026-11-10", time_visit = "09:00:00", observer = "AA",
               egg_id = 1)
  }
  report <- env$data_issues_run(app_file("DataEntry"), read, catalog = list(
    EGGS = "egg_id must be unique within an EGGS event."
  ))
  expect_equal(sort(report$issues$pk), c("1", "2"))
  expect_equal(nrow(report$failures), 0)
})


test_that("Cass River scoping covers all four tables and links eggs without duplicating them", {
  env <- data_issues_test_env()
  directory <- withr::local_tempdir()
  tables <- names(env$data_issues_catalog())
  for (table in tables) write_issue_inspector(directory, table, c(
    'list(',
    '  # Check a value.',
    '  x[, .(rowid, variable = "ring", reason = "Wrong value.")]',
    ')'
  ))
  calls <- character()
  report <- env$data_issues_run(directory, function(query, ..., params = NULL) {
    calls <<- c(calls, query)
    data.table(pk = 7, ring = "FAKE1", observer = "AA")
  }, catalog = setNames(rep(list("Check a value."), length(tables)), tables))
  expect_equal(report$tables, tables)
  expect_true(all(str_detect(calls, fixed("site = 'CR'"))))
  eggs <- calls[str_detect(calls, "SELECT \\* FROM EGGS")]
  expect_length(eggs, 1)
  expect_match(eggs, "WHERE EXISTS", fixed = TRUE)
  expect_match(eggs, "NESTS.nest_id = EGGS.nest_id", fixed = TRUE)
  expect_match(eggs, "NESTS.species = EGGS.species", fixed = TRUE)
  expect_false(str_detect(eggs, "EGGS.site"))
  expect_equal(nrow(report$issues), 4)
})


test_that("opening the tab refreshes issues and other tabs do not run checks", {
  env <- data_issues_test_env()
  calls <- 0
  env$data_issues_run <- function(...) {
    calls <<- calls + 1
    list(issues = env$data_issues_empty(), tables = names(env$data_issues_catalog()),
         failures = data.table(table = "EGGS", check = "Count"),
         checked_at = as.POSIXct("2026-11-10 12:00:00", tz = "UTC"))
  }
  shiny::testServer(env$data_issues_server, {
    session$flushReact()
    expect_equal(calls, 0)
    session$setInputs(main = "intro")
    expect_equal(calls, 0)
    session$setInputs(main = "data_issues")
    expect_equal(calls, 1)
    expect_match(output$data_issues_status, "0 issues across 4 tables")
    expect_match(output$data_issues_status, "results incomplete")
    expect_true(nzchar(output$data_issues_table))
    session$setInputs(main = "show_tables")
    expect_equal(calls, 1)
    session$setInputs(main = "data_issues")
    expect_equal(calls, 2)
  })
})
