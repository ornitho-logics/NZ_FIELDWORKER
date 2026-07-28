function(input, output, session) {
  reference_date <- reactiveVal(get_reference_date())
  pending_refdate <- reactiveVal(NULL)
  refdate_today_notice_shown <- reactiveVal(FALSE)

  same_refdate <- function(x, y) {
    identical(as.Date(x), as.Date(y))
  }

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

  observeEvent(
    reference_date(),
    {
      req(!isTRUE(refdate_today_notice_shown()))

      refdate <- as.Date(reference_date())
      req(!is.na(refdate))

      preferred_today <- as.Date(Sys.time(), tz = preferred_timezone)

      if (!same_refdate(refdate, preferred_today)) {
        refdate_today_notice_shown(TRUE)
        WarnToast(glue(
          "Reference date is {refdate}, but today for time-zone",
          "{preferred_timezone} is {preferred_today}."
        ))
      }
    },
    ignoreInit = FALSE
  )

  observeEvent(
    db_reference_date(),
    {
      refdate <- as.Date(db_reference_date())
      pending <- pending_refdate()

      if (!is.null(pending) && !same_refdate(refdate, pending)) {
        return()
      }

      if (!is.null(pending)) {
        pending_refdate(NULL)
      }

      if (!same_refdate(refdate, isolate(reference_date()))) {
        reference_date(refdate)
      }
    },
    ignoreInit = FALSE
  )

  observe({
    refdate <- reference_date()
    req(!is.na(refdate))
    updateDateInput(session, "refdate", value = refdate)
  })

  observeEvent(input$set_refdate, {
    req(input$refdate)

    refdate <- as.Date(input$refdate)
    req(!is.na(refdate))

    previous_refdate <- isolate(reference_date())

    pending_refdate(refdate)
    reference_date(refdate)

    later(
      function() {
        withReactiveDomain(session, {
          if (set_reference_date(refdate)) {
            WarnToast(glue("Reference date set to {refdate}."))
          } else {
            pending_refdate(NULL)
            reference_date(previous_refdate)
            ErrToast("Could not save the reference date.")
          }
        })
      },
      delay = 0
    )
  })

  if (isTRUE(getOption("fieldworker.debug_input", FALSE))) {
    observe({
      assign("input", reactiveValuesToList(input), envir = .GlobalEnv)
    })
  }

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

  output$overview_nests_show <- renderPlot(
    {
      try_else(
        overview_nests_graph(active_refdate()),
        fallback_ggplot,
        fail = 'overview_nests_graph() failed!'
      )
    }
  )

  output$overview_geolocator_show <- renderPlot(
    {
      try_else(
        overview_geolocator_graph(active_refdate()),
        fallback_ggplot,
        fail = 'overview_geolocator_graph() failed!'
      )
    }
  )

  output$overview_lay_date_show <- renderPlot(
    {
      try_else(
        overview_lay_date_graph(active_refdate()),
        fallback_ggplot,
        fail = 'overview_lay_date_graph() failed!'
      )
    }
  )

  output$overview_quota_show <- renderPlot(
    {
      try_else(
        overview_quota_graph(active_refdate()),
        fallback_ggplot,
        fail = 'overview_quota_graph() failed!'
      )
    }
  )

  output$new_data <- renderUI({
    entry_classes <- fifelse(
      dbtabs_entry %in% c("inspectors", "spatial_objects"),
      "btn-danger bttn-danger",
      "btn-primary bttn-primary"
    )

    startApp(
      hrefs = glue("../DataEntry/{dbtabs_entry}/"),
      labels = fifelse(
        dbtabs_entry %in% "inspectors",
        glue("{icon('user-check')} {dbtabs_entry}"),
        fifelse(
          dbtabs_entry %in% "spatial_objects",
          glue("{icon('draw-polygon')} {dbtabs_entry}"),
          glue("{icon('pencil')} {dbtabs_entry}")
        )
      ),
      classes = entry_classes
    )
  })

  output$open_gps <- renderUI({
    a(
      href = "../gpxui/",
      target = "_blank",
      rel = "noopener noreferrer",
      class = "btn btn-primary field-standalone-button",
      role = "button",
      icon("location-crosshairs"),
      "GPS upload/download"
    )
  })

  output$open_db <- renderUI({
    a(
      href = "../../../db_ui/field_db.php",
      target = "_blank",
      rel = "noopener noreferrer",
      class = "btn btn-primary field-standalone-button",
      role = "button",
      icon("database"),
      "Database interface"
    )
  })

  lapply(dbtabs_show_tables, function(tab) {
    output[[glue("{tab}_show")]] <- TABLE_show(tab, session)
  })

  lapply(dbtabs_show_views, function(tab) {
    output[[glue("{tab}_show")]] <- TABLE_show(
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

  nest_size <- debounce(
    reactive({
      req(input$nest_size)
      input$nest_size
    }),
    300
  )

  selected_nest_states <- debounce(
    reactive({
      input$nest_state
    }),
    300
  )

  output$nest_map_show <- renderLeaflet({
    try_else(
      {
        n <- N()
        req(n)
        n <- data.table(n)

        selected_states <- selected_nest_states()

        if (is.null(selected_states)) {
          selected_states <- unique(as.character(n$nest_state))
        }

        n <- n[as.character(nest_state) %in% selected_states]

        live_nest_leaflet(n, nest_size = nest_size())
      },
      fallback_leaflet,
      fail = "live_nest_leaflet() failed!"
    )
  })

  output$todo_pdf <- downloadHandler(
    filename = function() {
      download_filename("cass_nests", "pdf")
    },
    content = function(file) {
      download_with_feedback(
        session,
        "todo_pdf",
        {
          req(active_refdate())

          todo_pdf_save(file)
        }
      )
    },
    contentType = "application/pdf"
  )

  output$nest_latest_kmz <- downloadHandler(
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

  output$tables_html <- downloadHandler(
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

  output$database_copy <- downloadHandler(
    filename = function() {
      download_filename(db, "sql")
    },
    content = function(file) {
      download_with_feedback(
        session,
        "database_copy",
        mariadb_dump(file, database = db)
      )
    },
    contentType = "application/sql"
  )

  session$allowReconnect(TRUE)
}
