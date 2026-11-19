nest_finders_test_env <- function() {
  env <- new.env(parent = asNamespace("ggplot2"))
  env$.datatable.aware <- TRUE
  for (name in c("data.table", "as.data.table", "copy", "setorder")) {
    env[[name]] <- getExportedValue("data.table", name)
  }
  sys.source(app_file("main", "R", "overview_nest_finders.R"), env)
  env
}


test_that("nest finder queries include the chosen contributors and zero counts", {
  env <- nest_finders_test_env()
  query <- NULL
  parameters <- NULL
  env$db_get <- function(sql, params) {
    query <<- sql
    parameters <<- params
    data.table::data.table(
      observer_code = " bk ", contributor = "Invented Finder (BK)", n_found = 2,
      first_found = as.Date("2026-11-15"), last_found = as.Date("2026-11-15"),
      field_start = as.Date("2026-11-13"), field_stop = as.Date(NA_character_)
    )
  }
  x <- env$overview_nest_finders_data(as.Date("2026-11-19"))
  expect_identical(parameters, list("2026-11-19"))
  expect_setequal(x$observer_code, env$overview_nest_finders_included_codes)
  expect_equal(nrow(x), 11L)
  expect_equal(x[observer_code == "BK", n_found], 2)
  expect_true(all(x[observer_code != "BK", n_found] == 0))
  plot <- env$overview_nest_finders_plot(x, as.Date("2026-11-19"))
  expect_equal(nrow(plot$data), 11L)
  expect_equal(plot$data[observer_code == "BK", nests_per_week], 2)
  for (fragment in c(
    "ROW_NUMBER() OVER", "PARTITION BY UPPER(TRIM(nest_id))",
    "ORDER BY date, COALESCE(time_visit, '00:00:00'), pk",
    "nest_state = 'F'", "UPPER(TRIM(site)) = 'CR'", "date <= ?",
    "discovery_rank = 1", "FROM OBSERVERS", "LEFT JOIN contributors",
    "SELECT observer_code FROM contributors", "LEFT JOIN counts", "COALESCE(c.n_found, 0)",
    "MIN(start) AS field_start", "MAX(stop)",
    "Unrecorded", "NO_NEST"
  )) expect_match(query, fragment, fixed = TRUE)
})


test_that("failed queries are not presented as a leaderboard of zero counts", {
  env <- nest_finders_test_env()
  env$db_get <- function(...) data.table::data.table(error = "Invented query error")
  expect_error(env$overview_nest_finders_data(as.Date("2026-11-19")),
               "Nest-finding data could not be loaded", fixed = TRUE)
})


test_that("nest finder rankings retain zeros without trophies and rank weekly rates", {
  env <- nest_finders_test_env()
  x <- data.table::data.table(
    observer_code = c("BK", "LEH", "ADO", "KD"),
    contributor = c("Invented A", "Invented B", "Invented C", "Invented D"),
    n_found = c(0, 3, 3, 1),
    field_start = as.Date(c("2026-11-06", "2026-11-13", "2026-11-06", "2026-11-06")),
    field_stop = as.Date(c(NA, NA, NA, "2026-11-12")),
    first_found = as.Date(c(rep("2026-11-13", 3), "2026-11-08")),
    last_found = as.Date(c(rep("2026-11-13", 3), "2026-11-08"))
  )
  before <- data.table::copy(x)
  plot <- env$overview_nest_finders_plot(x, as.Date("2026-11-19"))
  expect_identical(plot$data$observer_code, c("LEH", "ADO", "KD", "BK"))
  expect_equal(plot$data$nests_per_week, c(3, 1.5, 1, 0))
  expect_equal(plot$data$n_found, c(3, 3, 1, 0))
  expect_identical(plot$data$total_label, c("3 nests", "3 nests", "1 nest", "0 nests"))
  expect_identical(plot$data$podium, c("\U0001F3C6 ", "\U0001F948 ", "\U0001F949 ", ""))
  expect_identical(x, before)
  expect_silent(ggplot2::ggplot_build(plot))
  expect_silent(ggplot2::ggplot_build(env$overview_nest_finders_plot(
    x[0], as.Date("2026-11-19")
  )))
})


test_that("missing or inconsistent field dates do not invent a rate", {
  env <- nest_finders_test_env()
  x <- data.table::data.table(
    observer_code = c("BK", "LEH", "ADO", "KD"),
    contributor = c("Invented A", "Invented B", "Invented C", "Invented D"),
    n_found = c(2, 2, 2, 2),
    field_start = as.Date(c(NA, "2026-11-20", "2026-11-13", "2026-11-13")),
    field_stop = as.Date(c(NA, NA, "2026-12-01", "2026-12-01")),
    first_found = as.Date(rep("2026-11-13", 4)),
    last_found = as.Date(rep("2026-11-13", 4))
  )
  plot <- env$overview_nest_finders_plot(x, as.Date("2026-11-19"))
  expect_equal(plot$data[observer_code == "ADO", nests_per_week], 2)
  expect_true(all(is.na(plot$data[observer_code %in% c("BK", "LEH"), nests_per_week])))
  expect_true(all(plot$data[observer_code %in% c("BK", "LEH"), podium] == ""))
  expect_true(all(plot$data[observer_code %in% c("ADO", "KD"), podium] == "\U0001F3C6 "))
  expect_true(all(grepl("rate unavailable",
    plot$data[observer_code %in% c("BK", "LEH"), total_label], fixed = TRUE)))
  expect_silent(ggplot2::ggplot_build(plot))
})


test_that("only included contributor codes appear and zero finds need no discovery dates", {
  env <- nest_finders_test_env()
  x <- data.table::data.table(
    observer_code = c("BK", "ZZ", "CS"),
    contributor = c("Invented Included", "Invented Other", "Invented Excluded"),
    n_found = c(0, 20, 30),
    field_start = as.Date(rep("2026-11-13", 3)),
    field_stop = as.Date(rep(NA_character_, 3)),
    first_found = as.Date(rep(NA_character_, 3)),
    last_found = as.Date(rep(NA_character_, 3))
  )
  plot <- env$overview_nest_finders_plot(x, as.Date("2026-11-19"))
  expect_identical(plot$data$observer_code, "BK")
  expect_equal(plot$data$nests_per_week, 0)
  expect_identical(plot$data$total_label, "0 nests")
  expect_identical(plot$data$podium, "")
  expect_silent(ggplot2::ggplot_build(plot))
})
