shinyServer(function(input, output, session) {
  # observe({
  #   on.exit(assign("input", reactiveValuesToList(input), envir = .GlobalEnv))
  # })

  output$ref_date_text <- renderUI({
    HTML(ref_date_message(input$refdate))
  })

  output$overview_show <- renderPlot({
    try_else(overview_graph, sys_graph)
  })

  output$new_data <- renderUI({
    entry_classes <- fifelse(
      dbtabs_entry %in% c("inspectors", "artifacts"),
      "btn-danger bttn-danger",
      "btn-primary bttn-primary"
    )

    startApp(
      hrefs = glue("../DataEntry/{dbtabs_entry}/"),
      labels = paste(icon("pencil"), dbtabs_entry),
      classes = entry_classes
    )
  })

  output$open_gps <- renderUI({
    startApp(
      hrefs = "../gpxui/",
      labels = paste(icon("location-crosshairs"), "GPS upload/download")
    )
  })

  output$open_db <- renderUI({
    startApp(
      hrefs = "../../../db_ui/field_db.php",
      labels = paste(icon("database"), "Database interface")
    )
  })

  lapply(dbtabs_view, function(tab) {
    output[[paste0(tab, "_show")]] <- TABLE_show(tab, session)
  })

  N <- reactive({
    current_nests(
      main_tab = input$main,
      refdate = input$refdate
    )
  })

  output$map_nests_show <- renderPlot({
    n <- N()
    req(n)
    map_nests(
      n[nest_state %in% input$nest_state],
      size = input$nest_size,
      grandTotal = nrow(n),
      .refdate = input$refdate
    )
  })

  output$map_nests_pdf <- download_plot_pdf(
    filename = "map_nests.pdf",
    plot = function() {
      n <- N()
      req(n)

      map_nests(
        n[nest_state %in% input$nest_state],
        size = input$nest_size,
        grandTotal = nrow(n),
        .refdate = input$refdate
      )
    }
  )

  output$nest_dynmap_show <- {
    leafmap <- leaflet_map()
    renderLeaflet(leafmap)
  }

  observeEvent(input$main, {
    if (input$main == "live_nest_map") {
      n <- N()
      req(n)
      n <- st_as_sf(n[!is.na(lat)], coords = c("lon", "lat"), crs = 4326)
      if (nrow(n) > 0) {
        leafletProxy(mapId = "nest_dynmap_show") |>
          clearGroup("live_nest_markers") |>
          addCircleMarkers(
            group = "live_nest_markers",
            data = n,
            fillOpacity = 0.5,
            opacity = 0.5,
            radius = ~3,
            label = ~nest
          )
      }
    }
  })

  todo_data <- reactive({
    n <- N()
    req(n)

    extract_TODO(n, .refdate = input$refdate)
  })

  output$todo_list_show <- render_todo_table(todo_data)

  output$map_todo_show <- renderPlot({
    n <- N()
    req(n)
    map_todo(n, size = input$nest_size, .refdate = input$refdate)
  })

  output$todo_pdf <- download_plot_pdf(
    filename = "todo.pdf",
    plot = function() {
      n <- N()
      req(n)

      todo(n, size = input$nest_size, .refdate = input$refdate)
    }
  )

  output$hatching_est_plot <- renderPlot({
    require(mgcv)

    h <- readRDS(hatch_pred_gam)

    pred <-
      ggeffects::ggpredict(
        h,
        terms = c(
          glue("float_angle [{input$float_angle}]"),
          glue("surface [{input$float_height}]")
        )
      ) |>
      data.table()
    pred <- pred[, .(predicted, conf.low, conf.high)]
    pred <- melt(pred, measure.vars = names(pred))
    pred[, date_ := as.Date(input$refdate) + value]
    pred[, value := round(value, 1)]
    pred[,
      variable := factor(
        variable,
        labels = c(
          "Most likely [average]",
          "Earliest [95%CI-low]",
          "Latest [95%CI-high]"
        )
      )
    ]
    setnames(pred, c("", "Days to hatch", "Hatching date"))

    gtab <- ggpubr::ggtexttable(
      pred,
      rows = NULL,
      theme = ggpubr::ttheme(base_size = 12)
    )

    g1 <-
      ggplot(h$model, aes(x = float_angle, y = days_to_hatch)) +
      ggbeeswarm::geom_beeswarm(alpha = 0.5) +
      geom_smooth() +
      geom_vline(aes(xintercept = input$float_angle), color = "#df4306") +
      theme_minimal(base_size = 12)

    g2 <-
      ggplot(h$model, aes(x = surface, y = days_to_hatch)) +
      ggbeeswarm::geom_beeswarm(alpha = 0.5) +
      geom_smooth(method = "loess", span = 1.0) +
      geom_vline(aes(xintercept = input$float_height), color = "#df4306") +
      theme_minimal(base_size = 12)

    gtab / (g1 + g2) + plot_layout(axes = "collect", heights = c(1, 2))
  })

  session$allowReconnect(TRUE)
})
