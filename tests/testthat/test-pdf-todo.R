test_that("team marks are distributed evenly across three teams", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare_team_marks

  for (n_marks in c(1L, 2L, 3L, 4L, 28L, 29L, 30L, 31L)) {
    marks <- sprintf("MOCK-%02d", seq_len(n_marks))
    observed <- prepare(data.frame(mark = marks))
    displayed_n <- min(n_marks, 30L)
    expected_sizes <- rep(displayed_n %/% 3L, 3L)
    remainder <- displayed_n %% 3L
    if (remainder) {
      expected_sizes[seq_len(remainder)] <-
        expected_sizes[seq_len(remainder)] + 1L
    }

    combo_cells <- as.matrix(observed[, -"Team"])
    expect_identical(
      as.integer(rowSums(combo_cells != "")),
      expected_sizes
    )
    expect_identical(
      as.character(observed$Team),
      c("Team 1", "Team 2", "Team 3")
    )
    expect_identical(
      as.character(t(combo_cells))[as.character(t(combo_cells)) != ""],
      head(marks, 30L)
    )
  }

  expect_error(
    prepare(data.frame(mark = character())),
    "No available combinations were returned",
    fixed = TRUE
  )
})


test_that("team marks render with the actual number of table columns", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare_team_marks
  body <- app$env$todo_pdf_body

  team_marks <- prepare(data.frame(mark = sprintf("MOCK-%02d", 1:26)))
  observed <- body(data.table(), team_marks = team_marks)
  columns <- grep("^  columns:", observed, value = TRUE)

  expect_identical(ncol(team_marks), 10L)
  expect_identical(
    columns,
    "  columns: (12fr, 8fr, 8fr, 8fr, 8fr, 8fr, 8fr, 8fr, 8fr, 8fr),"
  )
})


test_that("simple PDF tables reject mismatched column widths", {
  app <- load_main_app()
  render_table <- app$env$todo_pdf_simple_table

  expect_error(
    render_table(
      data.frame(First = "A", Second = "B"),
      column_widths = 1
    ),
    "column_widths must contain one value per table column.",
    fixed = TRUE
  )
})


test_that("to-do headings use the current operational subtitles", {
  app <- load_main_app()
  heading <- app$env$todo_pdf_heading

  expect_identical(
    heading("Hiding spot photos needed")$subtitle,
    "Find each brood; take in-situ and tent photos before chicks are 7 days old."
  )
  expect_identical(
    heading("Broods to recapture for flagging")$title,
    "Broods to recapture for flagging"
  )
  expect_identical(
    heading("Broods to recapture for flagging")$subtitle,
    "Recapture chicks aged 21 days or more; assign unique engraved UL flags."
  )
  expect_identical(
    heading("Untrapped brood")$subtitle,
    "Band chicks at hatched nests/broods with no chick captures."
  )
  expect_identical(
    heading("Unprocessed nest")$subtitle,
    "Complete required egg, nest/tent, or scrape photos; float where needed."
  )
  expect_identical(
    heading("Parent capture")$subtitle,
    "Follow the row notes: deploy a geolocator or band only."
  )
  expect_identical(
    heading("Parent resighting")$subtitle,
    "Association resolves after 3 nest-linked resightings or 1 confirming behaviour (IN, NM, BW, BC, FC, AC). MM, n = MM capture plus n non-confirming resightings."
  )
  expect_identical(
    heading("Re-process nest")$title,
    "Nests to process"
  )

  expect_error(
    heading("Unexpected stale task"),
    "Unexpected TODO task value in PDF renderer: Unexpected stale task",
    fixed = TRUE
  )
  expect_identical(
    heading("nest check")$subtitle,
    "Revisit to check hatch status and update the nest record."
  )
  expect_false(grepl("float", heading("nest check")$subtitle, ignore.case = TRUE))
  expect_true(grepl(
    "float where needed",
    heading("Unprocessed nest")$subtitle,
    fixed = TRUE
  ))
  expect_identical(
    heading("Clutch check")$subtitle,
    "Revisit to check for additional eggs."
  )
  expect_identical(
    heading("notA nest-check")$subtitle,
    "Confirm closure and enter notA; H-state nests may still be active mobile broods."
  )
})


test_that("re-process nests share the Nests to process PDF table", {
  app <- load_main_app()
  body <- app$env$todo_pdf_body(
    rows = data.table::data.table(
      Todo = c("Unprocessed nest", "Re-process nest"),
      Nest = c("MOCK-1", "MOCK-2"),
      State = c("S", "S"),
      `Clutch–Brood` = c("1–0", "2–0"),
      Hatch = c("", ""),
      `Last Visit` = c("1", "2"),
      Male = c("", ""),
      Female = c("", ""),
      Notes = c("egg photos needed", "new clutch evidence; refloat")
    )
  )
  body_text <- paste(body, collapse = "\n")

  expect_identical(
    sum(grepl("## Nests to process", body, fixed = TRUE)),
    1L
  )
  expect_false(grepl("## Re-process nest", body_text, fixed = TRUE))
  expect_true(grepl("MOCK-1", body_text, fixed = TRUE))
  expect_true(grepl("MOCK-2", body_text, fixed = TRUE))
  expect_true(
    grepl("new clutch evidence; refloat; re-process", body_text, fixed = TRUE)
  )
})


test_that("PDF task tables use the authoritative fieldworker order", {
  app <- load_main_app()
  body <- app$env$todo_pdf_body(
    rows = data.table::data.table(
      Todo = c(
        "Parent resighting",
        "take scrape photos",
        "Untrapped brood",
        "Re-process nest",
        "Hiding spot photos needed",
        "Clutch check",
        "nest check",
        "Parent capture",
        "Unprocessed nest",
        "Broods to recapture for flagging",
        "notA nest-check"
      ),
      Nest = paste0("MOCK-", seq_len(11)),
      State = c("I", "S", "H", "S", "H", "I", "I", "I", "S", "H", "notA"),
      `Clutch–Brood` = rep("1–0", 11),
      Hatch = rep("", 11),
      `Last Visit` = as.character(seq_len(11)),
      Male = rep("", 11),
      Female = rep("", 11),
      Notes = c(
        "resight",
        "scrape photos needed",
        "band",
        "float + photos",
        "photo",
        "check",
        "hatch",
        "capture",
        "float",
        "flag",
        "closure"
      )
    ),
    team_marks = data.table::data.table(
      Team = "Team 1",
      `1` = "MOCK-MARK"
    )
  )

  headings <- body[grepl("^## ", body)]
  expect_identical(
    headings,
    c(
      "## Broods to band",
      "## Broods to photograph",
      "## Broods to recapture for flagging",
      "## Nests to check for potential hatch",
      "## Nests to check for additional eggs",
      "## Nests to process",
      "## Parents to capture",
      "## Parents to resight for nest association",
      "## Nests requiring a 'notA' closure visit",
      "## Team marks"
    )
  )
  body_text <- paste(body, collapse = "\n")
  expect_true(
    grepl("float + nest/tent photos; re-process", body_text, fixed = TRUE)
  )
  expect_true(grepl("scrape photos", body_text, fixed = TRUE))
  expect_true(grepl("[S]", body_text, fixed = TRUE))
  expect_false(grepl("## Take scrape photos", body_text, fixed = TRUE))
})


test_that("bounded PDF layout keeps task sections together", {
  app <- load_main_app()
  body <- app$env$todo_pdf_body(
    rows = data.table::data.table(
      Todo = "Parent capture",
      Nest = "MOCK-NEST",
      State = "I",
      `Clutch–Brood` = "1–0",
      Hatch = "5",
      `Last Visit` = "1",
      Male = "MOCK-M",
      Female = "MOCK-F",
      Notes = "band"
    ),
    team_marks = data.table::data.table(
      Team = "Team 1",
      `1` = "MOCK-MARK"
    ),
    keep_tables_together = TRUE
  )
  body_text <- paste(body, collapse = "\n")

  expect_true(grepl("#block(breakable: false)[", body_text, fixed = TRUE))
  expect_true(
    grepl("#heading(level: 2)[Parents to capture]", body_text, fixed = TRUE)
  )
  expect_true(
    grepl("#heading(level: 2)[Team marks]", body_text, fixed = TRUE)
  )
  expect_false(grepl("## Parents to capture", body_text, fixed = TRUE))
})


test_that("all PDF task entry points use the bounded TODO_LIST query", {
  app <- load_main_app()
  query_tasks <- app$env$todo_pdf_query_tasks
  query_env <- environment(query_tasks)
  original_dbq <- get("DBq", envir = query_env)
  on.exit(assign("DBq", original_dbq, envir = query_env), add = TRUE)

  calls <- list()
  assign(
    "DBq",
    function(x, params = NULL, derived_merge_off = FALSE) {
      calls[[length(calls) + 1L]] <<- list(
        sql = x,
        derived_merge_off = derived_merge_off
      )
      data.frame()
    },
    envir = query_env
  )

  query_tasks()

  expect_length(calls, 1L)
  expect_true(calls[[1L]]$derived_merge_off)
  expect_match(calls[[1L]]$sql, "FROM TODO_LIST", fixed = TRUE)
  expect_false(grepl("SELECT *", calls[[1L]]$sql, fixed = TRUE))
  expect_match(calls[[1L]]$sql, "authoritative_M_mark", fixed = TRUE)

  pdf_source <- paste(readLines(app_file("main", "R", "pdf_todo.R")), collapse = "\n")
  map_source <- paste(
    readLines(app_file("main", "R", "pdf_todo_map.R")),
    collapse = "\n"
  )
  expect_false(grepl("SELECT * FROM TODO_LIST", pdf_source, fixed = TRUE))
  expect_false(grepl("SELECT * FROM TODO_LIST", map_source, fixed = TRUE))
  expect_match(
    pdf_source,
    "todo_pdf_prepare <- function(\n  todo = NULL,",
    fixed = TRUE
  )
  expect_match(
    map_source,
    "todo_pdf_map_save <- function(\n  file,\n  todo = NULL,",
    fixed = TRUE
  )
})


test_that("PDF generation rejects a failed BROODS_LATEST query", {
  app <- load_main_app()
  save_pdf <- app$env$todo_pdf_save
  query_env <- environment(save_pdf)
  original_dbq <- get("DBq", envir = query_env)
  on.exit(assign("DBq", original_dbq, envir = query_env), add = TRUE)

  calls <- list()
  assign(
    "DBq",
    function(x, params = NULL, derived_merge_off = FALSE) {
      calls[[length(calls) + 1L]] <<- list(
        sql = x,
        derived_merge_off = derived_merge_off
      )
      data.frame(error = "mock BROODS_LATEST failure")
    },
    envir = query_env
  )

  expect_error(
    save_pdf(tempfile(), todo = data.frame()),
    "BROODS_LATEST could not be loaded",
    fixed = TRUE
  )
  expect_length(calls, 1L)
  expect_true(calls[[1L]]$derived_merge_off)
  expect_match(calls[[1L]]$sql, "FROM BROODS_LATEST", fixed = TRUE)
})


test_that("parent-resighting PDF notes retain rules and identity counts", {
  app <- load_main_app()
  extract_rule_note <- app$env$todo_pdf_parent_resighting_rule_note

  expect_identical(
    extract_rule_note(c(
      "MM cap M with 2 resightings",
      "resight M (status ?); 7d rule",
      "MM cap F with 1 resighting; 36hr rule",
      "resight any (status ?); 7d+36hr",
      NA_character_
    )),
    c("", "7d rule", "36hr rule", "7d+36hr", "")
  )

  expect_identical(
    extract_rule_note(
      c("resight M (status ?); 7d rule", "MM cap F with 3 resightings"),
      male_identity_counts = c(2, 0),
      female_identity_counts = c(0, 1)
    ),
    c("2 males seen; 7d rule", "1 female seen")
  )

  expect_identical(
    extract_rule_note(
      c("MM cap M with 1 resighting", "MM cap M with 1 resighting"),
      male_identity_counts = c(1, 1),
      female_identity_counts = c(2, 2),
      male_association_pending = c(1, 1),
      female_association_pending = c(0, 1)
    ),
    c("1 male seen; F resolved", "1 male seen; 2 females seen")
  )

  expect_identical(
    extract_rule_note("not yet floated"),
    "not yet floated"
  )
})


test_that("team-mark tables use the shared PDF table style", {
  app <- load_main_app()
  body <- app$env$todo_pdf_body(
    rows = data.table::data.table(),
    team_marks = data.table::data.table(
      Team = "Team 1",
      `1` = "MOCK-1"
    )
  )

  expect_true(any(grepl("#strong[Team]", body, fixed = TRUE)))
  expect_true(any(grepl('table.cell(fill: rgb("#dfe5e7"))', body, fixed = TRUE)))
  expect_true(any(grepl("stroke: none", body, fixed = TRUE)))
})


test_that("parent-resighting PDF table uses descriptive identity columns", {
  app <- load_main_app()
  body <- app$env$todo_pdf_body(
    rows = data.table::data.table(
      Todo = "Parent resighting",
      Nest = "MOCK_NEST",
      State = "I",
      `Clutch–Brood` = "3–0",
      Hatch = "4",
      `Last Visit` = "1",
      Male = "MOCK-TG.GW (MM, 2) & MOCK-GY (1)",
      Female = "MOCK-BL (1)",
      Notes = "resight M; 7d rule"
    ),
    nest_summary = data.table::data.table()
  )
  body_text <- paste(body, collapse = "\n")

  expect_true(grepl("#strong[Male]", body_text, fixed = TRUE))
  expect_true(grepl("#strong[Female]", body_text, fixed = TRUE))
  expect_true(grepl("#strong[Notes]", body_text, fixed = TRUE))
  expect_true(
    grepl(
      "columns: (7fr, 5fr, 8fr, 8fr, 8fr, 21fr, 23fr, 20fr)",
      body_text,
      fixed = TRUE
    )
  )
  expect_true(
    grepl("MOCK-TG.GW (MM, 2) & MOCK-GY (1)", body_text, fixed = TRUE)
  )
  expect_true(grepl("resight M; 7d rule", body_text, fixed = TRUE))
})


test_that("PDF map uses plots A, B, and C", {
  app <- load_main_app()
  prepare_plots <- app$env$.todo_pdf_map_prepare_plots
  spatial_objects <- data.frame(
    variable = "study_area",
    value = paste0(
      "list(",
      "A = 'POLYGON ((172 -44.02, 172.01 -44.02, 172.01 -44.01, ",
      "172 -44.01, 172 -44.02))', ",
      "B = 'POLYGON ((172 -44, 172.01 -44, 172.01 -43.99, ",
      "172 -43.99, 172 -44))', ",
      "C = 'POLYGON ((172.02 -44, 172.03 -44, 172.03 -43.99, ",
      "172.02 -43.99, 172.02 -44))'",
      ")"
    )
  )

  plots <- prepare_plots(spatial_objects)

  expect_identical(plots$plot_name, c("A", "B", "C"))
})


test_that("Plot B can crop its western empty extent without changing defaults", {
  app <- load_main_app()
  panel_extent <- app$env$.todo_pdf_map_panel_extent
  boundary <- sf::st_as_sf(
    data.frame(
      geometry = sf::st_sfc(
        sf::st_polygon(list(rbind(
          c(0, 0), c(2500, 0), c(2500, 850), c(0, 850), c(0, 0)
        ))),
        crs = 2193
      )
    )
  )
  points <- sf::st_as_sf(
    data.frame(
      geometry = sf::st_sfc(
        sf::st_multipoint(rbind(c(1100, 250), c(2300, 650))),
        crs = 2193
      )
    )
  )
  landmark <- sf::st_as_sf(
    data.frame(
      geometry = sf::st_sfc(sf::st_point(c(900, 400)), crs = 2193)
    )
  )

  full <- panel_extent(boundary, points, target_ratio = 1.55)
  cropped <- panel_extent(
    boundary,
    points,
    target_ratio = 1.55,
    landmark = landmark,
    trim_west_to_points = TRUE,
    trim_padding_m = 150
  )

  expect_gt(cropped$x[1], full$x[1])
  expect_lte(cropped$x[1], 900 - 150)
})


test_that("parent-resighting marks drop bare duplicates when a counted mark exists", {
  app <- load_main_app()
  collapse <- app$env$todo_pdf_collapse_annotated_marks

  expect_identical(
    collapse(c("BY-LO & BY-LO (MM, 0)", "BY-GW (1) & BY-GW (1)")),
    c("BY-LO (MM, 0)", "BY-GW (1)")
  )
})


test_that("processing rows without flotation leave Est. Hatch blank", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare

  observed <- prepare(
    todo = data.frame(
      nest_id = c("MOCK_FLOAT", "MOCK_PHOTOS"),
      reference_date = as.Date(c("2026-10-14", "2026-10-14")),
      todo = c("Unprocessed nest", "Unprocessed nest"),
      notes = c("float + nest/tent photos", "nest/tent photos only"),
      nest_state = c("F", "F"),
      clutch_size = c(3, 3),
      brood_size = c(0, 0),
      min_days_to_hatch = c(10, 10),
      last_visit_days_ago = c(1, 1),
      M_mark = NA_character_,
      F_mark = NA_character_
    ),
    available_combos = data.frame(mark = paste0("MOCK-", seq_len(3)))
  )$rows

  expect_identical(
    observed$Hatch[match(c("MOCK_FLOAT", "MOCK_PHOTOS"), observed$Nest)],
    c("", "10")
  )
})


test_that("complete-clutch predictions without flotation stay blank in task rows", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare

  observed <- prepare(
    todo = data.frame(
      nest_id = "MOCK_COMPLETE",
      reference_date = as.Date("2026-10-14"),
      todo = "Parent capture",
      notes = "tag M (pair completion)",
      nest_state = "I",
      clutch_size = 3,
      brood_size = 0,
      min_days_to_hatch = 25,
      last_visit_days_ago = 1,
      M_mark = "X-X",
      F_mark = "MOCK-F"
    ),
    available_combos = data.frame(mark = paste0("MOCK-", seq_len(3))),
    hatch_prediction = data.frame(
      nest_id = "MOCK_COMPLETE",
      calibration_match_type = "complete clutch chronology",
      float_date = as.Date(NA),
      days_to_hatch = 25
    )
  )$rows

  expect_identical(observed$Hatch, "")
})


test_that("parent summary subtitle explains hatch intervals", {
  app <- load_main_app()
  body <- app$env$todo_pdf_body(
    rows = data.table::data.table(),
    nest_summary = data.table::data.table(),
    map_file = "mock-map.png"
  )

  expect_true(any(grepl(
    "Brood labels use chick band colour; symbols match the map. For active nests, \"Est. Hatch\" is days until hatch (negative = overdue); for broods, negative values are days since hatch.",
    body,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "Map of tasks needed on active nests and broods",
    body,
    fixed = TRUE
  )))
  expect_true(any(grepl("#v(-0.2em)", body, fixed = TRUE)))
  expect_false(any(grepl("#v(0.1em)", body, fixed = TRUE)))
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

  expect_identical(observed$State[observed$Nest == "-C0224"], "brood")
  expect_identical(observed$`Clutch–Brood`[observed$Nest == "-C0224"], "?–3")
  expect_identical(observed$State[observed$Nest == "C0615"], "brood")
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


test_that("PDF normalizes zero-clutch brood states", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare

  todo <- data.frame(
    nest_id = c("C_H_BROOD", "C_NOTA_BROOD"),
    reference_date = as.Date(rep("2026-10-01", 2)),
    todo = rep("Parent capture", 2),
    notes = rep("mock task", 2),
    nest_state = c("H", "notA"),
    clutch_size = c(0, 0),
    brood_size = c(2, 1),
    min_days_to_hatch = rep(NA, 2),
    last_visit_days_ago = rep(1, 2),
    M_mark = NA,
    F_mark = NA,
    stringsAsFactors = FALSE
  )

  observed <- prepare(
    todo = todo,
    available_combos = data.frame(mark = paste0("MOCK-", seq_len(30)))
  )$rows

  expect_identical(
    observed$State[order(observed$Nest)],
    c("brood", "brood")
  )
})


test_that("terminal hatched broods use unique age-C captures", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare

  todo <- data.frame(
    nest_id = c("B0208", "B0209"),
    reference_date = as.Date(rep("2026-10-04", 2)),
    todo = rep("Hiding spot photos needed", 2),
    notes = rep("0/3 chicks with rclass 'H' photos", 2),
    nest_state = c("notA", "H"),
    clutch_size = c(0, 0),
    brood_size = c(0, 1),
    min_days_to_hatch = c(-5, -5),
    last_visit_days_ago = c(2, 2),
    M_mark = c("YY-OY", "MOCK-M"),
    F_mark = c("BY-TG.B", "MOCK-F"),
    stringsAsFactors = FALSE
  )
  chicks <- data.frame(
    nest_id = rep(c("B0208", "B0209"), each = 3),
    age = rep("C", 6),
    ring = paste0("CP2000", seq_len(6)),
    site = rep("CR", 6),
    date = as.Date(rep("2026-09-29", 6)),
    stringsAsFactors = FALSE
  )

  observed <- prepare(
    todo = todo,
    available_combos = data.frame(mark = paste0("MOCK-", seq_len(30))),
    chick_captures = chicks
  )$rows

  expect_identical(observed$State, c("brood", "brood"))
  expect_identical(observed$`Clutch–Brood`, c("0–3", "0–3"))
})


test_that("PDF includes the main-version footer", {
  app <- load_main_app()
  version <- list(
    id = "abcdef1",
    source = "env:FIELDWORKER_GIT_ID",
    local = FALSE,
    dirty = FALSE
  )
  app$env$git_version <- version
  qmd <- app$env$todo_pdf_qmd(
    pdf = list(
      title = "Cass To-Dos for 2026-09-30",
      rows = data.table::data.table(),
      team_marks = data.table::data.table(),
      nest_summary = data.table::data.table()
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


test_that("local PDF footers identify the local commit and dirty state", {
  app <- load_main_app()

  expect_equal(
    app$env$todo_pdf_version_footer(list(
      id = "abcdef1",
      source = "git:HEAD-working-tree",
      local = TRUE,
      dirty = TRUE
    )),
    "version local-abcdef1-dirty"
  )
  expect_equal(
    app$env$todo_pdf_version_footer(list(
      id = "abcdef1",
      source = "git:HEAD",
      local = TRUE,
      dirty = FALSE
    )),
    "version local-abcdef1"
  )
  expect_equal(
    app$env$todo_pdf_version_footer(list(
      id = "abcdef1",
      source = "env:FIELDWORKER_GIT_ID",
      local = FALSE,
      dirty = FALSE
    )),
    "version abcdef1"
  )
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
  expect_false(grepl(
    "Band only",
    paste(note_key("band"), collapse = "\n"),
    fixed = TRUE
  ))
  expect_identical(note_key(c("photo", "hatch check")), character())

  revised_key <- paste(
    note_key(c(
      "tag M (pair completion)",
      "resight M; MM cap; status ?"
    )),
    collapse = "\n"
  )
  expect_true(grepl(
    "Captured with mobile mist net. Three subsequent nest-linked resightings with matching sex and identity confirms association OR a single nest-linked resighting with behav 'IN', 'NM', 'BW', 'BC', 'FC', or 'AC'.",
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


test_that("PDF parent summary retains negative broods from task inputs", {
  app <- load_main_app()
  prepare_summary <- app$env$todo_pdf_prepare_nest_summary

  nests <- data.frame(
    nest_id = "A_MOCK_ACTIVE",
    nest_state = "I",
    has_hatch_evidence = FALSE,
    is_negative_brood = FALSE,
    min_days_to_hatch = 6,
    M_mark = "MOCK-M",
    F_mark = "MOCK-F",
    stringsAsFactors = FALSE
  )
  todo <- data.frame(
    nest_id = c("-C0224", "-A0509", "-B0905"),
    todo = rep("Parent capture", 3),
    M_mark = rep(NA_character_, 3),
    F_mark = rep(NA_character_, 3),
    stringsAsFactors = FALSE
  )
  chicks <- data.frame(
    nest_id = c("-C0224", "-A0509", "-B0905"),
    age = rep("C", 3),
    LL = c("Y", "R", "B"),
    LR = rep("X", 3),
    date = as.Date(c("2026-09-26", "2026-10-11", "2026-10-13")),
    site = rep("CR", 3),
    stringsAsFactors = FALSE
  )

  summary <- prepare_summary(
    nests,
    as.Date("2026-10-15"),
    todo = todo,
    chick_captures = chicks
  )

  expect_true(all(todo$nest_id %in% summary$Nest))
  expect_identical(
    summary$LabelFill[match(todo$nest_id, summary$Nest)],
    c("#f4d03f", "#c62828", "#1565c0")
  )
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
    nest_id = c("B0201", "B0202"),
    nest_state = c("I", "I"),
    min_days_to_hatch = c(4, 5),
    M_mark = c("MOCK-M", "MOCK-M2"),
    F_mark = c("MOCK-F", "MOCK-F2"),
    lat = c(-43.3, -43.4),
    lon = c(170.3, 170.4),
    has_hatch_evidence = c(FALSE, FALSE),
    is_negative_brood = c(FALSE, FALSE),
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

  expect_identical(
    summary$Symbol[summary$Nest == "B0201"],
    "circle"
  )
  expect_identical(
    summary$SymbolColor[summary$Nest == "B0201"],
    "#7b858b"
  )
})


test_that("tagged capture tasks receive a white map outline and legend entry", {
  app <- load_main_app()
  prepare_map <- app$env$.todo_pdf_map_prepare_nests

  todo <- data.frame(
    nest_id = c("B2203", "B0207", "B0208"),
    todo = c("Parent capture", "Parent capture", "Parent resighting"),
    notes = c(
      "F: CORRECT DUPLICATE",
      "tag M (pair completion)",
      "resight M (status ?)"
    ),
    lat = c(-43.1, -43.2, -43.3),
    lon = c(170.1, 170.2, 170.3),
    stringsAsFactors = FALSE
  )
  nests <- data.frame(
    nest_id = c("B2203", "B0207", "B0208"),
    nest_state = rep("I", 3),
    lat = c(-43.1, -43.2, -43.3),
    lon = c(170.1, 170.2, 170.3),
    has_hatch_evidence = rep(FALSE, 3),
    is_negative_brood = rep(FALSE, 3),
    stringsAsFactors = FALSE
  )

  mapped <- prepare_map(
    todo = todo,
    chick_captures = data.frame(),
    nests_latest = nests
  )

  expect_true("tag_capture" %in% names(mapped))
  expect_false(mapped$tag_capture[mapped$nest_id == "B2203"])
  expect_true(mapped$tag_capture[mapped$nest_id == "B0207"])
  expect_false(mapped$tag_capture[mapped$nest_id == "B0208"])

  legend <- app$env$.todo_pdf_map_legend()
  fill_scale <- legend$scales$get_scales("fill")
  expect_true(
    "Capture (deploy tag if outlined in white)." %in% fill_scale$get_labels()
  )
  shape_scale <- legend$scales$get_scales("shape")
  expect_identical(
    shape_scale$get_limits(),
    c("Nest check", "notA visit")
  )
  expect_false("Other task" %in% shape_scale$get_limits())
  expect_true("No to-do task today" %in% fill_scale$get_labels())
})


test_that("brood work tasks receive a white label outline and legend entry", {
  app <- load_main_app()
  prepare_map <- app$env$.todo_pdf_map_prepare_nests

  todo <- data.frame(
    nest_id = c("B0201", "B0202", "B0203", "B0204"),
    todo = c(
      "Hiding spot photos needed",
      "Broods to recapture for flagging",
      "Untrapped brood",
      "Parent resighting"
    ),
    notes = NA_character_,
    lat = c(-43.1, -43.2, -43.3, -43.4),
    lon = c(170.1, 170.2, 170.3, 170.4),
    stringsAsFactors = FALSE
  )
  nests <- data.frame(
    nest_id = todo$nest_id,
    nest_state = rep("I", 4),
    lat = todo$lat,
    lon = todo$lon,
    has_hatch_evidence = rep(FALSE, 4),
    is_negative_brood = rep(FALSE, 4),
    stringsAsFactors = FALSE
  )

  mapped <- prepare_map(
    todo = todo,
    chick_captures = data.frame(),
    nests_latest = nests
  )

  brood_rows <- mapped$nest_id %in% c("B0201", "B0202", "B0203")
  expect_true(all(mapped$brood_work[brood_rows]))
  expect_identical(unique(mapped$label_outline[brood_rows]), "#ffffff")
  expect_identical(unique(mapped$label_outline_width[brood_rows]), 1.4)
  expect_false(mapped$brood_work[mapped$nest_id == "B0204"])
  expect_identical(mapped$label_outline[mapped$nest_id == "B0204"], "#ffffff")
  expect_identical(mapped$label_outline_width[mapped$nest_id == "B0204"], 0)

  legend <- app$env$.todo_pdf_map_legend()
  alpha_scale <- legend$scales$get_scales("alpha")
  expect_true(
    "Italic + white border = brood photo / flag / band work; upright/no border = no brood work" %in%
      alpha_scale$get_labels()
  )
  expect_true(is.function(app$env$.todo_pdf_map_draw_key_brood_label))
  expect_identical(unique(mapped$label_fontface[brood_rows]), "italic")
  expect_identical(mapped$label_fontface[mapped$nest_id == "B0204"], "plain")
})


test_that("capture work trumps simultaneous resight work on the map", {
  app <- load_main_app()
  prepare_map <- app$env$.todo_pdf_map_prepare_nests

  todo <- data.frame(
    nest_id = c("B_BOTH", "B_BOTH", "B_BOTH"),
    todo = c("nest check", "Parent capture", "Parent resighting"),
    notes = c(NA, "tag M (pair completion)", NA),
    lat = c(-43.1, -43.1, -43.1),
    lon = c(170.1, 170.1, 170.1),
    stringsAsFactors = FALSE
  )
  nests <- data.frame(
    nest_id = "B_BOTH",
    nest_state = "I",
    lat = -43.1,
    lon = 170.1,
    has_hatch_evidence = FALSE,
    is_negative_brood = FALSE,
    stringsAsFactors = FALSE
  )

  mapped <- prepare_map(
    todo = todo,
    chick_captures = data.frame(),
    nests_latest = nests
  )

  expect_identical(
    as.character(mapped$parent_work[mapped$nest_id == "B_BOTH"]),
    "Capture"
  )
  expect_identical(
    as.character(mapped$check_type[mapped$nest_id == "B_BOTH"]),
    "Nest check"
  )
  expect_true(mapped$tag_capture[mapped$nest_id == "B_BOTH"])
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


test_that("negative broods with NULL species retain PDF hatch and map data", {
  app <- load_main_app()
  prepare_summary <- app$env$todo_pdf_prepare_nest_summary
  prepare_nests <- get(
    ".todo_pdf_map_prepare_nests",
    envir = app$env
  )

  nests <- data.frame(
    nest_id = c("-C_MOCK", "A_MOCK_TASK"),
    species = c(NA_character_, "BADO"),
    nest_state = c(NA_character_, "I"),
    is_negative_brood = c(TRUE, FALSE),
    has_hatch_evidence = c(TRUE, FALSE),
    discovery_date = as.Date(c("2026-10-18", NA)),
    hatch_evidence_date = as.Date(c(NA, NA)),
    min_days_to_hatch = c(-2, 7),
    M_mark = c("MOCK-M", NA),
    F_mark = c("MOCK-F", NA),
    lat = c(-43.1, -43.2),
    lon = c(170.1, 170.2),
    stringsAsFactors = FALSE
  )

  summary <- prepare_summary(
    nests_latest = nests,
    reference_date = as.Date("2026-10-20"),
    todo = data.frame(),
    chick_captures = data.frame()
  )
  expect_identical(
    summary[summary$Nest == "-C_MOCK", `Est. Hatch`],
    "-2"
  )

  todo <- data.frame(
    nest_id = c("A_MOCK_TASK", "-C_MOCK"),
    todo = c("nest check", "nest check"),
    notes = c(NA_character_, NA_character_),
    reference_date = as.Date(c("2026-10-20", "2026-10-20")),
    lat = c(-43.2, -43.1),
    lon = c(170.2, 170.1),
    stringsAsFactors = FALSE
  )
  mapped <- prepare_nests(
    todo = todo,
    chick_captures = data.frame(),
    nests_latest = nests
  )
  expect_true("-C_MOCK" %in% mapped$nest_id)
  negative_map_row <- mapped[mapped$nest_id == "-C_MOCK", ]
  expect_equal(nrow(negative_map_row), 1L)
  expect_false(any(sf::st_is_empty(negative_map_row)))
})


test_that("parent summary uses canonical status marks across task types", {
  app <- load_main_app()
  prepare_summary <- app$env$todo_pdf_prepare_nest_summary

  nests <- data.frame(
    nest_id = "MOCK_NEST",
    nest_state = "I",
    min_days_to_hatch = 2,
    M_mark = "STALE-M",
    F_mark = "STALE-F",
    is_negative_brood = FALSE,
    has_hatch_evidence = FALSE,
    stringsAsFactors = FALSE
  )
  todo <- data.frame(
    nest_id = "MOCK_NEST",
    todo = "notA nest-check",
    min_days_to_hatch = 2,
    M_mark = "TASK-M",
    F_mark = "TASK-F",
    authoritative_M_mark = "CANONICAL-M",
    authoritative_F_mark = "CANONICAL-F",
    stringsAsFactors = FALSE
  )

  observed <- prepare_summary(
    nests_latest = nests,
    reference_date = as.Date("2026-10-08"),
    todo = todo
  )

  expect_identical(observed$Male, "CANONICAL-M")
  expect_identical(observed$Female, "CANONICAL-F")
})


test_that("parent summary reuses task hatch intervals", {
  app <- load_main_app()
  prepare_summary <- app$env$todo_pdf_prepare_nest_summary

  nests <- data.frame(
    nest_id = c("B0608", "C0212"),
    nest_state = c("I", "I"),
    min_days_to_hatch = c(17, NA),
    M_mark = c("MOCK-M1", "MOCK-M2"),
    F_mark = c("MOCK-F1", "MOCK-F2"),
    stringsAsFactors = FALSE
  )
  todo <- data.frame(
    nest_id = c("B0608", "C0212"),
    todo = c("Parent capture", "Hiding spot photos needed"),
    min_days_to_hatch = c(15, 5),
    stringsAsFactors = FALSE
  )

  summary <- prepare_summary(
    nests,
    as.Date("2026-10-01"),
    todo = todo,
    chick_captures = data.frame()
  )

  expect_identical(
    summary[summary$Nest == "B0608", `Est. Hatch`],
    "15"
  )
  expect_identical(
    summary[summary$Nest == "C0212", `Est. Hatch`],
    "5"
  )
})


test_that("parent summary uses no-float hatch predictions", {
  app <- load_main_app()
  prepare_summary <- app$env$todo_pdf_prepare_nest_summary

  nests <- data.frame(
    nest_id = c("B0616", "C0504", "A0511"),
    nest_state = c("I", "F", "I"),
    min_days_to_hatch = c(NA, NA, 25),
    M_mark = c("MOCK-M1", "MOCK-M2", "MOCK-M3"),
    F_mark = c("MOCK-F1", "MOCK-F2", "MOCK-F3"),
    stringsAsFactors = FALSE
  )
  hatch_prediction <- data.frame(
    nest_id = c("B0616", "C0504", "A0511"),
    calibration_match_type = c(
      "found as incomplete",
      "stable one-egg/no increase",
      "complete clutch chronology"
    ),
    float_date = as.Date(c(NA, NA, NA)),
    days_to_hatch = c(23, 23, 25),
    stringsAsFactors = FALSE
  )

  summary <- prepare_summary(
    nests,
    as.Date("2026-10-04"),
    todo = data.frame(),
    chick_captures = data.frame(),
    hatch_prediction = hatch_prediction
  )

  expect_identical(
    summary[summary$Nest == "B0616", `Est. Hatch`],
    "23"
  )
  expect_identical(
    summary[summary$Nest == "C0504", `Est. Hatch`],
    "23"
  )
  expect_identical(
    summary[summary$Nest == "A0511", `Est. Hatch`],
    ""
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


test_that("parent summary prefers a resolved identity over MM uncertainty", {
  app <- load_main_app()
  prepare_summary <- app$env$todo_pdf_prepare_nest_summary

  nests <- data.frame(
    nest_id = "C0214",
    nest_state = "notA",
    min_days_to_hatch = NA,
    M_mark = "YO-TW.WL",
    F_mark = "YO-TW.LO",
    has_hatch_evidence = TRUE,
    is_negative_brood = FALSE,
    brood_size = 1,
    stringsAsFactors = FALSE
  )
  todo <- data.frame(
    nest_id = c("C0214", "C0214"),
    todo = c("Parent resighting", "Parent capture"),
    M_mark = c("YO-TW.WL & X-X", "X-X"),
    F_mark = c("YO-TW.LO", "YO-TW.LO"),
    stringsAsFactors = FALSE
  )

  summary <- prepare_summary(
    nests,
    as.Date("2026-10-04"),
    todo = todo,
    chick_captures = data.frame()
  )

  expect_identical(summary$Male[summary$Nest == "C0214"], "X-X")
  expect_identical(summary$Female[summary$Nest == "C0214"], "YO-TW.LO")
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
  expect_identical(unique(observed$State), "brood")
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
      "Broods to recapture for flagging",
      "Parent capture",
      "Parent resighting",
      "Untrapped brood"
    ),
    Nest = c(
      "-MOCK_BROOD",
      "-MOCK_BROOD",
      "MOCK_NEST",
      "MOCK_NEST",
      "MOCK_BROOD"
    ),
    State = c("NA", "NA", "I", "I", "NA"),
    `Clutch–Brood` = c("NA–3", "NA–3", "3–0", "3–0", "NA–3"),
    Hatch = c("", "", "09-25", "09-25", ""),
    `Last Visit` = c("2", "2", "1", "1", "2"),
    Male = c("", "", "MOCK-M", "MOCK-M", ""),
    Female = c("", "", "MOCK-F", "MOCK-F", ""),
    Notes = c("photo", "flag", "capture", "resight", "band")
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
  expect_true(grepl("## Broods to recapture for flagging", body_text, fixed = TRUE))
  expect_true(grepl("## Parents to capture", body_text, fixed = TRUE))
  expect_true(grepl("## Parents to resight", body_text, fixed = TRUE))
  expect_true(grepl("## Broods to band", body_text, fixed = TRUE))
  expect_true(grepl("Nest/Brood", body_text, fixed = TRUE))
  expect_true(grepl("Brood", body_text, fixed = TRUE))
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

  expect_true(grepl("inset: \\(x: 2.2pt, y: 3.63pt\\)", output))
})


test_that("potential hatch checks prioritize unhatched eggs, hatch signs, then estimate", {
  app <- load_main_app()
  todo <- data.frame(
    nest_id = c(
      "MOCK_N_LATE", "MOCK_UNHATCHED", "MOCK_CS", "MOCK_C", "MOCK_N_EARLY"
    ),
    reference_date = as.Date(rep("2026-10-04", 5)),
    todo = rep("nest check", 5),
    notes = c(
      "Last visit: 3N",
      "Last visit: E; unhatched egg(s)",
      "Last visit: 1S",
      "Last visit: 2C",
      "Last visit: 3N"
    ),
    priority = rep(300, 5),
    days_overdue = rep(0, 5),
    min_days_to_hatch = c(6, 12, 8, 7, 2),
    last_visit_days_ago = rep(1, 5),
    nest_state = rep("I", 5),
    clutch_size = rep(3, 5),
    brood_size = rep(0, 5),
    M_mark = NA,
    F_mark = NA,
    stringsAsFactors = FALSE
  )

  prepared <- app$env$todo_pdf_prepare(
    todo = todo,
    available_combos = data.frame(mark = paste0("MOCK-", seq_len(30))),
    nests_latest = data.frame(),
    chick_captures = data.frame()
  )

  expect_identical(
    prepared$rows$Nest[prepared$rows$Todo == "nest check"],
    c("MOCK_UNHATCHED", "MOCK_C", "MOCK_CS", "MOCK_N_EARLY", "MOCK_N_LATE")
  )
})
