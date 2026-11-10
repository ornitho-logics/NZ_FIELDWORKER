phenology_test_env <- function() {
  for (package in c("data.table", "ggplot2", "stringr", "glue", "shiny")) {
    library(package, character.only = TRUE)
  }
  env <- new.env(parent = globalenv())
  sys.source(app_file("main", "R", "display_nest_ids.R"), env)
  sys.source(app_file("main", "R", "phenology.R"), env)
  env
}


test_that("daily phenology counts each nest once", {
  env <- phenology_test_env()
  rows <- data.table(
    nest_id = c("FAKE1", "FAKE1", "FAKE1", "FAKE2", "FAKE3", NA_character_),
    laid = as.Date(c("2026-09-01", "2026-09-01", "2026-09-01", "2026-09-01", "2026-09-05", "2026-09-01")),
    tag_id = c("FAKE_GEO1", "FAKE_GEO1", "FAKE_GEO2", "FAKE_GEO3", NA, NA)
  )
  before <- copy(rows)
  counts <- env$phenology_counts(rows)
  expect_equal(counts$nests, c(2, 1))
  expect_equal(rows, before)

  expect_equal(counts$day, as.Date(c("2026-09-01", "2026-09-05")))

  plot <- env$phenology_plot(rows, as.Date("2026-11-10"))
  expect_s3_class(plot, "ggplot")
  expect_silent(ggplot_build(plot))
  expect_silent(ggplot_build(env$phenology_plot(data.table(), as.Date("2026-11-10"))))
})


test_that("phenology queries only eligible Cass River estimates", {
  env <- phenology_test_env()
  calls <- list()
  env$db_get <- function(query, params) {
    calls[[length(calls) + 1]] <<- list(query = query, params = params)
    data.table(nest_id = "FAKE1", laid = as.Date("2026-09-01"), tag_id = NA_character_)
  }
  dat <- env$phenology_data(as.Date("2026-11-10"))
  expect_equal(nrow(dat), 1)
  expect_length(calls, 1)
  expect_identical(calls[[1]]$params, list("2026-11-10"))
  sql <- calls[[1]]$query
  for (fragment in c("DATE_SUB(MAX(e.float_date)",
                     "ROUND(AVG(e.predicted_days_since_laying))",
                     "UPPER(TRIM(n.site)) = 'CR'")) {
    expect_match(sql, fragment, fixed = TRUE)
  }
})


test_that("only opening Overview or changing its reference date reruns phenology", {
  env <- phenology_test_env()
  calls <- list()
  env$phenology_data <- function(date) {
    calls[[length(calls) + 1]] <<- date
    data.table(nest_id = "FAKE1", laid = date - 4, tag_id = NA_character_)
  }
  env$geo_data <- function(date) data.table(day = date, tags = 2)
  env$try_else <- function(expr, ...) force(expr)
  wrapper <- function(input, output, session) {
    date <- reactiveVal(as.Date("2026-11-10"))
    env$phenology_server(input, output, session, date)
  }
  shiny::testServer(wrapper, {
    session$setInputs(main = "intro")
    expect_error(output$overview_lay_date_show, class = "shiny.silent.error")
    expect_length(calls, 0)
    session$setInputs(main = "overview")
    expect_true(is.list(output$overview_lay_date_show))
    expect_equal(tail(calls, 1)[[1]], as.Date("2026-11-10"))
    date(as.Date("2026-11-11"))
    session$flushReact()
    expect_true(is.list(output$overview_lay_date_show))
    expect_equal(tail(calls, 1)[[1]], as.Date("2026-11-11"))
  })
})


test_that("daily deployment counts use capture dates and include replacement devices", {
  env <- phenology_test_env()
  calls <- list()
  env$db_get <- function(query, params) {
    calls[[1]] <<- list(query = query, params = params)
    data.table(day = as.Date(c("2026-09-01", "2026-09-02")), tags = c(6, 3))
  }
  dat <- env$geo_data(as.Date("2026-11-10"))
  expect_identical(calls[[1]]$params, list("2026-11-10"))
  sql <- calls[[1]]$query
  for (fragment in c("COUNT(DISTINCT TRIM(tag_id))", "GROUP BY date",
                     "UPPER(TRIM(site)) = 'CR'", "UPPER(TRIM(tag_type)) = 'GEO'",
                     "UPPER(TRIM(tag_action)) IN ('D', 'N')")) {
    expect_match(sql, fragment, fixed = TRUE)
  }
  expect_false(str_detect(sql, "nest_id"))
  plot <- env$phenology_plot(data.table(), as.Date("2026-11-10"), deployments = dat)
  built <- ggplot_build(plot)
  expect_equal(built$data[[1]]$xmax - built$data[[1]]$xmin, c(0.82, 0.82))
  expect_equal(nrow(built$layout$layout), 2)
  expect_equal(unique(built$layout$layout$SCALE_X), 1)
  expect_false(any(vapply(plot$layers, function(layer) inherits(layer$geom, "GeomLabel"), TRUE)))
  expect_true(all(built$data[[1]]$fill == "black"))
  expect_silent(ggplot_build(env$phenology_plot(data.table(), as.Date("2026-11-10"))))
})


test_that("both panels share one date axis even with different observation windows", {
  env <- phenology_test_env()
  plot <- env$phenology_plot(
    data.table(nest_id = "FAKE1", laid = as.Date("2026-09-01")),
    as.Date("2026-11-10"),
    deployments = data.table(day = as.Date("2026-10-15"), tags = 3)
  )
  built <- ggplot_build(plot)
  expect_equal(nrow(built$layout$layout), 2)
  expect_equal(unique(built$layout$layout$SCALE_X), 1)
  expect_identical(built$layout$panel_params[[1]]$x.range,
                   built$layout$panel_params[[2]]$x.range)
  expect_equal(built$data[[1]]$y, c(1, 3))
  expect_equal(plot$theme$axis.text.x$angle, 90)
})
