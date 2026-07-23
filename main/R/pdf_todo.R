todo_pdf_prepare <- function(todo = DBq("SELECT * FROM TODO_LIST")) {
  todo_dt <- data.table(todo)
  refdate <- as.Date(todo_dt$reference_date[1])

  if ("priority" %in% names(todo_dt)) {
    todo_dt[, let(priority = as.numeric(priority))]
  } else {
    todo_dt[, let(priority = NA_real_)]
  }

  if ("days_overdue" %in% names(todo_dt)) {
    todo_dt[, let(days_overdue = as.numeric(days_overdue))]
  } else {
    todo_dt[, let(days_overdue = NA_real_)]
  }

  if ("overdue_label" %in% names(todo_dt)) {
    todo_dt[, let(overdue_label = as.character(overdue_label))]
  } else {
    todo_dt[, let(overdue_label = as.character(days_overdue))]
  }
  todo_dt[is.na(overdue_label), let(overdue_label = "")]

  todo_dt <- todo_dt[
    order(todo, -priority, -days_overdue, nest_id, na.last = TRUE)
  ]

  rows <- todo_dt[,
    .(
      Todo = todo,
      Overdue = overdue_label,
      Nest = nest_id,
      State = nest_state,
      Clutch = clutch_size,
      Brood = brood_size,
      Hatch = min_days_to_hatch,
      `Last Visit` = last_visit_days_ago,
      Male = M_mark,
      Female = F_mark,
      Notes = notes
    )
  ]

  rows <- rows[, lapply(.SD, function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    x <- gsub("[\r\n]+", " ", x)
    x
  })]

  list(
    title = glue("Cass To-Dos for {refdate}"),
    rows = rows
  )
}

todo_pdf_heading <- function(todo_name) {
  switch(
    todo_name,
    "Hiding spot photos needed" = list(
      title = "Broods to photograph",
      subtitle = "find these broods and take in-situ and tent photos"
    ),
    "Unprocessed nest" = list(
      title = "Nests to process",
      subtitle = "egg photos and/or floatation needed"
    ),
    "Untrapped parent" = list(
      title = "Nests with parents to capture or resight",
      subtitle = "band unmarked parents or determine identity with resighting"
    ),
    "nest check" = list(
      title = "Nests to check for potential hatch",
      subtitle = NULL
    ),
    "notA nest-check" = list(
      title = "Nests requiring a 'notA' closure visit",
      subtitle = NULL
    ),
    list(
      title = todo_name,
      subtitle = NULL
    )
  )
}

todo_pdf_body <- function(rows) {
  if (!nrow(rows)) {
    return("No to-do items.")
  }

  out <- character()
  table_cols <- setdiff(names(rows), "Todo")

  for (todo in unique(rows$Todo)) {
    todo_rows <- as.data.frame(rows[Todo == todo, ..table_cols])
    heading <- todo_pdf_heading(todo)

    if (!(todo %in% c("notA nest-check", "Hiding spot photos needed"))) {
      names(todo_rows)[names(todo_rows) == "Hatch"] <- "Est. Hatch"
    }

    out <- c(
      out,
      glue("## {heading$title}"),
      ""
    )

    if (!is.null(heading$subtitle)) {
      out <- c(
        out,
        glue("*{heading$subtitle}*"),
        ""
      )
    }

    out <- c(
      out,
      knitr::kable(
        todo_rows,
        format = "pipe",
        align = c(rep("c", ncol(todo_rows) - 1), "l")
      ),
      "",
      ': {tbl-colwidths="[12,7,5,6,6,8,9,11,11,25]"}',
      ""
    )
  }

  out
}

todo_pdf_qmd <- function(
  pdf,
  template = file.path("templates", "todo_pdf.qmd")
) {
  body <- todo_pdf_body(pdf$rows)
  out <- character()

  for (line in readLines(template)) {
    out <- c(
      out,
      switch(
        line,
        "{{ title }}" = glue('title: "{pdf$title}"'),
        "{{ body }}" = body,
        line
      )
    )
  }

  out
}

todo_pdf_save <- function(
  file,
  todo = DBq("SELECT * FROM TODO_LIST")
) {
  pdf <- todo_pdf_prepare(todo)
  workdir <- tempfile("todo_pdf_")
  dir.create(workdir)
  on.exit(unlink(workdir, recursive = TRUE), add = TRUE)

  qmd <- file.path(workdir, "todo.qmd")
  output <- file.path(workdir, "todo.pdf")

  writeLines(todo_pdf_qmd(pdf), qmd)
  quarto_render(
    input = qmd,
    output_format = "typst",
    output_file = basename(output),
    quarto_args = c("--output-dir", workdir),
    execute = TRUE,
    quiet = FALSE
  )

  file.copy(output, file, overwrite = TRUE)
  invisible(file)
}
