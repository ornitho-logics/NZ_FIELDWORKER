


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
  tableName       = "EGGS"
  excludeColumns  = c("pk", "nov")
  n_empty_lines   = 20
  SERVER          = "nz_fieldworker"
  cnf = read.config(getOption("dbo.my.cnf"))[[SERVER]]
  user = cnf$user
  host = cnf$host
  pwd  = cnf$password
  db   = cnf$database

  species_opts = c("BADO", "WRYB", "SNZD", "BFDO")

  egg_id_opts = 1:4

  float_location_opts = c("bottom", "suspended", "surface")

  observer_opts =
    DBq("SELECT observer FROM OBSERVERS WHERE observer IS NOT NULL AND observer <> ''")[["observer"]] |>
    as.character() |>
    trimws() |>
    unique() |>
    sort()

  prefilled = list(
    date = format(Sys.Date(), "%Y-%m-%d"),
    species = "BADO"
  )

  if (length(observer_opts) == 1) {
    prefilled$observer <- observer_opts
    prefilled$observer_upload <- observer_opts
  }

  # UI elements
  egg_frame =
    muffleUnsignedIntegerWarning(emptyFrame(
      user           = user,
      host           = host,
      db             = db,
      pwd            = pwd,
      table          = tableName,
      excludeColumns = excludeColumns,
      n              = n_empty_lines,
      preFilled      = prefilled
    ))

  comments = muffleUnsignedIntegerWarning(column_comment(
    user           = user,
    host           = host,
    db             = db,
    pwd            = pwd,
    table          = tableName,
    excludeColumns = excludeColumns
  ))

  comments = comments[match(names(egg_frame), comments$Column), , drop = FALSE]

  uitable =
    egg_frame |>
    rhandsontable(afterGetColHeader = js_hot_tippy_header(comments, "description")) |>
      hot_cols(columnSorting = FALSE, manualColumnResize = TRUE) |>
      hot_rows(fixedRowsTop = 1) |>
      hot_col(col = "date", width = 95) |>
      hot_col(col = "time_visit", width = 85) |>
      hot_col(col = "nest_id", width = 95) |>
      hot_col(col = "species", width = 95, type = "autocomplete", source = species_opts, strict = TRUE) |>
      hot_col(col = "egg_id", type = "autocomplete", source = egg_id_opts, strict = TRUE) |>
      hot_col(col = "float_location", type = "autocomplete", source = float_location_opts, strict = TRUE)

  if (length(observer_opts) > 1) {
    uitable =
      uitable |>
      hot_col(col = "observer", type = "dropdown", source = observer_opts, strict = TRUE) |>
      hot_col(col = "observer_upload", type = "dropdown", source = observer_opts, strict = TRUE)
  }
