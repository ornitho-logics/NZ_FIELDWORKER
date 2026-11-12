# Parse source and use invented files only; never evaluate field validators.
catalog_root <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
catalog_env <- new.env(parent = baseenv())
sys.source(file.path(catalog_root, "tools", "validation", "build_validator_catalog.R"),
           envir = catalog_env)

test_that("catalogs cover every named current check and match source", {
  skip_if_not_installed("jsonlite")
  actual <- catalog_env$validator_catalog(catalog_root)
  expect_length(actual$rules, 265L)
  expect_identical(unname(vapply(actual$sources, `[[`, integer(1), "rules")),
                   c(98L, 26L, 53L, 6L, 57L, 25L))
  keys <- vapply(actual$rules, `[[`, "", "key")
  expect_false(anyDuplicated(keys) > 0L)
  for (rule in actual$rules) {
    expect_true(nzchar(rule$title))
    expect_gte(rule$line_end, rule$line_start)
  }
  output <- catalog_env$validator_catalog_outputs(catalog_root)
  for (path in names(output)) {
    saved <- paste0(paste(readLines(file.path(catalog_root, path), encoding = "UTF-8"),
                         collapse = "\n"), "\n")
    expect_identical(saved, output[[path]])
  }
  archived <- catalog_env$validator_catalog(catalog_root, archived = TRUE)
  expect_length(archived$rules, 186L)
  expect_length(archived$sources, 12L)
  expect_identical(archived$sources$OBSERVERS_warning$rules, 0L)
  expect_false(anyDuplicated(vapply(archived$rules, `[[`, "", "key")) > 0L)
})

test_that("catalog parsing never runs inspector expressions and rejects duplicate IDs", {
  root <- withr::local_tempdir()
  tables <- c("CAPTURES", "EGGS", "NESTS", "OBSERVERS", "RESIGHTINGS", "RESIGHTINGS_PUBLIC")
  for (table in tables) {
    dir.create(file.path(root, "DataEntry", table), recursive = TRUE)
    writeLines(c(
      "list(",
      "  # Invented check.",
      "  { stop('MUST NOT EVALUATE'); x[, .(reason = 'Invented message.')] } |>",
      "    try_validator(nam = 'val1')",
      ")"
    ), file.path(root, "DataEntry", table, "inspector.R"))
  }
  result <- catalog_env$validator_catalog(root)
  expect_length(result$rules, 6L)
  expect_identical(result$rules[[1L]]$title, "Invented check.")
  expect_contains(result$rules[[1L]]$messages, "Invented message.")
  writeLines("list(try_validator(NULL, nam='val1'), try_validator(NULL, nam='val1'))",
             file.path(root, "DataEntry", "CAPTURES", "inspector.R"))
  expect_error(catalog_env$validator_catalog(root), "duplicate rule ID", fixed = TRUE)
})
