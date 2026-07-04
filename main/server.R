function(input, output, session) {
  reference_date <- reactiveVal(get_reference_date())

  db_reference_date <- reactivePoll(
    5000,
    session = session,
    checkFunc = function() {
      dbtable_is_updated("settings")
    },
    valueFunc = get_reference_date
  )

  active_refdate <- reactive({
    refdate <- reference_date()
    req(!is.na(refdate))
    refdate
  })

  observe({
    refdate <- db_reference_date()

    if (!identical(as.Date(refdate), as.Date(reference_date()))) {
      reference_date(refdate)
    }
  })

  observe({
    refdate <- reference_date()
    req(!is.na(refdate))
    updateDateInput(session, "refdate", value = refdate)
  })

  observeEvent(input$set_refdate, {
    req(input$refdate)

    refdate <- as.Date(input$refdate)

    if (set_reference_date(refdate)) {
      reference_date(refdate)
      WarnToast(glue("Reference date set to {refdate}."))
    } else {
      ErrToast("Could not save the reference date.")
    }
  })

  observe({
    on.exit(assign("input", reactiveValuesToList(input), envir = .GlobalEnv))
  })

  output$ref_date_text <- renderUI({
    refdate <- reference_date()

    if (is.na(refdate)) {
      return("Reference date: not set.")
    }

    refdate <- as.character(as.Date(refdate))

    HTML(
      glue(
        'Reference date: {refdate}
        <span class="ref-date-relative small ml-2" data-refdate="{refdate}"></span>'
      )
    )
  })

  output$overview_show <- renderPlot(
    {
      try_else(
        overview_graph(active_refdate()),
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

  lapply(dbtabs_show_tables, function(tab) {
    output[[paste0(tab, "_show")]] <- TABLE_show(tab, session)
  })

  lapply(dbtabs_show_views, function(tab) {
    output[[paste0(tab, "_show")]] <- TABLE_show(
      tab,
      session,
      watch = dbtabs_show_view_sources[[tab]] %||% tab
    )
  })

  N <- reactivePoll(
    7000,
    session = session,
    checkFunc = function() {
      dbtable_is_updated(dbtabs_show_view_sources[["NESTS_LATEST"]])
    },
    valueFunc = function() {
      DBq("SELECT * FROM NESTS_LATEST")
    }
  )

  output$nest_map_show <- renderLeaflet({
    try_else(
      {
        n <- N()
        req(n)
        n <- data.table(n)

        selected_states <- input$nest_state

        if (is.null(selected_states)) {
          selected_states <- unique(as.character(n$nest_state))
        }

        n <- n[as.character(nest_state) %in% selected_states]

        req(input$nest_size)
        live_nest_leaflet(n, nest_size = input$nest_size)
      },
      fallback_leaflet,
      fail = "live_nest_leaflet() failed!"
    )
  })

  output$todo_pdf <- download_gt_pdf(
    filename = function() {
      download_filename("cass_nests", "pdf")
    },
    table = function() {
      try_else(
        {
          req(active_refdate())

          todo_pdf_table()
        },
        fallback_gt,
        fail = "todo_pdf_table() failed!"
      )
    },
    session = session,
    output_id = "todo_pdf"
  )

  output$nest_latest_kmz <- shiny::downloadHandler(
    filename = function() {
      download_filename("cass_nests", "kmz")
    },
    content = function(file) {
      download_with_feedback(
        session,
        "nest_latest_kmz",
        {
          req(active_refdate())
          kmz_nest_latest(file)
        }
      )
    },
    contentType = "application/vnd.google-earth.kmz"
  )

  output$tables_html <- shiny::downloadHandler(
    filename = function() {
      download_filename("cass_tables", "html")
    },
    content = function(file) {
      download_with_feedback(
        session,
        "tables_html",
        {
          req(active_refdate())
          html_tables(file)
        }
      )
    },
    contentType = "text/html"
  )

  session$allowReconnect(TRUE)
}
