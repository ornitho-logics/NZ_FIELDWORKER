


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

  species_opts = c("BADO", "WRYB", "SNZD", "BFDO")
  
  sites = c(
    "AR", "AU", "CH", "CL", "CR", "HC", "HR", "KK", "KP", "KT",
    "MB", "MR", "MS", "OD", "OK", "OM", "PB", "PR", "TA", "TO",
    "TP", "TR", "TS", "WA", "WN", "WS"
  )
  
  capture_status_opts = c("F", "R", "C", "D")
  
  cap_method = c("HA", "TB", "TN", "SM", "MM", "O")
  
  parents_opts = c("MF", "F", "M", "U1", "U2", "O")
  
  field_sex_opts = c("M", "M?", "F", "F?", "U")
  
  age_opts = c("A", "J", "C")
  
  yes_no_opts = c("0", "1")
  
  feather_wear = c("0", "1", "2", "3")
  
  blood_samp_opts = c("BQ", "BF", "BE")
  
  tag_type_opts = c("PTT", "GPS", "GEO")
  
  tag_action_opts = c("O", "D", "R", "S", "N")
  
  observer_opts =
    DBq("SELECT observer FROM OBSERVERS WHERE observer IS NOT NULL AND observer <> ''")[["observer"]] |>
    as.character() |>
    trimws() |>
    unique() |>
    sort()
  
  prefilled = list(
    date = format(Sys.Date(), "%Y-%m-%d"),
    species = "BADO",
    site = "CR"
  )
  
  if (length(observer_opts) == 1) {
    prefilled$observer <- observer_opts
    prefilled$observer_upload <- observer_opts
  }
  
# UI elements
  cap_frame =
    muffleUnsignedIntegerWarning(emptyFrame(
      user = user,
      host = host,
      db = db,
      pwd = pwd,
      table = tableName,
      excludeColumns = excludeColumns,
      n = n_empty_lines,
      preFilled = prefilled
    ))
  
  comments = muffleUnsignedIntegerWarning(column_comment(
    user           = user,
    host           = host,
    db             = db,
    pwd            = pwd,
    table          = tableName,
    excludeColumns = excludeColumns
  ))
  
  comments = comments[match(names(cap_frame), comments$Column), , drop = FALSE]

  uitable =
    cap_frame |>
    rhandsontable(afterGetColHeader = js_hot_tippy_header(comments, "description")) |>
    hot_cols(columnSorting = FALSE, manualColumnResize = TRUE) |>
    hot_rows(fixedRowsTop = 1) |>
    # autocompletion columns
    hot_col(col = "date", width = 95) |>
    hot_col(col = "species", type = "autocomplete", source = species_opts, strict = TRUE) |>
    hot_col(col = "site", type = "autocomplete", source = sites, strict = TRUE) |>
    hot_col(col = "capture_status", type = "autocomplete", source = capture_status_opts, strict = TRUE) |>
    hot_col(col = "capture_method", type = "autocomplete", source = cap_method, strict = TRUE) |>
    hot_col(col = "parents", type = "autocomplete", source = parents_opts, strict = TRUE) |>
    hot_col(col = "field_sex", type = "autocomplete", source = field_sex_opts, strict = TRUE) |>
    hot_col(col = "age", type = "autocomplete", source = age_opts, strict = TRUE) |>
    
    hot_col(col = "brood_patch", type = "autocomplete", source = yes_no_opts, strict = TRUE) |>
    hot_col(col = "wt_w_tag", type = "autocomplete", source = yes_no_opts, strict = TRUE) |>
    hot_col(col = "breast_samp", type = "autocomplete", source = yes_no_opts, strict = TRUE) |>
    hot_col(col = "primary_samp", type = "autocomplete", source = yes_no_opts, strict = TRUE) |>
    hot_col(col = "blood_samp", type = "autocomplete", source = blood_samp_opts, strict = TRUE) |>
    hot_col(col = "feather_wear", type = "autocomplete", source = feather_wear, strict = TRUE) |>
    
    hot_col(col = "tag_type", type = "autocomplete", source = tag_type_opts, strict = TRUE) |>
    hot_col(col = "tag_action", type = "autocomplete", source = tag_action_opts, strict = TRUE) |>
    
    hot_col(col = "mugshot_photo", type = "autocomplete", source = yes_no_opts, strict = TRUE) |>
    hot_col(col = "wing_photo", type = "autocomplete", source = yes_no_opts, strict = TRUE) |>
    hot_col(col = "chick_tent_photo", type = "autocomplete", source = yes_no_opts, strict = TRUE) |>
    hot_col(col = "chick_hide_photo", type = "autocomplete", source = yes_no_opts, strict = TRUE) |>
    hot_col(col = "falcon_upload", type = "autocomplete", source = yes_no_opts, strict = TRUE)
  
  if (length(observer_opts) > 1) {
    uitable =
      uitable |>
      hot_col(col = "observer", type = "dropdown", source = observer_opts, strict = TRUE) |>
      hot_col(col = "observer_upload", type = "dropdown", source = observer_opts, strict = TRUE)
  }
