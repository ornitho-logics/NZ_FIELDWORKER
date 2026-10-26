library(testthat)
library(data.table)

resightings_hard_path <- app_file(
  "notes",
  "codex_proposals",
  "validator_sandbox",
  "inspector_lists_by_table",
  "RESIGHTINGS_hard.R"
)

resightings_hard_exprs <- parse(file = resightings_hard_path)[[1L]]

find_resightings_validator <- function(name) {
  hits <- which(vapply(
    resightings_hard_exprs[-1L],
    function(expr) grepl(
      paste0('nam = "', name, '"'),
      paste(deparse(expr), collapse = " "),
      fixed = TRUE
    ),
    logical(1)
  ))
  expect_length(hits, 1L)
  resightings_hard_exprs[[hits + 1L]]
}

run_resightings_validator <- function(name, rows, refs = list()) {
  env <- new.env(parent = globalenv())
  env$x <- as.data.table(rows)
  env$try_validator <- function(expr, nam = NULL) {
    eval(substitute(expr), parent.frame())
  }
  env$db_get <- function(sql) {
    if (grepl("NESTS_LATEST", sql, fixed = TRUE)) {
      return(data.table(
        nest_id = character(), nest_state = character(),
        last_visit_datetime = character(), M_mark = character(), F_mark = character()
      ))
    }
    if (grepl("CAPTURES", sql, fixed = TRUE)) {
      return(data.table(
        date = character(), caught = character(), nest_id = character(), age = character(),
        field_sex = character(), UL = character(), LL = character(), UR = character(), LR = character()
      ))
    }
    refs[["NESTS"]] %||% data.table(
      nest_id = character(), date = character(), time_visit = character(), nest_state = character()
    )
  }
  eval(find_resightings_validator(name), envir = env)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

resighting_rows <- function(
  chick_rclass = "R",
  chick_nest_id = NA_character_,
  chick_gps_id = "4",
  chick_gps_point = "210",
  parent_nest_ids = "B0208",
  parent_dates = "2026-10-24",
  chick_date = NULL,
  parent_gps_id = "4",
  parent_gps_point = "210",
  parent_behav = "AC"
) {
  parent_n <- length(parent_nest_ids)
  parent <- data.table(
    species = rep("BADO", parent_n),
    observer = rep("ADO", parent_n),
    date = parent_dates,
    rclass = rep("R", parent_n),
    sex = rep("F", parent_n),
    age = rep("A", parent_n),
    behav = rep(parent_behav, parent_n),
    nest_id = parent_nest_ids,
    gps_id = rep(parent_gps_id, parent_n),
    gps_point = rep(parent_gps_point, parent_n),
    ring = rep(NA_character_, parent_n),
    UL = rep("X", parent_n), LL = rep("B", parent_n),
    UR = rep("X", parent_n), LR = rep("YY", parent_n),
    cam_id = rep(NA_character_, parent_n),
    photo_start = rep(NA_character_, parent_n),
    photo_end = rep(NA_character_, parent_n)
  )
  chick <- data.table(
    species = "BADO", observer = "ADO", date = chick_date %||% parent_dates[[1L]],
    rclass = chick_rclass, sex = "U", age = "C", behav = NA_character_,
    nest_id = chick_nest_id, gps_id = chick_gps_id, gps_point = chick_gps_point,
    ring = NA_character_, UL = "X", LL = "B", UR = "X", LR = NA_character_,
    cam_id = NA_character_, photo_start = NA_character_, photo_end = NA_character_
  )
  rbind(parent, chick, fill = TRUE)
}

test_that("ordinary age-C GPS-linked rows may omit nest_id with one valid parent link", {
  for (rclass in c("R", "P", "V", "C")) {
    rows <- resighting_rows(chick_rclass = rclass)
    result <- run_resightings_validator("RES_005B nest link", rows)
    expect_false(any(result$rowid == 2L & result$variable == "nest_id"), info = rclass)
    family_result <- run_resightings_validator("RES_005J same-session family link", rows)
    expect_equal(nrow(family_result), 0L, info = rclass)
  }
})

test_that("ordinary age-C blank nest_id still fails without a qualifying parent", {
  rows <- resighting_rows(parent_behav = "AT")
  result <- run_resightings_validator("RES_005B nest link", rows)
  expect_true(any(result$rowid == 2L & result$variable == "nest_id"))

  no_nest <- resighting_rows(chick_nest_id = "NO_NEST")
  no_nest_result <- run_resightings_validator("RES_005B nest link", no_nest)
  expect_true(any(no_nest_result$rowid == 2L & no_nest_result$variable == "nest_id"))
})

test_that("ordinary age-C blank nest_id rejects ambiguous parent nest links", {
  rows <- resighting_rows(parent_nest_ids = c("B0208", "B0209"))
  result <- run_resightings_validator("RES_005B nest link", rows)
  expect_true(any(result$rowid == 3L & result$variable == "nest_id"))
  expect_true(any(grepl("ambiguous", result$reason, ignore.case = TRUE)))
})

test_that("ordinary age-C exception requires same date and complete GPS", {
  no_gps <- resighting_rows(chick_gps_id = NA_character_, chick_gps_point = NA_character_)
  no_gps_result <- run_resightings_validator("RES_005B nest link", no_gps)
  expect_true(any(no_gps_result$rowid == 2L & no_gps_result$variable == "nest_id"))

  wrong_date <- resighting_rows(parent_dates = "2026-10-23", chick_date = "2026-10-24")
  wrong_date_result <- run_resightings_validator("RES_005B nest link", wrong_date)
  expect_true(any(wrong_date_result$rowid == 2L & wrong_date_result$variable == "nest_id"))
})

test_that("H rows retain their ring/GPS exception while the parent branch is stricter", {
  h_rows <- resighting_rows(chick_rclass = "H")
  h_rows[, `:=`(ring = c(NA_character_, "CP10001"), cam_id = c(NA_character_, "C4"),
               photo_start = c(NA_character_, "102-2810"), photo_end = c(NA_character_, "102-2812"))]
  result <- run_resightings_validator("RES_005B nest link", h_rows)
  expect_false(any(result$rowid == 2L & result$variable == "nest_id"))

  h_parent_only <- resighting_rows(chick_rclass = "H")
  h_parent_only[, ring := NA_character_]
  parent_only_result <- run_resightings_validator("RES_005B nest link", h_parent_only)
  expect_false(any(parent_only_result$rowid == 2L & parent_only_result$variable == "nest_id"))

  h_wrong_date <- resighting_rows(chick_rclass = "H", parent_dates = "2026-10-23", chick_date = "2026-10-24")
  h_wrong_date[, ring := NA_character_]
  wrong_date_result <- run_resightings_validator("RES_005B nest link", h_wrong_date)
  expect_true(any(wrong_date_result$rowid == 2L & wrong_date_result$variable == "nest_id"))
})

test_that("ordinary R rows keep ring optional and P/V photo checks remain separate", {
  r_rows <- resighting_rows(chick_rclass = "R")
  expect_false(any(run_resightings_validator("RES_005B nest link", r_rows)$rowid == 2L))

  p_missing <- resighting_rows(chick_rclass = "P")
  missing_photo_result <- run_resightings_validator("RES_009 photo metadata", p_missing)
  expect_true(any(missing_photo_result$rowid == 2L & missing_photo_result$variable == "cam_id"))

  p_complete <- copy(p_missing)
  p_complete[, `:=`(
    cam_id = c(NA_character_, "C4"),
    photo_start = c(NA_character_, "102-2810"),
    photo_end = c(NA_character_, "102-2812")
  )]
  complete_photo_result <- run_resightings_validator("RES_009 photo metadata", p_complete)
  expect_false(any(complete_photo_result$rowid == 2L))
})
