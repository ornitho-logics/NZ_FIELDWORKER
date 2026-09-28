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


test_that("live map preparation reconciles nests, broods, and failed closures", {
  app <- load_main_app()
  prepare_map_data <- get(".prepare_live_nest_map_data", envir = app$env)
  live_map <- get("live_nest_leaflet", envir = app$env)

  nests_latest <- data.frame(
    nest_id = c(
      "A_ACTIVE",
      "A_HATCHED",
      "A_HATCHED_NOTA",
      "A_FAILED_NOTA",
      "A_FALLBACK"
    ),
    nest_state = c("I", "H", "notA", "notA", "H"),
    has_hatch_evidence = c(FALSE, TRUE, TRUE, FALSE, TRUE),
    lat = c(-44.001, -44.002, -44.003, -44.004, -44.005),
    lon = c(172.001, 172.002, 172.003, 172.004, 172.005),
    stringsAsFactors = FALSE
  )
  broods_latest <- data.frame(
    nest_id = c(
      "A_HATCHED",
      "A_HATCHED_NOTA",
      "A_FALLBACK",
      "-B_MOBILE",
      "-C_NO_COORDS"
    ),
    is_negative_brood = c(FALSE, FALSE, FALSE, TRUE, TRUE),
    has_hatch_evidence = c(TRUE, TRUE, TRUE, TRUE, TRUE),
    nest_state = c("H", "notA", "H", NA, NA),
    lat = c(-44.102, -44.103, NA, -44.104, NA),
    lon = c(172.102, 172.103, NA, 172.104, NA),
    latest_chick_event_date = as.Date(c(
      "2026-09-01",
      "2026-09-02",
      "2026-09-03",
      "2026-09-04",
      "2026-09-04"
    )),
    stringsAsFactors = FALSE
  )

  mapped <- prepare_map_data(nests_latest, broods_latest)

  expect_length(unique(mapped$nest_id), 7)
  expect_identical(
    as.character(mapped$map_category[mapped$nest_id == "A_ACTIVE"]),
    "I"
  )
  expect_setequal(
    mapped$nest_id[mapped$map_category == "brood"],
    c("A_HATCHED", "A_HATCHED_NOTA", "A_FALLBACK", "-B_MOBILE", "-C_NO_COORDS")
  )
  expect_identical(
    as.character(mapped$map_category[mapped$nest_id == "A_FAILED_NOTA"]),
    "notA"
  )
  expect_identical(
    mapped$nest_id[mapped$nest_id == "-B_MOBILE"],
    "-B_MOBILE"
  )
  expect_equal(
    mapped[ nest_id == "A_HATCHED_NOTA", .(lat, lon)],
    data.table(lat = -44.103, lon = 172.103)
  )
  expect_equal(
    mapped[ nest_id == "A_FALLBACK", .(lat, lon)],
    data.table(lat = -44.005, lon = 172.005)
  )

  brood_only <- mapped[map_category == "brood"]
  not_a_only <- mapped[map_category == "notA"]
  expect_false("A_FAILED_NOTA" %in% brood_only$nest_id)
  expect_false(any(not_a_only$map_category == "brood"))

  map <- live_map(
    mapped,
    plots = data.frame(),
    map_data_prepared = TRUE
  )
  methods <- vapply(map$x$calls, `[[`, character(1), "method")
  marker_call <- map$x$calls[[match("addCircleMarkers", methods)]]
  legend_call <- map$x$calls[[match("addControl", methods)]]
  legend_text <- as.character(legend_call$args[[1]])

  expect_length(marker_call$args[[1]], 6)
  expect_false("-C_NO_COORDS" %in% marker_call$args[[11]])
  expect_match(legend_text, "brood", fixed = TRUE)
  expect_match(legend_text, "#1aa9fc", fixed = TRUE)
  expect_no_match(legend_text, ">H<", fixed = TRUE)

  warning_map <- live_map(
    mapped,
    plots = data.frame(),
    map_data_prepared = TRUE,
    broods_warning = "Some mobile brood markers were omitted."
  )
  warning_methods <- vapply(
    warning_map$x$calls,
    `[[`,
    character(1),
    "method"
  )
  warning_calls <- warning_map$x$calls[warning_methods == "addControl"]
  expect_true(any(vapply(
    warning_calls,
    function(call) grepl("omitted", as.character(call$args[[1]]), fixed = TRUE),
    logical(1)
  )))
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
    nest_id = c(
      "A_MOCK_TASK",
      "A_MOCK_ACTIVE",
      "A_MOCK_HATCHED_NOTA",
      "A_MOCK_FAILED_NOTA",
      "-B_MOCK_MOBILE"
    ),
    nest_state = c("I", "F", "notA", "notA", NA),
    has_hatch_evidence = c(FALSE, FALSE, TRUE, FALSE, TRUE),
    is_negative_brood = c(FALSE, FALSE, FALSE, FALSE, TRUE),
    lat = c(-44.001, -44.002, -44.003, -44.004, -44.005),
    lon = c(172.001, 172.002, 172.003, 172.004, 172.005)
  )

  mapped <- prepare_nests(
    todo = todo,
    chick_captures = data.frame(),
    nests_latest = nests_latest
  )

  expect_setequal(
    mapped$nest_id,
    c("A_MOCK_TASK", "A_MOCK_ACTIVE", "A_MOCK_HATCHED_NOTA", "-B_MOCK_MOBILE")
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
