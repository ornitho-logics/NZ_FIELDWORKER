library(testthat)

views_sql <- paste(
  readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
  collapse = "\n"
)
refresh_sql <- paste(
  readLines(
    app_file("DATABASE", "refresh_todo_list_snapshot.SQL"),
    warn = FALSE
  ),
  collapse = "\n"
)

count_fixed <- function(x, pattern) {
  hits <- gregexpr(pattern, x, fixed = TRUE)[[1L]]
  if (identical(hits, -1L)) 0L else length(hits)
}

test_that("capture event projections read the keyed CTE that defines origin_key", {
  for (sql in list(views_sql, refresh_sql)) {
    expect_match(
      sql,
      "e.capture_status\n  FROM keyed_chick_events e\n  LEFT JOIN resolved_prior_ring_nests inferred",
      fixed = TRUE
    )
    expect_no_match(
      sql,
      "e.capture_status\n  FROM raw_chick_events e\n  LEFT JOIN resolved_prior_ring_nests inferred",
      fixed = TRUE
    )
  }
})

test_that("GPS parent links require a same-date exact event", {
  expect_gte(
    count_fixed(views_sql, "c.capture_date = chick.observation_date"),
    3L
  )
  expect_gte(
    count_fixed(views_sql, "opposite.observation_date = chick.observation_date"),
    2L
  )
  expect_match(
    views_sql,
    "known.evidence_date <= opposite.observation_date",
    fixed = TRUE
  )
})

test_that("closure paths retain the shared evidence-eligibility gate", {
  expect_match(
    views_sql,
    "CASE\n      WHEN MAX(event_union.definitive_capture) = 1",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "WHEN MAX(event_union.confirming_resighting) = 1",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "THEN MIN(CASE\n        WHEN nonconfirming.nonconfirming_rank = 3",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "DATE(a.association_evidence_datetime)",
    fixed = TRUE
  )
  expect_gte(
    count_fixed(refresh_sql, "m.association_evidence_eligible = 1"),
    2L
  )
  expect_match(
    refresh_sql,
    "UPPER(TRIM(COALESCE(n.nest_state, ''))) IN ('S', 'F', 'I')",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "later_nest_parent_sex_count = 2",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "WHEN nonconfirming.nonconfirming_rank = 3",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "DATE(a.association_evidence_datetime),\n    old_proof.old_association_proof_date",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "FROM FIELD_2026_BADOatNZ.NESTS earlier_nest",
    fixed = TRUE
  )
})

test_that("ordinary unlinked links allow ringless rows but retain H-ring fallback", {
  start <- regexpr(
    "FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_RESIGHTING_ASSOCIATIONS AS",
    views_sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(start, 0L)

  remainder <- substring(views_sql, start)
  finish <- regexpr(
    "TODO_ORDINARY_FAMILY_RESIGHTING_ASSOCIATIONS",
    remainder,
    fixed = TRUE
  )[[1L]]
  expect_gt(finish, 0L)
  s10_sql <- substring(remainder, 1L, finish - 1L)

  expect_no_match(
    s10_sql,
    "UPPER(TRIM(COALESCE(r.rclass, ''))) <> 'H'",
    fixed = TRUE
  )
  expect_match(s10_sql, "OR chick.ring_key IS NOT NULL", fixed = TRUE)
  expect_match(views_sql, "AND r.rclass = 'H'", fixed = TRUE)
  expect_match(views_sql, "flag_ring_links", fixed = TRUE)
  expect_match(refresh_sql, "flag_ring_links", fixed = TRUE)
  expect_no_match(
    views_sql,
    "origin.origin_lookup_key = current_event.flag_origin_key",
    fixed = TRUE
  )
  expect_no_match(
    refresh_sql,
    "origin.origin_lookup_key = current_event.flag_origin_key",
    fixed = TRUE
  )
})

test_that("juvenile-origin helpers stay aligned and use exposed parent fields", {
  for (source_sql in list(views_sql, refresh_sql)) {
    if (identical(source_sql, views_sql)) {
      expect_match(
        source_sql,
        "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_JUVENILE_ORIGIN_EVENTS_INPUT AS",
        fixed = TRUE
      )
    } else {
      expect_match(
        source_sql,
        "CREATE TEMPORARY TABLE tmp_todo_juvenile_origin_events AS",
        fixed = TRUE
      )
    }
    expect_match(source_sql, "age_c_origin_evidence", fixed = TRUE)
    expect_match(source_sql, "age_c_origin_summary", fixed = TRUE)
    expect_match(source_sql, "flag_ring_links", fixed = TRUE)
    expect_match(source_sql, "resighting_flag_ring_summary", fixed = TRUE)
    expect_match(
      source_sql,
      "events.nest_id_source IN ('recorded', 'prior_ring')",
      fixed = TRUE
    )
    expect_match(source_sql, "capture_flag_ring_summary", fixed = TRUE)
    expect_match(
      source_sql,
      "links.link_event_date < current_event.event_date",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "links.link_event_datetime < captures.event_datetime",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "links.link_capture_pk < captures.capture_pk",
      fixed = TRUE
    )
    expect_match(source_sql, "bridge.n_ring_keys = 1", fixed = TRUE)
    expect_no_match(
      source_sql,
      "origin.origin_lookup_key = current_event.flag_origin_key",
      fixed = TRUE
    )
    expect_no_match(source_sql, "\\bevent\\.(event_date|resighting_pk)\\b")
  }

  expect_no_match(
    refresh_sql,
    "a.association_evidence_eligible",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "a.association_evidence_datetime IS NOT NULL",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "JOIN tmp_todo_closure_parent_associations a",
    fixed = TRUE
  )
})

test_that("closure and ordinary-family routes keep event-level gates", {
  expect_match(
    refresh_sql,
    "tmp_todo_closure_later_pairs",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "GREATEST(male.later_nest_date, female.later_nest_date)",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "WHEN raw.evidence_type = 'authoritative_selected'",
    fixed = TRUE
  )
  expect_match(refresh_sql, "tmp_todo_closure_old_proof", fixed = TRUE)
  expect_match(
    refresh_sql,
    "old_proof.old_association_proof_date",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "JOIN tmp_todo_ordinary_family_resighting_associations ordinary",
    fixed = TRUE
  )
  for (source_sql in list(views_sql, refresh_sql)) {
    if (identical(source_sql, views_sql)) {
      expect_match(source_sql, "TODO_ORDINARY_FAMILY_RESIGHTING_ASSOCIATIONS", fixed = TRUE)
    } else {
      expect_match(source_sql, "tmp_todo_ordinary_family_resighting_associations", fixed = TRUE)
    }
    expect_match(source_sql, "adult_source_table", fixed = TRUE)
    expect_match(source_sql, "adult_source_pk", fixed = TRUE)
    expect_match(source_sql, "adult_capture_status", fixed = TRUE)
    expect_match(source_sql, "conflicting_resighting", fixed = TRUE)
    expect_match(source_sql, "summary.n_adult_nest_ids = 1", fixed = TRUE)
  }
})

test_that("renesting keeps medium old-history pairs date-bounded", {
  expect_match(
    refresh_sql,
    "INSERT INTO tmp_todo_closure_old_proof (",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "WHERE identities.identity_confidence = 'medium'",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "AND m.association_evidence_eligible = 1",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "GREATEST(\n    MIN(n.date),\n    MIN(m.observation_date),\n    old_proof.old_association_proof_date\n  ) AS later_nest_date",
    fixed = TRUE
  )
  expect_no_match(
    refresh_sql,
    "old_proof.old_association_proof_date <= m.observation_date",
    fixed = TRUE
  )

  old_history <- data.frame(
    sex = c("M", "F"),
    confidence = c("medium", "medium"),
    old_date = as.Date(c("2026-09-01", "2026-09-02")),
    stringsAsFactors = FALSE
  )
  selected_old_proof <- old_history[old_history$confidence == "high", , drop = FALSE]
  medium_old_proof <- old_history[old_history$confidence == "medium", , drop = FALSE]

  expect_equal(nrow(selected_old_proof), 0L)
  expect_equal(nrow(medium_old_proof), 2L)
  expect_true(all(medium_old_proof$old_date <= as.Date("2026-09-10")))
  expect_setequal(medium_old_proof$sex, c("M", "F"))
})

test_that("H-photo GPS association vetoes explicit same-occasion chick conflicts", {
  start <- regexpr(
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS AS",
    views_sql,
    fixed = TRUE
  )[[1L]]
  remainder <- substring(views_sql, start)
  finish <- regexpr(
    "CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.BROODS_LATEST AS",
    remainder,
    fixed = TRUE
  )[[1L]]
  expect_gt(start, 0L)
  expect_gt(finish, 0L)
  h_sql <- substring(remainder, 1L, finish - 1L)
  expect_match(h_sql, "h.resighting_date", fixed = TRUE)
  expect_match(h_sql, "FROM FIELD_2026_BADOatNZ.CAPTURES conflicting_capture", fixed = TRUE)
  expect_match(h_sql, "FROM FIELD_2026_BADOatNZ.RESIGHTINGS conflicting_resighting", fixed = TRUE)
  expect_match(h_sql, "conflicting_capture.nest_id", fixed = TRUE)
  expect_match(h_sql, "conflicting_resighting.nest_id", fixed = TRUE)
})

test_that("S10 and juvenile origin routes reject future or conflicting evidence", {
  for (source_sql in list(views_sql, refresh_sql)) {
    expect_match(
      source_sql,
      "proof.association_proof_date <= r.date",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "all_proof.all_parent_proof_date <= r.date",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "UPPER(TRIM(conflicting_resighting.nest_id)) <>",
      fixed = TRUE
    )
    expect_match(source_sql, "event_datetime", fixed = TRUE)
    expect_match(
      source_sql,
      "origin.origin_event_datetime <= captures.event_datetime",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "origin.first_origin_date < current_event.event_date",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "flag_bridge.ring_key = captures.ring_key",
      fixed = TRUE
    )
  }

  juvenile_views <- lapply(
    list(views_sql, refresh_sql),
    function(source_sql) {
      start <- regexpr(
        if (identical(source_sql, views_sql)) {
          "TODO_JUVENILE_ORIGIN_EVENTS_INPUT AS"
        } else {
          "tmp_todo_juvenile_origin_events AS"
        },
        source_sql,
        fixed = TRUE
      )[[1L]]
      remainder <- substring(source_sql, start)
      finish <- regexpr(
        if (identical(source_sql, views_sql)) {
          "TODO_PARENT_CHICK_RESIGHTING_ASSOCIATIONS AS"
        } else {
          "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT AS"
        },
        remainder,
        fixed = TRUE
      )[[1L]]
      expect_gt(start, 0L)
      expect_gt(finish, 0L)
      substring(remainder, 1L, finish - 1L)
    }
  )
  for (juvenile_sql in juvenile_views) {
    expect_no_match(juvenile_sql, "prior_resighting_candidates", fixed = TRUE)
    expect_no_match(juvenile_sql, "latest_prior_event_date", fixed = TRUE)
    expect_match(juvenile_sql, "age_c_origin_summary", fixed = TRUE)
  }
  expect_match(
    refresh_sql,
    "CASE WHEN COALESCE(r.reactivation_evidence_count, 0) > 0",
    fixed = TRUE
  )
  expect_no_match(
    refresh_sql,
    "OR s.brood_id IS NOT NULL\n    THEN 1 ELSE 0 END",
    fixed = TRUE
  )
})

test_that("reactivation only accepts live capture statuses and approved links", {
  expect_match(
    refresh_sql,
    "UPPER(TRIM(COALESCE(x.capture_status, ''))) IN ('F', 'R', 'C')",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "tmp_todo_parent_chick_resighting_associations link",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT links",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "tmp_todo_juvenile_origin_events events",
    fixed = TRUE
  )
  expect_no_match(
    refresh_sql,
    "FIELD_2026_BADOatNZ.BROODS_LATEST brood",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "tmp_todo_chick_capture_events x",
    fixed = TRUE
  )
  expect_match(refresh_sql, "x.nest_id_source = 'prior_ring'", fixed = TRUE)
  expect_match(refresh_sql, "COALESCE(links.is_dead, 0) = 0", fixed = TRUE)
  expect_gte(
    count_fixed(refresh_sql, "x.date >= c.closure_candidate_date"),
    4L
  )
})

test_that("age-J success is distinct from presumed-dead closure", {
  expect_match(
    views_sql,
    "is_resolved TINYINT NOT NULL DEFAULT 0",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "CASE WHEN s.brood_id IS NOT NULL THEN 1 ELSE 0 END AS is_resolved",
    fixed = TRUE
  )
  expect_match(refresh_sql, "AND s.brood_id IS NULL", fixed = TRUE)
  expect_match(
    views_sql,
    "AND COALESCE(s.is_resolved, 0) = 0",
    fixed = TRUE
  )
  expect_match(refresh_sql, "OR closure.is_resolved = 1", fixed = TRUE)
})

test_that("juvenile origin matching ignores dead/unknown and ambiguous history", {
  expect_match(
    views_sql,
    "captures.age = 'J'",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "UPPER(TRIM(COALESCE(captures.capture_status, ''))) IN ('F', 'R', 'C')",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "HAVING COUNT(DISTINCT nest_id) = 1",
    fixed = TRUE
  )

  resolve_latest_origin <- function(events, origin_key, event_date) {
    live <- events[
      events$origin_key == origin_key &
        events$event_date <= event_date &
        events$capture_status %in% c("F", "R", "C") &
        !is.na(events$nest_id),
      ,
      drop = FALSE
    ]
    if (!nrow(live)) return(NA_character_)
    latest_date <- max(live$event_date)
    ids <- unique(live$nest_id[live$event_date == latest_date])
    if (length(ids) == 1L) ids[[1L]] else NA_character_
  }

  events <- data.frame(
    origin_key = c("ring:CP00001", "ring:CP00001", "ring:CP00002"),
    event_date = as.Date(c("2026-10-01", "2026-10-02", "2026-10-02")),
    capture_status = c("D", "F", ""),
    nest_id = c("B0101", "B0101", "B0102"),
    stringsAsFactors = FALSE
  )
  expect_equal(
    resolve_latest_origin(events, "ring:CP00001", as.Date("2026-10-03")),
    "B0101"
  )
  expect_true(
    is.na(
      resolve_latest_origin(events, "ring:CP00002", as.Date("2026-10-03"))
    )
  )

  ambiguous <- rbind(
    events[2, ],
    transform(events[2, ], nest_id = "B0102")
  )
  expect_true(
    is.na(
      resolve_latest_origin(ambiguous, "ring:CP00001", as.Date("2026-10-03"))
    )
  )
})

test_that("flag-only juvenile origin follows its verified ring bridge", {
  events <- data.frame(
    capture_pk = 1:3,
    age = c("C", "C", "J"),
    ring_key = c("RINGR", "RINGR", NA),
    flag_code = c(NA, "FWZZ", "FWZZ"),
    nest_id = c("B0901", "B0902", NA),
    nest_id_source = c("recorded", "prior_ring", ""),
    event_date = as.Date(c("2026-08-01", "2026-08-15", "2026-09-01")),
    event_datetime = as.POSIXct(
      c("2026-08-01 09:00:00", "2026-08-15 09:00:00", "2026-09-01 09:00:00"),
      tz = "UTC"
    ),
    capture_status = c("F", "C", ""),
    stringsAsFactors = FALSE
  )

  resolve_flag_only_origin <- function(events, flag_code, event_date) {
    live <- events[
      events$age == "C" &
        !is.na(events$ring_key) &
        !is.na(events$flag_code) &
        events$flag_code == flag_code &
        events$nest_id_source %in% c("recorded", "prior_ring") &
        events$event_date < event_date &
        events$capture_status %in% c("F", "R", "C"),
      ,
      drop = FALSE
    ]
    if (!nrow(live)) return(NA_character_)
    ring_ids <- unique(live$ring_key)
    if (length(ring_ids) != 1L) return(NA_character_)

    origin <- events[
      events$age == "C" &
        !is.na(events$ring_key) &
        events$ring_key == ring_ids[[1L]] &
        events$capture_status %in% c("F", "R", "C"),
      ,
      drop = FALSE
    ]
    priority <- if (any(origin$capture_status == "F")) "F" else c("R", "C")
    origin <- origin[origin$capture_status %in% priority, , drop = FALSE]
    first_date <- min(origin$event_date)
    ids <- unique(origin$nest_id[origin$event_date == first_date])
    if (length(ids) == 1L) ids[[1L]] else NA_character_
  }

  expect_equal(
    resolve_flag_only_origin(events, "FWZZ", as.Date("2026-09-01")),
    "B0901"
  )

  resolve_known_ring_origin <- function(events, ring_key, flag_code, event_date) {
    links <- events[
      events$age == "C" &
        !is.na(events$ring_key) &
        !is.na(events$flag_code) &
        events$flag_code == flag_code &
        events$nest_id_source %in% c("recorded", "prior_ring") &
        events$event_date < event_date,
      ,
      drop = FALSE
    ]
    linked_rings <- unique(links$ring_key)
    if (length(linked_rings) > 0L &&
        (length(linked_rings) != 1L || linked_rings[[1L]] != ring_key)) {
      return(NA_character_)
    }
    origin <- events[
      events$age == "C" &
        events$ring_key == ring_key &
        events$capture_status %in% c("F", "R", "C"),
      ,
      drop = FALSE
    ]
    if (!nrow(origin)) return(NA_character_)
    first_date <- min(origin$event_date[origin$capture_status == "F"])
    ids <- unique(origin$nest_id[origin$event_date == first_date])
    if (length(ids) == 1L) ids[[1L]] else NA_character_
  }

  expect_equal(
    resolve_known_ring_origin(events, "RINGR", "FWZZ", as.Date("2026-09-01")),
    "B0901"
  )
  expect_true(
    is.na(
      resolve_flag_only_origin(events, "FWZZ", as.Date("2026-08-10"))
    )
  )

  conflicting_flag_links <- rbind(
    events,
    transform(events[2, ], capture_pk = 4L, ring_key = "RINGQ")
  )
  expect_true(
    is.na(
      resolve_flag_only_origin(
        conflicting_flag_links,
        "FWZZ",
        as.Date("2026-09-01")
      )
    )
  )
  expect_true(
    is.na(
      resolve_known_ring_origin(
        conflicting_flag_links,
        "RINGR",
        "FWZZ",
        as.Date("2026-09-01")
      )
    )
  )
})

test_that("final notA checks survive mobile-brood closure suppression", {
  expect_match(refresh_sql, "'notA nest-check'", fixed = TRUE)
  expect_match(
    refresh_sql,
    "= 'notA nest-check'\n  OR NOT EXISTS (",
    fixed = TRUE
  )
})

test_that("mock policy distinguishes live captures from dead or unknown captures", {
  live_capture_status <- function(status) {
    toupper(trimws(ifelse(is.na(status), "", status))) %in% c("F", "R", "C")
  }

  expect_true(all(live_capture_status(c("F", "R", "C"))))
  expect_false(any(live_capture_status(c("D", NA, ""))))
})

test_that("mock policy does not infer dual-parent renesting from same-sex rows", {
  dual_parent_trigger <- function(authoritative_count, parent_count, sex_count) {
    authoritative_count >= 1L || (parent_count >= 2L && sex_count == 2L)
  }

  expect_true(dual_parent_trigger(0L, 2L, 2L))
  expect_true(dual_parent_trigger(1L, 1L, 1L))
  expect_false(dual_parent_trigger(0L, 2L, 1L))
})

test_that("candidate-6 preserves final identity vetoes through direct fallback", {
  for (source_sql in list(views_sql, refresh_sql)) {
    expect_match(source_sql, "resighting_identity_conflicts", fixed = TRUE)
    expect_match(source_sql, "capture_identity_conflicts", fixed = TRUE)
    expect_match(
      source_sql,
      "WHEN capture_conflict.capture_pk IS NOT NULL\n      THEN NULL",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "WHEN resighting_conflict.resighting_pk IS NOT NULL\n      THEN NULL",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "THEN 'unresolved_identity_conflict'",
      fixed = TRUE
    )
  }

  resolve_final_event <- function(origin_nests, recorded_id, conflict) {
    if (isTRUE(conflict)) return(NA_character_)
    if (origin_nests == 1L) return("ORIGIN")
    if (origin_nests > 1L) return(NA_character_)
    recorded_id
  }

  expect_true(
    is.na(resolve_final_event(0L, "A9030", conflict = TRUE))
  )
  expect_equal(
    resolve_final_event(0L, "A9030", conflict = FALSE),
    "A9030"
  )
  expect_equal(
    resolve_final_event(1L, "A9030", conflict = FALSE),
    "ORIGIN"
  )
})

test_that("candidate-6 uses raw encounter-wide GPS nest consensus", {
  expect_match(
    views_sql,
    "TODO_RAW_ENCOUNTER_NEST_CONSENSUS",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "COALESCE(c.nest_id, chick.nest_id) AS nest_id",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "AND encounter.n_explicit_nest_ids = 1",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "encounter.explicit_nest_id = UPPER(TRIM(parent.nest_id))",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "MIN(raw_encounters.nest_id) AS explicit_nest_id",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "UPPER(TRIM(COALESCE(c.species, ''))) = 'BADO'",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "UPPER(TRIM(COALESCE(r.species, ''))) = 'BADO'",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "tmp_todo_raw_encounter_nest_consensus",
    fixed = TRUE
  )
  expect_gte(
    count_fixed(views_sql, "TODO_RAW_ENCOUNTER_NEST_CONSENSUS"),
    6L
  )

  encounter_id <- function(adult_id, chick_ids) {
    ids <- unique(c(adult_id, chick_ids))
    ids <- ids[!is.na(ids) & nzchar(ids)]
    if (length(ids) == 1L) ids[[1L]] else NA_character_
  }

  expect_equal(encounter_id("A9035", "A9035"), "A9035")
  expect_equal(encounter_id("A9036", character()), "A9036")
  expect_equal(encounter_id(NA_character_, "A9037"), "A9037")
  expect_true(is.na(encounter_id("A9032", "A9033")))
  expect_true(is.na(encounter_id("A9032", c("A9032", "A9033"))))
})

test_that("candidate-6 applies the identity and raw-evidence truth tables", {
  for (source_sql in list(views_sql, refresh_sql)) {
    expect_match(
      source_sql,
      "WHERE current_event.flag_origin_key IS NOT NULL",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "flag_bridge.n_ring_keys <> 1",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "current_event.ring_origin_key IS NOT NULL",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "captures.ring_key IS NOT NULL\n        AND flag_bridge.ring_key <> captures.ring_key",
      fixed = TRUE
    )
  }

  bridge_conflict <- function(current_ring, n_bridged_rings, bridged_ring) {
    if (is.na(n_bridged_rings) || n_bridged_rings == 0L) {
      return(FALSE)
    }
    n_bridged_rings > 1L || (
      n_bridged_rings == 1L &&
        !is.na(current_ring) &&
        current_ring != bridged_ring
    )
  }

  expect_false(bridge_conflict(NA_character_, 0L, NA_character_))
  expect_false(bridge_conflict(NA_character_, 1L, "R9040"))
  expect_true(bridge_conflict(NA_character_, 2L, NA_character_))
  expect_false(bridge_conflict("R9040", 1L, "R9040"))
  expect_true(bridge_conflict("R9040", 1L, "R9041"))
  expect_true(bridge_conflict("R9040", 2L, "R9041"))

  raw_ids <- function(ids) {
    ids <- unique(ids[!is.na(ids) & nzchar(ids)])
    length(ids)
  }

  expect_equal(raw_ids(c("A9042", "A9042")), 1L)
  expect_equal(raw_ids(c("A9042", "A9043")), 2L)
  expect_equal(raw_ids(c("A9042", NA_character_, "")), 1L)
})

test_that("candidate-6 retains unresolved age-J events without changing age-C counts", {
  for (source_sql in list(views_sql, refresh_sql)) {
    expect_match(
      source_sql,
      "ELSE 'unresolved'",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "WHERE e.age = 'J'\n     OR COALESCE(e.recorded_nest_id, inferred.inferred_nest_id) IS NOT NULL",
      fixed = TRUE
    )
    expect_match(
      source_sql,
      "WHERE events.age = 'C'",
      fixed = TRUE
    )
  }

  retain_event <- function(age, recorded_id, inferred_id) {
    age == "J" || !is.na(recorded_id) || !is.na(inferred_id)
  }

  expect_true(retain_event("J", NA_character_, NA_character_))
  expect_true(retain_event("J", NA_character_, "A9034"))
  expect_true(retain_event("C", "A9034", NA_character_))
  expect_false(retain_event("C", NA_character_, NA_character_))
})

test_that("candidate-7 carries canonical encounter targets through final fallbacks", {
  expect_equal(
    count_fixed(views_sql, "SET SESSION lock_wait_timeout = 30;"),
    1L
  )
  timeout_pos <- regexpr(
    "SET SESSION lock_wait_timeout = 30;",
    views_sql,
    fixed = TRUE
  )[[1L]]
  helper_pos <- regexpr(
    "CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW\n  FIELD_2026_BADOatNZ.TODO_RAW_ENCOUNTER_NEST_CONSENSUS",
    views_sql,
    fixed = TRUE
  )[[1L]]
  expect_gt(timeout_pos, 0L)
  expect_gt(helper_pos, 0L)
  expect_lt(timeout_pos, helper_pos)

  expect_match(
    views_sql,
    "WHEN COALESCE(encounter.n_explicit_nest_ids, 0) > 1\n    THEN NULL",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "encounter.explicit_nest_id = UPPER(TRIM(captures.capture_nest_id))",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "encounter.explicit_nest_id = UPPER(TRIM(parent.nest_id))",
    fixed = TRUE
  )
  expect_match(
    views_sql,
    "encounter.explicit_nest_id = UPPER(TRIM(adult.adult_nest_id))",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "encounter.explicit_nest_id = UPPER(TRIM(parent.nest_id))",
    fixed = TRUE
  )
  expect_match(
    refresh_sql,
    "encounter.explicit_nest_id = UPPER(TRIM(adult.adult_nest_id))",
    fixed = TRUE
  )

  resolve_inferred_target <- function(raw_count, raw_id, target) {
    if (raw_count > 1L) return(NA_character_)
    if (raw_count == 1L && !identical(raw_id, target)) {
      return(NA_character_)
    }
    target
  }

  expect_true(is.na(resolve_inferred_target(2L, NA_character_, "-A9060")))
  expect_equal(resolve_inferred_target(1L, "-A9060", "-A9060"), "-A9060")
  expect_true(is.na(resolve_inferred_target(1L, "-A9061", "-A9060")))
  expect_equal(resolve_inferred_target(0L, NA_character_, "-A9060"), "-A9060")

  resolve_h_fallback <- function(raw_id, raw_count, raw_id_key, ring_target) {
    if (!is.na(raw_id) && nzchar(raw_id)) return(raw_id)
    if (raw_count > 1L) return(NA_character_)
    if (raw_count == 1L && !identical(raw_id_key, ring_target)) {
      return(NA_character_)
    }
    ring_target
  }

  expect_equal(
    resolve_h_fallback("A9060", 2L, "A9061", "A9060"),
    "A9060"
  )
  expect_true(
    is.na(resolve_h_fallback(NA_character_, 2L, "A9060", "A9060"))
  )
  expect_true(
    is.na(resolve_h_fallback(NA_character_, 1L, "A9061", "A9060"))
  )
  expect_equal(
    resolve_h_fallback(NA_character_, 1L, "A9060", "A9060"),
    "A9060"
  )
  expect_equal(
    resolve_h_fallback(NA_character_, 0L, NA_character_, "A9060"),
    "A9060"
  )
})

test_that("candidate-7 applies only the approved age-J D developmental rule", {
  for (source_sql in list(views_sql, refresh_sql)) {
    expect_match(source_sql, "developmental_age_j", fixed = TRUE)
    expect_match(
      source_sql,
      "captures.association_method = 'developmental_age_j'",
      fixed = TRUE
    )
  }
  expect_match(
    refresh_sql,
    "events.association_method <> 'developmental_age_j'",
    fixed = TRUE
  )

  juvenile_resolution <- function(age, status, has_stable_origin) {
    age == "J" && has_stable_origin && status %in% c("F", "R", "C", "D")
  }

  expect_true(juvenile_resolution("J", "D", TRUE))
  expect_true(juvenile_resolution("J", "F", TRUE))
  expect_false(juvenile_resolution("J", "D", FALSE))
  expect_false(juvenile_resolution("C", "D", TRUE))
  expect_false(juvenile_resolution("J", "", TRUE))
  expect_false(juvenile_resolution("J", NA_character_, TRUE))
})
