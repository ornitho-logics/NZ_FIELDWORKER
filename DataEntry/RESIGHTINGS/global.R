


#' shiny::runApp('./DataEntry/RESIGHTINGS', launch.browser = TRUE)

#! SETTINGS
  sapply(c(
    "DataEntry", # remotes::install_github('mpio-be/DataEntry')
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
  tags <- shiny::tags

#* FUNCTIONS
  
  DBq <- function(x) {
    con <- dbo::dbcon(server = SERVER, db = db)
    on.exit(DBI::dbDisconnect(con))

    o <- DBI::dbGetQuery(con, x)
    setDT(o)
    o
  }
  
  describeTable <- function() {
    x <- DBq("SELECT UNIQUE concat(UL,LL,UR,LR) combo, pk FROM RESIGHTINGS 
              ORDER BY pk DESC")

    data.table(
      N_entries       = nrow(x),
      N_unique_combos = length(unique(x$combo)),
      last_entry      = paste(x[1, pk], collapse = ", ")
    )
  }


#! PARAMETERS
  tableName = "RESIGHTINGS"
  excludeColumns  = c("pk", "nov")
  n_empty_lines   = 10
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
    preFilled      = list(species = "BADO") 
    ) |> 
    rhandsontable(afterGetColHeader = js_hot_tippy_header(comments, "description")) |>
      hot_cols(columnSorting = FALSE, manualColumnResize = TRUE) |>
      hot_rows(fixedRowsTop = 1)       