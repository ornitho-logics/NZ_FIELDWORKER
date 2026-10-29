library(testthat)

test_that("empty and populated map panels retain usable coordinate columns", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ggrepel")
  env <- new.env(parent = globalenv())
  for (name in getNamespaceExports("ggplot2")) {
    env[[name]] <- getExportedValue("ggplot2", name)
  }
  for (name in c(
    "st_geometry", "st_geometry<-", "st_crs<-", "st_sfc", "st_polygon", "st_difference",
    "st_union", "st_drop_geometry", "st_coordinates"
  )) {
    env[[name]] <- getExportedValue("sf", name)
  }
  for (expression in parse(app_file("main", "R", "pdf_todo_map.R"))) {
    if (
      is.call(expression)
        && identical(expression[[1L]], as.name("<-"))
        && is.call(expression[[3L]])
        && identical(expression[[3L]][[1L]], as.name("function"))
    ) {
      eval(expression, envir = env)
    }
  }
  plots <- sf::st_sf(
    plot_name = "A",
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(0, 0), c(100, 0), c(100, 100), c(0, 100), c(0, 0)
    ))), crs = 2193)
  )
  nests <- sf::st_as_sf(data.table::data.table(
    plot_name = "A", nest_id = "A9901", x = 50, y = 50,
    parent_work = "Capture", tag_capture = TRUE, check_type = "Nest check",
    label_outline = "white", label_outline_width = 0.2,
    label_fontface = "plain", label_fill = "black", label_text = "white"
  ), coords = c("x", "y"), crs = 2193)
  gate <- sf::st_sf(label = character(), geometry = sf::st_sfc(crs = 2193))
  spec <- list(A = list(
    extent = list(x = c(-20, 120), y = c(-20, 120), centre = c(50, 50)),
    rotation_deg = 0, local_image_rotation = FALSE,
    imagery_file = tempfile("absent_invented_imagery_")
  ))
  for (populated in c(FALSE, TRUE)) {
    points <- if (populated) nests else nests[0, ]
    panel <- env$.todo_pdf_map_panel("A", plots, points, gate, "B", spec)
    built <- ggplot2::ggplot_build(panel)
    expect_equal(nrow(built$data[[6L]]), as.integer(populated))
    expect_equal(nrow(built$data[[7L]]), as.integer(populated))
  }
})
