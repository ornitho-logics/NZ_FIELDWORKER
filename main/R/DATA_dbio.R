
DBq <- function(x) {
  con = dbo::dbcon(server = server, db = db)
  on.exit(DBI::dbDisconnect(con))

  o <- try(DBI::dbGetQuery(con, x), silent = TRUE)

  if (inherits(o, "try-error")) {
    err <- as.character(attributes(o)$condition)
    if (shiny::isRunning()) {
      showNotification(glue("⚠ {str_trunc(x, 30)}"), type = "error")
    }
    return(data.table(error = err))
  } else {
    return(data.table(o))
  }
}


dbtable_is_updated <- function(tab) {
  DBq(glue("CHECKSUM TABLE {tab}"))$Checksum
}



dbTxtDump <- function( p = paste0(fs::path_temp(), "_dbdump"), zipfile = "dbdump.zip" ) {
  
  dir.create(p)
  
  x = DBq("show full tables where Table_Type = 'BASE TABLE'")[, 1]
  setnames(x, "tabs")

  o = x[, DBq(paste("SELECT * FROM", tabs)) |> list() |> list(), by = tabs]
  o[, path := glue_data(.SD,"{tabs}.csv")]

  o[, fwrite(V1[[1]], glue_data(.SD,"{p}/path"), yaml = TRUE), by = tabs]

  zip::zip(zipfile = zipfile, files = o$path, root = p, recurse = FALSE, include_directories = FALSE)

}