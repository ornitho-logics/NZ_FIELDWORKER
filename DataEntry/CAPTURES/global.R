


#' shiny::runApp('./DataEntry/CAPTURES', launch.browser = TRUE)

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
    "beR",                  # remotes::install_github('mpio-be/beR')
    "dbo",                  # remotes::install_github('mpio-be/dbo') 
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
  tableName       = "CAPTURES"
  excludeColumns  = c("pk", "nov")
  n_empty_lines   = 10
  SERVER          = "nz_fieldworker"
  # SERVER          = "scidb_replica"
  cnf = read.config(getOption("dbo.my.cnf"))[[SERVER]]
  user = cnf$user
  host = cnf$host
  pwd  = cnf$password
  db   = cnf$database


  sites = c('MS', 'CR', 'KK', 'KT', 'MR', 'TP', 'MB', 'TS', 'OD', 'TR', 'TA', 'PR')

  cap_method = c('HA', 'TB', 'TN', 'SM', 'MM', 'O')


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
      user = user,
      host = host,
      db = db,
      pwd = pwd,
      table = tableName,
      excludeColumns = excludeColumns,
      n = n_empty_lines,
      preFilled = list(
        date = format(Sys.Date(), "%Y-%m-%d"),
        species = "BADO"
      )
    ) |>
    rhandsontable(afterGetColHeader = js_hot_tippy_header(comments, "description")) |>
    hot_cols(columnSorting = FALSE, manualColumnResize = TRUE) |>
    hot_rows(fixedRowsTop = 1) |>
    # autocompletion columns
    hot_col(col = "site", type = "autocomplete", source = sites,strict = TRUE)|>
    hot_col(col = "capture_method", type = "autocomplete", source = cap_method,strict = TRUE)