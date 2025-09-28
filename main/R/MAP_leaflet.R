

leaflet_map <- function( ) {
  
  leaflet(options = leafletOptions(zoomControl = TRUE)) |>

  addLayersControl(
    baseGroups    = c(
                    "Streets",
                    "Satellite",
                    "Topo"
                    ),
    options       = layersControlOptions(collapsed = TRUE)
  ) |> 

  addTiles(group = "Streets") |>
  addProviderTiles("OpenTopoMap", group = "Topo") |>
  addProviderTiles("Esri.WorldImagery", group = "Satellite") |>

  setView(lng = 172, lat = -44, zoom = 6) |>


  addControlGPS(
    options = gpsOptions(
      position   = "topleft",
      activate   = TRUE,
      autoCenter = TRUE,
      maxZoom    = 22,
      setView    = TRUE
    )
  ) |>

  addFullscreenControl()


}
