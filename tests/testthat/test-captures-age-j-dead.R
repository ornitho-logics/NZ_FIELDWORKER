testthat::test_that("age-J dead captures use recovered marks and blank release marks", {
  testthat::skip_if_not_installed("data.table")
  testthat::skip_if_not_installed("DataEntry")

  project_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
  hard_path <- file.path(
    project_root,
    "notes",
    "codex_proposals",
    "validator_sandbox",
    "inspector_lists_by_table",
    "CAPTURES_hard.R"
  )
  warning_path <- file.path(
    project_root,
    "notes",
    "codex_proposals",
    "validator_sandbox",
    "inspector_lists_by_table",
    "CAPTURES_warning.R"
  )

  find_validator <- function(path, label) {
    parsed <- parse(file = path)[[1]]
    hits <- which(vapply(
      parsed[-1],
      function(expr) grepl(label, paste(deparse(expr), collapse = " "), fixed = TRUE),
      logical(1)
    ))
    testthat::expect_length(hits, 1L)
    list(expr = parsed[[hits[[1L]] + 1L]], parsed = parsed)
  }

  cap013 <- find_validator(hard_path, "CAP_013 014 017 marks")$expr
  cap001b <- find_validator(hard_path, "CAP_001B uncertain marks")$expr
  cap007 <- find_validator(warning_path, "CAP_007 008 likely patterns")$expr

  eval_cap013 <- function(rows) {
    env <- new.env(parent = parent.frame())
    env$x <- rows
    env$db_get <- function(sql) data.table::data.table(ring = character())
    env$try_validator <- DataEntry::try_validator
    eval(cap013, envir = env)
  }

  eval_cap007 <- function(rows) {
    env <- new.env(parent = parent.frame())
    env$x <- rows
    env$try_validator <- DataEntry::try_validator
    eval(cap007, envir = env)
  }

  eval_cap001b <- function(rows) {
    env <- new.env(parent = parent.frame())
    env$x <- rows
    env$try_validator <- DataEntry::try_validator
    eval(cap001b, envir = env)
  }

  recovered_dead <- data.table::data.table(
    rowid = 1L,
    age = "J",
    site = "CR",
    capture_status = "D",
    capture_method = "MM",
    ring = "CP12345",
    UL_in = "X",
    LL_in = "B",
    UR_in = "M",
    LR_in = "X",
    UL = NA_character_,
    LL = NA_character_,
    UR = NA_character_,
    LR = NA_character_,
    tag_id_in = NA_character_,
    tag_id = NA_character_,
    tag_type = NA_character_,
    tag_action = NA_character_,
    wt_w_tag = NA_character_
  )

  passing_dead <- eval_cap013(recovered_dead)
  testthat::expect_equal(nrow(passing_dead), 0L)
  testthat::expect_equal(nrow(eval_cap007(recovered_dead)), 0L)

  flagged_dead <- data.table::copy(recovered_dead)
  flagged_dead[, UL_in := "FWZ9"]
  testthat::expect_equal(nrow(eval_cap013(flagged_dead)), 0L)

  contradictory_release <- data.table::copy(recovered_dead)
  contradictory_release[, `:=`(UL = "FWZ9", UR = "M")]
  release_problems <- eval_cap013(contradictory_release)
  testthat::expect_true(any(grepl("Dead-on-capture rows must leave all release", release_problems$reason, fixed = TRUE)))

  invalid_recovered_scheme <- data.table::copy(recovered_dead)
  invalid_recovered_scheme[, UL_in := NA_character_]
  recovered_problems <- eval_cap013(invalid_recovered_scheme)
  testthat::expect_true(any(grepl("Dead-on-capture rows must record the recovered combo", recovered_problems$reason, fixed = TRUE)))

  first_marking <- data.table::copy(recovered_dead)
  first_marking[, `:=`(
    capture_status = "F",
    UL_in = "X",
    LL_in = "X",
    UR_in = "X",
    LR_in = "X",
    UL = "FWZ9",
    LL = "X",
    UR = "M",
    LR = "X"
  )]
  testthat::expect_false(any(grepl("Juvenile captures", eval_cap013(first_marking)$reason)))

  changed_band <- data.table::copy(recovered_dead)
  changed_band[, `:=`(
    capture_status = "C",
    UL_in = "FWZ8",
    LL_in = "X",
    UR_in = "M",
    LR_in = "X",
    UL = "FWZ9",
    LL = "X",
    UR = "M",
    LR = "X"
  )]
  testthat::expect_false(any(grepl("Juvenile captures", eval_cap013(changed_band)$reason)))

  bad_first_marking <- data.table::copy(first_marking)
  bad_first_marking[, UL := "M"]
  testthat::expect_true(any(grepl("Juvenile captures must use", eval_cap013(bad_first_marking)$reason, fixed = TRUE)))

  bad_changed_band <- data.table::copy(changed_band)
  bad_changed_band[, UL := "M"]
  testthat::expect_true(any(grepl("Juvenile captures must use", eval_cap013(bad_changed_band)$reason, fixed = TRUE)))

  chick_dead_cr <- data.table::copy(recovered_dead)
  chick_dead_cr[, `:=`(age = "C", site = "CR", capture_method = "HA", UL_in = "X", LL_in = "O", UR_in = "M", LR_in = "X")]
  testthat::expect_equal(nrow(eval_cap013(chick_dead_cr)), 0L)
  testthat::expect_equal(nrow(eval_cap007(chick_dead_cr)), 0L)

  chick_dead_noncr <- data.table::copy(recovered_dead)
  chick_dead_noncr[, `:=`(age = "C", site = "AU", capture_method = "HA", UL_in = "M", LL_in = "X", UR_in = "X", LR_in = "B")]
  testthat::expect_equal(nrow(eval_cap013(chick_dead_noncr)), 0L)
  testthat::expect_equal(nrow(eval_cap007(chick_dead_noncr)), 0L)

  chick_dead_missing <- data.table::copy(chick_dead_cr)
  chick_dead_missing[, UL_in := NA_character_]
  testthat::expect_true(any(grepl("Dead-on-capture rows must record the recovered combo", eval_cap013(chick_dead_missing)$reason, fixed = TRUE)))

  chick_dead_uncertain <- data.table::copy(chick_dead_cr)
  chick_dead_uncertain[, UL_in := "?"]
  testthat::expect_true(any(grepl("cannot contain '?'", eval_cap001b(chick_dead_uncertain)$reason, fixed = TRUE)))

  chick_dead_release_filled <- data.table::copy(chick_dead_cr)
  chick_dead_release_filled[, UL := "M"]
  testthat::expect_true(any(grepl("Dead-on-capture rows must leave all release", eval_cap013(chick_dead_release_filled)$reason, fixed = TRUE)))
})
