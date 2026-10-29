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
  env$is.na_validator <- DataEntry::is.na_validator
  env$db_get <- function(sql) {
    empty_lookup <- function(columns) {
      data.table::as.data.table(stats::setNames(
        rep(list(character()), length(columns)), columns
      ))
    }
    if (grepl("NESTS_LATEST", sql, fixed = TRUE)) {
      return(data.table(
        nest_id = character(), nest_state = character(),
        last_visit_datetime = character(), M_mark = character(), F_mark = character()
      ))
    }
    if (grepl("ADULT_PARENT_STATUS", sql, fixed = TRUE)) {
      return(refs[["ADULT_PARENT_STATUS"]] %||% empty_lookup(c(
        "nest_id", "M_selected_identity_key", "F_selected_identity_key",
        "M_selected_mark", "F_selected_mark", "M_association_pending",
        "F_association_pending", "M_association_ambiguous", "F_association_ambiguous"
      )))
    }
    if (grepl("RESIGHTINGS", sql, fixed = TRUE)) {
      return(refs[["RESIGHTINGS"]] %||% empty_lookup(
        c("pk", "date", "site", "nest_id", "age", "sex", "behav", "rclass",
          "gps_id", "gps_point", "ring", "UL", "LL", "UR", "LR")
      ))
    }
    if (grepl("CAPTURES_ARCHIVE", sql, fixed = TRUE)) {
      return(refs[["CAPTURES_ARCHIVE"]] %||% empty_lookup(c(
        "date", "nest_id", "ring", "field_sex"
      )))
    }
    if (grepl("CAPTURES", sql, fixed = TRUE)) {
      return(refs[["CAPTURES"]] %||% empty_lookup(c(
        "pk", "date", "site", "caught", "nest_id", "age", "field_sex", "capture_status",
        "behav", "rclass", "gps_id", "gps_point", "ring",
        "UL_in", "LL_in", "UR_in", "LR_in", "UL", "LL", "UR", "LR"
      )))
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
    site = rep("CR", parent_n),
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
    species = "BADO", observer = "ADO", site = "CR", date = chick_date %||% parent_dates[[1L]],
    rclass = chick_rclass, sex = "U", age = "C", behav = NA_character_,
    nest_id = chick_nest_id, gps_id = chick_gps_id, gps_point = chick_gps_point,
    ring = NA_character_, UL = "X", LL = "B", UR = "X", LR = NA_character_,
    cam_id = NA_character_, photo_start = NA_character_, photo_end = NA_character_
  )
  rbind(parent, chick, fill = TRUE)
}

h_photo_rows <- function(
  chick_nest_id = "B0208",
  parent_nest_ids = chick_nest_id,
  parent_behav = "AC"
) {
  rows <- resighting_rows(
    chick_rclass = "H",
    chick_nest_id = chick_nest_id,
    parent_nest_ids = parent_nest_ids,
    parent_behav = parent_behav
  )
  rows[, `:=`(
    ring = c(NA_character_, "CP10001"),
    cam_id = c(NA_character_, "C4"),
    photo_start = c(NA_character_, "102-2810"),
    photo_end = c(NA_character_, "102-2812")
  )]
  rows
}

authoritative_negative_status <- function(
  nest_id = "-B0208",
  M_selected_mark = "B-YY",
  F_selected_mark = "B-YY",
  M_association_pending = 0L,
  F_association_pending = 0L,
  M_association_ambiguous = 0L,
  F_association_ambiguous = 0L
) {
  data.table(
    nest_id,
    M_selected_identity_key = "ring:male",
    F_selected_identity_key = "ring:female",
    M_selected_mark,
    F_selected_mark,
    M_association_pending,
    F_association_pending,
    M_association_ambiguous,
    F_association_ambiguous
  )
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

  no_nest_parent <- resighting_rows(parent_nest_ids = "NO_NEST")
  no_nest_parent_result <- run_resightings_validator("RES_005B nest link", no_nest_parent)
  expect_true(any(no_nest_parent_result$rowid == 2L & no_nest_parent_result$variable == "nest_id"))
})

test_that("SC independently requires a parent nest link without triggering chick association", {
  parent <- resighting_rows(parent_nest_ids = NA_character_, parent_behav = "SC")[1]

  nest_result <- run_resightings_validator("RES_005B nest link", parent)
  expect_true(any(nest_result$rowid == 1L & nest_result$variable == "nest_id"))
  expect_true(any(grepl("IN/NM/SC", nest_result$reason, fixed = TRUE)))

  family_result <- run_resightings_validator("RES_005J same-session family link", parent)
  expect_length(family_result$rowid, 0L)
})

test_that("independent adult association requires both observed lower-leg fields", {
  missing_lower <- resighting_rows(parent_behav = "SC")[1]
  missing_lower[, `:=`(LL = NA_character_, LR = NA_character_, UL = "X", UR = "X")]
  missing_result <- run_resightings_validator("RES_005B nest link", missing_lower)
  expect_true(any(missing_result$rowid == 1L & missing_result$variable == "LL"))
  expect_true(any(grepl("both LL and LR", missing_result$reason, fixed = TRUE)))

  observed_xx <- resighting_rows(parent_behav = "SC")[1]
  observed_xx[, `:=`(LL = "X", LR = "XX", UL = "X", UR = "X")]
  expect_length(run_resightings_validator("RES_005B nest link", observed_xx)$rowid, 0L)

  blank_sc <- copy(observed_xx)[, nest_id := NA_character_]
  blank_result <- run_resightings_validator("RES_005B nest link", blank_sc)
  expect_true(any(blank_result$rowid == 1L & blank_result$variable == "nest_id"))
})

test_that("approved blank negative-family route remains limited to BC/FC/AC", {
  status <- authoritative_negative_status()
  for (behav in c("BC", "FC", "AC")) {
    rows <- resighting_rows(parent_nest_ids = NA_character_, parent_behav = behav)
    result <- run_resightings_validator(
      "RES_005B nest link", rows,
      refs = list(ADULT_PARENT_STATUS = status)
    )
    expect_false(any(result$rowid == 1L & result$variable == "nest_id"), info = behav)
  }

  scrape <- resighting_rows(parent_nest_ids = NA_character_, parent_behav = "SC")
  scrape_result <- run_resightings_validator(
    "RES_005B nest link", scrape,
    refs = list(ADULT_PARENT_STATUS = status)
  )
  expect_true(any(scrape_result$rowid == 1L & scrape_result$variable == "nest_id"))
})

test_that("the obsolete NO_NEST sentinel is rejected by the nest-id format check", {
  rows <- data.table(
    site = c("CR", "MR", "CR"),
    species = c("BADO", "BADO", "WRYB"),
    nest_id = c("NO_NEST", " no_nest ", "B0208")
  )
  result <- run_resightings_validator("RES_004C nest id", rows)
  expect_true(all(c(1L, 2L) %in% result$rowid[result$variable == "nest_id"]))
  expect_false(any(result$rowid == 3L & result$variable == "nest_id"))
})

test_that("ordinary age-C blank nest_id may use a historical RESIGHTINGS parent link", {
  rows <- resighting_rows(parent_nest_ids = NA_character_)
  history <- data.table(
    pk = 101, date = "2026-10-23", nest_id = "B0208", age = "A", sex = "F",
    UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(RESIGHTINGS = history)
  )
  expect_false(any(result$rowid == 2L & result$variable == "nest_id"))
})

test_that("ordinary age-C blank nest_id may use a historical CAPTURES parent link", {
  rows <- resighting_rows(parent_nest_ids = NA_character_)
  history <- data.table(
    pk = 102, date = "2026-10-23", nest_id = "B0208", age = "A", field_sex = "F",
    capture_status = "F", UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(CAPTURES = history)
  )
  expect_false(any(result$rowid == 2L & result$variable == "nest_id"))
})

test_that("a saved age-C CAPTURES row can satisfy the parent reciprocal check", {
  parent_only <- resighting_rows()[1]
  saved_chick <- data.table(
    pk = 201, date = "2026-10-24", site = "CR", age = "C",
    nest_id = "B0208", gps_id = "4", gps_point = "210"
  )
  result <- run_resightings_validator(
    "RES_005J same-session family link",
    parent_only,
    refs = list(CAPTURES = saved_chick)
  )
  expect_false(any(result$rowid == 1L & result$variable == "behav"))
})

test_that("a saved age-C CAPTURES row must match date, site, and GPS", {
  parent_only <- resighting_rows()[1]
  saved_chick <- data.table(
    pk = 202, date = "2026-10-24", site = "CR", age = "C",
    nest_id = "B0208", gps_id = "4", gps_point = "211"
  )
  result <- run_resightings_validator(
    "RES_005J same-session family link",
    parent_only,
    refs = list(CAPTURES = saved_chick)
  )
  expect_true(any(result$rowid == 1L & result$variable == "behav"))
  expect_true(any(grepl("save the genuine age-C CAPTURES rows first", result$reason, fixed = TRUE)))
  expect_true(any(grepl("same date, site, gps_id, and gps_point", result$reason, fixed = TRUE)))
})

test_that("ordinary age-C blank nest_id still fails when the parent history is unresolved", {
  rows <- resighting_rows(parent_nest_ids = NA_character_)
  result <- run_resightings_validator("RES_005B nest link", rows)
  expect_true(any(result$rowid == 2L & result$variable == "nest_id"))
  expect_true(any(grepl("historical", result$reason, ignore.case = TRUE)))
})

test_that("ordinary age-C blank nest_id rejects ambiguous authoritative parent status", {
  rows <- resighting_rows(parent_nest_ids = NA_character_)
  status <- authoritative_negative_status(M_association_ambiguous = 1L)
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(ADULT_PARENT_STATUS = status)
  )
  expect_true(any(result$rowid == 2L & result$variable == "nest_id"))
})

test_that("one observed parent may use the authoritative two-parent negative status", {
  rows <- resighting_rows(parent_nest_ids = NA_character_)
  status <- authoritative_negative_status()
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(ADULT_PARENT_STATUS = status)
  )
  expect_length(result$rowid, 0L)
  family_result <- run_resightings_validator(
    "RES_005J same-session family link", rows,
    refs = list(ADULT_PARENT_STATUS = status)
  )
  expect_length(family_result$rowid, 0L)
})

test_that("two observed agreeing parents may use one authoritative negative brood", {
  rows <- resighting_rows(parent_nest_ids = c(NA_character_, NA_character_))
  rows[1, `:=`(sex = "M", LL = "B")]
  rows[2, `:=`(sex = "F", LL = "W")]
  status <- authoritative_negative_status(F_selected_mark = "W-YY")
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(ADULT_PARENT_STATUS = status)
  )
  expect_length(result$rowid, 0L)
  family_result <- run_resightings_validator(
    "RES_005J same-session family link", rows,
    refs = list(ADULT_PARENT_STATUS = status)
  )
  expect_length(family_result$rowid, 0L)
})

test_that("missing authoritative negative status fails closed for the whole family", {
  rows <- resighting_rows(parent_nest_ids = NA_character_)
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(ADULT_PARENT_STATUS = data.table())
  )
  expect_true(any(result$rowid %in% c(1L, 2L) & result$variable == "nest_id"))
})

test_that("ambiguous authoritative negative status does not infer a blank link", {
  rows <- resighting_rows(parent_nest_ids = c(NA_character_, NA_character_))
  rows[1, `:=`(sex = "M", LL = "B")]
  rows[2, `:=`(sex = "F", LL = "W")]
  status <- authoritative_negative_status(F_association_pending = 1L)
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(ADULT_PARENT_STATUS = status)
  )
  expect_true(all(c(1L, 2L, 3L) %in% result$rowid[result$variable == "nest_id"]))
})

test_that("wrong date or GPS does not create a negative family association", {
  rows <- resighting_rows(parent_nest_ids = NA_character_, chick_date = "2026-10-23")
  status <- authoritative_negative_status()
  nest_result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(ADULT_PARENT_STATUS = status)
  )
  family_result <- run_resightings_validator(
    "RES_005J same-session family link", rows,
    refs = list(ADULT_PARENT_STATUS = status)
  )
  expect_true(any(nest_result$rowid == 2L & nest_result$variable == "nest_id"))
  expect_true(any(family_result$rowid == 1L & family_result$variable == "behav"))

  gps_rows <- resighting_rows(parent_nest_ids = NA_character_, chick_gps_point = "211")
  gps_nest_result <- run_resightings_validator(
    "RES_005B nest link", gps_rows,
    refs = list(ADULT_PARENT_STATUS = status)
  )
  gps_family_result <- run_resightings_validator(
    "RES_005J same-session family link", gps_rows,
    refs = list(ADULT_PARENT_STATUS = status)
  )
  expect_true(any(gps_nest_result$rowid == 2L & gps_nest_result$variable == "nest_id"))
  expect_true(any(gps_family_result$rowid == 1L & gps_family_result$variable == "behav"))
})

test_that("one family occasion must resolve to one shared parent nest ID", {
  rows <- resighting_rows(parent_nest_ids = c("B0208", "B0209"))
  result <- run_resightings_validator("RES_005B nest link", rows)
  expect_true(all(c(1L, 2L, 3L) %in% result$rowid[result$variable == "nest_id"]))
  expect_true(any(grepl("same family occasion", result$reason, fixed = TRUE)))
})

test_that("positive, negative, and mixed nest IDs conflict within one family occasion", {
  for (ids in list(c("B0208", "B0209"), c("-B0208", "-B0209"), c("B0208", "-B0208"))) {
    rows <- resighting_rows(parent_nest_ids = ids)
    result <- run_resightings_validator("RES_005B nest link", rows)
    expect_true(all(c(1L, 2L, 3L) %in% result$rowid[result$variable == "nest_id"]), info = paste(ids, collapse = ","))
  }
})

test_that("same family IDs pass, while date, site, and GPS keep occasions separate", {
  rows <- resighting_rows(parent_nest_ids = c("B0208", "B0208"))
  expect_false(any(run_resightings_validator("RES_005B nest link", rows)$variable == "nest_id"))

  different_date <- copy(rows)
  different_date[2, date := "2026-10-25"]
  expect_false(any(run_resightings_validator("RES_005B nest link", different_date)$variable == "nest_id"))

  different_site <- copy(rows)
  different_site[2, site := "MR"]
  expect_false(any(run_resightings_validator("RES_005B nest link", different_site)$variable == "nest_id"))

  different_gps <- copy(rows)
  different_gps[2, gps_point := "211"]
  expect_false(any(run_resightings_validator("RES_005B nest link", different_gps)$variable == "nest_id"))
})

test_that("a saved family companion contributes to same-occasion nest conflict", {
  current <- resighting_rows()[1]
  saved_chick <- data.table(
    pk = 301, date = "2026-10-24", site = "CR", age = "C",
    nest_id = "B0209", gps_id = "4", gps_point = "210"
  )
  result <- run_resightings_validator(
    "RES_005B nest link", current,
    refs = list(RESIGHTINGS = saved_chick)
  )
  expect_true(any(result$rowid == 1L & result$variable == "nest_id"))
})

test_that("uncertain parent marks do not provide nest evidence without a verified ring", {
  rows <- resighting_rows()
  rows[1, LL := "R?"]
  result <- run_resightings_validator("RES_005B nest link", rows)
  expect_true(any(result$rowid == 2L & result$variable == "nest_id"))
})

test_that("a verified ring can override uncertain parent colours", {
  rows <- resighting_rows()
  rows[1, `:=`(LL = "R?", ring = "CP10001")]
  capture_history <- data.table(
    pk = 401, date = "2026-10-23", site = "CR", age = "A", field_sex = "F",
    capture_status = "F", ring = "CP10001", nest_id = "B0208",
    UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(CAPTURES = capture_history)
  )
  expect_false(any(result$rowid == 2L & result$variable == "nest_id"))
})

test_that("current capture ring keys treat CP and CP-dash spellings as equivalent", {
  rows <- resighting_rows()
  rows[1, `:=`(LL = "R?", ring = "CP-10001")]
  capture_history <- data.table(
    pk = 402, date = "2026-10-23", age = "A", field_sex = "F",
    capture_status = "F", ring = "CP10001", nest_id = NA_character_,
    UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(CAPTURES = capture_history)
  )
  expect_false(any(result$rowid == 2L & result$variable == "nest_id"))
})

test_that("a known current capture ring permits an explicit current nest with uncertain colours", {
  rows <- resighting_rows()
  rows[1, `:=`(LL = "R?", ring = "CP10001")]
  capture_history <- data.table(
    pk = 402, date = "2026-10-23", age = "A", field_sex = "F",
    capture_status = "F", ring = "CP10001", nest_id = NA_character_,
    UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(CAPTURES = capture_history)
  )
  expect_false(any(result$rowid == 2L & result$variable == "nest_id"))
})

test_that("a same-day known capture ring can support an explicit current nest", {
  rows <- resighting_rows()
  rows[1, `:=`(LL = "R?", ring = "CP10001")]
  capture_history <- data.table(
    pk = 403, date = "2026-10-24", age = "A", field_sex = "F",
    capture_status = "F", ring = "CP10001", nest_id = NA_character_,
    UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(CAPTURES = capture_history)
  )
  expect_false(any(result$rowid == 2L & result$variable == "nest_id"))
})

test_that("an archive-only known ring permits an explicit current nest but does not infer a blank nest", {
  explicit_rows <- resighting_rows()
  explicit_rows[1, `:=`(LL = "R?", ring = "CP-10002")]
  archive_history <- data.table(
    date = "2026-10-23", field_sex = "F", ring = "CP10002", nest_id = "B0199"
  )
  explicit_result <- run_resightings_validator(
    "RES_005B nest link", explicit_rows,
    refs = list(CAPTURES_ARCHIVE = archive_history)
  )
  expect_false(any(explicit_result$rowid == 2L & explicit_result$variable == "nest_id"))

  blank_rows <- copy(explicit_rows)
  blank_rows[1, nest_id := NA_character_]
  blank_result <- run_resightings_validator(
    "RES_005B nest link", blank_rows,
    refs = list(CAPTURES_ARCHIVE = archive_history)
  )
  expect_true(any(blank_result$rowid == 2L & blank_result$variable == "nest_id"))
})

test_that("unknown or future rings do not override uncertain parent colours", {
  unknown_rows <- resighting_rows()
  unknown_rows[1, `:=`(LL = "R?", ring = "CP10003")]
  unknown_result <- run_resightings_validator(
    "RES_005B nest link", unknown_rows,
    refs = list(CAPTURES_ARCHIVE = data.table(
      date = "2026-10-25", field_sex = "F", ring = "CP10003", nest_id = "B0199"
    ))
  )
  expect_true(any(unknown_result$rowid == 2L & unknown_result$variable == "nest_id"))

  future_rows <- resighting_rows()
  future_rows[1, `:=`(LL = "R?", ring = "CP10004")]
  future_result <- run_resightings_validator(
    "RES_005B nest link", future_rows,
    refs = list(CAPTURES = data.table(
      pk = 404, date = "2026-10-25", age = "A", field_sex = "F",
      capture_status = "F", ring = "CP10004", nest_id = "B0208"
    ))
  )
  expect_true(any(future_result$rowid == 2L & future_result$variable == "nest_id"))
})

test_that("conflicting capture identity history does not override uncertain parent colours", {
  rows <- resighting_rows()
  rows[1, `:=`(LL = "R?", ring = "CP10005")]
  capture_history <- data.table(
    pk = c(405, 406), date = c("2026-10-22", "2026-10-23"), age = c("A", "A"),
    field_sex = c("F", "M"), capture_status = c("F", "R"),
    ring = c("CP10005", "CP10005"), nest_id = c("B0208", "B0208")
  )
  result <- run_resightings_validator(
    "RES_005B nest link", rows,
    refs = list(CAPTURES = capture_history)
  )
  expect_true(any(result$rowid == 2L & result$variable == "nest_id"))
})

test_that("a nonblank but unverified ring does not override uncertain parent colours", {
  rows <- resighting_rows()
  rows[1, `:=`(LL = "R?", ring = "CP99999")]
  result <- run_resightings_validator("RES_005B nest link", rows)
  expect_true(any(result$rowid == 2L & result$variable == "nest_id"))
})

test_that("same-session parent and chick links require the same site", {
  rows <- resighting_rows()
  rows[2, site := "MR"]
  result <- run_resightings_validator("RES_005J same-session family link", rows)
  expect_true(any(result$rowid == 1L & result$variable == "behav"))
  expect_true(any(result$rowid == 2L & result$variable == "age"))
})

test_that("ordinary age-C exception requires same date and complete GPS", {
  no_gps <- resighting_rows(chick_gps_id = NA_character_, chick_gps_point = NA_character_)
  no_gps_result <- run_resightings_validator("RES_005B nest link", no_gps)
  expect_true(any(no_gps_result$rowid == 2L & no_gps_result$variable == "nest_id"))

  wrong_date <- resighting_rows(parent_dates = "2026-10-23", chick_date = "2026-10-24")
  wrong_date_result <- run_resightings_validator("RES_005B nest link", wrong_date)
  expect_true(any(wrong_date_result$rowid == 2L & wrong_date_result$variable == "nest_id"))
})

test_that("H rows require explicit positive or negative nest_id", {
  h_rows <- h_photo_rows()
  positive_result <- run_resightings_validator("RES_005B nest link", h_rows)
  expect_false(any(positive_result$rowid == 2L & positive_result$variable == "nest_id"))

  negative_h <- copy(h_rows[2])[, nest_id := "-B0208"]
  negative_result <- run_resightings_validator("RES_005B nest link", negative_h)
  expect_false(any(negative_result$rowid == 2L & negative_result$variable == "nest_id"))

  no_nest_h <- copy(h_rows[2])[, nest_id := "NO_NEST"]
  no_nest_result <- run_resightings_validator("RES_005B nest link", no_nest_h)
  expect_true(any(no_nest_result$variable == "nest_id"))

  blank_h <- resighting_rows(chick_rclass = "H")
  blank_h[, `:=`(ring = c(NA_character_, "CP10001"), cam_id = c(NA_character_, "C4"),
                photo_start = c(NA_character_, "102-2810"), photo_end = c(NA_character_, "102-2812"))]
  blank_result <- run_resightings_validator(
    "RES_005B nest link",
    blank_h,
    refs = list(CAPTURES = data.table(
      pk = 401, date = "2026-10-23", age = "C", capture_status = "F",
      ring = "CP10001", nest_id = "B0208"
    ))
  )
  expect_true(any(blank_result$rowid == 2L & blank_result$variable == "nest_id"))
  expect_true(any(grepl("explicit valid positive or negative nest_id", blank_result$reason, fixed = TRUE)))
})

test_that("actual H inspector expressions enforce the complete nest_id matrix", {
  prior_capture <- data.table(
    pk = 401, date = "2026-10-23", age = "C", capture_status = "F",
    ring = "CP10001", nest_id = "B0208"
  )
  companion_refs <- list(CAPTURES = prior_capture)

  for (nest_id in c("B0208", "-B0208")) {
    rows <- h_photo_rows(chick_nest_id = nest_id, parent_nest_ids = nest_id)
    for (validator in c(
      "RES_001 mandatory",
      "RES_005B nest link",
      "RES_005J same-session family link",
      "RES_009 photo metadata",
      "RES_010 H ring",
      "RES_010A H ring format",
      "RES_010B H ring in CAPTURES"
    )) {
      result <- run_resightings_validator(validator, rows, refs = companion_refs)
      expect_equal(nrow(result), 0L, info = paste(nest_id, validator))
    }
  }

  missing_or_invalid <- list(
    `NULL/SQL NA` = NA_character_,
    `empty` = "",
    `whitespace` = "   ",
    `textual NA` = "NA",
    `NO_NEST` = "NO_NEST",
    `invalid format` = "B02"
  )
  for (case_name in names(missing_or_invalid)) {
    nest_id <- missing_or_invalid[[case_name]]
    rows <- h_photo_rows(chick_nest_id = nest_id, parent_nest_ids = "B0208")
    link_result <- run_resightings_validator(
      "RES_005B nest link", rows, refs = companion_refs
    )
    format_result <- run_resightings_validator("RES_004C nest id", rows)
    result <- rbind(link_result, format_result, fill = TRUE)
    expect_true(
      any(result$rowid == 2L & result$variable == "nest_id"),
      info = paste("H nest_id:", case_name)
    )
  }
})

test_that("H companion requirements and family checks remain independent of nest_id", {
  valid <- h_photo_rows()
  refs <- list(CAPTURES = data.table(
    pk = 402, date = "2026-10-23", age = "C", capture_status = "F",
    ring = "CP10001", nest_id = "B0208"
  ))

  missing_gps <- copy(valid[2])[, gps_id := NA_character_]
  gps_result <- run_resightings_validator("RES_001 mandatory", missing_gps)
  expect_true(any(gps_result$variable == "gps_id"))

  missing_photo <- copy(valid[2])[, photo_start := NA_character_]
  photo_result <- run_resightings_validator("RES_009 photo metadata", missing_photo)
  expect_true(any(photo_result$variable == "photo_start"))

  missing_ring <- copy(valid[2])[, ring := NA_character_]
  ring_result <- run_resightings_validator("RES_010 H ring", missing_ring)
  expect_true(any(ring_result$variable == "ring"))

  expect_length(
    run_resightings_validator("RES_005J same-session family link", valid)$rowid,
    0L
  )

  wrong_site <- copy(valid)
  wrong_site[2, site := "MR"]
  site_result <- run_resightings_validator(
    "RES_005J same-session family link", wrong_site
  )
  expect_true(any(site_result$variable %in% c("behav", "age")))

  conflicting_nest <- h_photo_rows(
    chick_nest_id = "B0209", parent_nest_ids = "B0208"
  )
  conflict_result <- run_resightings_validator(
    "RES_005B nest link", conflicting_nest, refs = refs
  )
  expect_true(any(conflict_result$variable == "nest_id"))
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

test_that("partial tarsus marks with an unknown colour component are accepted", {
  skip_if_not_installed("DataEntry")
  env <- new.env(parent = globalenv())
  env$x <- data.table(LL = c("R?", "R"), rowid = 1:2)
  env$try_validator <- function(expr, nam = NULL) {
    eval(substitute(expr), parent.frame())
  }
  env$is.regexp_validator <- DataEntry::is.regexp_validator
  result <- eval(find_resightings_validator("left tarsus format"), envir = env)
  expect_false(any(result$rowid == 1L))
  expect_false(any(result$rowid == 2L))
})

test_that("adult nonconfirming RESIGHTINGS can use a current S scrape without fabricating chick origin", {
  scrape_history <- data.table(
    nest_id = "B0208", date = "2026-10-24", time_visit = "10:00",
    nest_state = "S", clutch_size = 0, brood_size = 0, pk = 101
  )

  adult_sc_same <- resighting_rows(
    parent_nest_ids = "B0208", parent_dates = "2026-10-24", parent_behav = "SC"
  )[1]
  adult_sc_same[, rowid := 44L]
  same_result <- run_resightings_validator(
    "RES_005F first nest event", adult_sc_same,
    refs = list(NESTS = scrape_history)
  )
  expect_length(same_result$rowid, 0L)
  expect_length(run_resightings_validator(
    "RES_005J same-session family link", adult_sc_same
  )$rowid, 0L)

  adult_sc_prior <- copy(adult_sc_same)[, date := "2026-10-25"]
  prior_result <- run_resightings_validator(
    "RES_005F first nest event", adult_sc_prior,
    refs = list(NESTS = scrape_history)
  )
  expect_length(prior_result$rowid, 0L)

  adult_nonconfirming <- copy(adult_sc_same)[, behav := "AT"]
  nonconfirming_result <- run_resightings_validator(
    "RES_005F first nest event", adult_nonconfirming,
    refs = list(NESTS = scrape_history)
  )
  expect_length(nonconfirming_result$rowid, 0L)

  adult_sc_future <- copy(adult_sc_same)[, date := "2026-10-23"]
  future_result <- run_resightings_validator(
    "RES_005F first nest event", adult_sc_future,
    refs = list(NESTS = scrape_history)
  )
  expect_true(any(future_result$rowid == 44L & future_result$variable == "nest_id"))
  expect_true(any(grepl("S scrape", future_result$reason, fixed = TRUE)))

  no_history_result <- run_resightings_validator(
    "RES_005F first nest event", adult_sc_same,
    refs = list(NESTS = scrape_history[0])
  )
  expect_true(any(no_history_result$rowid == 44L & no_history_result$variable == "nest_id"))

  closed_history <- rbind(
    scrape_history,
    data.table(
      nest_id = "B0208", date = "2026-10-25", time_visit = "11:00",
      nest_state = "notA", clutch_size = 0, brood_size = 0, pk = 102
    )
  )
  closed_result <- run_resightings_validator(
    "RES_005F first nest event", adult_sc_prior,
    refs = list(NESTS = closed_history)
  )
  expect_true(any(closed_result$rowid == 44L & closed_result$variable == "nest_id"))
})

test_that("S scrape exception does not weaken active or brood-stage rules", {
  scrape_history <- data.table(
    nest_id = "B0208", date = "2026-10-24", time_visit = "10:00",
    nest_state = "S", clutch_size = 0, brood_size = 0, pk = 101
  )

  for (behav in c("IN", "NM", "BW", "BC", "FC", "AC")) {
    parent <- resighting_rows(
      parent_nest_ids = "B0208", parent_dates = "2026-10-24", parent_behav = behav
    )[1]
    chronology_result <- run_resightings_validator(
      "RES_005F first nest event", parent,
      refs = list(NESTS = scrape_history)
    )
    expect_true(any(chronology_result$variable == "nest_id"), info = behav)
  }

  for (behav in c("IN", "NM")) {
    parent <- resighting_rows(
      parent_nest_ids = "B0208", parent_dates = "2026-10-24", parent_behav = behav
    )[1]
    active_result <- run_resightings_validator(
      "RES_005D ended nest", parent,
      refs = list(NESTS = scrape_history)
    )
    expect_true(any(active_result$variable == "nest_id"), info = behav)
  }

  for (behav in c("BC", "FC", "AC")) {
    parent <- resighting_rows(
      parent_nest_ids = "B0208", parent_dates = "2026-10-24", parent_behav = behav
    )[1]
    brood_result <- run_resightings_validator(
      "RES_005K brood-stage state", parent,
      refs = list(NESTS = scrape_history)
    )
    expect_true(any(brood_result$variable == "nest_id"), info = behav)
    family_result <- run_resightings_validator(
      "RES_005J same-session family link", parent
    )
    expect_true(any(family_result$variable == "behav"), info = behav)
  }

  for (state in c("F", "I", "H")) {
    history <- copy(scrape_history)[, `:=`(nest_state = state, pk = 201L)]
    parent <- resighting_rows(
      parent_nest_ids = "B0208", parent_dates = "2026-10-24", parent_behav = "SC"
    )[1]
    result <- run_resightings_validator(
      "RES_005F first nest event", parent,
      refs = list(NESTS = history)
    )
    expect_true(length(result$rowid) == 0L, info = state)
  }

  chick <- resighting_rows(
    chick_rclass = "R", chick_nest_id = "B0208", parent_dates = "2026-10-24",
    parent_behav = "AT"
  )[2]
  chick_result <- run_resightings_validator(
    "RES_005F first nest event", chick,
    refs = list(NESTS = scrape_history)
  )
  expect_true(any(chick_result$variable == "nest_id"))
})
