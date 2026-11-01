library(testthat)

test_that("capture mark hints exactly match source comments without changing validators", {
  ddl <- paste(readLines(app_file("DATABASE", "main_tables.SQL"), warn = FALSE), collapse = "\n")
  generator <- paste(readLines(app_file("DATABASE", "capture_mark_field_hints_2026-10-31.SQL"), warn = FALSE), collapse = "\n")
  for (name in c("UL_in", "LL_in", "UR_in", "LR_in", "UL", "LL", "UR", "LR")) {
    pattern <- paste0("`", name, "` varchar\\(10\\) DEFAULT NULL COMMENT '((?:[^']|'')*)'")
    found <- regmatches(ddl, regexec(pattern, ddl, perl = TRUE))[[1L]]
    expect_length(found, 2L)
    if (length(found) != 2L) next
    expect_true(nchar(found[[2L]], type = "chars") <= 1024L)
    expect_match(generator, paste0("'", found[[2L]], "'"), fixed = TRUE)
    expect_match(found[[2L]], "no mark; not missing", fixed = TRUE)
    expect_match(found[[2L]], "D:", fixed = TRUE)
    expect_false(grepl('leave blank only if capture_status is "R"', found[[2L]], fixed = TRUE))
  }
  expect_match(generator, "COUNT(*) = 8 AND SUM(is_safe) = 8", fixed = TRUE)
  expect_match(generator, "NO_BACKSLASH_ESCAPES", fixed = TRUE)
  expect_match(generator, ", ALGORITHM=INSTANT, LOCK=NONE;", fixed = TRUE)
  expect_match(generator, "SET SESSION lock_wait_timeout = 30", fixed = TRUE)
  expect_match(generator, "AS rollback_sql", fixed = TRUE)
  expect_match(generator, "IF(all_safe = 1", fixed = TRUE)
  # Remove comments and quoted SQL strings before checking executable commands.
  executable <- gsub("/\\*[\\s\\S]*?\\*/", "", generator, perl = TRUE)
  executable <- gsub("'(?:[^']|'')*'", "''", executable, perl = TRUE)
  expect_false(grepl("\\b(ALTER|CREATE|DROP|UPDATE|INSERT|DELETE|EXECUTE|PREPARE)\\b", executable, perl = TRUE))
})
