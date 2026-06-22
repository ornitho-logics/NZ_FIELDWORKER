default_study_site_artifact <- function() {
  'list(
    NZ = "POLYGON ((172.98 -43.58, 173.00 -43.58, 173.00 -43.56, 172.98 -43.56, 172.98 -43.58))"
  )'
}

artifact_text <- function(
  artifact_name,
  default = default_study_site_artifact()
) {
  x <- DBq(glue(
    "SELECT artifact FROM {db}.artifacts WHERE artifact_name = {shQuote(artifact_name)}"
  ))

  missing_artifact <-
    "error" %in%
    names(x) ||
    !nrow(x) ||
    is.na(x$artifact[1]) ||
    !nzchar(x$artifact[1])

  if (missing_artifact) {
    msg <- glue(
      "No artifact text found for `{artifact_name}`. Using fallback NZ square."
    )

    if (shiny::isRunning()) {
      showNotification(msg, type = "warning", duration = 10)
    } else {
      warning(msg, call. = FALSE)
    }

    return(default)
  }

  x$artifact[1]
}

study_site_from_text <- function(txt, crs = 4326) {
  x <- eval(parse(text = txt), envir = new.env(parent = globalenv()))

  if (!inherits(x, "sf")) {
    if (inherits(x, "sfc")) {
      x <- sf::st_sf(id = seq_along(x), geometry = x)
    } else {
      wkt <- unlist(x, use.names = TRUE)
      ids <- names(wkt)

      if (is.null(ids) || any(!nzchar(ids))) {
        ids <- seq_along(wkt)
      }

      x <- sf::st_sf(
        id = ids,
        geometry = sf::st_as_sfc(unname(wkt), crs = crs)
      )
    }
  }

  if (!"id" %in% names(x)) {
    x$id <- seq_len(nrow(x))
  }

  x |>
    sf::st_make_valid() |>
    sf::st_transform(4326)
}

study_site_loader <- function(artifact_name = "study_area") {
  artifact_text(artifact_name) |>
    study_site_from_text()
}
