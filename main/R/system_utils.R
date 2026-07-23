`%||%` <- function(x, y) {
  if (is.null(x) || !length(x)) y else x
}

DBq <- function(x) {
  o <- try(db_get(x), silent = TRUE)

  if (inherits(o, "try-error")) {
    err <- as.character(attributes(o)$condition)
    if (isRunning()) {
      showNotification(str_trunc(x, 30), type = "error")
    }
    return(data.table(error = err))
  } else {
    return(data.table(o))
  }
}


DBx <- function(x, params = NULL) {
  con <- NULL
  o <- try(
    {
      con <- db_con()
      on.exit(dbDisconnect(con), add = TRUE)

      if (is.null(params)) {
        dbExecute(con, x)
      } else {
        dbExecute(con, x, params = params)
      }
    },
    silent = TRUE
  )

  if (inherits(o, "try-error")) {
    err <- as.character(attributes(o)$condition)
    if (isRunning()) {
      showNotification(
        glue("Database write failed: {str_trunc(err, 80)}"),
        type = "error"
      )
    }
    return(FALSE)
  }

  TRUE
}


get_reference_date <- function() {
  x <- DBq(
    "SELECT value FROM settings WHERE variable = 'reference_date' LIMIT 1"
  )

  if ("error" %in% names(x) || nrow(x) == 0 || is.na(x$value[1])) {
    return(NA_Date_)
  }

  as.Date(x$value[1])
}


set_reference_date <- function(refdate) {
  refdate <- as.Date(refdate)

  if (is.na(refdate)) {
    return(FALSE)
  }

  DBx(
    "
    INSERT INTO settings (variable, value)
    VALUES ('reference_date', ?)
    ON DUPLICATE KEY UPDATE
      value = VALUES(value)
    ",
    params = list(as.character(refdate))
  )
}


dbtable_is_updated <- function(tab) {
  tab <- as.character(tab)
  tab <- unique(tab[!is.na(tab) & nzchar(tab)])

  if (!length(tab)) {
    return(sample.int(.Machine$integer.max, 1))
  }

  x <- DBq(glue("CHECKSUM TABLE {glue_collapse(tab, sep = ', ')}"))

  if (!"Checksum" %in% names(x)) {
    return(sample.int(.Machine$integer.max, 1))
  }

  if (!"Table" %in% names(x)) {
    x[, Table := tab[seq_len(.N)]]
  }

  if (!nrow(x) || all(is.na(x$Checksum))) {
    return(sample.int(.Machine$integer.max, 1))
  }

  checksum <- ifelse(is.na(x$Checksum), "NA", as.character(x$Checksum))
  paste(x$`Table`, checksum, collapse = "|")
}


showTable <- function(tab, exclude = c("pk", "nov"), formatDate = TRUE) {
  tryCatch(
    {
      cc <- data.table(db_get(glue("SHOW COLUMNS FROM {tab};")))
      cc <- cc[!Field %in% exclude]

      o <- data.table(
        db_get(
          glue("SELECT {glue_collapse(cc$Field, sep = ', ')} FROM {tab};")
        )
      )

      if (formatDate && "date" %in% cc$Field) {
        o[, let(date = format(date, "%m-%d"))]
      }

      if ("comments" %in% cc$Field) {
        o[
          !is.na(comments),
          let(
            comments = glue_data(
              .SD,
              HTML(
                '<span class="custom-tooltip"
              data-tooltip="{htmlEscape(
                str_replace_all(comments, "(;|\\\\.)\\\\s|(;|\\\\.)$", "\\n"),
                attribute = TRUE)}">
              {str_trunc(comments, 10, "right")}
            </span>'
              )
            )
          ),
          by = .I
        ]
      }

      o
    },
    error = function(e) {
      ddl <- tryCatch(
        {
          x <- db_get(glue("SHOW CREATE VIEW {tab};"))
          as.character(htmlEscape(x[["Create View"]][1]))
        },
        error = function(e) NULL
      )

      if (is.null(ddl)) {
        return(data.table(error = conditionMessage(e)))
      }

      data.table(
        error = conditionMessage(e),
        ddl = ddl
      )
    }
  )
}

download_plot_pdf <- function(filename, plot, width = 11, height = 8.5) {
  downloadHandler(
    filename = filename,
    content = function(file) {
      cairo_pdf(file = file, width = width, height = height)
      on.exit(dev.off(), add = TRUE)

      p <- plot()
      if (!is.null(p)) {
        print(p)
      }
    }
  )
}


mariadb_dump <- function(file, database) {
  # mariadb-dump needs standard group [client]

  cnf <- read.ini(path.expand(Sys.getenv("DATAENTRY_CNF")))
  client <- cnf[group]
  client[[1]][c("database", "dbname")] <- NULL
  names(client) <- "client"

  client_cnf <- tempfile(fileext = ".cnf")
  on.exit(unlink(client_cnf), add = TRUE)
  write.ini(client, client_cnf)
  Sys.chmod(client_cnf, "0600")

  status <- system2(
    "mariadb-dump",
    args = c(
      glue("--defaults-extra-file={client_cnf}"),
      "--single-transaction",
      "--routines",
      "--events",
      "--triggers",
      "--databases",
      database,
      glue("--result-file={file}")
    )
  )

  if (status != 0) {
    stop(glue("mariadb-dump failed with exit status {status}."), call. = FALSE)
  }
}


try_else <- function(primary, fallback, ...) {
  tryCatch(
    primary,
    error = function(e) fallback(...)
  )
}
