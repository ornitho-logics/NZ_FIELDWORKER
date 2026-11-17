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
    "mgcv",
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
  "RESIGHTINGS_field",
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
  "OVERVIEW"
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
    "predict_hatching",
    "RESIGHTINGS"
  ),
  BROODS_LATEST = c(
    "settings",
    "NESTS",
    "GPS_POINTS",
    "CAPTURES",
    "EGGS",
    "predict_hatching",
    "RESIGHTINGS"
  ),
  LIVE_NEST_MAP = c(
    "settings",
    "NESTS",
    "GPS_POINTS",
    "CAPTURES",
    "EGGS",
    "predict_hatching",
    "RESIGHTINGS",
    "TODO_REFRESH_STATUS",
    "TODO_PARENT_STATUS_SNAPSHOT"
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
  "brood" = "#1aa9fc",
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


git_commit_time <- function(app_dir, ref) {
  output <- git_output(
    app_dir,
    c("show", "-s", "--format=%cI", ref)
  )

  if (length(output) == 0L || !nzchar(trimws(output[[1L]]))) {
    return(NULL)
  }

  trimws(output[[1L]])
}


git_local_head_id <- function(app_dir) {
  normalize_git_id(
    git_output(app_dir, c("rev-parse", "--short=7", "HEAD"))
  )
}


git_worktree_dirty <- function(app_dir) {
  status <- git_output(
    app_dir,
    c("status", "--porcelain", "--untracked-files=no")
  )
  length(status) > 0L && any(nzchar(trimws(status)))
}


git_local_preview_enabled <- function() {
  value <- tolower(trimws(
    Sys.getenv("FIELDWORKER_LOCAL_PREVIEW", unset = "")
  ))

  value %in% c("1", "true", "yes", "on")
}


read_pwa_build = function(app_dir = getwd()) {
  path = file.path(app_dir, "www", "build.json")
  if (!file.exists(path)) return(NULL)
  build = tryCatch(
    jsonlite::read_json(path),
    error = function(error) NULL
  )
  if (!is.list(build) || !is.character(build$id) || length(build$id) != 1L ||
      is.na(build$id) || !grepl("^[a-f0-9]{64}$", build$id)) {
    return(NULL)
  }
  build
}


resolve_git_version = function(app_dir = getwd(), local_preview = NULL) {
  if (is.null(local_preview)) local_preview = git_local_preview_enabled()
  if (isTRUE(local_preview)) {
    id = git_local_head_id(app_dir)
    if (!is.null(id)) {
      return(list(id = id, source = "git:HEAD-working-tree",
        commit_time = git_commit_time(app_dir, "HEAD"), local = TRUE,
        dirty = git_worktree_dirty(app_dir), build_id = "unknown"))
    }
  }

  # Snapshot deployment metadata once at process startup. A later static-file
  # update must not relabel an R process that still runs the previous release.
  build = read_pwa_build(app_dir)
  if (!is.null(build)) {
    revision = normalize_git_id(build$revision)
    return(list(id = if (is.null(revision)) "unknown" else revision,
      source = "deployment:build.json", commit_time = NULL, local = FALSE,
      dirty = isTRUE(build$dirty), build_id = build$id))
  }
  list(id = "unknown", source = "unavailable", commit_time = NULL,
    local = FALSE, dirty = FALSE, build_id = "unknown")
}


git_commit_url_for_version <- function(version) {
  commit_id <- version$id
  if (
    is.null(commit_id) ||
      !length(commit_id) ||
      is.na(commit_id[[1L]]) ||
      identical(commit_id[[1L]], "unknown")
  ) {
    return("https://github.com/ornitho-logics/NZ_FIELDWORKER")
  }

  paste0(
    "https://github.com/ornitho-logics/NZ_FIELDWORKER/commit/",
    commit_id[[1L]]
  )
}


git_version_label_text <- function(version) {
  commit_id <- version$id
  if (
    is.null(commit_id) ||
      !length(commit_id) ||
      is.na(commit_id[[1L]]) ||
      !nzchar(as.character(commit_id[[1L]]))
  ) {
    commit_id <- "unknown"
  } else {
    commit_id <- as.character(commit_id[[1L]])
  }

  if (isTRUE(version$local) && commit_id != "unknown") {
    return(paste0("local-", commit_id))
  }

  if (!is.null(version$build_id) &&
      !identical(version$build_id, "unknown")) {
    return(paste("Build", substr(version$build_id, 1L, 12L)))
  }
  "Build unknown"
}


git_version <- resolve_git_version()
git_id <- git_version$id
git_commit_url <- git_commit_url_for_version(git_version)

message(
  "FIELDWORKER build: ",
  git_version$build_id,
  " (",
  git_version$source,
  ")"
)
