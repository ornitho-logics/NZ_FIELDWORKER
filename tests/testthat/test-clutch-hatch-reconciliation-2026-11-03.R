library(testthat)

# Invented records only. Extract and execute the production SELECTs and stage
# column lists in an explicitly selected, disposable, socket-only MariaDB.
clutch_sql <- function(file) {
  paste(readLines(app_file("DATABASE", file), warn = FALSE), collapse = "\n")
}

clutch_between <- function(sql, start, end) {
  pos <- regexpr(start, sql, fixed = TRUE)[1L]
  stopifnot(pos > 0L)
  rest <- substring(sql, pos)
  finish <- regexpr(end, rest, fixed = TRUE)[1L]
  stopifnot(finish > 0L)
  substr(rest, 1L, finish - 1L)
}

clutch_statement <- function(sql, start) {
  paste0(clutch_between(sql, start, ";\n"), ";")
}

clutch_cte <- function(sql, name, next_name) {
  paste0(clutch_between(sql, paste0(name, " AS ("),
                       paste0("),\n", next_name, " AS (")), ")")
}

clutch_literal <- function(value) {
  if (is.na(value)) return("CAST(NULL AS CHAR(64))")
  if (is.numeric(value)) return(as.character(value))
  paste0("'", gsub("'", "''", as.character(value), fixed = TRUE), "'")
}

clutch_values <- function(rows) {
  selects <- vapply(seq_len(max(1L, nrow(rows))), function(i) {
    cells <- vapply(names(rows), function(column) {
      value <- if (nrow(rows)) rows[[column]][i] else NA_character_
      paste(clutch_literal(value), "AS", column)
    }, character(1))
    paste("SELECT", paste(cells, collapse = ", "))
  }, character(1))
  paste(paste(selects, collapse = "\nUNION ALL\n"),
        if (!nrow(rows)) "WHERE 1 = 0" else "")
}

clutch_disposable_query <- function(sql) {
  socket <- Sys.getenv("THREAD2_TEST_MARIADB_SOCKET", unset = "")
  if (Sys.getenv("THREAD2_TEST_MARIADB_DISPOSABLE", unset = "") != "1" ||
      !grepl("^(/private)?/tmp/[^/]+\\.sock$", socket) ||
      !file.exists(socket) || !nzchar(Sys.which("mariadb"))) {
    skip("requires an explicitly selected disposable local MariaDB socket")
  }
  result <- system2(Sys.which("mariadb"), c(
    "--no-defaults", "--batch", "--skip-column-names", "--host=localhost",
    "--protocol=SOCKET", paste0("--socket=", socket), "--user=root"
  ), input = sql, stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status"))) stop(paste(result, collapse = "\n"))
  result
}

clutch_fixture <- function() {
  list(
    captures = data.frame(
      pk = 1:3, date = "2026-11-01", released = c("09:30:00", "09:40:00", "11:00:00"),
      caught = NA_character_, age = "C", capture_status = "F", species = "BADO",
      site = "CR", gps_id = 1L, gps_point = 101:103, nest_id = "ZZ0101",
      ring = paste0("MOCK-", 1:3), UL = "X", UL_in = "X"
    ),
    nests = data.frame(
      pk = 1:2, nest_id = "ZZ0101", site = "CR", date = c("2026-10-12", "2026-11-01"),
      time_visit = "09:00:00", nest_state = c("F", "H"), clutch_size = c(3L, 1L),
      brood_size = c(0L, 2L)
    ),
    eggs = data.frame(nest_id = character(), date = character(), time_visit = character()),
    reference_date = "2026-11-03", fallback = FALSE,
    context = list(
      nest_id = "ZZ0101", species = "BADO", nest_state = "H", hatch_state = "H",
      hatch_signs_present = 1L, clutch_size = 1L, brood_size = 2L, days_ago = 2L,
      last_visit_datetime = "2026-11-01 09:00:00", reference_date = "2026-11-03",
      observed_hatch_date = "2026-11-01", latest_clutch_datetime = "2026-11-01 09:00:00",
      capture_gate_clutch_size = 3L, capture_gate_clutch_start_datetime = "2026-10-12 09:00:00",
      current_clutch_size = 1L, current_clutch_datetime = "2026-11-01 09:00:00",
      current_clutch_start_datetime = "2026-11-01 09:00:00"
    )
  )
}

clutch_run <- function(fixture = clutch_fixture()) {
  refresh <- clutch_sql("refresh_todo_list_snapshot.SQL")
  views <- clutch_sql("views.SQL")
  statements <- c(
    "CREATE DATABASE IF NOT EXISTS codex_clutch_hatch_synthetic;",
    "USE codex_clutch_hatch_synthetic;",
    "SET SESSION sql_mode = 'STRICT_ALL_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';"
  )
  add_table <- function(name, rows) {
    statements <<- c(statements, paste("CREATE TEMPORARY TABLE", name, "AS", clutch_values(rows), ";"))
  }
  add_table("fixture_CAPTURES", fixture$captures)
  add_table("fixture_NESTS", fixture$nests)
  add_table("fixture_EGGS", fixture$eggs)
  add_table("fixture_settings", data.frame(variable = "reference_date", value = fixture$reference_date))
  add_table("fixture_RESIGHTINGS", data.frame(
    date = character(), gps_id = integer(), gps_point = integer(), nest_id = character(),
    species = character(), site = character(), age = character()
  ))
  statements <- c(statements,
    "CREATE TEMPORARY TABLE fixture_TODO_NEST_HISTORY AS SELECT * FROM fixture_NESTS WHERE date <= (SELECT value FROM fixture_settings);",
    sub("CREATE TABLE", "CREATE TEMPORARY TABLE", clutch_statement(refresh,
      "CREATE TABLE FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD ("), fixed = TRUE)
  )
  fixture$context$reference_date <- fixture$reference_date
  statements <- c(statements, paste0(
    "INSERT INTO fixture_TODO_NEST_CONTEXT_SNAPSHOT_BUILD (",
    paste(names(fixture$context), collapse = ", "), ") VALUES (",
    paste(vapply(fixture$context, clutch_literal, character(1)), collapse = ", "), ");"
  ))
  # Execute the real capture/date/normalization, death-target, and live-count
  # stages. The unrelated family resolver is represented by its staged output.
  for (name in c("raw_encounter_nest_consensus", "chick_capture_events",
                 "chick_capture_event_status", "chick_capture_targets", "chick_capture_context_base")) {
    statements <- c(statements, clutch_statement(refresh, paste0("CREATE TEMPORARY TABLE tmp_todo_", name, " AS")))
  }
  statements <- c(statements, paste(
    "CREATE TEMPORARY TABLE tmp_todo_chick_encounters AS SELECT",
    "events.capture_pk AS event_pk, events.event_date, events.event_datetime,",
    "CAST('CAPTURES' AS CHAR(16)) AS source_table, events.nest_id, events.gps_id, events.gps_point, events.ring_key,",
    "IF(events.ring_key IS NULL, 1, 0) AS is_unresolved_identity",
    "FROM tmp_todo_chick_capture_event_status events;"
  ))
  if (!is.null(fixture$encounters)) {
    statements <- c(statements, paste(
      "INSERT INTO tmp_todo_chick_encounters", clutch_values(fixture$encounters), ";"
    ))
  }
  latest_stub <- clutch_statement(views,
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW\n  FIELD_2026_BADOatNZ.TODO_CHICK_LATEST_ENCOUNTER_CONTEXT_INPUT AS")
  statements <- c(statements, sub("^[\\s\\S]*? AS\\n", "CREATE TEMPORARY TABLE tmp_todo_chick_latest_encounter_context AS\n",
                                latest_stub, perl = TRUE))
  statements <- c(statements,
    clutch_statement(refresh, "CREATE TEMPORARY TABLE tmp_todo_chick_capture_context AS"),
    sub("CREATE TABLE", "CREATE TEMPORARY TABLE", clutch_statement(refresh,
      "CREATE TABLE FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD ("), fixed = TRUE),
    clutch_statement(refresh, "INSERT INTO FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD (")
  )
  if (fixture$fallback) {
    fallback <- clutch_statement(views,
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW\n  FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT AS")
    fallback <- sub("^[\\s\\S]*? AS\\n", "CREATE TEMPORARY TABLE fixture_TODO_CHICK_CAPTURE_CONTEXT_INPUT AS\n", fallback, perl = TRUE)
    fallback <- gsub("FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_BASE_INPUT", "tmp_todo_chick_capture_context_base", fallback, fixed = TRUE)
    fallback <- gsub("FIELD_2026_BADOatNZ.TODO_CHICK_LATEST_ENCOUNTER_CONTEXT_INPUT", "tmp_todo_chick_latest_encounter_context", fallback, fixed = TRUE)
    statements <- c(statements, fallback)
  } else {
    statements <- c(statements, "CREATE TEMPORARY TABLE fixture_TODO_CHICK_CAPTURE_CONTEXT_INPUT AS SELECT * FROM fixture_TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD;")
  }
  ctes <- c(
    "sr AS (SELECT value AS reference_date FROM fixture_settings)",
    "task_context AS (SELECT * FROM fixture_TODO_NEST_CONTEXT_SNAPSHOT_BUILD)",
    "initial_clutch_status AS (SELECT NULL AS nest_id, NULL AS inferred_hatch_date WHERE 1 = 0)",
    paste("brood_context AS (SELECT NULL AS nest_id, NULL AS reference_date,",
          "NULL AS latest_encounter_datetime, NULL AS latest_encounter_date,",
          "0 AS is_negative_brood, 0 AS has_hatch_evidence WHERE 1 = 0)"),
    "adult_parent_status AS (SELECT NULL AS nest_id, NULL AS M_parent_mark, NULL AS F_parent_mark WHERE 1 = 0)",
    clutch_cte(refresh, "clutch_hatch_reconciliation", "latest_nests"),
    clutch_cte(refresh, "latest_nests", "active_nests"),
    clutch_cte(refresh, "active_nests", "first_processable_visit"),
    clutch_cte(refresh, "nota_followup_nests", "chick_captures"),
    clutch_cte(refresh, "todo_nest_check", "todo_untrapped_brood"),
    paste0(clutch_between(refresh, "todo_nota_nest_check AS (", ")\nSELECT\n  t.*"), ")"),
    "routed AS (SELECT * FROM todo_nest_check UNION ALL SELECT * FROM todo_nota_nest_check)"
  )
  statements <- c(statements, paste("WITH", paste(ctes, collapse = ",\n"), paste(
    "SELECT CONCAT_WS('|', n.clutch_size, COALESCE(chicks.n_original_hatched_chick_rings, -1),",
    "chicks.n_active_chick_rings, chicks.n_dead_chick_rings,",
    "COALESCE((SELECT GROUP_CONCAT(todo ORDER BY todo) FROM routed), '-'),",
    "n.nest_state, n.last_visit_datetime, raw.clutch_size, raw.capture_gate_clutch_size,",
    "raw.capture_gate_clutch_start_datetime)",
    "FROM latest_nests n JOIN task_context raw ON raw.nest_id = n.nest_id",
    "JOIN fixture_TODO_CHICK_CAPTURE_CONTEXT_INPUT chicks ON chicks.nest_id = n.nest_id;"
  )))
  # Namespace substitution changes only the fixture bindings, never expressions.
  statements <- gsub("FIELD_2026_BADOatNZ.", "fixture_", statements, fixed = TRUE)
  output <- clutch_disposable_query(paste(statements, collapse = "\n"))
  stopifnot(length(output) == 1L)
  result <- strsplit(output, "|", fixed = TRUE)[[1L]]
  names(result) <- c("eggs", "hatched", "live", "dead", "task", "state", "visit", "raw_eggs", "gate_size", "gate_start")
  result
}

test_that("original clutch hatch accounting routes real SQL tasks and preserves raw gates", {
  result <- clutch_run()
  expect_identical(unname(result[c("eggs", "hatched", "live", "dead", "task")]),
                   c("0", "3", "3", "0", "notA nest-check"))
  expect_identical(unname(result[c("state", "visit", "raw_eggs", "gate_size", "gate_start")]),
                   c("H", "2026-11-01 09:00:00", "1", "3", "2026-10-12 09:00:00"))
  fixture <- clutch_fixture()
  fixture$captures <- fixture$captures[1:2, ]
  expect_identical(unname(clutch_run(fixture)[c("eggs", "task")]), c("1", "nest check"))
  duplicate <- fixture$captures[2, ]; duplicate$pk <- 4L
  fixture$captures <- rbind(fixture$captures, duplicate)
  expect_identical(unname(clutch_run(fixture)[c("eggs", "hatched")]), c("1", "2"))
  fixture$captures$capture_status[3] <- "R"
  expect_identical(unname(clutch_run(fixture)[c("eggs", "hatched")]), c("1", "2"))
  fixture <- clutch_fixture()
  duplicate <- fixture$captures[3, ]; duplicate$pk <- 4L
  fixture$captures <- rbind(fixture$captures, duplicate)
  expect_identical(unname(clutch_run(fixture)[c("eggs", "hatched")]), c("0", "3"))
})

test_that("unknown, mixed, unresolved, extra, and future identities fail closed in SQL", {
  for (scenario in c("unknown", "mixed", "unlinked_first", "unresolved", "placeholder", "extra", "future", "untimed")) {
    fixture <- clutch_fixture()
    if (scenario == "unknown") fixture$captures$capture_status[3] <- "R"
    if (scenario %in% c("mixed", "unlinked_first")) {
      recapture <- fixture$captures[3, ]; recapture$pk <- 4L; recapture$capture_status <- "R"
      if (scenario == "unlinked_first") recapture$capture_status <- "F"
      fixture$captures$nest_id[3] <- if (scenario == "mixed") "-Z0202" else NA_character_
      fixture$captures <- rbind(fixture$captures, recapture)
    }
    if (scenario == "unresolved") fixture$captures$ring[3] <- NA_character_
    if (scenario == "placeholder") fixture$captures$ring[3] <- "NULL"
    if (scenario == "extra") {
      extra <- fixture$captures[3, ]; extra$pk <- 4L; extra$ring <- "MOCK-4"
      fixture$captures <- rbind(fixture$captures, extra)
    }
    if (scenario == "future") fixture$captures$date[3] <- "2026-11-04"
    if (scenario == "untimed") fixture$captures$released[3] <- NA_character_
    expect_identical(unname(clutch_run(fixture)[c("eggs", "task")]), c("1", "nest check"), info = scenario)
  }
})

test_that("cross-linked encounters, uncertain extras, and same-occasion conflicts block inference", {
  for (scenario in c("cross_link", "unresolved_encounter", "same_occasion", "brood_above_clutch")) {
    fixture <- clutch_fixture()
    if (scenario %in% c("cross_link", "unresolved_encounter")) {
      fixture$encounters <- data.frame(
        event_pk = 10L, event_date = "2026-11-02", event_datetime = "2026-11-02 00:00:00",
        source_table = "RESIGHTINGS", nest_id = if (scenario == "cross_link") "ZZ0202" else "ZZ0101",
        gps_id = 1L, gps_point = 201L, ring_key = if (scenario == "cross_link") "MOCK3" else NA_character_,
        is_unresolved_identity = if (scenario == "cross_link") 0L else 1L
      )
    }
    if (scenario == "same_occasion") {
      other <- fixture$captures[3, ]; other$pk <- 4L; other$ring <- "MOCK-4"; other$nest_id <- "ZZ0202"
      fixture$captures <- rbind(fixture$captures, other)
    }
    if (scenario == "brood_above_clutch") fixture$context$brood_size <- 4L
    expect_identical(unname(clutch_run(fixture)["eggs"]), "1", info = scenario)
  }
  fixture <- clutch_fixture()
  later <- fixture$captures[3, ]; later$pk <- 4L; later$capture_status <- "R"
  later$date <- "2026-11-04"; later$nest_id <- "ZZ0202"
  fixture$captures <- rbind(fixture$captures, later)
  expect_identical(unname(clutch_run(fixture)["eggs"]), "0")
})

test_that("later egg observations override older first-banding inference", {
  fixture <- clutch_fixture()
  fixture$context$latest_clutch_datetime <- "2026-11-02 09:00:00"
  expect_identical(unname(clutch_run(fixture)["eggs"]), "1")
  # A duplicate first-banding row must not move the evidence beyond that visit.
  duplicate <- fixture$captures[3, ]; duplicate$pk <- 4L; duplicate$date <- "2026-11-03"
  fixture$captures <- rbind(fixture$captures, duplicate)
  expect_identical(unname(clutch_run(fixture)["eggs"]), "1")
  fixture$captures$capture_status[4] <- "R"
  expect_identical(unname(clutch_run(fixture)[c("eggs", "hatched")]), c("1", "3"))
  fixture <- clutch_fixture()
  fixture$context$latest_clutch_datetime <- "2026-11-01 11:00:01"
  expect_identical(unname(clutch_run(fixture)["eggs"]), "1")
  fixture$context$latest_clutch_datetime <- "2026-11-01 11:00:00"
  expect_identical(unname(clutch_run(fixture)["eggs"]), "1")
  fixture$context$latest_clutch_datetime <- "2026-11-01 10:59:59"
  expect_identical(unname(clutch_run(fixture)["eggs"]), "0")
  fixture <- clutch_fixture()
  fixture$eggs <- data.frame(nest_id = "ZZ0101", date = "2026-11-02", time_visit = "09:00:00")
  expect_identical(unname(clutch_run(fixture)["eggs"]), "1")
  fixture$eggs$date <- "2026-11-04"
  expect_identical(unname(clutch_run(fixture)["eggs"]), "0")
  fixture$eggs$date <- "2026-11-01"; fixture$eggs$time_visit <- "11:00:01"
  expect_identical(unname(clutch_run(fixture)["eggs"]), "1")
  fixture$eggs$time_visit <- "10:59:59"
  expect_identical(unname(clutch_run(fixture)["eggs"]), "0")
  fixture$eggs$time_visit <- NA_character_
  expect_identical(unname(clutch_run(fixture)["eggs"]), "1")
  fixture <- clutch_fixture()
  fixture$nests$time_visit[2] <- NA_character_
  expect_identical(unname(clutch_run(fixture)["eggs"]), "1")
})

test_that("first hatch proof uses caught time without changing release-based operational clocks", {
  fixture <- clutch_fixture()
  fixture$captures$caught[3] <- "10:00:00"
  fixture$context$latest_clutch_datetime <- "2026-11-01 10:30:00"
  expect_identical(unname(clutch_run(fixture)[c("eggs", "task")]), c("1", "nest check"))
  fixture$context$latest_clutch_datetime <- "2026-11-01 09:59:59"
  expect_identical(unname(clutch_run(fixture)[c("eggs", "task")]), c("0", "notA nest-check"))
  # With no caught time, the release timestamp remains the explicit fallback.
  fixture$captures$caught[3] <- NA_character_
  fixture$context$latest_clutch_datetime <- "2026-11-01 10:30:00"
  expect_identical(unname(clutch_run(fixture)["eggs"]), "0")
  refresh <- clutch_sql("refresh_todo_list_snapshot.SQL")
  expect_match(refresh, "COALESCE(c.caught, c.released, '00:00:00')", fixed = TRUE)
  expect_match(refresh, "COALESCE(c.released, c.caught, '00:00:00')", fixed = TRUE)
})

test_that("dead chicks count as hatched without becoming live targets or closing the nest", {
  fixture <- clutch_fixture()
  dead <- fixture$captures[3, ]; dead$pk <- 4L; dead$capture_status <- "D"; dead$date <- "2026-11-02"
  dead$caught <- "10:00:00"; dead$released <- NA_character_
  fixture$captures <- rbind(fixture$captures, dead)
  expect_identical(unname(clutch_run(fixture)[c("eggs", "hatched", "live", "dead", "task", "state")]),
                   c("0", "3", "2", "1", "notA nest-check", "H"))
  fixture <- clutch_fixture()
  dead <- fixture$captures; dead$pk <- 4:6; dead$capture_status <- "D"; dead$date <- "2026-11-02"
  dead$caught <- "10:00:00"; dead$released <- NA_character_
  fixture$captures <- rbind(fixture$captures, dead)
  fixture$context$brood_size <- 0L
  expect_identical(unname(clutch_run(fixture)[c("eggs", "live", "task", "state")]),
                   c("0", "0", "notA nest-check", "H"))
  fixture <- clutch_fixture(); fixture$context$nest_state <- "notA"
  expect_identical(unname(clutch_run(fixture)[c("eggs", "task", "state")]), c("1", "-", "notA"))
})

test_that("missing hatch, smaller completion, and installer evidence remain conservative", {
  fixture <- clutch_fixture(); fixture$context$observed_hatch_date <- NA_character_
  expect_identical(unname(clutch_run(fixture)["eggs"]), "1")
  fixture <- clutch_fixture(); fixture$context$capture_gate_clutch_size <- 2L
  fixture$captures <- fixture$captures[1:2, ]
  expect_identical(unname(clutch_run(fixture)["eggs"]), "1")
  fixture <- clutch_fixture(); fixture$fallback <- TRUE
  expect_identical(unname(clutch_run(fixture)[c("eggs", "task")]), c("1", "nest check"))
})

test_that("reconciliation has one bounded task decision and matching stage contracts", {
  refresh <- clutch_sql("refresh_todo_list_snapshot.SQL")
  views <- clutch_sql("views.SQL")
  expect_match(refresh, "context.capture_gate_clutch_size AS current_clutch_size", fixed = TRUE)
  expect_match(refresh, "context.capture_gate_clutch_start_datetime AS current_clutch_start_datetime", fixed = TRUE)
  expect_match(refresh, "reconciliation.clutch_size,\n    context.clutch_size AS observed_clutch_size", fixed = TRUE)
  decision <- clutch_cte(refresh, "clutch_hatch_reconciliation", "latest_nests")
  expect_match(decision, "chicks.n_original_hatched_chick_rings = context.capture_gate_clutch_size", fixed = TRUE)
  expect_no_match(decision, "CAPTURES|RESIGHTINGS|NESTS n|UPDATE |INSERT ")
  for (field in c("n_original_hatched_chick_rings", "original_hatch_accounted_datetime",
                  "n_hatch_reconciliation_blockers", "hatch_reconciliation_reference_date")) {
    expect_match(views, paste("AS", field), fixed = TRUE)
    expect_match(refresh, paste("AS", field), fixed = TRUE)
  }
})
