# Parse/load/round-trip tracked exports into the runner's fresh synthetic DB.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
root <- normalizePath(args[[1L]])
socket <- args[[2L]]
stopifnot(grepl("^(/private)?/tmp/fw-reconstruct-[a-f0-9]+[.]sock$", socket), file.exists(socket))
marker <- jsonlite::read_json(args[[3L]])
stopifnot(identical(marker$socket, socket), identical(marker$purpose, "synthetic_reconstruction"))
con <- DBI::dbConnect(RMariaDB::MariaDB(), user = "root", host = "localhost", unix.socket = socket, dbname = "FIELD_2026_BADOatNZ")
tryCatch({
  stopifnot(identical(DBI::dbGetQuery(con, "SELECT token FROM reconstruction_owner")$token, marker$token))
  files <- list.files(file.path(root, "notes", "codex_proposals", "validator_sandbox", "inspector_lists_by_table"), pattern = "_(hard|warning)[.]R$", full.names = TRUE)
  stopifnot(length(files) == 12L)
  for (file in files) {
    code <- paste(readLines(file, warn = FALSE), collapse = "\n")
    parse(text = code) # Parse only: do not evaluate DB-managed validator expressions.
    role <- if (grepl("_hard[.]R$", file)) "hard" else "warn"
    table <- sub("_(hard|warning)[.]R$", "", basename(file))
    comments <- paste("Invented reconstruction export", role)
    DBI::dbExecute(con, "INSERT INTO inspectors (table_name, inspector, comments) VALUES (?, ?, ?)", params = list(table, code, comments))
    roundtrip <- DBI::dbGetQuery(con, "SELECT inspector FROM inspectors WHERE table_name = ? AND comments = ?", params = list(table, comments))
    stopifnot(nrow(roundtrip) == 1L, identical(roundtrip$inspector, code))
  }
  cat("PASS: 12 parsed inspector exports round-trip by table/comment role. Package execution is a separate acceptance item.\n")
}, finally = DBI::dbDisconnect(con))
