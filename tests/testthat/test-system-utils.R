test_that("showTable directs users to the database for a faulty view", {
  env <- new.env(parent = globalenv())
  env$data.table <- data.table::data.table
  env$glue <- glue::glue
  env$glue_collapse <- glue::glue_collapse

  source_app_file(app_file("main", "R", "system_utils.R"), env)

  env$db_get <- function(sql) {
    stop("View 'BROKEN_VIEW' references an invalid table", call. = FALSE)
  }

  result <- env$showTable("BROKEN_VIEW")

  expect_s3_class(result, "data.table")
  expect_named(result, "error")
  expect_identical(
    result$error,
    glue::glue(
      "Database object 'BROKEN_VIEW' is unavailable. ",
      "Open the database interface to inspect or repair it."
    )
  )
})


test_that("dbview_is_updated checks mapped source tables", {
  env <- new.env(parent = globalenv())
  env$glue <- glue::glue

  source_app_file(app_file("main", "R", "system_utils.R"), env)

  env$dbtabs_show_view_sources <- list(
    MAPPED_VIEW = c("TABLE_1", "TABLE_2")
  )
  env$dbtable_is_updated <- function(tab) {
    expect_identical(tab, c("TABLE_1", "TABLE_2"))
    "source-checksum"
  }

  expect_identical(
    env$dbview_is_updated("MAPPED_VIEW"),
    glue::glue("MAPPED_VIEW:source-checksum")
  )
})


test_that("dbview_is_updated keeps unmapped views stable", {
  env <- new.env(parent = globalenv())
  env$glue <- glue::glue

  source_app_file(app_file("main", "R", "system_utils.R"), env)

  env$dbtabs_show_view_sources <- list()
  env$dbtable_is_updated <- function(...) {
    stop("Unmapped views should not be checksummed", call. = FALSE)
  }

  expect_identical(
    env$dbview_is_updated("UNMAPPED_VIEW"),
    glue::glue("UNMAPPED_VIEW:unmapped")
  )
})


test_that("RDS database downloads include only the required archive view", {
  env <- new.env(parent = globalenv())
  env$glue <- glue::glue

  source_app_file(app_file("main", "R", "system_utils.R"), env)

  objects <- data.frame(
    table_name = c(
      "CAPTURES",
      "captures_archive",
      "TODO_LIST",
      "OVERVIEW"
    ),
    table_type = c("BASE TABLE", "VIEW", "VIEW", "VIEW")
  )

  expect_equal(
    env$rds_export_objects(objects),
    data.frame(
      table_name = c("CAPTURES", "captures_archive"),
      export_name = c("CAPTURES", "CAPTURES_ARCHIVE")
    )
  )
})


test_that("RDS database downloads require the archive view", {
  env <- new.env(parent = globalenv())
  env$glue <- glue::glue

  source_app_file(app_file("main", "R", "system_utils.R"), env)

  objects <- data.frame(
    table_name = c("CAPTURES", "TODO_LIST"),
    table_type = c("BASE TABLE", "VIEW")
  )

  expect_error(
    env$rds_export_objects(objects),
    "Required RDS export view(s) unavailable: CAPTURES_ARCHIVE.",
    fixed = TRUE
  )
})


test_that("SQL database downloads use an available dump client", {
  env <- new.env(parent = globalenv())
  source_app_file(app_file("main", "R", "system_utils.R"), env)

  find_program <- function(commands) {
    paths <- rep("", length(commands))
    paths[commands == "mysqldump"] <- "/usr/local/bin/mysqldump"
    stats::setNames(paths, commands)
  }

  expect_identical(
    env$mariadb_dump_command(find_program = find_program),
    "/usr/local/bin/mysqldump"
  )
})


test_that("SQL database downloads keep a completed dump with view warnings", {
  env <- new.env(parent = globalenv())
  env$glue <- glue::glue
  env$group <- "nz_fieldworker"
  env$read.ini <- function(...) {
    list(nz_fieldworker = list(host = "localhost", user = "mock"))
  }
  env$write.ini <- function(x, file) {
    writeLines("[client]", file)
  }
  source_app_file(app_file("main", "R", "system_utils.R"), env)

  fake_dump <- tempfile("fake-mariadb-dump-")
  writeLines(
    c(
      "#!/bin/sh",
      "force=0",
      "for arg in \"$@\"; do",
      "  case \"$arg\" in",
      "    --force) force=1 ;;",
      "    --result-file=*) output=${arg#*=} ;;",
      "  esac",
      "done",
      "[ \"$force\" -eq 1 ] || exit 9",
      "printf '%s\\n' '-- mock SQL backup' > \"$output\"",
      "printf '%s\\n' '-- Dump completed on 2026-09-29 21:00:00' >> \"$output\"",
      "exit 2"
    ),
    fake_dump
  )
  Sys.chmod(fake_dump, "0700")

  output <- tempfile(fileext = ".sql")
  result <- env$mariadb_dump(
    output,
    database = "MOCK_DATABASE",
    dump_command = fake_dump
  )

  expect_identical(result, output)
  expect_gt(file.info(output)$size, 0)
})


test_that("SQL database downloads reject an incomplete dump", {
  env <- new.env(parent = globalenv())
  env$glue <- glue::glue
  env$group <- "nz_fieldworker"
  env$read.ini <- function(...) {
    list(nz_fieldworker = list(host = "localhost", user = "mock"))
  }
  env$write.ini <- function(x, file) {
    writeLines("[client]", file)
  }
  source_app_file(app_file("main", "R", "system_utils.R"), env)

  fake_dump <- tempfile("incomplete-mariadb-dump-")
  writeLines(
    c(
      "#!/bin/sh",
      "for arg in \"$@\"; do",
      "  case \"$arg\" in",
      "    --result-file=*) output=${arg#*=} ;;",
      "  esac",
      "done",
      "printf '%s\\n' '-- partial SQL backup' > \"$output\"",
      "exit 2"
    ),
    fake_dump
  )
  Sys.chmod(fake_dump, "0700")

  expect_error(
    env$mariadb_dump(
      tempfile(fileext = ".sql"),
      database = "MOCK_DATABASE",
      dump_command = fake_dump
    ),
    "failed to create a non-empty SQL backup",
    fixed = TRUE
  )
})
