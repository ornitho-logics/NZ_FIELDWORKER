test_results <- read.csv("../tests/test-results.csv")
tests_ok <- test_results$failed[1] == 0

app_test_status <- list(
  text = glue::glue("{test_results$passed[1]} tests passed"),
  badge = glue::glue("{test_results$failed[1]} failed"),
  badge_color = if (tests_ok) "success" else "danger",
  icon = if (tests_ok) "circle-check" else "circle-xmark",
  icon_color = if (tests_ok) "#00815f" else "#d70427"
)

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

  title = glue('FIELDWORKER {ver}'),

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
      menuItem("Downloads", tabName = "downloads", icon = icon("download")),
      menuItem("Intro", tabName = "intro", icon = icon("circle-info")),
      menuItem("Overview", tabName = "overview", icon = icon("circle-play")),
      menuItem("GPS", tabName = "gps", icon = icon("location-arrow")),
      menuItem("Enter Data", tabName = "enter_data", icon = icon("edit")),
      menuItem("Show tables", tabName = "show_tables", icon = icon("table")),
      menuItem("Show Views", tabName = "show_views", icon = icon("eye")),
      menuItem("Database", tabName = "database", icon = icon("database")),
      menuItem(
        "Nest Map",
        tabName = "nest_map",
        icon = icon("broadcast-tower")
      ),

      hr(),

      menuItem(
        text = ver,
        icon = icon("code-branch", style = "color: gray;"),
        href = "https://github.com/mpio-be/NZ_FIELDWORKER"
      ),
      menuItem(
        text = app_test_status$text,
        icon = icon(
          app_test_status$icon,
          style = glue("color: {app_test_status$icon_color};")
        ),
        badgeLabel = app_test_status$badge,
        badgeColor = app_test_status$badge_color
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
        label = "Nest state:",
        multiple = TRUE,
        choices = c(
          "Scrape" = "S",
          "Found" = "F",
          "Incubated" = "I",
          "Hatched" = "H",
          "possibly Predated" = "pP",
          "possibly Deserted" = "pD",
          "Predated" = "P",
          "Deserted" = "D",
          "Not Active" = "notA",
          "Other" = "O"
        ),
        selected = c("S", "F", "I", "H", "pP", "pD", "P", "D", "notA", "O")
      )
    )
  ),
  body = dashboardBody(
    tags$head(
      tags$link(rel = "manifest", href = "manifest.webmanifest"),
      tags$meta(name = "theme-color", content = "#2f6fa3"),
      tags$meta(name = "mobile-web-app-capable", content = "yes"),
      tags$meta(name = "apple-mobile-web-app-capable", content = "yes"),
      tags$meta(name = "apple-mobile-web-app-title", content = "Fieldworker"),
      tags$link(rel = "apple-touch-icon", href = "icons/icon-192.png")
    ),
    includeCSS("./www/style.css"),
    includeScript("./www/reference_date.js"),
    includeScript("./www/download_feedback.js"),
    includeScript("./www/live_nest_leaflet.js"),
    includeScript("./www/pwa_install.js"),

    tabItems(
      # Download tab
      tabItem(
        tabName = "downloads",
        bs4Dash::box(
          title = "Install and downloads",
          width = 11,
          collapsible = FALSE,

          tags$button(
            id = "install_mobile",
            type = "button",
            class = "btn btn-success btn-lg btn-block mb-3",
            icon("mobile-alt"),
            "Install app on this device"
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
          tags$a(
            href = glue(
              "https://behavioural-ecology.orn.mpg.de/api/dump?schema={db}"
            ),
            target = "_blank",
            rel = "noopener",
            class = "btn btn-warning btn-lg btn-block",
            icon("database"),
            "Download Database as RDS"
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
          title = "Seasonal progression in nest discovery",
          width = 12,
          collapsible = TRUE,
          collapsed = FALSE,
          height = "50vh",
          style = "overflow: hidden;",
          plotOutput(
            "overview_show"
          )
        ),
        bs4Dash::box(
          title = "Seasonal progression in geolocator deployments",
          width = 12,
          collapsible = TRUE,
          collapsed = FALSE,
          height = "50vh",
          style = "overflow: hidden;",
          plotOutput(
            "overview_geolocator_show"
          )
        ),
        bs4Dash::box(
          title = "Seasonal progression in lay date",
          width = 12,
          collapsible = TRUE,
          collapsed = FALSE,
          height = "50vh",
          style = "overflow: hidden;",
          plotOutput(
            "overview_lay_date_show"
          )
        ),
        bs4Dash::box(
          title = "Current quotas for manipulations",
          width = 12,
          collapsible = TRUE,
          collapsed = FALSE,
          height = "40vh",
          style = "overflow: hidden;",
          plotOutput(
            "overview_quota_show",
            height = "32vh"
          )
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
              title = glue("[{i}]"),
              active = FALSE,
              spinner(
                DTOutput(outputId = glue("{i}_show"))
              )
            )
          })
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
      )
    )
  )
)
