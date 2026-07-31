for (app_name in names(dataentry_app_specs)) {
  local({
    name <- app_name
    spec <- dataentry_app_specs[[name]]

    test_that(paste("DataEntry app wiring:", name), {
      app <- load_dataentry_app(name)
      html <- htmltools::renderTags(app$ui)$html

      expect_identical(app$env$table_name, name)
      expect_identical(app$env$group, "nz_fieldworker")
      expect_equal(as.integer(app$env$n_empty_lines), spec$n_empty_lines)
      expect_identical(
        app$server,
        getExportedValue("DataEntry", spec$server)
      )

      expect_s3_class(app$ui, "shiny.tag.list")
      expect_match(html, 'id="table"', fixed = TRUE)
      expect_match(html, 'id="saveButton"', fixed = TRUE)
      expect_match(html, name, fixed = TRUE)

      if (spec$validation) {
        expect_match(html, 'id="ignore_checks"', fixed = TRUE)
      } else {
        expect_no_match(html, 'id="ignore_checks"', fixed = TRUE)
      }

      if (spec$kind == "append") {
        expect_type(app$env$prefilled, "list")
        expect_type(app$env$dropdowns, "list")
        expect_identical(app$env$exclude_columns, c("pk", "nov"))
      }

      if (spec$kind == "edit_rcode") {
        expect_identical(app$env$id_column, spec$id_column)
        expect_identical(app$env$code_column, spec$code_column)
        expect_identical(app$env$code_column_width, 760)
        expect_identical(app$env$code_row_height, 100)
      }
    })
  })
}


test_that("main app UI and entrypoint load", {
  app <- load_main_app()
  html <- htmltools::renderTags(app$ui)$html

  expect_s3_class(app$ui, "shiny.tag.list")
  expect_true(is.function(app$server))
  expect_identical(names(formals(app$server)), c("input", "output", "session"))
  expect_identical(app$env$group, "nz_fieldworker")
  expect_identical(app$env$preferred_timezone, "Pacific/Auckland")

  expect_match(html, "FIELDWORKER", fixed = TRUE)
  expect_match(html, 'data-value="downloads"', fixed = TRUE)
  expect_match(html, 'data-value="enter_data"', fixed = TRUE)
  expect_match(html, 'data-value="nest_map"', fixed = TRUE)
  expect_match(html, 'id="nest_map_show"', fixed = TRUE)
  expect_match(html, 'id="overview_nests_show"', fixed = TRUE)
  expect_match(html, 'id="overview_geolocator_show"', fixed = TRUE)
  expect_match(html, 'id="overview_lay_date_show"', fixed = TRUE)
  expect_match(html, 'id="overview_quota_show"', fixed = TRUE)
  expect_true(is.function(app$env$overview_nests_graph))

  for (output_id in c(
    "overview_nests_show",
    "overview_geolocator_show",
    "overview_lay_date_show",
    "overview_quota_show"
  )) {
    expect_equal(
      htmltools::tagQuery(app$ui)$
        find(glue::glue("#{output_id}"))$
        closest(".shiny-spinner-output-container")$
        length(),
      1
    )
  }

  expect_contains(app$env$dbtabs_show_views, "OVERVIEW")
  expect_setequal(
    app$env$dbtabs_show_view_sources[["OVERVIEW"]],
    c(
      "settings",
      "CAPTURES",
      "NESTS",
      "EGGS",
      "RESIGHTINGS"
    )
  )
  expect_match(html, app$env$app_test_status$text, fixed = TRUE)
  expect_match(html, app$env$app_test_status$badge, fixed = TRUE)
})


test_that("database overview view is defined", {
  views_sql <- paste(
    readLines(app_file("DATABASE", "views.SQL")),
    collapse = "\n"
  )

  expect_match(
    views_sql,
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.OVERVIEW AS",
    fixed = TRUE
  )
  expect_match(views_sql, "AS n_males_caught", fixed = TRUE)
  expect_match(views_sql, "AS n_females_caught", fixed = TRUE)
  expect_match(views_sql, "AS n_nests_found", fixed = TRUE)
  expect_match(views_sql, "AS n_distinct_resightings", fixed = TRUE)
  expect_match(views_sql, "overview.section", fixed = TRUE)
  expect_match(views_sql, "overview.metric", fixed = TRUE)
  expect_match(views_sql, "overview.n", fixed = TRUE)
})


test_that("gpxui app globals and entrypoint wiring load", {
  withr::local_options(list(shiny.maxRequestSize = 5 * 1024^2))
  app <- load_gpxui_wiring()
  html <- htmltools::renderTags(app$ui)$html

  expect_identical(app$calls$required, "gpxui")
  expect_identical(app$calls$ui, 1)
  expect_identical(app$calls$server, 1)
  expect_identical(app$env$GPS_IDS, 1:15)
  expect_identical(app$env$group, "nz_fieldworker")
  expect_identical(app$env$cnf_path, Sys.getenv("GPXUI_CNF"))
  expect_identical(getOption("shiny.maxRequestSize"), 10 * 1024^4)
  expect_match(html, 'id="gpxui-test-ui"', fixed = TRUE)

  shiny::testServer(app$server, {
    expect_identical(output$ready, "ready")
  })
})


test_that("installed gpxui package exposes the expected factories", {
  skip_if_not_installed("gpxui")

  expect_true(is.function(gpxui::gpx_ui))
  expect_named(
    formals(gpxui::gpx_ui),
    c("gps_ids", "export_tables")
  )
  expect_true(is.function(gpxui::gpx_server))
  expect_named(
    formals(gpxui::gpx_server),
    c(".cnf", "group")
  )

  server <- gpxui::gpx_server()
  expect_true(is.function(server))
  expect_identical(names(formals(server)), c("input", "output", "session"))

  shiny::testServer(server, {
    session$flushReact()

    expect_true(shiny::is.reactive(run_update))
    expect_true(shiny::is.reactive(get_feedback))
  })
})
