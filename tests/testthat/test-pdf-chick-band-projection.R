test_that("the real PDF loader preserves canonical links and supplies chick colours", {
  # Function definitions plus fake query results only: no app globals, config,
  # database connection, SQL execution or Quarto process is loaded.
  root <- testthat::test_path("..", "..")
  env <- new.env(parent = asNamespace("data.table"))
  for (name in c("display_nest_ids.R", "pdf_todo.R", "pdf_todo_map.R")) {
    sys.source(file.path(root, "main", "R", name), env)
  }
  queries <- character()
  selected <- NULL
  env$DBq <- function(sql, ...) {
    queries <<- c(queries, sql)
    if (grepl("FROM TODO_CHICK_CAPTURE_EVENTS_INPUT AS events", sql, fixed = TRUE)) {
      return(data.table::data.table(
        nest_id = "A0001", ring = "MOCK001", age = "C", site = "CR",
        date = as.Date("2026-01-01"), LL = "B", LR = "M"
      ))
    }
    if (grepl("FROM TODO_PARENT_STATUS", sql, fixed = TRUE) ||
        grepl("FROM TODO_CHICK_CAPTURE_CONTEXT_INPUT", sql, fixed = TRUE)) {
      return(data.table::data.table())
    }
    stop("Unexpected query in isolated PDF fixture")
  }
  env$todo_pdf_prepare <- function(todo, available, broods, chicks, ...) {
    selected <<- chicks
    stop("Fixture stops before PDF generation")
  }
  expect_error(env$todo_pdf_save(
    tempfile(fileext = ".pdf"),
    todo = data.frame(reference_date = as.Date("2026-01-02")),
    available_combos = data.frame(), spatial_objects = data.frame(),
    broods_latest = data.frame(), hatch_prediction = data.frame()
  ), "Fixture stops before PDF generation", fixed = TRUE)
  query <- queries[grepl("FROM TODO_CHICK_CAPTURE_EVENTS_INPUT AS events", queries, fixed = TRUE)]
  expect_length(query, 1L)
  expect_match(query, "SELECT events.nest_id, events.ring_key AS ring", fixed = TRUE)
  expect_match(query, "captures.LL, captures.LR", fixed = TRUE)
  expect_match(query, "LEFT JOIN CAPTURES AS captures ON captures.pk = events.capture_pk", fixed = TRUE)
  expect_match(query, "AND event_date <= CAST('2026-01-02' AS DATE)", fixed = TRUE)
  expect_identical(selected$nest_id, "A0001")
  colours <- env$.todo_pdf_map_prepare_chick_bands(selected, as.Date("2026-01-02"))
  expect_identical(colours$label_fill, "#1565c0")
  expect_identical(colours$label_text, "#ffffff")
})
