


#' shiny::runApp('./DataEntry/OBSERVERS', launch.browser = TRUE, port = 1234)

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
    "beR",                   # remotes::install_github('mpio-be/beR')
    "dbo",                   # remotes::install_github('mpio-be/dbo') 
    "configr"
  ), require, character.only = TRUE, quietly = TRUE)
  tags = shiny::tags

#* FUNCTIONS
  
  muffleUnsignedIntegerWarning <- function(expr) {
    withCallingHandlers(
      expr,
      warning = function(w) {
        if (grepl("^Unsigned INTEGER in col [0-9]+ imported as numeric$", conditionMessage(w))) {
          invokeRestart("muffleWarning")
        }
      }
    )
  }

  DBq <- function(x) {
    con <- dbo::dbcon(server = SERVER, db = db)
    on.exit(DBI::dbDisconnect(con))

    # MariaDB UNSIGNED integers are safely imported as R numeric here.
    o <- muffleUnsignedIntegerWarning(DBI::dbGetQuery(con, x))
    setDT(o)
    o
  }
  
  describeTable <- function() {
    x = DBq(glue("SELECT * FROM {tableName}"))
    data.frame(Info = glue("The database table has {nrow(x)} rows."))
  }



#! PARAMETERS
  tableName       = "OBSERVERS"
  n_empty_lines   = 5
  SERVER          = "nz_fieldworker"
  cnf = read.config(getOption("dbo.my.cnf"))[[SERVER]]
  user = cnf$user
  host = cnf$host
  pwd  = cnf$password
  db   = cnf$database


  # UI elements
  obs_frame =
    muffleUnsignedIntegerWarning(emptyFrame(
      user           = user,
      host           = host,
      db             = db,
      pwd            = pwd,
      table          = tableName,
      n              = n_empty_lines
    ))

  comments = muffleUnsignedIntegerWarning(column_comment(
    user           = user,
    host           = host,
    db             = db,
    pwd            = pwd,
    table          = tableName
  ))

  comments = comments[match(names(obs_frame), comments$Column), , drop = FALSE]

  uitable =
    obs_frame |>
    rhandsontable(afterGetColHeader = js_hot_tippy_header(comments, "description")) |>
      hot_cols(columnSorting = FALSE, manualColumnResize = TRUE) |>
      hot_rows(fixedRowsTop = 1)

  if ("name" %in% names(obs_frame))
    uitable = hot_col(uitable, col = "name", width = 160)

  if ("observer" %in% names(obs_frame))
    uitable = hot_col(uitable, col = "observer", width = 75)

  if ("START" %in% names(obs_frame))
    uitable = hot_col(uitable, col = "START", width = 95)

  if ("STOP" %in% names(obs_frame))
    uitable = hot_col(uitable, col = "STOP", width = 95)

  if ("gps_id" %in% names(obs_frame))
    uitable = hot_col(uitable, col = "gps_id", width = 65)

  if ("cam_id" %in% names(obs_frame))
    uitable = hot_col(uitable, col = "cam_id", width = 85)
