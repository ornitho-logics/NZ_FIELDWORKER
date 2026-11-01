# Child of bootstrap.py only. No main/global.R, real config or live app.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 4L)
root <- normalizePath(args[[1L]])
socket <- args[[2L]]
output <- args[[3L]]
stopifnot(grepl("^(/private)?/tmp/fw-reconstruct-[a-f0-9]+[.]sock$", socket), file.exists(socket))
marker <- jsonlite::read_json(args[[4L]])
stopifnot(identical(marker$socket, socket), identical(marker$purpose, "synthetic_reconstruction"))
con <- DBI::dbConnect(RMariaDB::MariaDB(), user="root", host="localhost", unix.socket=socket, dbname="FIELD_2026_BADOatNZ")
tryCatch(stopifnot(identical(DBI::dbGetQuery(con, "SELECT token FROM reconstruction_owner")$token, marker$token)),
         finally=DBI::dbDisconnect(con))
Sys.setenv(THREAD2_TEST_MARIADB_DISPOSABLE = "1", THREAD2_TEST_MARIADB_SOCKET = socket)
library(testthat)
app_file <- function(...) file.path(root, ...)
failures <- 0L
summary <- list()
for (file in c("test-sql-todo-task-gates-2026-10-29.R", "test-sql-latest-chick-encounter-context-2026-10-29.R")) {
  result <- test_file(app_file("tests", "testthat", file), reporter = "summary")
  expectations <- unlist(lapply(result, `[[`, "results"), recursive = FALSE)
  count <- function(type) sum(vapply(expectations, inherits, logical(1), what = type))
  row <- list(file = file, passed = count("expectation_success"), failed = count("expectation_failure") + count("expectation_error"), skipped = count("expectation_skip"), warnings = count("expectation_warning"))
  summary[[file]] <- row
  failures <- failures + row$failed + row$skipped + row$warnings
}
jsonlite::write_json(summary, output, pretty = TRUE, auto_unbox = TRUE)
if (failures) stop("Required focused SQL checks failed, skipped or warned; stop before rendering.")
