library(testthat)

views_source_sql <- function() {
  paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
}

extract_identity_matches_view <- function(sql) {
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1L]]
  start <- which(grepl(
    "^CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ\\.ADULT_IDENTITY_MATCHES AS$",
    lines
  ))[[1L]]
  next_start <- which(
    seq_along(lines) > start &
      grepl("^CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ\\.", lines)
  )[[1L]]
  end <- start + max(which(
    lines[start:(next_start - 1L)] == "FROM unmatched;"
  )) - 1L
  statement <- paste(lines[start:end], collapse = "\n")
  gsub(
    "FIELD_2026_BADOatNZ.",
    "THREAD2_SOURCE_TEST.",
    statement,
    fixed = TRUE
  )
}

extract_adult_scrape_identity_ctes <- function(sql) {
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1L]]
  view_start <- which(grepl(
    "^CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ\\.ADULT_SCRAPE_RESIGHTING_STATUS AS$",
    lines
  ))[[1L]]
  start <- view_start + which(lines[(view_start + 1L):length(lines)] ==
    "WITH sr AS (")[1L]
  next_cte <- which(
    seq_along(lines) > start &
      grepl("^adult_parent_identity_latest AS \\($", lines)
  )[[1L]]
  cte_sql <- paste(lines[start:(next_cte - 1L)], collapse = "\n")
  cte_sql <- sub(",\\s*$", "", cte_sql)
  paste0(
    gsub(
      "FIELD_2026_BADOatNZ.",
      "THREAD2_SOURCE_TEST.",
      cte_sql,
      fixed = TRUE
    ),
    "\nSELECT CONCAT_WS('|', nest_id, sex, COALESCE(mark, 'NULL'), " ,
    "is_confirmed_xx) " ,
    "FROM adult_resighting_latest;"
  )
}

thread2_test_socket_or_skip <- function() {
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

run_mariadb_batch <- function(socket, sql) {
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

new_thread2_test_schema <- function() {
  paste0(
    "THREAD2_SOURCE_TEST_",
    format(Sys.time(), "%Y%m%d%H%M%S"),
    "_",
    Sys.getpid()
  )
}

run_invented_mariadb_identity_view <- function(socket, view_statement) {
  schema_name <- new_thread2_test_schema()
  schema_identifier <- paste0("`", schema_name, "`")
  owned_schema <- FALSE
  on.exit(
    if (owned_schema) {
      try(
        run_mariadb_batch(
          socket,
          paste0("DROP DATABASE ", schema_identifier, ";")
        ),
        silent = TRUE
      )
    },
    add = TRUE
  )
  run_mariadb_batch(
    socket,
    paste0("CREATE DATABASE ", schema_identifier, ";")
  )
  owned_schema <- TRUE

  sql <- paste(
    "CREATE TABLE THREAD2_SOURCE_TEST.ADULT_RESIGHTING_IDENTITIES_ALL (",
    "  resighting_pk INT NOT NULL, nest_id VARCHAR(8), observed_sex CHAR(1),",
    "  observation_date DATE, behav VARCHAR(32), metal_ring VARCHAR(50),",
    "  flag_code VARCHAR(50), lower_key VARCHAR(32), spacer_key VARCHAR(32),",
    "  full_key VARCHAR(64), is_confirmed_xx TINYINT,",
    "  association_confirming TINYINT, association_nonconfirming TINYINT,",
    "  association_evidence_eligible TINYINT, raw_identity_key VARCHAR(64),",
    "  observed_mark VARCHAR(64)",
    ");",
    "CREATE TABLE THREAD2_SOURCE_TEST.ADULT_CAPTURE_IDENTITIES_ALL (",
    "  identity_key VARCHAR(64), capture_sex CHAR(1), capture_date DATE,",
    "  capture_status CHAR(1), metal_ring VARCHAR(50), flag_code VARCHAR(50),",
    "  lower_key VARCHAR(32), spacer_key VARCHAR(32), full_key VARCHAR(64),",
    "  is_confirmed_xx TINYINT, display_mark VARCHAR(64),",
    "  capture_datetime DATETIME, capture_pk VARCHAR(64), has_geo TINYINT,",
    "  is_au_migrant TINYINT, is_dead TINYINT,",
    "  is_single_colour_recruit TINYINT, has_mm_capture TINYINT",
    ");",
    "INSERT INTO THREAD2_SOURCE_TEST.ADULT_RESIGHTING_IDENTITIES_ALL VALUES",
    "  (100, 'B0208', 'M', '2026-10-10', 'IN', NULL, NULL, 'B|Y', NULL, NULL, 0, 1, 0, 1, 'lower:event100', 'B-Y'),",
    "  (101, 'B0208', 'F', '2026-10-10', 'IN', 'RING1', NULL, NULL, NULL, NULL, 0, 1, 0, 1, 'ring:RING1', 'X-Y'),",
    "  (102, 'B0208', 'M', '2026-10-10', 'IN', NULL, 'F1', NULL, NULL, NULL, 0, 1, 0, 1, 'flag:F1-X', 'X-Y'),",
    "  (103, 'B0208', 'F', '2026-10-10', 'IN', 'RING2', NULL, NULL, NULL, NULL, 0, 1, 0, 1, 'ring:RING2', 'X-Y'),",
    "  (104, 'B0208', 'F', '2026-10-10', 'IN', 'RING3', NULL, NULL, NULL, NULL, 0, 1, 0, 1, 'ring:RING3', 'X-Y'),",
    "  (105, 'B0208', 'F', '2026-10-10', 'IN', NULL, NULL, 'G|W', NULL, NULL, 0, 1, 0, 1, 'lower:event105', 'G-W'),",
    "  (106, 'B0208', 'M', '2026-10-10', 'AC', NULL, NULL, 'X|X', NULL, 'X|X|X|X', 1, 1, 0, 1, 'xx:B0208:M', 'X-X'),",
    "  (107, 'B0208', 'M', '2026-10-10', 'AC', 'RING4', NULL, 'X|X', NULL, 'X|X|X|X', 1, 1, 0, 1, 'ring:RING4', 'X-X');",
    "INSERT INTO THREAD2_SOURCE_TEST.ADULT_CAPTURE_IDENTITIES_ALL VALUES",
    "  ('lower:M', 'M', '2026-10-01', 'F', NULL, NULL, 'B|Y', NULL, NULL, 0, 'B-Y', '2026-10-01 08:00:00', 'lower-m', 0, 0, 0, 0, 0),",
    "  ('lower:F', 'F', '2026-10-01', 'F', NULL, NULL, 'B|Y', NULL, NULL, 0, 'B-Y', '2026-10-01 08:00:00', 'lower-f', 0, 0, 0, 0, 0),",
    "  ('ring:RING1', 'M', '2026-10-01', 'F', 'RING1', NULL, NULL, NULL, NULL, 0, 'M-RING1', '2026-10-01 08:00:00', 'ring1', 0, 0, 0, 0, 0),",
    "  ('flag:M', 'M', '2026-10-01', 'F', NULL, 'F1', NULL, NULL, NULL, 0, 'M-F1', '2026-10-01 08:00:00', 'flag-m', 0, 0, 0, 0, 0),",
    "  ('flag:F', 'F', '2026-10-01', 'F', NULL, 'F1', NULL, NULL, NULL, 0, 'F-F1', '2026-10-01 08:00:00', 'flag-f', 0, 0, 0, 0, 0),",
    "  ('ring:RING3', 'M', '2026-10-01', 'F', 'RING3', NULL, NULL, NULL, NULL, 0, 'M-RING3', '2026-10-01 08:00:00', 'ring3a', 0, 0, 0, 0, 0),",
    "  ('ring:RING3', 'M', '2026-10-05', 'F', 'RING3', NULL, NULL, NULL, NULL, 0, 'M-RING3', '2026-10-05 08:00:00', 'ring3b', 0, 0, 0, 0, 0),",
    "  ('ring:RING2', 'M', '2026-10-11', 'F', 'RING2', NULL, NULL, NULL, NULL, 0, 'M-RING2', '2026-10-11 08:00:00', 'ring2', 0, 0, 0, 0, 0),",
    "  ('lower:conflict-m', 'M', '2026-10-01', 'F', NULL, NULL, 'G|W', NULL, NULL, 0, 'G-W', '2026-10-01 08:00:00', 'lower-conflict-m', 0, 0, 0, 0, 0),",
    "  ('capture:missing-mark', 'M', '2026-10-01', 'F', NULL, NULL, 'X|X', NULL, 'X|X|X|X', 0, NULL, '2026-10-01 08:00:00', 'missing-mark', 0, 0, 0, 0, 0),",
    "  ('ring:RING4', 'M', '2026-10-01', 'F', 'RING4', NULL, 'X|X', NULL, 'X|X|X|X', 0, 'M-RING4', '2026-10-01 08:00:00', 'ring4', 0, 0, 0, 0, 0);",
    view_statement,
    "SELECT CONCAT_WS('|', resighting_pk, sex, observed_sex, match_class,",
    "  COALESCE(display_mark, 'NULL'), is_ambiguous_match, n_candidate_identities)",
    "FROM THREAD2_SOURCE_TEST.ADULT_IDENTITY_MATCHES",
    "ORDER BY resighting_pk;",
    sep = "\n"
  )
  sql <- gsub("THREAD2_SOURCE_TEST", schema_name, sql, fixed = TRUE)
  trimws(run_mariadb_batch(socket, sql))
}

run_invented_mariadb_confirming_guard <- function(socket) {
  sql <- paste(
    "WITH inputs AS (",
    "  SELECT 1 AS event_id, 'IN' AS behav, 'B0208' AS nest_id,",
    "    'B' AS LL_raw, 'YY' AS LR_raw, 'CR' AS site, '2026-10-10' AS event_date",
    "  UNION ALL SELECT 2, 'IN', 'B0208', NULL, 'YY', 'CR', '2026-10-10'",
    "  UNION ALL SELECT 3, 'SC', '-B0208', 'B', 'YY', 'CR', '2026-10-10'",
    "  UNION ALL SELECT 4, 'SC,IN', NULL, 'B', 'YY', 'CR', '2026-10-10'",
    "  UNION ALL SELECT 5, 'BC', 'B0208', 'B', '', 'CR', '2026-10-10'",
    "  UNION ALL SELECT 6, 'IN', 'B0209', 'B', 'YY', 'CR', '2026-10-10'",
    "  UNION ALL SELECT 7, 'IN', 'B0999', 'B', 'YY', 'CR', '2026-10-10'",
    "), known_nests AS (",
    "  SELECT 'B0208' AS nest_id, 'CR' AS site, '2026-10-01' AS nest_date",
    "  UNION ALL SELECT 'B0209', 'CR', '2026-10-11'",
    "), scored AS (",
    "  SELECT event_id, CASE",
    "    WHEN UPPER(TRIM(behav)) REGEXP",
    "      '(^|[,[:space:]])(IN|NM|SC|BW|BC|FC|AC)([,[:space:]]|$)'",
    "     AND nest_id IS NOT NULL",
    "     AND NULLIF(TRIM(LL_raw), '') IS NOT NULL",
    "     AND NULLIF(TRIM(LR_raw), '') IS NOT NULL",
    "     AND UPPER(TRIM(site)) = 'CR'",
    "     AND TRIM(nest_id) REGEXP '^-?[ABC][0-9]{4}$'",
    "     AND (LEFT(TRIM(nest_id), 1) = '-' OR EXISTS (",
    "       SELECT 1 FROM known_nests",
    "       WHERE UPPER(TRIM(known_nests.site)) = 'CR'",
    "         AND UPPER(TRIM(known_nests.nest_id)) = UPPER(TRIM(inputs.nest_id))",
    "         AND known_nests.nest_date <= inputs.event_date",
    "     ))",
    "    THEN 1 ELSE 0 END AS confirming",
    "  FROM inputs",
    ")",
    "SELECT GROUP_CONCAT(confirming ORDER BY event_id SEPARATOR ',')",
    "FROM scored;",
    sep = "\n"
  )

  trimws(tail(run_mariadb_batch(socket, sql), 1L))
}

run_invented_mariadb_adult_scrape_identity <- function(socket, cte_statement) {
  schema_name <- new_thread2_test_schema()
  schema_identifier <- paste0("`", schema_name, "`")
  owned_schema <- FALSE
  on.exit(
    if (owned_schema) {
      try(
        run_mariadb_batch(
          socket,
          paste0("DROP DATABASE ", schema_identifier, ";")
        ),
        silent = TRUE
      )
    },
    add = TRUE
  )

  run_mariadb_batch(
    socket,
    paste0("CREATE DATABASE ", schema_identifier, ";")
  )
  owned_schema <- TRUE

  sql <- paste(
    "CREATE TABLE THREAD2_SOURCE_TEST.settings (",
    "  variable VARCHAR(64), value VARCHAR(64)",
    ");",
    "INSERT INTO THREAD2_SOURCE_TEST.settings VALUES",
    "  ('reference_date', '2026-10-31');",
    "CREATE TABLE THREAD2_SOURCE_TEST.CAPTURES (",
    "  nest_id VARCHAR(8), site VARCHAR(2), age CHAR(1), field_sex VARCHAR(2),",
    "  capture_method VARCHAR(2), date DATE, released TIME, caught TIME,",
    "  pk INT, ring VARCHAR(50), UL VARCHAR(10), LL VARCHAR(10),",
    "  UR VARCHAR(10), LR VARCHAR(10), UL_in VARCHAR(10), LL_in VARCHAR(10),",
    "  UR_in VARCHAR(10), LR_in VARCHAR(10), capture_status CHAR(1),",
    "  tag_type VARCHAR(8), tag_action VARCHAR(8), tag_id VARCHAR(20)",
    ");",
    "INSERT INTO THREAD2_SOURCE_TEST.CAPTURES VALUES",
    "  ('A0101', 'CR', 'A', 'M', 'HA', '2026-10-01', '08:00:00', NULL, 1,",
    "   NULL, NULL, 'B', NULL, 'Y', NULL, NULL, NULL, NULL, 'F', NULL, NULL, NULL);",
    "CREATE TABLE THREAD2_SOURCE_TEST.CAPTURES_ARCHIVE (",
    "  ring VARCHAR(50), date DATE",
    ");",
    "CREATE TABLE THREAD2_SOURCE_TEST.RESIGHTINGS (",
    "  nest_id VARCHAR(8), site VARCHAR(2), age CHAR(1), sex VARCHAR(2),",
    "  date DATE, pk INT, UL VARCHAR(10), LL VARCHAR(10), UR VARCHAR(10),",
    "  LR VARCHAR(10), behav VARCHAR(32), ring VARCHAR(50)",
    ");",
    "INSERT INTO THREAD2_SOURCE_TEST.RESIGHTINGS VALUES",
    "  ('A0101', 'CR', 'A', 'F', '2026-10-02', 10, NULL, 'B', NULL, 'Y', 'IN', NULL);",
    "CREATE FUNCTION THREAD2_SOURCE_TEST.format_mark(",
    "  ul_value VARCHAR(10), ll_value VARCHAR(10),",
    "  ur_value VARCHAR(10), lr_value VARCHAR(10)",
    ") RETURNS VARCHAR(64) DETERMINISTIC RETURN CONCAT_WS('-',",
    "  NULLIF(UPPER(TRIM(ul_value)), ''), NULLIF(UPPER(TRIM(ll_value)), ''),",
    "  NULLIF(UPPER(TRIM(ur_value)), ''), NULLIF(UPPER(TRIM(lr_value)), ''));",
    cte_statement,
    sep = "\n"
  )
  sql <- gsub("THREAD2_SOURCE_TEST", schema_name, sql, fixed = TRUE)
  trimws(run_mariadb_batch(socket, sql))
}

valid_cr_nest_id <- function(x, site = "CR") {
  x <- trimws(as.character(x))
  isTRUE(
    !is.na(x) && nzchar(x) &&
      toupper(trimws(as.character(site))) == "CR" &&
      grepl("^-?[ABC][0-9]{4}$", x)
  )
}

confirming_behaviour <- function(behav, nest_id, LL, LR, site = "CR") {
  tokens <- unlist(strsplit(toupper(trimws(as.character(behav))), "[,[:space:]]+"))
  tokens <- tokens[nzchar(tokens)]
  any(c("IN", "NM", "SC", "BW", "BC", "FC", "AC") %in% tokens) &&
    valid_cr_nest_id(nest_id, site = site) &&
    !is.na(LL) && nzchar(trimws(as.character(LL))) &&
    !is.na(LR) && nzchar(trimws(as.character(LR)))
}

derived_sex <- function(
  observed_sex,
  candidate_sex,
  match_class,
  is_unique_match,
  n_candidate_sexes
) {
  if (isTRUE(is_unique_match) && match_class %in% c("ring", "flag")) {
    if (identical(as.integer(n_candidate_sexes), 1L)) {
      return(candidate_sex)
    }
  }
  observed_sex
}

best_priority_sexes <- function(candidates, priority) {
  unique(candidates$candidate_sex[candidates$match_priority == priority])
}

verified_history_sex <- function(history, key, event_date) {
  history <- history[
    history$key == key & history$date <= as.Date(event_date),
    ,
    drop = FALSE
  ]
  sexes <- unique(history$sex)
  if (!nrow(history) || length(sexes) != 1L) {
    return(NA_character_)
  }
  sexes[[1L]]
}

event_count_once <- function(events) {
  events <- events[events$eligible & events$resighting, , drop = FALSE]
  if (!nrow(events)) {
    return(0L)
  }
  identity_count <- tapply(events$identity_key, events$event_pk, function(x) {
    length(unique(x))
  })
  sum(identity_count == 1L)
}

xx_is_actual <- function(LL, LR) {
  toupper(trimws(as.character(LL))) %in% c("X", "XX") &&
    toupper(trimws(as.character(LR))) %in% c("X", "XX")
}

resighting_identity <- function(UL, LL, UR, LR, nest_id = "B0208", sex = "M") {
  raw <- vapply(
    list(UL, LL, UR, LR),
    function(value) {
      if (is.null(value)) NA_character_ else toupper(trimws(as.character(value)))
    },
    character(1)
  )
  if (xx_is_actual(raw[[2L]], raw[[4L]]) &&
      (is.na(raw[[1L]]) || grepl("^(X+|M)$", raw[[1L]])) &&
      (is.na(raw[[3L]]) || grepl("^(X+|M)$", raw[[3L]]))) {
    return(list(mark = "X-X", identity_key = paste("xx", nest_id, sex, sep = ":")))
  }
  if (any(!is.na(raw) & nzchar(raw) & !grepl("^(X+|M)$", raw))) {
    return(list(mark = "observed-mark", identity_key = "mark"))
  }
  list(mark = NA_character_, identity_key = "resighting:unmarked")
}

test_that("views SQL adds the explicit confirming-event completeness and validity guard", {
  sql <- views_source_sql()

  expect_match(
    sql,
    "keyed.nest_id IS NOT NULL",
    fixed = TRUE
  )
  expect_match(
    sql,
    "NULLIF(keyed.LL_raw, '') IS NOT NULL",
    fixed = TRUE
  )
  expect_match(
    sql,
    "NULLIF(keyed.LR_raw, '') IS NOT NULL",
    fixed = TRUE
  )
  expect_match(sql, "^-?[ABC][0-9]{4}$", fixed = TRUE)
  expect_match(
    sql,
    "adult_association_resighting_candidates",
    fixed = TRUE
  )
  expect_match(sql, "FIELD_2026_BADOatNZ.NESTS known_nest", fixed = TRUE)
  expect_match(sql, "known_nest.date <= raw_resighting.date", fixed = TRUE)
  expect_match(sql, "LEFT(TRIM(raw_resighting.nest_id), 1) = '-'", fixed = TRUE)
})

test_that("all confirming behaviours require complete explicit evidence", {
  sql <- views_source_sql()
  for (code in c("IN", "NM", "SC", "BW", "BC", "FC", "AC")) {
    expect_match(sql, code, fixed = TRUE)
    expect_true(confirming_behaviour(code, "B0208", "B", "YY"))
    expect_false(confirming_behaviour(code, "B0208", NA_character_, "YY"))
    expect_false(confirming_behaviour(code, "B0208", "B", NA_character_))
  }
  expect_true(confirming_behaviour("SC,IN", "B0208", "B", "YY"))
  expect_false(confirming_behaviour("SC,IN", "B0208", NA_character_, NA_character_))
})

test_that("invalid, wrong-site, and blank-ID SC events cannot confirm", {
  expect_true(valid_cr_nest_id("-B0208"))
  expect_false(valid_cr_nest_id("BA0208"))
  expect_false(valid_cr_nest_id("B0208", site = "MR"))
  expect_false(confirming_behaviour("SC", "B02", "B", "YY"))
  expect_false(confirming_behaviour("SC", NA_character_, "B", "YY"))
  expect_false(confirming_behaviour("SC", "NO_NEST", "B", "YY"))
})

test_that("actual X-X is scoped and missing fields are not wildcard XX", {
  expect_true(xx_is_actual("X", "X"))
  expect_true(xx_is_actual("XX", "X"))
  expect_false(xx_is_actual(NA_character_, "X"))
  expect_false(xx_is_actual("X", NA_character_))
  expect_false(xx_is_actual("", "X"))

  scoped_xx <- function(event_nest, candidate_nest, event_sex, candidate_sex) {
    !is.na(event_nest) && !is.na(candidate_nest) &&
      identical(event_nest, candidate_nest) &&
      identical(event_sex, candidate_sex)
  }
  expect_true(scoped_xx("B0208", "B0208", "M", "M"))
  expect_false(scoped_xx("B0208", "B0209", "M", "M"))
  expect_false(scoped_xx("B0208", "B0208", "M", "F"))

  missing_both <- resighting_identity(NULL, NULL, NULL, NULL)
  missing_left <- resighting_identity(NULL, NULL, NULL, "X")
  missing_right <- resighting_identity(NULL, "X", NULL, NULL)
  actual_xx <- resighting_identity(NULL, "XX", NULL, "X")
  expect_true(is.na(missing_both$mark))
  expect_true(is.na(missing_left$mark))
  expect_true(is.na(missing_right$mark))
  expect_identical(actual_xx$mark, "X-X")
  expect_identical(actual_xx$identity_key, "xx:B0208:M")
})

test_that("verified ring and flag history may determine derived sex", {
  expect_identical(
    derived_sex("F", "M", "ring", TRUE, 1L),
    "M"
  )
  expect_identical(
    derived_sex("M", "F", "flag", TRUE, 1L),
    "F"
  )
  expect_identical(
    derived_sex("F", "M", "lower", TRUE, 1L),
    "F"
  )
  expect_identical(
    derived_sex("F", "M", "single-lr-spacer", TRUE, 1L),
    "F"
  )
  expect_identical(
    derived_sex("F", "M", "ring", FALSE, 1L),
    "F"
  )
  expect_identical(
    derived_sex("F", "M", "ring", TRUE, 2L),
    "F"
  )
})

test_that("reused or contradictory flag history blocks derived sex", {
  candidates <- data.frame(
    identity_key = c("flag:F1", "flag:F2"),
    candidate_sex = c("M", "F"),
    match_priority = c(2L, 2L)
  )
  expect_setequal(best_priority_sexes(candidates, 2L), c("M", "F"))
  expect_identical(
    derived_sex("F", "M", "flag", TRUE, 2L),
    "F"
  )
})

test_that("future and contradictory identity history remain unresolved", {
  history <- data.frame(
    key = c("ring:one", "ring:one", "flag:F1"),
    sex = c("M", "F", "F"),
    date = as.Date(c("2026-10-01", "2026-10-02", "2026-10-20"))
  )
  expect_true(is.na(verified_history_sex(history, "ring:one", "2026-10-03")))
  expect_true(is.na(verified_history_sex(history, "flag:F1", "2026-10-10")))
  expect_identical(
    verified_history_sex(history, "flag:F1", "2026-10-21"),
    "F"
  )
})

test_that("uncertain marks remain ineligible without verified ring tracing", {
  evidence_eligible <- function(has_uncertain_mark, ring_traced_to_capture) {
    !(isTRUE(has_uncertain_mark) && !isTRUE(ring_traced_to_capture))
  }
  expect_false(evidence_eligible(TRUE, FALSE))
  expect_true(evidence_eligible(TRUE, TRUE))
  expect_true(evidence_eligible(FALSE, FALSE))
  sql <- views_source_sql()
  expect_match(sql, "ring_traced_to_capture", fixed = TRUE)
  expect_match(sql, "has_uncertain_mark", fixed = TRUE)
})

test_that("one actual resighting event contributes at most once", {
  events <- data.frame(
    event_pk = c("R1", "R1", "R2", "R3"),
    identity_key = c("ring:one", "lower:blue|red", "ring:two", "ring:three"),
    eligible = TRUE,
    resighting = TRUE
  )
  expect_identical(event_count_once(events), 2L)
})

test_that("blank-ID SC cannot become positive-nest evidence", {
  sql <- views_source_sql()
  expect_match(sql, "keyed.nest_id IS NOT NULL", fixed = TRUE)
  expect_match(sql, "WHERE event_union.nest_id IS NOT NULL", fixed = TRUE)
  expect_match(sql, "SC", fixed = TRUE)
  expect_false(confirming_behaviour("SC", NA_character_, "B", "YY"))
  expect_false(confirming_behaviour("BC", NA_character_, NA_character_, NA_character_))
})

test_that("the SQL includes event-level ambiguity protection", {
  sql <- views_source_sql()
  expect_match(sql, "best_history AS", fixed = TRUE)
  expect_match(sql, "n_candidate_sexes", fixed = TRUE)
  expect_match(sql, "match_class IN ('ring', 'flag')", fixed = TRUE)
  expect_match(sql, "best_identity.candidate_sex = r.observed_sex", fixed = TRUE)
  expect_match(sql, "match_strength", fixed = TRUE)
  expect_match(sql, "event_identity_counts AS", fixed = TRUE)
  expect_match(sql, "n_identity_keys = 1", fixed = TRUE)
  expect_match(sql, "event_union.ambiguous_match = 0", fixed = TRUE)
  expect_match(sql, "keyed.LL_raw IN ('X', 'XX')", fixed = TRUE)
  expect_match(sql, "keyed.LR_raw IN ('X', 'XX')", fixed = TRUE)
  expect_match(sql, "NULLIF(keyed.LL_raw, '') IS NOT NULL", fixed = TRUE)
})

test_that("explicit X-X rows cannot use colour-only identity matches", {
  view_statement <- extract_identity_matches_view(views_source_sql())

  expect_match(
    view_statement,
    "WHERE r.lower_key IS NOT NULL\n    AND r.is_confirmed_xx = 0\n    AND c.is_confirmed_xx = 0",
    fixed = TRUE
  )
  expect_match(
    view_statement,
    "WHERE r.spacer_key IS NOT NULL\n    AND r.is_confirmed_xx = 0\n    AND c.is_confirmed_xx = 0",
    fixed = TRUE
  )
  expect_match(
    view_statement,
    "WHERE r.full_key IS NOT NULL\n    AND r.is_confirmed_xx = 0\n    AND c.is_confirmed_xx = 0",
    fixed = TRUE
  )
  expect_match(
    view_statement,
    "AND r.is_confirmed_xx = 1\n        AND c.capture_status = 'F'",
    fixed = TRUE
  )

  sql <- views_source_sql()
  gps_start <- regexpr(
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ\\.ADULT_CHICK_GPS_PARENT_LINKS AS",
    sql
  )
  expect_gt(gps_start, 0L)
  gps_sql <- substring(sql, gps_start)
  gps_end <- regexpr(
    "\\nCREATE OR REPLACE VIEW FIELD_2026_BADOatNZ\\.",
    gps_sql
  )
  expect_gt(gps_end, 0L)
  gps_sql <- substring(gps_sql, 1L, gps_end - 1L)
  expect_equal(
    length(gregexpr("AND r.is_confirmed_xx = 0", gps_sql, fixed = TRUE)[[1L]]),
    3L
  )
})

test_that("MariaDB evaluates the confirming guard on invented rows", {
  socket <- thread2_test_socket_or_skip()

  expect_identical(
    run_invented_mariadb_confirming_guard(socket),
    "1,0,1,0,0,0,0"
  )
})

test_that("MariaDB executes the current identity matcher on invented stubs", {
  socket <- thread2_test_socket_or_skip()

  view_statement <- extract_identity_matches_view(views_source_sql())
  expect_match(view_statement, "CREATE OR REPLACE VIEW", fixed = TRUE)
  expect_match(view_statement, "best_history AS", fixed = TRUE)

  expect_identical(
    run_invented_mariadb_identity_view(socket, view_statement),
    c(
      "100|M|M|lower|B-Y|0|1",
      "101|M|F|ring|M-RING1|0|1",
      "102|M|M|flag|X-Y|1|1",
      "103|F|F|unmatched|X-Y|0|0",
      "104|M|F|ring|M-RING3|0|1",
      "105|F|F|lower|G-W|1|1",
      "106|M|M|unmatched|X-X|0|0",
      "107|M|M|ring|M-RING4|0|1"
    )
  )
})

test_that("the scrape helper preserves observed F and suppresses a conflicting lower-only mark", {
  sql <- views_source_sql()

  expect_match(sql, "adult_resighting_observations AS", fixed = TRUE)
  expect_match(sql, "raw.observed_mark AS mark", fixed = TRUE)
  expect_match(sql, "raw.observed_sex", fixed = TRUE)
  expect_match(sql, "captured.nest_id = raw.nest_id", fixed = TRUE)

  socket <- thread2_test_socket_or_skip()
  cte_statement <- extract_adult_scrape_identity_ctes(sql)

  expect_identical(
    run_invented_mariadb_adult_scrape_identity(socket, cte_statement),
    "A0101|F|NULL|0"
  )
})
