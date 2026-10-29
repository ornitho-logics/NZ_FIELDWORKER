library(testthat)
library(data.table)

observer_code_path <- function(table) {
  app_file("notes", "codex_proposals", "validator_sandbox",
           "inspector_lists_by_table", paste0(table, "_hard.R"))
}

observer_code_expr <- function(table, name) {
  exprs <- as.list(parse(file = observer_code_path(table))[[1L]])[-1L]
  hits <- vapply(exprs, function(expr) {
    grepl(paste0('nam = "', name, '"'),
          paste(deparse(expr), collapse = " "), fixed = TRUE)
  }, logical(1))
  stopifnot(sum(hits) == 1L)
  exprs[[which(hits)]]
}

run_observer_code <- function(table, name, rows, registered = NULL) {
  env <- new.env(parent = globalenv())
  env$x <- as.data.table(rows)
  env$try_validator <- function(expr, nam = NULL) eval(substitute(expr), parent.frame())
  env$is.regexp_validator <- DataEntry::is.regexp_validator
  env$db_get <- function(sql) {
    stopifnot(grepl("FROM OBSERVERS", sql, fixed = TRUE))
    copy(registered)
  }
  eval(observer_code_expr(table, name), envir = env)
}

test_that("actual observer format validators accept alphanumeric codes", {
  skip_if_not_installed("DataEntry")
  codes <- c("AB", "ABC", "P3", "P03", "3P", "23", "p3", "Ab", "P",
             "P333", "P-3", "P 3", "P_3", "P\u00e9", " P3", "P3 ")
  bad <- 7:16
  for (table in c("OBSERVERS", "EGGS", "NESTS", "RESIGHTINGS")) {
    out <- run_observer_code(table, "observer initials",
      data.table(rowid = seq_along(codes), observer = codes))
    expect_equal(sort(out$rowid), bad, info = table)
    expect_true(all(out$variable == "observer"), info = table)
    expect_true(all(grepl("letters or digits", out$reason, fixed = TRUE)), info = table)
  }
})

test_that("actual uploader validator accepts P3 and retains mandatory checks", {
  skip_if_not_installed("DataEntry")
  values <- c("AB", "P3", "P03", "23", NA, "", " ", "p3", "P", "P333", "P-3")
  out <- run_observer_code("CAPTURES", "observer upload initials",
    data.table(rowid = seq_along(values), observer_upload = values))
  expect_equal(sort(out$rowid), 5:11)
  expect_true(all(out$variable == "observer_upload"))
})

test_that("P3 must still be registered and active on the event date", {
  skip_if_not_installed("DataEntry")
  roster <- data.table(observer = "P3", start = "2026-10-01", stop = "2026-10-31")
  rows <- data.table(rowid = 1:3, observer = c("P3", "P3", "Q4"),
                     date = c("2026-10-15", "2026-11-01", "2026-10-15"))
  names <- c(CAPTURES = "CAP_002 observer active", EGGS = "EGG_002 observer active",
             RESIGHTINGS = "RES_002 observer active")
  for (table in names(names)) {
    out <- run_observer_code(table, names[[table]], rows, roster)
    expect_equal(sort(out$rowid), 2:3, info = table)
  }
  nest_roster <- copy(roster)
  setnames(nest_roster, c("start", "stop"), c("START", "STOP"))
  out <- run_observer_code("NESTS", "observer active", rows, nest_roster)
  expect_equal(sort(out$rowid), 2:3)
})

observer_sql_string <- function(sql, name) {
  hit <- regmatches(sql, regexec(paste0("SET @", name, " := '([^']*)';"), sql))[[1L]]
  stopifnot(length(hit) == 2L)
  hit[[2L]]
}

test_that("SQL replacements exactly reproduce the five reviewed inspector edits", {
  sql <- paste(readLines(app_file("DATABASE", "update_observer_code_validators_2026-10-29.SQL")), collapse = "\n")
  old <- observer_sql_string(sql, "observer_old_call")
  new <- observer_sql_string(sql, "observer_new_call")
  old_upload <- observer_sql_string(sql, "observer_upload_old_call")
  new_upload <- observer_sql_string(sql, "observer_upload_new_call")
  old_required <- observer_sql_string(sql, "observer_upload_old_required")
  new_required <- observer_sql_string(sql, "observer_upload_new_required")
  for (table in c("OBSERVERS", "EGGS", "NESTS", "RESIGHTINGS", "CAPTURES")) {
    current <- paste(readLines(observer_code_path(table)), collapse = "\n")
    if (table == "CAPTURES") {
      before <- gsub(new_upload, old_upload, current, fixed = TRUE)
      before <- gsub(new_required, old_required, before, fixed = TRUE)
      after <- gsub(old_upload, new_upload, before, fixed = TRUE)
      after <- gsub(old_required, new_required, after, fixed = TRUE)
    } else {
      before <- gsub(new, old, current, fixed = TRUE)
      after <- gsub(old, new, before, fixed = TRUE)
    }
    expect_false(identical(before, current), info = table)
    expect_identical(after, current, info = table)
    expect_length(parse(text = after), 1L)
  }
})

test_that("protocol and guarded installer agree with the tracked validator changes", {
  sql <- paste(readLines(app_file("DATABASE", "update_observer_code_validators_2026-10-29.SQL")), collapse = "\n")
  expect_match(sql, "START TRANSACTION", fixed = TRUE)
  expect_match(sql, "'COMMIT', 'ROLLBACK'", fixed = TRUE)
  expect_match(sql, "COUNT(DISTINCT table_name) = 5", fixed = TRUE)
  expect_match(sql, "ENGINE = 'InnoDB'", fixed = TRUE)
  expect_match(sql, "WHERE @observer_patch_ready = 1", fixed = TRUE)
  expect_false(grepl("(?im)^\\s*(ALTER|CREATE|DROP|DELETE|INSERT)\\s", sql, perl = TRUE))
  expect_false(grepl("UPDATE FIELD_2026_BADOatNZ\\.(OBSERVERS|CAPTURES|EGGS|NESTS|RESIGHTINGS)\\b", sql))
  for (table in c("OBSERVERS", "EGGS", "NESTS", "RESIGHTINGS", "CAPTURES")) {
    expect_match(sql, paste0("'", table, "_hard'"), fixed = TRUE)
  }
  skip_if_not_installed("yaml")
  protocol <- yaml::read_yaml(app_file("notes", "codex_proposals", "validator_sandbox",
    "xlsx_short_tag_update", "bdot_dataentry_validator_protocol_plot_aligned.yaml"))
  expect_identical(protocol$observer_code_format$regexp, "^[A-Z0-9]{2,3}$")
  expect_match(protocol$observer_code_format$public_exception, "RESIGHTINGS_PUBLIC", fixed = TRUE)
})

test_that("hint generator is read-only and preserves existing column attributes", {
  sql <- paste(readLines(app_file("DATABASE", "observer_code_field_hints_2026-10-29.SQL")), collapse = "\n")
  expect_false(grepl("(?im)^\\s*(ALTER|CREATE|DROP|DELETE|INSERT|UPDATE)\\s", sql, perl = TRUE))
  expect_match(sql, "c.CHARACTER_MAXIMUM_LENGTH = 3", fixed = TRUE)
  expect_match(sql, "c.IS_NULLABLE = 'YES'", fixed = TRUE)
  expect_match(sql, "c.IS_GENERATED", fixed = TRUE)
  expect_match(sql, "COLUMN_TYPE", fixed = TRUE)
  expect_match(sql, "CHARACTER_SET_NAME", fixed = TRUE)
  expect_match(sql, "COLLATION_NAME", fixed = TRUE)
  expect_match(sql, "ALGORITHM=INSTANT, LOCK=NONE", fixed = TRUE)
  expect_match(sql, "FIND_IN_SET('NO_BACKSLASH_ESCAPES', @@SESSION.sql_mode) = 0", fixed = TRUE)
  expect_match(sql, "SET SESSION sql_mode = ", fixed = TRUE)
  expect_false(grepl("RESIGHTINGS_PUBLIC", sql, fixed = TRUE))
})
