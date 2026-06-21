DBq <- function(x) {
  o <- try(DataEntry::db_get(x), silent = TRUE)

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
  x <- DBq(glue("CHECKSUM TABLE {tab}"))

  if (!"Checksum" %in% names(x)) {
    return(Sys.time())
  }

  x$Checksum
}

#' x = showTable('CAPTURES')
showTable <- function(tab, exclude = c("pk", "nov"), formatDate = TRUE) {
  cc <- DBq(glue("SHOW COLUMNS FROM {tab};"))
  cc <- cc[!Field %in% exclude]

  o <- DBq(
    glue("SELECT DISTINCT {paste(cc$Field, collapse = ', ')} FROM {tab};")
  )

  if (formatDate && "date" %in% cc$Field) {
    o[, date := format(date, "%m-%d")]
  }

  if ("comments" %in% cc$Field) {
    o[
      !is.na(comments),
      comments := glue_data(
        .SD,
        HTML(
          '<span class="custom-tooltip" 
        data-tooltip="{htmltools::htmlEscape(
          str_replace_all(comments, "(;|\\\\.)\\\\s|(;|\\\\.)$", "\\n"), 
          attribute = TRUE)}">
        {str_trunc(comments, 10, "right")}
      </span>'
        )
      ),
      by = .I
    ]
  }

  o
}
