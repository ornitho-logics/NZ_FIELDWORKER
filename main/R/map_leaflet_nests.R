map_nest_leaflet <- function(n, m = leaflet_map()) {
  n <- n[!is.na(lat) & !is.na(lon)]

  if (nrow(n) == 0) {
    return(m)
  }

  n <- st_as_sf(n, coords = c("lon", "lat"), crs = 4326)

  m |>
    addCircleMarkers(
      group = "live_nest_markers",
      data = n,
      fillOpacity = 0.5,
      opacity = 0.5,
      radius = ~3,
      label = ~nest
    )
}
