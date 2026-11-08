# Development-only generator. Reads reviewed source, never connects to a DB.
# Run from the repository root with one NEW output path in an ignored folder.
build_inspector_restore <- function(output) {
    stopifnot(requireNamespace("jsonlite", quietly = TRUE))
    archive_dir <- "docs/validation/archives/2026-11-08"
    archive <- file.path(archive_dir, "inspectors.tar.gz")
    manifest <- jsonlite::read_json(file.path(archive_dir, "manifest.json"))
    expected_archive <- "51fbc9453e20d90db30edb6bccd1acf1cae7bebcd331dd605c70a01ec244b92c"
    stopifnot(identical(manifest$archive$sha256, expected_archive))
    sha256 <- function(path) {
        cmd <- Sys.which("sha256sum")
        args <- shQuote(path)
        if (!nzchar(cmd)) {
            cmd <- Sys.which("shasum")
            args <- c("-a", "256", args)
        }
        if (!nzchar(cmd)) stop("Install sha256sum or shasum before proceeding.")
        result <- system2(cmd, args, stdout = TRUE, stderr = TRUE)
        if (!is.null(attr(result, "status")) || length(result) != 1L) {
            stop("Checksum command failed.")
        }
        hash <- substr(result, 1L, 64L)
        stopifnot(grepl("^[a-f0-9]{64}$", hash))
        hash
    }
    stopifnot(identical(sha256(archive), expected_archive))
    if (file.exists(output)) stop("Output exists; choose a new filename.")
    ignored <- system2("git", c("check-ignore", "-q", "--", shQuote(output)))
    if (!identical(ignored, 0L)) stop("Output must be inside a Git-ignored folder.")
    tables <- c("CAPTURES", "EGGS", "NESTS", "OBSERVERS", "RESIGHTINGS", "RESIGHTINGS_PUBLIC")
    prefix <- "notes/codex_proposals/validator_sandbox/inspector_lists_by_table"
    expected <- c(file.path(prefix, "FILE_INDEX.txt"),
        as.vector(outer(tables, c("hard.R", "warning.R"),
            function(table, role) file.path(prefix, paste(table, role, sep = "_")))))
    paths <- vapply(manifest$members, `[[`, "", "path")
    stopifnot(length(paths) == 13L, identical(sort(paths), sort(expected)))
    contents <- utils::untar(archive, list = TRUE)
    stopifnot(identical(sort(contents[!grepl("/$", contents)]), sort(expected)))
    allowed_dirs <- c("notes/", "notes/codex_proposals/",
        "notes/codex_proposals/validator_sandbox/", paste0(prefix, "/"))
    stopifnot(all(contents %in% c(expected, allowed_dirs)))
    dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
    extraction <- tempfile("restore-source-", tmpdir = dirname(output))
    dir.create(extraction)
    utils::untar(archive, exdir = extraction)
    hex <- function(value) paste(sprintf("%02x", as.integer(value)), collapse = "")
    literal <- function(value) paste0("CONVERT(0x", hex(charToRaw(enc2utf8(value))), " USING utf8mb4)")
    records <- list()
    for (member in manifest$members) {
        path <- file.path(extraction, member$path)
        stopifnot(file.info(path)$size == member$bytes,
                  identical(sha256(path), member$sha256))
        if (!grepl("\\.R$", path)) next
        code <- rawToChar(readBin(path, "raw", n = member$bytes))
        stopifnot(length(parse(text = code, keep.source = FALSE)) == 1L)
        filename <- basename(path)
        role <- if (grepl("_warning\\.R$", filename)) "warn" else "hard"
        table <- sub("_(hard|warning)\\.R$", "", filename)
        comment <- paste("LEH restored reviewed inspector archive 2026-11-08", role)
        records[[length(records) + 1L]] <- list(table = table, role = role,
            comment = comment, code = code, sha256 = member$sha256)
    }
    stopifnot(length(records) == 12L)
    quoted_tables <- paste(sprintf("'%s'", tables), collapse = ", ")
    payload <- paste(vapply(records, function(row) paste0("    ('", row$table,
        "', ", literal(row$code), ", ", literal(row$comment), ")"), ""), collapse = ",\n")
    cases <- paste(vapply(records, function(row) paste0(
        "WHEN table_name = '", row$table, "' AND BINARY comments = BINARY ",
        literal(row$comment), " AND SHA2(inspector, 256) = '", row$sha256,
        "' THEN 1"), ""), collapse = "\n        ")
    verification <- paste0(
        "SELECT COUNT(*), COUNT(DISTINCT CONCAT(table_name, CHAR(31), comments)),\n",
        "       COALESCE(SUM(CASE\n        ", cases, "\n        ELSE 0 END), 0)\n",
        "INTO v_total, v_distinct, v_matching\nFROM FIELD_2026_BADOatNZ.inspectors;")
    pause_code <- paste0("list(try_validator(data.table::data.table(rowid = integer(), ",
        "variable = character(), reason = character()), nam = \"TEMPORARY validation pause\"))")
    sql <- paste0(
        "-- HUMAN-APPLIED RESTORE: generated from the checksummed approved archive.\n",
        "-- No DB connection was made by the generator. Save a fresh backup first.\n",
        "-- Select FIELD_2026_BADOatNZ. Close inspector editors; Stop on error ON.\n",
        "-- Run the ENTIRE file, including DELIMITER lines, in Adminer.\n",
        "-- MariaDB only. The anonymous block creates no permanent routine or table.\n",
        "-- Exact pause definitions required; unexpected rows abort unchanged.\n",
        "-- A handler rolls back errors/warnings in the transaction owned here.\n",
        "-- New role comments describe restoration, not deleted original metadata.\n",
        "DELIMITER $$\nBEGIN NOT ATOMIC\n",
        "    DECLARE v_owns_transaction BOOLEAN DEFAULT FALSE;\n",
        "    DECLARE v_total BIGINT DEFAULT 0;\n",
        "    DECLARE v_distinct BIGINT DEFAULT 0;\n",
        "    DECLARE v_matching BIGINT DEFAULT 0;\n",
        "    DECLARE EXIT HANDLER FOR SQLWARNING\n",
        "    BEGIN\n",
        "        IF v_owns_transaction THEN ROLLBACK; END IF;\n",
        "        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Restore warning; owned transaction rolled back';\n",
        "    END;\n",
        "    DECLARE EXIT HANDLER FOR SQLEXCEPTION\n",
        "    BEGIN\n",
        "        IF v_owns_transaction THEN ROLLBACK; END IF;\n",
        "        RESIGNAL;\n",
        "    END;\n",
        "    IF COALESCE(DATABASE() = 'FIELD_2026_BADOatNZ', 0) <> 1\n",
        "       OR @@autocommit <> 1 OR @@in_transaction <> 0 THEN\n",
        "        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Wrong database or existing transaction; restore refused';\n",
        "    END IF;\n",
        "    IF (SELECT COUNT(*) FROM information_schema.TABLES\n",
        "        WHERE TABLE_SCHEMA = 'FIELD_2026_BADOatNZ' AND TABLE_NAME = 'inspectors'\n",
        "          AND TABLE_TYPE = 'BASE TABLE' AND ENGINE = 'InnoDB') <> 1\n",
        "       OR (SELECT COUNT(*) FROM information_schema.TRIGGERS\n",
        "           WHERE EVENT_OBJECT_SCHEMA = 'FIELD_2026_BADOatNZ'\n",
        "             AND EVENT_OBJECT_TABLE = 'inspectors') <> 0 THEN\n",
        "        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'InnoDB/no-trigger guard failed; restore refused';\n",
        "    END IF;\n",
        "    SET SESSION lock_wait_timeout = 15;\n",
        "    SET SESSION innodb_lock_wait_timeout = 15;\n",
        "    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;\n",
        "    START TRANSACTION;\n",
        "    SET v_owns_transaction = TRUE;\n",
        "    SELECT table_name AS locked_inspector_table\n",
        "    FROM FIELD_2026_BADOatNZ.inspectors FOR UPDATE;\n",
        verification, "\n",
        "    IF NOT (v_total = 12 AND v_distinct = 12 AND v_matching = 12) THEN\n",
        "        SELECT COUNT(*), COUNT(DISTINCT table_name), COALESCE(SUM(CASE\n",
        "            WHEN table_name IN (", quoted_tables, ")\n",
        "             AND BINARY inspector = BINARY ", literal(pause_code), "\n",
        "             AND BINARY comments = BINARY 'LEH temporary validation pause 2026-11-08 hard'\n",
        "            THEN 1 ELSE 0 END), 0)\n",
        "        INTO v_total, v_distinct, v_matching FROM FIELD_2026_BADOatNZ.inspectors;\n",
        "        IF NOT (v_total = 6 AND v_distinct = 6 AND v_matching = 6) THEN\n",
        "            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unexpected inspector state; nothing restored';\n",
        "        END IF;\n",
        "        DELETE FROM FIELD_2026_BADOatNZ.inspectors\n",
        "        WHERE table_name IN (", quoted_tables, ")\n",
        "          AND BINARY inspector = BINARY ", literal(pause_code), "\n",
        "          AND BINARY comments = BINARY 'LEH temporary validation pause 2026-11-08 hard';\n",
        "        INSERT INTO FIELD_2026_BADOatNZ.inspectors (table_name, inspector, comments) VALUES\n",
        payload, ";\n",
        verification, "\n",
        "        IF NOT (v_total = 12 AND v_distinct = 12 AND v_matching = 12) THEN\n",
        "            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Restore verification failed; rolling back';\n",
        "        END IF;\n",
        "    END IF;\n",
        "    COMMIT;\n",
        "    SET v_owns_transaction = FALSE;\n",
        "    SELECT 'RESTORED_12_VERIFIED' AS restore_status, v_total AS total_inspector_rows,\n",
        "           UTC_TIMESTAMP() AS verified_at_utc;\n",
        "END$$\nDELIMITER ;\n")
    writeLines(sql, output, useBytes = TRUE)
    message("Generated ", output, "; no database connection or installation performed.")
    invisible(output)
}

if (sys.nframe() == 0L) {
    args <- commandArgs(trailingOnly = TRUE)
    if (length(args) != 1L) {
        stop("Usage: Rscript --vanilla tools/validation/build_inspector_restore.R <new ignored output.SQL>")
    }
    build_inspector_restore(args[[1L]])
}
