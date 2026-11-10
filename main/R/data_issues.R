# Reviewed entry corrections, selected by title so inspector renumbering is harmless.
data_issues_catalog <- function() {
  list(
    CAPTURES = c(
      "Check release leg-mark characters.",
      "Check the metal-ring format.",
      "Check the field-season dates.",
      "Check the site code.",
      "Check book, form, and event uniqueness.",
      "Released must be blank when capture_status is D.",
      "Caught must be before released.",
      "Check capture_status.",
      "Check the nest or brood identifier.",
      "Check field_sex against age.",
      "Only one T allowed across upper leg positions.",
      "T codes are only allowed in upper leg positions.",
      "Short UR tag codes such as TY are reserved for GEO tags.",
      "tag_action D means the bird must not already carry a tag in the input combo.",
      "tag_action R means the bird must not retain a tag in the release combo.",
      "tag_action O can only be used when no tag is present at capture or release.",
      "tag_action D requires tag_id_in to be blank.",
      "tag_action R requires release tag_id to be blank.",
      "tag_action S requires the same tag_id before and after release.",
      "tag_action N requires different input and release tag IDs.",
      "Check optional measurements are numeric.",
      "Check adult morphometric ranges .",
      "Check juvenile morphometric ranges .",
      "Check chick morphometric ranges .",
      "Check recaptured-chick morphometric ranges .",
      "Check rebanded-chick morphometric ranges .",
      "photo_end must not precede photo_start.",
      "Check observer upload initials check 2.",
      "Check caught with format.",
      "Check left tibia in.",
      "Check left tarsus in.",
      "Check right tibia in.",
      "Check right tarsus in.",
      "Check optional moult scores.",
      "Check tag id in format.",
      "Check tag id format.",
      "Check camera id format.",
      "Check photo filename format photo start.",
      "Check photo filename format photo end."
    ),
    NESTS = c(
      "Check species allowed codes.",
      "Check site allowed codes.",
      "Check nest state allowed codes.",
      "Check bird inc allowed codes.",
      "Check nest photo allowed codes.",
      "Check tent photo allowed codes.",
      "Check observer initials.",
      "Check hatch state clutch count.",
      "Check date season.",
      "Check time format.",
      "Check nest id pattern.",
      "Check hatch state format.",
      "Check gps_id is numeric.",
      "Check the gps_id range.",
      "Require a whole number for gps_id.",
      "Check gps_point is numeric.",
      "Check the gps_point range.",
      "Require a whole number for gps_point.",
      "Check clutch_size is numeric.",
      "Check the clutch_size range.",
      "Require a whole number for clutch_size.",
      "Check brood_size is numeric.",
      "Check the brood_size range.",
      "Require a whole number for brood_size.",
      "Check hatch state for brood.",
      "Check camera id.",
      "Check photo filename photo start.",
      "Check photo filename photo end.",
      "photo_end must not precede photo_start."
    ),
    EGGS = c(
      "Check the field-season dates.",
      "Require a positive nest identifier.",
      "Surface float requires float_surface 0–3 mm.",
      "egg_id must be unique within an EGGS event.",
      "egg_id must not exceed the clutch_size of the matching NESTS event.",
      "Check species allowed codes.",
      "Check float location allowed codes.",
      "Check observer initials.",
      "Check date format.",
      "Check time format.",
      "Check egg_id is numeric.",
      "Check the egg_id range.",
      "Require a whole number for egg_id.",
      "Check float_angle is numeric.",
      "Check the float_angle range.",
      "Require a whole number for float_angle.",
      "Check float_surface is numeric.",
      "Check the float_surface range.",
      "Require a whole number for float_surface."
    ),
    RESIGHTINGS = c(
      "Check the field-season dates.",
      "Check the site code.",
      "Check the resighting class.",
      "Use M, MU, F, FU, or U.",
      "Use A, J, or C.",
      "Chick and juvenile resightings must use sex U.",
      "Class H requires age C.",
      "Check behaviour codes against age.",
      "Check the nest or brood identifier.",
      "End photo filenames with digits.",
      "photo_end must not precede photo_start.",
      "Check observer initials.",
      "Check gps_id is numeric.",
      "Check the gps_id range.",
      "Require a whole number for gps_id.",
      "Check gps_point is numeric.",
      "Check the gps_point range.",
      "Require a whole number for gps_point.",
      "Check date format.",
      "Check left tibia format.",
      "Check left tarsus format.",
      "Check right tibia format.",
      "Check right tarsus format.",
      "Check behaviour tokens.",
      "Check camera id format.",
      "Check photo filename format.",
      "Check hiding-photo chick ring format."
    )
  )
}


# Reuse the inspector expressions without their save-time error wrappers.
data_issues_rules <- function(file, titles) {
  code <- parse(file, keep.source = TRUE)
  if (length(code) != 1 || !identical(code[[1]][[1]], as.name("list"))) {
    stop("Inspector list unavailable.", call. = FALSE)
  }
  rules <- as.list(code[[1]])[-1]
  tokens <- getParseData(code)
  root <- tokens[tokens$parent == 0 & tokens$token == "expr", ]
  notes <- tokens[tokens$parent == root$id & tokens$token == "COMMENT", ]
  nodes <- tokens[tokens$parent == root$id & tokens$token == "expr", ]
  nodes <- nodes[order(nodes$line1, nodes$col1), ][-1, ]
  if (nrow(nodes) != length(rules)) stop("Invalid inspector list.", call. = FALSE)
  notes <- notes[order(notes$line1), ]
  headings <- vapply(seq_along(rules), function(i) {
    start <- if (i == 1) 0 else nodes$line2[i - 1]
    heading <- notes$text[notes$line1 > start & notes$line1 <= nodes$line1[i]]
    if (length(heading)) str_remove(tail(heading, 1), "^#\\s*") else ""
  }, "")
  if (!all(titles %in% headings)) stop("Selected checks unavailable.", call. = FALSE)
  keep <- which(headings %in% titles)
  setNames(lapply(keep, function(i) {
    rule <- rules[[i]]
    if (is.call(rule) && identical(rule[[1]], as.name("try_validator"))) {
      rule[[2]]
    } else {
      rule
    }
  }), headings[keep])
}


data_issues_empty <- function() {
  data.table(
    table = character(), pk = character(), date = character(),
    observer = character(), field = character(), value = character(),
    issue = character()
  )
}


data_issues_present <- function(x) {
  txt <- x |> as.character() |> str_trim()
  !is.na(x) & nzchar(txt) & str_to_upper(txt) != "NA"
}


data_issues_run <- function(
  directory = "../DataEntry", read_query = NULL,
  progress = function(table, index, total) NULL,
  catalog = data_issues_catalog()
) {
  if (is.null(read_query)) {
    con <- db_con()
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    DBI::dbExecute(con, "SET SESSION TRANSACTION READ ONLY")
    DBI::dbExecute(con, "SET SESSION max_statement_time = 30")
    DBI::dbBegin(con)
    on.exit(DBI::dbRollback(con), add = TRUE, after = FALSE)
    read_query <- function(query, ..., params = NULL) {
      DBI::dbGetQuery(con, query, params = params)
    }
  }

  ns <- asNamespace("DataEntry")
  cache <- new.env(parent = emptyenv())
  out <- list()
  failures <- list()
  checked <- character()
  unavailable <- FALSE
  fail <- function(table, check) {
    failures[[length(failures) + 1]] <<- data.table(table = table, check = check)
  }
  lookup <- function(query, ..., params = NULL) {
    if (!is.character(query) || length(query) != 1 ||
        !str_detect(query, regex("^\\s*SELECT\\b", ignore_case = TRUE)) ||
        str_detect(query, regex(
          ";|\\b(INTO|OUTFILE|DUMPFILE|FOR\\s+UPDATE|LOCK\\s+IN)\\b",
          ignore_case = TRUE
        ))) {
      unavailable <<- TRUE
      stop("Only read queries are allowed.", call. = FALSE)
    }
    key <- serialize(list(query, params), NULL) |> as.character() |>
      paste(collapse = "")
    if (!exists(key, cache, inherits = FALSE)) {
      result <- tryCatch(
        as.data.table(read_query(query, ..., params = params)), error = identity
      )
      assign(key, result, cache)
    }
    result <- get(key, cache, inherits = FALSE)
    if (inherits(result, "error")) {
      unavailable <<- TRUE
      stop("Lookup unavailable.", call. = FALSE)
    }
    copy(result)
  }
  reference <- function(query, ..., params = NULL) {
    query <- str_replace_all(query, regex(
      "\\bFROM\\s+`?NESTS`?(?=\\s|$)", ignore_case = TRUE
    ), "FROM (SELECT * FROM NESTS WHERE site = 'CR') AS NESTS")
    lookup(query, ..., params = params)
  }

  for (index in seq_along(catalog)) {
    table <- names(catalog)[index]
    progress(table, index, length(catalog))
    rules <- tryCatch(data_issues_rules(
      file.path(directory, table, "inspector.R"), catalog[[table]]
    ), error = identity)
    if (inherits(rules, "error")) {
      fail(table, "Inspector")
      next
    }
    # EGGS has no site column; identify Cass River eggs through their nests.
    query <- if (table == "EGGS") {
      paste(
        "SELECT * FROM EGGS WHERE EXISTS (",
        "SELECT 1 FROM NESTS WHERE NESTS.site = 'CR'",
        "AND NESTS.nest_id = EGGS.nest_id AND NESTS.species = EGGS.species)"
      )
    } else {
      paste0("SELECT * FROM `", table, "` WHERE site = 'CR'")
    }
    dat <- tryCatch(lookup(query), error = identity)
    if (inherits(dat, "error") || !"pk" %in% names(dat)) {
      fail(table, "Table")
      next
    }
    checked <- c(checked, table)
    dat <- get("hot_safe_table", ns)(dat)
    get("cleaner", ns)(dat)
    # Entry-time validators expect hh:mm rather than SQL's hh:mm:00.
    for (field in intersect(c("time_visit", "caught", "released"), names(dat))) {
      values <- as.character(dat[[field]])
      minute <- !is.na(values) & str_detect(values, "^\\d{2}:\\d{2}:00$")
      values[minute] <- str_sub(values[minute], 1, 5)
      set(dat, j = field, value = values)
    }
    set(dat, j = "rowid", value = seq_len(nrow(dat)))

    for (i in seq_along(rules)) {
      env <- new.env(parent = ns)
      env$x <- copy(dat)
      # Duplicate eggs need an identified visit, rather than shared missing keys.
      if (table == "EGGS" && str_starts(names(rules)[i], fixed("egg_id must"))) {
        fields <- c("nest_id", "date", "time_visit", "observer", "egg_id")
        complete <- lapply(dat[, fields, with = FALSE], data_issues_present) |>
          Reduce(f = `&`)
        env$x <- env$x[complete]
      }
      env$db_get <- reference
      env$DBq <- reference
      unavailable <- FALSE
      result <- tryCatch(eval(rules[[i]], env), error = identity)
      if (unavailable || inherits(result, "error") || !is.data.frame(result) ||
          !all(c("rowid", "variable", "reason") %in% names(result))) {
        fail(table, names(rules)[i])
        next
      }
      if (!nrow(result)) next
      rows <- match(as.character(result$rowid), as.character(dat$rowid))
      fields <- as.character(result$variable)
      valid <- !is.na(rows) & !is.na(fields) & fields %in% names(dat)
      if (!all(valid)) fail(table, names(rules)[i])
      if (!any(valid)) next
      rows <- rows[valid]
      fields <- fields[valid]
      values <- vapply(seq_along(rows), function(j) {
        as.character(dat[[fields[j]]][rows[j]])
      }, "")
      # A correction needs an existing value; missing evidence is outside this tab.
      keep <- which(data_issues_present(values))
      if (!length(keep)) next
      context <- function(field) {
        if (field %in% names(dat)) as.character(dat[[field]][rows[keep]]) else
          rep(NA_character_, length(keep))
      }
      out[[length(out) + 1]] <- data.table(
        table = table, pk = context("pk"), date = context("date"),
        observer = context("observer"), field = fields[keep], value = values[keep],
        issue = as.character(result$reason)[valid][keep]
      )
    }
  }

  issues <- if (length(out)) {
    unique(rbindlist(out))[, .(issue = paste(unique(issue), collapse = " ")),
      by = .(table, pk, date, observer, field, value)]
  } else data_issues_empty()
  list(
    issues = issues, tables = checked, checked_at = Sys.time(),
    failures = if (length(failures)) rbindlist(failures) else
      data.table(table = character(), check = character())
  )
}


data_issues_server <- function(input, output, session) {
  report <- reactiveVal(NULL)
  observeEvent(input$main, {
    req(identical(input$main, "data_issues"))
    result <- tryCatch(
      withProgress(message = "Checking data", value = 0, {
        data_issues_run(progress = function(table, index, total) {
          setProgress(value = (index - 1) / total, detail = table)
        })
      }),
      error = function(error) NULL
    )
    report(result)
    if (is.null(result)) showNotification("Data check failed.", type = "error")
  })

  output$data_issues_status <- renderText({
    result <- report()
    if (is.null(result)) return("Cass River entries.")
    text <- paste0(
      nrow(result$issues), " issues across ", length(result$tables),
      " tables. Cass River. Checked ", format(result$checked_at, "%Y-%m-%d %H:%M"), "."
    )
    if (nrow(result$failures)) text <- paste(
      text, nrow(result$failures), "checks unavailable; results incomplete."
    )
    text
  })

  output$data_issues_table <- renderDT({
    result <- report()
    datatable(
      if (is.null(result)) data_issues_empty() else result$issues,
      colnames = c("Table", "PK", "Date", "Observer", "Field", "Value", "Issue"),
      rownames = FALSE, filter = "top", escape = TRUE,
      options = list(
        pageLength = 200, lengthMenu = c(25, 50, 100, 200),
        scrollX = TRUE, autoWidth = TRUE
      )
    )
  }, server = TRUE)
}
