test_that("tagged-bird PDF follow-up uses the strict unseen threshold", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare_unseen_tagged_birds

  view_1 <- data.frame(
    mark = c("MOCK-B", "MOCK-A", "MOCK-C", "MOCK-D", "MOCK-E"),
    sex = c("F", "M", "F", "M", "F"),
    nest_id = c("MOCK_NEST_02", "MOCK_NEST_01", NA, "MOCK_NEST_04", NA),
    days_since_cap = c(12, 15, 8, 20, 7),
    days_since_last_seen = c(NA, NA, NA, 3, NA)
  )

  observed <- prepare(view_1)

  expect_identical(
    names(observed),
    c("Mark", "Sex", "Nest", "Days Since Cap")
  )
  expect_identical(observed$Mark, c("MOCK-A", "MOCK-B", "MOCK-C"))
  expect_identical(observed$Nest, c("MOCK_NEST_01", "MOCK_NEST_02", ""))
  expect_identical(observed$`Days Since Cap`, c("15", "12", "8"))
})


test_that("to-do headings use the current operational subtitles", {
  app <- load_main_app()
  heading <- app$env$todo_pdf_heading

  expect_identical(
    heading("Hiding spot photos needed")$subtitle,
    "find these broods and take in-situ and tent photos before the chicks are 7 days old"
  )
  expect_identical(
    heading("Parent capture")$subtitle,
    "follow notes for tag deployment or band-only instructions"
  )
  expect_identical(
    heading("Parent resighting")$subtitle,
    "Association of MM-cap parent will resolve after either 1) three subsequent resightings, or 2) one ‘behav’ “IN”, “NM”, or “BW” resighting"
  )
  expect_identical(
    heading("nest check")$subtitle,
    "egg floatation data estimates that these nests are within 7 days of hatching"
  )
  expect_identical(
    heading("notA nest-check")$subtitle,
    "these nests have finished and can be closed; nest_ids with state \"H\" may still be active mobile broods that require monitoring"
  )
})


test_that("tagged-bird follow-up table is included in the PDF body", {
  app <- load_main_app()
  body <- app$env$todo_pdf_body(
    rows = data.table::data.table(),
    unseen_tagged_birds = data.table::data.table(
      Mark = "MOCK-A",
      Sex = "M",
      Nest = "MOCK_NEST_01",
      `Days Since Cap` = "15"
    )
  )

  expect_true(any(grepl("## Tagged birds to resight", body, fixed = TRUE)))
  expect_true(any(grepl(
    "These birds have not been in seen in over 7 days since tag deployment, please resight and comment either \"no limp\", \"slight limp\", or \"severe limp\".",
    body,
    fixed = TRUE
  )))
})


test_that("PDF display marks broods, unknown negative clutch, and capture status", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare

  todo <- data.frame(
    nest_id = c("-C0224", "C0615", "C0307", "C0625", "A0306", "B0220"),
    reference_date = as.Date(rep("2026-10-01", 6)),
    todo = c(
      "Parent capture", "Parent capture", "Parent capture",
      "Parent capture", "Parent capture", "notA nest-check"
    ),
    notes = c(
      "resight/band M (status ?)",
      "band X-X F; resight/band M",
      "resight/band F; band X-X M",
      "band X-X F; resight/band M",
      "resight/band F; band X-X M",
      "remove flag + do notA"
    ),
    nest_state = c(NA, "H", "I", "I", "I", "notA"),
    clutch_size = c(NA, 0, 3, 3, 3, NA),
    brood_size = c(3, 0, 0, 0, 0, 0),
    min_days_to_hatch = rep(NA, 6),
    last_visit_days_ago = rep(1, 6),
    M_mark = c(NA, "BY-TY.YW", "X-X", NA, NA, "MOCK-M"),
    F_mark = c("OY-YG", "X-X", "MOCK-F", "MOCK-F", "X-X", "MOCK-F"),
    stringsAsFactors = FALSE
  )

  observed <- prepare(
    todo = todo,
    available_combos = data.frame(mark = paste0("MOCK-", seq_len(30))),
    nests_latest = data.frame(),
    chick_captures = data.frame(
      nest_id = rep("-C0224", 3),
      age = rep("C", 3),
      ring = paste0("CP0000", 1:3),
      site = rep("CR", 3),
      date = as.Date(rep("2026-09-30", 3))
    )
  )$rows

  expect_identical(observed$State[observed$Nest == "-C0224"], "Brood")
  expect_identical(observed$`Clutch–Brood`[observed$Nest == "-C0224"], "?–3")
  expect_identical(observed$State[observed$Nest == "C0615"], "Brood")
  expect_identical(
    observed$Notes[observed$Nest == "C0625"],
    "band X-X F; resight/band M (status ?)"
  )
  expect_identical(
    observed$Notes[observed$Nest == "A0306"],
    "resight/band F (status ?); band X-X M"
  )
  expect_identical(
    observed$Notes[observed$Nest == "B0220"],
    "remove flag + enter 'notA'"
  )
})


test_that("PDF includes the main-version footer", {
  app <- load_main_app()
  version <- list(id = "abcdef1")
  app$env$git_version <- version
  qmd <- app$env$todo_pdf_qmd(
    pdf = list(
      title = "Cass To-Dos for 2026-09-30",
      rows = data.table::data.table(),
      team_marks = data.table::data.table(),
      nest_summary = data.table::data.table(),
      unseen_tagged_birds = data.table::data.table()
    ),
    map_file = NULL,
    template = app_file("main/templates/todo_pdf.qmd")
  )
  qmd_text <- paste(qmd, collapse = "\n")

  expect_equal(
    app$env$todo_pdf_version_footer(version),
    "version abcdef1"
  )
  expect_true(grepl("#set page(header:", qmd_text, fixed = TRUE))
  expect_true(grepl("Cass To-Dos for 2026-09-30", qmd_text, fixed = TRUE))
  expect_true(grepl(
    '#align(center)[#text(size: 12pt, weight: "bold"',
    qmd_text,
    fixed = TRUE
  ))
  expect_false(grepl('title: "Cass To-Dos for 2026-09-30"', qmd_text, fixed = TRUE))
  expect_true(grepl("#set page(footer:", qmd_text, fixed = TRUE))
  expect_true(grepl(
    "version abcdef1",
    qmd_text,
    fixed = TRUE
  ))
  expect_true(grepl(
    "#counter(page).display()",
    qmd_text,
    fixed = TRUE
  ))
  expect_true(grepl(
    "#align(left)",
    qmd_text,
    fixed = TRUE
  ))
  expect_false(grepl("CEST", qmd_text, fixed = TRUE))
  expect_false(grepl("commit time", qmd_text, fixed = TRUE))
})


test_that("PDF note key includes only definitions used by task notes", {
  app <- load_main_app()
  note_key <- app$env$todo_pdf_note_key

  observed <- paste(
    note_key(c("tag M (pair completion)", "resight M; 7d rule", "band X-X F")),
    collapse = "\n"
  )

  expect_true(grepl("7d rule", observed, fixed = TRUE))
  expect_true(grepl("Pair completion", observed, fixed = TRUE))
  expect_true(grepl("Band only", observed, fixed = TRUE))
  expect_false(grepl("36hr rule", observed, fixed = TRUE))
  expect_false(grepl("Sex/phenology balance", observed, fixed = TRUE))
  expect_false(grepl("FO marker", observed, fixed = TRUE))
  expect_false(grepl("M/F w/GEO", observed, fixed = TRUE))
  expect_false(grepl("Status ?", observed, fixed = TRUE))

  revised_key <- paste(
    note_key(c(
      "tag M (pair completion)",
      "resight M; MM cap; status ?"
    )),
    collapse = "\n"
  )
  expect_true(grepl(
    "Captured with mobile mist net. Three subsequent nest-linked resightings with matching sex and identity confirms association OR a single nest-linked resighting with behav 'IN', 'NM', or 'BW'.",
    revised_key,
    fixed = TRUE
  ))
  expect_true(grepl(
    "Prioritize tagging the eligible untagged mate so that both pair members are tagged",
    revised_key,
    fixed = TRUE
  ))
  expect_true(grepl(
    "Identity or X-X status is unknown.",
    revised_key,
    fixed = TRUE
  ))
})


test_that("PDF parent summary keeps mobile broods and hatched notA nests", {
  app <- load_main_app()
  prepare_summary <- app$env$todo_pdf_prepare_nest_summary

  nests <- data.frame(
    nest_id = c("A_MOCK_ACTIVE", "A_MOCK_HATCHED", "A_MOCK_FAILED", "-B_MOCK"),
    nest_state = c("I", "notA", "notA", NA),
    has_hatch_evidence = c(FALSE, TRUE, FALSE, TRUE),
    is_negative_brood = c(FALSE, FALSE, FALSE, TRUE),
    min_days_to_hatch = c(6, NA, NA, NA),
    M_mark = c("MOCK-M", "MOCK-HM", "MOCK-FM", "MOCK-MM"),
    F_mark = c("MOCK-F", "MOCK-HF", "MOCK-FF", "NULL"),
    brood_size = c(0, 2, 0, NA)
  )
  todo <- data.frame(
    nest_id = c("A_MOCK_ACTIVE", "-B_MOCK"),
    todo = c("Parent capture", "Parent resighting"),
    M_mark = c("MOCK-M", "MOCK-MM"),
    F_mark = c("MOCK-F", "NULL")
  )

  summary <- prepare_summary(
    nests,
    as.Date("2026-09-24"),
    todo = todo,
    chick_captures = data.frame()
  )

  expect_setequal(
    summary$Nest,
    c("A_MOCK_ACTIVE", "A_MOCK_HATCHED", "-B_MOCK")
  )
  expect_identical(
    summary[summary$Nest == "-B_MOCK", `Est. Hatch`],
    ""
  )
  expect_identical(
    summary[summary$Nest == "-B_MOCK", Female],
    ""
  )
  expect_false("A_MOCK_FAILED" %in% summary$Nest)
})


test_that("notA task rows remain available to the PDF summary and map", {
  app <- load_main_app()
  prepare_summary <- app$env$todo_pdf_prepare_nest_summary
  prepare_map <- app$env$.todo_pdf_map_prepare_nests

  todo <- data.frame(
    nest_id = c("B0220", "B0604"),
    todo = c("notA nest-check", "notA nest-check"),
    nest_state = c("notA", "notA"),
    min_days_to_hatch = c(NA, NA),
    M_mark = c("MOCK-M1", "MOCK-M2"),
    F_mark = c("MOCK-F1", "MOCK-F2"),
    lat = c(-43.1, -43.2),
    lon = c(170.1, 170.2),
    stringsAsFactors = FALSE
  )
  nests <- data.frame(
    nest_id = "B0201",
    nest_state = "I",
    min_days_to_hatch = 4,
    M_mark = "MOCK-M",
    F_mark = "MOCK-F",
    lat = -43.3,
    lon = 170.3,
    has_hatch_evidence = FALSE,
    is_negative_brood = FALSE,
    stringsAsFactors = FALSE
  )

  summary <- prepare_summary(
    nests,
    as.Date("2026-10-01"),
    todo = todo,
    chick_captures = data.frame()
  )
  expect_true(all(c("B0220", "B0604") %in% summary$Nest))
  expect_identical(summary$Symbol[summary$Nest == "B0220"], "notA")

  mapped <- prepare_map(todo, data.frame(), nests)
  expect_true(all(c("B0220", "B0604") %in% mapped$nest_id))
  expect_identical(
    as.character(mapped$check_type[mapped$nest_id == "B0220"]),
    "notA visit"
  )
})


test_that("parent summary displays hatch intervals", {
  app <- load_main_app()
  prepare_summary <- app$env$todo_pdf_prepare_nest_summary

  nests <- data.frame(
    nest_id = c("A_MOCK_HATCHED", "A_MOCK_ACTIVE", "-B_MOCK"),
    nest_state = c("H", "I", NA),
    has_hatch_evidence = c(TRUE, FALSE, TRUE),
    is_negative_brood = c(FALSE, FALSE, TRUE),
    hatch_evidence_date = as.Date(c("2026-09-20", NA, NA)),
    discovery_date = as.Date(c(NA, NA, "2026-09-18")),
    min_days_to_hatch = c(NA, 6, NA),
    M_mark = c("MOCK-HM", "MOCK-AM", "MOCK-BM"),
    F_mark = c("MOCK-HF", "MOCK-AF", "MOCK-BF"),
    stringsAsFactors = FALSE
  )

  summary <- prepare_summary(
    nests,
    as.Date("2026-09-24"),
    todo = data.frame(),
    chick_captures = data.frame()
  )

  expect_identical(
    summary[summary$Nest == "A_MOCK_HATCHED", `Est. Hatch`],
    "-4"
  )
  expect_identical(
    summary[summary$Nest == "A_MOCK_ACTIVE", `Est. Hatch`],
    "6"
  )
  expect_identical(
    summary[summary$Nest == "-B_MOCK", `Est. Hatch`],
    "-6"
  )
})


test_that("parent summary uses the resolved parent-task identities", {
  app <- load_main_app()
  prepare_summary <- app$env$todo_pdf_prepare_nest_summary

  nests <- data.frame(
    nest_id = c("C0217", "C0220", "C0221"),
    nest_state = rep("I", 3),
    min_days_to_hatch = rep(5, 3),
    M_mark = c("BY-STALE", "BASE-M", "BASE-M2"),
    F_mark = c("BASE-F", "BASE-F2", "BASE-F3"),
    stringsAsFactors = FALSE
  )
  todo <- data.frame(
    nest_id = c("C0217", "C0217", "C0220"),
    todo = c("Parent capture", "Parent resighting", "Parent resighting"),
    M_mark = c("X-X", "X-X", "BY-TAG & X-X"),
    F_mark = c("YY-TY.YL", "YY-TY.YL", "BASE-F2"),
    stringsAsFactors = FALSE
  )

  summary <- prepare_summary(
    nests,
    as.Date("2026-09-30"),
    todo = todo,
    chick_captures = data.frame()
  )

  expect_identical(
    summary[summary$Nest == "C0217", Male],
    "X-X"
  )
  expect_identical(
    summary[summary$Nest == "C0217", Female],
    "YY-TY.YL"
  )
  expect_identical(
    summary[summary$Nest == "C0220", Male],
    "BY-TAG & X-X"
  )
  expect_identical(
    summary[summary$Nest == "C0221", Male],
    "BASE-M2"
  )
})


test_that("PDF rows normalize negative broods and count unique captured rings", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare

  todo <- data.frame(
    nest_id = rep("-MOCK_BROOD", 4),
    reference_date = as.Date(rep("2026-09-28", 4)),
    todo = c(
      "Parent capture", "Parent capture",
      "Hiding spot photos needed", "Hiding spot photos needed"
    ),
    notes = c(
      "band X-X M", "band X-X M",
      "need H resightings", "need H resightings"
    ),
    nest_state = c(NA, NA, "H", "H"),
    clutch_size = c(NA, NA, 0, 0),
    brood_size = c(NA, NA, 3, 3),
    M_mark = NA,
    F_mark = "NULL",
    stringsAsFactors = FALSE
  )
  available <- data.frame(mark = paste0("MOCK-", seq_len(30)))
  chicks <- data.frame(
    nest_id = rep("-MOCK_BROOD", 3),
    age = rep("C", 3),
    ring = c("CP00001", "CP00001", "CP00002"),
    stringsAsFactors = FALSE
  )

  observed <- prepare(
    todo = todo,
    available_combos = available,
    chick_captures = chicks
  )$rows

  expect_equal(
    nrow(observed[observed$Todo == "Parent capture", ]),
    1L
  )
  expect_equal(
    nrow(observed[observed$Todo == "Hiding spot photos needed", ]),
    1L
  )
  expect_identical(unique(observed$State), "Brood")
  expect_identical(unique(observed$`Clutch–Brood`), "?–2")
  expect_identical(unique(observed$Female), "")
})


test_that("H nests use unique age-C rings when brood size is unresolved", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare

  todo <- data.frame(
    nest_id = c("B0208", "B0208", "B0209", "B0211"),
    reference_date = as.Date(rep("2026-09-30", 4)),
    todo = rep("Parent capture", 4),
    notes = rep("mock task", 4),
    nest_state = rep("H", 4),
    clutch_size = rep(3, 4),
    brood_size = rep(0, 4),
    min_days_to_hatch = rep(-1, 4),
    last_visit_days_ago = rep(1, 4),
    M_mark = NA,
    F_mark = NA,
    stringsAsFactors = FALSE
  )

  chicks <- data.frame(
    nest_id = c(
      "B0208", "B0208", "B0208", "B0211", "B0211"
    ),
    age = rep("C", 5),
    ring = c(
      "CP00001", "CP00001", "CP00002", "CP00003", "CP00003"
    ),
    date = as.Date(c(
      "2026-09-29", "2026-09-30", "2026-09-30",
      "2026-09-30", "2026-10-01"
    )),
    site = rep("CR", 5),
    stringsAsFactors = FALSE
  )

  observed <- prepare(
    todo = todo,
    available_combos = data.frame(mark = paste0("MOCK-", seq_len(30))),
    chick_captures = chicks
  )$rows

  expect_identical(
    observed$`Clutch–Brood`[observed$Nest == "B0208"],
    "3–2"
  )
  expect_identical(
    observed$`Clutch–Brood`[observed$Nest == "B0209"],
    "3–0"
  )
  expect_identical(
    observed$`Clutch–Brood`[observed$Nest == "B0211"],
    "3–1"
  )
})


test_that("parent capture PDF sorting prioritizes hatch, negative broods, then hatch date", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare

  todo <- data.frame(
    nest_id = c("I_MOCK_LATE", "-MOCK_BROOD", "H_MOCK", "I_MOCK_EARLY"),
    reference_date = as.Date(rep("2026-09-28", 4)),
    todo = rep("Parent capture", 4),
    notes = rep("mock task", 4),
    nest_state = c("I", NA, "H", "I"),
    clutch_size = c(3, NA, 3, 3),
    brood_size = c(0, NA, 0, 0),
    min_days_to_hatch = c(8, NA, 5, 2),
    last_visit_days_ago = c(2, 2, 1, 3),
    M_mark = NA,
    F_mark = NA,
    stringsAsFactors = FALSE
  )
  available <- data.frame(mark = paste0("MOCK-", seq_len(30)))
  chicks <- data.frame(
    nest_id = "-MOCK_BROOD",
    age = "C",
    stringsAsFactors = FALSE
  )

  observed <- prepare(
    todo = todo,
    available_combos = available,
    chick_captures = chicks
  )$rows

  expect_identical(
    observed$Nest[observed$Todo == "Parent capture"],
    c("H_MOCK", "-MOCK_BROOD", "I_MOCK_EARLY", "I_MOCK_LATE")
  )
})


test_that("chick colour labels are used in operational parent and brood tables", {
  app <- load_main_app()
  rows <- data.table::data.table(
    Todo = c(
      "Hiding spot photos needed",
      "Parent capture",
      "Parent resighting",
      "Untrapped brood"
    ),
    Nest = c("-MOCK_BROOD", "MOCK_NEST", "MOCK_NEST", "MOCK_BROOD"),
    State = c("NA", "I", "I", "NA"),
    `Clutch–Brood` = c("NA–3", "3–0", "3–0", "NA–3"),
    Hatch = c("", "09-25", "09-25", ""),
    `Last Visit` = c("2", "1", "1", "2"),
    Male = c("", "MOCK-M", "MOCK-M", ""),
    Female = c("", "MOCK-F", "MOCK-F", ""),
    Notes = c("photo", "capture", "resight", "band")
  )
  nest_summary <- data.table::data.table(
    Nest = c("-MOCK_BROOD", "MOCK_NEST"),
    LabelFill = c("#1565c0", "#f4d03f"),
    LabelText = c("#ffffff", "#000000")
  )

  body <- app$env$todo_pdf_body(
    rows = rows,
    nest_summary = nest_summary
  )
  body_text <- paste(body, collapse = "\n")

  expect_true(grepl("## Broods to photograph", body_text, fixed = TRUE))
  expect_true(grepl("## Parents to capture", body_text, fixed = TRUE))
  expect_true(grepl("## Parents to resight", body_text, fixed = TRUE))
  expect_true(grepl("## Broods to band", body_text, fixed = TRUE))
  expect_true(grepl("Nest/Brood", body_text, fixed = TRUE))
  expect_true(grepl("#f4d03f", body_text, fixed = TRUE))
  expect_true(grepl("#1565c0", body_text, fixed = TRUE))
  expect_true(grepl("stroke: none", body_text, fixed = TRUE))
  expect_true(grepl("#strong[-MOCK\\_BROOD]", body_text, fixed = TRUE))
  expect_true(grepl("#strong[MOCK\\_NEST]", body_text, fixed = TRUE))
})


test_that("parent summary keeps a larger adaptive vertical row inset", {
  app <- load_main_app()
  summary <- data.table::data.table(
    Nest = paste0("MOCK_", seq_len(39)),
    `Est. Hatch` = rep("09-25", 39),
    Male = rep("MOCK-M", 39),
    Female = rep("MOCK-F", 39),
    Symbol = rep("circle", 39),
    SymbolColor = rep("#7b858b", 39),
    LabelFill = rep(NA_character_, 39),
    LabelText = rep(NA_character_, 39)
  )

  output <- paste(
    app$env$todo_pdf_nest_summary_table(summary),
    collapse = "\n"
  )

  expect_true(grepl("inset: \\(x: 2.2pt, y: 4.05pt\\)", output))
})
