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


test_that("H snapshot output is unchanged for canonical evidence and excludes the retired fallback", {
  snapshot_counts <- function(associations, targets, allowed_methods) {
    associations <- associations[
      !is.na(associations$resolved_nest_id) &
        nzchar(trimws(associations$resolved_nest_id)) &
        associations$association_method %in% allowed_methods,
      ,
      drop = FALSE
    ]
    if (!nrow(associations)) {
      return(data.frame(
        nest_id = character(),
        n_hiding_spot_photos = integer(),
        stringsAsFactors = FALSE
      ))
    }

    associations$nest_id <- trimws(as.character(associations$resolved_nest_id))
    associations$ring_key <- gsub(
      "-",
      "",
      toupper(trimws(as.character(associations$ring))),
      fixed = TRUE
    )
    targets$nest_id <- trimws(as.character(targets$nest_id))
    targets$ring_key <- gsub(
      "-",
      "",
      toupper(trimws(as.character(targets$ring_key))),
      fixed = TRUE
    )

    observed <- merge(
      unique(associations[c("nest_id", "ring_key")]),
      unique(targets[c("nest_id", "ring_key")]),
      by = c("nest_id", "ring_key")
    )
    if (!nrow(observed)) {
      return(data.frame(
        nest_id = character(),
        n_hiding_spot_photos = integer(),
        stringsAsFactors = FALSE
      ))
    }

    counts <- aggregate(
      ring_key ~ nest_id,
      data = observed,
      FUN = length
    )
    names(counts)[names(counts) == "ring_key"] <-
      "n_hiding_spot_photos"
    counts[order(counts$nest_id), , drop = FALSE]
  }

  associations <- data.frame(
    resighting_pk = 1:8,
    ring = c("CP101", "CP102", "CP103", "CP104", "CP104", "CP105", "CP106", "CP107"),
    resolved_nest_id = c(
      "A_DIRECT", "-B_NEG", "-B_NEG", "A_DIRECT", "A_DIRECT", "A_HIST",
      NA_character_, "A_FALLBACK"
    ),
    association_method = c(
      "direct", "same_occasion_adult", "ring_capture", "same_occasion_adult",
      "same_occasion_adult", "ring_capture", "ambiguous_capture_history",
      "authoritative_parent_same_occasion"
    ),
    stringsAsFactors = FALSE
  )
  targets <- data.frame(
    nest_id = c("A_DIRECT", "A_DIRECT", "-B_NEG", "-B_NEG", "A_HIST", "A_FALLBACK"),
    ring_key = c("CP101", "CP104", "CP102", "CP103", "CP105", "CP107"),
    stringsAsFactors = FALSE
  )

  current_methods <- c("direct", "same_occasion_adult", "ring_capture")
  legacy_methods <- c(current_methods, "authoritative_parent_same_occasion")
  canonical <- associations[
    associations$association_method != "authoritative_parent_same_occasion",
    ,
    drop = FALSE
  ]

  expect_equal(
    snapshot_counts(canonical, targets, current_methods),
    snapshot_counts(canonical, targets, legacy_methods)
  )
  expect_equal(
    snapshot_counts(associations, targets, current_methods),
    data.frame(
      nest_id = c("-B_NEG", "A_DIRECT", "A_HIST"),
      n_hiding_spot_photos = c(2L, 2L, 1L),
      stringsAsFactors = FALSE
    )
  )
})


test_that("multiple H rows for one resolved brood produce one operational task", {
  resolved_h_rows <- c("A_MOCK", "A_MOCK", "A_MOCK")
  expect_identical(unique(resolved_h_rows), "A_MOCK")
  expect_length(unique(resolved_h_rows), 1L)
})
