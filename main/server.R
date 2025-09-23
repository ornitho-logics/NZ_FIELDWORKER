shinyServer(function(input, output, session) {

observe(on.exit(assign('input', reactiveValuesToList(input), envir = .GlobalEnv)))
# observe(on.exit(assign("session", reactiveValuesToList(session$clientData), envir = .GlobalEnv)))

# Control Bar Clock
  output$clock <- renderUI({
    invalidateLater(5000, session)
    glue('<kbd>{format(Sys.time(), "%d-%B %H:%M %Z")}</kbd>') |> HTML()
  })

  output$hdd_state <- renderUI({
    dfsys_output()
})

# ENTER DATA
  output$new_data <- renderUI({
    startApp(
        hrefs = glue('../DataEntry/{dbtabs_entry}/'),
        labels = paste(icon("pencil"), dbtabs_entry)
    )
})

# GPS
output$open_gps <- renderUI({
  startApp(
    hrefs  = "../gpxui/" ,
    labels = p(icon("location-crosshairs"), "GPS upload/download")
  ) 
})

# Database Interface
  output$open_db <- renderUI({
    startApp(
      hrefs = "../../../db_ui/field_db.php",
      labels = p(icon("database"), "Database interface")
    )
  })

  output$dbdump <- downloadHandler(
    filename = paste0(db, ".zip"),
    content = function(file) {
      dbTxtDump(zipfile = file)
})

# DATA VIEWERS

  #NOTE: Crosscheck with dbtabs_view
  output$OBSERVERS_show          <- TABLE_show("OBSERVERS", session)      
  output$CAPTURES_show           <- TABLE_show("CAPTURES", session)       
  output$RESIGHTINGS_show        <- TABLE_show("RESIGHTINGS", session)       
  output$RESIGHTINGS_PUBLIC_show <- TABLE_show("RESIGHTINGS_PUBLIC", session)       
  output$NESTS_show              <- TABLE_show("NESTS", session)       
  output$EGGS_show               <- TABLE_show("EGGS", session)       

# DATA SETS
  N <- reactive({
    req(input$main %in% c("MAP", "nests_overview"))
    
    w <- Waiter$new(
      id = "MAP_show", 
      html = tagList(spin_ellipsis(), h4("Processing nests..."))
    )
    
    w$show()
    on.exit(w$hide(), add = TRUE)
    
    NESTS()
  })

#+ NESTS MAP
leafmap <- leaflet_map()

output$MAP_show <- renderLeaflet(leafmap)

observeEvent(input$main, {
  if (input$main == "MAP") {
    n <- N()
    req(n)
    if (nrow(n) > 0) {
      leafletProxy("MAP_show") |>
        clearMarkers() |>
        clearShapes() |>
        addCircleMarkers(
          data        = n,
          fillOpacity = 0.5,
          opacity     = 0.5,
          radius      = ~3,
          label       = ~nest_id
        )
    }
  }
})

#+ NESTS OVERVIEW
output$nests_overview <- DT::renderDataTable(
  {
    n <- N()
    req(n)
  },
  server        = FALSE,
  rownames      = TRUE, 
  escape        = FALSE,
  extensions    = c("Scroller", "Buttons"),
  options       = list(
    dom         = "Blfrtip",
    buttons     = list("copy", list(
      extend = "collection",
      buttons = c("excel", "pdf"),
      text = "Download"
    )),
    scrollX     = "600px",
    deferRender = TRUE,
    scrollY     = 900,
    scroller    = TRUE, 
    searching   = TRUE, 
    columnDefs  = list(list(className = "dt-center", targets = "_all"))
  ),
  class = c("compact", "stripe", "order-column", "hover")
)

})
