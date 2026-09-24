example_plots <- function() {
  data.frame(
    variable = "study_area",
    value = paste0(
      "list(",
      "A = 'POLYGON ((172 -44, 172.01 -44, 172.01 -43.99, ",
      "172 -43.99, 172 -44))', ",
      "B = 'POLYGON ((172.02 -44, 172.03 -44, 172.03 -43.99, ",
      "172.02 -43.99, 172.02 -44))'",
      ")"
    )
  )
}


test_that(".prepare_plots converts stored WKT to sf polygons", {
  app <- load_main_app()
  prepare_plots <- get(".prepare_plots", envir = app$env)
  raw_plots <- example_plots()

  plots <- prepare_plots(raw_plots)

  expect_s3_class(plots, "sf")
  expect_identical(plots$plot_name, c("A", "B"))
  expect_identical(names(plots), c("plot_name", "geometry"))
  expect_setequal(
    as.character(sf::st_geometry_type(plots)),
    "POLYGON"
  )
  expect_equal(sf::st_crs(plots)$epsg, 4326)
})


test_that(".prepare_plots fails gracefully", {
  app <- load_main_app()
  prepare_plots <- get(".prepare_plots", envir = app$env)
  invalid <- data.frame(variable = "study_area", value = "not valid R")
  prepared <- prepare_plots(invalid)

  expect_s3_class(prepared, "sf")
  expect_equal(nrow(prepared), 0)
})


test_that("live_nest_leaflet draws subtle plots below nest markers", {
  app <- load_main_app()
  live_map <- get("live_nest_leaflet", envir = app$env)
  raw_plots <- example_plots()
  nests <- data.frame(
    nest_id = "A0101",
    nest_state = "F",
    lat = -43.995,
    lon = 172.005
  )

  map <- live_map(nests, plots = raw_plots)
  methods <- vapply(map$x$calls, `[[`, character(1), "method")
  polygon_call <- map$x$calls[[match("addPolygons", methods)]]

  expect_s3_class(map, "leaflet")
  expect_lt(match("addPolygons", methods), match("addCircleMarkers", methods))
  expect_identical(polygon_call$args[[3]], "Plots")
  expect_identical(polygon_call$args[[4]]$color, "#d70427")
  expect_false(polygon_call$args[[4]]$fill)
  expect_identical(polygon_call$args[[7]], c("A", "B"))
  expect_true(polygon_call$args[[8]]$permanent)
  expect_identical(polygon_call$args[[8]]$direction, "center")
  expect_lte(polygon_call$args[[8]]$opacity, 0.55)
  expect_identical(
    polygon_call$args[[8]]$style[["pointer-events"]],
    "none"
  )
})


test_that("live_nest_leaflet fits plot bounds when there are no nests", {
  app <- load_main_app()
  live_map <- get("live_nest_leaflet", envir = app$env)
  raw_plots <- example_plots()

  map <- live_map(data.frame(), plots = raw_plots)
  methods <- vapply(map$x$calls, `[[`, character(1), "method")

  expect_contains(methods, "addPolygons")
  expect_true(length(map$x$fitBounds) > 0)
  expect_false("addCircleMarkers" %in% methods)
})


test_that("PDF map keeps active nests without current tasks", {
  app <- load_main_app()
  prepare_nests <- get(".todo_pdf_map_prepare_nests", envir = app$env)
  todo <- data.frame(
    nest_id = "A_MOCK_TASK",
    todo = "nest check",
    reference_date = as.Date("2026-09-24"),
    lat = -44.001,
    lon = 172.001
  )
  nests_latest <- data.frame(
    nest_id = c("A_MOCK_TASK", "A_MOCK_ACTIVE", "A_MOCK_CLOSED"),
    nest_state = c("I", "F", "notA"),
    lat = c(-44.001, -44.002, -44.003),
    lon = c(172.001, 172.002, 172.003)
  )

  mapped <- prepare_nests(
    todo = todo,
    chick_captures = data.frame(),
    nests_latest = nests_latest
  )

  expect_setequal(
    mapped$nest_id,
    c("A_MOCK_TASK", "A_MOCK_ACTIVE")
  )
  expect_identical(
    as.character(mapped$parent_work[mapped$nest_id == "A_MOCK_ACTIVE"]),
    "No capture/resight"
  )
  expect_identical(
    as.character(mapped$check_type[mapped$nest_id == "A_MOCK_ACTIVE"]),
    "Other task"
  )
})
