# These checks source function definitions only. No app, database or real
# configuration is loaded; the worker test uses a shell-only fake SQL client.
progress_functions <- function() {
  env <- new.env(parent = baseenv())
  env$glue <- glue::glue
  sys.source(testthat::test_path("..", "..", "main", "R", "system_utils.R"), env)
  env
}

test_that("snapshot elapsed time is a clock, not a completion estimate", {
  env <- progress_functions()
  start <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  job <- list(started_at = start)
  expect_identical(env$todo_snapshot_refresh_elapsed(job, start), "Elapsed: 0 min 00 sec.")
  expect_identical(env$todo_snapshot_refresh_elapsed(job, start + 545), "Elapsed: 9 min 05 sec.")
  expect_identical(env$todo_snapshot_refresh_elapsed(job, start + 1201), "Elapsed: 20 min 01 sec.")
  expect_identical(env$todo_snapshot_refresh_elapsed(job, start - 1), "Elapsed: 0 min 00 sec.")
  expect_null(env$todo_snapshot_refresh_elapsed(list(), start))
  expect_null(env$todo_snapshot_refresh_elapsed(list(started_at = NA), start))
})

test_that("every SQL stage has an informative worker message", {
  root <- testthat::test_path("..", "..")
  sql <- readLines(file.path(root, "DATABASE", "refresh_todo_list_snapshot.SQL"))
  worker <- readLines(file.path(root, "main", "R", "system_utils.R"))
  marker_lines <- grep("^SELECT 'TODO_REFRESH_STAGE[|]", sql, value = TRUE)
  stages <- sub(".*TODO_REFRESH_STAGE[|]([^']+)'.*", "\\1", marker_lines)
  expect_length(stages, 9L)
  for (stage in stages) {
    expect_true(any(grepl(paste0("TODO_REFRESH_STAGE|", stage, "'*) detail="),
                         worker, fixed = TRUE)), info = stage)
  }
  expect_true(any(grepl("--unbuffered", worker, fixed = TRUE)))
  expect_true(any(grepl("Building parent-nest associations from resightings and captures",
                        worker, fixed = TRUE)))
  ui <- paste(readLines(file.path(root, "main", "ui.R")), collapse = "\n")
  server <- paste(readLines(file.path(root, "main", "server.R")), collapse = "\n")
  expect_match(ui, "Can take up to 20 minutes to build", fixed = TRUE)
  expect_match(ui, "a busy server may take longer", fixed = TRUE)
  expect_match(server, "todo_snapshot_refresh_elapsed(job)", fixed = TRUE)
  expect_match(server, "Some stages take several minutes without a new message.", fixed = TRUE)
})

test_that("the actual status UI renders a live stage and elapsed time without querying", {
  env <- progress_functions()
  server <- eval(parse(testthat::test_path("..", "..", "main", "server.R")))
  assignment <- Filter(function(expr) {
    is.call(expr) && identical(expr[[1]], as.name("<-")) &&
      identical(expr[[2]], quote(output$todo_snapshot_status))
  }, as.list(body(server)))[[1L]]
  start <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  env$todo_refresh_job <- function() list(
    state = "running", refdate = as.Date("2026-01-01"), started_at = start,
    detail = "Building parent-nest associations from resightings and captures"
  )
  env$output <- new.env()
  env$tags <- htmltools::tags
  env$session <- NULL
  interval <- NULL
  env$invalidateLater <- function(milliseconds, ...) interval <<- milliseconds
  env$renderUI <- function(expr) eval(substitute(expr), env)
  elapsed <- env$todo_snapshot_refresh_elapsed
  env$todo_snapshot_refresh_elapsed <- function(job) elapsed(job, start + 545)
  env$DBq <- function(...) stop("Status redraw must not query the database")
  eval(assignment, env)
  html <- as.character(env$output$todo_snapshot_status)
  expect_identical(interval, 1000)
  expect_match(html, "Building parent-nest associations from resightings and captures", fixed = TRUE)
  expect_match(html, "Elapsed: 9 min 05 sec.", fixed = TRUE)
  expect_match(html, 'aria-busy="true"', fixed = TRUE)
  expect_match(html, 'role="timer"', fixed = TRUE)
  expect_match(html, 'aria-live="off"', fixed = TRUE)
})

test_that("the actual asynchronous worker reports stages before completion", {
  skip_on_os("windows")
  lock <- file.path(tempdir(), "FIELD_2026_BADOatNZ.todo_snapshot_refresh.lock")
  skip_if(dir.exists(lock), "Another local mock refresh owns the worker lock")
  env <- progress_functions()
  directory <- tempfile("todo-progress-test-")
  dir.create(directory)
  withr::defer(unlink(directory, recursive = TRUE))
  cnf <- file.path(directory, "fake.cnf")
  sql <- file.path(directory, "fake.sql")
  client <- file.path(directory, "fake-client.sh")
  writeLines("# invented test configuration; no credentials", cnf)
  writeLines("-- not SQL; consumed only by the fake client", sql)
  writeLines(c(
    "#!/bin/sh",
    "printf '%s\\n' 'TODO_REFRESH_STAGE|parent_status'",
    "sleep 3",
    "printf '%s\\n' 'TODO_REFRESH_STAGE|brood_context'",
    "sleep 3",
    "exit 0"
  ), client)
  Sys.chmod(client, "0700")
  env$todo_refresh_client_cnf <- function() cnf
  job <- env$todo_snapshot_refresh_start(
    as.Date("2026-01-01"), "INVENTED_ONLY", client, sql
  )
  script <- paste(readLines(job$script_file), collapse = "\n")
  expect_match(script, "--batch --raw --skip-column-names --unbuffered", fixed = TRUE)
  expect_false(grepl("--force", script, fixed = TRUE))
  seen <- character()
  deadline <- Sys.time() + 12
  repeat {
    job <- env$todo_snapshot_refresh_status(job)
    if (identical(job$state, "running")) seen <- c(seen, job$detail)
    if (job$state %in% c("succeeded", "failed", "busy") || Sys.time() >= deadline) break
    Sys.sleep(0.1)
  }
  expect_identical(job$state, "succeeded")
  expect_contains(seen, "Building parent-nest associations from resightings and captures")
  expect_contains(seen, "Updating brood counts and locations")
  # The worker writes its terminal status just before its EXIT trap cleans up.
  # Wait for that owned cleanup; do not race it or remove the evidence ourselves.
  cleanup_deadline <- Sys.time() + 2
  while ((file.exists(cnf) || dir.exists(lock)) && Sys.time() < cleanup_deadline) {
    Sys.sleep(0.05)
  }
  expect_false(file.exists(cnf))
  expect_false(dir.exists(lock))
  unlink(c(job$status_file, job$log_file, job$script_file))
})
