todo_pdf_prepare <- function(todo = DBq("SELECT * FROM TODO_LIST")) {
  todo <- data.table(todo)
  refdate <- as.Date(todo$reference_date[1])

  rows <- todo[,
    .(
      Todo = todo,
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
