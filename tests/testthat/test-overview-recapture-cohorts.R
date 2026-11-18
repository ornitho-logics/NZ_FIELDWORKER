# Source definitions only; database reads are replaced with an aggregate mock.
recapture_cohorts_test_env <- function() {
  env <- new.env(parent = asNamespace("ggplot2"))
  for (name in c("data.table", "as.data.table", "copy", "fifelse", "let")) {
    env[[name]] <- getExportedValue("data.table", name)
  }
  sys.source(app_file("main", "R", "overview_recapture_cohorts.R"), env)
  env
}


test_that("recapture cohorts query is bounded to two previous years and Cass adults", {
  env <- recapture_cohorts_test_env()
  query <- NULL
  parameters <- NULL
  env$db_get <- function(sql, params) {
    query <<- sql
    parameters <<- params
    data.table::data.table(cohort_year = 2024:2025,
                          n_previous = c(20, 10), n_recaptured = c(5, 0))
  }
  x <- env$overview_recapture_cohorts_data(as.Date("2026-11-18"))
  expect_identical(parameters, as.list(c(
    "2026-01-01", "2026-01-01", "2024-01-01", "2026-01-01",
    "2024-01-01", "2026-01-01", "2026-01-01", "2026-11-18"
  )))
  for (fragment in c(
    "FROM CAPTURES_ARCHIVE", "UPPER(TRIM(site_code)) = 'CR'",
    "UPPER(TRIM(site)) = 'CR'", "UPPER(TRIM(age)) = 'A'",
    "COUNT(DISTINCT h.ring_key)", "COUNT(DISTINCT c.ring_key)",
    "LEFT JOIN history", "LEFT JOIN current_birds"
  )) expect_match(query, fragment, fixed = TRUE)
  expect_equal(x$n_recaptured, c(5, 0))
})


test_that("cohort bars label counts, percentages, zero recaptures, and missing cohorts", {
  env <- recapture_cohorts_test_env()
  x <- data.table::data.table(cohort_year = 2024:2025,
                             n_previous = c(20, 10), n_recaptured = c(5, 0))
  before <- data.table::copy(x)
  plot <- env$overview_recapture_cohorts_plot(x, as.Date("2026-11-18"))
  expect_equal(plot$data$proportion, c(0.25, 0))
  expect_equal(plot$data$label, c("5 / 20 (25.0%)", "0 / 10 (0.0%)"))
  expect_identical(x, before)
  expect_silent(ggplot2::ggplot_build(plot))

  x[, `:=`(n_previous = 0, n_recaptured = 0)]
  plot <- env$overview_recapture_cohorts_plot(x, as.Date("2026-11-18"))
  expect_true(all(is.na(plot$data$proportion)))
  expect_true(all(plot$data$label == "No previous captures"))
  expect_silent(ggplot2::ggplot_build(plot))
})
