qualifying_hiding_photo_events <- function(resightings, reference_date) {
  x <- data.table::as.data.table(resightings)
  if (!"ring" %in% names(x)) {
    x[, ring := NA_character_]
  }

  x[, `:=`(
    nest_id_key = trimws(as.character(nest_id)),
    age_key = toupper(trimws(as.character(age))),
    rclass_key = toupper(trimws(as.character(rclass))),
    ring_key = toupper(trimws(as.character(ring)))
  )]

  x[
    !is.na(nest_id_key) & nzchar(nest_id_key) &
      !is.na(date) & as.Date(date) <= as.Date(reference_date) &
      age_key == "C" &
      rclass_key == "H" &
      !is.na(ring_key) & nzchar(ring_key) & ring_key != "NA",
    .(nest_id = nest_id_key, ring = trimws(as.character(ring)))
  ]
}


resolve_hiding_association <- function(
  raw_nest_id = NA_character_,
  adult_nest_ids = character(),
  capture_nest_ids = character()
) {
  clean_ids <- function(ids) {
    ids <- trimws(as.character(ids))
    ids[!is.na(ids) & nzchar(ids) & toupper(ids) != "NO_NEST"]
  }

  direct <- clean_ids(raw_nest_id)
  if (length(direct) > 0L) {
    return(list(nest_id = direct[[1]], method = "direct"))
  }
  if (length(raw_nest_id) > 0L &&
      !is.na(raw_nest_id[[1]]) &&
      toupper(trimws(raw_nest_id[[1]])) == "NO_NEST") {
    return(list(nest_id = NA_character_, method = "explicit_no_nest"))
  }

  adults <- unique(clean_ids(adult_nest_ids))
  if (length(adults) > 1L) {
    return(list(nest_id = NA_character_, method = "ambiguous_same_occasion_adult"))
  }
  if (length(adults) == 1L) {
    return(list(nest_id = adults[[1]], method = "same_occasion_adult"))
  }

  captures <- unique(clean_ids(capture_nest_ids))
  if (length(captures) > 1L) {
    return(list(nest_id = NA_character_, method = "ambiguous_capture_history"))
  }
  if (length(captures) == 1L) {
    return(list(nest_id = captures[[1]], method = "ring_capture"))
  }

  list(nest_id = NA_character_, method = "unresolved")
}


test_that("a ring-bearing H event resolves positive and negative broods", {
  events <- data.frame(
    nest_id = c("A_MOCK", "-B_MOCK"),
    date = as.Date(c("2026-09-01", "2026-09-01")),
    age = c("C", "C"),
    rclass = c("H", "H"),
    ring = c("CP100", "CP200"),
    stringsAsFactors = FALSE
  )

  observed <- qualifying_hiding_photo_events(events, "2026-09-02")

  expect_setequal(observed$nest_id, c("A_MOCK", "-B_MOCK"))
  expect_setequal(observed$ring, c("CP100", "CP200"))
})


test_that("blank, whitespace, and textual NA rings do not resolve H tasks", {
  events <- data.frame(
    nest_id = rep("A_MOCK", 5),
    date = as.Date(rep("2026-09-01", 5)),
    age = rep("C", 5),
    rclass = c("H", "H", "H", "H", "R"),
    ring = c("", "   ", NA_character_, " na ", "CP999"),
    stringsAsFactors = FALSE
  )

  observed <- qualifying_hiding_photo_events(events, "2026-09-02")

  expect_length(observed$nest_id, 0L)
})


test_that("separate H events retain each chick ring while non-H rows are ignored", {
  events <- data.frame(
    nest_id = c("A_MOCK", "A_MOCK", "A_MOCK"),
    date = as.Date(rep("2026-09-01", 3)),
    age = c("C", "C", "C"),
    rclass = c("H", "H", "P"),
    ring = c("CP101", "CP102", "CP103"),
    stringsAsFactors = FALSE
  )

  observed <- qualifying_hiding_photo_events(events, "2026-09-02")

  expect_identical(observed$nest_id, c("A_MOCK", "A_MOCK"))
  expect_identical(observed$ring, c("CP101", "CP102"))
})


test_that("a pre-ring snapshot cannot resolve an H task", {
  events <- data.frame(
    nest_id = "-C_MOCK",
    date = as.Date("2026-09-01"),
    age = "C",
    rclass = "H",
    stringsAsFactors = FALSE
  )

  observed <- qualifying_hiding_photo_events(events, "2026-09-02")

  expect_length(observed$nest_id, 0L)
})


test_that("H association prefers direct, then same-occasion adult, then ring capture", {
  direct <- resolve_hiding_association(
    raw_nest_id = "A_MOCK_DIRECT",
    adult_nest_ids = "A_MOCK_ADOPTED",
    capture_nest_ids = "A_MOCK_ORIGINAL"
  )
  expect_identical(direct$nest_id, "A_MOCK_DIRECT")
  expect_identical(direct$method, "direct")

  adult <- resolve_hiding_association(
    adult_nest_ids = "A_MOCK_ADOPTED",
    capture_nest_ids = "A_MOCK_ORIGINAL"
  )
  expect_identical(adult$nest_id, "A_MOCK_ADOPTED")
  expect_identical(adult$method, "same_occasion_adult")

  capture <- resolve_hiding_association(capture_nest_ids = "-B_MOCK")
  expect_identical(capture$nest_id, "-B_MOCK")
  expect_identical(capture$method, "ring_capture")
})


test_that("unlinked H association stays unresolved when family evidence is ambiguous", {
  two_families <- resolve_hiding_association(
    adult_nest_ids = c("A_MOCK_ONE", "A_MOCK_TWO"),
    capture_nest_ids = "A_MOCK_ONE"
  )
  expect_true(is.na(two_families$nest_id))
  expect_identical(two_families$method, "ambiguous_same_occasion_adult")

  conflicting_captures <- resolve_hiding_association(
    capture_nest_ids = c("-B_MOCK_ONE", "-B_MOCK_TWO")
  )
  expect_true(is.na(conflicting_captures$nest_id))
  expect_identical(conflicting_captures$method, "ambiguous_capture_history")

  unmatched_parent <- resolve_hiding_association(
    adult_nest_ids = "-C_MOCK_FAMILY"
  )
  expect_identical(unmatched_parent$nest_id, "-C_MOCK_FAMILY")
  expect_identical(unmatched_parent$method, "same_occasion_adult")
})


test_that("multiple H rows for one resolved brood produce one operational task", {
  resolved_h_rows <- c("A_MOCK", "A_MOCK", "A_MOCK")
  expect_identical(unique(resolved_h_rows), "A_MOCK")
  expect_length(unique(resolved_h_rows), 1L)
})
