
leaflet_map <- function( ) {
  leaflet(options = leafletOptions(zoomControl = TRUE)) |>
    setView(lng = 172, lat = -44, zoom = 6) |>
    addTiles(group = "OpenStreetMap") |>
      addControlGPS(
        options = gpsOptions(
          position   = "topleft",
          activate   = TRUE,
          autoCenter = TRUE,
          maxZoom    = 16,
          setView    = TRUE
        )
      ) |>
      addMiniMap(toggleDisplay = TRUE) |>
      
      addFullscreenControl()


}
