view_1_sql <- function() {
  sql <- paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )

  start <- regexpr(
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.VIEW_1 AS",
    sql,
    fixed = TRUE
  )
  expect_gt(start[[1]], 0)

  remainder <- substring(sql, start[[1]])
  finish <- regexpr(
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.OVERVIEW AS",
    remainder,
    fixed = TRUE
  )
  expect_gt(finish[[1]], 0)

  substring(remainder, 1, finish[[1]] - 1)
}


test_that("VIEW_1 keeps its exact public contract", {
  sql <- view_1_sql()
  final_select <- sub(
    ".*\nSELECT\n  bird[.]mark AS mark,",
    "bird.mark AS mark,",
    sql
  )
  final_select <- sub(
    "\nFROM tagged_birds bird.*",
    "",
    final_select
  )

  alias_matches <- gregexpr(
    "[[:space:]]AS[[:space:]]+[a-z_]+",
    final_select,
    perl = TRUE
  )
  aliases <- regmatches(final_select, alias_matches)[[1]]
  aliases <- sub(".*[[:space:]]", "", aliases)

  expect_identical(
    aliases,
    c(
      "mark",
      "nest_id",
      "sex",
      "cap_date",
      "days_since_cap",
      "days_since_last_seen",
      "comment_last_seen",
      "number_of_resightings",
      "limp_ratio"
    )
  )
})


test_that("VIEW_1 uses stable cohort and collision-safe identity rules", {
  sql <- view_1_sql()

  expect_match(
    sql,
    "UPPER(TRIM(COALESCE(c.tag_type, ''))) = 'GEO'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "UPPER(TRIM(COALESCE(raw_capture.tag_action, ''))) IN ('D', 'N')",
    fixed = TRUE
  )
  expect_no_match(sql, "IN ('D', 'S', 'N')", fixed = TRUE)
  expect_match(sql, "PARTITION BY event.bird_id", fixed = TRUE)
  expect_match(sql, "WHERE deployment_rank = 1", fixed = TRUE)
  expect_match(sql, "COUNT(DISTINCT bird_id) AS n_birds", fixed = TRUE)
  expect_match(sql, "AND owner.n_birds = 1", fixed = TRUE)
  expect_match(sql, "mark_key <> 'X-X'", fixed = TRUE)
  expect_match(sql, "mark_key <> 'XX-XX'", fixed = TRUE)
  expect_match(
    sql,
    "SUBSTRING_INDEX(mark_key, '-', 1) NOT IN ('X', 'XX')",
    fixed = TRUE
  )
  expect_match(
    sql,
    "FIELD_2026_BADOatNZ.format_mark(",
    fixed = TRUE
  )
  expect_match(sql, "latest_nest.nest_id AS nest_id", fixed = TRUE)
  expect_match(sql, "NULLIF(TRIM(c.nest_id), '')", fixed = TRUE)
  expect_match(sql, "UPPER(TRIM(c.nest_id)) <> 'NO_NEST'", fixed = TRUE)
  expect_match(sql, "PARTITION BY association.bird_id", fixed = TRUE)
  expect_match(sql, "WHERE association_rank = 1", fixed = TRUE)
})


test_that("VIEW_1 canonicalizes GEO spacer identities and fails closed when ambiguous", {
  sql <- view_1_sql()

  expect_match(sql, "capture_mark_versions AS (", fixed = TRUE)
  expect_match(sql, "capture_mark_identity_values AS (", fixed = TRUE)
  expect_match(sql, "resighting_mark_identities AS (", fixed = TRUE)
  expect_match(
    sql,
    "COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), ''))",
    fixed = TRUE
  )
  expect_match(sql, "versions.UR_norm REGEXP '^T[A-Z]$'", fixed = TRUE)
  expect_match(sql, "SUBSTRING(versions.UR_norm, 2)", fixed = TRUE)
  expect_match(sql, "resighting.UR_norm IS NULL", fixed = TRUE)
  expect_match(sql, "alias_partial_owner_counts", fixed = TRUE)
  expect_match(sql, "resighting.sex_key = alias.sex_key", fixed = TRUE)

  canonical_mark <- function(ll, ur, lr) {
    if (
      !is.na(lr) && nchar(lr) == 1L
        && !is.na(ur) && grepl("^T[A-Z]$", ur)
        && substr(ur, 2L, 2L) %notin% c("X", "M")
    ) {
      return(paste0(ifelse(is.na(ll) || !nzchar(ll), "X", ll), "-", substr(ur, 2L, 2L), ".", lr))
    }
    paste0(ifelse(is.na(ll) || !nzchar(ll), "X", ll), "-", ifelse(is.na(ur) || !nzchar(ur), "X", ur), ".", ifelse(is.na(lr) || !nzchar(lr), "X", lr))
  }
  `%notin%` <- Negate(`%in%`)

  captures <- data.frame(
    bird_id = c("MOCK-M-Y", "MOCK-M-G", "MOCK-F-Y", "MOCK-MULTI"),
    sex_key = c("M", "M", "F", "M"),
    LL = c("BY", "BY", "BY", "BY"),
    UR = c("TY", "TG", "TY", "TY"),
    LR = c("L", "L", "L", "LG"),
    cap_date = as.Date(c("2026-09-01", "2026-09-01", "2026-09-01", "2026-09-01")),
    stringsAsFactors = FALSE
  )
  captures$mark_key <- mapply(canonical_mark, captures$LL, captures$UR, captures$LR)

  resightings <- data.frame(
    event = c("before-reference", "future", "ambiguous-no-UR", "female-exact"),
    sex_key = c("M", "M", NA, "F"),
    LL = c("BY", "BY", "BY", "BY"),
    UR = c("TY", "TY", NA, "TY"),
    LR = c("L", "L", "L", "L"),
    date = as.Date(c("2026-09-10", "2026-09-30", "2026-09-10", "2026-09-10")),
    stringsAsFactors = FALSE
  )
  reference_date <- as.Date("2026-09-15")
  resightings <- resightings[resightings$date <= reference_date, , drop = FALSE]

  expect_identical(
    captures$mark_key,
    c("BY-Y.L", "BY-G.L", "BY-Y.L", "BY-TY.LG")
  )
  expect_identical(resightings$event, c("before-reference", "ambiguous-no-UR", "female-exact"))

  mock_match <- function(resighting, captures) {
    if (is.na(resighting$UR)) {
      candidates <- captures[
        captures$LL == resighting$LL & captures$LR == resighting$LR,
        ,
        drop = FALSE
      ]
      if (!is.na(resighting$sex_key)) {
        candidates <- candidates[candidates$sex_key == resighting$sex_key, , drop = FALSE]
      }
      return(if (nrow(candidates) == 1L) candidates$bird_id else character())
    }

    candidates <- captures[captures$mark_key == canonical_mark(
      resighting$LL,
      resighting$UR,
      resighting$LR
    ), , drop = FALSE]
    if (!is.na(resighting$sex_key)) {
      candidates <- candidates[candidates$sex_key == resighting$sex_key, , drop = FALSE]
    }
    if (nrow(candidates) == 1L) candidates$bird_id else character()
  }

  expect_length(mock_match(resightings[resightings$event == "ambiguous-no-UR", ], captures), 0L)
  expect_identical(
    mock_match(resightings[resightings$event == "female-exact", ], captures),
    "MOCK-F-Y"
  )
  expect_identical(
    mock_match(
      data.frame(sex_key = "M", LL = "BY", UR = "TY", LR = "L"),
      captures
    ),
    "MOCK-M-Y"
  )
})


test_that("VIEW_1 uses reference-date and distinct-day aggregations", {
  sql <- view_1_sql()

  expect_match(sql, "HAVING COUNT(*) = 1", fixed = TRUE)
  expect_match(sql, "resighting.resighting_date >= bird.cap_date", fixed = TRUE)
  expect_match(sql, "r.date <= reference.reference_date", fixed = TRUE)
  expect_match(
    sql,
    "COUNT(DISTINCT resighting_date) AS number_of_resightings",
    fixed = TRUE
  )
  expect_match(
    sql,
    "DATEDIFF(reference.reference_date, bird.cap_date)",
    fixed = TRUE
  )
  expect_match(
    sql,
    "ORDER BY classified.resighting_date DESC, classified.pk DESC",
    fixed = TRUE
  )
  expect_match(sql, "MAX(is_limp) AS is_limp_day", fixed = TRUE)
  expect_match(
    sql,
    "/ NULLIF(summary.walking_fine_days, 0) AS limp_ratio",
    fixed = TRUE
  )
})


test_that("VIEW_1 classifier distinguishes affirmative and negative walking text", {
  sql <- view_1_sql()

  expect_match(sql, "AS has_limp_word", fixed = TRUE)
  expect_match(sql, "AS has_negated_limp", fixed = TRUE)
  expect_match(sql, "AS has_negated_lame", fixed = TRUE)
  expect_match(sql, "AS has_walking_fine_phrase", fixed = TRUE)
  expect_match(sql, "AS has_impaired_walking_phrase", fixed = TRUE)
  expect_match(
    sql,
    "WHEN terms.has_limp_word = 1 AND terms.has_negated_limp = 0 THEN 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHEN summary.number_of_resightings IS NULL THEN NULL",
    fixed = TRUE
  )
  expect_match(sql, "ELSE 'walking fine'", fixed = TRUE)
})


test_that("VIEW_1 receives compact browser column widths", {
  app <- load_main_app()

  widths <- app$env$view_table_column_widths("VIEW_1", view = TRUE)

  expect_identical(
    vapply(widths, `[[`, character(1), "width"),
    c(
      "120px", "100px", "60px", "105px", "110px", "135px", "220px", "140px", "100px"
    )
  )
  expect_identical(
    vapply(widths, `[[`, integer(1), "targets"),
    0:8
  )
  expect_identical(
    app$env$view_table_column_widths("VIEW_1", view = FALSE),
    list()
  )
})
