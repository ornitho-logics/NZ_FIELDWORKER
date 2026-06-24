study_site_loader <- function(
  lon = 170.507560,
  lat = -43.881055,
  radius_m = 1000,
  crs = 4326
) {
  fallback <- function() {
    msg <- "The study site did not load properly. WKT is faulty. Fix the entry in the artifacts table"

    if (shiny::isRunning()) {
      showNotification(msg, type = "warning", duration = 10)
    } else {
      warning(msg, call. = FALSE)
    }

    sf::st_sf(
      id = "study_site",
      geometry = sf::st_sfc(sf::st_point(c(lon, lat)), crs = 4326)
    ) |>
      sf::st_buffer(radius_m)
  }

  x <- try(
    DBq(glue(
      "SELECT artifact FROM {db}.artifacts WHERE artifact_name = 'study_area'"
    )),
    silent = TRUE
  )

  if (
    inherits(x, "try-error") ||
      "error" %in% names(x) ||
      !nrow(x) ||
      is.na(x$artifact[1]) ||
      !nzchar(x$artifact[1])
  ) {
    return(fallback())
  }

  study_site <- try(
    {
      obj <- eval(
        parse(text = x$artifact[1]),
        envir = new.env(parent = globalenv())
      )

      if (inherits(obj, "sf")) {
        out <- obj
      } else if (inherits(obj, "sfc")) {
        out <- sf::st_sf(id = seq_along(obj), geometry = obj)
      } else {
        wkt <- unlist(obj, use.names = TRUE)
        ids <- names(wkt)

        if (is.null(ids) || any(!nzchar(ids))) {
          ids <- seq_along(wkt)
        }

        out <- sf::st_sf(
          id = ids,
          geometry = sf::st_as_sfc(unname(wkt), crs = crs)
        )
      }

      if (!"id" %in% names(out)) {
        out$id <- seq_len(nrow(out))
      }

      out <- out |>
        sf::st_make_valid() |>
        sf::st_transform(4326)

      # smoke test for later in leaflet
      out |>
        sf::st_union() |>
        sf::st_centroid()

      out
    },
    silent = TRUE
  )

  if (inherits(study_site, "try-error") || !inherits(study_site, "sf")) {
    return(fallback())
  }

  study_site
}
