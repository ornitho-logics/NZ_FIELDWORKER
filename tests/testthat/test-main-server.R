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
  app$env$overview_tagged_resightings_graph <- overview_plot_stub(
    "tagged_resightings"
  )
  app$env$overview_band_combos_graph <- overview_plot_stub("band_combos")
  app$env$overview_lay_date_graph <- overview_plot_stub("lay_date")
  app$env$overview_hatching_forecast_graph <- overview_plot_stub(
    "hatching_forecast"
  )
  app$env$overview_quota_graph <- overview_plot_stub("quota")

  shiny::testServer(app$server, {
    session$flushReact()

    output$overview_nests_show
    output$overview_geolocator_show
    output$overview_tagged_resightings_show
    output$overview_cr_combos_show
    output$overview_lay_date_show
    output$overview_hatching_forecast_show
    output$overview_quota_show

    expect_identical(as.Date(reference_date()), today)
    expect_identical(as.Date(active_refdate()), today)
    expect_identical(overview_calls$nests, today)
    expect_identical(overview_calls$geolocator, today)
    expect_identical(overview_calls$tagged_resightings, today)
    expect_identical(overview_calls$band_combos, today)
    expect_identical(overview_calls$lay_date, today)
    expect_identical(overview_calls$hatching_forecast, today)
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
    expect_identical(
      tail(overview_calls$tagged_resightings, 1),
      next_date
    )
    expect_identical(tail(overview_calls$band_combos, 1), next_date)
    expect_identical(tail(overview_calls$lay_date, 1), next_date)
    expect_identical(
      tail(overview_calls$hatching_forecast, 1),
      next_date
    )
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

    if (grepl("parent_events AS", sql, fixed = TRUE)) {
      return(data.frame(
        n_confirmed_pairs = 0,
        n_pairs_total = 0
      ))
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
    app$env$overview_tagged_resightings_graph(refdate, date_limits),
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
  expect_s3_class(
    app$env$overview_hatching_forecast_graph(refdate),
    "ggplot"
  )

  expect_length(quota_plots, 4)
  expect_length(queries, 13)
  expect_true(all(vapply(
    queries,
    function(query) {
      expected_params <- if (grepl(
        "parent_events AS",
        query$sql,
        fixed = TRUE
      )) {
        list(as.character(refdate))
      } else {
        list(as.character(refdate))
      }
      identical(query$params, expected_params)
    },
    logical(1)
  )))

  geolocator_quota_sql <- queries[[9]]$sql

  expect_match(
    geolocator_quota_sql,
    "COUNT(DISTINCT NULLIF(TRIM(tag_id), ''))",
    fixed = TRUE
  )

  expect_match(queries[[1]]$sql, "MIN(date_) AS start_date", fixed = TRUE)
  expect_match(queries[[2]]$sql, "COALESCE(site, ''))) = 'CR'", fixed = TRUE)
  expect_match(queries[[3]]$sql, "COALESCE(site, ''))) = 'CR'", fixed = TRUE)
  expect_match(queries[[4]]$sql, "parent_events AS", fixed = TRUE)
  expect_match(queries[[4]]$sql, "n_confirmed_pairs", fixed = TRUE)
  expect_match(queries[[4]]$sql, "identity_match", fixed = TRUE)
  expect_match(queries[[4]]$sql, "n_matching_post_mm_resightings", fixed = TRUE)
  expect_match(queries[[4]]$sql, "requires_spacer_identity", fixed = TRUE)
  expect_match(queries[[4]]$sql, "has_xx_nest_behav", fixed = TRUE)
  expect_match(
    queries[[4]]$sql,
    "has_geolocator AS has_geo",
    fixed = TRUE
  )
  expect_match(
    queries[[4]]$sql,
    "COALESCE(f.n_matching_post_mm_resightings, 0) < 3",
    fixed = TRUE
  )
  expect_match(
    queries[[4]]$sql,
    "FROM capture_events c\n  WHERE c.mark IS NOT NULL",
    fixed = TRUE
  )
  expect_match(
    queries[[4]]$sql,
    "mm_xx_parent_confirmed = 1 OR mm_resight_pending = 1",
    fixed = TRUE
  )
  expect_match(queries[[5]]$sql, "FROM deployments d", fixed = TRUE)
  expect_match(queries[[5]]$sql, "r.comments", fixed = TRUE)
  expect_match(
    queries[[5]]$sql,
    "PARTITION BY tarsus_mark, capture_sex",
    fixed = TRUE
  )
  expect_match(
    queries[[5]]$sql,
    "r.resighting_sex = d.capture_sex",
    fixed = TRUE
  )
  expect_match(
    queries[[5]]$sql,
    "c.capture_status",
    fixed = TRUE
  )
  expect_match(queries[[6]]$sql, "FROM CAPTURES_ARCHIVE", fixed = TRUE)
  expect_match(queries[[7]]$sql, "has_banded_mark = 1", fixed = TRUE)
  expect_match(queries[[8]]$sql, "COALESCE(site, ''))) = 'CR'", fixed = TRUE)
  expect_match(
    queries[[8]]$sql,
    "LEFT JOIN geolocator_deployments",
    fixed = TRUE
  )
  expect_match(queries[[8]]$sql, "c.age, ''))) = 'A'", fixed = TRUE)
  expect_match(queries[[8]]$sql, "c.tag_type, ''))) = 'GEO'", fixed = TRUE)
  expect_match(queries[[8]]$sql, "c.tag_action, ''))) = 'D'", fixed = TRUE)
  expect_match(
    queries[[13]]$sql,
    "FROM EGGS_HATCH_PREDICTION e",
    fixed = TRUE
  )
  expect_match(
    queries[[13]]$sql,
    "e.predicted_hatch_date > sr.reference_date",
    fixed = TRUE
  )
})


test_that("pair tally does not fall back to the obsolete heuristic", {
  app <- load_main_app()
  calls <- 0L

  app$env$db_get <- function(sql, params) {
    calls <<- calls + 1L

    if (grepl("identity_match", sql, fixed = TRUE)) {
      return(data.frame(error = "mock database does not support the extended pair query"))
    }

    data.frame(n_confirmed_pairs = 19L, n_pairs_total = 25L)
  }

  expect_error(
    app$env$overview_pair_tallies(
      refdate = as.Date("2026-07-21"),
      require_geolocator = TRUE
    ),
    "mock database does not support the extended pair query"
  )
  expect_equal(calls, 1L)
})


test_that("pair protocol caption is shown under both pair-tally panels", {
  app <- load_main_app()
  refdate <- as.Date("2026-07-21")

  app$env$db_get <- function(sql, params) {
    if (grepl("MIN(date_) AS start_date", sql, fixed = TRUE)) {
      return(data.frame(start_date = as.character(refdate - 30)))
    }

    if (
      grepl("parent_events AS", sql, fixed = TRUE) &&
        grepl("m.has_geolocator = 1", sql, fixed = TRUE)
    ) {
      return(data.frame(n_confirmed_pairs = 2L, n_pairs_total = 19L))
    }

    if (grepl("parent_events AS", sql, fixed = TRUE)) {
      return(data.frame(n_confirmed_pairs = 3L, n_pairs_total = 20L))
    }

    data.frame()
  }

  expect_equal(
    app$env$overview_pair_tallies(refdate, require_geolocator = TRUE),
    c(confirmed_pairs = 2L, total_pairs = 19L)
  )
  expect_equal(
    app$env$overview_pair_tallies(refdate, require_geolocator = FALSE),
    c(confirmed_pairs = 3L, total_pairs = 20L)
  )

  geolocator_plot <- app$env$overview_geolocator_graph(refdate)
  band_combos_plot <- app$env$overview_band_combos_graph(refdate)
  caption <- app$env$overview_pair_confirmation_caption()

  expect_identical(geolocator_plot$labels$caption, caption)
  expect_identical(band_combos_plot$labels$caption, caption)
  expect_match(caption, "caught with the nest trap", fixed = TRUE)
  expect_match(caption, "resighted around the nest 3 times", fixed = TRUE)
  expect_match(caption, "behav class \"IN\", \"NM\", or \"BW\"", fixed = TRUE)
})


test_that("lay-date bins tally geolocators by associated nest", {
  app <- load_main_app()
  x <- data.frame(
    nest_id = c("MOCK_NEST_1", "MOCK_NEST_1", "MOCK_NEST_2", "MOCK_NEST_3"),
    datetime = as.Date(c(
      "2026-09-01",
      "2026-09-01",
      "2026-09-01",
      "2026-09-05"
    )),
    tag_id = c("MOCK_GEO_1", "MOCK_GEO_1", "MOCK_GEO_2", NA_character_)
  )

  bins <- app$env$overview_lay_date_bins(x, binwidth = 4L)

  expect_equal(sum(bins$n_nests), 3L)
  expect_equal(sum(bins$n_geolocators), 2L)
  expect_equal(bins$n_nests, c(2L, 1L))
  expect_equal(bins$n_geolocators, c(2L, 0L))

  plot <- app$env$overview_lay_date_plot(
    x,
    ylab = "N estimated lay dates",
    date_limits = as.Date(c("2026-08-25", "2026-09-10"))
  )

  expect_s3_class(plot, "ggplot")
  expect_silent(ggplot2::ggplot_build(plot))
})


test_that("hatching forecast uses one-day bins, three-day labels, and marks reference date", {
  app <- load_main_app()
  refdate <- as.Date("2026-09-01")
  x <- data.frame(
    nest_id = c("MOCK_NEST_1", "MOCK_NEST_2", "MOCK_NEST_3"),
    datetime = as.POSIXct(
      c("2026-08-31 00:00:00", "2026-09-03 00:00:00", "2026-09-10 00:00:00"),
      tz = "UTC"
    )
  )

  plot <- app$env$overview_hatching_forecast_plot(x, refdate)

  expect_s3_class(plot, "ggplot")
  built <- NULL
  expect_silent(built <- ggplot2::ggplot_build(plot))
  expect_equal(
    plot$coordinates$limits$x,
    as.Date(c("2026-08-29", "2026-09-10"))
  )
  histogram_index <- which(vapply(
    plot$layers,
    function(layer) inherits(layer$geom, "GeomBar"),
    logical(1)
  ))
  expect_length(histogram_index, 1L)
  expect_equal(plot$layers[[histogram_index]]$stat_params$binwidth, 1)
  vline_index <- which(vapply(
    plot$layers,
    function(layer) inherits(layer$geom, "GeomVline"),
    logical(1)
  ))
  expect_length(vline_index, 1L)
  expect_gt(vline_index, histogram_index)
  reference_label <- vapply(
    plot$layers,
    function(layer) {
      identical(layer$aes_params$label, "reference date") &&
        identical(layer$aes_params$angle, 90)
    },
    logical(1)
  )
  expect_true(any(reference_label))
  x_breaks <- built$layout$panel_params[[1]]$x$breaks
  x_breaks <- x_breaks[is.finite(x_breaks)]
  expect_equal(diff(x_breaks), rep(3, length(x_breaks) - 1L))
})


test_that("overview limp status distinguishes comment evidence", {
  app <- load_main_app()
  comments <- c(
    "walking normally",
    "slight hesitation while walking",
    "bird is limping",
    "foraging beside the river",
    "walks fine and limps",
    "walks well, no limp",
    "not limping today",
    "limp0",
    "limp: 1",
    "LIMP = 2"
  )

  expect_identical(
    app$env$overview_limp_status(comments),
    c(
      "No limp reported",
      "Possible/slight limp",
      "Limping",
      "No limp reported",
      "Limping",
      "No limp reported",
      "No limp reported",
      "No limp reported",
      "Possible/slight limp",
      "Limping"
    )
  )
  expect_identical(
    app$env$overview_tagged_mark_label(c("WY_GO_F", "BY_L_M")),
    c("WY-GO", "BY-L")
  )
  expect_identical(
    app$env$overview_tagged_display_mark(
      c("BY_L", "BY_L", "WY_GO"),
      c("TY", "TG", "TO"),
      c("L", "L", "GO")
    ),
    c("BY_Y.L", "BY_G.L", "WY_GO")
  )
  expect_identical(
    app$env$overview_deployment_linetype(c("C", "F", NA_character_)),
    c("dashed", "solid", "solid")
  )

  mock_histories <- data.frame(
    tarsus_mark = c("MOCK_A", "MOCK_A", "MOCK_B"),
    right_upper = c("TY", "TY", "TG"),
    right_tarsus = c("A", "A", "B"),
    sex = c("Female", "Female", "Male"),
    deployment_capture_status = c("C", "C", "F"),
    deployment_date = as.Date(c(
      "2026-09-01",
      "2026-09-01",
      "2026-09-03"
    )),
    resighting_pk = c(1L, 2L, 3L),
    resighting_date = as.Date(c(
      "2026-09-04",
      "2026-09-06",
      "2026-09-07"
    )),
    comments = c(
      "walking normally",
      "slight hesitation while walking",
      "bird is limping"
    )
  )
  plot <- app$env$overview_tagged_resighting_plot(
    mock_histories,
    date_limits = as.Date(c("2026-09-01", "2026-09-10"))
  )

  expect_s3_class(plot, "ggplot")
  expect_silent(ggplot2::ggplot_build(plot))
  expect_equal(
    plot$coordinates$limits$x,
    as.Date(c("2026-08-30", "2026-09-10"))
  )
  expect_s3_class(plot$facet, "FacetGrid")
  expect_true(plot$facet$params$free$y)
  expect_true(plot$facet$params$space_free$y)
  expect_setequal(
    plot$data$deployment_linetype,
    c("dashed", "solid")
  )
  expect_s3_class(plot$theme$strip.text.y, "element_blank")
  expect_match(plot$labels$caption, "\n", fixed = TRUE)
  expect_match(plot$labels$caption, "capture_status = C", fixed = TRUE)
  expect_identical(plot$guides$guides$fill$params$ncol, 1)
  expect_identical(
    plot$theme$legend.title.position,
    "top"
  )
  expect_identical(plot$theme$legend.direction, "vertical")
  facet_annotation_data <- Filter(
    function(layer_data) "facet_label" %in% names(layer_data),
    lapply(plot$layers, function(layer) layer$data)
  )
  expect_length(facet_annotation_data, 1)
  expect_setequal(
    facet_annotation_data[[1]]$facet_label,
    c("Females", "Males")
  )

  shared_mark_plot <- app$env$overview_tagged_resighting_plot(
    data.frame(
      tarsus_mark = c("BY_YB", "BY_YB"),
      right_upper = c("TY", "TG"),
      right_tarsus = c("YB", "YB"),
      sex = c("Female", "Male"),
      deployment_capture_status = c("C", "F"),
      deployment_date = as.Date(c("2026-09-02", "2026-09-03")),
      resighting_pk = c(11L, 12L),
      resighting_date = as.Date(c("2026-09-06", "2026-09-07")),
      comments = c("walking normally", "walking normally")
    ),
    date_limits = as.Date(c("2026-09-01", "2026-09-10"))
  )

  expect_setequal(
    as.character(shared_mark_plot$data$bird_id),
    c("BY_YB_F", "BY_YB_M")
  )
  expect_setequal(
    as.character(shared_mark_plot$data$sex),
    c("Female", "Male")
  )
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
    date_limits = as.Date(c("2026-08-01", "2026-08-10")),
    summary_label = "Number of females = 2\nNumber of males = 2"
  )

  expect_silent(ggplot2::ggplot_build(plot))
  expect_identical(plot$theme$legend.position, "inside")
  expect_equal(plot$theme$legend.position.inside, c(0.02, 0.76))
  expect_equal(
    plot$coordinates$limits$x,
    as.Date(c("2026-08-01", "2026-08-10"))
  )
  annotation_labels <- unlist(lapply(plot$layers, function(layer) {
    if (!is.null(layer$aes_params$label)) {
      return(as.character(layer$aes_params$label))
    }

    character()
  }))

  expect_contains(
    annotation_labels,
    "Number of females = 2\nNumber of males = 2"
  )
  annotation_layer <- plot$layers[[which(vapply(
    plot$layers,
    function(layer) !is.null(layer$aes_params$label),
    logical(1)
  ))]]
  expect_equal(annotation_layer$aes_params$vjust, 1.3)
  expect_identical(
    app$env$overview_cumulative_total(sex_counts, "Female"),
    2L
  )
})
