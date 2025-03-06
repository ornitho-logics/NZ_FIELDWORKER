


#' shiny::runApp('./DataEntry/EGGS', launch.browser =  TRUE)

#! SETTINGS
  sapply(c(
    "DataEntry",            # remotes::install_github('mpio-be/DataEntry')
    "DataEntry.validation", # remotes::install_github('mpio-be/DataEntry.validation')
    "shinyjs", 
    "shinyWidgets",
    "shinytoastr",
    "tableHTML", 
    "glue", 
    "stringr", 
    "beR",   # remotes::install_github('mpio-be/beR')
    "dbo",           # remotes::install_github('mpio-be/dbo') 
    "configr"
  ), require, character.only = TRUE, quietly = TRUE)
  tags = shiny::tags

#* FUNCTIONS
  
  DBq <- function(x) {
    con <- dbo::dbcon(server = SERVER, db = db)
    on.exit(DBI::dbDisconnect(con))

    o <- DBI::dbGetQuery(con, x)
    setDT(o)
    o
  }
  
  describeTable <- function() {
    x = DBq(glue("SELECT * FROM {tableName}"))
    data.frame(Info = glue("The database table has {nrow(x)} rows."))
  }



#! PARAMETERS
  tableName       = "EGGS"
  excludeColumns  = c("pk", "nov")
  n_empty_lines   = 20
  SERVER          = "nz_fieldworker"
  cnf = read.config(getOption("dbo.my.cnf"))[[SERVER]]
  user = cnf$user
  host = cnf$host
  pwd  = cnf$password
  db   = cnf$database


  # UI elements
  comments = column_comment(
    user           = user,
    host           = host,
    db             = db,
    pwd            = pwd,
    table          = tableName,
    excludeColumns = excludeColumns
  )

  uitable = 
    emptyFrame(   
    user           = user,
    host           = host,
    db             = db,
    pwd            = pwd,
    table          = tableName,
    excludeColumns = excludeColumns,
    n              = n_empty_lines, 
    preFilled = list(
      date = format(Sys.Date(), "%Y-%m-%d"),
      species = "BADO" 
    )
    ) |> 
    rhandsontable(afterGetColHeader = js_hot_tippy_header(comments, "description")) |>
      hot_cols(columnSorting = FALSE, manualColumnResize = TRUE) |>
      hot_rows(fixedRowsTop = 1) 