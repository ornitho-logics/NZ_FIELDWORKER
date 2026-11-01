# Development metadata only: no app sourcing, config, database or installation.
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])), "..", ".."))
lock <- file.path(root, "docs", "reconstruction", "environment.lock.json")
stopifnot(requireNamespace("jsonlite", quietly = TRUE))
packages <- c("DataEntry", "dbo", "gpxui", "DBI", "RMariaDB", "DT", "data.table", "stringr", "glue", "ggplot2", "mgcv", "ggrepel", "htmltools", "htmlwidgets", "ini", "jsonlite", "quarto", "patchwork", "png", "curl", "sf", "zip", "shiny", "shinyWidgets", "shinycssloaders", "bs4Dash", "fresh", "later", "waiter", "leaflet", "commonmark", "testthat", "withr", "remotes")
supplemental <- jsonlite::read_json(file.path(root, "docs", "reconstruction", "external-sources.json"))$packages
packages <- unique(c(packages, unlist(lapply(supplemental, `[[`, "dependencies"), use.names=FALSE)))
installed <- installed.packages()
dependencies <- tools::package_dependencies(intersect(packages, rownames(installed)), db = installed,
                                           which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE)
packages <- sort(setdiff(unique(c(packages, unlist(dependencies, use.names = FALSE))),
                         rownames(installed.packages(priority = "base"))))
inventory <- lapply(packages, function(package) {
  path <- find.package(package, quiet = TRUE)
  if (!length(path)) return(list(name = package, version = NULL, status = "NOT AVAILABLE"))
  description <- read.dcf(file.path(path, "DESCRIPTION"))[1, ]
  field <- function(key) if (key %in% names(description)) unname(description[[key]]) else NULL
  repository <- field("Repository")
  sha <- field("RemoteSha")
  list(name = package, version = field("Version"), repository = repository,
       remote_type = field("RemoteType"), remote_owner = field("RemoteUsername"),
       remote_repo = field("RemoteRepo"), remote_sha = sha,
       dependencies = as.list(tools::package_dependencies(package, db=installed, which=c("Depends", "Imports", "LinkingTo"), recursive=FALSE)[[1L]]),
       provenance = if (!is.null(sha)) "commit" else if (identical(repository, "CRAN")) "CRAN version archive" else if (package %in% rownames(installed.packages(priority = "recommended"))) "R recommended distribution" else "installed version only; source provenance unresolved")
})
tool_version <- function(name) {
  executable <- Sys.which(name)
  if (!nzchar(executable) && name == "quarto" && requireNamespace("quarto", quietly = TRUE)) {
    executable <- tryCatch(quarto::quarto_path(), error = function(e) "")
  }
  if ((!length(executable) || is.na(executable) || !nzchar(executable)) && name == "quarto") {
    candidates <- c(Sys.getenv("QUARTO_PATH", ""), "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto")
    candidates <- candidates[nzchar(candidates) & file.exists(candidates)]
    executable <- if (length(candidates)) candidates[[1L]] else ""
  }
  if (!length(executable) || is.na(executable) || !nzchar(executable)) return(NULL)
  out <- tryCatch(suppressWarnings(system2(executable, "--version", stdout = TRUE, stderr = TRUE)), error = function(e) character())
  if (!length(out) || !is.null(attr(out, "status"))) return(NULL)
  out[[1L]]
}
current <- list(schema_version = "1.0.0", reference = "9e010e5", captured_on = "2026-10-31",
                R = as.character(getRversion()), platform = R.version$platform,
                packages = inventory, tools = list(quarto = tool_version("quarto")),
                database = list(engine = "MariaDB", version = "11.8.9", charset = "utf8mb4", collation = "utf8mb4_uca1400_ai_ci"),
                policy = "Reference pins only; no auto-activation. Versions with unresolved source provenance need an approved source artifact/commit before full environment reconstruction acceptance.")
if (identical(args, "--record")) {
  jsonlite::write_json(current, lock, auto_unbox = TRUE, pretty = TRUE, null = "null")
  cat("Recorded dependency metadata; missing/provenance gaps remain explicit.\n")
} else if (identical(args, "--check")) {
  expected <- jsonlite::read_json(lock, simplifyVector = FALSE)
  for (pin in supplemental) {
    i <- which(vapply(expected$packages, function(x) identical(x$name, pin$name), logical(1)))
    if (length(i) == 1L && is.null(expected$packages[[i]]$version)) expected$packages[[i]] <- pin
  }
  issues <- character()
  if (!identical(current$R, expected$R)) issues <- c(issues, "R version differs")
  for (i in seq_along(inventory)) {
    found <- inventory[[i]]
    pin <- Filter(function(x) identical(x$name, found$name), expected$packages)
    if (!length(pin) || is.null(found$version) || !identical(found$version, pin[[1]]$version)) issues <- c(issues, paste(found$name, "missing or version differs"))
    if (identical(found$provenance, "installed version only; source provenance unresolved")) issues <- c(issues, paste(found$name, "source provenance unresolved"))
    if (length(pin) && !identical(found$remote_sha, pin[[1]]$remote_sha)) issues <- c(issues, paste(found$name, "source commit differs"))
  }
  if (!identical(current$tools$quarto, expected$tools$quarto) || is.null(current$tools$quarto)) issues <- c(issues, "Quarto missing or version differs")
  result <- list(state = if (length(issues)) "NOT AVAILABLE" else "PASS", issues = issues, platform = current$platform)
  cat(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE), "\n")
  if (length(issues)) quit(status = 2L)
} else stop("Use --record or --check; no packages are installed by this tool.")
