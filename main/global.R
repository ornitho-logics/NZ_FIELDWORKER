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
    "RESIGHTINGS"
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


git_branch_name <- function(app_dir) {
  branch <- git_output(
    app_dir,
    c("rev-parse", "--abbrev-ref", "HEAD")
  )
  if (length(branch) == 0L || !nzchar(trimws(branch[[1L]]))) {
    return(NULL)
  }
  trimws(branch[[1L]])
}


git_local_preview_enabled <- function() {
  value <- tolower(trimws(
    Sys.getenv("FIELDWORKER_LOCAL_PREVIEW", unset = "")
  ))

  value %in% c("1", "true", "yes", "on")
}


resolve_git_version <- function(
  app_dir = getwd(),
  local_preview = NULL
) {
  app_dir <- normalizePath(app_dir, mustWork = FALSE)

  if (is.null(local_preview)) {
    local_preview <- git_local_preview_enabled()
  }

  # FIELDWORKER_GIT_ID was used by an older deployment and can survive a
  # checkout update in a long-lived Shiny process. It is deliberately not a
  # production fallback: a stale identifier is worse than an explicit
  # "unknown" label. CI/deployment identifiers below are only used when they
  # are provided by a trusted build environment.
  environment_names <- c(
    "GITHUB_SHA",
    "SOURCE_VERSION",
    "RENDER_GIT_COMMIT"
  )

  # Deployment variables are useful when the app is copied without its Git
  # metadata.  When a checkout is available, however, a stale variable must
  # not mask the commit that actually supplies the app files.  This can happen
  # when a long-lived Shiny process retains an old FIELDWORKER_GIT_ID after a
  # checkout has been updated.
  local_head <- git_local_head_id(app_dir)
  branch <- git_branch_name(app_dir)
  dirty <- !is.null(local_head) && git_worktree_dirty(app_dir)

  # Local traceability is opt-in. It must never be inferred from the branch or
  # dirty state because production may run from a copied checkout or a
  # deployment branch. The local PDF harness can set FIELDWORKER_LOCAL_PREVIEW
  # when it intentionally wants a local-<commit> identifier.
  if (isTRUE(local_preview) && !is.null(local_head)) {
    return(list(
      id = local_head,
      source = "git:HEAD-working-tree",
      commit_time = git_commit_time(app_dir, "HEAD"),
      local = TRUE,
      dirty = dirty
    ))
  }

  # Production always asks the public repository for the current main ref
  # first. This makes a merged main commit visible without restarting a
  # process merely to refresh a value captured at startup.
  remote_main_id <- git_remote_main_id()

  if (!is.null(remote_main_id)) {
    return(list(
      id = remote_main_id,
      source = "remote:origin/main",
      commit_time = NULL,
      local = FALSE,
      dirty = FALSE
    ))
  }

  # Trusted build-system metadata is useful for deployments that do not carry
  # a Git checkout and cannot reach GitHub. The legacy FIELDWORKER_GIT_ID is
  # intentionally excluded because it is known to become stale.
  for (name in environment_names) {
    id <- normalize_git_id(Sys.getenv(name, unset = NA_character_))

    if (!is.null(id) &&
        (is.null(local_head) || git_ref_matches_app(app_dir, id))) {
      return(list(
        id = id,
        source = paste0("env:", name),
        commit_time = git_commit_time(app_dir, id),
        local = FALSE,
        dirty = FALSE
      ))
    }
  }

  # A clean main checkout remains a truthful offline fallback. Never expose a
  # feature-branch or dirty HEAD as the production version: that was the cause
  # of the misleading local-34cc549 label.
  if (!is.null(local_head) &&
      !isTRUE(dirty) &&
      !is.null(branch) &&
      branch %in% c("main", "master", "HEAD")) {
    return(list(
      id = local_head,
      source = "git:HEAD",
      commit_time = git_commit_time(app_dir, "HEAD"),
      local = FALSE,
      dirty = FALSE
    ))
  }

  list(
    id = "unknown",
    source = "unavailable",
    commit_time = NULL,
    local = FALSE,
    dirty = FALSE
  )
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

  commit_id
}


git_version <- resolve_git_version()
git_id <- git_version$id
git_commit_url <- git_commit_url_for_version(git_version)

message(
  "FIELDWORKER commit: ",
  git_id,
  " (",
  git_version$source,
  ")"
)
