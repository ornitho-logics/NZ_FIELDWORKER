# Source-only checks: never source global.R, start Shiny, or open a database.
withdrawal_root <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
withdrawal_file <- function(...) file.path(withdrawal_root, ...)
withdrawal_text <- function(...) paste(readLines(withdrawal_file(...), encoding = "UTF-8"), collapse = "\n")

test_that("Overview consolidates charts while Phenology and notA reports stay absent", {
  ui <- withdrawal_text("main", "ui.R")
  server <- withdrawal_text("main", "server.R")
  expect_silent(parse(withdrawal_file("main", "ui.R")))
  expect_silent(parse(withdrawal_file("main", "server.R")))
  expect_silent(parse(withdrawal_file("main", "global.R")))
  expect_false(grepl("notA_summary", ui))
  expect_match(ui, 'tabName = "field_manual"', fixed = TRUE)
  plots <- regmatches(ui, gregexpr('overview_[a-z_]+_show', ui))[[1]]
  expect_setequal(plots, c(
    "overview_recapture_cohorts_show",
    "overview_nest_finders_show",
    "overview_quota_show", "overview_lay_date_show", "overview_hatching_forecast_show",
    "overview_nests_show", "overview_cr_combos_show", "overview_geolocator_show",
    "overview_chick_growth_show", "overview_tagged_resightings_show"
  ))
  expect_length(plots, 10L)
  expect_false(grepl("overview_recaptures_show", ui, fixed = TRUE))
  expect_false(grepl("overview_recaptures_show", server, fixed = TRUE))
  for (id in plots) {
    expect_match(server, paste0("output$", id, " <- renderPlot("), fixed = TRUE)
  }
  expect_false(grepl('tabName = "phenology"', ui, fixed = TRUE))
  expect_false(grepl('plotOutput("phenology_show"', ui, fixed = TRUE))
  expect_false(file.exists(withdrawal_file("main", "R", "phenology.R")))
  expect_match(ui, 'tabName = "overview"', fixed = TRUE)
  expect_false(grepl("phenology_server", server, fixed = TRUE))
  expect_match(server, 'dbtable_is_updated(c("CAPTURES", "NESTS"))', fixed = TRUE)
  expect_match(server, "overview_chick_growth_data_version()", fixed = TRUE)
  expect_true(file.exists(withdrawal_file("main", "R", "ggplot_overview.R")))
  expect_false(file.exists(withdrawal_file("DATABASE", "notA_summary.SQL")))
  for (tab in c("downloads", "enter_data", "show_views", "nest_map", "field_resightings")) {
    expect_match(ui, paste0('tabName = "', tab, '"'), fixed = TRUE)
  }
  expect_match(server, "field_resightings_server(input, output, active_refdate)", fixed = TRUE)
  expressions <- as.list(parse(withdrawal_file("main", "global.R")))
  env <- new.env(parent = baseenv())
  for (name in c("dbtabs_show_views", "dbtabs_show_view_sources", "dbtabs_entry")) {
    found <- Filter(function(expr) is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
                      identical(expr[[2L]], as.name(name)), expressions)
    expect_length(found, 1L)
    eval(found[[1L]], env)
  }
  expect_setequal(env$dbtabs_show_views,
    c("TODO_LIST", "AVAILABLE_COMBOS", "NESTS_LATEST", "CAPTURES_ARCHIVE", "EGGS_HATCH_PREDICTION", "OVERVIEW"))
  expect_false("notA_summary" %in% names(env$dbtabs_show_view_sources))
  expect_setequal(env$dbtabs_show_view_sources$OVERVIEW,
    c("settings", "CAPTURES", "NESTS", "EGGS", "RESIGHTINGS"))
  expect_contains(env$dbtabs_entry, c("CAPTURES", "NESTS", "EGGS", "RESIGHTINGS", "OBSERVERS"))
})

test_that("Overview and notA source archives remain intact", {
  skip_if_not_installed("jsonlite")
  overview <- jsonlite::read_json(withdrawal_file("docs", "overview-archive", "2026-11-08", "manifest.json"))
  expect_length(overview$members, 9L)
  archive <- withdrawal_file("docs", "overview-archive", "2026-11-08", overview$archive$file)
  expect_equal(unname(file.info(archive)$size), overview$archive$bytes)
  expect_identical(unname(tools::md5sum(archive)), overview$archive$md5)
  helper <- withdrawal_file(overview$helper$archived_path)
  expect_identical(unname(tools::md5sum(helper)), overview$helper$md5)
  expect_equal(unname(file.info(helper)$size), overview$helper$bytes)
  expect_identical(unname(tools::md5sum(withdrawal_file("main", "R", "ggplot_overview.R"))),
    overview$helper$md5)
  env <- new.env(parent = baseenv())
  env$DBq <- env$db_get <- function(...) stop("Database access is forbidden in archive checks")
  expect_silent(sys.source(helper, envir = env))
  for (name in c("overview_quota_graph", "overview_lay_date_graph", "overview_hatching_forecast_graph",
                 "overview_nests_graph", "overview_band_combos_graph", "overview_geolocator_graph",
                 "overview_chick_growth_graph", "overview_tagged_resightings_graph")) {
    expect_true(is.function(env[[name]]))
  }
  nota <- jsonlite::read_json(withdrawal_file("docs", "notA-summary-archive", "2026-11-08", "manifest.json"))
  expect_length(nota$members, 1L)
  member <- nota$members[[1L]]
  path <- withdrawal_file(member$archived_path)
  expect_identical(unname(tools::md5sum(path)), member$md5)
  expect_equal(unname(file.info(path)$size), member$bytes)
  expect_match(paste(readLines(path), collapse = "\n"),
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.notA_summary", fixed = TRUE)
})

test_that("reconstruction retains archive references but does not install withdrawn report", {
  skip_if_not_installed("jsonlite")
  rules <- jsonlite::read_json(withdrawal_file("docs", "reconstruction", "rules.json"))
  history <- Filter(function(rule) identical(rule$id, "HISTORY-001"), rules$rules)
  expect_length(history, 1L)
  expect_match(history[[1L]]$statement, "Archived optional report", fixed = TRUE)
  expect_true(all(vapply(history[[1L]]$sources, function(path) file.exists(withdrawal_file(path)), logical(1))))
  bootstrap <- withdrawal_text("tools", "reconstruction", "bootstrap.py")
  expect_false(grepl('install("historical_view"', bootstrap, fixed = TRUE))
  expect_false(grepl("FROM notA_summary", bootstrap, fixed = TRUE))
  expect_match(bootstrap, 'install("refresh_next_date"', fixed = TRUE)
  expect_match(withdrawal_text("DATABASE", "views.SQL"),
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.OVERVIEW AS", fixed = TRUE)
})
