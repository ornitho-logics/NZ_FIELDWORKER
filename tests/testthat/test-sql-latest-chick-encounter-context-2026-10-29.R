library(testthat)

latest_chick_context_source_sql <- function() {
  paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
}

refresh_chick_context_source_sql <- function() {
  paste(
    readLines(
      app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
      warn = FALSE
    ),
    collapse = "\n"
  )
}

extract_temptable_view <- function(sql, view_name, schema_name) {
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1L]]
  create_starts <- which(grepl(
    "^CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW",
    lines
  ))
  start <- create_starts[vapply(
    create_starts,
    function(index) any(grepl(
      paste0(view_name, " AS$"),
      lines[index:min(index + 2L, length(lines))]
    )),
    logical(1)
  )][[1L]]
  next_start <- create_starts[create_starts > start][[1L]]
  statement <- paste(lines[start:(next_start - 1L)], collapse = "\n")
  gsub(
    "FIELD_2026_BADOatNZ.",
    paste0(schema_name, "."),
    statement,
    fixed = TRUE
  )
}

extract_temporary_table <- function(sql, table_name, schema_name) {
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1L]]
  statement_starts <- which(grepl(
    "^(CREATE (TEMPORARY TABLE|OR REPLACE ALGORITHM = TEMPTABLE VIEW)|ALTER TABLE|SELECT 'TODO_REFRESH_STAGE|DROP TEMPORARY TABLE)",
    lines
  ))
  start <- statement_starts[vapply(
    statement_starts,
    function(index) any(grepl(
      paste0(table_name, " AS$"),
      lines[index:min(index + 1L, length(lines))]
    )),
    logical(1)
  )][[1L]]
  next_start <- statement_starts[statement_starts > start][[1L]]
  statement <- paste(lines[start:(next_start - 1L)], collapse = "\n")
  gsub(
    "FIELD_2026_BADOatNZ.",
    paste0(schema_name, "."),
    statement,
    fixed = TRUE
  )
}

extract_temporary_table_before <- function(
  sql,
  table_name,
  before_pattern,
  schema_name
) {
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1L]]
  statement_starts <- which(grepl(
    "^(CREATE (TEMPORARY TABLE|OR REPLACE ALGORITHM = TEMPTABLE VIEW)|ALTER TABLE|SELECT 'TODO_REFRESH_STAGE|DROP TEMPORARY TABLE)",
    lines
  ))
  before_line <- which(grepl(before_pattern, lines, fixed = TRUE))[[1L]]
  matching_starts <- statement_starts[vapply(
    statement_starts,
    function(index) any(grepl(
      paste0(table_name, " AS$"),
      lines[index:min(index + 2L, length(lines))]
    )),
    logical(1)
  )]
  start <- tail(matching_starts[matching_starts < before_line], 1L)
  next_start <- statement_starts[statement_starts > start][[1L]]
  statement <- paste(lines[start:(next_start - 1L)], collapse = "\n")
  gsub(
    "FIELD_2026_BADOatNZ.",
    paste0(schema_name, "."),
    statement,
    fixed = TRUE
  )
}

latest_chick_context_socket_or_skip <- function() {
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

run_latest_chick_context_mariadb <- function(socket, sql) {
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
  if (!is.null(attr(output, "status")) && attr(output, "status") != 0) {
    stop(paste(output, collapse = "\n"))
  }
  paste(output, collapse = "\n")
}

test_that("latest chick context exposes one shared conservative contract", {
  sql <- latest_chick_context_source_sql()
  expect_match(sql, "TODO_CHICK_ENCOUNTERS_INPUT", fixed = TRUE)
  expect_match(sql, "TODO_CHICK_LATEST_ENCOUNTER_CONTEXT_INPUT", fixed = TRUE)
  expect_match(sql, "latest_encounter_flagged_count", fixed = TRUE)
  expect_match(sql, "latest_encounter_unresolved_count", fixed = TRUE)
  expect_match(sql, "latest_encounter_is_conservative", fixed = TRUE)
  expect_match(sql, "latest_encounter_is_fallback", fixed = TRUE)
  expect_match(sql, "latest_encounter_availability", fixed = TRUE)
  expect_match(sql, "CAST(NULL AS SIGNED) AS event_pk", fixed = TRUE)
  expect_match(sql, "CAST(NULL AS DATE) AS latest_encounter_date", fixed = TRUE)
  expect_match(sql, "WHERE 1 = 0", fixed = TRUE)
  expect_match(
    sql,
    "FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_BASE_INPUT base",
    fixed = TRUE
  )
  expect_match(
    sql,
    "LEFT JOIN FIELD_2026_BADOatNZ.TODO_CHICK_LATEST_ENCOUNTER_CONTEXT_INPUT latest",
    fixed = TRUE
  )
  boundary_start <- regexpr(
    "FIELD_2026_BADOatNZ.TODO_CHICK_ENCOUNTERS_INPUT AS",
    sql,
    fixed = TRUE
  )
  boundary_end <- regexpr(
    "TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT",
    sql,
    fixed = TRUE
  )
  install_boundary <- substr(sql, boundary_start, boundary_end)
  expect_false(
    grepl("RESIGHTINGS_H_BROOD_ASSOCIATIONS", install_boundary, fixed = TRUE)
  )
  expect_false(
    grepl(
      "TODO_PARENT_CHICK_RESIGHTING_ASSOCIATIONS",
      install_boundary,
      fixed = TRUE
    )
  )
  parent_input_pos <- regexpr(
    paste(
      "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW",
      "FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT AS",
      sep = "\n  "
    ),
    sql,
    fixed = TRUE
  )
  parent_consumer_pos <- regexpr(
    "FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_RESIGHTING_ASSOCIATIONS AS",
    sql,
    fixed = TRUE
  )
  expect_true(parent_input_pos > 0L)
  expect_true(parent_consumer_pos > parent_input_pos)
})

test_that("refresh-local encounter calculation is staged after parent status", {
  sql <- refresh_chick_context_source_sql()
  parent_stage_pos <- regexpr(
    "SELECT 'TODO_REFRESH_STAGE|parent_status' AS refresh_stage;",
    sql,
    fixed = TRUE
  )
  encounter_pos <- regexpr(
    "CREATE TEMPORARY TABLE tmp_todo_chick_encounters AS",
    sql,
    fixed = TRUE
  )
  chick_stage_pos <- regexpr(
    "SELECT 'TODO_REFRESH_STAGE|chick_capture_context' AS refresh_stage;",
    sql,
    fixed = TRUE
  )
  expect_true(parent_stage_pos > 0L)
  expect_true(encounter_pos > parent_stage_pos)
  expect_true(chick_stage_pos > encounter_pos)
  expect_match(
    sql,
    "FROM tmp_todo_chick_encounters events",
    fixed = TRUE
  )
  expect_match(
    sql,
    "LEFT JOIN tmp_todo_chick_latest_encounter_context latest",
    fixed = TRUE
  )
})

test_that("actual encounter resolver preserves direct links and guards inferred links", {
  socket <- latest_chick_context_socket_or_skip()
  schema_name <- paste0("thread2_encounters_", Sys.getpid())
  schema_identifier <- paste0("`", schema_name, "`")
  on.exit(
    try(
      run_latest_chick_context_mariadb(
        socket,
        paste0("DROP DATABASE IF EXISTS ", schema_identifier, ";")
      ),
      silent = TRUE
    ),
    add = TRUE
  )

  encounter_statement <- extract_temporary_table(
    refresh_chick_context_source_sql(),
    "tmp_todo_chick_encounters",
    schema_name
  )
  capture_events_statement <- extract_temporary_table(
    refresh_chick_context_source_sql(),
    "tmp_todo_chick_capture_events",
    schema_name
  )
  setup <- paste(
    paste0("CREATE DATABASE ", schema_identifier, ";"),
    paste0("USE ", schema_identifier, ";"),
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".settings (variable VARCHAR(64), value DATE);"
    ),
    paste0(
      "INSERT INTO ", schema_identifier,
      ".settings VALUES ('reference_date', '2026-10-28');"
    ),
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".CAPTURES (",
      "pk INT, ring VARCHAR(50), nest_id VARCHAR(32), age CHAR(1), ",
      "site VARCHAR(2), date DATE, released TIME, caught TIME, ",
      "gps_id INT, gps_point INT, capture_status CHAR(1), ",
      "UL VARCHAR(10), UL_in VARCHAR(10));"
    ),
    paste0(
      "INSERT INTO ", schema_identifier,
      ".CAPTURES VALUES ",
      "(1,'R_DIRECT','POS_DIRECT','C','CR','2026-10-28',NULL,NULL,NULL,NULL,'F',NULL,NULL),",
      "(2,'R_MISSING',NULL,'C','CR','2026-10-28',NULL,NULL,NULL,NULL,'R',NULL,NULL),",
      "(3,'R_INFER',NULL,'C','CR','2026-10-28',NULL,NULL,7,70,'R',NULL,NULL),",
      "(4,'R_FUTURE','POS_DIRECT','C','CR','2026-10-29',NULL,NULL,8,80,'F',NULL,NULL),",
      "(10,'R_MISSING','POS_DIRECT','J','CR','2026-10-20','10:00:00',NULL,NULL,NULL,'F',NULL,NULL),",
      "(11,'R_INFER','POS_DIRECT','J','CR','2026-10-20','10:00:00',NULL,NULL,NULL,'F',NULL,NULL),",
      "(20,'R_RING','POS_RING','C','CR','2026-10-20','10:00:00',NULL,NULL,NULL,'F',NULL,NULL),",
      "(21,'R_AMBIG','POS_A','C','CR','2026-10-21','10:00:00',NULL,NULL,NULL,'F',NULL,NULL),",
      "(22,'R_AMBIG','POS_B','C','CR','2026-10-21','10:00:00',NULL,NULL,NULL,'F',NULL,NULL);"
    ),
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".RESIGHTINGS (",
      "pk INT, date DATE, gps_id INT, gps_point INT, site VARCHAR(2), ",
      "age CHAR(1), rclass CHAR(1), nest_id VARCHAR(16), ring VARCHAR(50), ",
      "UL VARCHAR(10), UR VARCHAR(10));"
    ),
    paste0(
      "INSERT INTO ", schema_identifier,
      ".RESIGHTINGS VALUES ",
      "(201,'2026-10-28',4,40,'CR','C','V','POS_DIRECT','R_RESIGHT',NULL,NULL),",
      "(202,'2026-10-28',NULL,NULL,'CR','C','V','POS_DIRECT','R_NO_GPS',NULL,NULL),",
      "(203,'2026-10-28',5,50,'CR','C','V',NULL,'R_RING',NULL,NULL),",
      "(204,'2026-10-28',5,51,'CR','C','V',NULL,'R_AMBIG',NULL,NULL),",
      "(205,'2026-10-29',9,90,'CR','C','V','POS_DIRECT','R_FUTURE',NULL,NULL),",
      "(206,'2026-10-28',5,50,'CR','C','H',NULL,'R_RING',NULL,NULL),",
      "(207,'2026-10-28',6,60,'CR','C','V','POS_NEW_FLAG','R_MOVED_FLAG',NULL,NULL),",
      "(208,'2026-10-28',6,61,'CR','C','V','POS_NEW_DEAD','R_MOVED_DEAD',NULL,NULL),",
      "(209,'2026-10-28',5,52,'CR','C','V',NULL,'R_RING',NULL,NULL);"
    ),
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".RESIGHTINGS_H_BROOD_ASSOCIATIONS (",
      "resighting_pk INT, resolved_nest_id VARCHAR(32), ",
      "association_method VARCHAR(64));"
    ),
    paste0(
      "INSERT INTO ", schema_identifier,
      ".RESIGHTINGS_H_BROOD_ASSOCIATIONS VALUES ",
      "(206,NULL,'ambiguous_capture_history');"
    ),
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".tmp_todo_ordinary_family_resighting_associations (",
      "resighting_pk INT, nest_id VARCHAR(32), association_method VARCHAR(64));"
    ),
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".tmp_todo_parent_chick_resighting_associations (",
      "resighting_pk INT, nest_id VARCHAR(32));"
    ),
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".tmp_todo_raw_encounter_nest_consensus (",
      "event_date DATE, gps_id INT, gps_point INT, ",
      "n_explicit_nest_ids INT, explicit_nest_id VARCHAR(32));"
    ),
    paste0(
      "INSERT INTO ", schema_identifier,
      ".tmp_todo_raw_encounter_nest_consensus VALUES ",
      "('2026-10-28',5,51,2,'POS_A'),",
      "('2026-10-28',5,52,1,'POS_OTHER');"
    ),
    capture_events_statement,
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".tmp_todo_chick_capture_targets (",
      "nest_id VARCHAR(32), ring_key VARCHAR(50), ",
      "is_confirmed_dead TINYINT, has_flagged_capture TINYINT);"
    ),
    paste0(
      "INSERT INTO ", schema_identifier,
      ".tmp_todo_chick_capture_targets VALUES ",
      "('OLD_FLAG','R_MOVED_FLAG',0,1),",
      "('OLD_DEAD','R_MOVED_DEAD',1,1);"
    ),
    encounter_statement,
    paste0(
      "SELECT CONCAT_WS('|', event_pk, source_table, nest_id, ",
      "COALESCE(ring_key, 'NULL'), COALESCE(gps_id, 'NULL'), ",
      "COALESCE(gps_point, 'NULL'), is_known_dead, has_flagged_capture) FROM ", schema_identifier,
      ".tmp_todo_chick_encounters ",
      "WHERE event_pk IN (1, 2, 3, 4, 201, 202, 203, 204, 205, 206, 207, 208, 209) ",
      "ORDER BY event_pk;"
    ),
    sep = "\n"
  )

  observed <- trimws(
    run_latest_chick_context_mariadb(socket, setup)
  )
  expect_equal(
    observed,
    paste(
      "1|CAPTURES|POS_DIRECT|R_DIRECT|NULL|NULL|0|0",
      "3|CAPTURES|POS_DIRECT|R_INFER|7|70|0|0",
      "201|RESIGHTINGS|POS_DIRECT|R_RESIGHT|4|40|0|0",
      "203|RESIGHTINGS|POS_RING|R_RING|5|50|0|0",
      "207|RESIGHTINGS|POS_NEW_FLAG|R_MOVED_FLAG|6|60|0|1",
      "208|RESIGHTINGS|POS_NEW_DEAD|R_MOVED_DEAD|6|61|1|1",
      sep = "\n"
    )
  )
})

test_that("invented latest encounters preserve flagged, unflagged, and uncertain identities", {
  socket <- latest_chick_context_socket_or_skip()
  schema_name <- paste0("thread2_latest_chick_", Sys.getpid())
  schema_identifier <- paste0("`", schema_name, "`")
  on.exit(
    try(
      run_latest_chick_context_mariadb(
        socket,
        paste0("DROP DATABASE IF EXISTS ", schema_identifier, ";")
      ),
      silent = TRUE
    ),
    add = TRUE
  )

  view_statement <- extract_temporary_table(
    refresh_chick_context_source_sql(),
    "tmp_todo_chick_latest_encounter_context",
    schema_name
  )
  context_statement <- extract_temporary_table_before(
    refresh_chick_context_source_sql(),
    "tmp_todo_chick_capture_context",
    "SELECT 'TODO_REFRESH_STAGE|chick_capture_context' AS refresh_stage;",
    schema_name
  )
  setup <- paste(
    paste0("CREATE DATABASE ", schema_identifier, ";"),
    paste0("USE ", schema_identifier, ";"),
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".settings (variable VARCHAR(64), value DATE);"
    ),
    paste0(
      "INSERT INTO ", schema_identifier,
      ".settings VALUES ('reference_date', '2026-10-28');"
    ),
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".tmp_todo_chick_encounters (",
      "event_pk INT, event_date DATE, event_datetime DATETIME, ",
      "source_table VARCHAR(16), nest_id VARCHAR(32), gps_id INT, ",
      "gps_point INT, ring_key VARCHAR(50), flag_code VARCHAR(50), ",
      "capture_status CHAR(1), nest_id_source VARCHAR(16), source_rank INT, ",
      "event_identity_key VARCHAR(80), is_unresolved_identity TINYINT, ",
      "is_known_dead TINYINT, has_flagged_capture TINYINT);"
    ),
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".tmp_todo_chick_capture_targets (",
      "nest_id VARCHAR(16), ring_key VARCHAR(50), ",
      "is_confirmed_dead TINYINT, has_flagged_capture TINYINT);"
    ),
    paste0(
      "CREATE TABLE ", schema_identifier,
      ".tmp_todo_chick_capture_context_base (",
      "nest_id VARCHAR(32), n_chick_captures INT, ",
      "n_captured_chick_rings INT, n_flagged_chick_rings INT, ",
      "n_unringed_chick_captures INT, n_dead_chick_rings INT, ",
      "n_active_chick_rings INT, n_active_flagged_chick_rings INT, ",
      "n_active_chick_captures INT, n_unresolved_dead_chick_events INT, ",
      "observed_brood_size INT, latest_brood_count_date DATE, ",
      "n_deaths_after_latest_brood_count INT, ",
      "n_operational_brood_size INT, operational_brood_size_source VARCHAR(64));"
    ),
    paste0(
      "INSERT INTO ", schema_identifier,
      ".tmp_todo_chick_capture_targets VALUES ",
      "('MOCK_FLAGGED','R2',0,1),",
      "('MOCK_UNCERTAIN','R1',0,1),",
      "('MOCK_DEAD','R3',1,1),",
      "('MOCK_TWO','R4',0,1),",
      "('MOCK_TWO','R5',0,0),",
      "('MOCK_DISTINCT','R7',0,1),",
      "('MOCK_DISTINCT','R8',0,0),",
      "('MOCK_CONTRADICT','R9',0,1);"
    ),
    paste0(
      "INSERT INTO ", schema_identifier,
      ".tmp_todo_chick_encounters VALUES ",
      "(1,'2026-10-20','2026-10-20 09:00:00','CAPTURES','MOCK_FLAGGED',2,1,",
      "'R1',NULL,'F','recorded',1,'ring:R1',0,0,0),",
      "(2,'2026-10-27','2026-10-27 10:00:00','RESIGHTINGS','MOCK_FLAGGED',2,2,",
      "'R2',NULL,NULL,'recorded',2,'ring:R2',0,0,1),",
      "(3,'2026-10-28','2026-10-28 08:00:00','CAPTURES','MOCK_UNCERTAIN',2,3,",
      "'R1',NULL,'F','recorded',1,'ring:R1',0,0,1),",
      "(4,'2026-10-28','2026-10-28 08:00:00','RESIGHTINGS','MOCK_UNCERTAIN',2,3,",
      "'R1',NULL,NULL,'recorded',2,'ring:R1',0,0,1),",
      "(5,'2026-10-28','2026-10-28 08:00:00','RESIGHTINGS','MOCK_UNCERTAIN',2,3,",
      "NULL,NULL,NULL,'recorded',2,'resightings:5',1,0,0),",
      "(6,'2026-10-28','2026-10-28 08:00:00','CAPTURES','MOCK_DEAD',2,4,",
      "'R3',NULL,'D','recorded',1,'ring:R3',0,1,1),",
      "(7,'2026-10-29','2026-10-29 08:00:00','RESIGHTINGS','MOCK_FUTURE',2,5,",
      "'R4',NULL,NULL,'recorded',2,'ring:R4',0,0,1),",
      "(8,'2026-10-28','2026-10-28 08:00:00','RESIGHTINGS','MOCK_TWO',2,6,",
      "'R4',NULL,NULL,'recorded',2,'ring:R4',0,0,1),",
      "(9,'2026-10-28','2026-10-28 08:00:00','RESIGHTINGS','MOCK_TWO',2,6,",
      "'R5',NULL,NULL,'recorded',2,'ring:R5',0,0,0),",
      "(10,'2026-10-29','2026-10-29 08:00:00','RESIGHTINGS','MOCK_FUTURE',2,5,",
      "'R5',NULL,NULL,'recorded',2,'ring:R5',0,0,0),",
      "(11,'2026-10-28','2026-10-28 08:00:00','RESIGHTINGS','MOCK_RESIGHT_ONLY',2,7,",
      "'R6',NULL,NULL,'recorded',2,'ring:R6',0,0,0),",
      "(12,'2026-10-28','2026-10-28 08:00:00','CAPTURES','MOCK_DISTINCT',2,8,",
      "'R7',NULL,'F','recorded',1,'ring:R7',0,0,1),",
      "(13,'2026-10-28','2026-10-28 08:00:00','RESIGHTINGS','MOCK_DISTINCT',2,8,",
      "'R8',NULL,NULL,'recorded',2,'ring:R8',0,0,0),",
      "(14,'2026-10-28','2026-10-28 08:00:00','CAPTURES','MOCK_CONTRADICT',2,9,",
      "'R9',NULL,'F','recorded',1,'ring:R9',0,0,1),",
      "(15,'2026-10-28','2026-10-28 08:00:00','RESIGHTINGS','MOCK_CONTRADICT',2,9,",
      "'R9',NULL,NULL,'recorded',2,'resightings:15',1,0,1);"
    ),
    view_statement,
    context_statement,
    paste0(
      "SELECT CONCAT_WS('|', nest_id, DATE_FORMAT(latest_encounter_date, '%Y-%m-%d'),",
      "DATE_FORMAT(latest_encounter_datetime, '%Y-%m-%d %H:%i:%s'),",
      "latest_encounter_count, latest_encounter_flagged_count,",
      "latest_encounter_unflagged_count, latest_encounter_unresolved_count,",
      "latest_encounter_known_dead_count, latest_encounter_is_conservative,",
      "latest_encounter_is_fallback, latest_encounter_availability,",
      "COALESCE(latest_encounter_ring_list, 'NULL'), latest_encounter_source)",
      " FROM ", schema_identifier,
      ".tmp_todo_chick_latest_encounter_context",
      " ORDER BY nest_id;"
    ),
    paste0(
      "SELECT CONCAT_WS('|', nest_id, COALESCE(n_chick_captures, 'NULL'),",
      "COALESCE(latest_encounter_count, 'NULL'),",
      "COALESCE(latest_encounter_availability, 'NULL'))",
      " FROM ", schema_identifier,
      ".tmp_todo_chick_capture_context",
      " WHERE nest_id = 'MOCK_RESIGHT_ONLY';"
    ),
    sep = "\n"
  )

  # Keep invented brood identifiers within the production six-character
  # nest_id contract while retaining readable labels in the fixture source.
  short_nest_ids <- c(
    MOCK_FLAGGED = "FFLAG",
    MOCK_UNCERTAIN = "FUNCRT",
    MOCK_DEAD = "FDEAD",
    MOCK_TWO = "FTWO",
    MOCK_DISTINCT = "FDISTN",
    MOCK_CONTRADICT = "FCONTR",
    MOCK_RESIGHT_ONLY = "FRESIT",
    MOCK_FUTURE = "FFUTUR"
  )
  for (nest_id in names(short_nest_ids)) {
    setup <- gsub(
      nest_id,
      short_nest_ids[[nest_id]],
      setup,
      fixed = TRUE
    )
  }

  observed <- strsplit(trimws(
    run_latest_chick_context_mariadb(socket, setup)
  ), "\n", fixed = TRUE)[[1L]]
  observed <- observed[!grepl("^TODO_REFRESH_STAGE\\|", observed)]
  expect_equal(
    observed[seq_len(7L)],
    c(
      "FCONTR|2026-10-28|2026-10-28 08:00:00|2|1|0|1|0|1|1|conservative|R9|CAPTURES, RESIGHTINGS",
      "FDEAD|2026-10-28|2026-10-28 08:00:00|0|0|0|0|1|1|1|unavailable|NULL|CAPTURES",
      "FDISTN|2026-10-28|2026-10-28 08:00:00|2|1|1|0|0|0|0|available|R7, R8|CAPTURES, RESIGHTINGS",
      "FFLAG|2026-10-27|2026-10-27 10:00:00|1|1|0|0|0|0|0|available|R2|RESIGHTINGS",
      "FRESIT|2026-10-28|2026-10-28 08:00:00|1|0|1|0|0|0|0|available|R6|RESIGHTINGS",
      "FTWO|2026-10-28|2026-10-28 08:00:00|2|1|1|0|0|0|0|available|R4, R5|RESIGHTINGS",
      "FUNCRT|2026-10-28|2026-10-28 08:00:00|2|1|1|1|0|1|1|conservative|R1|CAPTURES, RESIGHTINGS"
    )
  )
  expect_equal(
    observed[[8L]],
    "FRESIT|NULL|1|available"
  )
  expect_false(grepl("FFUTUR", paste(observed, collapse = "\n"), fixed = TRUE))
})
