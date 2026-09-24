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
      error = function(e) {
        stop(
          "Could not load AVAILABLE_COMBOS for the Team marks table.",
          call. = FALSE
        )
      }
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
  if (length(marks) < 30) {
    stop(
      sprintf(
        "Team marks requires 30 available combinations; only %d were returned.",
        length(marks)
      ),
      call. = FALSE
    )
  }
  marks <- head(marks, 30)

  team_marks <- as.data.table(
    matrix(marks, nrow = 3, byrow = TRUE)
  )

  setnames(team_marks, as.character(seq_len(ncol(team_marks))))
  team_marks[, Team := c("Team 1", "Team 2", "Team 3")]
  setcolorder(team_marks, c("Team", as.character(seq_len(10))))

  team_marks
}


todo_pdf_as_numeric <- function(x) {
  if (inherits(x, "integer64")) {
    if (!requireNamespace("bit64", quietly = TRUE)) {
      stop("Package {bit64} is required to format 64-bit database values.")
    }
    return(as.numeric(bit64::as.integer64(x)))
  }
  suppressWarnings(as.numeric(as.character(x)))
}


todo_pdf_prepare_nest_summary <- function(
  nests_latest,
  reference_date,
  todo = NULL,
  chick_captures = NULL
) {
  nests <- data.table(nests_latest)
  required_columns <- c(
    "nest_id",
    "nest_state",
    "min_days_to_hatch",
    "M_mark",
    "F_mark"
  )

  if (!nrow(nests) || !all(required_columns %in% names(nests))) {
    return(data.table(
      Nest = character(),
      `Est. Hatch` = character(),
      Male = character(),
      Female = character(),
      Symbol = character(),
      SymbolColor = character(),
      LabelFill = character(),
      LabelText = character()
    ))
  }

  nests <- nests[
    !toupper(trimws(as.character(nest_state))) %chin% c("NOTA", "S")
  ]
  nests[, min_days_to_hatch := todo_pdf_as_numeric(min_days_to_hatch)]
  nests[, predicted_hatch_date := as.Date(reference_date) + min_days_to_hatch]

  summary <- nests[
    !is.na(nest_id) & nzchar(trimws(as.character(nest_id))),
    .(
      Nest = trimws(as.character(nest_id)),
      `Est. Hatch` = fifelse(
        is.na(predicted_hatch_date),
        "",
        format(predicted_hatch_date, "%m-%d")
      ),
      Male = as.character(M_mark),
      Female = as.character(F_mark)
    )
  ]

  summary[, c("Male", "Female") := lapply(.SD, function(x) {
    x[is.na(x)] <- ""
    gsub("[\r\n]+", " ", x)
  }), .SDcols = c("Male", "Female")]

  todo_dt <- data.table(todo)
  check_todos <- c("Clutch check", "Unprocessed nest", "nest check")
  if (nrow(todo_dt) && all(c("nest_id", "todo") %in% names(todo_dt))) {
    parent_todos <- c("Untrapped parent", "Parent capture", "Parent resighting")
    parent_mark_columns <- c("M_mark", "F_mark")
    if (all(parent_mark_columns %in% names(todo_dt))) {
      parent_marks <- todo_dt[
        todo %chin% parent_todos &
          !is.na(nest_id) &
          nzchar(trimws(as.character(nest_id))),
        c(
          list(Nest = trimws(as.character(nest_id))),
          lapply(.SD, function(x) {
            x <- trimws(as.character(x))
            x[is.na(x) | !nzchar(x)] <- NA_character_
            x
          })
        ),
        .SDcols = parent_mark_columns
      ]

      if (nrow(parent_marks)) {
        parent_marks <- melt(
          parent_marks,
          id.vars = "Nest",
          variable.name = "sex_mark",
          value.name = "mark",
          na.rm = TRUE
        )
        parent_marks[, mark_rank := fifelse(
          grepl("\\s&\\s", mark),
          2L,
          1L
        )]
        parent_marks[, mark_length := nchar(mark)]
        setorder(parent_marks, Nest, sex_mark, -mark_rank, -mark_length, mark)
        parent_marks <- parent_marks[, .SD[1L], by = .(Nest, sex_mark)]
        parent_marks <- dcast(
          parent_marks,
          Nest ~ sex_mark,
          value.var = "mark"
        )
        setnames(
          parent_marks,
          old = intersect(parent_mark_columns, names(parent_marks)),
          new = sub("_mark$", "_todo_mark", intersect(parent_mark_columns, names(parent_marks)))
        )

        summary <- merge(summary, parent_marks, by = "Nest", all.x = TRUE, sort = FALSE)
        if ("M_todo_mark" %in% names(summary)) {
          summary[!is.na(M_todo_mark), Male := M_todo_mark]
          summary[, M_todo_mark := NULL]
        }
        if ("F_todo_mark" %in% names(summary)) {
          summary[!is.na(F_todo_mark), Female := F_todo_mark]
          summary[, F_todo_mark := NULL]
        }
      }
    }

    task_symbols <- todo_dt[,
      .(
        Symbol = if (any(todo %chin% check_todos)) "triangle" else "circle",
        SymbolColor = fcase(
          any(todo == "Parent capture"), "#d32f2f",
          any(todo == "Parent resighting"), "#1976d2",
          default = "#7b858b"
        )
      ),
      by = nest_id
    ]
    summary <- merge(
      summary,
      task_symbols,
      by.x = "Nest",
      by.y = "nest_id",
      all.x = TRUE,
      sort = FALSE
    )
  } else {
    summary[, let(Symbol = "circle", SymbolColor = "#7b858b")]
  }

  chick_bands <- .todo_pdf_map_prepare_chick_bands(
    chick_captures,
    reference_date
  )
  if (nrow(chick_bands)) {
    chick_bands <- chick_bands[, .(
      Nest = nest_id,
      LabelFill = label_fill,
      LabelText = label_text
    )]
    summary <- merge(summary, chick_bands, by = "Nest", all.x = TRUE, sort = FALSE)
  } else {
    summary[, let(LabelFill = NA_character_, LabelText = NA_character_)]
  }

  summary[is.na(Symbol), let(Symbol = "circle")]
  summary[is.na(SymbolColor), let(SymbolColor = "#7b858b")]
  setcolorder(
    summary,
    c(
      "Nest", "Est. Hatch", "Male", "Female", "Symbol", "SymbolColor",
      "LabelFill", "LabelText"
    )
  )
  summary[order(Nest)]
}


todo_pdf_prepare <- function(
  todo = DBq("SELECT * FROM TODO_LIST"),
  available_combos = NULL,
  nests_latest = NULL,
  chick_captures = NULL
) {
  todo_dt <- data.table(todo)
  refdate <- as.Date(todo_dt$reference_date[1])

  if ("priority" %in% names(todo_dt)) {
    todo_dt[, let(priority = todo_pdf_as_numeric(priority))]
  } else {
    todo_dt[, let(priority = NA_real_)]
  }

  if ("days_overdue" %in% names(todo_dt)) {
    todo_dt[, let(days_overdue = todo_pdf_as_numeric(days_overdue))]
  } else {
    todo_dt[, let(days_overdue = NA_real_)]
  }

  if ("min_days_to_hatch" %in% names(todo_dt)) {
    todo_dt[, let(min_days_to_hatch = todo_pdf_as_numeric(min_days_to_hatch))]
  } else {
    todo_dt[, let(min_days_to_hatch = NA_real_)]
  }

  if ("last_visit_days_ago" %in% names(todo_dt)) {
    todo_dt[, let(last_visit_days_ago = todo_pdf_as_numeric(last_visit_days_ago))]
  } else {
    todo_dt[, let(last_visit_days_ago = NA_real_)]
  }

  if ("geo_priority_rank" %in% names(todo_dt)) {
    todo_dt[, let(geo_priority_rank = todo_pdf_as_numeric(geo_priority_rank))]
  } else {
    todo_dt[, let(geo_priority_rank = NA_real_)]
  }

  parent_todos <- c("Parent capture", "Parent resighting")
  todo_dt[, let(
    pdf_geo_sort_group = fcase(
      todo == "Parent capture" & !is.na(geo_priority_rank), 0,
      todo == "Parent capture" & grepl("^tag ", notes), 1,
      todo == "Parent capture" & grepl("^band ", notes), 2,
      default = 3
    ),
    pdf_geo_priority = fifelse(
      todo == "Parent capture",
      geo_priority_rank,
      NA_real_
    ),
    pdf_sort_primary = fifelse(
      todo %chin% parent_todos,
      min_days_to_hatch,
      -priority
    ),
    pdf_sort_secondary = fifelse(
      todo %chin% parent_todos,
      -last_visit_days_ago,
      -days_overdue
    )
  )]

  todo_dt <- todo_dt[
    order(
      todo,
      pdf_geo_sort_group,
      pdf_geo_priority,
      pdf_sort_primary,
      pdf_sort_secondary,
      nest_id,
      na.last = TRUE
    )
  ]

  todo_dt[, let(clutch_brood = fifelse(
    is.na(clutch_size) & is.na(brood_size),
    "",
    paste0(
      fifelse(is.na(clutch_size), "", as.character(clutch_size)),
      "–",
      fifelse(is.na(brood_size), "", as.character(brood_size))
    )
  ))]

  rows <- todo_dt[,
    .(
      Todo = todo,
      Nest = nest_id,
      State = nest_state,
      `Clutch–Brood` = clutch_brood,
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
    team_marks = todo_pdf_prepare_team_marks(available_combos),
    nest_summary = todo_pdf_prepare_nest_summary(
      nests_latest,
      refdate,
      todo_dt,
      chick_captures
    )
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
      subtitle = "follow GEO note priority; capture only once nest-age and 36-hour rules allow"
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
    "    [*MM cap:* The bird was captured away from the nest using method MM. An at-nest resighting with IN or NM behaviour is needed to confirm its association. #linebreak() *Pair completion:* At nests known by Sep 24, prioritize the eligible untagged mate; at later nests, complete a pair after the first planned deployment. #linebreak() *Sex/phenology balance:* Deploy to the stated sex, or either sex, to fill the nest's lay-date stratum. #linebreak() *FO marker:* Orange-flagged AU migrant; never deploy a GEO. #linebreak() *No tag needed:* Band the stated parent only. #linebreak() *M/F w/GEO:* The confirmed male/female carries a geolocator. *Status ?:* Identity or band status is unknown.],",
    "  )",
    "]",
    "#v(0.3em)",
    "```",
    ""
  )
}

todo_pdf_nest_summary_table <- function(nest_summary, n_blocks = 3L) {
  summary <- data.table(nest_summary)
  if (!nrow(summary)) {
    return(character())
  }

  n_blocks <- min(as.integer(n_blocks), nrow(summary))
  block_sizes <- rep(nrow(summary) %/% n_blocks, n_blocks)
  remainder <- nrow(summary) %% n_blocks
  if (remainder) {
    block_sizes[seq_len(remainder)] <- block_sizes[seq_len(remainder)] + 1L
  }
  block_ends <- cumsum(block_sizes)
  block_starts <- c(1L, head(block_ends, -1L) + 1L)
  blocks <- Map(
    function(first, last) summary[first:last],
    block_starts,
    block_ends
  )
  rows_per_block <- max(block_sizes)

  max_font_size <- 8.5
  label_inset_y <- 3
  max_inset_y <- 6.2 - label_inset_y
  target_table_height <- 280
  if (rows_per_block <= 12L) {
    font_size <- max_font_size
    inset_y <- max_inset_y
  } else {
    font_size <- min(
      max_font_size * sqrt(12 / rows_per_block),
      target_table_height * 0.75 / (rows_per_block + 2)
    )
    inset_y <- max(
      0,
      (
        target_table_height - (rows_per_block + 2) * font_size
      ) / (2 * (rows_per_block + 1)) - label_inset_y
    )
  }
  font_size <- format(round(font_size, 2), trim = TRUE)
  inset_y <- format(round(inset_y, 2), trim = TRUE)

  typst_content <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    x <- gsub("\\", "\\\\", x, fixed = TRUE)
    x <- gsub("#", "\\#", x, fixed = TRUE)
    x <- gsub("[", "\\[", x, fixed = TRUE)
    x <- gsub("]", "\\]", x, fixed = TRUE)
    x <- gsub("*", "\\*", x, fixed = TRUE)
    x <- gsub("_", "\\_", x, fixed = TRUE)
    x <- gsub("$", "\\$", x, fixed = TRUE)
    x
  }

  typst_table <- function(block) {
    header_fill <- '#dfe5e7'
    stripe_fill <- '#f1f3f3'
    white_fill <- '#ffffff'
    cells <- c(
      glue('table.cell(fill: rgb("{header_fill}"))[#strong[Nest]]'),
      glue('table.cell(fill: rgb("{header_fill}"))[#strong[Est.#linebreak()Hatch]]'),
      glue('table.cell(fill: rgb("{header_fill}"))[#strong[Male]]'),
      glue('table.cell(fill: rgb("{header_fill}"))[#strong[Female]]')
    )

    for (row in seq_len(nrow(block))) {
      row_fill <- if (row %% 2L == 0L) stripe_fill else white_fill
      glyph <- if (block$Symbol[row] == "triangle") "▲" else "●"
      has_chick_label <- !is.na(block$LabelFill[row]) &&
        nzchar(block$LabelFill[row])
      nest_cell <- if (nzchar(block$Nest[row])) {
        if (has_chick_label) {
          glue(
            '#box[',
            '  #text(fill: rgb("{block$SymbolColor[row]}"))[{glyph}]',
            '  #h(1pt)',
            '  #box(',
            '    fill: rgb("{block$LabelFill[row]}"),',
            '    stroke: 0.25pt + rgb("#17242d"),',
            '    radius: 1.8pt,',
            glue('    inset: (x: 3pt, y: {label_inset_y}pt),'),
            '  )[#text(fill: rgb("{block$LabelText[row]}"))',
            '[#strong[{typst_content(block$Nest[row])}]]]',
            ']'
          )
        } else {
          glue(
            '#box[',
            '  #text(fill: rgb("{block$SymbolColor[row]}"))[{glyph}]',
            '  #h(1pt)',
            '  #strong[{typst_content(block$Nest[row])}]',
            ']'
          )
        }
      } else {
        typst_content("")
      }

      cells <- c(
        cells,
        glue(
          'table.cell(fill: rgb("{row_fill}"))',
          '[{nest_cell}]'
        ),
        glue(
          'table.cell(fill: rgb("{row_fill}"))',
          '[{typst_content(block[["Est. Hatch"]][row])}]'
        ),
        glue(
          'table.cell(fill: rgb("{row_fill}"))',
          '[{typst_content(block$Male[row])}]'
        ),
        glue(
          'table.cell(fill: rgb("{row_fill}"))',
          '[{typst_content(block$Female[row])}]'
        )
      )
    }

    c(
      "[",
      "#table(",
      "  columns: (1.1fr, 0.8fr, 1.125fr, 1.125fr),",
      "  align: (left, center, center, center),",
      glue("  inset: (x: 2.2pt, y: {inset_y}pt),"),
      '  stroke: 0.25pt + rgb("#aeb8ba"),',
      paste0("  ", paste(cells, collapse = ",\n  "), ","),
      ")",
      "]"
    )
  }

  tables <- lapply(blocks, typst_table)

  c(
    "```{=typst}",
    "#v(-0.7em)",
    glue("#set text(size: {font_size}pt)"),
    "#grid(",
    glue("  columns: ({paste(rep('1fr', n_blocks), collapse = ', ')}),"),
    "  gutter: 9pt,",
    paste0(vapply(tables, paste, "", collapse = "\n"), collapse = ",\n"),
    ")",
    "#set text(size: 9pt)",
    "```",
    ""
  )
}


todo_pdf_body <- function(
  rows,
  team_marks = NULL,
  map_file = NULL,
  nest_summary = NULL
) {
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
        ': {tbl-colwidths="[8,6,10,9,10,14,14,29]"}',
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

  if (!is.null(map_file)) {
    out <- c(
      out,
      "```{=typst}",
      "#pagebreak()",
      glue('#align(center)[#image("{map_file}", width: 100%)]'),
      "```",
      "",
      todo_pdf_nest_summary_table(nest_summary)
    )
  }

  out
}

todo_pdf_qmd <- function(
  pdf,
  map_file = NULL,
  template = file.path("templates", "todo_pdf.qmd")
) {
  body <- todo_pdf_body(
    pdf$rows,
    pdf$team_marks,
    map_file,
    pdf$nest_summary
  )
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
  available_combos = NULL,
  spatial_objects = NULL,
  nests_latest = NULL,
  chick_captures = NULL
) {
  if (is.null(nests_latest)) {
    nests_latest <- DBq("SELECT * FROM NESTS_LATEST")
  }

  workdir <- tempfile("todo_pdf_")
  dir.create(workdir)
  on.exit(unlink(workdir, recursive = TRUE), add = TRUE)

  qmd <- file.path(workdir, "todo.qmd")
  output <- file.path(workdir, "todo.pdf")
  map_file <- file.path(workdir, "todo_map.png")

  if (is.null(spatial_objects)) {
    spatial_objects <- DBq(
      "SELECT * FROM spatial_objects WHERE variable = 'study_area'"
    )
  }
  if (is.null(chick_captures)) {
    chick_captures <- DBq("
      SELECT nest_id, date, caught, age, site, LL, LR, pk
      FROM CAPTURES
      WHERE age = 'C'
        AND site = 'CR'
        AND nest_id IS NOT NULL
        AND TRIM(nest_id) NOT IN ('', 'NO_NEST')
    ")
  }
  pdf <- todo_pdf_prepare(
    todo,
    available_combos,
    nests_latest,
    chick_captures
  )

  todo_pdf_map_save(
    file = map_file,
    todo = todo,
    spatial_objects = spatial_objects,
    chick_captures = chick_captures,
    nests_latest = nests_latest
  )

  writeLines(todo_pdf_qmd(pdf, basename(map_file)), qmd)
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
