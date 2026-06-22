
leaflet_map <- function(x = studySiteCenter[1], y = studySiteCenter[2]) {
  leaflet(
    options = leafletOptions(zoomControl = TRUE)
  ) |>
    addTiles(group = "Street Map") |>
    addProviderTiles("OpenStreetMap", group = "Street Map") |>
    addProviderTiles("Esri.WorldImagery", group = "Satellite") |>
    addProviderTiles("OpenTopoMap", group = "Topo Map") |>
    addScaleBar(
      position = "bottomright",
      options = scaleBarOptions(imperial = FALSE, maxWidth = 200)
    ) |>
    setView(
      lng = as.numeric(x),
      lat = as.numeric(y),
      zoom = 7
    ) |>
    addLayersControl(
      baseGroups = c("Street Map", "Satellite", "Topo Map"),
      options = layersControlOptions(
        collapsed = TRUE,
        position = "topleft"
      )
    )
}
