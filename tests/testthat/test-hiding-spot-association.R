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
    raw_id <- if (keep_value(h$nest_id)) trimws(as.character(h$nest_id)) else NA_character_
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
      if (!length(expected_sex)) return(FALSE)

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

      current_identity <- unique(as.character(occasion$identity_key))
      matched_identity <- unique(
        as.character(occasion$identity_key)[
          as.character(occasion$identity_key) %in% unlist(
            lapply(expected_sex, function(sex) {
              expected$identity_key[expected$sex == sex]
            })
          )
        ]
      )

      all(matched) &&
        length(current_identity) == length(matched_identity) &&
        length(current_identity) == length(expected_sex)
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


test_that("a linked H row resolves without derived parent matching", {
  observed <- mock_h_brood_associations(
    mock_h_event("linked", nest_id = "A_MOCK"),
    data.frame(),
    data.frame(),
    data.frame()
  )

  expect_identical(observed$resolved_nest_id, "A_MOCK")
  expect_identical(observed$association_status, "explicit")
})


test_that("an unlinked H row resolves with both parents at shared GPS", {
  observed <- mock_h_brood_associations(
    mock_h_event("derived"),
    data.frame(
      ring = "CP001",
      date = as.Date("2026-09-02"),
      nest_id = "A_MOCK",
      stringsAsFactors = FALSE
    ),
    data.frame(
      nest_id = c("A_MOCK", "A_MOCK"),
      date = as.Date(c("2026-09-01", "2026-09-01")),
      sex = c("M", "F"),
      identity_key = c("M_PARENT", "F_PARENT"),
      stringsAsFactors = FALSE
    ),
    data.frame(
      date = as.Date(c("2026-09-03", "2026-09-03")),
      gps_id = c("G1", "G1"),
      gps_point = c("P1", "P1"),
      sex = c("M", "F"),
      identity_key = c("M_PARENT", "F_PARENT"),
      stringsAsFactors = FALSE
    )
  )

  expect_identical(observed$resolved_nest_id, "A_MOCK")
  expect_identical(observed$association_status, "derived")
})


test_that("one unmatched parent leaves the H association open for review", {
  observed <- mock_h_brood_associations(
    mock_h_event("unmatched"),
    data.frame(
      ring = "CP001",
      date = as.Date("2026-09-02"),
      nest_id = "A_MOCK",
      stringsAsFactors = FALSE
    ),
    data.frame(
      nest_id = c("A_MOCK", "A_MOCK"),
      date = as.Date(c("2026-09-01", "2026-09-01")),
      sex = c("M", "F"),
      identity_key = c("M_PARENT", "F_PARENT"),
      stringsAsFactors = FALSE
    ),
    data.frame(
      date = as.Date(c("2026-09-03", "2026-09-03")),
      gps_id = c("G1", "G1"),
      gps_point = c("P1", "P1"),
      sex = c("M", "F"),
      identity_key = c("M_PARENT", "OTHER_FAMILY_F"),
      stringsAsFactors = FALSE
    )
  )

  expect_identical(observed$association_status, "ambiguous")
  expect_identical(observed$resolved_nest_id, "A_MOCK")
})


test_that("two families sharing a GPS pair are not silently conflated", {
  h_events <- rbind(
    mock_h_event("family_a", ring = "CP001"),
    mock_h_event("family_b", ring = "CP002")
  )
  chick_captures <- data.frame(
    ring = c("CP001", "CP002"),
    date = as.Date(c("2026-09-02", "2026-09-02")),
    nest_id = c("A_MOCK", "B_MOCK"),
    stringsAsFactors = FALSE
  )
  parent_history <- data.frame(
    nest_id = rep(c("A_MOCK", "B_MOCK"), each = 2),
    date = as.Date(rep("2026-09-01", 4)),
    sex = rep(c("M", "F"), 2),
    identity_key = c("A_M", "A_F", "B_M", "B_F"),
    stringsAsFactors = FALSE
  )
  occasion_parents <- data.frame(
    date = as.Date(rep("2026-09-03", 4)),
    gps_id = rep("G1", 4),
    gps_point = rep("P1", 4),
    sex = c("M", "F", "M", "F"),
    identity_key = c("A_M", "A_F", "B_M", "B_F"),
    stringsAsFactors = FALSE
  )

  observed <- mock_h_brood_associations(
    h_events,
    chick_captures,
    parent_history,
    occasion_parents
  )

  expect_true(all(observed$association_status == "ambiguous"))
  expect_setequal(observed$resolved_nest_id, c("A_MOCK", "B_MOCK"))
})


test_that("multiple H photos resolve one operational task per brood", {
  h_events <- rbind(
    mock_h_event("h1", ring = "CP001"),
    mock_h_event("h2", ring = "CP002")
  )
  chick_captures <- data.frame(
    ring = c("CP001", "CP002"),
    date = as.Date(c("2026-09-02", "2026-09-02")),
    nest_id = c("-B_MOCK", "-B_MOCK"),
    stringsAsFactors = FALSE
  )
  parent_history <- data.frame(
    nest_id = "-B_MOCK",
    date = as.Date("2026-09-01"),
    sex = "M",
    identity_key = "M_PARENT",
    stringsAsFactors = FALSE
  )
  occasion_parents <- data.frame(
    date = as.Date(c("2026-09-03", "2026-09-03")),
    gps_id = c("G1", "G1"),
    gps_point = c("P1", "P1"),
    sex = c("M", "M"),
    identity_key = c("M_PARENT", "M_PARENT"),
    stringsAsFactors = FALSE
  )

  observed <- mock_h_brood_associations(
    h_events,
    chick_captures,
    parent_history,
    occasion_parents
  )

  expect_true(all(observed$association_status == "derived"))
  expect_setequal(unique(observed$resolved_nest_id), "-B_MOCK")
  expect_equal(nrow(observed), 2L)
})


test_that("the SQL contract keeps H metadata and association statuses explicit", {
  sql <- paste(
    readLines(app_file("DATABASE", "views.SQL"), warn = FALSE),
    collapse = "\n"
  )

  expect_match(sql, "RESIGHTINGS_H_BROOD_ASSOCIATIONS", fixed = TRUE)
  expect_match(sql, "photo_start", fixed = TRUE)
  expect_match(sql, "photo_end", fixed = TRUE)
  expect_match(sql, "association_status IN ('explicit', 'derived')", fixed = TRUE)
  expect_match(sql, "association_status = 'ambiguous'", fixed = TRUE)
  expect_match(sql, "a.resolved_nest_id AS nest_id", fixed = TRUE)
})
