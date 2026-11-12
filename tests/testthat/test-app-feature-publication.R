# Source-only checks: never source global.R, start Shiny, or open a database.
withdrawal_root <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
withdrawal_file <- function(...) file.path(withdrawal_root, ...)
withdrawal_text <- function(...) paste(readLines(withdrawal_file(...), encoding = "UTF-8"), collapse = "\n")

test_that("restored panels and notA coexist with newer features", {
  ui <- withdrawal_text("main", "ui.R")
  server <- withdrawal_text("main", "server.R")
  expect_silent(parse(withdrawal_file("main", "ui.R")))
  expect_silent(parse(withdrawal_file("main", "server.R")))
  expect_silent(parse(withdrawal_file("main", "global.R")))
  expect_match(ui, 'tabName = "field_manual"', fixed = TRUE)
  expect_match(ui, 'src = "field-manual/core-guide.html"', fixed = TRUE)
  expect_match(ui, 'identical(i, "notA_summary")', fixed = TRUE)
  plots <- regmatches(ui, gregexpr('overview_[a-z_]+_show', ui))[[1]]
  expect_setequal(plots, c(
    "overview_lay_date_show", "overview_lay_date_history_show", "overview_quota_show",
    "overview_hatching_forecast_show", "overview_nests_show", "overview_cr_combos_show",
    "overview_geolocator_show", "overview_chick_growth_show", "overview_tagged_resightings_show"
  ))
  expect_length(plots, 9L)
  expect_false(anyDuplicated(plots) > 0L)
  expect_match(ui, 'tabName = "overview"', fixed = TRUE)
  expect_match(server, "phenology_server(input, output, session, active_refdate)", fixed = TRUE)
  renderers <- paste(server, withdrawal_text("main", "R", "phenology.R"))
  owners <- regmatches(renderers, gregexpr('output\\$overview_[a-z_]+_show[[:space:]]*<-', renderers))[[1]]
  owners <- sub('[[:space:]]*<-$', "", sub('output\\$', "", owners))
  expect_length(owners, 9L)
  expect_false(anyDuplicated(owners) > 0L)
  expect_setequal(owners, plots)
  expect_match(server, "overview_plot_date_limits <- reactive", fixed = TRUE)
  expect_match(server, "overview_chick_growth_data_version <- reactivePoll", fixed = TRUE)
  expect_true(file.exists(withdrawal_file("main", "R", "ggplot_overview.R")))
  expect_true(file.exists(withdrawal_file("DATABASE", "notA_summary.SQL")))
  expect_false(file.exists(withdrawal_file("COPYRIGHT.md")))
  for (tab in c("downloads", "enter_data", "show_views", "nest_map", "field_resightings", "data_issues")) {
    expect_match(ui, paste0('tabName = "', tab, '"'), fixed = TRUE)
  }
  expect_match(server, "field_resightings_server(input, output, active_refdate)", fixed = TRUE)
  expect_match(server, "data_issues_server(input, output, session)", fixed = TRUE)
  expressions <- as.list(parse(withdrawal_file("main", "global.R")))
  env <- new.env(parent = baseenv())
  for (name in c("dbtabs_show_views", "dbtabs_show_view_sources", "dbtabs_entry", "dbtabs_show_tables")) {
    found <- Filter(function(expr) is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
                      identical(expr[[2L]], as.name(name)), expressions)
    expect_length(found, 1L)
    eval(found[[1L]], env)
  }
  expect_setequal(env$dbtabs_show_views,
    c("TODO_LIST", "AVAILABLE_COMBOS", "NESTS_LATEST", "CAPTURES_ARCHIVE", "EGGS_HATCH_PREDICTION", "notA_summary"))
  expect_false("OVERVIEW" %in% names(env$dbtabs_show_view_sources))
  expect_setequal(env$dbtabs_show_view_sources$notA_summary, c(
    "settings", "TODO_REFRESH_STATUS", "TODO_NEST_CONTEXT_SNAPSHOT", "TODO_PARENT_STATUS_SNAPSHOT"
  ))
  expect_contains(env$dbtabs_entry, c("CAPTURES", "NESTS", "EGGS", "RESIGHTINGS", "OBSERVERS"))
  expect_contains(env$dbtabs_show_tables, "RESIGHTINGS_field")
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
  expect_identical(unname(tools::md5sum(withdrawal_file(member$original_path))), member$md5)
  expect_match(paste(readLines(path), collapse = "\n"),
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.notA_summary", fixed = TRUE)
})

test_that("reconstruction retains archives and installs restored report after snapshot publication", {
  skip_if_not_installed("jsonlite")
  rules <- jsonlite::read_json(withdrawal_file("docs", "reconstruction", "rules.json"))
  history <- Filter(function(rule) identical(rule$id, "HISTORY-001"), rules$rules)
  expect_length(history, 1L)
  expect_match(history[[1L]]$statement, "Restored optional report", fixed = TRUE)
  expect_true(all(vapply(history[[1L]]$sources, function(path) file.exists(withdrawal_file(path)), logical(1))))
  bootstrap <- withdrawal_text("tools", "reconstruction", "bootstrap.py")
  expect_match(bootstrap, 'install("historical_view"', fixed = TRUE)
  expect_match(bootstrap, "FROM notA_summary", fixed = TRUE)
  expect_match(bootstrap, 'install("refresh_next_date"', fixed = TRUE)
  expect_match(withdrawal_text("DATABASE", "views.SQL"),
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.OVERVIEW AS", fixed = TRUE)
})

test_that("all nine chart renderers retain reference-date updates without real queries", {
  for (package in c("shiny", "ggplot2")) skip_if_not_installed(package)
  env <- new.env(parent = asNamespace("shiny"))
  env$DBq <- env$db_get <- function(...) stop("Database access forbidden in publication tests")
  env$dbtable_is_updated <- function(...) "invented-unchanged"
  env$fallback_ggplot <- function(...) stop("Unexpected chart fallback")
  env$try_else <- function(expr, ...) force(expr)
  env$overview_date_limits <- function(date) c(date - 30, date)
  env$calls <- new.env(parent = emptyenv())
  env$calls$dates <- list()
  graphs <- c("overview_nests_graph", "overview_geolocator_graph",
              "overview_tagged_resightings_graph", "overview_band_combos_graph",
              "overview_lay_date_graph", "overview_hatching_forecast_graph",
              "overview_chick_growth_graph", "overview_quota_graph")
  for (name in graphs) local({
    key <- name
    env[[key]] <- function(date, ...) {
      env$calls$dates[[key]] <- date
      ggplot2::ggplot()
    }
  })
  sys.source(withdrawal_file("main", "R", "phenology.R"), envir = env)
  env$phenology_data <- function(date) {
    env$calls$dates[["phenology"]] <- date
    data.frame()
  }
  env$geo_data <- function(date) data.frame()
  env$phenology_plot <- function(dat, ...) {
    force(dat)
    ggplot2::ggplot()
  }
  server <- parse(withdrawal_file("main", "server.R"))[[1L]]
  statements <- as.list(server[[3L]])[-1L]
  selected <- Filter(function(expr) {
    if (!is.call(expr) || !identical(expr[[1L]], as.name("<-"))) return(FALSE)
    lhs <- paste(deparse(expr[[2L]]), collapse = "")
    grepl("^overview_(plot_date_limits|chick_growth_data_version)$", lhs) ||
      grepl("^output\\$overview_", lhs)
  }, statements)
  expect_length(selected, 10L)
  env$chart_statements <- selected
  wrapper <- function(input, output, session) {
    active_refdate <- shiny::reactiveVal(as.Date("2031-11-12"))
    phenology_server(input, output, session, active_refdate)
    for (expr in chart_statements) eval(expr, envir = environment())
  }
  environment(wrapper) <- env
  outputs <- c("overview_lay_date_show", "overview_lay_date_history_show",
               "overview_quota_show", "overview_hatching_forecast_show", "overview_nests_show",
               "overview_cr_combos_show", "overview_geolocator_show", "overview_chick_growth_show",
               "overview_tagged_resightings_show")
  shiny::testServer(wrapper, {
    session$setInputs(main = "intro")
    for (id in outputs) expect_error(output[[id]], class = "shiny.silent.error")
    expect_length(env$calls$dates, 0L)
    session$setInputs(main = "overview")
    for (id in outputs) expect_true(is.list(output[[id]]))
    expect_setequal(names(env$calls$dates), c(graphs, "phenology"))
    expect_true(all(vapply(env$calls$dates, identical, logical(1), as.Date("2031-11-12"))))
    active_refdate(as.Date("2031-11-13"))
    session$flushReact()
    for (id in outputs) expect_true(is.list(output[[id]]))
    expect_true(all(vapply(env$calls$dates, identical, logical(1), as.Date("2031-11-13"))))
  })
})

test_that("restored dashboard markup renders without global config, records, or a server", {
  for (package in c("shiny", "bs4Dash", "shinyWidgets", "waiter", "fresh",
                    "DT", "glue", "htmltools")) {
    skip_if_not_installed(package)
    suppressPackageStartupMessages(library(package, character.only = TRUE))
  }
  env <- new.env(parent = globalenv())
  env$DBq <- env$db_get <- env$db_con <- function(...) stop("Database access forbidden")
  env$read.csv <- function(...) data.frame(failed = 0L, passed = 0L)
  env$spinner <- identity
  env$leafletOutput <- function(outputId, ...) shiny::tags$div(id = outputId)
  env$preferred_timezone <- "Pacific/Auckland"
  globals <- as.list(parse(withdrawal_file("main", "global.R")))
  for (name in c("dbtabs_show_tables", "dbtabs_show_views")) {
    item <- Filter(function(expr) is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
                     identical(expr[[2L]], as.name(name)), globals)
    expect_length(item, 1L)
    eval(item[[1L]], env)
  }
  helpers <- as.list(parse(withdrawal_file("main", "R", "system_utils_app.R")))
  theme <- Filter(function(expr) is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
                    identical(expr[[2L]], as.name("fieldworker_theme")), helpers)
  expect_length(theme, 1L)
  eval(theme[[1L]], env)
  withr::local_dir(withdrawal_file("main"))
  ui <- eval(parse("ui.R"), env)
  html <- htmltools::renderTags(ui)$html
  expect_match(html, 'data-value="data_issues"', fixed = TRUE)
  expect_match(html, 'data-value="field_manual"', fixed = TRUE)
  expect_match(html, 'src="field-manual/core-guide.html"', fixed = TRUE)
  expect_match(html, 'href="field-manual/core-guide.html"', fixed = TRUE)
  expect_match(html, "notA_summary", fixed = TRUE)
  plots <- regmatches(html, gregexpr('id="overview_[a-z_]+_show"', html))[[1L]]
  expect_length(plots, 9L)
  expect_false(anyDuplicated(plots) > 0L)
})
