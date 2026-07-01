#TODO

prepare_todo_list <- function(x, .refdate = input$refdate) {
  #! ALL_RULES
  # "catch M", "catch F", "nest check", "hatch check" # and combinations of it

  if (nrow(x) == 0) {
    return(data.table())
  }

  o <- x[!nest_state %in% c("P", "D", "notA")]
  o[,
    last_trap := difftime(
      as.Date(.refdate),
      as.Date(trap_on_date),
      units = "days"
    ) |>
      as.numeric()
  ]
  o[, imminent_hatching := str_detect(hatch_state, "S|CC|\\bC\\b|[0-9]C")]

  # CATCH
  #! RULES
  #+ min_days_to_hatch <= 14
  #+ nest_state != 'H'
  #+ catch or caching attempt with one day break
  #+ hatching did not start: hatch_state does not contain S, C, CC

  # male
  cm <- o[
    min_days_to_hatch <= 14 & nest_state != 'H',
    .(nest, M_cap, M_nest, last_trap)
  ]
  cm[is.na(M_cap), todo_catch := "catch M"]
  cm[last_trap == 0, todo_catch := NA]
  cm[!is.na(M_nest), todo_catch := NA]
  cm <- unique(cm)

  # female
  cf <- o[
    min_days_to_hatch <= 14 & nest_state != 'H',
    .(nest, F_cap, F_nest, last_trap)
  ]
  cf[is.na(F_cap), todo_catch := "catch F"]
  cf[last_trap == 0, todo_catch := NA]
  cf[!is.na(F_nest), todo_catch := NA]
  cf <- unique(cf)

  catch <- merge(cm, cf, by = 'nest', all = TRUE)
  catch[,
    todo_catch := paste(
      c(todo_catch.x, todo_catch.y) |> na.omit(),
      collapse = ", "
    ),
    by = .I
  ]
  catch <- catch[
    !is.na(todo_catch) & nchar(todo_catch) > 0,
    .(nest, todo_catch)
  ]
  catch[todo_catch == "catch M, catch F", todo_catch := "catch any"]

  catch <- catch[!nest %in% o[imminent_hatching == TRUE]$nest]

  # NESTS CHECK
  #! RULES
  #+ if last check >=7
  #+ if nest_state = pD, pP

  nc <- o[
    lastCheck >= 7 |
      nest_state %in% c("pD", "pP"),
    .(nest, todo_check = "nest check")
  ] |>
    unique()

  # HATCH CHECK
  #+ RULES
  #+ if min_days_to_hatch <= 4
  #+ if eggs show no signs of hatch today then do not check next day but in 2 days
  #+ if not all chicks hatched (using, hatch_state, brood_size, clutch_size)

  hc <- o[
    !collected &
      min_days_to_hatch <= 4,
    .(
      nest,
      lastHandsonCheck,
      imminent_hatching,
      last_clutch,
      last_brood,
      todo_check = "hatch check"
    )
  ] |>
    unique()
  hc <- hc[
    lastHandsonCheck >= 1 |
      (imminent_hatching) |
      (last_brood > 0 & last_clutch > 0)
  ]
  hc <- hc[, .(nest, todo_check)]

  check <- merge(nc, hc, by = "nest", all = TRUE, suffixes = c("", "_hatch"))
  check[!is.na(todo_check_hatch), todo_check := todo_check_hatch]
  check <- check[
    !is.na(todo_check) & nchar(todo_check) > 0,
    .(nest, todo_check)
  ]

  # prepare final set

  out <- merge(catch, check, all = TRUE, by = "nest")

  out <- merge(out, o[, .(nest, lat, lon)], by = "nest", all = TRUE)

  os <- o[, .(
    nest,
    last_check_days_ago = lastCheck,
    last_handson_check = lastHandsonCheck,
    last_clutch,
    last_brood,
    last_state = nest_state,
    min_days_to_hatch
  )]
  out <- merge(os, out, by = "nest", all.x = TRUE)
  setcolorder(out, c("todo_catch", "todo_check"), after = "nest")

  setorder(out, todo_catch, todo_check, na.last = TRUE)
  out
}


todo_list <- function(n, .refdate = Sys.Date()) {
  x <- prepare_todo_list(n, .refdate = .refdate) |>
    data.table()

  cols <- intersect(c("lat", "lon"), names(x))

  if (length(cols)) {
    x[, (cols) := NULL]
  }

  x
}
