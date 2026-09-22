#+ NOTE:
#' list.files('./main/R/', full.names = TRUE) |> lapply(source) |> invisible(); source('main/global.R')
#' shiny::devmode(TRUE);shiny::runApp("./main", launch.browser = TRUE )

#! PACKAGES & DATA
sapply(
  c(
    "DataEntry",
    "DBI",
    "DT",
    "data.table",
    "stringr",
    "glue",
    "ggplot2",
    "ggrepel",
    "htmltools",
    "htmlwidgets",
    "ini",
    "jsonlite",
    "quarto",
    "patchwork",
    "png",
    "curl",
    "sf",
    "zip",

    "shiny",
    "shinyWidgets",
    "shinycssloaders",
    "bs4Dash",
    "fresh",
    "later",
    "waiter",

    "leaflet"
  ),
  require,
  character.only = TRUE,
  quietly = TRUE
)


#! OPTIONS

group <- "nz_fieldworker"
preferred_timezone <- "Pacific/Auckland"

db <- "FIELD_2026_BADOatNZ"
dbtabs_entry <- c(
  "OBSERVERS",
  "CAPTURES",
  "NESTS",
  "EGGS",
  "RESIGHTINGS",
  "RESIGHTINGS_PUBLIC",
  "spatial_objects",
  "inspectors"
)


dbtabs_show_tables <- c(
  "OBSERVERS",
  "CAPTURES",
  "NESTS",
  "EGGS",
  "RESIGHTINGS",
  "RESIGHTINGS_PUBLIC",
  "GPS_POINTS",
  "settings",
  "predict_hatching"
)


dbtabs_show_views <- c(
  "TODO_LIST",
  "AVAILABLE_COMBOS",
  "NESTS_LATEST",
  "CAPTURES_ARCHIVE",
  "EGGS_HATCH_PREDICTION",
  "OVERVIEW",
  "VIEW_1",
  "VIEW_2"
)

# watch list for View updates
dbtabs_show_view_sources <- list(
  OVERVIEW = c(
    "settings",
    "CAPTURES",
    "NESTS",
    "EGGS",
    "RESIGHTINGS"
  ),

  TODO_LIST = c(
    "settings",
    "NESTS",
    "GPS_POINTS",
    "CAPTURES",
    "EGGS",
    "predict_hatching",
    "RESIGHTINGS"
  ),

  NESTS_LATEST = c(
    "settings",
    "NESTS",
    "GPS_POINTS",
    "CAPTURES",
    "EGGS",
    "predict_hatching"
  ),
  CAPTURES_ARCHIVE = c("BADOatNZ.CAPTURES"),

  EGGS_HATCH_PREDICTION = c(
    "settings",
    "NESTS",
    "EGGS",
    "predict_hatching"
  )
)


nest_state_cols <- c(
  "S" = "#f38c38",
  "F" = "#00815f",
  "I" = "#fff023",
  "H" = "#1aa9fc",
  "B" = "#20A387",
  "pP" = "#A50026",
  "P" = "#6405a3",
  "pD" = "#CC79A7",
  "D" = "#6A51A3",
  "notA" = "#4b4b4b",
  "O" = "#999999"
)


kmz_nest_state_cols <- c(
  S = "#f7b267",
  F = "#65cdaa",
  I = "#fff58f",
  H = "#78d6ff",
  B = "#76d7bd",
  pP = "#e37882",
  P = "#b78be7",
  pD = "#edadd3",
  D = "#b9a1dc",
  notA = "#9b9b9b",
  O = "#d0d0d0",
  unknown = "#c7c7c7"
)


#! etc

# Deployments can update app files without advancing the surrounding Git HEAD.
normalize_git_id <- function(value) {
  if (length(value) == 0L || is.na(value[[1L]])) {
    return(NULL)
  }

  value <- trimws(value[[1L]])

  if (!grepl("^[0-9A-Fa-f]{7,40}$", value)) {
    return(NULL)
  }

  tolower(substr(value, 1L, 7L))
}


git_output <- function(app_dir, args) {
  output <- tryCatch(
    suppressWarnings(
      system2(
        "git",
        c("-C", shQuote(app_dir), args),
        stdout = TRUE,
        stderr = FALSE
      )
    ),
    error = function(error) character()
  )

  if (!is.null(attr(output, "status")) && attr(output, "status") != 0L) {
    return(character())
  }

  output
}


git_ref_matches_app <- function(app_dir, ref) {
  status <- tryCatch(
    suppressWarnings(
      system2(
        "git",
        c("-C", shQuote(app_dir), "diff", "--quiet", ref, "--", "."),
        stdout = FALSE,
        stderr = FALSE
      )
    ),
    error = function(error) 1L
  )

  identical(as.integer(status), 0L)
}


parse_git_ls_remote <- function(output) {
  if (length(output) == 0L || !nzchar(trimws(output[[1L]]))) {
    return(NULL)
  }

  fields <- strsplit(trimws(output[[1L]]), "[[:space:]]+")[[1L]]
  normalize_git_id(fields[[1L]])
}


git_remote_main_id <- function(timeout = 5L) {
  output <- tryCatch(
    suppressWarnings(
      system2(
        "git",
        c(
          "ls-remote",
          "https://github.com/ornitho-logics/NZ_FIELDWORKER.git",
          "refs/heads/main"
        ),
        stdout = TRUE,
        stderr = FALSE,
        timeout = timeout
      )
    ),
    error = function(error) character()
  )

  if (!is.null(attr(output, "status")) && attr(output, "status") != 0L) {
    return(NULL)
  }

  parse_git_ls_remote(output)
}


resolve_git_version <- function(app_dir = getwd()) {
  environment_names <- c(
    "FIELDWORKER_GIT_ID",
    "GITHUB_SHA",
    "SOURCE_VERSION",
    "RENDER_GIT_COMMIT"
  )

  for (name in environment_names) {
    id <- normalize_git_id(Sys.getenv(name, unset = NA_character_))

    if (!is.null(id)) {
      return(list(id = id, source = paste0("env:", name)))
    }
  }

  app_dir <- normalizePath(app_dir, mustWork = FALSE)

  for (ref in c("HEAD", "origin/main", "main")) {
    if (!git_ref_matches_app(app_dir, ref)) {
      next
    }

    id <- normalize_git_id(
      git_output(app_dir, c("rev-parse", "--short=7", ref))
    )

    if (!is.null(id)) {
      return(list(id = id, source = paste0("git:", ref)))
    }
  }

  id <- git_remote_main_id()

  if (!is.null(id)) {
    return(list(id = id, source = "remote:origin/main"))
  }

  list(id = "unknown", source = "unavailable")
}


git_version <- resolve_git_version()
git_id <- git_version$id
git_commit_url <- if (git_id == "unknown") {
  "https://github.com/ornitho-logics/NZ_FIELDWORKER"
} else {
  paste0(
    "https://github.com/ornitho-logics/NZ_FIELDWORKER/commit/",
    git_id
  )
}

message(
  "FIELDWORKER commit: ",
  git_id,
  " (",
  git_version$source,
  ")"
)
