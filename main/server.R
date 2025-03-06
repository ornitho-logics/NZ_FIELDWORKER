

shinyServer(function(input, output, session) {

 observe( on.exit( assign('input', reactiveValuesToList(input) , envir = .GlobalEnv)) )
# observe(on.exit(assign("session", reactiveValuesToList(session$clientData), envir = .GlobalEnv)))

#* control bar 
  output$clock = renderUI({

    invalidateLater(5000, session)

    glue('<kbd>{format(Sys.time(), "%d-%B %H:%M %Z")}</kbd>') |> HTML()

  })


  output$hdd_state = renderUI({

    dfsys_output()
  
  })




#* ENTER DATA
  output$new_data = renderUI({

    startApp(getOption("app_nam"), "DataEntry", getOption("dbtabs_entry"),
      host = session$clientData$url_hostname,
      labels = paste(icon("pencil"), getOption("dbtabs_entry"))
    )
  
  })

#* GPS
  output$open_gps = renderUI({

    startApp(getOption("app_nam"), "gpxui",
      host = session$clientData$url_hostname,
      labels = p(icon("location-crosshairs"), "GPS upload/download")
    )
  
  })

#* Database interface
  output$open_db = renderUI({
    
    startApp("db_ui", "field_db.php",
      isShiny = FALSE,
      host = session$clientData$url_hostname,
      labels = p(icon("database"), "Database interface")
    )

  })
  
  output$dbdump = downloadHandler(
    filename = paste0(getOption("db"), ".zip"),
    content = function(file) {
      
      dbTxtDump(zipfile = file)

  }
  )
  

#* VIEW DATA     

  TABLE_show = function(table_nam) {
    DT::renderDataTable(
      {
      get_data = reactivePoll(5000, session,
        checkFunc = function() {
          dbtable_is_updated(table_nam)
        },
        valueFunc = function() {
          DBq(glue("select * FROM {table_nam}"))[, ":="(pk = NULL, nov = NULL)] |>
            data.frame()
        }
      )

      get_data()

      },
      server        = FALSE,
      rownames      = FALSE, 
      escape        = FALSE,
      extensions    = c("Scroller", "Buttons"),
      options       = list(
        dom         = "Blfrtip",
        buttons     = list("copy", list(
                      extend = "collection"
                      , buttons = "excel"
                      , text = "Download"
                    ) ),
        scrollX     = "600px",
        deferRender = TRUE,
        scrollY     = 900,
        scroller    = TRUE, 
        searching   = TRUE, 
        columnDefs  = list(list(className = "dt-center", targets = "_all"))
      ),
      class = c("compact", "stripe", "order-column", "hover")
    )
  }
 
  # crosscheck with getOption('dbtabs_view')
  output$OBSERVERS_show   = TABLE_show("OBSERVERS")      
  output$CAPTURES_show    = TABLE_show("CAPTURES")       
  output$RESIGHTINGS_show = TABLE_show("RESIGHTINGS")       
  output$NESTS_show       = TABLE_show("NESTS")       
  output$EGGS_show        = TABLE_show("EGGS")       


#+ NESTS DATA

  N <- reactive({
    
    if (input$main == "NESTS MAP" | input$main == "LIVE NEST MAP" | input$main == 'NESTS OVERVIEW') {
      
      WaitToast("Processing nests...")
    
      n = NESTS()
      # nolat = n[is.na(lat)]
      # if (nrow(nolat) > 0) {
      #   ErrToast(
      #     glue("{paste(nolat$nest, collapse = ';')} without coordinates.
      #           Did you download all GPS units?")
      #   )
      # }

      # n[, N := .N, nest_id]
      # doubleEntry = n[N > 1]
      
      # if (nrow(doubleEntry) > 0) {
      #   WarnToast(
      #     glue("Nests with inconsistent states: {paste( unique(doubleEntry$nest_id), collapse = ';')} ")
      #   )
      # }

      n
    }
  })



#* NESTS MAP
  leafmap = leaflet_map(x=getOption("studySiteCenter")[1],y=getOption("studySiteCenter")[2]) 

  output$nest_dynmap_show = renderLeaflet(leafmap)

  observeEvent(
    list(input$main == "NEST MAP"), {

      n = N()
      req(n)
      # n = st_as_sf(n[!is.na(lat)], coords = c("lon", "lat"), crs = 4326)


    if (nrow(n) > 0) {

      leafletProxy(mapId = "nest_dynmap_show") |>
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
  
  
  })

#* NESTS OVERVIEW

  output$nests_overview =  DT::renderDataTable(
      {
      n = N()
      req(n)
      # setorder(n, days_till_hatching)

      },
      server        = FALSE,
      rownames      = TRUE, 
      escape        = FALSE,
      extensions    = c("Scroller", "Buttons"),
      options       = list(
        dom         = "Blfrtip",
        buttons     = list("copy", list(
                      extend = "collection"
                      , buttons = c("excel", "pdf")
                      , text = "Download"
                    ) ),
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
