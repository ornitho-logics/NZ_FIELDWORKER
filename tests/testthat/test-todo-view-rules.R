todo_list_view_sql <- function() {
  sql <- paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
  start_marker <- paste(
    "CREATE OR REPLACE VIEW",
    "FIELD_2026_BADOatNZ.TODO_LIST AS"
  )
  end_marker <- paste(
    "CREATE OR REPLACE VIEW",
    "FIELD_2026_BADOatNZ.VIEW_1 AS"
  )
  start <- regexpr(start_marker, sql, fixed = TRUE)[[1]]
  expect_gt(start, 0L)

  remainder <- substring(sql, start)
  finish <- regexpr(end_marker, remainder, fixed = TRUE)[[1]]
  expect_gt(finish, 0L)

  substring(remainder, 1L, finish - 1L)
}


views_source_sql <- function() {
  paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )
}


test_that("TODO_LIST contains the bounded operational rules", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "IN ('F', 'I', 'H', 'PP', 'PD', 'NOTA')",
    fixed = TRUE
  )
  expect_match(
    sql,
    "UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'NOTA'\n          AND EXISTS (\n            SELECT 1\n            FROM hatched_nests hatched",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHEN UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "UPPER(TRIM(COALESCE(active_nests.species, ''))) = 'BADO'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "UPPER(TRIM(COALESCE(wryb_nest.species, ''))) = 'WRYB'",
    fixed = TRUE
  )
  expect_match(sql, "WHERE NOT EXISTS", fixed = TRUE)
  expect_match(
    sql,
    "FROM FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h",
    fixed = TRUE
  )
})


test_that("hatched terminal notA nests remain eligible for parent work", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "WHERE UPPER(TRIM(COALESCE(n.nest_state, ''))) = 'NOTA'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "JOIN hatched_nests\n                ON n.nest_id = hatched_nests.nest_id",
    fixed = TRUE
  )
  expect_match(
    sql,
    "IN ('F', 'I', 'H', 'PP', 'PD', 'NOTA')",
    fixed = TRUE
  )

  parent_work_eligible <- function(latest_state, had_h_event) {
    state <- toupper(trimws(latest_state))
    state %in% c("F", "I", "H", "PP", "PD") ||
      (state == "NOTA" && isTRUE(had_h_event))
  }

  expect_true(parent_work_eligible("notA", TRUE))
  expect_false(parent_work_eligible("notA", FALSE))
  expect_true(parent_work_eligible("H", TRUE))

  capture_allowed_for_parent_work <- function(latest_state, had_h_event) {
    toupper(trimws(latest_state)) == "H" ||
      (toupper(trimws(latest_state)) == "NOTA" && isTRUE(had_h_event))
  }
  expect_true(capture_allowed_for_parent_work("notA", TRUE))
  expect_false(capture_allowed_for_parent_work("notA", FALSE))

  pair_completion_note <- function(latest_state, had_h_event, male_xx, female_geo) {
    if (parent_work_eligible(latest_state, had_h_event) && male_xx && female_geo) {
      "tag M (pair completion)"
    } else {
      NA_character_
    }
  }

  expect_identical(
    pair_completion_note("notA", TRUE, male_xx = TRUE, female_geo = TRUE),
    "tag M (pair completion)"
  )
})


test_that("H hiding-photo association is shared by BROODS_LATEST and TODO_LIST", {
  sql <- views_source_sql()

  expect_match(
    sql,
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS AS",
    fixed = TRUE
  )
  expect_match(sql, "same_occasion_adult_summary", fixed = TRUE)
  expect_match(sql, "latest_ring_capture_summary", fixed = TRUE)
  expect_match(
    sql,
    "COALESCE(h_assoc.resolved_nest_id, r.nest_id) AS nest_id",
    fixed = TRUE
  )
  expect_match(sql, "'ambiguous_same_occasion_adult'", fixed = TRUE)
  expect_match(sql, "'ambiguous_capture_history'", fixed = TRUE)
  expect_match(
    sql,
    "h.association_method IN (\n      'direct',\n      'same_occasion_adult',\n      'ring_capture'",
    fixed = TRUE
  )
})


test_that("BROODS_LATEST treats age-C captures as positive brood evidence", {
  sql <- views_source_sql()

  expect_match(sql, "positive_chick_status AS", fixed = TRUE)
  expect_match(
    sql,
    "AND UPPER(TRIM(COALESCE(c.age, ''))) = 'C'",
    fixed = TRUE
  )
  expect_match(sql, "chicks.first_chick_capture_date", fixed = TRUE)
  expect_match(sql, "OR chicks.nest_id IS NOT NULL", fixed = TRUE)
})


test_that("hiding-photo TODO counts distinct captured and photographed rings", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "COUNT(DISTINCT NULLIF(\n      NULLIF(UPPER(TRIM(COALESCE(c.ring, ''))), ''),\n      'NA'\n    )) AS n_captured_chick_rings",
    fixed = TRUE
  )
  expect_match(sql, "COUNT(*) AS n_chick_captures", fixed = TRUE)
  expect_match(
    sql,
    "COUNT(DISTINCT h.ring) AS n_hiding_spot_photos",
    fixed = TRUE
  )
  expect_match(sql, "r.photo_start", fixed = TRUE)
  expect_match(sql, "r.photo_end", fixed = TRUE)
  expect_match(
    sql,
    "COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0)\n           < chick_captures.n_captured_chick_rings",
    fixed = TRUE
  )
  expect_match(
    sql,
    "' chicks with rclass ''H'' photos'",
    fixed = TRUE
  )
  expect_false(grepl("need H resightings", sql, fixed = TRUE))
})


test_that("MM parent follow-up accepts qualifying behaviour or three matching resightings", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "n_matching_post_mm_resightings",
    fixed = TRUE
  )
  expect_match(
    sql,
    "COALESCE(followup.n_matching_post_mm_resightings, 0) < 3",
    fixed = TRUE
  )
  expect_match(
    sql,
    "association.association_date >= mm.mm_capture_date",
    fixed = TRUE
  )
  expect_match(
    sql,
    "'(^|[^A-Z])(BW|NM|IN|BC|FC)([^A-Z]|$)'",
    fixed = TRUE
  )
  expect_match(sql, "post_mm_xx_seen", fixed = TRUE)

  matching_followup_resolved <- function(
    resightings,
    reference_date,
    capture_date = "2026-09-01"
  ) {
    post_mm <- resightings[
      resightings$date >= as.Date(capture_date) &
        resightings$date <= as.Date(reference_date),
    ]
    matching <- toupper(trimws(post_mm$mark)) == "BY-YY"
    has_nest_behaviour <- grepl(
      "(^|[^A-Z])(BW|NM|IN|BC|FC)([^A-Z]|$)",
      toupper(trimws(post_mm$behav)),
      perl = TRUE
    )
    sum(matching) >= 1 && (
      any(matching & has_nest_behaviour) || sum(matching) >= 3
    )
  }

  mock_resightings <- data.frame(
    date = as.Date(c(
      "2026-09-02", "2026-09-03", "2026-09-04", "2026-09-05"
    )),
    mark = c("X-X", "BY-YY", "BY-YY", "BY-YY"),
    behav = c("AT", "AT", "AT", "AT"),
    stringsAsFactors = FALSE
  )

  expect_false(matching_followup_resolved(mock_resightings, "2026-09-04"))
  expect_true(matching_followup_resolved(mock_resightings, "2026-09-05"))

  same_day_behaviour <- data.frame(
    date = as.Date("2026-09-01"),
    mark = "BY-YY",
    behav = "AT, BW",
    stringsAsFactors = FALSE
  )
  expect_true(
    matching_followup_resolved(same_day_behaviour, "2026-09-01")
  )

  for (behaviour in c("BC", "FC")) {
    qualifying_behaviour <- data.frame(
      date = as.Date("2026-09-02"),
      mark = "BY-YY",
      behav = behaviour,
      stringsAsFactors = FALSE
    )
    expect_true(
      matching_followup_resolved(qualifying_behaviour, "2026-09-02")
    )
  }

  one_matching_resighting <- data.frame(
    date = as.Date(c("2026-09-02", "2026-09-03")),
    mark = c("BY-YY", "YO-OR"),
    behav = c("AT", "BW"),
    stringsAsFactors = FALSE
  )
  expect_false(
    matching_followup_resolved(one_matching_resighting, "2026-09-05")
  )
})


test_that("MM identity matching can use LL and LR without UL or UR", {
  sql <- todo_list_view_sql()

  expect_match(sql, "adult_mm_post_resighting_matched", fixed = TRUE)
  expect_match(sql, "mm.LL_norm IS NOT NULL", fixed = TRUE)
  expect_match(sql, "association.LL_obs = mm.LL_norm", fixed = TRUE)
  expect_match(sql, "association.LR_obs = mm.LR_norm", fixed = TRUE)
  expect_match(sql, "requires_spacer_identity", fixed = TRUE)
  expect_match(sql, "'CP19738'", fixed = TRUE)
  expect_match(sql, "'CP19739'", fixed = TRUE)
  expect_match(sql, "'CP19693'", fixed = TRUE)
  expect_match(sql, "'CP19848'", fixed = TRUE)

  mm_identity_match <- function(
    mm_ll,
    mm_lr,
    mm_mark,
    resighting_ll,
    resighting_lr,
    resighting_mark,
    requires_spacer_identity = FALSE
  ) {
    if (isTRUE(requires_spacer_identity)) {
      return(identical(toupper(trimws(mm_mark)), toupper(trimws(resighting_mark))))
    }
    !is.na(mm_ll) && !is.na(mm_lr) &&
      !is.na(resighting_ll) && !is.na(resighting_lr) &&
      identical(resighting_ll, mm_ll) &&
      identical(resighting_lr, mm_lr)
  }

  # A missing UL/UR does not prevent a complete lower-leg match.
  expect_true(
    mm_identity_match(
      "BY", "OL", "YO-TO.OL", "BY", "OL", "BY-OL"
    )
  )
  # A different lower-leg combination remains a non-match.
  expect_false(
    mm_identity_match(
      "BY", "OL", "YO-TO.OL", "BY", "OY", "BY-OY"
    )
  )
  # Missing LL or LR cannot establish the identity.
  expect_false(
    mm_identity_match(
      "BY", "OL", "YO-TO.OL", NA_character_, "OL", "-OL"
    )
  )
  # The four approved single-LR birds still require the spacer-inclusive mark.
  expect_false(
    mm_identity_match(
      "BY", "L", "BY-TY.L", "BY", "L", "BY-L",
      requires_spacer_identity = TRUE
    )
  )
  expect_true(
    mm_identity_match(
      "BY", "L", "BY-TY.L", "BY", "L", "BY-TY.L",
      requires_spacer_identity = TRUE
    )
  )
})


test_that("hatched brood task Hatch values use the recorded H date", {
  sql <- todo_list_view_sql()

  expect_match(sql, "MIN(observed_nest.date) AS hatch_date", fixed = TRUE)
  expect_match(
    sql,
    "AND UPPER(TRIM(COALESCE(observed_nest.nest_state, ''))) = 'H'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHEN observed_hatch_dates.hatch_date IS NOT NULL",
    fixed = TRUE
  )
  expect_match(
    sql,
    "observed_hatch_dates.hatch_date,\n        sr.reference_date",
    fixed = TRUE
  )
  expect_match(
    sql,
    "DATEDIFF(\n      brood_followup_nests.hatch_date,\n      brood_followup_nests.reference_date\n    ) AS min_days_to_hatch",
    fixed = TRUE
  )

  hatch_value <- function(hatch_date, reference_date, is_negative = FALSE) {
    if (isTRUE(is_negative)) {
      return(NA_integer_)
    }
    as.integer(as.Date(hatch_date) - as.Date(reference_date))
  }

  expect_identical(
    hatch_value("2026-09-28", "2026-09-29"),
    -1L
  )
  expect_identical(
    hatch_value("2026-09-24", "2026-09-25"),
    -1L
  )
  expect_identical(
    hatch_value("2026-09-28", "2026-09-29", is_negative = TRUE),
    NA_integer_
  )

  parent_hatch_value <- function(
    observed_hatch_date,
    reference_date,
    inferred_hatch_date = NA,
    predicted_hatch_days = NA_integer_
  ) {
    if (!is.na(observed_hatch_date)) {
      return(as.integer(
        as.Date(observed_hatch_date) - as.Date(reference_date)
      ))
    }
    if (!is.na(inferred_hatch_date)) {
      return(as.integer(
        as.Date(inferred_hatch_date) - as.Date(reference_date)
      ))
    }
    predicted_hatch_days
  }

  expect_identical(
    parent_hatch_value("2026-09-28", "2026-09-29", "2026-10-04", 5L),
    -1L
  )
})


test_that("brood banding notes identify broods young enough for leg flags", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "DATEDIFF(\n             brood_followup_nests.hatch_date,\n             brood_followup_nests.reference_date\n           ) <= -21",
    fixed = TRUE
  )
  expect_match(
    sql,
    "'no chick captures; chicks old enough for leg flags'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "DATEDIFF(b.reference_date, b.discovery_date) >= 21",
    fixed = TRUE
  )

  banding_note <- function(hatch_value = NA_integer_, discovery_age = NA_integer_) {
    if (!is.na(hatch_value) && hatch_value <= -21L) {
      return("no chick captures; chicks old enough for leg flags")
    }
    if (!is.na(discovery_age) && discovery_age >= 21L) {
      return("no chick captures; chicks old enough for leg flags")
    }
    "no chick captures"
  }

  expect_identical(
    banding_note(hatch_value = -21L),
    "no chick captures; chicks old enough for leg flags"
  )
  expect_identical(
    banding_note(hatch_value = -20L),
    "no chick captures"
  )
  expect_identical(
    banding_note(discovery_age = 21L),
    "no chick captures; chicks old enough for leg flags"
  )
  expect_identical(
    banding_note(discovery_age = 20L),
    "no chick captures"
  )
})


test_that("hatch-stage parent work bypasses the clutch-age gate", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "WHEN UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'",
    fixed = TRUE
  )
  expect_match(
    sql,
    "OR active_nests.hatch_signs_present = 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "ELSE COALESCE(capture_age.capture_allowed_after_completion, 0)",
    fixed = TRUE
  )

  capture_gate <- function(nest_state, hatch_signs_present, age_gate = 0) {
    if (toupper(trimws(nest_state)) == "H" || hatch_signs_present == 1) {
      return(1L)
    }
    as.integer(age_gate)
  }

  expect_identical(capture_gate("H", 0), 1L)
  expect_identical(capture_gate("I", 1), 1L)
  expect_identical(capture_gate("I", 0, 1), 1L)
  expect_identical(capture_gate("I", 0, 0), 0L)
})


test_that("partial H visits remain in potential-hatch checks", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'\n        AND COALESCE(active_nests.clutch_size, 0) > 0\n        AND active_nests.days_ago >= 1",
    fixed = TRUE
  )
  expect_match(sql, "'; unhatched egg(s)'", fixed = TRUE)

  asynchronous_hatch_check <- function(nest_state, clutch_size, days_ago) {
    toupper(trimws(nest_state)) == "H" &&
      !is.na(clutch_size) && clutch_size > 0 &&
      days_ago >= 1
  }

  expect_true(asynchronous_hatch_check("H", 1, 1))
  expect_false(asynchronous_hatch_check("H", 0, 1))
  expect_false(asynchronous_hatch_check("H", 1, 0))
  expect_false(asynchronous_hatch_check("I", 1, 1))
})


test_that("pending MM parents stay in resighting rather than capture work", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "WHEN COALESCE(adult_mm_followup_status.M_mm_resight_pending, 0) = 1\n      THEN 0",
    fixed = TRUE
  )
  expect_match(
    sql,
    "(mm.sex = 'M' AND COALESCE(adult_parent_status.M_mm_resight_pending, 0) = 1)",
    fixed = TRUE
  )
  expect_match(
    sql,
    "(mm.sex = 'F' AND COALESCE(adult_parent_status.F_mm_resight_pending, 0) = 1)",
    fixed = TRUE
  )
  expect_no_match(sql, "AND followup.nest_id IS NULL", fixed = TRUE)
  expect_no_match(sql, "'resight/band M (MM cap)'", fixed = TRUE)
  expect_match(sql, "' had MM cap'", fixed = TRUE)
  expect_match(sql, "has_xx_nest_behav", fixed = TRUE)
  expect_match(sql, "matched.has_nest_behav = 1", fixed = TRUE)
  expect_no_match(
    sql,
    "association.is_confirmed_xx = 1\n         AND association.has_matching_nest_behav = 1",
    fixed = TRUE
  )
  expect_match(sql, "xx_nest_behav_date", fixed = TRUE)
  expect_match(sql, "matching_post_mm_resight_date", fixed = TRUE)
  expect_match(
    sql,
    "later_capture.capture_date >= followup.xx_nest_behav_date",
    fixed = TRUE
  )
  expect_match(
    sql,
    "followup.matching_post_mm_resight_date\n              <= followup.xx_nest_behav_date",
    fixed = TRUE
  )
  expect_match(sql, "M_mm_xx_parent_confirmed", fixed = TRUE)
  expect_match(
    sql,
    "WHEN COALESCE(\n             adult_mm_followup_status.M_mm_xx_parent_confirmed,\n             0\n           ) = 1\n      THEN 'X-X'",
    fixed = TRUE
  )

  alternate_xx_parent <- function(
    is_xx,
    has_nest_behaviour,
    later_non_xx_capture = FALSE
  ) {
    isTRUE(is_xx) &&
      isTRUE(has_nest_behaviour) &&
      !isTRUE(later_non_xx_capture)
  }

  # A different X-X bird with IN is a confirmed alternate parent after MM.
  expect_true(alternate_xx_parent(TRUE, TRUE))
  expect_false(alternate_xx_parent(TRUE, FALSE))
  expect_false(alternate_xx_parent(TRUE, TRUE, TRUE))

  mm_followup_pending <- function(n_matching, has_nest_behaviour) {
    n_matching == 0L ||
      (!isTRUE(has_nest_behaviour) && n_matching < 3L)
  }

  capture_candidate <- function(mm_pending, unknown_status) {
    isTRUE(unknown_status) && !isTRUE(mm_pending)
  }

  xx_parent_confirmed <- function(is_xx, has_nest_behaviour) {
    isTRUE(is_xx) && isTRUE(has_nest_behaviour)
  }

  xx_parent_remains_confirmed <- function(
    xx_behaviour_date,
    later_banded_capture_date = NA,
    later_matching_resight_date = NA
  ) {
    capture_is_before_xx <- is.na(later_banded_capture_date) ||
      as.Date(later_banded_capture_date) < as.Date(xx_behaviour_date)
    matching_resight_is_not_later <- is.na(later_matching_resight_date) ||
      as.Date(later_matching_resight_date) <= as.Date(xx_behaviour_date)
    capture_is_before_xx && matching_resight_is_not_later
  }

  displayed_mm_parent_mark <- function(
    capture_mark,
    xx_behaviour_date,
    later_banded_capture_date = NA,
    later_matching_resight_date = NA
  ) {
    if (xx_parent_remains_confirmed(
      xx_behaviour_date,
      later_banded_capture_date,
      later_matching_resight_date
    )) {
      return("X-X")
    }
    capture_mark
  }

  expect_true(mm_followup_pending(1L, FALSE))
  expect_false(mm_followup_pending(1L, TRUE))
  expect_false(mm_followup_pending(3L, FALSE))
  expect_false(capture_candidate(TRUE, TRUE))
  expect_true(capture_candidate(FALSE, TRUE))
  expect_true(xx_parent_confirmed(TRUE, TRUE))
  expect_false(xx_parent_confirmed(TRUE, FALSE))
  expect_true(xx_parent_remains_confirmed("2026-09-01"))
  expect_false(
    xx_parent_remains_confirmed("2026-09-01", "2026-09-01")
  )
  expect_false(
    xx_parent_remains_confirmed("2026-09-01", "2026-09-02")
  )
  expect_false(
    xx_parent_remains_confirmed(
      "2026-09-25",
      later_matching_resight_date = "2026-09-26"
    )
  )
  expect_identical(
    displayed_mm_parent_mark(
      "BY-TY.YW",
      "2026-09-25",
      later_matching_resight_date = "2026-09-26"
    ),
    "BY-TY.YW"
  )
})


test_that("pair completion requires a confirmed GEO association", {
  sql <- todo_list_view_sql()

  expect_match(sql, "THEN '; status ?'", fixed = TRUE)
  expect_match(
    sql,
    "WHEN COALESCE(adult_mm_followup_status.F_mm_xx_parent_confirmed, 0) = 1\n      THEN 0\n      WHEN COALESCE(adult_mm_followup_status.F_mm_resight_pending, 0) = 1",
    fixed = TRUE
  )

  resolved_parent_geo <- function(identity_has_geo, xx_parent_confirmed, pending) {
    if (isTRUE(xx_parent_confirmed) || isTRUE(pending)) 0 else identity_has_geo
  }
  expect_identical(resolved_parent_geo(1, TRUE, FALSE), 0)
  expect_identical(resolved_parent_geo(1, FALSE, TRUE), 0)
  expect_identical(resolved_parent_geo(1, FALSE, FALSE), 1)

  expect_match(
    sql,
    "COALESCE(base.F_captured_has_geo, 0) = 1\n                   AND (\n                     COALESCE(base.F_mm_resight_pending, 0) = 0\n                     OR COALESCE(base.M_confirmed_unbanded, 0) = 1\n                   )",
    fixed = TRUE
  )
  expect_match(
    sql,
    "COALESCE(base.M_captured_has_geo, 0) = 1\n                   AND (\n                     COALESCE(base.M_mm_resight_pending, 0) = 0\n                     OR COALESCE(base.F_confirmed_unbanded, 0) = 1\n                   )",
    fixed = TRUE
  )

  pair_target <- function(
    male_tag_eligible,
    female_quota_remaining,
    male_quota_remaining,
    female_has_geo,
    female_captured_has_geo,
    female_mm_pending
  ) {
    if (
      male_tag_eligible &&
        male_quota_remaining > 0 &&
        (
          female_has_geo ||
            (female_captured_has_geo && !female_mm_pending)
        )
    ) {
      return("M")
    }
    if (female_quota_remaining > 0 && male_quota_remaining >= 0) {
      return(NULL)
    }
    NULL
  }

  expect_identical(
    pair_target(TRUE, 1, 1, TRUE, FALSE, FALSE),
    "M"
  )
  expect_identical(
    pair_target(TRUE, 1, 1, FALSE, TRUE, TRUE),
    NULL
  )
})


test_that("pair completion bypasses the release ceiling but balance does not", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "ranked_base.pair_target IS NOT NULL\n           OR ranked_base.geo_rank <= GREATEST(",
    fixed = TRUE
  )
  expect_match(
    sql,
    "targets.pair_target IS NOT NULL\n                 OR targets.n_geo_deployed < targets.release_ceiling",
    fixed = TRUE
  )
  expect_match(
    sql,
    "WHEN ranked.pair_target IS NOT NULL\n      THEN 1 ELSE 0",
    fixed = TRUE
  )
  expect_no_match(
    sql,
    "WHEN ranked.geo_is_actionable = 1\n       AND ranked.pair_target IS NOT NULL\n       AND ranked.geo_rank <= GREATEST(",
    fixed = TRUE
  )

  geo_is_actionable <- function(
    is_candidate,
    pair_target,
    geo_rank,
    release_slots_remaining
  ) {
    isTRUE(is_candidate) && (
      !is.null(pair_target) ||
        geo_rank <= max(0, release_slots_remaining)
    )
  }

  expect_true(geo_is_actionable(TRUE, "F", 8, 0))
  expect_false(geo_is_actionable(TRUE, NULL, 1, 0))
  expect_true(geo_is_actionable(TRUE, NULL, 1, 1))
})


test_that("notA follow-up notes use the compact operational wording", {
  sql <- todo_list_view_sql()

  expect_match(sql, "'hatched; remove flag + do notA'", fixed = TRUE)
  expect_match(sql, "'remove flag + do notA'", fixed = TRUE)
  expect_no_match(sql, "'brood away; remove nest marks + enter notA'", fixed = TRUE)
  expect_no_match(sql, "'remove nest marks + enter notA'", fixed = TRUE)
})


test_that("one tagged parent produces pair completion without deployment-date gating", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "COALESCE(base.F_has_geo, 0) = 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "COALESCE(base.M_has_geo, 0) = 1",
    fixed = TRUE
  )
  expect_no_match(
    sql,
    "base.is_pre25_nest = 1\n                 OR base.F_geo_deployment_date >= base.first_found_date",
    fixed = TRUE
  )
  expect_no_match(
    sql,
    "base.is_pre25_nest = 1\n                 OR base.M_geo_deployment_date >= base.first_found_date",
    fixed = TRUE
  )

  pair_completion_target <- function(
    male_tagged,
    female_tagged,
    male_tag_eligible = TRUE,
    female_tag_eligible = TRUE,
    male_quota_remaining = 1,
    female_quota_remaining = 1,
    male_mm_pending = FALSE,
    female_mm_pending = FALSE
  ) {
    if (
      female_tagged &&
        !male_tagged &&
        male_tag_eligible &&
        male_quota_remaining > 0 &&
        !female_mm_pending
    ) {
      return("M")
    }
    if (
      male_tagged &&
        !female_tagged &&
        female_tag_eligible &&
        female_quota_remaining > 0 &&
        !male_mm_pending
    ) {
      return("F")
    }
    NULL
  }

  parent_capture_note <- function(pair_target, actionable = TRUE) {
    if (isTRUE(actionable) && !is.null(pair_target)) {
      return(paste0("tag ", pair_target, " (pair completion)"))
    }
    "ordinary parent work"
  }

  # C0217-like: tagged female, untagged/unknown male. The female's
  # deployment date is deliberately absent from this mock.
  expect_identical(
    parent_capture_note(pair_completion_target(FALSE, TRUE)),
    "tag M (pair completion)"
  )
  # C2205-like: tagged male, X-X female. The male's deployment date is
  # deliberately absent from this mock.
  expect_identical(
    parent_capture_note(pair_completion_target(TRUE, FALSE)),
    "tag F (pair completion)"
  )
  # MM uncertainty still belongs in Parents to resight, not pair completion.
  expect_identical(
    pair_completion_target(
      FALSE,
      TRUE,
      female_mm_pending = TRUE
    ),
    NULL
  )
  expect_identical(
    pair_completion_target(
      TRUE,
      FALSE,
      male_mm_pending = TRUE
    ),
    NULL
  )
  # Quota and parent eligibility remain authoritative.
  expect_identical(
    pair_completion_target(
      FALSE,
      TRUE,
      male_quota_remaining = 0
    ),
    NULL
  )
})


test_that("confirmed X-X alternate parent can complete a tagged pair", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "COALESCE(base.M_captured_has_geo, 0) = 1\n                   AND (\n                     COALESCE(base.M_mm_resight_pending, 0) = 0\n                     OR COALESCE(base.F_confirmed_unbanded, 0) = 1\n                   )",
    fixed = TRUE
  )
  expect_match(
    sql,
    "COALESCE(base.F_captured_has_geo, 0) = 1\n                   AND (\n                     COALESCE(base.F_mm_resight_pending, 0) = 0\n                     OR COALESCE(base.M_confirmed_unbanded, 0) = 1\n                   )",
    fixed = TRUE
  )
  expect_match(sql, "THEN 'X-X F'", fixed = TRUE)

  pair_completion_target <- function(
    target_sex,
    target_is_xx,
    opposite_captured_has_geo,
    opposite_mm_pending,
    target_tag_eligible = TRUE,
    target_quota_remaining = 1
  ) {
    alternate_parent_resolves <- target_is_xx && opposite_mm_pending
    if (
      target_sex == "F" &&
        target_tag_eligible &&
        target_quota_remaining > 0 &&
        opposite_captured_has_geo &&
        (!opposite_mm_pending || alternate_parent_resolves)
    ) {
      return("F")
    }
    NULL
  }

  pair_note <- function(target_sex, target_mark) {
    target_label <- if (identical(target_mark, "X-X")) {
      paste("X-X", target_sex)
    } else {
      target_sex
    }
    paste0("tag ", target_label, " (pair completion)")
  }

  expect_identical(
    pair_completion_target("F", TRUE, TRUE, TRUE),
    "F"
  )
  expect_identical(
    pair_note("F", "X-X"),
    "tag X-X F (pair completion)"
  )
  expect_null(
    pair_completion_target("F", TRUE, TRUE, TRUE, target_tag_eligible = FALSE)
  )
  expect_null(
    pair_completion_target("F", TRUE, FALSE, TRUE)
  )
})


test_that("live X-X after a dead MM capture remains GEO eligible", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "COALESCE(parent_status.M_is_dead, 0) = 0\n                   OR (\n                     COALESCE(parent_status.M_mm_xx_parent_confirmed, 0) = 1\n                     AND COALESCE(parent_status.M_confirmed_unbanded, 0) = 1\n                     AND COALESCE(parent_status.M_mm_resight_pending, 0) = 0\n                   )",
    fixed = TRUE
  )
  expect_match(
    sql,
    "AS M_mm_xx_parent_confirmed",
    fixed = TRUE
  )

  tag_eligible <- function(
    is_dead,
    mm_xx_parent_confirmed,
    confirmed_unbanded,
    mm_resight_pending = FALSE
  ) {
    !isTRUE(mm_resight_pending) &&
      (
        !isTRUE(is_dead) ||
          (
            isTRUE(mm_xx_parent_confirmed) &&
              isTRUE(confirmed_unbanded) &&
              !isTRUE(mm_resight_pending)
          )
      )
  }

  # C0217-like chronology: dead MM capture, then live X-X with IN.
  expect_true(tag_eligible(TRUE, TRUE, TRUE))
  # A dead parent without a later qualifying live X-X remains ineligible.
  expect_false(tag_eligible(TRUE, FALSE, FALSE))
  # Pending MM uncertainty still blocks tag deployment.
  expect_false(tag_eligible(TRUE, TRUE, TRUE, mm_resight_pending = TRUE))
})


test_that("resolved MM follow-up uses the canonical captured parent mark", {
  sql <- todo_list_view_sql()

  expect_match(
    sql,
    "COALESCE(adult_mm_followup_status.F_mm_resight_pending, 0) = 1",
    fixed = TRUE
  )
  expect_match(
    sql,
    "adult_parent_identity_status.F_identity_mark",
    fixed = TRUE
  )

  displayed_female_mark <- function(
    followup_pending,
    mm_capture_mark,
    identity_mark,
    post_mm_xx_seen
  ) {
    if (isTRUE(followup_pending) && !is.null(mm_capture_mark)) {
      if (isTRUE(post_mm_xx_seen)) {
        return(paste(mm_capture_mark, "& X-X"))
      }
      return(mm_capture_mark)
    }
    identity_mark
  }

  expect_identical(
    displayed_female_mark(TRUE, "BY-YY", "BY-YY", TRUE),
    "BY-YY & X-X"
  )
  expect_identical(
    displayed_female_mark(FALSE, "BY-YY", "BY-YY", TRUE),
    "BY-YY"
  )
})


test_that("TODO_LIST stays within the known MariaDB CTE limit", {
  sql <- todo_list_view_sql()
  lines <- strsplit(sql, "\n", fixed = TRUE)[[1]]
  cte_lines <- grep("^[A-Za-z0-9_]+ AS \\($", lines, value = TRUE)

  expect_gt(length(cte_lines), 0L)
  expect_lte(length(cte_lines), 63L)
})
