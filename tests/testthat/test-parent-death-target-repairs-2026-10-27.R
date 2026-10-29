library(testthat)

death_target_source_sql <- function() {
  paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
}

extract_death_target_context_view <- function(sql, schema_name) {
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1L]]
  start <- which(grepl(
    "^CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ\\.TODO_CHICK_CAPTURE_CONTEXT_BASE_INPUT AS$",
    lines
  ))[[1L]]
  next_start <- which(
    seq_along(lines) > start &
      grepl("^CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ\\.", lines)
  )[[1L]]
  statement <- paste(lines[start:(next_start - 1L)], collapse = "\n")
  gsub(
    "FIELD_2026_BADOatNZ.",
    paste0(schema_name, "."),
    statement,
    fixed = TRUE
  )
}

extract_death_target_targets_view <- function(sql, schema_name) {
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1L]]
  start <- which(grepl(
    "^CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ\\.TODO_CHICK_CAPTURE_TARGETS_INPUT AS$",
    lines
  ))[[1L]]
  next_start <- which(
    seq_along(lines) > start &
      grepl("^CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ\\.", lines)
  )[[1L]]
  statement <- paste(lines[start:(next_start - 1L)], collapse = "\n")
  gsub(
    "FIELD_2026_BADOatNZ.",
    paste0(schema_name, "."),
    statement,
    fixed = TRUE
  )
}

extract_death_target_event_status_view <- function(sql, schema_name) {
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1L]]
  start <- which(grepl(
    "^CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ\\.TODO_CHICK_CAPTURE_EVENT_STATUS_INPUT AS$",
    lines
  ))[[1L]]
  next_start <- which(
    seq_along(lines) > start &
      grepl("^CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ\\.", lines)
  )[[1L]]
  statement <- paste(lines[start:(next_start - 1L)], collapse = "\n")
  gsub(
    "FIELD_2026_BADOatNZ.",
    paste0(schema_name, "."),
    statement,
    fixed = TRUE
  )
}

death_target_socket_or_skip <- function() {
  socket <- Sys.getenv("THREAD2_TEST_MARIADB_SOCKET", unset = "")
  if (!nzchar(socket)) {
    skip("set THREAD2_TEST_MARIADB_SOCKET for the isolated MariaDB check")
  }
  if (Sys.getenv("THREAD2_TEST_MARIADB_DISPOSABLE", unset = "") != "1") {
    skip("set THREAD2_TEST_MARIADB_DISPOSABLE=1 for the disposable MariaDB check")
  }
  if (!grepl("^(/private)?/tmp/[^/]+\\.sock$", socket)) {
    skip("the MariaDB check accepts only a private temporary socket path")
  }
  if (!file.exists(socket)) {
    skip("the selected disposable MariaDB socket is not available")
  }
  if (!nzchar(Sys.which("mariadb"))) {
    skip("mariadb CLI is not available")
  }
  socket
}

run_death_target_mariadb <- function(socket, sql) {
  output <- system2(
    Sys.which("mariadb"),
    args = c(
      "--no-defaults",
      "--batch",
      "--skip-column-names",
      "--socket", socket,
      "--user", "root"
    ),
    input = sql,
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status")
  if (!is.null(status) && status != 0) {
    stop(paste(output, collapse = "\n"))
  }
  output
}

new_death_target_schema <- function() {
  paste0(
    "THREAD2_DEATH_TEST_",
    format(Sys.time(), "%Y%m%d%H%M%S"),
    "_",
    Sys.getpid(),
    "_",
    sample.int(999999L, 1L)
  )
}

invented_death_fixture <- function() {
  events <- data.frame(
    capture_pk = c(1L, 2L, 3L, 10L, 11L, 12L, 20L, 21L, 30L, 40L, 41L, 42L, 50L, 51L, 60L, 70L, 71L, 72L, 73L, 80L, 81L),
    event_date = as.Date(c(
      "2026-10-01", "2026-10-02", "2026-10-03",
      "2026-10-01", "2026-10-02", "2026-10-03",
      "2026-10-01", "2026-10-02",
      "2026-10-03",
      "2026-10-01", "2026-10-02", "2026-10-04",
      "2026-10-01", "2026-10-02",
      "2026-11-01",
      "2026-10-01", "2026-10-01", "2026-10-01", "2026-10-02",
      "2026-10-01", "2026-10-02"
    )),
    nest_id = c(
      "A0101", "A0101", "A0101",
      "A0102", "A0109", "A0102",
      "-A0201", "-A0201",
      "A0103",
      "A0104", "A0104", "A0104",
      "A0105", "A0105",
      "A0106",
      "A0107", "A0107", "A0107", "A0107",
      "A0108", "-A0202"
    ),
    ring = c(
      "CP-001", "CP002", "CP001",
      "CP003", "CP004", NA,
      "CP-100", "CP100",
      NA,
      "CP900", "CP900", "CP900",
      "CP500", NA,
      "CP600",
      "CP700", "CP701", "CP702", "CP700",
      "CP800", "CP800"
    ),
    flag_code = c(
      "F001", "F002", "F001",
      "F003", "F003", "F003",
      "F100", "F100",
      NA,
      "F900", "F900", "F900",
      "F500", "F500",
      "F600",
      "F700", "F701", "F702", "F700",
      "F800", "F800"
    ),
    capture_status = c(
      "F", "F", "D",
      "F", "F", "D",
      "F", "D",
      "D",
      "F", "D", "F",
      "F", "D",
      "D",
      "F", "F", "F", "D",
      "F", "D"
    ),
    stringsAsFactors = FALSE
  )
  events <- rbind(
    events,
    data.frame(
      capture_pk = c(90L, 91L, 100L, 101L),
      event_date = as.Date(c(
        "2026-10-01", "2026-10-02", "2026-10-05", "2026-10-05"
      )),
      nest_id = c("A0110", "A0110", "A0112", "A0112"),
      ring = c("CP910", "CP910", "CP920", "CP920"),
      flag_code = c(NA, "F910", "F920", "F920"),
      capture_status = c("F", "F", "D", "F"),
      stringsAsFactors = FALSE
    )
  )
  events$event_datetime <- as.POSIXct(
    paste(events$event_date, "08:00:00"),
    format = "%Y-%m-%d %H:%M:%S",
    tz = "UTC"
  )
  events$event_time_is_observed <- 1L
  events$event_datetime[events$capture_pk == 100L] <- as.POSIXct(
    "2026-10-05 20:00:00",
    format = "%Y-%m-%d %H:%M:%S",
    tz = "UTC"
  )
  events
}

normalize_death_ring <- function(x) {
  x <- toupper(trimws(ifelse(is.na(x), "", x)))
  x[x %in% c("", "X", "XX", "X-X", "NA", "N/A")] <- NA_character_
  gsub("-", "", x, fixed = TRUE)
}

resolve_confirmed_death_keys <- function(events, reference_date) {
  events <- events[events$event_date <= as.Date(reference_date), , drop = FALSE]
  events$ring_key <- normalize_death_ring(events$ring)
  events$flag_code <- toupper(trimws(ifelse(is.na(events$flag_code), "", events$flag_code)))
  direct <- events[
    events$capture_status == "D" & !is.na(events$ring_key),
    c("nest_id", "ring_key", "capture_pk", "event_date", "event_datetime", "event_time_is_observed"),
    drop = FALSE
  ]
  bridge <- events[
    events$capture_status == "D" &
      is.na(events$ring_key) &
      nzchar(events$flag_code),
    c("nest_id", "capture_pk", "event_date", "event_datetime", "event_time_is_observed", "flag_code"),
    drop = FALSE
  ]
  bridged <- do.call(rbind, lapply(seq_len(nrow(bridge)), function(i) {
    candidates <- unique(events$ring_key[
      events$flag_code == bridge$flag_code[i] &
        !is.na(events$ring_key)
    ])
    if (length(candidates) != 1L) return(NULL)
    data.frame(
      nest_id = bridge$nest_id[i],
      ring_key = candidates,
      capture_pk = bridge$capture_pk[i],
      event_date = bridge$event_date[i],
      event_datetime = bridge$event_datetime[i],
      event_time_is_observed = bridge$event_time_is_observed[i],
      stringsAsFactors = FALSE
    )
  }))
  candidates <- rbind(direct, bridged)
  if (!nrow(candidates)) return(candidates)
  keep <- vapply(seq_len(nrow(candidates)), function(i) {
    later_live <- events$ring_key == candidates$ring_key[i] &
      events$capture_status %in% c("F", "R", "C") &
      (
        events$event_date > candidates$event_date[i] |
          (events$event_date == candidates$event_date[i] &
             events$event_time_is_observed == 1L &
             candidates$event_time_is_observed[i] == 1L &
             (
               events$event_datetime > candidates$event_datetime[i] |
                 (events$event_datetime == candidates$event_datetime[i] &
                    events$capture_pk > candidates$capture_pk[i])
             ))
      )
    !any(later_live)
  }, logical(1L))
  result <- unique(candidates[keep, c("nest_id", "ring_key", "event_date"), drop = FALSE])
  names(result)[names(result) == "event_date"] <- "dead_event_date"
  result
}

resolved_dead_bridge_events <- function(events) {
  events$ring_key <- normalize_death_ring(events$ring)
  events$flag_code <- toupper(trimws(ifelse(is.na(events$flag_code), "", events$flag_code)))
  resolved <- rep(FALSE, nrow(events))
  dead_rows <- which(
    events$capture_status == "D" &
      is.na(events$ring_key) &
      nzchar(events$flag_code)
  )
  for (i in dead_rows) {
    candidate_rings <- unique(events$ring_key[
      events$flag_code == events$flag_code[i] &
        !is.na(events$ring_key)
    ])
    resolved[i] <- length(candidate_rings) == 1L
  }
  resolved
}

summarize_death_targets <- function(events, reference_date, brood_counts = data.frame()) {
  events <- events[events$event_date <= as.Date(reference_date), , drop = FALSE]
  events$ring_key <- normalize_death_ring(events$ring)
  events$is_resolved_dead_bridge <- resolved_dead_bridge_events(events)
  dead <- resolve_confirmed_death_keys(events, reference_date)
  events$is_confirmed_dead <- FALSE
  if (nrow(dead)) {
    events$is_confirmed_dead <- events$ring_key %in% dead$ring_key
  }
  out <- lapply(split(events, events$nest_id), function(x) {
    nest <- x$nest_id[[1L]]
    captured <- unique(x$ring_key[!is.na(x$ring_key)])
    active <- unique(x$ring_key[!is.na(x$ring_key) & !x$is_confirmed_dead])
    flagged <- unique(x$ring_key[!is.na(x$ring_key) & nzchar(x$flag_code)])
    active_flagged <- unique(x$ring_key[
      !is.na(x$ring_key) & nzchar(x$flag_code) & !x$is_confirmed_dead
    ])
    dead_count <- length(setdiff(captured, active))
    brood <- brood_counts[brood_counts$nest_id == nest, , drop = FALSE]
    observed <- if (nrow(brood)) brood$brood_size[[1L]] else NA_real_
    count_date <- if (nrow(brood)) brood$brood_count_date[[1L]] else as.Date(NA)
    dead_for_nest <- dead[dead$ring_key %in% captured, , drop = FALSE]
    deaths_after_count <- if (nrow(brood)) {
      sum(dead_for_nest$dead_event_date > count_date)
    } else {
      0L
    }
    if (is.na(observed)) {
      operational <- length(active)
      source <- "captured_live_rings"
    } else if (!deaths_after_count) {
      operational <- max(observed, length(active))
      source <- "latest_brood_size"
    } else {
      operational <- max(observed - deaths_after_count, length(active))
      source <- "latest_brood_size_minus_deaths_after_count"
    }
    data.frame(
      nest_id = nest,
      n_captured_chick_rings = length(captured),
      n_dead_chick_rings = dead_count,
      n_active_chick_rings = length(active),
      n_flagged_chick_rings = length(flagged),
      n_active_flagged_chick_rings = length(active_flagged),
      n_unresolved_dead_chick_events = sum(
        is.na(x$ring_key) &
          x$capture_status == "D" &
          !x$is_resolved_dead_bridge
      ),
      n_operational_brood_size = operational,
      operational_brood_size_source = source,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

test_that("confirmed death removes only the safely identified brood-local chick", {
  events <- invented_death_fixture()
  events <- events[events$event_date <= as.Date("2026-10-31"), , drop = FALSE]
  dead <- resolve_confirmed_death_keys(events, "2026-10-31")
  expect_setequal(
    paste(dead$nest_id, dead$ring_key),
    c(
      "A0101 CP001", "-A0201 CP100", "A0105 CP500",
      "A0107 CP700", "-A0202 CP800", "A0112 CP920"
    )
  )
  expect_false(any(dead$nest_id == "A0102"))
  expect_false(any(dead$nest_id == "A0103"))
  expect_false(any(dead$nest_id == "A0104"))
  expect_false(any(dead$nest_id == "A0106"))
  expect_true(any(dead$ring_key == "CP800"))
})

test_that("active target counts support H photos and flagging without double subtraction", {
  events <- invented_death_fixture()
  brood_counts <- data.frame(
    nest_id = c("A0101", "A0102", "A0104", "A0105", "A0107", "A0108", "A0109"),
    brood_size = c(2, 1, 1, 1, 3, 1, 1),
    brood_count_date = as.Date(c(
      "2026-10-01", "2026-10-04", "2026-10-01", "2026-10-01",
      "2026-10-03", "2026-10-01", "2026-10-02"
    )),
    stringsAsFactors = FALSE
  )
  summary <- summarize_death_targets(events, "2026-10-31", brood_counts)
  a0101 <- summary[summary$nest_id == "A0101", , drop = FALSE]
  expect_equal(a0101$n_captured_chick_rings, 2)
  expect_equal(a0101$n_dead_chick_rings, 1)
  expect_equal(a0101$n_active_chick_rings, 1)
  expect_equal(a0101$n_active_flagged_chick_rings, 1)
  expect_equal(a0101$n_operational_brood_size, 1)
  expect_equal(a0101$operational_brood_size_source, "latest_brood_size_minus_deaths_after_count")

  a0102 <- summary[summary$nest_id == "A0102", , drop = FALSE]
  expect_equal(a0102$n_active_chick_rings, 1)
  expect_equal(a0102$n_unresolved_dead_chick_events, 1)
  expect_equal(a0102$n_operational_brood_size, 1)

  bridged <- summary[summary$nest_id == "A0105", , drop = FALSE]
  expect_equal(bridged$n_unresolved_dead_chick_events, 0)

  unflagged_then_flagged <- summary[summary$nest_id == "A0110", , drop = FALSE]
  expect_equal(unflagged_then_flagged$n_captured_chick_rings, 1)
  expect_equal(unflagged_then_flagged$n_flagged_chick_rings, 1)
  expect_equal(unflagged_then_flagged$n_active_chick_rings, 1)
  expect_equal(unflagged_then_flagged$n_active_flagged_chick_rings, 1)

  negative <- summary[summary$nest_id == "-A0201", , drop = FALSE]
  expect_equal(negative$n_dead_chick_rings, 1)
  expect_equal(negative$n_active_chick_rings, 0)
  expect_equal(negative$n_operational_brood_size, 0)
  expect_equal(negative$operational_brood_size_source, "captured_live_rings")

  recovered <- summary[summary$nest_id == "A0104", , drop = FALSE]
  expect_equal(recovered$n_dead_chick_rings, 0)
  expect_equal(recovered$n_active_chick_rings, 1)
  expect_equal(recovered$n_operational_brood_size, 1)

  ambiguous <- summary[summary$nest_id == "A0103", , drop = FALSE]
  expect_equal(nrow(ambiguous), 1)
  expect_equal(ambiguous$n_unresolved_dead_chick_events, 1)

  mixed <- summary[summary$nest_id == "A0108", , drop = FALSE]
  expect_equal(mixed$n_dead_chick_rings, 1)
  expect_equal(mixed$n_active_chick_rings, 0)

  mixed_negative <- summary[summary$nest_id == "-A0202", , drop = FALSE]
  expect_equal(mixed_negative$n_dead_chick_rings, 1)
  expect_equal(mixed_negative$n_active_chick_rings, 0)

  count_after_death <- summary[summary$nest_id == "A0107", , drop = FALSE]
  expect_equal(count_after_death$n_dead_chick_rings, 1)
  expect_equal(count_after_death$n_active_chick_rings, 2)
  expect_equal(count_after_death$n_operational_brood_size, 3)
  expect_equal(count_after_death$operational_brood_size_source, "latest_brood_size")

  conflicting_flag <- summary[summary$nest_id == "A0109", , drop = FALSE]
  expect_equal(conflicting_flag$n_dead_chick_rings, 0)
  expect_equal(conflicting_flag$n_active_chick_rings, 1)

  same_day_time <- summary[summary$nest_id == "A0112", , drop = FALSE]
  expect_equal(same_day_time$n_dead_chick_rings, 1)
  expect_equal(same_day_time$n_active_chick_rings, 0)
})

test_that("the source view exposes the death and operational-target contract", {
  sql <- death_target_source_sql()
  expect_match(sql, "n_dead_chick_rings", fixed = TRUE)
  expect_match(sql, "n_active_chick_rings", fixed = TRUE)
  expect_match(sql, "n_active_flagged_chick_rings", fixed = TRUE)
  expect_match(sql, "n_unresolved_dead_chick_events", fixed = TRUE)
  expect_match(sql, "n_operational_brood_size", fixed = TRUE)
  expect_match(sql, "n_bridge_ring_keys = 1", fixed = TRUE)
  expect_match(sql, "later.capture_status", fixed = TRUE)
  expect_match(sql, "later.event_datetime > candidate.dead_event_datetime", fixed = TRUE)
  expect_match(sql, "candidate.dead_event_time_is_observed", fixed = TRUE)
  expect_match(sql, "chick_events.event_time_is_observed", fixed = TRUE)
  expect_match(sql, "one row per nest_id/ring_key", fixed = TRUE)
  expect_match(sql, "MAX(CASE", fixed = TRUE)
  expect_match(sql, "is_resolved_dead_bridge", fixed = TRUE)
  expect_match(sql, "targets.dead_event_datetime > brood.brood_count_datetime", fixed = TRUE)
  expect_match(sql, "subtract n_dead_chick_rings a second time", fixed = TRUE)
  expect_match(sql, "LEFT JOIN ring_counts rings", fixed = TRUE)
})

test_that("current capture-history base view executes against an invented death fixture", {
  socket <- death_target_socket_or_skip()
  schema_name <- new_death_target_schema()
  schema_identifier <- paste0("`", schema_name, "`")
  owned_schema <- FALSE
  on.exit(
    if (owned_schema) {
      try(
        run_death_target_mariadb(
          socket,
          paste0("DROP DATABASE ", schema_identifier, ";")
        ),
        silent = TRUE
      )
    },
    add = TRUE
  )

  run_death_target_mariadb(
    socket,
    paste0("CREATE DATABASE ", schema_identifier, ";")
  )
  owned_schema <- TRUE

  events <- invented_death_fixture()
  events <- events[events$event_date <= as.Date("2026-10-31"), , drop = FALSE]
  event_values <- vapply(seq_len(nrow(events)), function(i) {
    paste0(
      "(", events$capture_pk[i], ", '", events$event_date[i],
      "', '", format(events$event_datetime[i], "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      "', ", events$event_time_is_observed[i], ", 'C', '",
      events$nest_id[i], "', ",
      ifelse(is.na(events$ring[i]), "NULL", paste0("'", normalize_death_ring(events$ring[i]), "'")),
      ", ",
      ifelse(is.na(events$flag_code[i]), "NULL", paste0("'", events$flag_code[i], "'")),
      ", '", events$capture_status[i], "')"
    )
  }, character(1L))
  brood_values <- paste(
    "('A0101', 'CR', '2026-10-01', '08:00:00', 2, 1),",
    "('A0102', 'CR', '2026-10-04', '08:00:00', 1, 2),",
    "('A0104', 'CR', '2026-10-01', '08:00:00', 1, 3),",
    "('A0105', 'CR', '2026-10-01', '08:00:00', 1, 4),",
    "('A0107', 'CR', '2026-10-03', '08:00:00', 3, 5),",
    "('A0108', 'CR', '2026-10-01', '08:00:00', 1, 6),",
    "('A0109', 'CR', '2026-10-02', '08:00:00', 1, 7)"
  )
  view_sql <- extract_death_target_context_view(
    death_target_source_sql(),
    schema_name
  )
  target_view_sql <- extract_death_target_targets_view(
    death_target_source_sql(),
    schema_name
  )
  event_status_view_sql <- extract_death_target_event_status_view(
    death_target_source_sql(),
    schema_name
  )
  setup_sql <- paste0(
    "CREATE TABLE ", schema_identifier, ".TODO_CHICK_CAPTURE_EVENTS_INPUT (",
    "capture_pk INT NOT NULL, event_date DATE NOT NULL, event_datetime DATETIME NOT NULL, ",
    "event_time_is_observed TINYINT NOT NULL, ",
    "age CHAR(1) NOT NULL, ",
    "nest_id VARCHAR(10) NOT NULL, ring_key VARCHAR(50) NULL, ",
    "flag_code VARCHAR(20) NULL, capture_status VARCHAR(1) NULL, ",
    "PRIMARY KEY (capture_pk));",
    "INSERT INTO ", schema_identifier, ".TODO_CHICK_CAPTURE_EVENTS_INPUT ",
    "(capture_pk, event_date, event_datetime, event_time_is_observed, age, nest_id, ring_key, flag_code, capture_status) VALUES ",
    paste(event_values, collapse = ","), ";",
    "CREATE TABLE ", schema_identifier, ".settings (",
    "variable VARCHAR(64) NOT NULL, value VARCHAR(32) NULL);",
    "INSERT INTO ", schema_identifier, ".settings (variable, value) ",
    "VALUES ('reference_date', '2026-10-31');",
    "CREATE TABLE ", schema_identifier, ".NESTS (",
    "nest_id VARCHAR(10) NOT NULL, site VARCHAR(2) NOT NULL, date DATE NOT NULL, ",
    "time_visit TIME NULL, brood_size INT NULL, pk INT NOT NULL, ",
    "PRIMARY KEY (pk));",
    "INSERT INTO ", schema_identifier, ".NESTS ",
    "(nest_id, site, date, time_visit, brood_size, pk) VALUES ",
    brood_values, ";",
    event_status_view_sql,
    target_view_sql,
    view_sql
  )
  run_death_target_mariadb(socket, setup_sql)
  result <- run_death_target_mariadb(
    socket,
    paste0(
      "SELECT nest_id, n_dead_chick_rings, n_active_chick_rings, ",
      "n_active_flagged_chick_rings, n_unresolved_dead_chick_events, ",
      "n_operational_brood_size ",
      "FROM ", schema_identifier, ".TODO_CHICK_CAPTURE_CONTEXT_BASE_INPUT ",
      "ORDER BY nest_id;"
    )
  )
  result <- result[nzchar(trimws(result))]
  parsed <- do.call(rbind, strsplit(result, "\t", fixed = TRUE))
  expect_equal(parsed[parsed[, 1L] == "A0101", 2:6, drop = FALSE], matrix(c("1", "1", "1", "0", "1"), nrow = 1L))
  expect_equal(parsed[parsed[, 1L] == "A0102", 2:6, drop = FALSE], matrix(c("0", "1", "1", "1", "1"), nrow = 1L))
  expect_equal(parsed[parsed[, 1L] == "A0103", 2:6, drop = FALSE], matrix(c("0", "0", "0", "1", "0"), nrow = 1L))
  expect_equal(parsed[parsed[, 1L] == "-A0201", 2:6, drop = FALSE], matrix(c("1", "0", "0", "0", "0"), nrow = 1L))
  expect_equal(parsed[parsed[, 1L] == "A0104", 2:6, drop = FALSE], matrix(c("0", "1", "1", "0", "1"), nrow = 1L))
  expect_equal(parsed[parsed[, 1L] == "A0105", 2:6, drop = FALSE], matrix(c("1", "0", "0", "0", "0"), nrow = 1L))
  expect_equal(parsed[parsed[, 1L] == "A0107", 2:6, drop = FALSE], matrix(c("1", "2", "2", "0", "3"), nrow = 1L))
  expect_equal(parsed[parsed[, 1L] == "A0108", 2:6, drop = FALSE], matrix(c("1", "0", "0", "0", "0"), nrow = 1L))
  expect_equal(parsed[parsed[, 1L] == "-A0202", 2:6, drop = FALSE], matrix(c("1", "0", "0", "0", "0"), nrow = 1L))
  expect_equal(parsed[parsed[, 1L] == "A0109", 2:6, drop = FALSE], matrix(c("0", "1", "1", "0", "1"), nrow = 1L))
  expect_equal(parsed[parsed[, 1L] == "A0110", 2:6, drop = FALSE], matrix(c("0", "1", "1", "0", "1"), nrow = 1L))
  expect_equal(parsed[parsed[, 1L] == "A0112", 2:6, drop = FALSE], matrix(c("1", "0", "0", "0", "0"), nrow = 1L))
})
