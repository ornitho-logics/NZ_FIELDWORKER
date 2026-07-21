.kmz_nest_state_key <- function(x) {
  x <- trimws(as.character(x))
  x[is.na(x) | !nzchar(x)] <- "unknown"
  x
}

.kmz_safe_id <- function(x) {
  x <- gsub("[^A-Za-z0-9_-]+", "_", as.character(x))
  x[is.na(x) | !nzchar(x)] <- "unknown"
  x
}

.kmz_xml_escape <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""

  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x <- gsub("'", "&apos;", x, fixed = TRUE)

  x
}

.kmz_label_value <- function(x) {
  if (!length(x)) {
    return(NA_character_)
  }

  x <- x[1]

  if (is.na(x)) {
    return(NA_character_)
  }

  x <- as.character(x)

  if (!nzchar(trimws(x))) {
    return(NA_character_)
  }

  x
}

.kmz_icon_text <- function(x) {
  x <- .kmz_label_value(x)

  if (is.na(x)) {
    return("")
  }

  days <- suppressWarnings(as.numeric(x))

  if (!is.na(days)) {
    return(format(round(days), trim = TRUE, scientific = FALSE))
  }

  x
}

.kmz_label_text <- function(row) {
  lines <- c(
    .kmz_label_value(row$nest_id),
    .kmz_label_value(row$hatch_state)
  )

  lines <- lines[!is.na(lines)]

  if (!length(lines)) {
    return("unknown nest")
  }

  paste(lines, collapse = " | ")
}

.kmz_kml_style <- function(id, icon_href) {
  glue(
    "<Style id=\"{.kmz_xml_escape(id)}\">",
    "<IconStyle>",
    "<scale>2</scale>",
    "<Icon><href>{.kmz_xml_escape(icon_href)}</href></Icon>",
    "<hotSpot x=\"0.5\" y=\"0.06\" xunits=\"fraction\" yunits=\"fraction\"/>",
    "</IconStyle>",
    "<LabelStyle><scale>1.5</scale></LabelStyle>",
    "<BalloonStyle><displayMode>hide</displayMode></BalloonStyle>",
    "</Style>"
  ) |>
    as.character()
}

.kmz_kml_placemark <- function(row) {
  nest_name <- .kmz_label_text(row)

  glue(
    "<Placemark>",
    "<name>{.kmz_xml_escape(nest_name)}</name>",
    "<styleUrl>#{.kmz_xml_escape(row$kmz_style)}</styleUrl>",
    "<Point>",
    "<coordinates>{sprintf('%.8f,%.8f,0', row$lon, row$lat)}</coordinates>",
    "</Point>",
    "</Placemark>"
  ) |>
    as.character()
}

.kmz_write_pin_icon <- function(file, fill, label = "", outline = "#455a64") {
  png(
    filename = file,
    width = 96,
    height = 96,
    units = "px",
    bg = "transparent"
  )
  on.exit(dev.off(), add = TRUE)

  par(mar = rep(0, 4), xaxs = "i", yaxs = "i")
  plot.new()
  plot.window(xlim = c(0, 1), ylim = c(0, 1), asp = 1)

  polygon(
    x = c(0.5, 0.86, 0.14),
    y = c(0.02, 0.47, 0.47),
    col = fill,
    border = outline,
    lwd = 4
  )

  symbols(
    x = 0.5,
    y = 0.6,
    circles = 0.34,
    inches = FALSE,
    add = TRUE,
    bg = fill,
    fg = outline,
    lwd = 4
  )

  symbols(
    x = 0.5,
    y = 0.61,
    circles = 0.17,
    inches = FALSE,
    add = TRUE,
    bg = "#ffffff",
    fg = adjustcolor(outline, alpha.f = 0.65),
    lwd = 2
  )

  label <- .kmz_label_value(label)

  if (!is.na(label)) {
    text(
      x = 0.5,
      y = 0.61,
      labels = label,
      col = "#111827",
      font = 2,
      cex = max(0.75, min(1.7, 2.1 - 0.28 * nchar(label)))
    )
  }
}

.kmz_zip <- function(file, files, root) {
  out_dir <- dirname(file)

  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }

  file <- file.path(
    normalizePath(out_dir, mustWork = TRUE),
    basename(file)
  )

  unlink(file)

  if (requireNamespace("zip", quietly = TRUE)) {
    zipr(
      zipfile = file,
      files = files,
      root = root,
      mode = "mirror",
      include_directories = FALSE
    )
  } else {
    oldwd <- setwd(root)
    on.exit(setwd(oldwd), add = TRUE)

    status <- utils::zip(
      zipfile = file,
      files = files,
      flags = "-r9Xq"
    )

    if (!is.null(status) && status != 0) {
      stop("Could not create KMZ archive.", call. = FALSE)
    }
  }

  if (!file.exists(file) || file.info(file)[["size"]] == 0) {
    stop("Could not create KMZ archive.", call. = FALSE)
  }

  invisible(file)
}

# Write the latest nest locations to a KMZ file.
# Creates a KMZ containing one placemark per row in `n`, with custom pin icons.
# coloured by `nest_state`, with offline-safe labels for Google Earth Android.
# kmz_nest_latest('~/Dropbox/test.kmz')

kmz_nest_latest <- function(
  file,
  n = DBq("SELECT * FROM NESTS_LATEST"),
  document_name = "Cass nests"
) {
  if ("error" %in% names(n)) {
    stop(n$error[1], call. = FALSE)
  }

  n <- copy(as.data.table(n))

  bad_coord <- n[
    is.na(lat) | is.na(lon) | !is.finite(lat) | !is.finite(lon),
    .(nest_id, lat, lon)
  ]

  if (nrow(bad_coord)) {
    stop(
      glue(
        "Cannot create KMZ: {nrow(bad_coord)} row(s) have missing or non-finite coordinates."
      ),
      call. = FALSE
    )
  }

  n[, kmz_state := .kmz_nest_state_key(nest_state)]

  if ("days_ago" %in% names(n)) {
    n[, kmz_icon_text := vapply(days_ago, .kmz_icon_text, character(1))]
  } else {
    n[, kmz_icon_text := ""]
  }

  n[,
    kmz_style := glue_data(
      .SD,
      "nest_{.kmz_safe_id(kmz_state)}_{.kmz_safe_id(kmz_icon_text)}"
    ) |>
      as.character()
  ]

  icon_styles <- unique(n[, .(state = kmz_state, icon_text = kmz_icon_text, style_id = kmz_style)])
  setorder(icon_styles, state, icon_text)

  icon_styles[,
    let(
      icon_href = glue_data(
        .SD,
        "icons/{.kmz_safe_id(style_id)}.png"
      ) |>
        as.character(),
      color = unname(kmz_nest_state_cols[state])
    )
  ]
  icon_styles[is.na(color), color := kmz_nest_state_cols[["unknown"]]]

  workdir <- tempfile("nest_latest_kmz_")
  icon_dir <- file.path(workdir, "icons")

  dir.create(icon_dir, recursive = TRUE)
  on.exit(unlink(workdir, recursive = TRUE), add = TRUE)

  icon_styles[,
    .kmz_write_pin_icon(
      file = file.path(workdir, icon_href),
      fill = color,
      label = icon_text
    ),
    by = style_id
  ]

  icon_styles[,
    style_kml := .kmz_kml_style(
      id = style_id,
      icon_href = icon_href
    ),
    by = style_id
  ]

  placemark_kml <- n[,
    .(
      placemark_kml = .kmz_kml_placemark(.SD)
    ),
    by = seq_len(nrow(n))
  ][["placemark_kml"]]

  kml <- c(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<kml xmlns=\"http://www.opengis.net/kml/2.2\">",
    "<Document>",
    glue("<name>{.kmz_xml_escape(document_name)}</name>") |>
      as.character(),
    icon_styles$style_kml,
    "<Folder>",
    "<name>Nests</name>",
    placemark_kml,
    "</Folder>",
    "</Document>",
    "</kml>"
  )

  writeLines(kml, file.path(workdir, "doc.kml"), useBytes = TRUE)

  .kmz_zip(
    file = file,
    files = c("doc.kml", icon_styles$icon_href),
    root = workdir
  )

  invisible(file)
}
