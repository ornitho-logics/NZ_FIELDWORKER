library(testthat)

test_that("guarded tag notes retain the existing white capture-point stroke", {
  for (package in c("data.table", "sf", "ggplot2", "ggrepel")) {
    skip_if_not_installed(package)
  }
  env <- new.env(parent = asNamespace("data.table"))
  for (name in getNamespaceExports("ggplot2")) {
    env[[name]] <- getExportedValue("ggplot2", name)
  }
  for (name in c(
    "st_as_sf", "st_transform", "st_geometry", "st_geometry<-",
    "st_crs<-", "st_sfc", "st_polygon", "st_difference", "st_union",
    "st_drop_geometry", "st_coordinates"
  )) {
    env[[name]] <- getExportedValue("sf", name)
  }
  for (file in c("display_nest_ids.R", "pdf_todo_map.R")) {
    for (expression in parse(app_file("main", "R", file))) {
      if (
        is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
          is.call(expression[[3L]]) &&
          identical(expression[[3L]][[1L]], as.name("function"))
      ) {
        eval(expression, envir = env)
      }
    }
  }
  # Entirely invented locations and IDs; no app, database or tile service.
  todo <- data.frame(
    nest_id = sprintf("B_TEST_%d", 1:5),
    todo = c(rep("Parent capture", 3), "Parent resighting", "Parent capture"),
    notes = c(
      rep("tag any, but only if one is confirmed X-X", 2),
      "resight/band M (status ?)",
      "tag any, but only if one is confirmed X-X",
      NA_character_
    ),
    lat = rep(-43, 5), lon = rep(170, 5), stringsAsFactors = FALSE
  )
  mapped <- env$.todo_pdf_map_prepare_nests(todo, data.frame(), data.frame())
  observed <- setNames(mapped$tag_capture, mapped$nest_id)
  expect_identical(
    unname(observed[todo$nest_id]), c(TRUE, TRUE, FALSE, FALSE, FALSE)
  )

  # Place the invented points in a tiny invented panel to inspect the actual
  # white-stroke layer without drawing imagery or generating a PDF.
  sf::st_geometry(mapped) <- sf::st_sfc(
    lapply(seq_len(nrow(mapped)), function(index) sf::st_point(c(10 * index, 50))),
    crs = 2193
  )
  plots <- sf::st_sf(
    plot_name = "B",
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(0, 0), c(100, 0), c(100, 100), c(0, 100), c(0, 0)
    ))), crs = 2193)
  )
  gate <- sf::st_sf(label = character(), geometry = sf::st_sfc(crs = 2193))
  specs <- list(B = list(
    extent = list(x = c(-20, 120), y = c(-20, 120), centre = c(50, 50)),
    rotation_deg = 0, local_image_rotation = FALSE,
    imagery_file = tempfile("absent_invented_tag_imagery_")
  ))
  panel <- env$.todo_pdf_map_panel("B", plots, mapped, gate, "A", specs)
  white_points <- ggplot2::ggplot_build(panel)$data[[7L]]
  expect_equal(nrow(white_points), 2L)
  expect_true(all(white_points$colour == "#ffffff"))
  expect_true(all(white_points$stroke == 0.95))
})
