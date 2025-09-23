
bs4Dash::dashboardPage(
  help = NULL,
  preloader = list(
    html = spin_loaders(id = 16, color = "#01125f"), 
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
      menuItem("MAP", tabName = "MAP", icon = icon("map")),
      menuItem("GPS", tabName = "gps", icon = icon("location-arrow")),
      menuItem("ENTER DATA", tabName = "enter_data", icon = icon("edit")),
      menuItem("DATABASE", tabName = "database", icon = icon("database")),
      menuItem("VIEW DATA", tabName = "view_data", icon = icon("table")),
      menuItem("NESTS OVERVIEW", tabName = "nests_overview", icon = icon("tasks"))
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
      
      # View Data Tab
      tabItem(
        tabName = "view_data",
        bs4Dash::tabsetPanel(
          id = "tabset",
          .list = lapply(dbtabs_view, function(i) {
            tabPanel(
              title = paste0("[", i, "]"),
              active = FALSE,
              DT::DTOutput(outputId = paste0(i, "_show"))
            )
          })
        )
      ),
      
      # Nests Overview Tab
      tabItem(
        tabName = "nests_overview",
        DT::DTOutput(outputId = "nests_overview")
      )
    )
  ),
  
  controlbar = dashboardControlbar(
    uiOutput("clock"),
    code("Hard drive:"),
    uiOutput("hdd_state")
  )
)
