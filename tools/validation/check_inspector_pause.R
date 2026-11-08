# Approved in-memory checks only: no app startup, DB connection, or field rows.
ns <- asNamespace("DataEntry")
proposal <- paste(readLines("docs/validation/noop_inspector.R"), collapse = "\n")
sql <- readLines("DATABASE/pause_inspectors_2026-11-08.SQL")
code_line <- grep("^SET @pause_code = '", sql, value = TRUE)
stopifnot(length(code_line) == 1L)
code <- sub("';$", "", sub("^SET @pause_code = '", "", code_line))
tables <- c("CAPTURES", "EGGS", "NESTS", "OBSERVERS", "RESIGHTINGS", "RESIGHTINGS_PUBLIC")
n_checks <- 0L
check <- function(ok) {
    stopifnot(isTRUE(ok))
    n_checks <<- n_checks + 1L
}
clone_with <- function(fn, bindings) {
    environment(fn) <- list2env(bindings, parent = environment(fn))
    fn
}
check(identical(parse(text = code, keep.source = FALSE),
                parse(text = proposal, keep.source = FALSE)))

# Exercise actual loader/parser bodies, replacing DB reads in a private closure.
# This never changes the installed namespace or any global DB function.
make_issues <- function(payloads) {
    loader <- clone_with(get("inspector_loader", ns), list(
        inspectors_table_exists = function() TRUE,
        db_get = function(sql, ..., params) {
            stopifnot(identical(length(params), 1L), params[[1L]] %in% tables)
            data.frame(inspector = payloads, stringsAsFactors = FALSE)
        }
    ))
    clone_with(get("validation_issues", ns), list(inspector_loader = loader))
}
issues <- make_issues(code)
save_gate <- get("validate_before_save", ns)
panel <- list(open = function(...) stop("Unexpected blocking panel call"))
inputs <- list(ignore_checks = FALSE)
examples <- list(
    data.table::data.table(observer = "!", nest_id = "BAD", clutch_size = -99L),
    data.table::data.table(observer = NA_character_, nest_id = NA_character_),
    data.table::data.table(rowid = 1:2, arbitrary = c("invented", "values")),
    data.table::data.table(rowid = integer(), arbitrary = character())
)
for (table in tables) {
    for (x in examples) {
        found <- issues(x, table_name = table)
        check(nrow(found) == 0L)
        check(all(c("rowid", "variable", "reason") %in% names(found)))
        result <- save_gate(inputs, x, table_name = table, validation_panel = panel,
                            issues = function(x) issues(x, table_name = table))
        check(result$ok && !result$ignore_validators)
        check(identical(result$x, x))
    }
}

# Multiple no-op rows remain compatible with the loader's c(list(...), ...) path.
check(nrow(make_issues(rep(code, 2L))(examples[[1L]], tables[[1L]])) == 0L)

# Regression control: reproduce the existing empty-table bug without Shiny UI.
empty_issues <- make_issues(character())(examples[[1L]], tables[[1L]])
check(nrow(empty_issues) == 1L)
check(all(is.na(empty_issues$variable)))
check(grepl("Inspector validation failed", empty_issues$reason[[1L]], fixed = TRUE))
placeholder_issues <- make_issues("list()")(examples[[1L]], tables[[1L]])
check(nrow(placeholder_issues) == 1L)
check(grepl("Inspector validation failed", placeholder_issues$reason[[1L]], fixed = TRUE))
opened <- FALSE
gate_env <- list(showNotification = function(...) invisible(NULL))
blocked_gate <- clone_with(save_gate, gate_env)
blocked <- blocked_gate(inputs, examples[[1L]],
    validation_panel = list(open = function(value) opened <<- value),
    issues = function(x) empty_issues)
check(!blocked$ok && opened)

# Document, rather than change, the package's existing nov semantics.
nov <- get("add_nov_flags", ns)(data.table::data.table(rowid = 1:2),
    issues(examples[[1L]], tables[[1L]]))
check(all(nov$nov == 0))

# Parse all approved exports without evaluating their real validation code.
exports <- list.files("notes/codex_proposals/validator_sandbox/inspector_lists_by_table",
    pattern = "_(hard|warning)\\.R$", full.names = TRUE)
check(length(exports) == 12L)
for (path in exports) check(length(parse(file = path)) == 1L)
cat(sprintf("PASS: %d checks; DataEntry %s; no app or database connection.\n",
    n_checks, as.character(utils::packageVersion("DataEntry"))))
