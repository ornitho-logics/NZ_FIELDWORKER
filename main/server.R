shinyServer(function(input, output, session) {
  observe({
    on.exit(assign("input", reactiveValuesToList(input), envir = .GlobalEnv))
  })

  output$ref_date_text <- renderUI({
    ago <- round(Sys.Date() - as.Date(input$refdate))

    if (ago == 0) {
      o <- glue(
        "Reference date: {S(input$refdate, 1)} today. <i>Todo-s are for tomorrow!</i>"
      )
    }

    if (ago > 0) {
      o <- glue("Reference date: {S(input$refdate, 2)} {abs(ago)} days ago.")
    }

    if (ago < 0) {
      o <- glue(
        "Reference date: {S(input$refdate, 2)} {abs(ago)} days from now."
      )
    }

    HTML(o)
  })

  output$clock <- renderUI({
    invalidateLater(5000, session)
    glue('{HR()}{format(Sys.time(), "%d-%B %H:%M %Z")}') |> HTML()
  })

  output$hdd_state <- renderUI({
    dfsys_output()
  })

  output$new_data <- renderUI({
    startApp(
      hrefs = glue("../DataEntry/{dbtabs_entry}/"),
      labels = paste(icon("pencil"), dbtabs_entry)
    )
  })

  output$open_gps <- renderUI({
    startApp(
      hrefs = "../gpxui/",
      labels = p(icon("location-crosshairs"), "GPS upload/download")
    )
  })

  output$open_db <- renderUI({
    startApp(
      hrefs = "../../../db_ui/field_db.php",
      labels = p(icon("database"), "Database interface")
    )
  })

  lapply(dbtabs_view, function(tab) {
    output[[paste0(tab, "_show")]] <- TABLE_show(tab, session)
  })

  N <- reactive({
    if (
      input$main %in% c("nests_map", "live_nest_map", "todo_list", "todo_map")
    ) {
      n <- tryCatch(
        NESTS(.refdate = input$refdate),
        error = function(e) {
          ErrToast(glue(
            "Error fetching nests data. Maybe there are no nests on {input$refdate}?"
          ))
          return(NULL)
        }
      )

      if (is.null(n) || nrow(n) == 0) {
        ErrToast(glue("No nests found on {input$refdate}."))
        return(NULL)
      }

      req(n)

      nolat <- n[is.na(lat)]
      if (nrow(nolat) > 0) {
        ErrToast(
          glue(
            "{paste(nolat$nest, collapse = ';')} without coordinates. Did you download all GPS units?"
          )
        )
      }

      n[, N := .N, nest]
      doubleEntry <- n[N > 1]
      if (nrow(doubleEntry) > 0) {
        WarnToast(
          glue(
            "Nests with inconsistent states: {paste(unique(doubleEntry$nest), collapse = ';')}"
          )
        )
      }
      n
    }
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

  output$map_nests_pdf <- downloadHandler(
    filename = "map_nests.pdf",
    content = function(file) {
      n <- N()
      req(n)
      cairo_pdf(file = file, width = 11, height = 8.5)

      print(
        map_nests(
          n[nest_state %in% input$nest_state],
          size = input$nest_size,
          grandTotal = nrow(n),
          .refdate = input$refdate
        )
      )
      dev.off()
    }
  )

  leafmap <- leaflet_map()
  output$nest_dynmap_show <- renderLeaflet(leafmap)

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

  output$todo_list_show <- DT::renderDataTable(
    {
      n <- N() |> extract_TODO(.refdate = input$refdate)
      req(n)
      n[, let(lat = NULL, lon = NULL)]
    },
    server = FALSE,
    rownames = TRUE,
    escape = FALSE,
    extensions = c("Scroller", "Buttons"),
    options = list(
      dom = "Blfrtip",
      buttons = list(
        "copy",
        list(
          extend = "collection",
          buttons = c("excel", "pdf"),
          text = "Download"
        )
      ),
      scrollX = "600px",
      deferRender = TRUE,
      scrollY = 900,
      scroller = TRUE,
      searching = TRUE,
      columnDefs = list(list(className = "dt-center", targets = "_all"))
    ),
    class = c("compact", "stripe", "order-column", "hover")
  )

  output$map_todo_show <- renderPlot({
    n <- N()
    req(n)
    map_todo(n, size = input$nest_size, .refdate = input$refdate)
  })

  output$map_todo_pdf <- downloadHandler(
    filename = "map_todo.pdf",
    content = function(file) {
      n <- N()
      req(n)

      cairo_pdf(file = file, width = 11, height = 8.5)
      map_todo(n, size = input$nest_size, .refdate = input$refdate)
      dev.off()
    }
  )

  output$overview_show <- renderPlot({
    blank <- function(title) {
      ggplot() +
        annotate("text", x = 0, y = 0, label = title) +
        theme_void()
    }

    eggs <- tryCatch(ALL_EGGS(), error = function(e) data.table())
    if (nrow(eggs) > 0) {
      eggs[, year := factor(year(date))]
      eggs[, Date := update(min_pred_hatch_date, year = 2000) - 26 - 4]
      rdate <- as.Date(input$refdate) |> update(year = 2000)

      g1 <- ggplot(eggs, aes(x = Date, fill = year)) +
        geom_histogram(binwidth = 2, position = "dodge") +
        geom_vline(xintercept = rdate, col = "#001346", linewidth = 1.5) +
        ggtitle("First egg date") +
        xlab("") +
        ylab("") +
        scale_x_date(date_labels = "%b %d", date_breaks = "3 day") +
        theme_bw() +
        theme(
          axis.text.x = element_text(angle = 90, hjust = 1, size = 14),
          legend.position = "inside",
          legend.position.inside = c(1, 1),
          legend.justification = c("right", "top"),
          legend.background = element_rect(
            fill = alpha("white", 0.7),
            color = NA
          )
        )
    } else {
      g1 <- blank("No egg flotation data")
    }

    nests_by_observer <- DBq(
      "
      SELECT observer, COUNT(DISTINCT nest_id) N
      FROM NESTS
      WHERE nest_id IS NOT NULL
      GROUP BY observer
      "
    )

    if (nrow(nests_by_observer) > 0) {
      g2 <- ggplot(
        nests_by_observer,
        aes(x = fct_reorder(observer, -N), y = N)
      ) +
        geom_col(fill = "#ad7100", color = "black") +
        labs(x = "Observer", y = "N nests") +
        theme_minimal(base_size = 14)
    } else {
      g2 <- blank("No nest observer data")
    }

    bypass <- DBq("SELECT observer, nov FROM NESTS")
    if (nrow(bypass) > 0 && "nov" %in% names(bypass)) {
      bypass <- bypass[, .N, .(observer, nov)] |>
        dcast(observer ~ nov, value.var = "N")
      if (!"0" %in% names(bypass)) {
        bypass[, `0` := 0]
      }
      if (!"1" %in% names(bypass)) {
        bypass[, `1` := 0]
      }
      bypass[, Bypass_validation_rate := `1` / (`1` + `0`)]

      g3 <- ggplot(
        bypass,
        aes(
          x = fct_reorder(observer, -Bypass_validation_rate),
          y = Bypass_validation_rate
        )
      ) +
        geom_col(fill = "#5b016d", color = "black") +
        labs(x = "Observer", y = "Bypass validation rate") +
        scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
        theme_minimal(base_size = 14)
    } else {
      g3 <- blank("No validation flags")
    }

    nn <- NESTS(.refdate = input$refdate)
    pp <- nn[
      !is.na(min_pred_hatch_date),
      .(
        nest,
        date = as.Date(min_pred_hatch_date),
        hatching = "predicted"
      )
    ]

    oo <- nn[
      nest_state %in% c("H", "B"),
      .(
        nest,
        date = as.Date(lastDate),
        hatching = "observed"
      )
    ]

    O <- rbind(pp, oo, fill = TRUE)
    if (nrow(O) > 0) {
      g4 <- ggplot(O, aes(x = date, fill = hatching)) +
        geom_histogram(binwidth = 1, position = "dodge") +
        geom_vline(
          xintercept = as.Date(input$refdate),
          col = "#001346",
          linewidth = 1
        ) +
        ggtitle(glue(
          "Hatching: {nrow(oo)} nests hatched; {nrow(nn[nest_state %in% c('I', 'F')])} nests expected to hatch."
        )) +
        xlab("") +
        ylab("") +
        scale_x_date(date_labels = "%b %d", date_breaks = "2 day") +
        scale_fill_manual(values = c("#e76b05", "#03c9bf91")) +
        theme_bw() +
        theme(
          axis.text.x = element_text(angle = 90, hjust = 1, size = 14),
          legend.position = "inside",
          legend.position.inside = c(1, 1),
          legend.justification = c("right", "top"),
          legend.background = element_rect(
            fill = alpha("white", 0.7),
            color = NA
          )
        )
    } else {
      g4 <- blank("No hatching data")
    }

    (g1 + g4) / (g2 + g3)
  })

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
