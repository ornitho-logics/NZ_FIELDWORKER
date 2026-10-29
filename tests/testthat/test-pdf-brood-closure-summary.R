library(testthat)

# Load function definitions only: never source app globals or open a database.
pdf_summary_env <- new.env(parent = asNamespace("data.table"))
for (path in c(
  app_file("main", "R", "display_nest_ids.R"),
  app_file("main", "R", "pdf_todo.R")
)) {
  for (expression in parse(path)) {
    if (
      is.call(expression)
        && identical(expression[[1L]], as.name("<-"))
        && is.call(expression[[3L]])
        && identical(expression[[3L]][[1L]], as.name("function"))
    ) {
      eval(expression, envir = pdf_summary_env)
    }
  }
}
pdf_summary_env$DBq <- function(...) stop("Database access forbidden in this test")
# Band-label rendering is independent of the brood-inclusion decision.
pdf_summary_env$.todo_pdf_map_prepare_chick_bands <- function(...) {
  data.table::data.table()
}

summary_fixture <- function(ids = character()) {
  data.table::data.table(
    nest_id = ids,
    nest_state = rep(NA_character_, length(ids)),
    min_days_to_hatch = rep(NA_real_, length(ids)),
    M_mark = rep(NA_character_, length(ids)),
    F_mark = rep(NA_character_, length(ids)),
    is_negative_brood = grepl("^-", ids),
    has_hatch_evidence = rep(TRUE, length(ids)),
    discovery_date = rep(as.Date("2026-10-20"), length(ids))
  )
}

test_that("flagging guidance states the day-36 boundary and possible reopening", {
  heading <- pdf_summary_env$todo_pdf_heading("Broods to recapture for flagging")
  for (field in c("subtitle", "subtitle_typst", "subtitle_markdown")) {
    expect_match(heading[[field]], "From day 36", fixed = TRUE)
    expect_match(heading[[field]], "during ages 21-35", fixed = TRUE)
    expect_match(heading[[field]], "later live encounters can restore", fixed = TRUE)
  }
})

test_that("historical captures cannot restore authoritatively excluded broods", {
  result <- pdf_summary_env$todo_pdf_prepare_nest_summary(
    summary_fixture(),
    as.Date("2026-10-27"),
    chick_captures = data.table::data.table(nest_id = c("-A9901", "-A9902")),
    broods_authoritative = TRUE
  )
  expect_equal(nrow(result), 0L)
})

test_that("local snapshots retain the historical negative-brood fallback", {
  result <- pdf_summary_env$todo_pdf_prepare_nest_summary(
    summary_fixture(),
    as.Date("2026-10-27"),
    chick_captures = data.table::data.table(nest_id = "-A9901")
  )
  expect_equal(result$Nest, "-A9901")
})

test_that("authoritative active broods remain in the summary", {
  result <- pdf_summary_env$todo_pdf_prepare_nest_summary(
    summary_fixture("-A9903"),
    as.Date("2026-10-27"),
    chick_captures = data.table::data.table(nest_id = "-A9901"),
    broods_authoritative = TRUE
  )
  expect_equal(result$Nest, "-A9903")
})

test_that("published task and physical notA fallbacks remain available", {
  result <- pdf_summary_env$todo_pdf_prepare_nest_summary(
    summary_fixture(),
    as.Date("2026-10-27"),
    todo = data.table::data.table(
      nest_id = c("-A9904", "A9905"),
      todo = c("Parent resighting", "notA nest-check")
    ),
    broods_authoritative = TRUE
  )
  expect_setequal(result$Nest, c("-A9904", "A9905"))
  expect_equal(result[Nest == "A9905", Symbol], "notA")
})

test_that("closed positive broods stay out of the summary but notA remains mappable", {
  todo <- data.table::data.table(
    nest_id = c("A9906", "A9907"),
    todo = c("notA nest-check", "notA nest-check"),
    nest_state = c("notA", "notA"),
    min_days_to_hatch = c(NA_real_, NA_real_),
    M_mark = c(NA_character_, NA_character_),
    F_mark = c(NA_character_, NA_character_),
    lat = c(-43.1, -43.2),
    lon = c(170.1, 170.2)
  )
  closure_status <- data.table::data.table(
    brood_id = "A9906",
    reference_date = as.Date("2026-10-27"),
    is_presumed_dead = 1L,
    is_resolved = 0L
  )

  summary <- pdf_summary_env$todo_pdf_prepare_nest_summary(
    summary_fixture(),
    as.Date("2026-10-27"),
    todo = todo,
    broods_authoritative = TRUE,
    closure_status = closure_status
  )
  expect_false("A9906" %in% summary$Nest)
  expect_true("A9907" %in% summary$Nest)
  expect_true("A9906" %in% todo$nest_id)
  expect_equal(todo$todo[todo$nest_id == "A9906"], "notA nest-check")

  skip_if_not_installed("sf")
  map_env <- new.env(parent = asNamespace("data.table"))
  map_env$st_as_sf <- sf::st_as_sf
  map_env$st_transform <- sf::st_transform
  map_env$.todo_pdf_map_prepare_chick_bands <- function(...) {
    data.table::data.table(
      nest_id = character(),
      label_fill = character(),
      label_text = character()
    )
  }
  for (expression in parse(app_file("main", "R", "display_nest_ids.R"))) {
    if (
      is.call(expression)
        && identical(expression[[1L]], as.name("<-"))
        && is.call(expression[[3L]])
        && identical(expression[[3L]][[1L]], as.name("function"))
    ) {
      eval(expression, envir = map_env)
    }
  }
  for (expression in parse(app_file("main", "R", "pdf_todo_map.R"))) {
    if (
      is.call(expression)
        && identical(expression[[1L]], as.name("<-"))
        && is.call(expression[[3L]])
        && identical(expression[[3L]][[1L]], as.name("function"))
    ) {
      eval(expression, envir = map_env)
    }
  }
  mapped <- map_env$.todo_pdf_map_prepare_nests(
    todo,
    nests_latest = data.table::data.table()
  )
  expect_setequal(mapped$nest_id, c("A9906", "A9907"))
  expect_true(all(as.character(mapped$check_type) == "notA visit"))
})

test_that("the normal query path propagates authoritative brood provenance", {
  save_body <- paste(deparse(body(pdf_summary_env$todo_pdf_save)), collapse = "\n")
  prepare_body <- paste(deparse(body(pdf_summary_env$todo_pdf_prepare)), collapse = "\n")
  expect_match(save_body, "broods_authoritative <- FALSE", fixed = TRUE)
  expect_match(save_body, "SELECT * FROM TODO_BROODS_FOR_PDF", fixed = TRUE)
  expect_match(save_body, "broods_authoritative <- TRUE", fixed = TRUE)
  expect_match(save_body, "broods_authoritative = broods_authoritative", fixed = TRUE)
  expect_match(prepare_body, "broods_authoritative = broods_authoritative", fixed = TRUE)
  expect_identical(formals(pdf_summary_env$todo_pdf_prepare)$broods_authoritative, FALSE)
})

test_that("save distinguishes its authoritative query from supplied preview inputs", {
  exercise_save <- function(...) {
    env <- new.env(parent = pdf_summary_env)
    save <- pdf_summary_env$todo_pdf_save
    environment(save) <- env
    env$DBq <- function(sql, ...) {
      if (grepl("TODO_BROOD_CLOSURE_STATUS", sql, fixed = TRUE)) {
        return(data.table::data.table(
          brood_id = character(),
          reference_date = as.Date(character()),
          is_presumed_dead = integer(),
          is_resolved = integer()
        ))
      }
      data.table::data.table()
    }
    env$todo_pdf_prepare <- function(..., broods_authoritative) {
      env$observed_authority <- broods_authoritative
      stop("summary captured before rendering", call. = FALSE)
    }
    expect_error(save(
      file = "unused.pdf",
      todo = data.table::data.table(reference_date = as.Date("2026-10-27")),
      available_combos = data.table::data.table(),
      spatial_objects = data.table::data.table(),
      chick_captures = data.table::data.table(),
      chick_encounters = data.table::data.table(),
      hatch_prediction = data.table::data.table(),
      ...
    ), "summary captured before rendering", fixed = TRUE)
    env$observed_authority
  }
  expect_true(exercise_save())
  expect_false(exercise_save(nests_latest = summary_fixture()))
  expect_false(exercise_save(broods_latest = summary_fixture()))
})
