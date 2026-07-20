todo_pdf_prepare <- function(todo = DBq("SELECT * FROM TODO_LIST")) {
  todo_dt <- data.table(todo)
  refdate <- as.Date(todo_dt$reference_date[1])
  
  if ("priority" %in% names(todo_dt)) {
    todo_dt[, priority := as.numeric(priority)]
  } else {
    todo_dt[, priority := NA_real_]
  }
  
  if ("days_overdue" %in% names(todo_dt)) {
    todo_dt[, days_overdue := as.numeric(days_overdue)]
  } else {
    todo_dt[, days_overdue := NA_real_]
  }
  
  if ("overdue_label" %in% names(todo_dt)) {
    todo_dt[, overdue_label := as.character(overdue_label)]
  } else {
    todo_dt[, overdue_label := as.character(days_overdue)]
  }
  todo_dt[is.na(overdue_label), overdue_label := ""]
  
  todo_dt <- todo_dt[
    order(todo, -priority, -days_overdue, nest_id, na.last = TRUE)
  ]
  
  rows <- todo_dt[,
                  .(
                    Todo = todo,
                    Priority = priority,
                    Overdue = overdue_label,
                    Nest = nest_id,
                    State = nest_state,
                    Clutch = clutch_size,
                    Brood = brood_size,
                    Hatch = min_days_to_hatch,
                    Visit = last_visit_days_ago,
                    M = M_mark,
                    F = F_mark,
                    Notes = notes
                  )
  ]
  
  rows[,
       names(rows) := lapply(.SD, function(x) {
         x <- as.character(x)
         x[is.na(x)] <- ""
         x
       })
  ]
  
  list(
    title = glue("Cass todo ({refdate})"),
    rows = rows
  )
}


todo_pdf_r <- function(x) {
  paste(deparse(x), collapse = "\n")
}


todo_pdf_body <- function(rows) {
  if (!nrow(rows)) {
    return("No to-do items.")
  }
  
  out <- character()
  table_cols <- setdiff(names(rows), "Todo")
  
  for (todo in unique(rows$Todo)) {
    out <- c(
      out,
      glue("## {todo}"),
      "",
      "```{r}",
      glue(
        "todo_rows[todo_rows$Todo == {todo_pdf_r(todo)}, ",
        "{todo_pdf_r(table_cols)}, drop = FALSE]"
      ),
      "```",
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
        "{{ title }}" = glue("# {pdf$title}"),
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
  
  saveRDS(as.data.frame(pdf$rows), file.path(workdir, "todo_rows.rds"))
  writeLines(todo_pdf_qmd(pdf), qmd)
  quarto::quarto_render(
    input = qmd,
    output_format = "pdf",
    output_file = basename(output),
    quarto_args = c("--output-dir", workdir),
    execute = TRUE,
    quiet = FALSE
  )
  
  file.copy(output, file, overwrite = TRUE)
  invisible(file)
}