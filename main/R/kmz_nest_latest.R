kmz_nest_latest <- function(
  file,
  n = DBq("SELECT * FROM NESTS_LATEST"),
  document_name = "Cass nests"
) {
  n <- data.table(n)

  if ("error" %in% names(n)) {
    stop(n$error[1])
  }

  workdir <- tempfile("nest_latest_kmz_")
  icon_dir <- file.path(workdir, "icons")
  dir.create(icon_dir, recursive = TRUE)
  on.exit(unlink(workdir, recursive = TRUE), add = TRUE)

  n[, kmz_state := kmz_nest_state_key(nest_state)]
  n[, kmz_style := paste0("nest_", kmz_safe_id(kmz_state))]

  states <- sort(unique(n$kmz_state))

  state_styles <- data.table(
    state = states,
    style_id = paste0("nest_", kmz_safe_id(states)),
    icon_href = paste0("icons/nest_", kmz_safe_id(states), ".png")
  )

  state_styles[,
    color := unname(kmz_nest_state_cols[state])
  ]
  state_styles[
    is.na(color),
    color := kmz_nest_state_cols[["unknown"]]
  ]

  for (i in seq_len(nrow(state_styles))) {
    kmz_write_pin_icon(
      file = file.path(workdir, state_styles$icon_href[i]),
      fill = state_styles$color[i]
    )
  }

  placemark_data <- n[
    !is.na(lat) & !is.na(lon)
  ]

  kml <- c(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<kml xmlns=\"http://www.opengis.net/kml/2.2\">",
    "<Document>",
    paste0("<name>", kmz_xml_escape(document_name), "</name>"),
    vapply(
      seq_len(nrow(state_styles)),
      function(i) {
        kmz_kml_style(
          id = state_styles$style_id[i],
          icon_href = state_styles$icon_href[i]
        )
      },
      character(1)
    ),
    "<Folder>",
    "<name>Nests</name>",
    vapply(
      seq_len(nrow(placemark_data)),
      function(i) {
        kmz_kml_placemark(placemark_data[i])
      },
      character(1)
    ),
    "</Folder>",
    "</Document>",
    "</kml>"
  )

  writeLines(kml, file.path(workdir, "doc.kml"), useBytes = TRUE)

  kmz_zip(
    file = file,
    files = c("doc.kml", state_styles$icon_href),
    root = workdir
  )

  invisible(file)
}

kmz_nest_state_cols <- c(
  "S" = "#f7b267",
  "F" = "#65cdaa",
  "I" = "#fff58f",
  "H" = "#78d6ff",
  "B" = "#76d7bd",
  "pP" = "#e37882",
  "P" = "#b78be7",
  "pD" = "#edadd3",
  "D" = "#b9a1dc",
  "notA" = "#9b9b9b",
  "O" = "#d0d0d0",
  "unknown" = "#c7c7c7"
)

kmz_nest_state_key <- function(x) {
  x <- as.character(x)
  x[is.na(x) | !nzchar(trimws(x))] <- "unknown"
  trimws(x)
}

kmz_safe_id <- function(x) {
  x <- gsub("[^A-Za-z0-9_-]+", "_", as.character(x))
  x[!nzchar(x)] <- "unknown"
  x
}

kmz_xml_escape <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x <- gsub("'", "&apos;", x, fixed = TRUE)
  x
}

kmz_html_escape <- function(x) {
  x <- kmz_xml_escape(x)
  x <- gsub("\r\n|\r|\n", "<br/>", x)
  x
}

kmz_popup_value <- function(x) {
  x <- as.character(x)

  if (is.na(x) || !nzchar(trimws(x))) {
    return(NA_character_)
  }

  x
}

kmz_popup_html <- function(row) {
  popup_cols <- setdiff(
    names(row),
    c("lat", "lon", "kmz_state", "kmz_style")
  )

  values <- lapply(row[, ..popup_cols], kmz_popup_value)
  keep <- !vapply(values, is.na, logical(1))

  if (!any(keep)) {
    return("<p>No nest details available.</p>")
  }

  rows <- Map(
    function(field, value) {
      paste0(
        "<tr>",
        "<th style=\"text-align:left;vertical-align:top;",
        "padding:3px 8px 3px 0;border-bottom:1px solid #ddd;\">",
        kmz_html_escape(field),
        "</th>",
        "<td style=\"vertical-align:top;",
        "padding:3px 0;border-bottom:1px solid #ddd;\">",
        kmz_html_escape(value),
        "</td>",
        "</tr>"
      )
    },
    names(values)[keep],
    values[keep]
  )

  paste0(
    "<table style=\"border-collapse:collapse;font-size:13px;\">",
    paste(rows, collapse = ""),
    "</table>"
  )
}

kmz_kml_style <- function(id, icon_href) {
  paste0(
    "<Style id=\"",
    kmz_xml_escape(id),
    "\">",
    "<IconStyle>",
    "<scale>1.1</scale>",
    "<Icon><href>",
    kmz_xml_escape(icon_href),
    "</href></Icon>",
    "<hotSpot x=\"0.5\" y=\"0.06\" xunits=\"fraction\" yunits=\"fraction\"/>",
    "</IconStyle>",
    "<LabelStyle><scale>0.75</scale></LabelStyle>",
    "</Style>"
  )
}

kmz_kml_placemark <- function(row) {
  nest_name <- kmz_popup_value(row$nest_id)

  if (is.na(nest_name)) {
    nest_name <- "unknown nest"
  }

  description <- kmz_xml_escape(kmz_popup_html(row))

  paste0(
    "<Placemark>",
    "<name>",
    kmz_xml_escape(nest_name),
    "</name>",
    "<styleUrl>#",
    kmz_xml_escape(row$kmz_style),
    "</styleUrl>",
    "<description>",
    description,
    "</description>",
    "<Point>",
    "<coordinates>",
    sprintf("%.8f,%.8f,0", row$lon, row$lat),
    "</coordinates>",
    "</Point>",
    "</Placemark>"
  )
}

kmz_write_pin_icon <- function(file, fill, outline = "#455a64") {
  grDevices::png(
    filename = file,
    width = 96,
    height = 96,
    units = "px",
    bg = "transparent"
  )
  on.exit(grDevices::dev.off(), add = TRUE)

  graphics::par(mar = rep(0, 4), xaxs = "i", yaxs = "i")
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, 1), ylim = c(0, 1), asp = 1)
  graphics::polygon(
    x = c(0.5, 0.78, 0.22),
    y = c(0.05, 0.46, 0.46),
    col = fill,
    border = outline,
    lwd = 4
  )
  graphics::symbols(
    x = 0.5,
    y = 0.58,
    circles = 0.29,
    inches = FALSE,
    add = TRUE,
    bg = fill,
    fg = outline,
    lwd = 4
  )
  graphics::symbols(
    x = 0.5,
    y = 0.59,
    circles = 0.105,
    inches = FALSE,
    add = TRUE,
    bg = "#ffffff",
    fg = grDevices::adjustcolor(outline, alpha.f = 0.65),
    lwd = 2
  )
}

kmz_zip <- function(file, files, root) {
  unlink(file)

  if (requireNamespace("zip", quietly = TRUE)) {
    zip::zipr(
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

    if (!is.null(status) && !identical(status, 0L)) {
      stop("Could not create KMZ archive.")
    }
  }

  if (!file.exists(file) || file.info(file)[["size"]] == 0) {
    stop("Could not create KMZ archive.")
  }

  invisible(file)
}
