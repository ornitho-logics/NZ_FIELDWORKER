library(testthat)

# Execute the actual association SELECT with invented input CTEs, not a second
# R implementation of the association rules. No schema or records are written.
mm_xx_query <- function(captures, sightings, reference_date = "2026-10-31", include_display = FALSE) {
  sql <- paste(readLines(app_file("DATABASE", "views.SQL"), warn = FALSE), collapse = "\n")
  start <- regexpr("CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_PARENT_NEST_ASSOCIATIONS AS", sql, fixed = TRUE)[[1L]]
  stopifnot(start > 0L)
  statement <- substring(sql, start)
  ending <- "\nFROM classified;"
  finish <- regexpr(ending, statement, fixed = TRUE)[[1L]]
  stopifnot(finish > 0L)
  statement <- substr(statement, 1L, finish + nchar(ending) - 2L)
  statement <- sub("^[\\s\\S]*?\\bWITH\\s+", "", statement, perl = TRUE)
  statement <- gsub("FIELD_2026_BADOatNZ.", "", statement, fixed = TRUE)
  for (name in c("ADULT_CAPTURE_IDENTITIES", "ADULT_IDENTITY_MATCHES", "ADULT_CHICK_GPS_PARENT_LINKS_INPUT")) {
    statement <- gsub(name, tolower(name), statement, fixed = TRUE)
  }
  projection <- regexpr("\nSELECT\n  classified.nest_id,", statement, fixed = TRUE)[[1L]]
  stopifnot(projection > 0L)
  ctes <- substr(statement, 1L, projection - 1L)
  result_select <- substring(statement, projection)
  values <- function(name, rows) {
    literal <- function(x) {
      if (is.na(x)) return("NULL")
      if (is.numeric(x)) return(as.character(x))
      paste0("'", gsub("'", "''", as.character(x), fixed = TRUE), "'")
    }
    selects <- vapply(seq_len(nrow(rows)), function(i) {
      paste("SELECT", paste(vapply(names(rows), function(column) {
        paste(literal(rows[[column]][i]), "AS", column)
      }, character(1)), collapse = ", "))
    }, character(1))
    paste0(name, " AS (", paste(selects, collapse = "\nUNION ALL\n"), ")")
  }
  paste(
    "WITH", values("capture_fixture", captures), ",",
    values("sighting_fixture", sightings), ",",
    "adult_capture_identities AS (SELECT * FROM capture_fixture WHERE capture_date <=", shQuote(reference_date), "),",
    "adult_identity_matches AS (SELECT * FROM sighting_fixture WHERE observation_date <=", shQuote(reference_date), "),",
    "adult_chick_gps_parent_links_input AS (SELECT capture_fixture.* FROM capture_fixture WHERE 1=0),",
    ctes, ", actual_associations AS (", result_select, ")",
    "SELECT CONCAT_WS('|', identity_key, association_level, association_selected, association_pending,",
    paste0("COALESCE(CAST(association_evidence_datetime AS CHAR), 'NULL'), n_nonconfirming_resightings",
      if (include_display) ", COALESCE(association_display_basis, 'NULL')" else "", ")"),
    "FROM actual_associations ORDER BY identity_key;"
  )
}

mm_xx_execute <- function(query) {
  socket <- Sys.getenv("THREAD2_TEST_MARIADB_SOCKET", unset = "")
  if (Sys.getenv("THREAD2_TEST_MARIADB_DISPOSABLE", unset = "") != "1" ||
      !grepl("^(/private)?/tmp/[^/]+\\.sock$", socket) || !file.exists(socket) ||
      !nzchar(Sys.which("mariadb"))) {
    skip("requires explicitly selected disposable local MariaDB, no defaults")
  }
  result <- system2(Sys.which("mariadb"), c("--no-defaults", "--batch", "--skip-column-names", "--host=localhost", "--protocol=SOCKET", paste0("--socket=", socket), "--user=root", "--database=information_schema"),
                    input = query, stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status"))) stop(paste(tail(result, 5L), collapse = "\n"))
  result
}

mm_xx_capture <- function(identity, day, sex = "M", status = "F", method = "MM") {
  data.frame(nest_id = "MOCK_NEST", capture_sex = sex, identity_key = identity,
    capture_pk = paste(identity, day), capture_date = sprintf("2026-10-%02d", day),
    capture_datetime = sprintf("2026-10-%02d 10:00:00", day),
    capture_status = status, capture_method = method, is_confirmed_xx = 0, association_evidence_eligible = 1,
    display_mark = identity, has_geo = 0, is_au_migrant = 0, is_dead = 0,
    is_single_colour_recruit = 0, definitive_capture = as.integer(method == "TN"),
    has_mm_capture = as.integer(method == "MM"), stringsAsFactors = FALSE)
}

mm_xx_sighting <- function(identity, day, sex = "M", confirming = FALSE, pk = day, ambiguous = FALSE) {
  data.frame(nest_id = "MOCK_NEST", sex = sex, identity_key = identity,
    resighting_pk = pk, observation_date = sprintf("2026-10-%02d", day),
    behav = if (confirming) "IN" else "AT",
    display_mark = identity, has_geo = 0, is_au_migrant = 0, is_dead = 0,
    is_single_colour_recruit = 0, association_evidence_eligible = 1,
    association_confirming = as.integer(confirming),
    association_nonconfirming = as.integer(!confirming),
    is_ambiguous_match = as.integer(ambiguous), stringsAsFactors = FALSE)
}

test_that("actual SQL display provenance follows the existing winning association gate", {
  for (sex in c("M", "F")) {
    capture <- mm_xx_capture("ring:MOCK_DISPLAY", 3, sex)
    for (behav in c("IN", "NM", "SC", "BW", "BC", "FC", "AC", "AT, IN")) {
      sighting <- mm_xx_sighting("ring:MOCK_DISPLAY", 4, sex, TRUE)
      sighting$behav <- behav
      expected <- if (behav == "AT, IN") "IN" else behav
      result <- mm_xx_execute(mm_xx_query(capture, sighting, include_display = TRUE))
      expect_true(endsWith(result, paste0("|0|", expected)))
    }
    sighting <- mm_xx_sighting("ring:MOCK_DISPLAY", 4, sex, TRUE)
    tn <- transform(capture, capture_method = "TN", definitive_capture = 1L, has_mm_capture = 0L)
    expect_true(endsWith(mm_xx_execute(mm_xx_query(tn, sighting, include_display = TRUE)), "|0|TN"))
    repeated <- do.call(rbind, lapply(4:6, function(day) mm_xx_sighting("ring:MOCK_DISPLAY", day, sex)))
    expect_true(endsWith(mm_xx_execute(mm_xx_query(capture, repeated, include_display = TRUE)), "|3|3"))
    expect_true(endsWith(mm_xx_execute(mm_xx_query(capture, repeated[1:2, ], include_display = TRUE)), "|2|NULL"))
    xx <- mm_xx_sighting(paste0("xx:MOCK_NEST:", sex), 3, sex, TRUE)
    expect_true(endsWith(mm_xx_execute(mm_xx_query(capture, xx, include_display = TRUE)), "|0|IN"))
  }
})

test_that("actual SQL preserves identified pre-MM evidence independently for both sexes", {
  for (sex in c("M", "F")) {
    capture <- mm_xx_capture("ring:MOCK_A", 3, sex, status = "R")
    expect_identical(mm_xx_execute(mm_xx_query(capture,
      mm_xx_sighting("ring:MOCK_A", 1, sex, TRUE))),
      "ring:MOCK_A|2|1|0|2026-10-01 00:00:00|0")
    sightings <- do.call(rbind, lapply(c(1, 2, 4), function(day) mm_xx_sighting("ring:MOCK_A", day, sex)))
    expect_identical(mm_xx_execute(mm_xx_query(capture, sightings)),
      "ring:MOCK_A|1|1|0|2026-10-04 00:00:00|3")
    capture$definitive_capture <- 1L
    expect_identical(mm_xx_execute(mm_xx_query(capture, sightings)),
      "ring:MOCK_A|3|1|0|2026-10-03 10:00:00|3")
  }
})

test_that("actual SQL keeps X-X separate until the newly marked bird earns its own proof", {
  for (sex in c("M", "F")) {
    xx <- paste0("xx:MOCK_NEST:", sex)
    captures <- rbind(mm_xx_capture("ring:MOCK_A", 1, sex), mm_xx_capture("ring:MOCK_B", 3, sex))
    old_xx <- mm_xx_sighting(xx, 2, sex, TRUE)
    for (days in list(integer(), 4L, c(4L, 5L))) {
      sightings <- old_xx
      for (day in days) sightings <- rbind(sightings, mm_xx_sighting("ring:MOCK_B", day, sex))
      expected <- c("ring:MOCK_A|0|0|0|NULL|0", paste0("ring:MOCK_B|0|0|0|NULL|", length(days)),
        paste0(xx, "|2|1|0|2026-10-02 00:00:00|0"))
      expect_identical(mm_xx_execute(mm_xx_query(captures, sightings)), expected)
    }
    three <- rbind(old_xx, do.call(rbind, lapply(4:6, function(day) mm_xx_sighting("ring:MOCK_B", day, sex))))
    expect_identical(mm_xx_execute(mm_xx_query(captures, three)), c(
      "ring:MOCK_A|0|0|0|NULL|0", "ring:MOCK_B|1|1|0|2026-10-06 00:00:00|3"))
    one <- rbind(old_xx, mm_xx_sighting("ring:MOCK_B", 4, sex, TRUE))
    expect_identical(mm_xx_execute(mm_xx_query(captures, one)), c(
      "ring:MOCK_A|0|0|0|NULL|0", "ring:MOCK_B|2|1|0|2026-10-04 00:00:00|0"))
    expect_identical(mm_xx_execute(mm_xx_query(captures, three, "2026-10-05")), c(
      "ring:MOCK_A|0|0|0|NULL|0", "ring:MOCK_B|0|0|0|NULL|2",
      paste0(xx, "|2|1|0|2026-10-02 00:00:00|0")))
    duplicated <- rbind(old_xx, mm_xx_sighting("ring:MOCK_B", 4, sex), mm_xx_sighting("ring:MOCK_B", 4, sex), mm_xx_sighting("ring:MOCK_B", 5, sex))
    expect_identical(mm_xx_execute(mm_xx_query(captures, duplicated)), c(
      "ring:MOCK_A|0|0|0|NULL|0", "ring:MOCK_B|0|0|0|NULL|2",
      paste0(xx, "|2|1|0|2026-10-02 00:00:00|0")))
  }
})

test_that("different-day X-X replacement rejects ambiguous, wrong-sex, and recapture evidence", {
  capture <- mm_xx_capture("ring:MOCK_B", 3)
  old_xx <- mm_xx_sighting("xx:MOCK_NEST:M", 2, confirming = TRUE)
  proof <- mm_xx_sighting("ring:MOCK_B", 4, confirming = TRUE)
  cases <- list(
    ambiguous = list(capture, transform(proof, is_ambiguous_match = 1L), old_xx),
    wrong_sex = list(capture, transform(proof, sex = "F"), old_xx),
    recapture = list(transform(capture, capture_status = "R"), proof, old_xx)
  )
  for (case in cases) {
    observed <- mm_xx_execute(mm_xx_query(case[[1L]], rbind(case[[3L]], case[[2L]])))
    expect_true(any(startsWith(observed, "xx:MOCK_NEST:M|2|")))
  }
})

test_that("same-day confirming X-X targets one first-marked bird without later proof", {
  for (sex in c("M", "F")) {
    xx <- paste0("xx:MOCK_NEST:", sex)
    sighting <- mm_xx_sighting(xx, 3, sex, TRUE)
    first <- mm_xx_capture("ring:MOCK_B", 3, sex)
    expect_identical(mm_xx_execute(mm_xx_query(first, sighting)),
      "ring:MOCK_B|2|1|0|2026-10-03 10:00:00|0")
    # TN proof remains definitive, and a duplicated raw sighting is not a
    # second identity or additional distinct event.
    tn <- transform(first, definitive_capture = 1L, has_mm_capture = 0L)
    expect_identical(mm_xx_execute(mm_xx_query(tn, rbind(sighting, sighting))),
      "ring:MOCK_B|3|1|0|2026-10-03 10:00:00|0")
    # Earlier-day proof is retired, never transferred/backdated: this bird's
    # own linked confirming proof is on the actual first-capture date.
    earlier <- mm_xx_sighting(xx, 2, sex, TRUE, pk = 20)
    expect_identical(mm_xx_execute(mm_xx_query(first, rbind(earlier, sighting))),
      "ring:MOCK_B|2|1|0|2026-10-03 10:00:00|0")
    # Later X-X evidence stays separate and creates a strong conflict.
    later <- mm_xx_sighting(xx, 4, sex, TRUE)
    observed <- mm_xx_execute(mm_xx_query(first, rbind(sighting, later)))
    expect_true("ring:MOCK_B|2|0|1|2026-10-03 10:00:00|0" %in% observed)
    expect_true(paste0(xx, "|2|0|1|2026-10-04 00:00:00|0") %in% observed)
  }
})

test_that("same-day linkage preserves identity, nest, sex, eligibility, and date guards", {
  first <- mm_xx_capture("ring:MOCK_B", 3)
  xx <- mm_xx_sighting("xx:MOCK_NEST:M", 3, confirming = TRUE)
  cases <- list(
    nonconfirming = list(first, transform(xx, association_confirming = 0L, association_nonconfirming = 1L)),
    ambiguous = list(first, transform(xx, is_ambiguous_match = 1L)),
    ineligible_sighting = list(first, transform(xx, association_evidence_eligible = 0L)),
    ineligible_capture = list(transform(first, association_evidence_eligible = 0L), xx),
    recapture = list(transform(first, capture_status = "R"), xx),
    changed_mark = list(transform(first, capture_status = "C"), xx),
    unmarked_capture = list(transform(first, is_confirmed_xx = 1L), xx),
    other_sex = list(transform(first, capture_sex = "F"), xx),
    other_nest = list(transform(first, nest_id = "MOCK_OTHER"), xx),
    earlier_capture = list(mm_xx_capture("ring:MOCK_B", 2), xx),
    later_capture = list(mm_xx_capture("ring:MOCK_B", 4), xx)
  )
  for (case in cases) {
    observed <- mm_xx_execute(mm_xx_query(case[[1]], case[[2]]))
    expect_false(any(startsWith(observed, "ring:MOCK_B|2|1|")))
  }
  future <- mm_xx_execute(mm_xx_query(first, xx, "2026-10-02"))
  expect_length(future, 0L)
  # Competing same-day first markings block the link even if one rival's
  # later resighting match is ambiguous. Do not filter into false uniqueness.
  captures <- rbind(first, mm_xx_capture("ring:MOCK_C", 3))
  rival <- mm_xx_sighting("ring:MOCK_C", 4, ambiguous = TRUE)
  for (sightings in list(xx, rbind(xx, rival))) {
    observed <- mm_xx_execute(mm_xx_query(captures, sightings))
    expect_true(any(startsWith(observed, "xx:MOCK_NEST:M|2|1|")))
    expect_false(any(startsWith(observed, "ring:MOCK_B|2|1|")))
  }
  # Duplicate first-capture rows for the same identity are not two birds.
  expect_identical(mm_xx_execute(mm_xx_query(rbind(first, first), xx)),
    "ring:MOCK_B|2|1|0|2026-10-03 10:00:00|0")
})

test_that("same-day linkage preserves all observations without adding another candidate", {
  first <- mm_xx_capture("ring:MOCK_F", 3, "F", method = "TN")
  xx <- mm_xx_sighting("xx:MOCK_NEST:F", 3, "F", TRUE)
  marked <- mm_xx_sighting("ring:MOCK_F", 4, "F", TRUE)
  with_counts <- function(sightings) {
    query <- mm_xx_query(first, sightings)
    query <- sub("n_nonconfirming_resightings)",
      "n_nonconfirming_resightings, n_confirming_resightings, n_resightings)",
      query, fixed = TRUE)
    mm_xx_execute(query)
  }
  expect_identical(with_counts(rbind(xx, marked)),
    "ring:MOCK_F|3|1|0|2026-10-03 10:00:00|0|2|2")
  sightings <- rbind(xx, transform(xx, resighting_pk = 30),
    transform(xx, resighting_pk = 31), marked,
    mm_xx_sighting("ring:MOCK_F", 5, "F", TRUE),
    mm_xx_sighting("ring:MOCK_F", 6, "F"),
    mm_xx_sighting("ring:MOCK_F", 7, "F"))
  expect_identical(with_counts(sightings),
    "ring:MOCK_F|3|1|0|2026-10-03 10:00:00|2|5|7")
})

test_that("a same-day targeted first marking cannot revive an earlier MM-only candidate", {
  captures <- rbind(mm_xx_capture("ring:MOCK_A", 1), mm_xx_capture("ring:MOCK_B", 3))
  sightings <- rbind(mm_xx_sighting("xx:MOCK_NEST:M", 2, confirming = TRUE),
    mm_xx_sighting("xx:MOCK_NEST:M", 3, confirming = TRUE))
  expect_identical(mm_xx_execute(mm_xx_query(captures, sightings)), c(
    "ring:MOCK_A|0|0|0|NULL|0", "ring:MOCK_B|2|1|0|2026-10-03 10:00:00|0"))
})

test_that("displaced MM-only identities cannot revive when the earlier X-X placeholder retires", {
  for (sex in c("M", "F")) {
    captures <- rbind(mm_xx_capture("ring:MOCK_A", 1, sex), mm_xx_capture("ring:MOCK_B", 5, sex))
    xx <- mm_xx_sighting(paste0("xx:MOCK_NEST:", sex), 4, sex, TRUE)
    a <- do.call(rbind, lapply(c(2, 3, 6), function(day) mm_xx_sighting("ring:MOCK_A", day, sex, pk = 100 + day)))
    b <- do.call(rbind, lapply(6:8, function(day) mm_xx_sighting("ring:MOCK_B", day, sex)))
    expect_identical(mm_xx_execute(mm_xx_query(captures, rbind(xx, a, b))), c(
      "ring:MOCK_A|0|0|0|NULL|3", "ring:MOCK_B|1|1|0|2026-10-08 00:00:00|3"))
    # Three observations already completed before the X-X conflict are not
    # MM-only evidence; the existing hierarchy/ambiguity rules still apply.
    prior <- do.call(rbind, lapply(1:3, function(day) mm_xx_sighting("ring:MOCK_A", day, sex, pk = 100 + day)))
    observed <- mm_xx_execute(mm_xx_query(captures, rbind(xx, prior, b)))
    expect_true("ring:MOCK_A|1|0|1|2026-10-03 00:00:00|3" %in% observed)
    expect_true("ring:MOCK_B|1|0|1|2026-10-08 00:00:00|3" %in% observed)
    # The other sex's confirming X-X event cannot displace this identity.
    opposite <- if (sex == "M") "F" else "M"
    other_xx <- mm_xx_sighting(paste0("xx:MOCK_NEST:", opposite), 4, opposite, TRUE)
    expect_true("ring:MOCK_A|1|1|0|2026-10-06 00:00:00|3" %in%
      mm_xx_execute(mm_xx_query(captures[1, ], rbind(other_xx, a))))
  }
})

test_that("retirement preserves duplicates, later X-X, and competing-candidate safeguards", {
  captures <- rbind(mm_xx_capture("ring:MOCK_A", 1), mm_xx_capture("ring:MOCK_B", 3))
  xx <- mm_xx_sighting("xx:MOCK_NEST:M", 2, confirming = TRUE)
  b <- do.call(rbind, lapply(4:6, function(day) mm_xx_sighting("ring:MOCK_B", day)))
  expected <- c("ring:MOCK_A|0|0|0|NULL|0", "ring:MOCK_B|1|1|0|2026-10-06 00:00:00|3")
  expect_identical(mm_xx_execute(mm_xx_query(captures, rbind(xx, b, b[1, ]))), expected)
  later <- mm_xx_sighting("xx:MOCK_NEST:M", 7, confirming = TRUE)
  expect_true("xx:MOCK_NEST:M|2|1|0|2026-10-07 00:00:00|0" %in%
    mm_xx_execute(mm_xx_query(captures, rbind(xx, b, later))))
  competing_capture <- mm_xx_capture("ring:MOCK_C", 3)
  competing_proof <- transform(b, identity_key = "ring:MOCK_C", display_mark = "ring:MOCK_C", resighting_pk = resighting_pk + 100)
  expect_true("xx:MOCK_NEST:M|2|1|0|2026-10-02 00:00:00|0" %in%
    mm_xx_execute(mm_xx_query(rbind(captures, competing_capture), rbind(xx, b, competing_proof))))
  ambiguous <- mm_xx_sighting("ring:MOCK_B", 7, ambiguous = TRUE)
  expect_true("xx:MOCK_NEST:M|2|1|0|2026-10-02 00:00:00|0" %in%
    mm_xx_execute(mm_xx_query(captures, rbind(xx, b, ambiguous))))
})
