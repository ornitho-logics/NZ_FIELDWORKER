mock_h_brood_associations <- function(
    h_events,
    chick_captures,
    parent_history,
    occasion_parents
) {
  keep_value <- function(x) {
    !is.na(x) & nzchar(trimws(as.character(x))) &
      toupper(trimws(as.character(x))) != "NA"
  }

  h_events <- as.data.frame(h_events, stringsAsFactors = FALSE)
  chick_captures <- as.data.frame(chick_captures, stringsAsFactors = FALSE)
  parent_history <- as.data.frame(parent_history, stringsAsFactors = FALSE)
  occasion_parents <- as.data.frame(occasion_parents, stringsAsFactors = FALSE)

  result <- lapply(seq_len(nrow(h_events)), function(i) {
    h <- h_events[i, , drop = FALSE]
    raw_id <- if (keep_value(h$nest_id)) {
      trimws(as.character(h$nest_id))
    } else {
      NA_character_
    }
    ring <- toupper(trimws(as.character(h$ring)))

    if (keep_value(raw_id) && toupper(raw_id) != "NO_NEST") {
      return(data.frame(
        h_id = h$h_id,
        resolved_nest_id = raw_id,
        association_status = "explicit",
        stringsAsFactors = FALSE
      ))
    }

    linked <- chick_captures[
      keep_value(chick_captures$ring) &
        toupper(trimws(chick_captures$ring)) == ring &
        as.Date(chick_captures$date) < as.Date(h$date) &
        keep_value(chick_captures$nest_id) &
        toupper(trimws(chick_captures$nest_id)) != "NO_NEST",
      ,
      drop = FALSE
    ]
    candidates <- unique(trimws(as.character(linked$nest_id)))

    if (!length(candidates)) {
      return(data.frame(
        h_id = h$h_id,
        resolved_nest_id = NA_character_,
        association_status = "unresolved",
        stringsAsFactors = FALSE
      ))
    }

    occasion <- occasion_parents[
      as.Date(occasion_parents$date) == as.Date(h$date) &
        as.character(occasion_parents$gps_id) == as.character(h$gps_id) &
        as.character(occasion_parents$gps_point) == as.character(h$gps_point),
      ,
      drop = FALSE
    ]

    supported <- vapply(candidates, function(candidate) {
      expected <- parent_history[
        trimws(as.character(parent_history$nest_id)) == candidate &
          as.Date(parent_history$date) < as.Date(h$date) &
          keep_value(parent_history$identity_key),
        ,
        drop = FALSE
      ]
      expected_sex <- unique(as.character(expected$sex))
      if (!length(expected_sex)) {
        return(FALSE)
      }

      matched <- vapply(expected_sex, function(sex) {
        prior <- expected[expected$sex == sex, , drop = FALSE]
        current <- occasion[occasion$sex == sex, , drop = FALSE]
        any(
          keep_value(current$identity_key) &
            vapply(current$identity_key, function(identity) {
              any(prior$identity_key == identity)
            }, logical(1))
        )
      }, logical(1))

      expected_identities <- unique(as.character(expected$identity_key))
      current_identities <- unique(as.character(occasion$identity_key))
      matched_identities <- intersect(current_identities, expected_identities)

      all(matched) &&
        length(current_identities) == length(matched_identities) &&
        length(current_identities) == length(expected_sex)
    }, logical(1))

    if (sum(supported) == 1L) {
      return(data.frame(
        h_id = h$h_id,
        resolved_nest_id = candidates[which(supported)],
        association_status = "derived",
        stringsAsFactors = FALSE
      ))
    }

    data.frame(
      h_id = rep(h$h_id, length(candidates)),
      resolved_nest_id = candidates,
      association_status = "ambiguous",
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, result)
}


mock_h_event <- function(
    h_id,
    date = "2026-09-03",
    nest_id = NA_character_,
    ring = "CP001",
    gps_id = "G1",
    gps_point = "P1"
) {
  data.frame(
    h_id = h_id,
    date = as.Date(date),
    nest_id = nest_id,
    ring = ring,
    gps_id = gps_id,
    gps_point = gps_point,
    stringsAsFactors = FALSE
  )
}


test_that("linked and unsupported H events remain explicit or unresolved", {
  explicit <- mock_h_brood_associations(
    mock_h_event("linked", nest_id = "A_MOCK"),
    data.frame(),
    data.frame(),
    data.frame()
  )
  unresolved <- mock_h_brood_associations(
    mock_h_event("unresolved", nest_id = "NA"),
    data.frame(),
    data.frame(),
    data.frame()
  )

  expect_identical(explicit$resolved_nest_id, "A_MOCK")
  expect_identical(explicit$association_status, "explicit")
  expect_true(is.na(unresolved$resolved_nest_id))
  expect_identical(unresolved$association_status, "unresolved")
})


test_that("an unlinked H event resolves only with matching family evidence", {
  chick_captures <- data.frame(
    ring = "CP001",
    date = as.Date("2026-09-02"),
    nest_id = "A_MOCK",
    stringsAsFactors = FALSE
  )
  parent_history <- data.frame(
    nest_id = c("A_MOCK", "A_MOCK"),
    date = as.Date(c("2026-09-01", "2026-09-01")),
    sex = c("M", "F"),
    identity_key = c("M_PARENT", "F_PARENT"),
    stringsAsFactors = FALSE
  )
  matching_parents <- data.frame(
    date = as.Date(c("2026-09-03", "2026-09-03")),
    gps_id = c("G1", "G1"),
    gps_point = c("P1", "P1"),
    sex = c("M", "F"),
    identity_key = c("M_PARENT", "F_PARENT"),
    stringsAsFactors = FALSE
  )
  unmatched_parents <- matching_parents
  unmatched_parents$identity_key[2] <- "OTHER_FAMILY_F"

  derived <- mock_h_brood_associations(
    mock_h_event("derived"),
    chick_captures,
    parent_history,
    matching_parents
  )
  ambiguous <- mock_h_brood_associations(
    mock_h_event("ambiguous"),
    chick_captures,
    parent_history,
    unmatched_parents
  )

  expect_identical(derived$resolved_nest_id, "A_MOCK")
  expect_identical(derived$association_status, "derived")
  expect_identical(ambiguous$resolved_nest_id, "A_MOCK")
  expect_identical(ambiguous$association_status, "ambiguous")
})


test_that("one supported family wins without leaving false review rows", {
  observed <- mock_h_brood_associations(
    mock_h_event("one_supported"),
    data.frame(
      ring = c("CP001", "CP001"),
      date = as.Date(c("2026-09-01", "2026-09-02")),
      nest_id = c("A_MOCK", "B_MOCK"),
      stringsAsFactors = FALSE
    ),
    data.frame(
      nest_id = c("A_MOCK", "A_MOCK", "B_MOCK", "B_MOCK"),
      date = as.Date(rep("2026-09-01", 4)),
      sex = c("M", "F", "M", "F"),
      identity_key = c("A_M", "A_F", "B_M", "B_F"),
      stringsAsFactors = FALSE
    ),
    data.frame(
      date = as.Date(c("2026-09-03", "2026-09-03")),
      gps_id = c("G1", "G1"),
      gps_point = c("P1", "P1"),
      sex = c("M", "F"),
      identity_key = c("A_M", "A_F"),
      stringsAsFactors = FALSE
    )
  )

  expect_identical(nrow(observed), 1L)
  expect_identical(observed$resolved_nest_id, "A_MOCK")
  expect_identical(observed$association_status, "derived")
})


test_that("the helper status counts completion but retains review flags", {
  associations <- data.frame(
    reference_date = as.Date(rep("2026-09-28", 4)),
    h_id = c("h1", "h2", "h3", "h4"),
    resolved_nest_id = c("A_MOCK", "A_MOCK", "A_MOCK", NA),
    association_status = c("explicit", "derived", "ambiguous", "unresolved"),
    stringsAsFactors = FALSE
  )
  linked <- associations[!is.na(associations$resolved_nest_id), ]
  status <- aggregate(
    h_id ~ reference_date + resolved_nest_id,
    linked[linked$association_status %in% c("explicit", "derived"), ],
    function(x) length(unique(x))
  )
  names(status)[3] <- "n_hiding_spot_photos"
  review <- aggregate(
    association_status ~ reference_date + resolved_nest_id,
    linked,
    function(x) as.integer(any(x == "ambiguous"))
  )
  names(review)[3] <- "review_flag"
  status <- merge(status, review, all = TRUE)

  expect_identical(status$n_hiding_spot_photos, 2L)
  expect_identical(status$review_flag, 1L)
})


test_that("the SQL keeps association, helper, brood, and task layers separate", {
  sql <- paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )

  expect_match(sql, "RESIGHTINGS_H_BROOD_ASSOCIATIONS AS", fixed = TRUE)
  expect_match(sql, "HIDING_SPOT_STATUS AS", fixed = TRUE)
  expect_match(sql, "photo_start", fixed = TRUE)
  expect_match(sql, "photo_end", fixed = TRUE)
  expect_match(sql, "association_status IN ('explicit', 'derived')", fixed = TRUE)
  expect_match(sql, "association_status = 'ambiguous'", fixed = TRUE)
  expect_match(sql, "e.supported_candidate_count <> 1", fixed = TRUE)
  expect_match(sql, "a.resolved_nest_id AS nest_id", fixed = TRUE)
  expect_match(sql, "FROM resolved_h_events e", fixed = TRUE)

  helper_start <- regexpr(
    paste(
      "CREATE OR REPLACE VIEW",
      "FIELD_2026_BADOatNZ.HIDING_SPOT_STATUS AS"
    ),
    sql,
    fixed = TRUE
  )[[1]]
  expect_gt(helper_start, 0L)
  helper_remainder <- substring(sql, helper_start)
  helper_end <- regexpr(
    paste(
      "CREATE OR REPLACE VIEW",
      "FIELD_2026_BADOatNZ.BROODS_LATEST AS"
    ),
    helper_remainder,
    fixed = TRUE
  )[[1]]
  expect_gt(helper_end, 0L)
  helper_sql <- substring(helper_remainder, 1L, helper_end - 1L)

  expect_no_match(helper_sql, "\nWITH ", fixed = TRUE)
  expect_match(helper_sql, "GROUP BY a.reference_date", fixed = TRUE)
})
