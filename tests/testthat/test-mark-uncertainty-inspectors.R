library(testthat)
library(data.table)

mark_uncertainty_resightings_path <- app_file(
  "notes",
  "codex_proposals",
  "validator_sandbox",
  "inspector_lists_by_table",
  "RESIGHTINGS_hard.R"
)

mark_uncertainty_warning_path <- app_file(
  "notes",
  "codex_proposals",
  "validator_sandbox",
  "inspector_lists_by_table",
  "RESIGHTINGS_warning.R"
)

mark_uncertainty_captures_path <- app_file(
  "notes",
  "codex_proposals",
  "validator_sandbox",
  "inspector_lists_by_table",
  "CAPTURES_hard.R"
)

mark_uncertainty_resightings_exprs <- parse(file = mark_uncertainty_resightings_path)[[1L]]
mark_uncertainty_warning_exprs <- parse(file = mark_uncertainty_warning_path)[[1L]]
mark_uncertainty_captures_exprs <- parse(file = mark_uncertainty_captures_path)[[1L]]

find_mark_uncertainty_validator <- function(exprs, name) {
  hits <- which(vapply(
    exprs[-1L],
    function(expr) grepl(
      paste0('nam = "', name, '"'),
      paste(deparse(expr), collapse = " "),
      fixed = TRUE
    ),
    logical(1)
  ))
  expect_length(hits, 1L)
  exprs[[hits + 1L]]
}

run_mark_uncertainty_simple <- function(exprs, name, rows) {
  env <- new.env(parent = globalenv())
  env$x <- as.data.table(rows)
  env$try_validator <- function(expr, nam = NULL) {
    eval(substitute(expr), parent.frame())
  }
  env$is.regexp_validator <- DataEntry::is.regexp_validator
  eval(find_mark_uncertainty_validator(exprs, name), envir = env)
}

empty_mark_lookup <- function(columns) {
  data.table::as.data.table(stats::setNames(
    rep(list(character()), length(columns)),
    columns
  ))
}

run_mark_uncertainty_resightings <- function(name, rows, refs = list()) {
  env <- new.env(parent = globalenv())
  env$x <- as.data.table(rows)
  env$try_validator <- function(expr, nam = NULL) {
    eval(substitute(expr), parent.frame())
  }
  env$db_get <- function(sql) {
    if (grepl("NESTS_LATEST", sql, fixed = TRUE)) {
      return(refs[["NESTS_LATEST"]] %||% data.table(
        nest_id = character(), nest_state = character(),
        last_visit_datetime = character(), M_mark = character(), F_mark = character()
      ))
    }
    if (grepl("ADULT_PARENT_STATUS", sql, fixed = TRUE)) {
      return(refs[["ADULT_PARENT_STATUS"]] %||% empty_mark_lookup(c(
        "nest_id", "M_selected_identity_key", "F_selected_identity_key",
        "M_selected_mark", "F_selected_mark", "M_association_pending",
        "F_association_pending", "M_association_ambiguous", "F_association_ambiguous"
      )))
    }
    if (grepl("RESIGHTINGS", sql, fixed = TRUE)) {
      return(refs[["RESIGHTINGS"]] %||% empty_mark_lookup(
        c("pk", "date", "nest_id", "age", "sex", "ring", "UL", "LL", "UR", "LR")
      ))
    }
    if (grepl("CAPTURES_ARCHIVE", sql, fixed = TRUE)) {
      return(refs[["CAPTURES_ARCHIVE"]] %||% empty_mark_lookup(c(
        "ring", "date", "field_sex", "gen_sex", "UL", "LL", "UR", "LR"
      )))
    }
    if (grepl("CAPTURES", sql, fixed = TRUE)) {
      return(refs[["CAPTURES"]] %||% empty_mark_lookup(c(
        "pk", "date", "site", "caught", "nest_id", "age", "field_sex", "capture_status",
        "UL_in", "LL_in", "UR_in", "LR_in", "UL", "LL", "UR", "LR",
        "capture_method"
      )))
    }
    refs[["NESTS"]] %||% data.table(
      nest_id = character(), date = character(), time_visit = character(), nest_state = character()
    )
  }
  exprs <- if (name %in% c("RES_005G social parent mark", "RES_005H resighting sex history", "RES_005I X-X parent slot")) {
    mark_uncertainty_warning_exprs
  } else {
    mark_uncertainty_resightings_exprs
  }
  eval(find_mark_uncertainty_validator(exprs, name), envir = env)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

test_that("RESIGHTINGS accepts ordered uncertainty forms in every segment", {
  skip_if_not_installed("DataEntry")

  accepted <- list(
    UL = c("?", "?R", "R?", "FWX8", "X"),
    LL = c("?", "?R", "R?", "B", "XX"),
    UR = c("?", "?R", "R?", "T?", "TY", "M", "X"),
    LR = c("?", "?R", "R?", "B", "XX")
  )
  validator_names <- c(
    UL = "left tibia format",
    LL = "left tarsus format",
    UR = "right tibia format",
    LR = "right tarsus format"
  )

  for (column in names(accepted)) {
    result <- run_mark_uncertainty_simple(
      mark_uncertainty_resightings_exprs,
      validator_names[[column]],
      data.table(rowid = seq_along(accepted[[column]]), value = accepted[[column]])[, (column) := value][, value := NULL]
    )
    expect_length(result$rowid, 0L)
  }
})

test_that("RESIGHTINGS rejects unsupported uncertainty forms and bare UR T", {
  skip_if_not_installed("DataEntry")

  rejected <- list(
    UL = c("T?", "?RR", "R??"),
    LL = c("T?", "?RR", "M?"),
    UR = c("T", "T??", "?M"),
    LR = c("T?", "?RR", "M?")
  )
  validator_names <- c(
    UL = "left tibia format",
    LL = "left tarsus format",
    UR = "right tibia format",
    LR = "right tarsus format"
  )

  for (column in names(rejected)) {
    result <- run_mark_uncertainty_simple(
      mark_uncertainty_resightings_exprs,
      validator_names[[column]],
      data.table(rowid = seq_along(rejected[[column]]), value = rejected[[column]])[, (column) := value][, value := NULL]
    )
    expect_setequal(result$rowid, seq_along(rejected[[column]]))
  }
})

test_that("uncertain H marks do not trigger deterministic H layout inference", {
  rows <- data.table(
    rowid = 1:5,
    rclass = "H",
    UL = c("?", "M", "M", "M", "M"),
    LL = c("R?", NA_character_, "?", "B", NA_character_),
    UR = c("M", "?R", NA_character_, NA_character_, NA_character_),
    LR = c(NA_character_, "R?", "R?", NA_character_, "?")
  )
  result <- run_mark_uncertainty_simple(
    mark_uncertainty_resightings_exprs,
    "RES_011 H chick band layout",
    rows
  )
  expect_length(result$rowid, 0L)
})

test_that("uncertain marks do not create a definitive RESIGHTINGS parent history match", {
  rows <- data.table(
    rowid = 1:2,
    date = c("2026-10-24", "2026-10-24"),
    site = c("CR", "CR"),
    age = c("A", "C"),
    rclass = c("R", "R"),
    sex = c("F", "U"),
    behav = c("BC", NA_character_),
    nest_id = c(NA_character_, NA_character_),
    gps_id = c("4", "4"),
    gps_point = c("210", "210"),
    ring = c(NA_character_, NA_character_),
    UL = c("X", "X"),
    LL = c("R?", "B"),
    UR = c("X", "X"),
    LR = c("YY", NA_character_)
  )
  prior <- data.table(
    pk = 101,
    date = "2026-10-23",
    nest_id = "B0208",
    age = "A",
    field_sex = "F",
    capture_status = "F",
    UL = "X", LL = "R?", UR = "X", LR = "YY"
  )
  result <- run_mark_uncertainty_resightings(
    "RES_005B nest link",
    rows,
    refs = list(CAPTURES = prior)
  )
  expect_true(any(result$rowid == 1L & result$variable == "nest_id"))
  expect_true(any(result$rowid == 2L & result$variable == "nest_id"))
})

test_that("ring evidence remains available for sex-history checks with an uncertain mark", {
  row <- data.table(
    rowid = 1L,
    date = "2026-10-24",
    age = "A",
    sex = "F",
    ring = "CP10001",
    UL = "X", LL = "R?", UR = "X", LR = "YY"
  )
  prior <- data.table(
    pk = 201,
    date = "2026-10-23",
    field_sex = "M",
    ring = "CP10001",
    UL = "X", LL = "R", UR = "X", LR = "YY"
  )
  result <- run_mark_uncertainty_resightings(
    "RES_005H resighting sex history",
    row,
    refs = list(CAPTURES = prior)
  )
  expect_true(any(result$rowid == 1L & result$variable == "sex"))
})

test_that("archive lower-band-only matches are not definitive sex history", {
  row <- data.table(
    rowid = 1L,
    date = "2026-10-24",
    age = "A",
    sex = "F",
    ring = NA_character_,
    UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  archive <- data.table(
    date = "2026-10-23",
    field_sex = "M",
    gen_sex = NA_character_,
    ring = NA_character_,
    UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  result <- run_mark_uncertainty_resightings(
    "RES_005H resighting sex history",
    row,
    refs = list(CAPTURES_ARCHIVE = archive)
  )
  expect_length(result$rowid, 0L)
})

test_that("archive ring and engraved-flag identities remain definitive sex history", {
  ring_row <- data.table(
    rowid = 1L,
    date = "2026-10-24",
    age = "A",
    sex = "F",
    ring = "CP10007",
    UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  ring_archive <- data.table(
    date = "2026-10-23",
    field_sex = "M",
    gen_sex = NA_character_,
    ring = "CP10007",
    UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  ring_result <- run_mark_uncertainty_resightings(
    "RES_005H resighting sex history",
    ring_row,
    refs = list(CAPTURES_ARCHIVE = ring_archive)
  )
  expect_true(any(ring_result$rowid == 1L & ring_result$variable == "sex"))

  flag_row <- copy(ring_row)[, `:=`(
    ring = NA_character_,
    UL = "FQ1", LL = "X", UR = "X", LR = "X"
  )]
  flag_archive <- copy(ring_archive)[, `:=`(
    ring = NA_character_,
    UL = "FQ1", LL = "X", UR = "X", LR = "X"
  )]
  flag_result <- run_mark_uncertainty_resightings(
    "RES_005H resighting sex history",
    flag_row,
    refs = list(CAPTURES_ARCHIVE = flag_archive)
  )
  expect_true(any(flag_result$rowid == 1L & flag_result$variable == "sex"))
})

test_that("uncertain social-parent marks are not compared as definitive combinations", {
  row <- data.table(
    rowid = 1L,
    date = "2026-10-24",
    age = "A",
    sex = "F",
    behav = "BC",
    nest_id = "B0208",
    UL = "X", LL = "R?", UR = "X", LR = "YY"
  )
  prior <- data.table(
    pk = 301,
    date = "2026-10-23",
    caught = "10:00",
    nest_id = "B0208",
    age = "A",
    field_sex = "F",
    capture_method = "TB",
    UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  result <- run_mark_uncertainty_resightings(
    "RES_005G social parent mark",
    row,
    refs = list(CAPTURES = prior)
  )
  expect_length(result$rowid, 0L)
})

test_that("uncertain X-X candidates do not trigger the parent-slot warning", {
  row <- data.table(
    rowid = 1L,
    date = "2026-10-24",
    age = "A",
    sex = "F",
    behav = "BC",
    nest_id = "B0208",
    UL = "?",
    LL = "X",
    UR = "X",
    LR = "X"
  )
  prior <- data.table(
    pk = 401,
    date = "2026-10-23",
    nest_id = "B0208",
    age = "A",
    sex = "F",
    ring = NA_character_,
    UL = "X", LL = "B", UR = "X", LR = "YY"
  )
  result <- run_mark_uncertainty_resightings(
    "RES_005I X-X parent slot",
    row,
    refs = list(RESIGHTINGS = prior)
  )
  expect_length(result$rowid, 0L)
})

test_that("CAPTURES rejects uncertainty notation in all handled and recovered mark fields", {
  fields <- c("UL", "LL", "UR", "LR", "UL_in", "LL_in", "UR_in", "LR_in")
  statuses <- rep(c("F", "R", "C", "D"), length.out = length(fields))
  rows <- data.table(
    rowid = seq_along(fields),
    capture_status = statuses,
    age = "C"
  )
  for (field in fields) {
    rows[, (field) := NA_character_]
  }
  for (i in seq_along(fields)) {
    rows[i, (fields[[i]]) := if (fields[[i]] %in% c("UR", "UR_in")) "T?" else "R?"]
  }

  result <- run_mark_uncertainty_simple(
    mark_uncertainty_captures_exprs,
    "CAP_001B uncertain marks",
    rows
  )
  expect_setequal(result$variable, fields)
  expect_setequal(result$rowid, seq_along(fields))

  clean <- rows
  for (field in fields) {
    clean[, (field) := "X"]
  }
  clean_result <- run_mark_uncertainty_simple(
    mark_uncertainty_captures_exprs,
    "CAP_001B uncertain marks",
    clean
  )
  expect_length(clean_result$rowid, 0L)
})
