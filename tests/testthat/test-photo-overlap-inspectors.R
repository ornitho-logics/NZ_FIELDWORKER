library(testthat)
library(data.table)

photo_overlap_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
photo_overlap_paths <- c(
    CAPTURES = file.path(photo_overlap_root, "notes", "codex_proposals", "validator_sandbox", "inspector_lists_by_table", "CAPTURES_hard.R"),
    NESTS = file.path(photo_overlap_root, "notes", "codex_proposals", "validator_sandbox", "inspector_lists_by_table", "NESTS_hard.R"),
    RESIGHTINGS = file.path(photo_overlap_root, "notes", "codex_proposals", "validator_sandbox", "inspector_lists_by_table", "RESIGHTINGS_hard.R")
)

photo_overlap_block <- function(path) {
    parsed <- parse(file = path)[[1L]]
    candidates <- as.list(parsed)[-1L]
    candidates <- candidates[vapply(candidates, function(expr) {
        grepl("GLOBAL_005 photo unique|nam = \"photo numbers unique\"", paste(deparse(expr), collapse = ""))
    }, logical(1))]
    expect_length(candidates, 1L)
    candidates[[1L]]
}

run_photo_overlap_block <- function(path, current, refs) {
    env <- new.env(parent = globalenv())
    env$x <- as.data.table(current)
    env$try_validator <- function(expr, nam = NULL) {
        eval(substitute(expr), parent.frame())
    }
    env$db_get <- function(sql) {
        table <- sub(".*FROM ([A-Z_]+).*", "\\1", sql)
        value <- refs[[table]]
        if (is.null(value)) data.table() else value
    }
    eval(photo_overlap_block(path), envir = env)
}

photo_overlap_row <- function(table_name, pk = 1L, start = "102-4122", end = "102-4154",
                              observer = "ADO", nest_id = "-BA0808") {
    data.table(
        pk = pk,
        cam_id = "C5",
        date = "2026-10-25",
        observer = observer,
        nest_id = nest_id,
        gps_id = 7L,
        gps_point = 88L,
        rclass = if (table_name == "RESIGHTINGS") "H" else NA_character_,
        age = if (table_name == "RESIGHTINGS") "C" else NA_character_,
        photo_start = start,
        photo_end = end
    )
}

empty_photo_refs <- list(
    CAPTURES = data.table(),
    NESTS = data.table(),
    RESIGHTINGS = data.table()
)

test_that("photo overlap inspectors cover all photo-bearing tables and preserve edits", {
    for (table_name in names(photo_overlap_paths)) {
        current <- photo_overlap_row(table_name, pk = 1L)
        expect_equal(
            nrow(run_photo_overlap_block(photo_overlap_paths[[table_name]], current, empty_photo_refs)),
            0L
        )

        refs <- empty_photo_refs
        refs[[table_name]] <- photo_overlap_row(table_name, pk = 1L)
        expect_equal(
            nrow(run_photo_overlap_block(photo_overlap_paths[[table_name]], current, refs)),
            0L
        )

        refs[[table_name]] <- photo_overlap_row(
            table_name,
            pk = 2L,
            nest_id = if (table_name == "RESIGHTINGS") "-BA0809" else "-BA0808"
        )
        expect_equal(
            nrow(run_photo_overlap_block(photo_overlap_paths[[table_name]], current, refs)),
            1L
        )
    }
})

test_that("saved H rows from the same photo session may share a range", {
    refs <- empty_photo_refs
    refs$RESIGHTINGS <- photo_overlap_row("RESIGHTINGS", pk = 91L, observer = "BJ")
    current <- photo_overlap_row("RESIGHTINGS", pk = 1L, observer = "ADO")

    expect_equal(
        nrow(run_photo_overlap_block(photo_overlap_paths[["RESIGHTINGS"]], current, refs)),
        0L
    )

    refs$RESIGHTINGS <- photo_overlap_row("RESIGHTINGS", pk = 91L, nest_id = "-BA0809")
    result <- run_photo_overlap_block(photo_overlap_paths[["RESIGHTINGS"]], current, refs)
    expect_equal(nrow(result), 1L)
    expect_equal(result$variable, "photo_start")
})

test_that("roll-frame prefixes remain part of photo identity when extensions are present", {
    refs <- empty_photo_refs
    refs$RESIGHTINGS <- photo_overlap_row(
        "RESIGHTINGS", pk = 91L,
        start = "103-4122.JPG", end = "103-4154.JPG", nest_id = "-BA0809"
    )
    current <- photo_overlap_row(
        "RESIGHTINGS", pk = 1L,
        start = "102-4122.JPG", end = "102-4154.JPG"
    )

    expect_equal(
        nrow(run_photo_overlap_block(photo_overlap_paths[["RESIGHTINGS"]], current, refs)),
        0L
    )
})
