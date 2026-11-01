# Opt-in package materialisation into a NEW isolated library only.
# Default prints an exact source plan. Never updates the app's existing library.
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])), "..", ".."))
stopifnot(requireNamespace("jsonlite", quietly = TRUE))
value <- function(flag) { i <- match(flag, args); if (is.na(i)) NULL else { stopifnot(i < length(args)); args[[i + 1L]] } }
lock <- jsonlite::read_json(file.path(root, "docs", "reconstruction", "environment.lock.json"))
pins <- jsonlite::read_json(file.path(root, "docs", "reconstruction", "external-sources.json"))$packages
packages <- setNames(lock$packages, vapply(lock$packages, `[[`, "", "name"))
for (pin in pins) if (is.null(packages[[pin$name]]$version)) packages[[pin$name]] <- pin
only <- value("--only")
all_packages <- packages
base_packages <- c("R", rownames(installed.packages(priority="base")))
if (!is.null(only)) { stopifnot(only %in% names(packages)); packages <- packages[only] }
ordered <- character()
visiting <- character()
visit <- function(name) {
  if (name %in% ordered || name %in% base_packages) return(invisible(NULL))
  if (!name %in% names(all_packages)) stop("Required dependency has no pin: ", name)
  if (!name %in% names(packages)) {
    # A narrow overlay may reuse only already-matching locked dependencies.
    existing <- tryCatch(utils::packageDescription(name), error=function(e) NULL)
    pin <- all_packages[[name]]
    if (is.null(existing) || is.null(pin$version) || !identical(existing$Version, pin$version)) stop("Overlay dependency does not match lock; install full environment first: ", name)
    if (!is.null(pin$remote_sha) && !identical(existing$RemoteSha, pin$remote_sha)) stop("Overlay dependency commit differs: ", name)
    return(invisible(NULL))
  }
  if (name %in% visiting) stop("Cyclic dependency plan")
  visiting <<- c(visiting, name)
  for (dependency in unlist(packages[[name]]$dependencies)) visit(dependency)
  visiting <<- setdiff(visiting, name)
  ordered <<- c(ordered, name)
}
if (is.null(only) && any(vapply(packages, function(p) !is.null(p$remote_sha), logical(1)))) visit("remotes")
for (name in names(packages)) visit(name)
plan <- lapply(ordered, function(name) {
  pin <- packages[[name]]
  if (is.null(pin$version)) stop("No version/source pin: ", name)
  if (!is.null(pin$remote_sha)) {
    stopifnot(identical(pin$remote_type, "github"), grepl("^[a-f0-9]{40}$", pin$remote_sha))
    source <- paste0(pin$remote_owner, "/", pin$remote_repo, "@", pin$remote_sha)
    kind <- "github_commit"
  } else if (identical(pin$repository, "CRAN")) {
    source <- paste0("https://cran.r-project.org/src/contrib/Archive/", name, "/", name, "_", pin$version, ".tar.gz")
    kind <- "CRAN_archive"
  } else if (identical(pin$provenance, "R recommended distribution")) {
    source <- paste("R", lock$R, "recommended distribution")
    kind <- "R_distribution"
  } else stop("Unresolved package provenance: ", name)
  list(name=name, version=pin$version, kind=kind, source=source,
       exact_current_fallback=if (kind == "CRAN_archive") paste0("https://cran.r-project.org/src/contrib/", name, "_", pin$version, ".tar.gz") else NULL)
})
cat(jsonlite::toJSON(plan, auto_unbox=TRUE, pretty=TRUE), "\n")
if (!"--apply" %in% args) quit(status=0L)
library <- value("--library")
if (is.null(library) || dir.exists(library) || file.exists(library)) stop("--apply requires a NEW --library path; existing libraries are never modified")
stopifnot(identical(as.character(getRversion()), lock$R))
dir.create(library, recursive=TRUE)
writeLines("FIELDWORKER isolated reconstruction library", file.path(library, ".reconstruction-library"))
.libPaths(c(library, .libPaths()))
for (entry in plan) {
  if (entry$kind == "R_distribution") {
    if (!identical(as.character(utils::packageVersion(entry$name)), entry$version)) stop("Provision matching R recommended package: ", entry$name)
  } else if (entry$kind == "CRAN_archive") {
    archive <- tempfile(paste0(entry$name, "_"), fileext=".tar.gz")
    fetched <- tryCatch(suppressWarnings(download.file(entry$source, archive, quiet=TRUE)) == 0L, error=function(e) FALSE)
    if (!fetched) download.file(entry$exact_current_fallback, archive, quiet=TRUE)
    install.packages(archive, lib=library, repos=NULL, type="source", dependencies=FALSE)
  } else {
    stopifnot(requireNamespace("remotes", quietly=TRUE))
    pin <- Filter(function(p) identical(p$name, "remotes"), lock$packages)
    stopifnot(length(pin) == 1L, identical(as.character(utils::packageVersion("remotes")), pin[[1L]]$version))
    remotes::install_github(entry$source, lib=library, dependencies=FALSE, upgrade="never", build_vignettes=FALSE, auth_token="")
  }
  installed <- utils::packageDescription(entry$name, lib.loc=if (entry$kind == "R_distribution") NULL else library)
  stopifnot(identical(installed$Version, entry$version))
  if (entry$kind == "github_commit") stopifnot(identical(installed$RemoteSha, packages[[entry$name]]$remote_sha))
}
cat("Installed selected pins into isolated library only. Prepend it per process with R_LIBS, preserving existing library paths, then rerun inventory/acceptance.\n")
