bs4Dash::dashboardPage(
  scrollToTop = TRUE,
  dark = FALSE,
  help = NULL,
  preloader = list(
    html = waiter::spin_loaders(id = 16, color = "#1e3d24"),
    color = '#2f6fa3de'
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
    uiOutput("ref_date_text")
  ),

  sidebar = dashboardSidebar(
    collapsed = FALSE,
    width = "180px",
    sidebarMenu(
      id = "main", # Assigning an id here allows input$main to be set
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
      menuItem("Downloads", tabName = "downloads", icon = icon("download")),
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
    collapsed = FALSE,

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
        class = "btn-primary btn-sm"
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
    includeCSS("./www/style.css"),
    includeScript("./www/reference_date.js"),
    includeScript("./www/download_feedback.js"),
    includeScript("./www/live_nest_leaflet.js"),

    tabItems(
      # Intro tab
      tabItem(
        tabName = "intro",
        div(
          class = "intro-help",
          includeMarkdown("./www/help/intro.md")
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
      ),

      # Download tab
      tabItem(
        tabName = "downloads",
        box(
          title = "Download for offline use",
          width = 11,

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
            label = "Download Nest KMZ",
            icon = icon("globe"),
            size = "lg",
            block = TRUE,
            style = "material-flat",
            color = "primary"
          ),
          br(),
          downloadBttn(
            outputId = "tables_html",
            label = "Download Tables HTML",
            icon = icon("table"),
            size = "lg",
            block = TRUE,
            style = "material-flat",
            color = "primary"
          ),
          br()
        )
      )
    )
  )
)
