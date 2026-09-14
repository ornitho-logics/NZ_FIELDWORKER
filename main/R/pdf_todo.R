todo_pdf_prepare_team_marks <- function(available_combos = NULL) {
  if (is.null(available_combos)) {
    available_combos <- tryCatch(
      DBq("
        SELECT mark
        FROM AVAILABLE_COMBOS
        WHERE site_code = 'CR'
        ORDER BY
          CASE
            WHEN LEFT(LL, 1) = 'Y' THEN 0
            ELSE 1
          END,
          CASE
            WHEN CONCAT(LL, LR) NOT REGEXP '[LR]' THEN 0
            WHEN CONCAT(LL, LR) REGEXP 'R' THEN 2
            WHEN CONCAT(LL, LR) REGEXP 'L' THEN 1
            ELSE 0
          END,
          LL,
          LR
      "),
      error = function(e) data.table(mark = character())
    )
  }

  combos_dt <- data.table(available_combos)
  marks <- if ("mark" %in% names(combos_dt)) {
    as.character(combos_dt$mark)
  } else {
    character()
  }

  marks <- trimws(marks)
  marks <- marks[!is.na(marks) & nzchar(marks)]
  marks <- head(marks, 30)

  if (length(marks) < 30) {
    marks <- c(marks, rep("", 30 - length(marks)))
  }

  team_marks <- as.data.table(
    matrix(marks, nrow = 3, byrow = TRUE)
  )

  setnames(team_marks, as.character(seq_len(ncol(team_marks))))
  team_marks[, Team := c("Team 1", "Team 2", "Team 3")]
  setcolorder(team_marks, c("Team", as.character(seq_len(10))))

  team_marks
}


todo_pdf_prepare <- function(
  todo = DBq("SELECT * FROM TODO_LIST"),
  available_combos = NULL
) {
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
    rows = rows,
    team_marks = todo_pdf_prepare_team_marks(available_combos)
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
    "Parent capture" = list(
      title = "Nests to capture",
      subtitle = "capture target parents once nest-age and 36-hour rules allow"
    ),
    "Parent resighting" = list(
      title = "Nests to resight",
      subtitle = "confirm parent identity or association with the nest"
    ),
    "nest check" = list(
      title = "Nests to check for potential hatch",
      subtitle = NULL
    ),
    "take scrape photos" = list(
      title = "Take scrape photos",
      subtitle = NULL
    ),
    "Clutch check" = list(
      title = "Nests to check for additional eggs",
      subtitle = "revisit to confirm whether the clutch has increased"
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

todo_pdf_note_key <- function() {
  c(
    "```{=typst}",
    "#v(-0.4em)",
    "#block(",
    "  width: 100%,",
    "  fill: rgb(\"#f4f7f7\"),",
    "  stroke: 0.45pt + rgb(\"#71858a\"),",
    "  radius: 2pt,",
    "  inset: (x: 6pt, y: 4pt),",
    ")[",
    "  #set text(size: 7.4pt)",
    "  #set par(leading: 0.35em)",
    "  *Note key* \\",
    "  #grid(",
    "    columns: (1fr, 1fr),",
    "    gutter: 9pt,",
    "    [*7d rule:* Resighting only. Capture is not allowed until at least 7 days after estimated clutch completion. #linebreak() *36hr rule:* Resighting only. Another parent cannot be captured until 08:00 on the reference day is at least 36 hours after the previous parent capture at that nest.],",
    "    [*MM cap:* The bird was captured away from the nest using method MM. An at-nest resighting with IN or NM behaviour is needed to confirm its association. #linebreak() *M/F w/GEO:* The confirmed male/female parent carries a geolocator. #linebreak() *Status ?:* That parent's identity or band status is unknown. Resighting is needed to determine whether capture is required.],",
    "  )",
    "]",
    "#v(0.3em)",
    "```",
    ""
  )
}

todo_pdf_body <- function(rows, team_marks = NULL) {
  out <- todo_pdf_note_key()
  if (!nrow(rows)) {
    out <- c(out, "No to-do items.", "")
  } else {
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
  }

  if (!is.null(team_marks) && nrow(team_marks)) {
    out <- c(
      out,
      "## Team marks",
      "",
      "*Use non-Lime 1.5x bands for the geolocator spacer on the tibia, and 2x bands on the tarsi*",
      "",
      knitr::kable(
        as.data.frame(team_marks),
        format = "pipe",
        align = rep("c", ncol(team_marks))
      ),
      "",
      ': {tbl-colwidths="[12,8,8,8,8,8,8,8,8,8,8]"}',
      ""
    )
  }

  out
}

todo_pdf_qmd <- function(
  pdf,
  template = file.path("templates", "todo_pdf.qmd")
) {
  body <- todo_pdf_body(pdf$rows, pdf$team_marks)
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
  todo = DBq("SELECT * FROM TODO_LIST"),
  available_combos = NULL
) {
  pdf <- todo_pdf_prepare(todo, available_combos)
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
