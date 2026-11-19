# Source definitions only; database reads are replaced with an aggregate mock.
recapture_cohorts_test_env <- function() {
  env <- new.env(parent = globalenv())
  env$.datatable.aware <- TRUE
  for (name in c("ggplot", "geom_col", "aes", "facet_wrap", "vars",
                 "coord_polar", "scale_y_continuous", "expansion",
                 "scale_fill_manual", "labs", "theme_void", "theme",
                 "element_text")) {
    env[[name]] <- getExportedValue("ggplot2", name)
  }
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


test_that("encounter cohorts add only adult Cass RESIGHTINGS with unique identity matching", {
  env <- recapture_cohorts_test_env()
  query <- NULL
  parameters <- NULL
  env$db_get <- function(sql, params) {
    query <<- sql
    parameters <<- params
    data.table::data.table(cohort_year = 2024:2025,
                          n_previous = c(20, 10), n_recaptured = c(8, 3))
  }
  plot <- env$overview_encounter_cohorts_graph(as.Date("2026-11-19"))
  expect_length(parameters, 12L)
  expect_identical(tail(parameters, 4), as.list(c(
    "2026-01-01", "2026-11-19", "2026-01-01", "2026-11-19"
  )))
  for (fragment in c(
    "FROM RESIGHTINGS r", "UPPER(TRIM(r.age)) = 'A'",
    "UPPER(TRIM(r.site)) = 'CR'", "r.date >= ? AND r.date <= ?",
    "HAVING COUNT(DISTINCT ring_key) = 1",
    "SELECT ring_key FROM current_birds\n      UNION\n      SELECT ring_key FROM sighted_birds",
    "LEFT JOIN encountered_birds", "COUNT(DISTINCT c.ring_key)"
  )) expect_match(query, fragment, fixed = TRUE)
  expect_false(grepl("RESIGHTINGS_PUBLIC", query, fixed = TRUE))
  expect_equal(plot$data$proportion, c(0.4, 0.3))
  expect_match(plot$labels$subtitle, "captures or resightings", fixed = TRUE)
  expect_silent(ggplot2::ggplot_build(plot))
})


test_that("cohort pies label counts, percentages, zero recaptures, and missing cohorts", {
  env <- recapture_cohorts_test_env()
  x <- data.table::data.table(cohort_year = 2024:2025,
                             n_previous = c(20, 10), n_recaptured = c(5, 0))
  before <- data.table::copy(x)
  plot <- env$overview_recapture_cohorts_plot(x, as.Date("2026-11-18"))
  expect_equal(plot$data$proportion, c(0.25, 0))
  expect_equal(plot$data$label, c("5 / 20 (25.0%)", "0 / 10 (0.0%)"))
  expect_identical(x, before)
  slices <- plot$layers[[1]]$data
  expect_equal(slices$fraction, c(0.25, 0, 0.75, 1))
  expect_s3_class(plot$coordinates, "CoordPolar")
  expect_silent(ggplot2::ggplot_build(plot))

  x[, `:=`(n_previous = 0, n_recaptured = 0)]
  plot <- env$overview_recapture_cohorts_plot(x, as.Date("2026-11-18"))
  expect_true(all(is.na(plot$data$proportion)))
  expect_true(all(plot$data$label == "No previous captures"))
  expect_equal(nrow(plot$layers[[1]]$data), 0L)
  expect_silent(ggplot2::ggplot_build(plot))

  x[, `:=`(n_previous = 10, n_recaptured = 10)]
  plot <- env$overview_recapture_cohorts_plot(x, as.Date("2026-11-18"))
  expect_equal(plot$layers[[1]]$data$fraction, c(1, 1, 0, 0))
  expect_true(all(plot$data$label == "10 / 10 (100.0%)"))
  expect_silent(ggplot2::ggplot_build(plot))
})
