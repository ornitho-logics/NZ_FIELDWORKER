# Documentation only: parse inspector source; never evaluate validators or query data.
validator_catalog <- function(root = ".", archived = FALSE) {
    tables <- c("CAPTURES", "EGGS", "NESTS", "OBSERVERS", "RESIGHTINGS", "RESIGHTINGS_PUBLIC")
    manifest <- if (archived) jsonlite::read_json(file.path(
        root, "docs", "validation", "archives", "2026-11-08", "manifest.json")) else NULL
    entries <- if (archived) unlist(lapply(tables, function(table)
        paste(table, c("hard", "warning"), sep = "_")), use.names = FALSE) else tables
    literal_strings <- function(expr) {
        if (missing(expr)) return(character())
        if (is.character(expr)) return(expr)
        if (!is.call(expr) && !is.pairlist(expr) && !is.expression(expr)) return(character())
        unlist(lapply(as.list(expr), literal_strings), use.names = FALSE)
    }
    rows <- list()
    sources <- list()
    first_label <- function(expr) {
        if (missing(expr) || !is.call(expr)) return(NULL)
        if (identical(expr[[1L]], as.name("try_validator"))) {
            label <- as.list(expr)[["nam"]]
            if (is.character(label) && length(label) == 1L) return(label)
        }
        for (child in as.list(expr)[-1L]) {
            label <- first_label(child)
            if (!is.null(label)) return(label)
        }
        NULL
    }
    for (entry in entries) {
        table <- if (archived) sub("_(hard|warning)$", "", entry) else entry
        role <- if (archived) sub(paste0("^", table, "_"), "", entry) else "file"
        path <- if (archived) file.path(
            "notes", "codex_proposals", "validator_sandbox", "inspector_lists_by_table",
            paste0(entry, ".R")) else file.path("DataEntry", table, "inspector.R")
        file <- file.path(root, path)
        if (archived) {
            member <- Filter(function(item) identical(item$path, path), manifest$members)
            if (length(member) != 1L) stop("Missing archived manifest entry: ", path)
            hash <- system2("git", c("hash-object", "--no-filters", shQuote(file)), stdout = TRUE)
            if (!identical(hash, member[[1L]]$git_blob) ||
                file.info(file)$size != member[[1L]]$bytes) {
                stop("Editable export no longer matches immutable archived source: ", path)
            }
        }
        code <- parse(file, keep.source = TRUE)
        if (length(code) != 1L || !is.call(code[[1L]]) ||
            !identical(code[[1L]][[1L]], as.name("list"))) {
            stop("Expected one literal inspector list: ", path, call. = FALSE)
        }
        rules <- as.list(code[[1L]])[-1L]
        tokens <- utils::getParseData(code)
        top <- tokens[tokens$parent == 0L & tokens$token == "expr", ]
        if (nrow(top) != 1L) stop("Ambiguous inspector source: ", path)
        nodes <- tokens[tokens$parent == top$id & tokens$token == "expr", ]
        nodes <- nodes[order(nodes$line1, nodes$col1), ][-1L, ]
        notes <- tokens[tokens$parent == top$id & tokens$token == "COMMENT", ]
        notes <- notes[order(notes$line1, notes$col1), ]
        if (nrow(nodes) != length(rules)) stop("Source positions do not match rules: ", path)
        sources[[entry]] <- list(path = path, md5 = unname(tools::md5sum(file)),
                                  rules = length(rules))
        ids <- character()
        for (i in seq_along(rules)) {
            rule <- rules[[i]]
            if (!archived && (!is.call(rule) || !identical(rule[[1L]], as.name("try_validator")))) {
                stop("Expected a named try_validator wrapper: ", path, " rule ", i)
            }
            id <- first_label(rule)
            if (!is.character(id) || length(id) != 1L || !nzchar(id) || id %in% ids) {
                stop("Missing or duplicate rule ID: ", path, " rule ", i)
            }
            ids <- c(ids, id)
            previous <- if (i == 1L) 0L else nodes$line2[i - 1L]
            headings <- notes$text[notes$line1 > previous & notes$line1 <= nodes$line1[i]]
            title <- if (length(headings)) sub("^#\\s*", "", utils::tail(headings, 1L)) else id
            reasons <- character()
            collect_reasons <- function(expr) {
                if (missing(expr)) return(invisible(NULL))
                if (!is.call(expr)) return(invisible(NULL))
                parts <- as.list(expr)
                labels <- names(parts)
                if (!is.null(labels)) {
                    for (j in which(labels == "reason")) {
                        reasons <<- c(reasons, literal_strings(parts[[j]]))
                    }
                }
                for (child in parts[-1L]) collect_reasons(child)
                invisible(NULL)
            }
            collect_reasons(rule)
            rows[[length(rows) + 1L]] <- list(
                key = paste(entry, id, sep = ":"), table = table, entry = entry,
                role = role, id = id,
                title = title, source = path,
                line_start = nodes$line1[i], line_end = nodes$line2[i],
                messages = unique(reasons[nzchar(reasons)])
            )
        }
    }
    list(format_version = 1L, archived = archived,
         source_commit = if (archived) manifest$source_commit else NULL,
         scope = if (archived) "Immutable original hard/warning groups; not the current loader or a recommendation to install them." else
             "Current per-app inspector.R definitions; source inventory, not a live deployment or severity claim.",
         sources = sources, rules = rows)
}

validator_catalog_markdown <- function(catalog) {
    clean <- function(value) {
        value <- gsub("[\r\n]+", " ", value)
        gsub("|", "\\|", value, fixed = TRUE)
    }
    out <- c(
        if (catalog$archived) "# Archived validator groups for maintainer review" else
            "# Validator reference for maintainers", "",
        "Generated from the current per-app source by",
        "`tools/validation/build_validator_catalog.R`. No validators are evaluated.",
        "This is GitHub documentation, not an app settings screen. Read",
        "[selective validation](SELECTIVE_VALIDATION.md) before changing a check.", "",
        if (catalog$archived)
            "Keys combine the original hard/warning export and its outer named validator group." else
            "Keys combine the table and its existing `try_validator(nam = ...)` label.",
        "A heading describes a whole check, which may cover several fields or conditions.",
        "The message column lists up to three literal source messages, not every",
        "possible dynamic result. The complete expression is authoritative.",
        if (catalog$archived)
            "Links are pinned to the original source commit. Groups are not one-to-one matches to current valN checks; this is not an instruction to install the old lists." else
            "Line links refer to current files; regenerate after editing or moving rules.", "",
        "| Table | Checks | Source MD5 |", "| --- | ---: | --- |"
    )
    for (table in names(catalog$sources)) {
        entry <- catalog$sources[[table]]
        out <- c(out, sprintf("| [%s](#%s) | %d | `%s` |",
                              table, tolower(table), entry$rules, entry$md5))
    }
    for (table in names(catalog$sources)) {
        out <- c(out, "", paste("##", table), "",
                 "| Check ID | What it checks | Example messages |",
                 "| --- | --- | --- |")
        for (rule in Filter(function(row) row$entry == table, catalog$rules)) {
            link <- if (catalog$archived) sprintf(
                "https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/%s/%s#L%d-L%d",
                catalog$source_commit, rule$source, rule$line_start, rule$line_end) else
                sprintf("../../%s#L%d-L%d", rule$source, rule$line_start, rule$line_end)
            messages <- utils::head(rule$messages, 3L)
            examples <- if (length(messages)) paste(clean(messages), collapse = "<br>") else
                "See source for constructed messages."
            out <- c(out, sprintf("| [`%s`](%s) | %s | %s |",
                                  rule$key, link, clean(rule$title), examples))
        }
    }
    paste0(paste(out, collapse = "\n"), "\n")
}

validator_catalog_outputs <- function(root = ".") {
    catalog <- validator_catalog(root)
    archived <- validator_catalog(root, archived = TRUE)
    list(
        "docs/validation/VALIDATOR_CATALOG.md" = validator_catalog_markdown(catalog),
        "docs/validation/validator_catalog.json" =
            paste0(jsonlite::toJSON(catalog, auto_unbox = TRUE, pretty = TRUE), "\n"),
        "docs/validation/ARCHIVED_VALIDATOR_CATALOG.md" = validator_catalog_markdown(archived),
        "docs/validation/archived_validator_catalog.json" =
            paste0(jsonlite::toJSON(archived, auto_unbox = TRUE, pretty = TRUE), "\n")
    )
}

if (sys.nframe() == 0L) {
    args <- commandArgs(trailingOnly = TRUE)
    output <- validator_catalog_outputs()
    if (identical(args, "--check")) {
        for (path in names(output)) {
            if (!file.exists(path) ||
                !identical(paste0(paste(readLines(path, warn = FALSE, encoding = "UTF-8"),
                                       collapse = "\n"), "\n"), output[[path]])) {
                stop("Validator catalog is stale: ", path, call. = FALSE)
            }
        }
        message("Current and archived catalogs match their reviewed inspector sources.")
    } else if (identical(args, "--markdown")) {
        cat(output[[1L]])
    } else if (identical(args, "--json")) {
        cat(output[[2L]])
    } else if (identical(args, "--archived-markdown")) {
        cat(output[[3L]])
    } else if (identical(args, "--archived-json")) {
        cat(output[[4L]])
    } else {
        stop("Use --check, --markdown, --json, --archived-markdown, or --archived-json.", call. = FALSE)
    }
}
