# Parse only pure build helpers: never load global.R or database config.
pwa_build_env <- function() {
  env <- new.env(parent = globalenv())
  names <- c("read_pwa_build", "resolve_pwa_build_id")
  for (expr in parse(app_file("main", "global.R"))) {
    if (is.call(expr) && as.character(expr[[1L]]) %in% c("<-", "=") &&
        is.symbol(expr[[2L]]) && as.character(expr[[2L]]) %in% names) eval(expr, env)
  }
  env
}


test_that("installed-app build identity uses the prepared release stamp", {
  env <- pwa_build_env()
  directory <- withr::local_tempdir()
  dir.create(file.path(directory, "www"))
  expect_identical(env$resolve_pwa_build_id(directory), "unknown")
  path <- file.path(directory, "www", "build.json")
  jsonlite::write_json(list(id = strrep("a", 64)), path, auto_unbox = TRUE)
  build_id <- env$resolve_pwa_build_id(directory)
  expect_identical(build_id, strrep("a", 64))
  jsonlite::write_json(list(id = strrep("c", 64)), path, auto_unbox = TRUE)
  expect_identical(build_id, strrep("a", 64))
  expect_identical(env$resolve_pwa_build_id(directory), strrep("c", 64))
})


test_that("malformed deployment stamps do not acquire a misleading fallback", {
  env <- pwa_build_env()
  directory <- withr::local_tempdir()
  dir.create(file.path(directory, "www"))
  for (value in c("not JSON", '{"id":"short"}', '{"id":["bad","bad"]}', '{"id":null}')) {
    writeLines(value, file.path(directory, "www", "build.json"))
    expect_identical(env$resolve_pwa_build_id(directory), "unknown")
  }
})


test_that("the sidebar uses a simple release version without test counts or Git labels", {
  ui = paste(readLines(app_file("main", "ui.R")), collapse = "\n")
  server = paste(readLines(app_file("main", "server.R")), collapse = "\n")
  expect_match(ui, 'paste("Version", app_version)', fixed = TRUE)
  expect_false(grepl("git_version_label", ui, fixed = TRUE))
  expect_false(grepl("git_version_label", server, fixed = TRUE))
  expect_false(grepl("test-results.csv", ui, fixed = TRUE))
  expect_false(grepl("app_test_status", ui, fixed = TRUE))
  # The hidden process stamp still supports installed-app update detection.
  expect_match(ui, 'name = "fieldworker-build", content = pwa_build_id', fixed = TRUE)
})


test_that("installed app identity and scope remain stable", {
  manifest = jsonlite::read_json(app_file("main", "www", "manifest.webmanifest"))
  expect_identical(manifest$id, "./")
  expect_identical(manifest$scope, "./")
  expect_identical(manifest$start_url, "./")
  expect_identical(manifest$display, "standalone")
  for (icon in manifest$icons) expect_true(file.exists(app_file("main", "www", icon$src)))
})


test_that("install guidance and update controls render without loading the app", {
  sections = list()
  visit = function(expr) {
    if (!is.call(expr)) return()
    if (identical(expr[[1L]], quote(tags$section))) {
      sections[[length(sections) + 1L]] <<- expr
      return()
    }
    for (child in as.list(expr)[-1L]) visit(child)
  }
  for (expr in parse(app_file("main", "ui.R"))) visit(expr)
  expect_length(sections, 2L)
  env = list2env(list(tags = shiny::tags, icon = shiny::icon))
  html = htmltools::renderTags(htmltools::tagList(lapply(sections, eval, envir = env)))$html
  for (id in c("install_mobile", "install_help", "pwa_check_updates", "pwa_update", "pwa_update_later")) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
  expect_match(html, "Update and reload", fixed = TRUE)
  expect_match(html, "Live pages and downloads need a connection.", fixed = TRUE)
  expect_match(html, 'aria-live="polite"', fixed = TRUE)
})
