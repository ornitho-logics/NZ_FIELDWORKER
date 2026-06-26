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
      title = paste(pagetitle, year(Sys.Date())),
      image = "ICO.png"
    ),
    uiOutput("ref_date_text")
  ),

  sidebar = dashboardSidebar(
    collapsed = TRUE,
    sidebarMenu(
      id = "main", # Assigning an id here allows input$main to be set
      menuItem("Overview", tabName = "overview", icon = icon("circle-play")),
      menuItem("GPS", tabName = "gps", icon = icon("location-arrow")),
      menuItem("Enter Data", tabName = "enter_data", icon = icon("edit")),
      menuItem("Database", tabName = "database", icon = icon("database")),
      menuItem("View Data", tabName = "view_data", icon = icon("table")),
      menuItem("Nests Map", tabName = "nests_map", icon = icon("map")),
      menuItem(
        "Live Nest Map",
        tabName = "live_nest_map",
        icon = icon("broadcast-tower")
      ),
      menuItem("To-Do list", tabName = "todo_list", icon = icon("tasks")),
      menuItem("Hatching", tabName = "hatching_est", icon = icon("egg")),
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
    width = 400,
    overlay = FALSE,
    collapsed = FALSE,

    box(
      title = "Reference date" |> bttl(),
      width = 12,
      overlay = FALSE,
      collapsible = FALSE,
      dateInput(
        inputId = 'refdate',
        label = NULL,
        value = Sys.time()
      )
    ),

    box(
      title = "Map settings" |> bttl(),
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
          "Found" = "F",
          "Incubated" = "I",
          "Hatched" = "H",
          "Brood" = "B",
          "possibly Predated" = "pP",
          "possibly Deserted" = "pD",
          "Predated" = "P",
          "Deserted" = "D",
          "Not Active" = "notA",
          "Other" = "O"
        ),
        selected = c("F", "I", "H", "B", "pP", "pD", "P", "D", "notA", "O")
      )
    ),

    box(
      title = "Download" |> bttl(),
      width = 12,

      downloadBttn(
        outputId = "map_nests_pdf",
        label = "Nests",
        icon = icon("file-pdf")
      ),
      downloadBttn(
        outputId = "todo_pdf",
        label = "To-do",
        icon = icon("file-pdf")
      )
    )
  ),
  body = dashboardBody(
    includeCSS("./www/style.css"),

    tags$script(HTML(
      '
    $(function () {
      $("[data-toggle=\'popover\']").popover({ html: true });
    });
  '
    )),

    tabItems(
      # Overview tab (first tab)
      tabItem(
        tabName = "overview",
        box(
          width = 11,
          plotOutput(
            "overview_show",
            width = "80%"
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
      # View Data tab
      tabItem(
        tabName = "view_data",
        bs4Dash::tabsetPanel(
          id = "tabset",
          .list = lapply(dbtabs_view, function(i) {
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
      # Nests Map tab
      tabItem(
        tabName = "nests_map",
        fluidRow(
          box(
            width = 12,
            maximizable = TRUE,
            spinner(
              plotOutput("map_nests_show")
            )
          )
        )
      ),
      # Live Nest Map tab
      tabItem(
        tabName = "live_nest_map",
        fluidRow(
          box(
            width = 12,
            maximizable = TRUE,

            spinner(
              leafletOutput(
                outputId = "map_nest_leaflet_show",
                width = "100%",
                height = "calc(99vh - 1px)"
              )
            )
          )
        )
      ),
      # To-Do list tab
      tabItem(
        tabName = "todo_list",
        spinner(
          DT::DTOutput(outputId = "todo_list_show")
        )
      ),

      # Hatching tab
      tabItem(
        tabName = "hatching_est",

        fluidRow(
          box(
            title = 'Select flotation ',
            icon = icon("gears"),
            width = 2,
            sliderInput(
              'float_angle',
              'Angle:',
              value = 50,
              min = 14,
              max = 90,
              step = 1
            ),
            sliderInput(
              'float_height',
              'Height:',
              value = 2,
              min = 0,
              max = 6,
              step = 1
            )
          ),

          box(
            width = 8,
            spinner(
              plotOutput(outputId = "hatching_est_plot")
            )
          )
        )
      )
    )
  )
)
