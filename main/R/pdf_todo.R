todo_pdf_table <- function(todo = DBq("SELECT * FROM TODO_LIST")) {
  todo <- data.table(todo)

  if ("error" %in% names(todo)) {
    stop(todo$error[1])
  }

  refdate <- todo[
    !is.na(reference_date),
    as.Date(reference_date[1])
  ]

  if (!length(refdate) || is.na(refdate)) {
    refdate <- get_reference_date()
  }

  title <- if (is.na(refdate)) {
    "Cass todo"
  } else {
    glue("Cass todo ({as.Date(refdate)})")
  }

  if (!nrow(todo)) {
    return(
      data.table(status = "No to-do items") |>
        gt::gt() |>
        gt::tab_header(
          title = gt::md(glue("**{title}**"))
        ) |>
        gt::cols_label(status = "Status")
    )
  }

  todo_order <- c(
    "nest check",
    "Untrapped parent",
    "Untrapped brood",
    "Unprocessed nest",
    "Re-process nest",
    "Hiding spot photos needed"
  )

  todo[
    ,
    todo_order := match(todo, todo_order)
  ]
  todo[
    is.na(todo_order),
    todo_order := .Machine$integer.max
  ]

  todo[
    ,
    `:=`(
      M_print = fifelse(
        is.na(M_mark) | !nzchar(as.character(M_mark)),
        "-",
        as.character(M_mark)
      ),
      F_print = fifelse(
        is.na(F_mark) | !nzchar(as.character(F_mark)),
        "-",
        as.character(F_mark)
      )
    )
  ]
  todo[, parents := paste0("M: ", M_print, "; F: ", F_print)]

  setorder(
    todo,
    todo_order,
    min_days_to_hatch,
    -last_visit_days_ago,
    nest_id,
    na.last = TRUE
  )

  todo_print <- todo[
    ,
    .(
      todo,
      nest_id,
      notes,
      nest_state,
      clutch_size,
      brood_size,
      min_days_to_hatch,
      last_visit_days_ago,
      parents
    )
  ]

  body_cols <- setdiff(names(todo_print), "todo")

  todo_print |>
    gt::gt(groupname_col = "todo") |>
    gt::tab_header(
      title = gt::md(glue("**{title}**"))
    ) |>
    gt::cols_label(
      nest_id = "Nest",
      notes = "Notes",
      nest_state = "State",
      clutch_size = "Clutch",
      brood_size = "Brood",
      min_days_to_hatch = "Days to hatch",
      last_visit_days_ago = "Last visit",
      parents = "Parents"
    ) |>
    gt::sub_missing(
      columns = body_cols,
      missing_text = ""
    ) |>
    gt::cols_align(
      align = "center",
      columns = c(
        "nest_id",
        "nest_state",
        "clutch_size",
        "brood_size",
        "min_days_to_hatch",
        "last_visit_days_ago"
      )
    ) |>
    gt::tab_options(
      table.font.size = gt::px(11),
      data_row.padding = gt::px(3),
      heading.title.font.size = gt::px(18),
      row_group.font.weight = "bold"
    ) |>
    gt::opt_row_striping()
}
