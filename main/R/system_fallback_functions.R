fallback_ggplot <- function(fail = "Code error!") {
  ggplot() +
    ggtitle(fail) +
    theme_void() +
    theme(
      plot.title = element_text(size = 20)
    )
}

fallback_dt <- function(fail = "Function failed!") {
  data.table(
    status = fail
  )
}

fallback_gt <- function(fail = "Function failed!") {
  data.table(status = fail) |>
    gt::gt() |>
    gt::tab_header(title = gt::md("**Error**"))
}


fallback_leaflet <- function(
  fail = "Leaflet map failed!",
  lon = 170.507560,
  lat = -43.881055,
  zoom = 15,
  ...
) {
  leaflet(options = leafletOptions(zoomControl = TRUE)) |>
    addTiles() |>
    setView(
      lng = lon,
      lat = lat,
      zoom = zoom
    ) |>
    addControl(
      html = htmltools::tags$div(
        style = paste(
          "background: rgba(255, 255, 255, 0.94);",
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
