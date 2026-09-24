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
    "UPPER(TRIM(COALESCE(c.tag_action, ''))) IN ('D', 'N')",
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
    "FIELD_2026_BADOatNZ.format_mark(r.UL, r.LL, r.UR, r.LR)",
    fixed = TRUE
  )
})


test_that("VIEW_1 uses reference-date and distinct-day aggregations", {
  sql <- view_1_sql()

  expect_match(sql, "HAVING COUNT(*) = 1", fixed = TRUE)
  expect_match(sql, "r.date >= bird.cap_date", fixed = TRUE)
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
    c("120px", "60px", "105px", "110px", "135px", "220px", "140px", "100px")
  )
  expect_identical(
    vapply(widths, `[[`, integer(1), "targets"),
    0:7
  )
  expect_identical(
    app$env$view_table_column_widths("VIEW_1", view = FALSE),
    list()
  )
})
