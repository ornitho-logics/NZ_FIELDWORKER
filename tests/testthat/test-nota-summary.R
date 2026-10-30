# Invented data only. SELECT fixtures use an explicitly selected disposable
# socket. The separately opted-in DDL check requires an empty owned instance;
# no field records, app or real configuration are loaded.
nota_summary_source <- function() {
  paste(readLines(app_file("DATABASE", "notA_summary.SQL")), collapse = "\n")
}

nota_summary_fixture_sql <- function(state = "succeeded", reference = "2030-12-01",
                                     swap_sexes = FALSE) {
  literal <- function(value) {
    if (is.na(value)) return("NULL")
    paste0("'", gsub("'", "''", as.character(value), fixed = TRUE), "'")
  }
  cte <- function(name, rows) {
    statements <- vapply(seq_len(nrow(rows)), function(i) {
      paste("SELECT", paste(vapply(names(rows), function(column) {
        paste(literal(rows[[column]][i]), "AS", column)
      }, character(1L)), collapse = ", "))
    }, character(1L))
    paste0(name, " AS (", paste(statements, collapse = " UNION ALL "), ")")
  }
  nests <- data.frame(
    nest_id = sprintf("Z90%02d", 1:14),
    reference_date = "2030-12-01", species = "BADO",
    nest_state = c("notA", rep("I", 5), rep("notA", 4), "I", "notA", "I", "I"),
    first_found_date = c("2030-11-01", "2030-11-10", "2030-11-12",
                         "2030-11-13", "2030-10-20", "2030-11-14",
                         rep("2030-11-01", 4), "2030-11-15",
                         "2030-11-01", "2030-11-15", "2030-11-16"),
    last_visit_datetime = "2030-11-20 10:00:00",
    observed_hatch_date = NA_character_, stringsAsFactors = FALSE
  )
  # A closed nest can still have a living brood; keep its hatch evidence.
  nests$observed_hatch_date[1] <- "2030-11-09"
  parents <- data.frame(nest_id = nests$nest_id, reference_date = "2030-12-01")
  for (sex in c("M", "F")) {
    for (field in c("selected_identity_key", "selected_mark", "resight_association_details")) {
      parents[[paste0(sex, "_", field)]] <- NA_character_
    }
    for (field in c("confirmed_unbanded", "resight_association_pending",
                    "resight_association_ambiguous", "mm_resight_pending",
                    "resighting_identity_count", "identity_single_colour_recruit",
                    "identity_is_dead")) {
      parents[[paste0(sex, "_", field)]] <- 0L
    }
  }
  set_parent <- function(row, sex, key, mark) {
    parents[[paste0(sex, "_selected_identity_key")]][row] <<- key
    parents[[paste0(sex, "_selected_mark")]][row] <<- mark
    parents[[paste0(sex, "_resighting_identity_count")]][row] <<- 1L
  }
  set_parent(1, "M", "lower:RY|BY", "RY-BY")
  set_parent(2, "M", "lower:RY|BY", "RY-BY")
  set_parent(1, "F", "ring:FAKE0001", "OY-YG")
  # A different female at the next male nest must not inherit the old female.
  set_parent(2, "F", "ring:FAKE0002", "GY-WY")
  # Same ring, changed display mark: identity, not text, establishes the link.
  for (row in c(3, 4, 5, 6, 8, 9)) {
    set_parent(row, "F", "ring:FAKE0001", "RY-TO.L")
  }
  parents$F_resight_association_pending[4] <- 1L
  parents$reference_date[6] <- "2030-11-30"
  parents$F_resight_association_ambiguous[8] <- 1L
  parents$F_resight_association_details[8] <- "invented competing observations"
  parents$F_mm_resight_pending[9] <- 1L
  parents$F_identity_is_dead[1] <- 1L # Death does not erase historical parentage.
  for (row in c(10, 11)) {
    set_parent(row, "M", "xx:invented-placeholder", "X-X")
    parents$M_confirmed_unbanded[row] <- 1L
  }
  for (row in c(12, 13)) {
    # Unmatched sightings can have shared colours without the recruit flag.
    set_parent(row, "M", "lower:R|X", "R-X")
    parents$M_identity_single_colour_recruit[row] <- 0L
  }
  parents <- parents[parents$nest_id != "Z9007", ] # Keep unknown-parent nests.
  if (swap_sexes) {
    original_names <- names(parents)
    names(parents) <- ifelse(grepl("^M_", original_names),
      sub("^M_", "F_", original_names), sub("^F_", "M_", original_names))
  }
  fixtures <- c(
    cte("fixture_settings", data.frame(variable = "reference_date", value = reference)),
    cte("fixture_refresh", data.frame(refresh_id = c(1L, 2L),
      reference_date = "2030-12-01", state = c("succeeded", state),
      completed_at = "2030-12-01 10:00:00")),
    cte("fixture_nests", nests), cte("fixture_parents", parents)
  )
  sql <- nota_summary_source()
  body <- substring(sql, regexpr("WITH published AS (", sql, fixed = TRUE)[1L] + 5L)
  for (pair in list(
    c("settings", "fixture_settings"), c("TODO_REFRESH_STATUS", "fixture_refresh"),
    c("TODO_NEST_CONTEXT_SNAPSHOT", "fixture_nests"),
    c("TODO_PARENT_STATUS_SNAPSHOT", "fixture_parents")
  )) {
    body <- gsub(paste0("FIELD_2026_BADOatNZ.", pair[1]), pair[2], body, fixed = TRUE)
  }
  paste0("WITH ", paste(fixtures, collapse = ",\n"), ",\n", body)
}

test_that("notA summary reads only published bounded sources", {
  sql <- nota_summary_source()
  body <- substring(sql, regexpr("WITH published AS (", sql, fixed = TRUE)[1L])
  expect_match(sql, "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.notA_summary", fixed = TRUE)
  expect_match(body, "TODO_NEST_CONTEXT_SNAPSHOT", fixed = TRUE)
  expect_match(body, "TODO_PARENT_STATUS_SNAPSHOT", fixed = TRUE)
  expect_false(grepl("ADULT_PARENT_STATUS|ADULT_IDENTITY_MATCHES|_BUILD|_PREVIOUS", body))
  expect_false(grepl("CREATE TABLE|INSERT INTO|UPDATE |DELETE |ALTER TABLE", sql))
  expect_match(body, "SELECT MAX(latest.refresh_id)", fixed = TRUE)
  expect_match(body, "later.first_found_date > original.first_found_date", fixed = TRUE)
})

test_that("the app replaces View2 and watches published summary inputs", {
  expressions <- as.list(parse(app_file("main", "global.R")))
  env <- new.env(parent = baseenv())
  for (name in c("dbtabs_show_views", "dbtabs_show_view_sources")) {
    assignment <- Filter(function(expr) {
      is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
        identical(expr[[2L]], as.name(name))
    }, expressions)
    expect_length(assignment, 1L)
    eval(assignment[[1L]], env)
  }
  expect_contains(env$dbtabs_show_views, "notA_summary")
  expect_false("VIEW_2" %in% env$dbtabs_show_views)
  expect_setequal(env$dbtabs_show_view_sources$notA_summary,
    c("settings", "TODO_REFRESH_STATUS", "TODO_NEST_CONTEXT_SNAPSHOT",
      "TODO_PARENT_STATUS_SNAPSHOT"))
})

test_that("actual notA SQL preserves parent uncertainty and safe later links", {
  socket <- Sys.getenv("THREAD2_TEST_MARIADB_SOCKET", unset = "")
  skip_if(Sys.getenv("THREAD2_TEST_MARIADB_DISPOSABLE", unset = "") != "1" ||
    !grepl("^(/private)?/tmp/[^/]+\\.sock$", socket) || !file.exists(socket) ||
    !nzchar(Sys.which("mariadb")), "requires an explicitly selected disposable local MariaDB")
  query <- function(sql) {
    result <- system2(Sys.which("mariadb"), args = c(
      "--no-defaults", "--batch", "--socket", socket, "--user", "root"
    ), input = sql, stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(result, "status"))) stop(paste(result, collapse = "\n"))
    if (!length(result)) return(data.frame()) # MariaDB prints no header for zero rows.
    utils::read.delim(text = paste(result, collapse = "\n"), na.strings = "NULL",
                      check.names = FALSE, stringsAsFactors = FALSE)
  }
  rows <- query(nota_summary_fixture_sql())
  expect_setequal(rows$nest_id, c("Z9001", "Z9007", "Z9008", "Z9009", "Z9010", "Z9012"))
  expect_false(anyDuplicated(rows$nest_id) > 0L)
  old <- rows[rows$nest_id == "Z9001", ]
  expect_identical(old$male, "RY-BY")
  expect_identical(old$female, "OY-YG")
  expect_identical(old$male_later_confirmed_nests, "Z9002")
  expect_identical(old$female_later_confirmed_nests, "Z9003")
  expect_identical(old$female_status, "resolved")
  expect_identical(as.character(old$observed_hatch_date), "2030-11-09")
  expect_identical(rows$male_status[rows$nest_id == "Z9007"], "unknown")
  expect_identical(rows$female_status[rows$nest_id == "Z9008"], "ambiguous")
  expect_identical(rows$female_status[rows$nest_id == "Z9009"], "pending")
  expect_true(is.na(rows$female[rows$nest_id == "Z9008"]))
  expect_identical(rows$male[rows$nest_id == "Z9010"], "X-X")
  expect_true(is.na(rows$male_later_confirmed_nests[rows$nest_id == "Z9010"]))
  expect_true(is.na(rows$male_later_confirmed_nests[rows$nest_id == "Z9012"]))
  expect_equal(nrow(query(nota_summary_fixture_sql(state = "running"))), 0L)
  expect_equal(nrow(query(nota_summary_fixture_sql(state = "failed"))), 0L)
  expect_equal(nrow(query(nota_summary_fixture_sql(reference = "2030-12-02"))), 0L)
  swapped <- query(nota_summary_fixture_sql(swap_sexes = TRUE))
  old_swapped <- swapped[swapped$nest_id == "Z9001", ]
  expect_identical(old_swapped$female_later_confirmed_nests, "Z9002")
  expect_identical(old_swapped$male_later_confirmed_nests, "Z9003")
  expect_identical(swapped$male_status[swapped$nest_id == "Z9008"], "ambiguous")
})

test_that("the actual view installs against only its small published inputs", {
  socket <- Sys.getenv("THREAD2_TEST_MARIADB_SOCKET", unset = "")
  skip_if(Sys.getenv("NOTA_SUMMARY_EMPTY_INSTANCE_DDL", unset = "") != "1" ||
    Sys.getenv("THREAD2_TEST_MARIADB_DISPOSABLE", unset = "") != "1" ||
    !grepl("^(/private)?/tmp/[^/]+\\.sock$", socket) || !file.exists(socket) ||
    !nzchar(Sys.which("mariadb")), "requires separately approved empty-instance DDL")
  run <- function(sql) {
    result <- system2(Sys.which("mariadb"), args = c(
      "--no-defaults", "--batch", "--skip-column-names",
      "--socket", socket, "--user", "root"
    ), input = sql, stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(result, "status"))) stop(paste(result, collapse = "\n"))
    result
  }
  expect_length(run("SHOW DATABASES LIKE 'FIELD_2026_BADOatNZ';"), 0L)
  run("CREATE DATABASE FIELD_2026_BADOatNZ CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci;")
  fixture <- nota_summary_fixture_sql()
  prefix <- substring(fixture, 1L, regexpr("published AS (", fixture, fixed = TRUE)[1L] - 1L)
  prefix <- sub(",[[:space:]]*$", "", prefix)
  inputs <- c(settings = "fixture_settings", TODO_REFRESH_STATUS = "fixture_refresh",
              TODO_NEST_CONTEXT_SNAPSHOT = "fixture_nests",
              TODO_PARENT_STATUS_SNAPSHOT = "fixture_parents")
  for (table in names(inputs)) {
    run(paste0("CREATE TABLE FIELD_2026_BADOatNZ.", table, " AS ", prefix,
               " SELECT * FROM ", inputs[[table]], ";"))
  }
  run(nota_summary_source())
  expect_identical(run("SELECT COUNT(*) FROM FIELD_2026_BADOatNZ.notA_summary;"), "6")
  expect_length(run("SHOW COLUMNS FROM FIELD_2026_BADOatNZ.notA_summary;"), 15L)
})
