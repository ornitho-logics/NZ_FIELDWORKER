`%||%` <- function(x, y) {
  if (is.null(x) || !length(x)) y else x
}

# We need SET SESSION optimizer_switch = 'derived_merge=off' for very complex Views;

DBq <- function(x, params = NULL, derived_merge_off = FALSE) {
  o <- try(
    {
      con <- db_con()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      if (derived_merge_off) {
        DBI::dbExecute(
          con,
          "SET SESSION optimizer_switch = 'derived_merge=off'"
        )
      }

      if (is.null(params)) {
        DBI::dbGetQuery(con, x)
      } else {
        DBI::dbGetQuery(con, x, params = params)
      }
    },
    silent = TRUE
  )

  if (inherits(o, "try-error")) {
    err <- as.character(attributes(o)$condition)

    if (isRunning()) {
      showNotification(str_trunc(x, 30), type = "error")
    }

    return(data.table(error = err))
  }

  data.table(o)
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


dbview_is_updated <- function(view) {
  sources <- dbtabs_show_view_sources[[view]]

  if (is.null(sources)) {
    return(glue("{view}:unmapped"))
  }

  glue("{view}:{dbtable_is_updated(sources)}")
}


showTable <- function(tab, exclude = c("pk", "nov"), formatDate = TRUE) {
  tryCatch(
    {
      cc <- data.table(db_get(glue("SHOW COLUMNS FROM {tab};")))
      cc <- cc[!Field %in% exclude]

      o <- data.table(
        DBq(
          glue("SELECT {glue_collapse(cc$Field, sep = ', ')} FROM {tab};"),
          derived_merge_off = TRUE
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
      data.table(
        error = glue(
          "Database object '{tab}' is unavailable. ",
          "Open the database interface to inspect or repair it."
        )
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


dump_schema <- function(schema, path = tempfile(fileext = ".rds")) {
  con <- db_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  schema_sql <- DBI::dbQuoteString(con, schema)

  # Views are derived from these tables and may be too complex to materialize
  # inside a web download request. The SQL download preserves their definitions.
  tabs <- DBI::dbGetQuery(
    con,
    glue(
      "
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = {schema_sql}
        AND table_type = 'BASE TABLE'
      ORDER BY table_name
      "
    )
  )$table_name

  o <- lapply(tabs, function(tab) {
    table_sql <- DBI::dbQuoteIdentifier(
      con,
      DBI::Id(schema = schema, table = tab)
    )

    DBI::dbGetQuery(con, glue("SELECT * FROM {table_sql}"))
  })

  names(o) <- tabs

  saveRDS(o, path, compress = "xz")
  path
}


mariadb_dump_command <- function(
  configured = Sys.getenv("MARIADB_DUMP", unset = ""),
  find_program = Sys.which
) {
  candidates <- unique(c(
    configured[nzchar(configured)],
    "mariadb-dump",
    "mysqldump"
  ))
  commands <- find_program(candidates)
  commands <- unname(commands[nzchar(commands)])

  if (!length(commands)) {
    stop(
      "Neither mariadb-dump nor mysqldump is available to create the SQL backup.",
      call. = FALSE
    )
  }

  commands[[1]]
}


mariadb_dump_is_complete <- function(file, tail_bytes = 8192L) {
  if (
    !file.exists(file) ||
      is.na(file.info(file)$size) ||
      file.info(file)$size == 0
  ) {
    return(FALSE)
  }

  size <- file.info(file)$size
  con <- file(file, open = "rb")
  on.exit(close(con), add = TRUE)

  offset <- max(0, size - tail_bytes)
  seek(con, where = offset, origin = "start")
  suffix <- readBin(con, what = "raw", n = min(size, tail_bytes))

  grepl("-- Dump completed on ", rawToChar(suffix), fixed = TRUE)
}


mariadb_dump <- function(
  file,
  database,
  dump_command = mariadb_dump_command()
) {
  # mariadb-dump needs standard group [client]

  cnf <- read.ini(path.expand(Sys.getenv("DATAENTRY_CNF")))
  client <- cnf[group]
  client[[1]][c("database", "dbname")] <- NULL
  names(client) <- "client"

  client_cnf <- tempfile(fileext = ".cnf")
  on.exit(unlink(client_cnf), add = TRUE)
  write.ini(client, client_cnf)
  Sys.chmod(client_cnf, "0600")

  output <- suppressWarnings(system2(
    dump_command,
    args = c(
      glue("--defaults-extra-file={client_cnf}"),
      # Keep the base-table backup usable if a derived view is invalid.
      "--force",
      "--single-transaction",
      "--routines",
      "--events",
      "--triggers",
      "--databases",
      database,
      glue("--result-file={file}")
    ),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status") %||% 0L

  # With --force, mariadb-dump may finish a usable backup but still return 2
  # after reporting an invalid view. Its completion marker is authoritative.
  if (!mariadb_dump_is_complete(file)) {
    detail <- paste(tail(output, 3), collapse = " ")
    detail <- if (nzchar(detail)) glue(" {detail}") else ""
    stop(
      glue(
        "{basename(dump_command)} failed to create a non-empty SQL backup ",
        "(exit status {status}).{detail}"
      ),
      call. = FALSE
    )
  }

  invisible(file)
}


try_else <- function(primary, fallback, ...) {
  tryCatch(
    primary,
    error = function(e) fallback(...)
  )
}
