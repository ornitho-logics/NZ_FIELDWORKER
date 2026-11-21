dashboardPage(
  scrollToTop = TRUE,
  dark = NULL,
  freshTheme = fieldworker_theme,
  fullscreen = TRUE,
  help = NULL,
  preloader = list(
    html = spin_loaders(id = 16, color = "#3480be"),
    color = "#f8fafc"
  ),

  title = "FIELDWORKER",

  header = dashboardHeader(
    title = dashboardBrand(
      title = HTML(
        '
        <span style="font-family: Georgia, serif; font-size: 1em; font-weight: 700;">
          B<span style="font-size: 1.3em;">&#8857;</span>2026
        </span>
        '
      ),
      image = "ICO.png"
    ),
    uiOutput("ref_date_text"),
    skin = "light",
    status = "white"
  ),

  sidebar = dashboardSidebar(
    collapsed = TRUE,
    width = "180px",
    skin = "light",
    status = "primary",
    sidebarMenu(
      id = "main", # Assigning an id here allows input$main to be set
      menuItem(
        "Field Resightings",
        tabName = "field_resightings",
        icon = icon("magnifying-glass")
      ),
      menuItem("Downloads", tabName = "downloads", icon = icon("download")),
      menuItem("Intro", tabName = "intro", icon = icon("circle-info")),
      menuItem("Overview", tabName = "overview", icon = icon("circle-play")),
      menuItem("GPS", tabName = "gps", icon = icon("location-arrow")),
      menuItem("Enter Data", tabName = "enter_data", icon = icon("edit")),
      menuItem("Show tables", tabName = "show_tables", icon = icon("table")),
      menuItem("Data issues", tabName = "data_issues", icon = icon("bomb")),
      menuItem("Show Views", tabName = "show_views", icon = icon("eye")),
      menuItem("Database", tabName = "database", icon = icon("database")),
      menuItem(
        "Nest Map",
        tabName = "nest_map",
        icon = icon("broadcast-tower")
      ),
      menuItem(
        "Field Manual",
        tabName = "field_manual",
        icon = icon("book-open")
      ),

      hr(),

      menuItem(
        text = tags$span(id = "app_version_label", paste("Version", app_version)),
        icon = icon("circle-info", style = "color: gray;")
      )
    )
  ),

  controlbar = dashboardControlbar(
    width = 280,
    overlay = FALSE,
    collapsed = TRUE,
    skin = "light",

    bs4Dash::box(
      title = "Fieldwork datetime",
      width = 12,
      overlay = FALSE,
      collapsible = FALSE,
      tags$div(
        class = "preferred-timezone-clock",
        `data-timezone` = preferred_timezone,
        tags$div(
          class = "preferred-timezone-name",
          preferred_timezone
        ),
        tags$div(
          class = "preferred-timezone-value",
          "--"
        )
      )
    ),

    bs4Dash::box(
      title = "Reference date",
      width = 12,
      overlay = FALSE,
      collapsible = FALSE,
      dateInput(
        inputId = 'refdate',
        label = NULL,
        value = NULL
      ),
      actionButton(
        inputId = "set_refdate",
        label = "Set",
        icon = icon("check"),
        class = "btn-primary refdate-set-button"
      )
    ),

    bs4Dash::box(
      title = "Map settings",
      width = 12,
      sliderInput(
        inputId = "nest_size",
        label = "Text and symbol size:",
        min = 3,
        max = 12,
        step = 0.5,
        value = 4
      ),

      pickerInput(
        inputId = "nest_state",
        label = "State / brood:",
        multiple = TRUE,
        choices = c(
          "Scrape" = "S",
          "Found" = "F",
          "Incubated" = "I",
          "Brood" = "brood",
          "possibly Predated" = "pP",
          "possibly Deserted" = "pD",
          "Predated" = "P",
          "Deserted" = "D",
          "Not Active" = "notA",
          "Other" = "O"
        ),
        selected = c("S", "F", "I", "brood", "pP", "pD", "P", "D", "notA", "O")
      )
    )
  ),
  body = dashboardBody(
    tags$head(
      tags$link(rel = "manifest", href = "manifest.webmanifest"),
      tags$meta(name = "fieldworker-build", content = pwa_build_id),
      tags$meta(name = "theme-color", content = "#2f6fa3"),
      tags$meta(name = "mobile-web-app-capable", content = "yes"),
      tags$meta(name = "apple-mobile-web-app-capable", content = "yes"),
      tags$meta(name = "apple-mobile-web-app-title", content = "Fieldworker"),
      tags$link(rel = "apple-touch-icon", href = "icons/icon-192.png")
    ),
    includeCSS("./www/style.css"),
    includeScript("./www/reference_date.js"),
    includeScript("./www/download_feedback.js"),
    includeScript("./www/overview_boxes.js"),
    includeScript("./www/live_nest_leaflet.js"),
    includeScript("./www/field_resightings_location.js"),
    includeScript("./www/pwa_install.js"),

    tags$section(
      id = "pwa_update_notice", class = "pwa-update", hidden = TRUE,
      `aria-label` = "App update",
      tags$div(class = "pwa-update-icon", `aria-hidden` = "true", icon("download")),
      tags$div(
        class = "pwa-update-copy",
        tags$strong("A new version of Fieldworker is ready"),
        tags$p(id = "pwa_update_detail", role = "status", `aria-live` = "polite",
          "Save your work, then reload when you are ready.")
      ),
      tags$div(
        class = "pwa-update-actions",
        tags$button(id = "pwa_update", type = "button", class = "btn btn-primary",
          "Update and reload"),
        tags$button(id = "pwa_update_later", type = "button", class = "btn btn-outline-secondary",
          "Later")
      )
    ),

    tabItems(
      # Download tab
      tabItem(
        tabName = "downloads",
        bs4Dash::box(
          title = "Install and downloads",
          width = 11,
          collapsible = FALSE,

          tags$section(
            class = "pwa-panel", `aria-label` = "Install Fieldworker",
            tags$div(class = "pwa-panel-icon", `aria-hidden` = "true", icon("mobile-screen-button")),
            tags$div(
              class = "pwa-panel-content",
              tags$h3("Fieldworker, one tap away"),
              tags$p("Add Fieldworker to your home screen for quick access to maps, observations, and downloads."),
              tags$button(
                id = "install_mobile", type = "button", class = "btn btn-primary", hidden = TRUE,
                tags$span(id = "install_mobile_label", "Install Fieldworker")
              ),
              tags$p(id = "install_help", class = "pwa-install-help", role = "status", `aria-live` = "polite",
                "In Chrome, open the menu and choose Install app or Add to home screen."),
              tags$p(class = "pwa-network-note", "Live pages and downloads need a connection."),
              tags$div(
                class = "pwa-update-check",
                tags$button(id = "pwa_check_updates", type = "button",
                  class = "btn btn-link", "Check for updates"),
                tags$span(id = "pwa_update_status", role = "status", `aria-live` = "polite")
              )
            )
          ),
          tags$p(
            class = "small text-muted mb-2",
            "Downloaded files are saved by the browser or installed app. ",
            "On Android or iPhone/iPad, open the Files app and check Downloads or Recent."
          ),
          tags$p(
            id = "download_location_notice",
            class = "small font-weight-bold mb-3 d-none",
            "Download started. After it finishes, push Open or check Downloads or Recent in the Files app."
          ),
          actionButton(
            inputId = "refresh_todo_snapshot",
            label = tagList(
              icon("database"),
              "Build To-do snapshot"
            ),
            class = "btn btn-secondary btn-lg btn-block field-download-button"
          ),
          tags$p(
            id = "todo_snapshot_build_time",
            class = "small text-muted mt-2 mb-2",
            "Can take up to 20 minutes to build; a busy server may take longer. ",
            "Please do not start another build while one is running."
          ),
          uiOutput("todo_snapshot_status"),
          br(),
          downloadLink(
            outputId = "todo_pdf",
            label = tagList(icon("file-pdf"), "Download To-do PDF"),
            class = "btn btn-primary btn-lg btn-block field-download-button"
          ),
          br(),
          downloadLink(
            outputId = "nest_latest_kmz",
            label = tagList(icon("globe"), "Download Offline Nest KMZ"),
            class = "btn btn-primary btn-lg btn-block field-download-button"
          ),
          br(),
          downloadLink(
            outputId = "tables_html",
            label = tagList(
              icon("table"),
              "Download Offline Interactive Tables"
            ),
            class = "btn btn-primary btn-lg btn-block field-download-button"
          ),
          br(),
          downloadLink(
            outputId = "database_rds",
            label = tagList(icon("database"), "Download Database as RDS"),
            class = "btn btn-warning btn-lg btn-block field-download-button"
          ),
          br(),
          downloadLink(
            outputId = "database_copy",
            label = tagList(icon("database"), "Download Database Copy"),
            class = "btn btn-warning btn-lg btn-block field-download-button"
          ),
          br()
        )
      ),

      # Intro tab
      tabItem(
        tabName = "intro",
        bs4Card(
          title = "Fieldworker at a glance",
          width = 12,
          collapsible = FALSE,

          includeHTML("./www/help/intro.html")
        )
      ),

      # Overview tab
      tabItem(
        tabName = "overview",
        bs4Dash::box(
          title = tags$span(style = "color: #c62828;", "Cass: Nest-finding leaderboard"),
          width = 12,
          collapsible = TRUE,
          collapsed = TRUE,
          spinner(plotOutput("overview_nest_finders_show", height = "70vh"))
        ),
        bs4Dash::box(
          title = "Cass: Adults recaptured or resighted from the previous two years",
          width = 12,
          collapsible = TRUE,
          collapsed = TRUE,
          spinner(plotOutput("overview_recapture_cohorts_show", height = "55vh")),
          spinner(plotOutput("overview_encounter_cohorts_show", height = "55vh"))
        ),
        bs4Dash::box(
          title = "Current quotas for manipulations (Cass and elsewhere in NZ).",
          width = 12,
          collapsible = TRUE,
          collapsed = TRUE,
          height = "40vh",
          style = "overflow: hidden;",
          spinner(
            plotOutput(
              "overview_quota_show",
              height = "32vh"
            )
          )
        ),
        bs4Dash::box(
          title = "Cass: lay date phenology",
          width = 12,
          collapsible = TRUE,
          collapsed = TRUE,
          height = "50vh",
          style = "overflow: hidden;",
          spinner(
            plotOutput(
              "overview_lay_date_show"
            )
          )
        ),
        bs4Dash::box(
          title = "Cass: Hatching Forecast",
          width = 12,
          collapsible = TRUE,
          collapsed = TRUE,
          height = "50vh",
          style = "overflow: hidden;",
          spinner(
            plotOutput(
              "overview_hatching_forecast_show"
            )
          )
        ),
        bs4Dash::box(
          title = "Cass: Seasonal progression in nest discovery",
          width = 12,
          collapsible = TRUE,
          collapsed = TRUE,
          height = "50vh",
          style = "overflow: hidden;",
          spinner(
            plotOutput(
              "overview_nests_show"
            )
          )
        ),
        bs4Dash::box(
          title = "Cass: Seasonal progression in unique band combinations encountered (resighted or captured)",
          width = 12,
          collapsible = TRUE,
          collapsed = TRUE,
          height = "50vh",
          style = "overflow: hidden;",
          spinner(
            plotOutput(
              "overview_cr_combos_show"
            )
          )
        ),
        bs4Dash::box(
          title = "Cass: Seasonal progression in geolocator deployments",
          width = 12,
          collapsible = TRUE,
          collapsed = TRUE,
          height = "50vh",
          style = "overflow: hidden;",
          spinner(
            plotOutput(
              "overview_geolocator_show"
            )
          )
        ),
        bs4Dash::box(
          title = "Cass: Chick growth trends",
          width = 12,
          collapsible = TRUE,
          collapsed = TRUE,
          height = "55vh",
          style = "overflow: hidden;",
          spinner(
            plotOutput(
              "overview_chick_growth_show",
              height = "47vh"
            )
          )
        ),
        bs4Dash::box(
          title = "Cass: Resighting histories of geolocator-tagged birds",
          width = 12,
          collapsible = TRUE,
          collapsed = TRUE,
          spinner(
            plotOutput(
              "overview_tagged_resightings_show",
              height = "105vh"
            )
          )
        )
      ),

      # Field Resightings tab
      tabItem(
        tabName = "field_resightings",
        bs4Dash::box(
          title = "Field Resightings",
          width = 12,
          collapsible = FALSE,
          tags$form(
            class = "field-resightings-form",
            onsubmit = paste0(
              "Shiny.setInputValue('field_resightings_request', ",
              "{combo: document.getElementById('field_resightings_combo').value}, ",
              "{priority: 'event'}); return false;"
            ),
            tags$div(
              class = "form-group shiny-input-container",
              style = "width: 100%;",
              tags$input(
                id = "field_resightings_combo",
                type = "text",
                class = "form-control",
                placeholder = "COMBO (LLLR e.g. OYRL)",
                autocapitalize = "characters",
                autocorrect = "off",
                autocomplete = "off",
                spellcheck = "false",
                enterkeyhint = "search"
              )
            ),
            tags$button(
              id = "field_resightings_submit",
              type = "submit",
              class = "btn btn-primary btn-lg btn-block",
              icon("magnifying-glass"),
              "Search"
            )
          ),
          spinner(uiOutput("field_resightings_results"))
        )
      ),

      # GPS tab
      tabItem(
        tabName = "gps",
        uiOutput("open_gps"),
        hr(),
        includeHTML("./www/help/gps.html")
      ),

      # Enter Data tab
      tabItem(
        tabName = "enter_data",
        uiOutput("new_data"),
        hr(),
        includeHTML("./www/help/enter_data.html")
      ),

      # DB tab
      tabItem(
        tabName = "database",
        uiOutput("open_db"),
        includeHTML("./www/help/database.html")
      ),

      # Show tables tab
      tabItem(
        tabName = "show_tables",
        bs4Dash::tabsetPanel(
          id = "tabset_tables",
          .list = lapply(dbtabs_show_tables, function(i) {
            tabPanel(
              title = if (identical(i, "field_joirnal")) "Field journal" else glue("[{i}]"),
              active = FALSE,
              spinner(
                DTOutput(outputId = glue("{i}_show"))
              )
            )
          })
        )
      ),

      tabItem(
        tabName = "data_issues",
        bs4Dash::box(
          title = "Data issues",
          width = 12,
          collapsible = FALSE,
          tags$p(textOutput("data_issues_status")),
          spinner(DTOutput("data_issues_table"))
        )
      ),

      # Show views tab
      tabItem(
        tabName = "show_views",
        bs4Dash::tabsetPanel(
          id = "tabset_views",
          .list = lapply(dbtabs_show_views, function(i) {
            tabPanel(
              title = glue("[{i}]"),
              active = FALSE,
              spinner(
                DTOutput(outputId = glue("{i}_show"))
              )
            )
          })
        )
      ),

      # Live Nest Map tab
      tabItem(
        tabName = "nest_map",
        fluidRow(
          bs4Dash::box(
            width = 12,
            collapsible = FALSE,
            maximizable = TRUE,

            spinner(
              leafletOutput(
                outputId = "nest_map_show",
                width = "100%",
                height = "calc(99vh - 1px)"
              )
            )
          )
        )
      ),

      # Static, database-independent manual; styles and search stay in its frame.
      tabItem(
        tabName = "field_manual",
        tags$p(
          class = "small text-muted mb-2",
          tags$a(
            href = "field-manual/core-guide.html",
            target = "_blank",
            rel = "noopener",
            "Open Field Manual in a separate window"
          )
        ),
        tags$iframe(
          id = "field_manual_reader",
          title = "BADO Field Manual — Core Team Field Guide and Full Protocol Manual",
          src = "field-manual/core-guide.html",
          loading = "lazy",
          style = paste0(
            "width:100%;height:calc(100vh - 145px);min-height:600px;",
            "border:0;border-radius:0.85rem;background:white;"
          )
        )
      )
    )
  )
)
