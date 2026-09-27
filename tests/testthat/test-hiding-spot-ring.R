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
