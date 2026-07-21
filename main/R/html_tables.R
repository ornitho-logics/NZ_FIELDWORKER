html_table_sources <- function() {
  c(
    CAPTURES = "SELECT * FROM CAPTURES",
    RESIGHTINGS = "SELECT * FROM RESIGHTINGS",
    CAPTURES_ARCHIVE = "SELECT * FROM CAPTURES_ARCHIVE",
    NESTS_LATEST = "SELECT * FROM NESTS_LATEST"
  )
}


html_tables_fetch <- function(sources = html_table_sources()) {
  lapply(
    sources,
    function(sql) {
      x <- DBq(sql)

      if ("error" %in% names(x)) {
        stop(x$error[1])
      }

      data.table(x)
    }
  )
}


html_tables <- function(
  file,
  tables = html_tables_fetch(),
  title = "Cass tables"
) {
  payload <- list(
    title = unbox(title),
    generated = unbox(format(Sys.time(), "%Y-%m-%d %H:%M")),
    tables = unname(Map(html_table_payload, names(tables), tables))
  )

  json <- toJSON(
    payload,
    auto_unbox = FALSE,
    null = "null",
    na = "null"
  )
  json <- gsub("</", "<\\/", as.character(json), fixed = TRUE)

  writeLines(
    html_tables_document(json),
    con = file,
    useBytes = TRUE
  )

  invisible(file)
}


html_table_payload <- function(name, x) {
  x <- data.table(x)
  x <- x[, lapply(.SD, function(col) {
    col <- as.character(col)
    col[is.na(col)] <- ""
    col
  })]

  rows <- if (nrow(x)) {
    lapply(seq_len(nrow(x)), function(i) unname(unlist(x[i])))
  } else {
    list()
  }

  list(
    name = unbox(name),
    columns = names(x),
    nrow = unbox(nrow(x)),
    rows = rows
  )
}


html_tables_document <- function(
  json,
  template = file.path("templates", "html_offline_tables.html")
) {
  out <- character()

  for (line in readLines(template)) {
    out <- c(
      out,
      switch(
        line,
        "{{ json }}" = json,
        line
      )
    )
  }

  paste0(out, collapse = "\n")
}
