test_that("main server initializes and updates the reference date", {
  app <- load_main_app()
  today <- as.Date(Sys.time(), tz = app$env$preferred_timezone)
  saved <- new.env(parent = emptyenv())
  saved$date <- as.Date(NA)
  saved$notices <- character()
  overview_calls <- new.env(parent = emptyenv())

  overview_plot_stub <- function(name) {
    force(name)
    overview_calls[[name]] <- as.Date(character())

    function(refdate, date_limits = NULL) {
      overview_calls[[name]] <- c(
        overview_calls[[name]],
        as.Date(refdate)
      )
      ggplot2::ggplot()
    }
  }

  app$env$get_reference_date <- function() today
  app$env$dbtable_is_updated <- function(...) "unchanged"
  app$env$set_reference_date <- function(refdate) {
    saved$date <- as.Date(refdate)
    TRUE
  }
  app$env$WarnToast <- function(message) {
    saved$notices <- c(saved$notices, as.character(message))
  }
  app$env$ErrToast <- function(...) NULL
  app$env$TABLE_show <- function(...) shiny::renderText("")
  app$env$later <- function(callback, delay = 0) callback()
  app$env$overview_date_limits <- function(refdate) {
    c(as.Date(refdate) - 30, as.Date(refdate))
  }
  app$env$overview_nests_graph <- overview_plot_stub("nests")
  app$env$overview_geolocator_graph <- overview_plot_stub("geolocator")
  app$env$overview_band_combos_graph <- overview_plot_stub("band_combos")
  app$env$overview_lay_date_graph <- overview_plot_stub("lay_date")
  app$env$overview_quota_graph <- overview_plot_stub("quota")

  shiny::testServer(app$server, {
    session$flushReact()

    output$overview_nests_show
    output$overview_geolocator_show
    output$overview_cr_combos_show
    output$overview_lay_date_show
    output$overview_quota_show

    expect_identical(as.Date(reference_date()), today)
    expect_identical(as.Date(active_refdate()), today)
    expect_identical(overview_calls$nests, today)
    expect_identical(overview_calls$geolocator, today)
    expect_identical(overview_calls$band_combos, today)
    expect_identical(overview_calls$lay_date, today)
    expect_identical(overview_calls$quota, today)
    expect_match(output$ref_date_text$html, as.character(today), fixed = TRUE)
    expect_match(output$open_gps$html, "../gpxui/", fixed = TRUE)
    expect_match(output$open_db$html, "db_ui/field_db.php", fixed = TRUE)

    next_date <- today + 1
    session$setInputs(refdate = as.character(next_date), set_refdate = 1)
    session$flushReact()

    expect_identical(saved$date, next_date)
    expect_identical(as.Date(reference_date()), next_date)
    expect_identical(tail(overview_calls$nests, 1), next_date)
    expect_identical(tail(overview_calls$geolocator, 1), next_date)
    expect_identical(tail(overview_calls$band_combos, 1), next_date)
    expect_identical(tail(overview_calls$lay_date, 1), next_date)
    expect_identical(tail(overview_calls$quota, 1), next_date)
    expect_true(any(grepl(
      as.character(next_date),
      saved$notices,
      fixed = TRUE
    )))
  })
})


test_that("overview graph helpers use aligned reference-date queries", {
  app <- load_main_app()
  refdate <- as.Date("2026-07-21")
  queries <- list()

  app$env$db_get <- function(sql, params) {
    queries[[length(queries) + 1]] <<- list(
      sql = sql,
      params = params
    )

    if (grepl("MIN(date_) AS start_date", sql, fixed = TRUE)) {
      return(data.frame(start_date = as.character(refdate - 30)))
    }

    if (grepl("SELECT COUNT", sql, fixed = TRUE)) {
      return(data.frame(n = 0))
    }

    data.frame()
  }

  date_limits <- app$env$overview_date_limits(refdate)

  expect_equal(date_limits, c(refdate - 30, refdate))
  expect_s3_class(
    app$env$overview_nests_graph(refdate, date_limits),
    "ggplot"
  )
  expect_s3_class(
    app$env$overview_geolocator_graph(refdate, date_limits),
    "ggplot"
  )
  expect_s3_class(
    app$env$overview_band_combos_graph(refdate, date_limits),
    "ggplot"
  )
  expect_s3_class(
    app$env$overview_lay_date_graph(refdate, date_limits),
    "ggplot"
  )

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  quota_plots <- app$env$overview_quota_graph(refdate)

  expect_length(quota_plots, 4)
  expect_length(queries, 9)
  expect_true(all(vapply(
    queries,
    function(query) identical(
      query$params,
      list(as.character(refdate))
    ),
    logical(1)
  )))

  geolocator_quota_sql <- queries[[6]]$sql

  expect_match(
    geolocator_quota_sql,
    "COUNT(DISTINCT NULLIF(TRIM(tag_id), ''))",
    fixed = TRUE
  )

  expect_match(queries[[1]]$sql, "MIN(date_) AS start_date", fixed = TRUE)
  expect_match(queries[[2]]$sql, "COALESCE(site, ''))) = 'CR'", fixed = TRUE)
  expect_match(queries[[3]]$sql, "COALESCE(site, ''))) = 'CR'", fixed = TRUE)
  expect_match(queries[[4]]$sql, "FROM CAPTURES_ARCHIVE", fixed = TRUE)
  expect_match(queries[[5]]$sql, "COALESCE(site, ''))) = 'CR'", fixed = TRUE)
})


test_that("overview cumulative ribbons contain no diagonal segments", {
  app <- load_main_app()
  x <- data.table::data.table(
    plot_date = as.Date(c("2026-08-01", "2026-08-03", "2026-08-07")),
    cumulative_n = c(1L, 3L, 4L)
  )

  ribbon <- app$env$overview_step_ribbon_data(x)
  x_change <- diff(as.numeric(ribbon$plot_date))
  y_change <- diff(ribbon$cumulative_n)

  expect_true(all(x_change == 0 | y_change == 0))

  sex_counts <- data.table::data.table(
    plot_date = as.Date(c(
      "2026-08-01",
      "2026-08-03",
      "2026-08-02",
      "2026-08-07"
    )),
    sex = c("Female", "Female", "Male", "Male"),
    cumulative_n = c(1L, 2L, 1L, 2L)
  )
  plot <- app$env$overview_cumulative_plot(
    sex_counts,
    ylab = "Cumulative count",
    sex_split = TRUE,
    date_limits = as.Date(c("2026-08-01", "2026-08-10"))
  )

  expect_silent(ggplot2::ggplot_build(plot))
  expect_identical(plot$theme$legend.position, "inside")
  expect_equal(plot$theme$legend.position.inside, c(0.02, 0.98))
  expect_equal(
    plot$coordinates$limits$x,
    as.Date(c("2026-08-01", "2026-08-10"))
  )
})
