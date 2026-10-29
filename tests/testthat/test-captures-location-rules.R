library(testthat)
library(data.table)

captures_hard_path <- app_file(
  "notes",
  "codex_proposals",
  "validator_sandbox",
  "inspector_lists_by_table",
  "CAPTURES_hard.R"
)

captures_hard_exprs <- parse(file = captures_hard_path)[[1L]]

find_captures_validator <- function(name) {
  hits <- which(vapply(
    captures_hard_exprs[-1L],
    function(expr) grepl(
      paste0('nam = "', name, '"'),
      paste(deparse(expr), collapse = " "),
      fixed = TRUE
    ),
    logical(1)
  ))
  expect_length(hits, 1L)
  captures_hard_exprs[[hits + 1L]]
}

run_captures_validator <- function(name, rows, refs = list(), db_failure = FALSE) {
  env <- new.env(parent = globalenv())
  env$x <- as.data.table(rows)
  env$try_validator <- function(expr, nam = NULL) {
    eval(substitute(expr), parent.frame())
  }
  env$db_get <- function(sql) {
    if (isTRUE(db_failure)) {
      stop("mock database unavailable")
    }
    if (grepl("RESIGHTINGS", sql, fixed = TRUE)) {
      return(refs[["RESIGHTINGS"]] %||% data.table())
    }
    if (grepl("CAPTURES", sql, fixed = TRUE)) {
      return(refs[["CAPTURES"]] %||% data.table())
    }
    data.table()
  }
  eval(find_captures_validator(name), envir = env)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

capture_row <- function(
  age = "C",
  capture_status = "R",
  nest_id = "B0208",
  gps_id = NA_character_,
  gps_point = NA_character_,
  caught_with = NA_character_
) {
  data.table(
    date = "2026-10-24", caught = "10:00", species = "BADO", site = "CR",
    observer = "ADO", capture_status = capture_status, capture_method = "TB",
    nest_id = nest_id, caught_with = caught_with, parents = "MF",
    gps_id = gps_id, gps_point = gps_point, field_sex = if (age == "A") "M" else "U",
    age = age, ring = "CP12345", UL = "X", LL = "B", UR = "M", LR = "X"
  )
}

test_that("positive-nest age-C F captures may use the nest location", {
  result <- run_captures_validator(
    "CAP_001 mandatory",
    capture_row(capture_status = "F")
  )
  expect_false(any(result$variable %in% c("gps_id", "gps_point")))
})

test_that("positive-nest age-C R and C captures require a complete GPS pair", {
  for (status in c("R", "C")) {
    result <- run_captures_validator(
      "CAP_001 mandatory",
      capture_row(capture_status = status)
    )
    expect_true(all(c("gps_id", "gps_point") %in% result$variable), info = status)

    complete <- run_captures_validator(
      "CAP_001 mandatory",
      capture_row(capture_status = status, gps_id = "4", gps_point = "210")
    )
    expect_false(any(complete$variable %in% c("gps_id", "gps_point")), info = status)
  }
})

test_that("an adult captured with chicks at a positive nest requires a complete GPS pair", {
  result <- run_captures_validator(
    "CAP_001 mandatory",
    capture_row(
      age = "A", capture_status = "F", caught_with = "2C",
      gps_id = NA_character_, gps_point = NA_character_
    )
  )
  expect_true(all(c("gps_id", "gps_point") %in% result$variable))
})

test_that("CAPTURES rejects the obsolete NO_NEST sentinel", {
  result <- run_captures_validator(
    "CAP_009 nest id",
    capture_row(nest_id = "NO_NEST", gps_id = "4", gps_point = "210")
  )
  expect_true(any(result$variable == "nest_id"))
  expect_true(any(grepl("no longer accepted", result$reason, ignore.case = TRUE)))
})

test_that("same-occasion chick captures must use one nest_id", {
  for (status in c("R", "C")) {
    rows <- rbind(
      capture_row(capture_status = status, nest_id = "B0208", gps_id = "4", gps_point = "210"),
      capture_row(capture_status = status, nest_id = "B0209", gps_id = "4", gps_point = "210")
    )
    result <- run_captures_validator("CAP_009B family nest ids", rows)
    expect_true(all(c(1L, 2L) %in% result$rowid[result$variable == "nest_id"]), info = status)
    expect_true(any(grepl("same family occasion", result$reason, fixed = TRUE)), info = status)
  }
})

test_that("CAPTURES submitted after a saved RESIGHTINGS family row is checked", {
  current <- capture_row(capture_status = "R", nest_id = "B0209", gps_id = "4", gps_point = "210")
  saved_parent <- data.table(
    pk = 501, date = "2026-10-24", site = "CR", nest_id = "B0208",
    gps_id = "4", gps_point = "210", age = "A", behav = "AC"
  )
  result <- run_captures_validator(
    "CAP_009B family nest ids", current,
    refs = list(RESIGHTINGS = saved_parent)
  )
  expect_true(any(result$rowid == 1L & result$variable == "nest_id"))
})

test_that("matching IDs and separate occasions remain valid", {
  current <- capture_row(capture_status = "R", nest_id = "B0208", gps_id = "4", gps_point = "210")
  saved_parent <- data.table(
    pk = 502, date = "2026-10-24", site = "CR", nest_id = "B0208",
    gps_id = "4", gps_point = "210", age = "A", behav = "BC"
  )
  expect_false(any(run_captures_validator(
    "CAP_009B family nest ids", current,
    refs = list(RESIGHTINGS = saved_parent)
  )$variable == "nest_id"))

  separate_date <- copy(saved_parent)
  separate_date[, date := "2026-10-25"]
  expect_false(any(run_captures_validator(
    "CAP_009B family nest ids", current,
    refs = list(RESIGHTINGS = separate_date)
  )$variable == "nest_id"))

  separate_site <- copy(saved_parent)
  separate_site[, site := "MR"]
  expect_false(any(run_captures_validator(
    "CAP_009B family nest ids", current,
    refs = list(RESIGHTINGS = separate_site)
  )$variable == "nest_id"))

  separate_gps <- copy(saved_parent)
  separate_gps[, gps_point := "211"]
  expect_false(any(run_captures_validator(
    "CAP_009B family nest ids", current,
    refs = list(RESIGHTINGS = separate_gps)
  )$variable == "nest_id"))

  edited <- copy(current)
  edited[, pk := 777]
  saved_self <- data.table(
    pk = 777, date = "2026-10-24", site = "CR", nest_id = "B0209",
    gps_id = "4", gps_point = "210", age = "C", caught_with = NA_character_
  )
  expect_false(any(run_captures_validator(
    "CAP_009B family nest ids", edited,
    refs = list(CAPTURES = saved_self)
  )$variable == "nest_id"))
})

test_that("negative and mixed family IDs are checked, including saved CAPTURES", {
  negative_rows <- rbind(
    capture_row(capture_status = "R", nest_id = "-B0208", gps_id = "4", gps_point = "210"),
    capture_row(capture_status = "R", nest_id = "-B0209", gps_id = "4", gps_point = "210")
  )
  negative_result <- run_captures_validator("CAP_009B family nest ids", negative_rows)
  expect_true(all(c(1L, 2L) %in% negative_result$rowid[negative_result$variable == "nest_id"]))

  current <- capture_row(capture_status = "R", nest_id = "B0208", gps_id = "4", gps_point = "210")
  saved_chick <- data.table(
    pk = 503, date = "2026-10-24", site = "CR", nest_id = "-B0208",
    gps_id = "4", gps_point = "210", age = "C", caught_with = NA_character_
  )
  mixed_result <- run_captures_validator(
    "CAP_009B family nest ids", current,
    refs = list(CAPTURES = saved_chick)
  )
  expect_true(any(mixed_result$rowid == 1L & mixed_result$variable == "nest_id"))
})

test_that("an unavailable companion lookup fails closed for a family capture", {
  current <- capture_row(capture_status = "R", nest_id = "B0208", gps_id = "4", gps_point = "210")
  result <- run_captures_validator(
    "CAP_009B family nest ids", current,
    db_failure = TRUE
  )
  expect_true(any(result$rowid == 1L & result$variable == "nest_id"))
  expect_true(any(grepl("database connection", result$reason, ignore.case = TRUE)))
})
