function(input, output, session) {
  reference_date <- reactiveVal(get_reference_date())
  pending_refdate <- reactiveVal(NULL)
  todo_refresh_job <- reactiveVal(NULL)
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

  overview_plot_date_limits <- reactive({
    overview_date_limits(active_refdate())
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

  observeEvent(input$refresh_todo_snapshot, {
    if (!is.null(pending_refdate())) {
      WarnToast("Wait for the reference date change to finish before refreshing the To-do snapshot.")
      return()
    }

    refdate <- get_reference_date()
    if (is.na(refdate)) {
      ErrToast("Set a valid reference date before building the To-do snapshot.")
      return()
    }

    existing <- todo_refresh_job()
    if (
      !is.null(existing) &&
        existing$state %in% c("queued", "running")
    ) {
      WarnToast("A To-do snapshot build is already running.")
      return()
    }

    job <- tryCatch(
      todo_snapshot_refresh_start(refdate = refdate),
      error = function(error) error
    )

    if (inherits(job, "error")) {
      ErrToast(conditionMessage(job))
      return()
    }

    todo_refresh_job(job)
    WarnToast(glue(
      "To-do snapshot build started for {refdate}. The current PDF remains available until the new build succeeds."
    ))
  }, ignoreInit = TRUE)

  observe({
    job <- todo_refresh_job()

    if (is.null(job) || !(job$state %in% c("queued", "running"))) {
      return()
    }

    invalidateLater(1000, session)
    updated <- tryCatch(
      todo_snapshot_refresh_status(job),
      error = function(error) {
        job$state <- "failed"
        job$detail <- conditionMessage(error)
        job
      }
    )

    if (
      !identical(updated$state, job$state) ||
        !identical(updated$detail, job$detail)
    ) {
      if (identical(updated$state, "succeeded") &&
          !todo_snapshot_is_current(updated$refdate)) {
        updated$state <- "failed"
        updated$detail <- "The build finished, but the published snapshot does not match the reference date."
      }

      todo_refresh_job(updated)

      if (identical(updated$state, "succeeded")) {
        WarnToast(glue(
          "To-do snapshot for {updated$refdate} is ready."
        ))
      } else if (updated$state %in% c("failed", "busy")) {
        ErrToast(glue(
          "To-do snapshot build {updated$state}.",
          if (!is.null(updated$detail)) glue(" Details: {updated$detail}") else ""
        ))
      }
    }
  })

  output$todo_snapshot_status <- renderUI({
    job <- todo_refresh_job()

    if (!is.null(job)) {
      if (job$state %in% c("queued", "running")) {
        stage <- if (is.null(job$detail) || !nzchar(job$detail)) {
          if (identical(job$state, "queued")) {
            "Waiting to start"
          } else {
            "Preparing snapshot"
          }
        } else {
          job$detail
        }

        return(tags$div(
          class = "todo-snapshot-progress mt-2",
          tags$div(
            class = "d-flex align-items-center small text-muted",
            tags$span(
              class = "spinner-border spinner-border-sm mr-2",
              role = "status",
              `aria-hidden` = "true"
            ),
            tags$span(
              glue(
                "{stage} for reference date {job$refdate}. ",
                "This may take several minutes."
              )
            )
          ),
          tags$div(
            class = "progress mt-2",
            style = "height: 6px;",
            role = "progressbar",
            `aria-label` = "To-do snapshot build in progress",
            `aria-valuemin` = "0",
            `aria-valuemax` = "100",
            tags$div(
              class = "progress-bar progress-bar-striped progress-bar-animated",
              style = "width: 100%;"
            )
          )
        ))
      }

      if (identical(job$state, "succeeded")) {
        return(tags$p(
          class = "small text-success mt-2",
          glue("To-do snapshot ready for {job$refdate}.")
        ))
      }

      return(tags$p(
        class = "small text-danger mt-2",
        glue("To-do snapshot build {job$state}. Please try again.")
      ))
    }

    ready <- tryCatch(
      todo_snapshot_is_current(reference_date()),
      error = function(error) FALSE
    )

    if (isTRUE(ready)) {
      tags$p(
        class = "small text-success mt-2",
        glue("To-do snapshot ready for {reference_date()}.")
      )
    } else {
      tags$p(
        class = "small text-warning mt-2",
        "Build the To-do snapshot after changing the reference date."
      )
    }
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
        overview_nests_graph(
          active_refdate(),
          overview_plot_date_limits()
        ),
        fallback_ggplot,
        fail = 'overview_nests_graph() failed!'
      )
    }
  )

  output$overview_geolocator_show <- renderPlot(
    {
      try_else(
        overview_geolocator_graph(
          active_refdate(),
          overview_plot_date_limits()
        ),
        fallback_ggplot,
        fail = 'overview_geolocator_graph() failed!'
      )
    }
  )

  output$overview_tagged_resightings_show <- renderPlot(
    {
      try_else(
        overview_tagged_resightings_graph(
          active_refdate(),
          overview_plot_date_limits()
        ),
        fallback_ggplot,
        fail = 'overview_tagged_resightings_graph() failed!'
      )
    }
  )

  output$overview_cr_combos_show <- renderPlot(
    {
      try_else(
        overview_band_combos_graph(
          active_refdate(),
          overview_plot_date_limits()
        ),
        fallback_ggplot,
        fail = 'overview_band_combos_graph() failed!'
      )
    }
  )

  output$overview_lay_date_show <- renderPlot(
    {
      try_else(
        overview_lay_date_graph(
          active_refdate(),
          overview_plot_date_limits()
        ),
        fallback_ggplot,
        fail = 'overview_lay_date_graph() failed!'
      )
    }
  )

  output$overview_hatching_forecast_show <- renderPlot(
    {
      try_else(
        overview_hatching_forecast_graph(active_refdate()),
        fallback_ggplot,
        fail = 'overview_hatching_forecast_graph() failed!'
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
      view = TRUE
    )
  })

  N <- reactivePoll(
    7000,
    session = session,
    checkFunc = function() {
      dbtable_is_updated(dbtabs_show_view_sources[["LIVE_NEST_MAP"]])
    },
    valueFunc = function() {
      list(
        nests = DBq("SELECT * FROM NESTS_LATEST"),
        broods = DBq("SELECT * FROM BROODS_LATEST")
      )
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
        source_data <- N()
        req(source_data)

        is_dbq_error <- function(x) {
          is.data.frame(x) &&
            "error" %in% names(x)
        }

        if (is_dbq_error(source_data$nests)) {
          stop("NESTS_LATEST could not be loaded.", call. = FALSE)
        }

        n <- data.table(source_data$nests)
        warning_messages <- character()

        if (is_dbq_error(source_data$broods)) {
          warning_messages <- c(
            warning_messages,
            "Brood layer unavailable; hatched and mobile brood markers may be missing."
          )
          broods <- data.table()
        } else {
          broods <- data.table(source_data$broods)
        }

        map_data <- .prepare_live_nest_map_data(n, broods)

        missing_negative_coords <- map_data[
          is_negative_brood & (is.na(lat) | is.na(lon))
        ]
        if (nrow(missing_negative_coords)) {
          warning_messages <- c(
            warning_messages,
            "Some mobile brood markers were omitted because no valid GPS location was available."
          )
        }
        broods_warning <- paste(warning_messages, collapse = " ")
        if (!nzchar(broods_warning)) {
          broods_warning <- NULL
        }

        selected_states <- selected_nest_states()

        if (is.null(selected_states)) {
          selected_states <- unique(as.character(map_data$map_category))
        }

        selected_states[selected_states == "H"] <- "brood"
        map_data <- map_data[as.character(map_category) %in% selected_states]

        live_nest_leaflet(
          map_data,
          nest_size = nest_size(),
          map_data_prepared = TRUE,
          broods_warning = broods_warning
        )
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
          req(todo_snapshot_is_current(active_refdate()))

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

  output$database_rds <- downloadHandler(
    filename = function() {
      download_filename(db, "rds")
    },
    content = function(file) {
      download_with_feedback(
        session,
        "database_rds",
        dump_schema(db, path = file)
      )
    },
    contentType = "application/octet-stream"
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
