
leaflet_map <- function( ) {
  leaflet(options = leafletOptions(zoomControl = TRUE)) |>
    setView(lng = 172, lat = -44, zoom = 6) |>
    addTiles(group = "OpenStreetMap")
}
