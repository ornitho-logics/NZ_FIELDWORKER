leaflet_map <- function(fail = NULL) {
  stusi <-
    study_site_loader()

  center <-
    stusi |>
    st_union() |>
    st_centroid() |>
    st_coordinates() |>
    as.numeric()

  m <-
    leaflet(options = leafletOptions(zoomControl = TRUE)) |>
    addProviderTiles(providers$Esri.WorldImagery, group = "Satellite") |>
    addProviderTiles(providers$OpenStreetMap, group = "Street Map") |>
    addProviderTiles(providers$OpenTopoMap, group = "Topo Map") |>
    addPolygons(
      data = stusi,
      group = "subplots",
      label = ~ as.character(id),
      labelOptions = labelOptions(
        permanent = TRUE,
        textOnly = TRUE,
        direction = "center",
        style = list(
          "font-size" = "18px",
          "font-weight" = "700",
          "color" = "#ffffff",
          "text-shadow" = "0 1px 3px #000000"
        )
      ),
      fillOpacity = 0,
      color = "#e24c4c",
      weight = 2
    ) |>
    addScaleBar(
      position = "bottomright",
      options = scaleBarOptions(imperial = FALSE, maxWidth = 200)
    ) |>
    addMeasure(primaryLengthUnit = "meters") |>
    addControlGPS(
      options = gpsOptions(
        position = "topleft",
        activate = TRUE,
        autoCenter = TRUE,
        maxZoom = 16,
        setView = TRUE
      )
    ) |>
    setView(
      lng = center[1],
      lat = center[2],
      zoom = 15
    ) |>
    addLayersControl(
      baseGroups = c("Satellite", "Street Map", "Topo Map"),
      overlayGroups = "subplots",
      options = layersControlOptions(
        collapsed = TRUE,
        position = "topleft"
      )
    )

  if (!is.null(fail)) {
    m <-
      m |>
      addControl(
        html = htmltools::tags$div(
          style = paste(
            "background: rgba(255, 255, 255, 0.92);",
            "padding: 8px 10px;",
            "border-radius: 4px;",
            "font-weight: 700;",
            "color: #b00020;",
            "box-shadow: 0 1px 5px rgba(0, 0, 0, 0.35);"
          ),
          fail
        ),
        position = "topright"
      )
  }

  m
}
