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

todo_pdf_escape_latex <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- gsub("[\r\n]+", " ", x)
  x <- gsub("\\\\", "<<BACKSLASH>>", x)
  x <- gsub("~", "<<TILDE>>", x, fixed = TRUE)
  x <- gsub("\\^", "<<CARET>>", x, perl = TRUE)
  x <- gsub("([#$%&_{}])", "\\\\\\1", x, perl = TRUE)
  x <- gsub("<<BACKSLASH>>", "\\\\textbackslash{}", x, fixed = TRUE)
  x <- gsub("<<TILDE>>", "\\\\textasciitilde{}", x, fixed = TRUE)
  x <- gsub("<<CARET>>", "\\\\textasciicircum{}", x, fixed = TRUE)
  x
}

todo_pdf_table_latex <- function(todo_name, x) {
  header_labels <- names(x)
  header_labels[header_labels == "Clutch"] <- "\\rotatebox[origin=c]{90}{Clutch}"
  header_labels[header_labels == "Brood"] <- "\\rotatebox[origin=c]{90}{Brood}"
  
  if (!(todo_name %in% c("notA nest-check", "Hiding spot photos needed"))) {
    header_labels[header_labels == "Hatch"] <- "Est. Hatch"
  }
  
  header <- paste(header_labels, collapse = " & ")
  body <- apply(as.matrix(x), 1, function(row) {
    paste0(paste(todo_pdf_escape_latex(row), collapse = " & "), " \\\\")
  })
  
  c(
    "\\begingroup",
    "\\setlength{\\tabcolsep}{3pt}",
    "\\renewcommand{\\arraystretch}{1.08}",
    "\\begin{longtable}{>{\\centering\\arraybackslash}p{2.0cm}>{\\centering\\arraybackslash}p{1.1cm}>{\\centering\\arraybackslash}p{0.75cm}>{\\centering\\arraybackslash}p{0.45cm}>{\\centering\\arraybackslash}p{0.45cm}>{\\centering\\arraybackslash}p{1.45cm}>{\\centering\\arraybackslash}p{1.45cm}>{\\centering\\arraybackslash}p{2.45cm}>{\\centering\\arraybackslash}p{2.45cm}>{\\RaggedRight\\arraybackslash}p{4.45cm}}",
    "\\toprule",
    paste0(header, " \\\\"),
    "\\midrule",
    "\\endfirsthead",
    "\\toprule",
    paste0(header, " \\\\"),
    "\\midrule",
    "\\endhead",
    "\\midrule",
    "\\multicolumn{10}{r}{\\footnotesize\\emph{Continued on next page}} \\\\",
    "\\endfoot",
    "\\bottomrule",
    "\\endlastfoot",
    body,
    "\\end{longtable}",
    "\\endgroup"
  )
}

todo_pdf_heading <- function(todo_name) {
  switch(
    todo_name,
    "Hiding spot photos needed" = "Broods to photograph: find these broods and take in-situ and tent photos",
    "Unprocessed nest" = "Nests to process: egg photos and floatation needed",
    "Untrapped parent" = "Nests with parents to capture or resight: band unmarked parents or determine identity with resighting",
    "nest check" = "Nests to check for potential hatch",
    "notA nest-check" = "Nests requiring a 'notA' closure visit",
    todo_name
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
    out <- c(
      out,
      glue("## {todo_pdf_heading(todo)}"),
      "",
      todo_pdf_table_latex(todo, todo_rows),
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
  
  writeLines(todo_pdf_qmd(pdf), qmd)
  quarto_render(
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
