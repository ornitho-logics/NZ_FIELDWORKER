
bs4Dash::dashboardPage(
help = NULL,
preloader = list(
  html = spin_loaders(id = 16, color = "#7c8f8b"), 
  color = "#b8c7c5"
),
dark = FALSE,
title = paste("FIELDWORKER", year(Sys.Date())),

header = dashboardHeader(
  title = dashboardBrand(
    title = paste(pagetitle, year(Sys.Date())),
    image = "ICO.png"
  )
),

sidebar = dashboardSidebar(
  collapsed = TRUE,
  sidebarMenu(
    id = "main",
    menuItem("MAP",          tabName = "MAP", icon = icon("map")),
    menuItem("VIEW DATA<small style='color:#d00'> this season</small>"|>HTML(), 
                              tabName = "view_data", icon = icon("table")),
                              
    menuItem("VIEW DATA<small style='color:#0066d0'> all seasons </small>"|>HTML(), 
                              tabName = "view_data_all", icon = icon("table")),

    menuItem("GPS",          tabName = "gps", icon = icon("location-arrow")),
    menuItem("DATA ENTRY",   tabName = "enter_data", icon = icon("edit")),
    menuItem("DATABASE",     tabName = "database", icon = icon("database"))

  )
),

body = dashboardBody(
  

  tabItems(
    # Map Tab
    tabItem(
      tabName = "MAP",

      div(
        style = "height: 90vh; width: 100%;",  
        leafletOutput("MAP_show", width = "100%", height = "100%")
      )
    )
    ,
    
    # GPS Tab
    tabItem(
      tabName = "gps",
      uiOutput("open_gps"),
      hr(),
      includeMarkdown("./www/help/gps.md")
    ),
    
    # Enter Data Tab
    tabItem(
      tabName = "enter_data",
      uiOutput("new_data"),
      hr(),
      includeMarkdown("./www/help/enter_data.md")
    ),
    
    # Database Tab
    tabItem(
      tabName = "database",
      div(
        class = "btn-toolbar btn-group-lg",
        style = "gap: 5px;",
        uiOutput("open_db")
      ),
      hr(),
      includeMarkdown("./www/help/database.md")
    ),
    
    # View Data Tab (this season)
    tabItem(
      tabName = "view_data",
      bs4Dash::tabsetPanel(
        id = "tabset",
        .list = lapply(dbtabs_view, function(i) {
          tabPanel(
            title = paste0("[", i, "]"),
            active = FALSE,
            DT::DTOutput(outputId = paste0(i, "_show")) |>
            withSpinner()
          )
        })
      )
    ), 

    # View Data Tab (all seasons)
    tabItem(
      tabName = "view_data_all",
      bs4Dash::tabsetPanel(
        id = "tabset2",
        tabPanel(title = "ALL ADULT CAPTURES",
        DT::DTOutput(outputId =  "all_adults_show") |>withSpinner()),
        tabPanel(title = "ALL PAIRS",DT::DTOutput(outputId =  "all_pairs_show")|>withSpinner())
        
      )
      )
    




    
  )
),

controlbar = dashboardControlbar(
  uiOutput("clock"),
  code("Hard drive:"),
  uiOutput("hdd_state")
)
)
