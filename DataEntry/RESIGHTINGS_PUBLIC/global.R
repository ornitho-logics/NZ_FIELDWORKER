


#' shiny::runApp('./DataEntry/RESIGHTINGS_PUBLIC', launch.browser = TRUE)

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
  tableName = "RESIGHTINGS_PUBLIC"
  excludeColumns  = c("pk", "nov")
  n_empty_lines   = 10
  SERVER          = "nz_fieldworker"
  cnf = read.config(getOption("dbo.my.cnf"))[[SERVER]]
  user = cnf$user
  host = cnf$host
  pwd  = cnf$password
  db   = cnf$database

  species_opts = c("BADO", "WRYB", "SNZD", "BFDO")

  sites = c(
    "AR", "AU", "CH", "CL", "CR", "HC", "HR", "KK", "KP", "KT",
    "MB", "MR", "MS", "OD", "OK", "OM", "PB", "PR", "TA", "TO",
    "TP", "TR", "TS", "WA", "WN", "WS"
  )

  sex_opts = c("M", "M?", "F", "F?", "U")

  country_opts = c("NZ", "AU", "O")

  yes_no_opts = c("0", "1")

  # UI elements
  public_frame =
    muffleUnsignedIntegerWarning(emptyFrame(
      user           = user,
      host           = host,
      db             = db,
      pwd            = pwd,
      table          = tableName,
      excludeColumns = excludeColumns,
      n              = n_empty_lines,
      preFilled      = list(species = "BADO")
    ))

  comments = muffleUnsignedIntegerWarning(column_comment(
    user           = user,
    host           = host,
    db             = db,
    pwd            = pwd,
    table          = tableName,
    excludeColumns = excludeColumns
  ))

  comments = comments[match(names(public_frame), comments$Column), , drop = FALSE]

  uitable =
    public_frame |>
    rhandsontable(afterGetColHeader = js_hot_tippy_header(comments, "description")) |>
      hot_cols(columnSorting = FALSE, manualColumnResize = TRUE) |>
      hot_rows(fixedRowsTop = 1) |>
      hot_col(col = "species", width = 95, type = "autocomplete", source = species_opts, strict = TRUE) |>
      hot_col(col = "time", width = 80) |>
      hot_col(col = "date", width = 95) |>
      hot_col(col = "sex", type = "autocomplete", source = sex_opts, strict = TRUE) |>
      hot_col(col = "num_photos", width = 85) |>
      hot_col(col = "source", width = 120) |>
      hot_col(col = "source_identifier", width = 180) |>
      hot_col(col = "country", type = "autocomplete", source = country_opts, strict = TRUE) |>
      hot_col(col = "site", type = "autocomplete", source = sites, strict = TRUE) |>
      hot_col(col = "falcon_upload", type = "autocomplete", source = yes_no_opts, strict = TRUE)
