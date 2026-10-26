normalize_resighting_value <- function(value) {
  value <- trimws(as.character(value))
  value[is.na(value) | !nzchar(value) | toupper(value) == "NA"] <- NA_character_
  value
}

resighting_parent_chick_link <- function(parent, chick) {
  same_date <- !is.na(parent$date) && !is.na(chick$date) &&
    as.Date(parent$date) == as.Date(chick$date)

  parent_nest <- normalize_resighting_value(parent$nest_id)
  chick_nest <- normalize_resighting_value(chick$nest_id)
  same_nest <- !is.na(parent_nest) && !is.na(chick_nest) &&
    toupper(parent_nest) != "NO_NEST" &&
    toupper(chick_nest) != "NO_NEST" &&
    parent_nest == chick_nest

  parent_gps_id <- normalize_resighting_value(parent$gps_id)
  chick_gps_id <- normalize_resighting_value(chick$gps_id)
  parent_gps_point <- normalize_resighting_value(parent$gps_point)
  chick_gps_point <- normalize_resighting_value(chick$gps_point)
  same_gps <- !is.na(parent_gps_id) && !is.na(chick_gps_id) &&
    !is.na(parent_gps_point) && !is.na(chick_gps_point) &&
    parent_gps_id == chick_gps_id && parent_gps_point == chick_gps_point

  isTRUE(same_date && (same_nest || same_gps))
}

resighting_parent_chick_issues <- function(rows) {
  parent_behaviour_codes <- c("BC", "FC", "AC")
  tokens <- strsplit(
    toupper(ifelse(is.na(rows$behav), "", rows$behav)),
    ",",
    fixed = TRUE
  )
  tokens <- lapply(tokens, trimws)

  parent_rows <- which(vapply(
    seq_len(nrow(rows)),
    function(i) rows$age[[i]] == "A" &&
      any(tokens[[i]] %in% parent_behaviour_codes),
    logical(1)
  ))
  chick_rows <- which(rows$age == "C")

  chick_failures <- chick_rows[!vapply(chick_rows, function(chick_i) {
    any(vapply(parent_rows, function(parent_i) {
      resighting_parent_chick_link(rows[parent_i, ], rows[chick_i, ])
    }, logical(1)))
  }, logical(1))]

  parent_failures <- parent_rows[!vapply(parent_rows, function(parent_i) {
    any(vapply(chick_rows, function(chick_i) {
      resighting_parent_chick_link(rows[parent_i, ], rows[chick_i, ])
    }, logical(1)))
  }, logical(1))]

  list(chick_failures = chick_failures, parent_failures = parent_failures)
}

test_that("AC parent with a same-date linked chick passes", {
  rows <- data.frame(
    date = as.Date(c("2026-10-24", "2026-10-24")),
    age = c("A", "C"),
    behav = c("AC", NA_character_),
    nest_id = c("A0001", "A0001"),
    gps_id = c(NA_character_, NA_character_),
    gps_point = c(NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )

  issues <- resighting_parent_chick_issues(rows)

  expect_length(issues$chick_failures, 0L)
  expect_length(issues$parent_failures, 0L)
})

test_that("an AC parent without a linked chick fails reciprocally", {
  rows <- data.frame(
    date = as.Date("2026-10-24"),
    age = "A",
    behav = "AC",
    nest_id = "A0001",
    gps_id = NA_character_,
    gps_point = NA_character_,
    stringsAsFactors = FALSE
  )

  issues <- resighting_parent_chick_issues(rows)

  expect_identical(issues$parent_failures, 1L)
  expect_length(issues$chick_failures, 0L)
})

test_that("a chick without a BC, FC, or AC parent fails", {
  rows <- data.frame(
    date = as.Date(c("2026-10-24", "2026-10-24")),
    age = c("A", "C"),
    behav = c("AT", NA_character_),
    nest_id = c("A0001", "A0001"),
    gps_id = c(NA_character_, NA_character_),
    gps_point = c(NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )

  issues <- resighting_parent_chick_issues(rows)

  expect_identical(issues$chick_failures, 2L)
  expect_length(issues$parent_failures, 0L)
})

test_that("same-date same-GPS linkage is accepted and mismatched linkage is rejected", {
  linked <- data.frame(
    date = as.Date(c("2026-10-24", "2026-10-24")),
    age = c("A", "C"),
    behav = c("AC", NA_character_),
    nest_id = c(NA_character_, NA_character_),
    gps_id = c("GPS1", "GPS1"),
    gps_point = c("10", "10"),
    stringsAsFactors = FALSE
  )
  mismatched <- linked
  mismatched$gps_point[[2L]] <- "11"

  expect_true(resighting_parent_chick_link(linked[1, ], linked[2, ]))
  expect_false(resighting_parent_chick_link(mismatched[1, ], mismatched[2, ]))

  different_date <- linked
  different_date$date[[2L]] <- as.Date("2026-10-25")
  expect_false(resighting_parent_chick_link(different_date[1, ], different_date[2, ]))
})

test_that("BC and FC retain the same reciprocal behavior as AC", {
  for (behaviour in c("BC", "FC")) {
    rows <- data.frame(
      date = as.Date(c("2026-10-24", "2026-10-24")),
      age = c("A", "C"),
      behav = c(behaviour, NA_character_),
      nest_id = c("A0001", "A0001"),
      gps_id = c(NA_character_, NA_character_),
      gps_point = c(NA_character_, NA_character_),
      stringsAsFactors = FALSE
    )

    passing <- resighting_parent_chick_issues(rows)
    expect_length(passing$chick_failures, 0L)
    expect_length(passing$parent_failures, 0L)

    failing <- resighting_parent_chick_issues(rows[1, , drop = FALSE])
    expect_identical(failing$parent_failures, 1L)
  }
})

test_that("tracked RESIGHTINGS exports include AC in both reciprocal rules", {
  hard <- paste(
    readLines(app_file(
      "notes/codex_proposals/validator_sandbox/inspector_lists_by_table/RESIGHTINGS_hard.R"
    )),
    collapse = "\n"
  )
  warning <- paste(
    readLines(app_file(
      "notes/codex_proposals/validator_sandbox/inspector_lists_by_table/RESIGHTINGS_warning.R"
    )),
    collapse = "\n"
  )

  expect_match(hard, "RES_005J")
  expect_match(hard, "RES_005K")
  expect_match(hard, "BC.*FC.*AC|BC.*AC.*FC")
  expect_match(warning, "AC")
})
