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
  withr::local_envvar(FIELDWORKER_GIT_ID = "ABCDEF1234567890")
  app <- load_main_app()
  html <- htmltools::renderTags(app$ui)$html

  expect_s3_class(app$ui, "shiny.tag.list")
  expect_true(is.function(app$server))
  expect_identical(names(formals(app$server)), c("input", "output", "session"))
  expect_identical(app$env$group, "nz_fieldworker")
  expect_identical(app$env$preferred_timezone, "Pacific/Auckland")
  expect_identical(app$env$git_id, "abcdef1")
  expect_identical(
    app$env$git_version$source,
    "env:FIELDWORKER_GIT_ID"
  )
  expect_identical(
    app$env$parse_git_ls_remote(
      "ABCDEF1234567890ABCDEF1234567890ABCDEF12\trefs/heads/main"
    ),
    "abcdef1"
  )
  expect_null(app$env$parse_git_ls_remote(character()))

  expect_identical(
    app$env$git_local_head_id(app_file("main")),
    app$env$normalize_git_id(
      app$env$git_output(
        app_file("main"),
        c("rev-parse", "--short=7", "HEAD")
      )
    )
  )

  expect_match(html, "FIELDWORKER", fixed = TRUE)
  expect_match(html, "abcdef1", fixed = TRUE)
  expect_match(
    html,
    paste0(
      "https://github.com/ornitho-logics/NZ_FIELDWORKER/commit/",
      "abcdef1"
    ),
    fixed = TRUE
  )
  expect_match(html, 'data-value="downloads"', fixed = TRUE)
  expect_match(html, 'data-value="enter_data"', fixed = TRUE)
  expect_match(html, 'data-value="nest_map"', fixed = TRUE)
  expect_match(html, 'id="nest_map_show"', fixed = TRUE)
  expect_match(html, 'id="overview_nests_show"', fixed = TRUE)
  expect_match(html, 'id="overview_geolocator_show"', fixed = TRUE)
  expect_match(html, 'id="overview_tagged_resightings_show"', fixed = TRUE)
  expect_match(
    html,
    paste0(
      'id="overview_tagged_resightings_show" ',
      'style="width:100%;height:105vh;"'
    ),
    fixed = TRUE
  )
  expect_match(html, 'id="overview_cr_combos_show"', fixed = TRUE)
  expect_match(html, 'id="overview_lay_date_show"', fixed = TRUE)
  expect_match(html, 'id="overview_hatching_forecast_show"', fixed = TRUE)
  expect_match(html, 'id="overview_quota_show"', fixed = TRUE)
  expect_true(is.function(app$env$overview_nests_graph))
  expect_true(is.function(app$env$overview_tagged_resightings_graph))
  expect_true(is.function(app$env$overview_hatching_forecast_graph))
  expect_true(is.function(app$env$overview_limp_status))

  for (output_id in c(
    "overview_nests_show",
    "overview_geolocator_show",
    "overview_tagged_resightings_show",
    "overview_cr_combos_show",
    "overview_lay_date_show",
    "overview_hatching_forecast_show",
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
  expect_identical(
    sum(app$env$dbtabs_show_views == "VIEW_1"),
    1L
  )
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
  expect_identical(
    app$env$dbtabs_show_view_sources[["VIEW_1"]],
    c("settings", "CAPTURES", "RESIGHTINGS")
  )
  expect_true("RESIGHTINGS" %in% app$env$dbtabs_show_view_sources[["NESTS_LATEST"]])
  expect_identical(
    app$env$dbtabs_show_view_sources[["BROODS_LATEST"]],
    app$env$dbtabs_show_view_sources[["LIVE_NEST_MAP"]]
  )
  expect_match(html, "State / brood:", fixed = TRUE)
  expect_match(html, "Brood", fixed = TRUE)
  expect_no_match(html, "Hatched", fixed = TRUE)
  expect_match(html, app$env$app_test_status$text, fixed = TRUE)
  expect_match(html, app$env$app_test_status$badge, fixed = TRUE)
})


test_that("git version falls back to local HEAD when remote lookup is unavailable", {
  withr::local_envvar(FIELDWORKER_GIT_ID = "ABCDEF1234567890")
  app <- load_main_app()

  withr::local_envvar(c(
    FIELDWORKER_GIT_ID = NA,
    GITHUB_SHA = NA,
    SOURCE_VERSION = NA,
    RENDER_GIT_COMMIT = NA
  ))
  app$env$git_ref_matches_app <- function(...) FALSE
  app$env$git_remote_main_id <- function(...) NULL

  expected_id <- app$env$git_local_head_id(app_file("main"))
  observed <- app$env$resolve_git_version(app_file("main"))

  expect_identical(observed$id, expected_id)
  expect_identical(observed$source, "git:HEAD-working-tree")
  expect_identical(
    observed$commit_time,
    app$env$git_commit_time(app_file("main"), "HEAD")
  )
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
