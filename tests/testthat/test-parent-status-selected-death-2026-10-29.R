library(testthat)

selected_death_source_sql <- function() {
  paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
}

extract_selected_death_cte <- function(sql, name, next_marker) {
  prefix <- paste0(name, " AS (")
  start <- regexpr(prefix, sql, fixed = TRUE)[[1L]]
  stopifnot(start > 0L)
  body_start <- start + nchar(prefix)
  remaining <- substring(sql, start)
  end <- regexpr(next_marker, remaining, fixed = TRUE)[[1L]]
  stopifnot(end > 0L)
  body <- substr(sql, body_start, start + end - 2L)
  paste0(name, " AS (", body, ")")
}

selected_death_values_cte <- function(name, rows) {
  literal <- function(value) {
    if (is.na(value)) return("NULL")
    if (is.numeric(value)) return(as.character(value))
    paste0("'", gsub("'", "''", as.character(value), fixed = TRUE), "'")
  }
  selects <- vapply(seq_len(nrow(rows)), function(i) {
    cells <- vapply(names(rows), function(column) {
      paste(literal(rows[[column]][i]), "AS", column)
    }, character(1))
    paste("SELECT", paste(cells, collapse = ", "))
  }, character(1))
  paste0(name, " AS (", paste(selects, collapse = "\nUNION ALL\n"), ")")
}

selected_death_mariadb_query <- function(sql) {
  socket <- Sys.getenv("THREAD2_TEST_MARIADB_SOCKET", unset = "")
  if (
    Sys.getenv("THREAD2_TEST_MARIADB_DISPOSABLE", unset = "") != "1"
      || !grepl("^(/private)?/tmp/[^/]+\\.sock$", socket)
      || !file.exists(socket)
      || !nzchar(Sys.which("mariadb"))
  ) {
    skip("requires the explicitly selected disposable local MariaDB socket")
  }
  output <- system2(
    Sys.which("mariadb"),
    args = c(
      "--no-defaults", "--batch", "--skip-column-names",
      "--socket", socket, "--user", "root"
    ),
    input = sql,
    stdout = TRUE,
    stderr = TRUE
  )
  if (!is.null(attr(output, "status"))) {
    stop(paste(output, collapse = "\n"))
  }
  output
}

test_that("selected death is projected separately from historical death", {
  sql <- selected_death_source_sql()
  expect_match(
    sql,
    paste0(
      "CASE WHEN by_identity.association_selected = 1\n",
      "        THEN by_identity.is_dead END\n",
      "    ) AS selected_is_dead"
    ),
    fixed = TRUE
  )
  expect_match(
    sql,
    "MAX(by_identity.is_dead) AS any_is_dead",
    fixed = TRUE
  )
  expect_false(grepl("selected_death_by_nest", sql, fixed = TRUE))
  expect_match(
    sql,
    "pivoted.M_selected_is_dead AS M_identity_is_dead",
    fixed = TRUE
  )
  expect_match(
    sql,
    "pivoted.F_selected_is_dead AS F_identity_is_dead",
    fixed = TRUE
  )
  pivoted <- extract_selected_death_cte(sql, "pivoted", ")\nSELECT")
  expect_match(pivoted, "AS M_selected_is_dead", fixed = TRUE)
  expect_match(pivoted, "AS F_selected_is_dead", fixed = TRUE)
  expect_match(sql, "SELECT\n  pivoted.nest_id,", fixed = TRUE)
  expect_false(grepl("SELECT\n  pivoted.*,", sql, fixed = TRUE))
  expect_match(sql, "FROM pivoted\nLEFT JOIN capture_timing", fixed = TRUE)
})

test_that("actual selected-death projection handles competing and ambiguous identities", {
  rows <- data.frame(
    nest_id = c(
      "TEST_COMPETING_DEAD", "TEST_COMPETING_DEAD",
      "TEST_SELECTED_DEAD", "TEST_SELECTED_DEAD",
      "TEST_F_COMPETING_DEAD", "TEST_F_COMPETING_DEAD",
      "TEST_F_SELECTED_DEAD", "TEST_F_SELECTED_DEAD",
      "TEST_AMBIGUOUS", "TEST_AMBIGUOUS",
      "TEST_NO_SELECTED"
    ),
    sex = c("M", "M", "M", "M", "F", "F", "F", "F", "M", "M", "M"),
    identity_key = c(
      "ring:M-LIVE", "ring:M-DEAD",
      "ring:M-DEAD", "ring:M-LIVE",
      "ring:F-LIVE", "ring:F-DEAD",
      "ring:F-DEAD", "ring:F-LIVE",
      "ring:M-A", "ring:M-B", "ring:M-UNKNOWN"
    ),
    parent_mark = c(
      "MLIVE", "MDEAD", "MDEAD", "MLIVE", "FLIVE", "FDEAD",
      "FDEAD", "FLIVE", "MA", "MB", "MUNKNOWN"
    ),
    association_selected = c(1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0),
    association_ambiguous = c(0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1),
    association_pending = c(0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1),
    has_geo = rep(0, 11),
    is_dead = c(0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1),
    is_au_migrant = rep(0, 11),
    single_colour_recruit = rep(0, 11),
    has_mm_capture = rep(0, 11),
    n_nonconfirming_resightings = rep(0, 11),
    n_resightings = rep(0, 11),
    stringsAsFactors = FALSE
  )
  status_by_sex <- extract_selected_death_cte(
    selected_death_source_sql(),
    "status_by_sex",
    "), capture_timing AS ("
  )
  pivoted <- extract_selected_death_cte(
    selected_death_source_sql(),
    "pivoted",
    ")\nSELECT"
  )
  query <- paste(
    "WITH", selected_death_values_cte("fixture", rows), ",",
    "by_identity AS (SELECT * FROM fixture),",
    "units AS (SELECT DISTINCT nest_id, '2026-10-29' AS reference_date FROM by_identity),",
    status_by_sex, ",", pivoted,
    "SELECT CONCAT_WS('|', nest_id,",
    "COALESCE(CAST(M_selected_is_dead AS CHAR), 'NULL'),",
    "COALESCE(CAST(F_selected_is_dead AS CHAR), 'NULL'))",
    "FROM pivoted ORDER BY nest_id;"
  )
  observed <- selected_death_mariadb_query(query)
  expect_identical(observed, c(
    "TEST_AMBIGUOUS|NULL|NULL",
    "TEST_COMPETING_DEAD|0|NULL",
    "TEST_F_COMPETING_DEAD|NULL|0",
    "TEST_F_SELECTED_DEAD|NULL|1",
    "TEST_NO_SELECTED|NULL|NULL",
    "TEST_SELECTED_DEAD|1|NULL"
  ))
})
