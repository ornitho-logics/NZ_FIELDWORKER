shinyServer(function(input, output, session) {
  observe({
    on.exit(assign("input", reactiveValuesToList(input), envir = .GlobalEnv))
  })

  output$ref_date_text <- renderUI({
    HTML(ref_date_message(input$refdate))
  })

  output$overview_show <- renderPlot(
    {
      try_else(
        overview_graph(),
        fallback_ggplot,
        fail = 'overview_graph() failed!'
      )
    }
  )

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
    NESTS(
      main_tab = input$main,
      refdate = input$refdate
    )
  })

  output$map_nests_show <- renderPlot({
    try_else(
      {
        n <- N()
        req(n)

        map_nests(
          n[nest_state %in% input$nest_state],
          size = input$nest_size,
          grandTotal = nrow(n),
          .refdate = input$refdate
        )
      },
      fallback_ggplot,
      fail = "map_nests() failed!"
    )
  })

  output$map_nests_pdf <- download_plot_pdf(
    filename = "map_nests.pdf",
    plot = function() {
      try_else(
        {
          n <- N()
          req(n)

          map_nests(
            n[nest_state %in% input$nest_state],
            size = input$nest_size,
            grandTotal = nrow(n),
            .refdate = input$refdate
          )
        },
        fallback_ggplot,
        fail = "map_nests() failed!"
      )
    }
  )

  output$map_nest_leaflet_show <- renderLeaflet({
    try_else(
      {
        n <- N()
        req(n)

        live_nest_leaflet(n)
      },
      fallback_leaflet,
      fail = "live_nest_leaflet() failed!"
    )
  })

  output$todo_list_show <- render_todo_table({
    try_else(
      {
        n <- N()
        req(n)

        todo_list(n, .refdate = input$refdate)
      },
      fallback_dt,
      fail = "todo_list() failed!"
    )
  })

  output$todo_pdf <- download_gt_pdf(
    filename = "todo.pdf",
    table = function() {
      try_else(
        {
          n <- N()
          req(n)

          todo_pdf_table(n, .refdate = input$refdate)
        },
        fallback_gt,
        fail = "todo_pdf_table() failed!"
      )
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
