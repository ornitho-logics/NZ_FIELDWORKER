library(testthat)

views_sql <- paste(
  readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
  collapse = "\n"
)
refresh_sql <- paste(
  readLines(app_file("DATABASE", "refresh_todo_list_snapshot.SQL"), warn = FALSE),
  collapse = "\n"
)
main_tables_sql <- paste(
  readLines(app_file("DATABASE", "main_tables.SQL"), warn = FALSE),
  collapse = "\n"
)

mark_evidence_eligible <- function(mark_fields, ring_traced = FALSE) {
  if (any(grepl("\\?", mark_fields, fixed = FALSE), na.rm = TRUE)) {
    return(isTRUE(ring_traced))
  }
  TRUE
}

test_that("question-mark uncertainty is event-wide unless a traced ring overrides it", {
  expect_false(mark_evidence_eligible(c("X", "?", "X", "X")))
  expect_false(mark_evidence_eligible(c("X", "?R", "X", "X")))
  expect_false(mark_evidence_eligible(c("X", "R?", "X", "X")))
  expect_false(mark_evidence_eligible(c("FABC", "B", "?", "Y")))
  expect_true(mark_evidence_eligible(c("X", "?R", "X", "X"), ring_traced = TRUE))
  expect_false(mark_evidence_eligible(c("X", "?R", "X", "X"), ring_traced = FALSE))
  expect_true(mark_evidence_eligible(c("X", "B", "X", "Y")))
})

test_that("installed SQL exposes one uncertainty gate across parent evidence paths", {
  expect_match(views_sql, "has_uncertain_mark", fixed = TRUE)
  expect_match(views_sql, "ring_traced_to_capture", fixed = TRUE)
  expect_match(views_sql, "association_evidence_eligible", fixed = TRUE)
  expect_match(views_sql, "ADULT_PARENT_NEST_ASSOCIATIONS", fixed = TRUE)
  expect_match(views_sql, "c.association_evidence_eligible = 1", fixed = TRUE)
  expect_match(views_sql, "r.association_evidence_eligible = 1", fixed = TRUE)
  expect_match(views_sql, "matched.association_evidence_eligible = 1", fixed = TRUE)
  expect_match(views_sql, "CAPTURES_ARCHIVE archive_ring", fixed = TRUE)
})

test_that("install and refresh S10 paths use the same uncertainty gate", {
  expect_match(views_sql, "matched.association_evidence_eligible = 1", fixed = TRUE)
  expect_match(refresh_sql, "matched.association_evidence_eligible = 1", fixed = TRUE)
  expect_match(refresh_sql, "association_evidence_eligible", fixed = TRUE)
})

test_that("the retired NO_NEST sentinel is absent from active entry hints", {
  expect_no_match(main_tables_sql, "NO_NEST", fixed = TRUE)
})
