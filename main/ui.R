bs4Dash::dashboardPage(
  scrollToTop = TRUE,
  dark = NULL,
  freshTheme = fieldworker_theme,
  fullscreen = TRUE,
  help = NULL,
  preloader = list(
    html = waiter::spin_loaders(id = 16, color = "#2f6fa3"),
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
      HR(),
      menuItem(
        text = "",
        icon = icon("github", style = "color: gray;"),
        href = "https://github.com/mpio-be/NZ_FIELDWORKER"
      ),
      menuItem(
        text = "",
        icon = icon("at", style = "color: gray;"),
        href = "mailto:mihai.valcu@bi.mpg.de?subject=Complain"
      )
    )
  ),

  controlbar = dashboardControlbar(
    width = 280,
    overlay = FALSE,
    collapsed = TRUE,
    skin = "light",

    box(
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

    box(
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
        box(
          title = "Install and downloads",
          width = 11,

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
          downloadBttn(
            outputId = "todo_pdf",
            label = "Download To-do PDF",
            icon = icon("file-pdf"),
            size = "lg",
            block = TRUE,
            style = "material-flat",
            color = "primary"
          ),
          br(),
          downloadBttn(
            outputId = "nest_latest_kmz",
            label = "Download Offline Nest KMZ",
            icon = icon("globe"),
            size = "lg",
            block = TRUE,
            style = "material-flat",
            color = "primary"
          ),
          br(),
          downloadBttn(
            outputId = "tables_html",
            label = "Download Offline Interactive Tables",
            icon = icon("table"),
            size = "lg",
            block = TRUE,
            style = "material-flat",
            color = "primary"
          ),
          br()
        )
      ),

      # Intro tab
      tabItem(
        tabName = "intro",
        bs4Dash::bs4Card(
          title = "Fieldworker at a glance",
          width = 8,
          collapsible = TRUE,

          includeHTML("./www/help/intro.html")
        )
      ),

      # Overview tab
      tabItem(
        tabName = "overview",
        bs4Dash::box(
          width = 12,
          height = "50vh",
          style = "overflow: hidden;",
          plotOutput(
            "overview_show"
          )
        )
      ),

      # GPS tab
      tabItem(
        tabName = "gps",
        includeMarkdown("./www/help/gps.md"),
        uiOutput("open_gps")
      ),

      # Enter Data tab
      tabItem(
        tabName = "enter_data",
        uiOutput("new_data"),
        hr(),
        includeMarkdown("./www/help/enter_data.md")
      ),

      # DB tab
      tabItem(
        tabName = "database",
        uiOutput("open_db"),
        includeMarkdown("./www/help/database.md")
      ),

      # Show tables tab
      tabItem(
        tabName = "show_tables",
        bs4Dash::tabsetPanel(
          id = "tabset_tables",
          .list = lapply(dbtabs_show_tables, function(i) {
            tabPanel(
              title = paste0("[", i, "]"),
              active = FALSE,
              spinner(
                DT::DTOutput(outputId = paste0(i, "_show"))
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
              title = paste0("[", i, "]"),
              active = FALSE,
              spinner(
                DT::DTOutput(outputId = paste0(i, "_show"))
              )
            )
          })
        )
      ),

      # Live Nest Map tab
      tabItem(
        tabName = "nest_map",
        fluidRow(
          box(
            width = 12,
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
