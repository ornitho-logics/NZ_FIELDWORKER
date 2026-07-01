todo_pdf_table <- function(n, .refdate = Sys.Date()) {
  x <- todo_list(n, .refdate = .refdate)

  if (nrow(x) == 0) {
    x <- data.table(
      nest = "No to-dos",
      todo_catch = "",
      todo_check = "",
      last_check_days_ago = NA_real_,
      last_handson_check = NA_real_,
      last_clutch = NA_real_,
      last_brood = NA_real_,
      last_state = "",
      min_days_to_hatch = NA_real_
    )
  }

  x |>
    gt::gt() |>
    gt::tab_header(
      title = gt::md("**To-do list**"),
      subtitle = as.character(as.Date(.refdate))
    ) |>
    gt::cols_label(
      nest = "Nest",
      todo_catch = "Catch",
      todo_check = "Check",
      last_check_days_ago = "Last check",
      last_handson_check = "Hands-on",
      last_clutch = "Clutch",
      last_brood = "Brood",
      last_state = "State",
      min_days_to_hatch = "Days to hatch"
    ) |>
    gt::fmt_missing(
      columns = gt::everything(),
      missing_text = ""
    ) |>
    gt::fmt_number(
      columns = where(is.numeric),
      decimals = 1
    ) |>
    gt::tab_options(
      table.font.size = gt::px(12),
      heading.title.font.size = gt::px(18),
      heading.subtitle.font.size = gt::px(12),
      column_labels.font.weight = "bold",
      data_row.padding = gt::px(4),
      table.width = gt::pct(100)
    )
}
