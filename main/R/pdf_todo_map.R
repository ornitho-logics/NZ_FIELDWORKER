.todo_pdf_map_rotation_matrix <- function(angle_deg) {
  angle <- angle_deg * pi / 180
  matrix(
    c(cos(angle), sin(angle), -sin(angle), cos(angle)),
    nrow = 2,
    byrow = TRUE
  )
}

.todo_pdf_map_prepare_plots <- function(spatial_objects) {
  objects <- data.table(spatial_objects)

  if ("variable" %in% names(objects)) {
    objects <- objects[variable == "study_area"]
  }

  if (!nrow(objects) || !"value" %in% names(objects)) {
    stop("The study-area polygons are missing from spatial_objects.")
  }

  plot_wkt <- eval(parse(text = objects$value[[1]]))
  plots <- st_sf(
    plot_name = names(plot_wkt),
    geometry = st_as_sfc(unlist(plot_wkt), crs = 4326)
  ) |>
    st_transform(2193) |>
    st_make_valid()

  plots <- plots[plots$plot_name %in% c("A", "B", "C"), ]
  if (!all(c("A", "B", "C") %in% plots$plot_name)) {
    stop("Plot polygons A, B, and C are required for the to-do map.")
  }

  plots
}

.todo_pdf_map_prepare_nests <- function(todo) {
  todo <- data.table(todo)
  check_todos <- c("Clutch check", "Unprocessed nest", "nest check")

  nest_tasks <- todo[,
    .(
      lat = {
        value <- lat[!is.na(lat)]
        if (length(value)) as.numeric(value[1]) else NA_real_
      },
      lon = {
        value <- lon[!is.na(lon)]
        if (length(value)) as.numeric(value[1]) else NA_real_
      },
      check_type = if (any(todo %chin% check_todos)) {
        "Nest check"
      } else {
        "Other task"
      },
      parent_work = fcase(
        any(todo == "Parent capture"), "Capture",
        any(todo == "Parent resighting"), "Resight",
        default = "No capture/resight"
      )
    ),
    by = nest_id
  ]

  nest_tasks <- nest_tasks[!is.na(lat) & !is.na(lon)]
  nest_tasks[, plot_name := substr(nest_id, 1L, 1L)]
  nest_tasks <- nest_tasks[plot_name %chin% c("A", "B", "C")]
  nest_tasks[, check_type := factor(
    check_type,
    levels = c("Nest check", "Other task")
  )]
  nest_tasks[, parent_work := factor(
    parent_work,
    levels = c("Capture", "Resight", "No capture/resight")
  )]

  st_as_sf(nest_tasks, coords = c("lon", "lat"), crs = 4326) |>
    st_transform(2193)
}

.todo_pdf_map_panel_extent <- function(
  boundary,
  points,
  target_ratio,
  landmark = NULL,
  rotation_deg = 0,
  min_x = 180,
  min_y = 180
) {
  geometry <- c(st_geometry(boundary), st_geometry(points))
  if (!is.null(landmark) && nrow(landmark)) {
    geometry <- c(geometry, st_geometry(landmark))
  }

  raw_bounds <- st_bbox(geometry)
  centre <- c(
    mean(raw_bounds[c("xmin", "xmax")]),
    mean(raw_bounds[c("ymin", "ymax")])
  )

  if (rotation_deg != 0) {
    rotation <- .todo_pdf_map_rotation_matrix(rotation_deg)
    geometry <- (geometry - centre) * rotation
    rotated_bounds <- st_bbox(geometry)
    rotated_offset <- c(
      mean(rotated_bounds[c("xmin", "xmax")]),
      mean(rotated_bounds[c("ymin", "ymax")])
    )
    centre <- centre + as.numeric(rotated_offset %*% t(rotation))
    geometry <- geometry - rotated_offset
  }

  bounds <- st_bbox(geometry)
  x_span <- max(bounds[["xmax"]] - bounds[["xmin"]], min_x)
  y_span <- max(bounds[["ymax"]] - bounds[["ymin"]], min_y)

  if (x_span / y_span < target_ratio) {
    x_span <- y_span * target_ratio
  } else {
    y_span <- x_span / target_ratio
  }

  x_span <- x_span * 1.08
  y_span <- y_span * 1.08

  list(
    x = centre[1] + c(-0.5, 0.5) * x_span,
    y = centre[2] + c(-0.5, 0.5) * y_span,
    centre = centre
  )
}

.todo_pdf_map_imagery_url <- function(spec) {
  bbox <- c(spec$extent$x[1], spec$extent$y[1], spec$extent$x[2], spec$extent$y[2])
  params <- c(
    bbox = paste(bbox, collapse = ","),
    bboxSR = "2193",
    imageSR = "2193",
    size = spec$image_size,
    format = "png32",
    transparent = "false",
    rotation = as.character(spec$server_rotation),
    f = "image"
  )
  query <- paste(
    paste0(names(params), "=", vapply(params, utils::URLencode, "", reserved = TRUE)),
    collapse = "&"
  )

  paste0(
    "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?",
    query
  )
}

.todo_pdf_map_transform_sf <- function(x, centre, rotation_deg) {
  out <- x
  geometry <- st_geometry(out) - centre
  if (rotation_deg != 0) {
    geometry <- geometry * .todo_pdf_map_rotation_matrix(rotation_deg)
  }
  st_geometry(out) <- geometry
  st_crs(out) <- 2193
  out
}

.todo_pdf_map_rotate_image <- function(image) {
  if (length(dim(image)) == 2L) {
    return(t(image[nrow(image):1, , drop = FALSE]))
  }
  aperm(image[dim(image)[1]:1, , , drop = FALSE], c(2, 1, 3))
}

.todo_pdf_map_read_imagery <- function(spec) {
  if (!file.exists(spec$imagery_file)) {
    return(NULL)
  }

  image <- png::readPNG(spec$imagery_file)
  if (length(dim(image)) == 2L) {
    image <- array(rep(image, 3L), dim = c(dim(image), 3L))
  }
  if (dim(image)[3] == 3L) {
    rgba <- array(1, dim = c(dim(image)[1], dim(image)[2], 4L))
    rgba[, , 1:3] <- image
    image <- rgba
  }

  image[, , 4] <- image[, , 4] * 0.58
  if (spec$local_image_rotation) {
    image <- .todo_pdf_map_rotate_image(image)
  }

  as.raster(image)
}

.todo_pdf_map_scale_length <- function(panel_width) {
  candidates <- c(10, 20, 25, 50, 100, 200, 250, 500, 1000)
  max(candidates[candidates <= panel_width * 0.24])
}

.todo_pdf_map_panel <- function(plot_id, plots, nests, gate, gate_plot, panel_specs) {
  spec <- panel_specs[[plot_id]]
  points <- .todo_pdf_map_transform_sf(
    nests[nests$plot_name == plot_id, ],
    centre = spec$extent$centre,
    rotation_deg = spec$rotation_deg
  )
  boundary <- .todo_pdf_map_transform_sf(
    plots[plots$plot_name == plot_id, ],
    centre = spec$extent$centre,
    rotation_deg = spec$rotation_deg
  )
  panel_gate <- if (gate_plot == plot_id) {
    .todo_pdf_map_transform_sf(
      gate,
      centre = spec$extent$centre,
      rotation_deg = spec$rotation_deg
    )
  } else {
    gate[0, ]
  }

  if (spec$local_image_rotation) {
    xlim <- spec$extent$y - spec$extent$centre[2]
    ylim <- rev(-(spec$extent$x - spec$extent$centre[1]))
  } else {
    xlim <- spec$extent$x - spec$extent$centre[1]
    ylim <- spec$extent$y - spec$extent$centre[2]
  }

  panel_rect <- st_sfc(
    st_polygon(list(rbind(
      c(xlim[1], ylim[1]),
      c(xlim[2], ylim[1]),
      c(xlim[2], ylim[2]),
      c(xlim[1], ylim[2]),
      c(xlim[1], ylim[1])
    ))),
    crs = 2193
  )
  outside_mask <- suppressWarnings(st_difference(panel_rect, st_union(boundary)))
  point_xy <- cbind(st_drop_geometry(points), st_coordinates(points))
  gate_xy <- if (nrow(panel_gate)) {
    cbind(st_drop_geometry(panel_gate), st_coordinates(panel_gate))
  } else {
    data.frame(label = character(), X = numeric(), Y = numeric())
  }

  x_span <- diff(xlim)
  y_span <- diff(ylim)
  scale_length <- .todo_pdf_map_scale_length(x_span)
  scale_x <- xlim[2] - 0.07 * x_span - scale_length
  scale_y <- ylim[1] + 0.055 * y_span

  angle <- spec$rotation_deg * pi / 180
  north_vector <- c(-sin(angle), cos(angle))
  north_length <- 0.25 * x_span
  north_end <- c(xlim[2] - 0.07 * x_span, ylim[1] + 0.20 * y_span)
  north_start <- north_end - north_vector * north_length
  north_label <- north_end + north_vector * (0.035 * x_span)
  north <- data.frame(
    x = north_start[1],
    y = north_start[2],
    xend = north_end[1],
    yend = north_end[2],
    label_x = north_label[1],
    label_y = north_label[2]
  )

  task_cols <- c(
    Capture = "#d32f2f",
    Resight = "#1976d2",
    `No capture/resight` = "#7b858b"
  )
  task_shapes <- c(`Nest check` = 24, `Other task` = 21)

  panel <- ggplot()
  imagery <- .todo_pdf_map_read_imagery(spec)
  if (!is.null(imagery)) {
    panel <- panel + annotation_raster(
      imagery,
      xmin = xlim[1], xmax = xlim[2],
      ymin = ylim[1], ymax = ylim[2]
    )
  }

  panel +
    geom_sf(data = outside_mask, fill = "white", colour = NA, alpha = 0.52) +
    geom_sf(data = boundary, fill = NA, colour = "white", linewidth = 1.15, alpha = 0.9) +
    geom_sf(data = boundary, fill = NA, colour = "#604d36", linewidth = 0.45) +
    geom_point(
      data = gate_xy,
      aes(X, Y),
      shape = 23,
      size = 3.2,
      stroke = 0.75,
      fill = "#f2c94c",
      colour = "#17242d"
    ) +
    ggrepel::geom_label_repel(
      data = gate_xy,
      aes(X, Y, label = label),
      seed = 20260916,
      size = 2.75,
      fontface = "bold",
      colour = "#17242d",
      fill = scales::alpha("#fff7cf", 0.92),
      label.size = 0.15,
      label.padding = grid::unit(0.1, "lines"),
      box.padding = 0.38,
      point.padding = 0.28,
      min.segment.length = 0,
      segment.colour = "#3d4a51",
      segment.size = 0.3,
      max.overlaps = Inf,
      xlim = xlim + c(0.025, -0.025) * x_span,
      ylim = ylim + c(0.025, -0.025) * y_span
    ) +
    geom_point(
      data = point_xy,
      aes(X, Y, fill = parent_work, shape = check_type),
      size = 3.45,
      stroke = 0.75,
      colour = "#17242d"
    ) +
    ggrepel::geom_label_repel(
      data = point_xy,
      aes(X, Y, label = nest_id),
      seed = 20260916,
      size = 2.75,
      fontface = "bold",
      colour = "#17242d",
      fill = scales::alpha("white", 0.88),
      label.size = 0.15,
      label.padding = grid::unit(0.1, "lines"),
      box.padding = 0.38,
      point.padding = 0.28,
      min.segment.length = 0,
      segment.colour = "#3d4a51",
      segment.size = 0.3,
      max.overlaps = Inf,
      max.time = 4,
      xlim = xlim + c(0.025, -0.025) * x_span,
      ylim = ylim + c(0.025, -0.025) * y_span
    ) +
    annotate(
      "label",
      x = xlim[1] + 0.045 * x_span,
      y = ylim[2] - 0.035 * y_span,
      label = paste("Plot", plot_id),
      hjust = 0,
      vjust = 1,
      size = 3.6,
      fontface = "bold",
      colour = "#17242d",
      fill = scales::alpha("white", 0.82),
      linewidth = 0
    ) +
    geom_segment(
      data = north,
      aes(x, y, xend = xend, yend = yend),
      inherit.aes = FALSE,
      linewidth = 0.55,
      colour = "#17242d",
      arrow = ggplot2::arrow(type = "closed", length = grid::unit(1.8, "mm"))
    ) +
    geom_text(
      data = north,
      aes(label_x, label_y, label = "N"),
      inherit.aes = FALSE,
      size = 3,
      fontface = "bold",
      colour = "#17242d"
    ) +
    annotate(
      "segment",
      x = scale_x,
      xend = scale_x + scale_length,
      y = scale_y,
      yend = scale_y,
      linewidth = 0.65,
      colour = "#17242d"
    ) +
    annotate(
      "segment",
      x = c(scale_x, scale_x + scale_length),
      xend = c(scale_x, scale_x + scale_length),
      y = scale_y - 0.008 * y_span,
      yend = scale_y + 0.008 * y_span,
      linewidth = 0.65,
      colour = "#17242d"
    ) +
    annotate(
      "text",
      x = scale_x + scale_length / 2,
      y = scale_y + 0.019 * y_span,
      label = paste(scale_length, "m"),
      size = 2.6,
      fontface = "bold",
      colour = "#17242d"
    ) +
    scale_fill_manual(
      values = task_cols,
      limits = names(task_cols),
      drop = FALSE,
      name = "Parent work"
    ) +
    scale_shape_manual(
      values = task_shapes,
      limits = names(task_shapes),
      labels = c("Nest check", "other task (i.e., Parent work)"),
      drop = FALSE,
      name = "Nest work"
    ) +
    coord_sf(xlim = xlim, ylim = ylim, expand = FALSE, datum = NA) +
    theme_void() +
    theme(
      panel.background = element_rect(fill = "#edf0f1", colour = "#7f8b90", linewidth = 0.5),
      plot.background = element_rect(fill = "white", colour = NA),
      plot.margin = margin(1.5, 1.5, 1.5, 1.5, unit = "mm"),
      legend.position = "none"
    )
}

.todo_pdf_map_legend <- function() {
  task_cols <- c(
    Capture = "#d32f2f",
    Resight = "#1976d2",
    `No capture/resight` = "#7b858b"
  )
  task_shapes <- c(`Nest check` = 24, `Other task` = 21)

  ggplot(
    data.frame(
      parent_work = factor(names(task_cols), levels = names(task_cols)),
      check_type = factor(
        c("Nest check", "Other task", "Other task"),
        levels = names(task_shapes)
      )
    ),
    aes(0, 0)
  ) +
    geom_point(aes(fill = parent_work), shape = 21, size = 3.2, alpha = 0) +
    geom_point(aes(shape = check_type), fill = "#7b858b", size = 3.2, alpha = 0) +
    scale_fill_manual(values = task_cols, drop = FALSE, name = "Parent work") +
    scale_shape_manual(
      values = task_shapes,
      labels = c("Nest check", "other task (i.e., Parent work)"),
      drop = FALSE,
      name = "Nest work"
    ) +
    guides(
      fill = guide_legend(
        order = 1,
        nrow = 1,
        override.aes = list(alpha = 1, shape = 21, size = 3.2)
      ),
      shape = guide_legend(
        order = 2,
        nrow = 1,
        override.aes = list(alpha = 1, fill = "#7b858b", size = 3.2)
      )
    ) +
    theme_void() +
    theme(
      legend.position = "top",
      legend.box = "vertical",
      legend.box.just = "left",
      legend.title = element_text(face = "bold", size = 8.5),
      legend.text = element_text(size = 8.2),
      legend.spacing.x = grid::unit(2, "mm"),
      legend.spacing.y = grid::unit(0.5, "mm"),
      legend.margin = margin(0, 0, 0, 0),
      legend.key.width = grid::unit(5, "mm"),
      plot.margin = margin(0, 0, 0, 0)
    )
}

todo_pdf_map_save <- function(
  file,
  todo = DBq("SELECT * FROM TODO_LIST"),
  spatial_objects = DBq("SELECT * FROM spatial_objects WHERE variable = 'study_area'")
) {
  plots <- .todo_pdf_map_prepare_plots(spatial_objects)
  nests <- .todo_pdf_map_prepare_nests(todo)

  gate <- st_as_sf(
    data.frame(label = "gate", lon = 170.480287, lat = -43.879213),
    coords = c("lon", "lat"),
    crs = 4326
  ) |>
    st_transform(2193)
  gate_plot <- plots$plot_name[st_nearest_feature(gate, plots)]

  panel_specs <- list(
    A = list(
      rotation_deg = -90,
      local_image_rotation = TRUE,
      server_rotation = 0,
      target_ratio = 2.55,
      image_size = "1275,500"
    ),
    B = list(
      rotation_deg = -90,
      local_image_rotation = TRUE,
      server_rotation = 0,
      target_ratio = 2.55,
      image_size = "1275,500"
    ),
    C = list(
      rotation_deg = -17.5,
      local_image_rotation = FALSE,
      server_rotation = -17.5,
      target_ratio = 1 / 2.55,
      image_size = "500,1275"
    )
  )

  imagery_dir <- tempfile("todo_map_imagery_")
  dir.create(imagery_dir)
  on.exit(unlink(imagery_dir, recursive = TRUE), add = TRUE)

  for (plot_id in names(panel_specs)) {
    panel_specs[[plot_id]]$extent <- .todo_pdf_map_panel_extent(
      plots[plots$plot_name == plot_id, ],
      nests[nests$plot_name == plot_id, ],
      target_ratio = panel_specs[[plot_id]]$target_ratio,
      landmark = if (gate_plot == plot_id) gate else NULL,
      rotation_deg = if (plot_id == "C") panel_specs[[plot_id]]$rotation_deg else 0
    )
    panel_specs[[plot_id]]$imagery_file <- file.path(
      imagery_dir,
      paste0("plot_", plot_id, ".png")
    )
  }

  tryCatch(
    invisible(curl::multi_download(
      urls = vapply(panel_specs, .todo_pdf_map_imagery_url, ""),
      destfiles = vapply(panel_specs, `[[`, "", "imagery_file"),
      resume = FALSE,
      progress = FALSE
    )),
    error = function(e) {
      warning("Satellite imagery was unavailable; rendering the to-do map without it.")
    }
  )

  panels <- lapply(
    names(panel_specs),
    .todo_pdf_map_panel,
    plots = plots,
    nests = nests,
    gate = gate,
    gate_plot = gate_plot,
    panel_specs = panel_specs
  )
  panel_row <- patchwork::wrap_plots(panels, nrow = 1)
  map <- patchwork::wrap_plots(
    panel_row,
    .todo_pdf_map_legend(),
    ncol = 1,
    heights = c(1, 0.16)
  )

  ggsave(
    filename = file,
    plot = map,
    width = 190,
    height = 175,
    units = "mm",
    dpi = 240,
    bg = "white"
  )

  invisible(file)
}
