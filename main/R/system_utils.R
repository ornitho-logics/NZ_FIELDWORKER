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


mariadb_client_command <- function(
  configured = Sys.getenv("MARIADB_CLIENT", unset = "")
) {
  candidates <- c(
    configured,
    unname(Sys.which(c("mariadb", "mysql")))
  )
  candidates <- candidates[nzchar(candidates)]

  if (!length(candidates)) {
    stop(
      "Neither mariadb nor mysql is available to refresh the TODO snapshot.",
      call. = FALSE
    )
  }

  candidates[[1L]]
}


todo_refresh_sql_path <- function() {
  configured <- Sys.getenv("FIELDWORKER_REFRESH_SQL", unset = "")
  candidates <- c(
    configured,
    file.path(getwd(), "DATABASE", "refresh_todo_list_snapshot.SQL"),
    file.path(getwd(), "..", "DATABASE", "refresh_todo_list_snapshot.SQL")
  )
  candidates <- candidates[nzchar(candidates)]
  candidates <- normalizePath(candidates, mustWork = FALSE)
  candidates <- candidates[file.exists(candidates)]

  if (!length(candidates)) {
    stop(
      "Could not locate DATABASE/refresh_todo_list_snapshot.SQL.",
      call. = FALSE
    )
  }

  candidates[[1L]]
}


todo_refresh_client_cnf <- function() {
  cnf_path <- path.expand(Sys.getenv("DATAENTRY_CNF", unset = ""))

  if (!nzchar(cnf_path) || !file.exists(cnf_path)) {
    stop(
      "DATAENTRY_CNF is not configured for the TODO snapshot worker.",
      call. = FALSE
    )
  }

  cnf <- read.ini(cnf_path)
  client <- cnf[[group]]

  if (is.null(client) || !length(client)) {
    stop(
      glue("Database configuration group '{group}' is unavailable."),
      call. = FALSE
    )
  }

  # Remove the application-only database name, then wrap the section under
  # the standard [client] name expected by MariaDB command-line clients.
  client[c("database", "dbname")] <- NULL
  client <- list(client = client)

  client_cnf <- tempfile("fieldworker-todo-client-", fileext = ".cnf")
  write.ini(client, client_cnf)
  Sys.chmod(client_cnf, "0600")
  client_cnf
}


todo_snapshot_refresh_start <- function(
  refdate = get_reference_date(),
  database = db,
  client_command = mariadb_client_command(),
  sql_path = todo_refresh_sql_path()
) {
  refdate <- as.Date(refdate)

  if (is.na(refdate)) {
    stop("A valid reference date is required to refresh the TODO snapshot.", call. = FALSE)
  }

  client_cnf <- todo_refresh_client_cnf()
  job_id <- basename(tempfile("todo-refresh-"))
  status_file <- file.path(tempdir(), paste0(job_id, ".status"))
  log_file <- file.path(tempdir(), paste0(job_id, ".log"))
  script_file <- file.path(tempdir(), paste0(job_id, ".sh"))

  writeLines("queued", status_file, useBytes = TRUE)

  client <- shQuote(client_command)
  cnf <- shQuote(client_cnf)
  database_arg <- shQuote(database)
  sql <- shQuote(sql_path)
  status <- shQuote(status_file)
  log <- shQuote(log_file)
  lock_dir <- shQuote(
    file.path(tempdir(), "FIELD_2026_BADOatNZ.todo_snapshot_refresh.lock")
  )

  worker <- c(
    "#!/bin/sh",
    "set +e",
    glue("if ! mkdir {lock_dir} 2>/dev/null; then"),
    glue("  printf '%s\\n' 'busy' > {status}; exit 75;"),
    "fi",
    glue("trap \"rmdir {lock_dir} 2>/dev/null; rm -f {cnf}\" EXIT"),
    glue(
      "printf '%s\\n' 'running' > {status}"
    ),
    glue(
      "{client} --defaults-extra-file={cnf} {database_arg} ",
      "< {sql} > {log} 2>&1 &"
    ),
    "client_pid=$!",
    "while kill -0 \"$client_pid\" 2>/dev/null; do",
    glue(
      "  stage_line=$(grep 'TODO_REFRESH_STAGE|' {log} 2>/dev/null | tail -n 1)"
    ),
    "  case \"$stage_line\" in",
    "    *'TODO_REFRESH_STAGE|nest_context'*) detail='Building nest context' ;;",
    "    *'TODO_REFRESH_STAGE|parent_status'*) detail='Building parent status' ;;",
    "    *'TODO_REFRESH_STAGE|task_rows'*) detail='Building task rows' ;;",
    "    *'TODO_REFRESH_STAGE|publishing'*) detail='Publishing snapshot' ;;",
    "    *) detail='Preparing snapshot' ;;",
    "  esac",
    glue("  printf 'running|%s\\n' \"$detail\" > {status}"),
    "  sleep 1",
    "done",
    "wait \"$client_pid\"",
    "refresh_status=$?",
    glue(
      "if [ \"$refresh_status\" -eq 0 ]; then ",
      "printf '%s\\n' 'succeeded' > {status}; ",
      "else printf 'failed|%s\\n' \"$refresh_status\" > {status}; fi"
    ),
    "exit \"$refresh_status\""
  )
  writeLines(worker, script_file, useBytes = TRUE)
  Sys.chmod(script_file, "0700")

  launched <- try(
    system2("/bin/sh", script_file, stdout = FALSE, stderr = FALSE, wait = FALSE),
    silent = TRUE
  )

  if (inherits(launched, "try-error")) {
    unlink(c(client_cnf, status_file, script_file))
    stop(
      "Could not start the TODO snapshot worker.",
      call. = FALSE
    )
  }

  list(
    id = job_id,
    refdate = refdate,
    state = "queued",
    status_file = status_file,
    log_file = log_file,
    script_file = script_file,
    started_at = Sys.time()
  )
}


todo_snapshot_refresh_status <- function(job) {
  if (is.null(job)) {
    return(list(state = "idle"))
  }

  state <- "running"
  detail <- NULL

  if (file.exists(job$status_file)) {
    status_lines <- readLines(job$status_file, warn = FALSE)
    status_line <- if (length(status_lines)) {
      trimws(status_lines[[1L]])
    } else {
      "running"
    }
    fields <- strsplit(status_line, "[|]", fixed = FALSE)[[1L]]
    state <- fields[[1L]]
    if (length(fields) > 1L) {
      detail <- fields[[2L]]
    }
  }

  if (state %in% c("succeeded", "failed", "busy")) {
    unlink(job$script_file)
  }

  job$state <- state
  job$detail <- detail
  job
}


todo_snapshot_is_current <- function(refdate = get_reference_date()) {
  refdate <- as.Date(refdate)

  if (is.na(refdate)) {
    return(FALSE)
  }

  x <- DBq(
    paste(
      "SELECT COUNT(*) AS n",
      "FROM TODO_PARENT_STATUS_SNAPSHOT",
      "WHERE reference_date = ?"
    ),
    params = list(as.character(refdate)),
    derived_merge_off = TRUE
  )

  if ("error" %in% names(x) || nrow(x) == 0L || is.na(x$n[[1L]])) {
    return(FALSE)
  }

  as.numeric(x$n[[1L]]) > 0
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


rds_export_objects <- function(
  objects,
  included_views = "CAPTURES_ARCHIVE"
) {
  normalized_names <- toupper(objects$table_name)
  normalized_types <- toupper(objects$table_type)
  normalized_views <- toupper(included_views)

  missing_views <- setdiff(
    normalized_views,
    normalized_names[normalized_types == "VIEW"]
  )

  if (length(missing_views)) {
    stop(
      sprintf(
        "Required RDS export view(s) unavailable: %s.",
        paste(missing_views, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  selected <- normalized_types == "BASE TABLE" |
    (
      normalized_types == "VIEW" &
        normalized_names %in% normalized_views
    )
  export_objects <- objects[selected, "table_name", drop = FALSE]
  export_objects$export_name <- export_objects$table_name

  selected_views <- normalized_types[selected] == "VIEW"
  export_objects$export_name[selected_views] <- included_views[
    match(normalized_names[selected][selected_views], normalized_views)
  ]

  export_objects
}


dump_schema <- function(schema, path = tempfile(fileext = ".rds")) {
  con <- db_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  schema_sql <- DBI::dbQuoteString(con, schema)

  objects <- DBI::dbGetQuery(
    con,
    glue(
      "
      SELECT table_name, table_type
      FROM information_schema.tables
      WHERE table_schema = {schema_sql}
      ORDER BY table_name
      "
    )
  )

  # CAPTURES_ARCHIVE is small and safety-critical for available band marks.
  # Other derived views remain excluded from the web download request.
  export_objects <- rds_export_objects(objects)

  o <- lapply(export_objects$table_name, function(tab) {
    table_sql <- DBI::dbQuoteIdentifier(
      con,
      DBI::Id(schema = schema, table = tab)
    )

    DBI::dbGetQuery(con, glue("SELECT * FROM {table_sql}"))
  })

  names(o) <- export_objects$export_name

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
