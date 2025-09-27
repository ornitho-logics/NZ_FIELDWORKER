shinyServer(function(input, output, session) {

# observe(on.exit(assign('input', reactiveValuesToList(input), envir = .GlobalEnv)))
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

# DATA SETS (REACTIVE)
  all_adult_cap <- reactive({
    req(input$main %in% c("MAP", "view_data_all"))
   
    all_adults()
})
  all_pair <- reactive({
    req(input$main %in% c( "view_data_all"))
   
    all_adults() |> pairs()
})


# DATA VIEWERS

  #NOTE: Crosscheck with dbtabs_view
  output$OBSERVERS_show          <- TABLE_show("OBSERVERS", session)      
  output$CAPTURES_show           <- TABLE_show("CAPTURES", session)       
  output$RESIGHTINGS_show        <- TABLE_show("RESIGHTINGS", session)       
  output$RESIGHTINGS_PUBLIC_show <- TABLE_show("RESIGHTINGS_PUBLIC", session)       
  output$NESTS_show              <- TABLE_show("NESTS", session)       
  output$EGGS_show               <- TABLE_show("EGGS", session)       

  output$all_adults_show         <- DATASET_show(all_adult_cap()[, let(lat = NULL, lon = NULL)] )
  output$all_pairs_show          <- DATASET_show(all_pair()[, let(lat = NULL, lon = NULL)] )



#+ FIELD MAP
  leafmap <- leaflet_map()

  output$MAP_show <- renderLeaflet(leafmap)

  observeEvent(input$main, {
    if (input$main == "MAP") {
      
      dat <- all_adult_cap()
      
      if (nrow(dat) > 0) {
        leafletProxy("MAP_show") |>
          clearMarkers() |>
          clearShapes() |>
          addCircleMarkers(
            data        = dat,
            fillOpacity = 0.5,
            opacity     = 0.5,
            radius      = ~3,
            label       = ~ combo
          
          )
      }
    }
})



})
