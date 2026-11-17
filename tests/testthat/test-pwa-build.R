# Parse only pure build helpers: never load global.R, an app, or database config.
pwa_build_env = function() {
  env = new.env(parent = globalenv())
  names = c("normalize_git_id", "git_output", "git_commit_time", "git_local_head_id",
    "git_worktree_dirty", "git_local_preview_enabled", "read_pwa_build",
    "resolve_git_version", "git_commit_url_for_version", "git_version_label_text")
  for (expr in parse(app_file("main", "global.R"))) {
    if (is.call(expr) && as.character(expr[[1L]]) %in% c("<-", "=") &&
        is.symbol(expr[[2L]]) && as.character(expr[[2L]]) %in% names) eval(expr, env)
  }
  env$git_local_head_id = function(...) stop("Production must not consult Git")
  env
}


test_that("production build identity comes only from the prepared release", {
  env = pwa_build_env()
  directory = withr::local_tempdir()
  dir.create(file.path(directory, "www"))
  withr::local_envvar(c(FIELDWORKER_LOCAL_PREVIEW = NA,
    GITHUB_SHA = strrep("f", 40), FIELDWORKER_GIT_ID = "abcdef1"))
  missing = env$resolve_git_version(directory)
  expect_identical(missing$build_id, "unknown")
  expect_identical(missing$source, "unavailable")
  path = file.path(directory, "www", "build.json")
  jsonlite::write_json(list(id = strrep("a", 64), revision = strrep("b", 40), dirty = FALSE), path, auto_unbox = TRUE)
  version = env$resolve_git_version(directory)
  expect_identical(version$id, strrep("b", 7))
  expect_identical(version$build_id, strrep("a", 64))
  expect_identical(version$source, "deployment:build.json")
  expect_identical(env$git_version_label_text(version), paste("Build", strrep("a", 12)))
  expect_match(env$git_commit_url_for_version(version), strrep("b", 7), fixed = TRUE)
  jsonlite::write_json(list(id = strrep("c", 64), revision = strrep("d", 40)), path, auto_unbox = TRUE)
  expect_identical(version$build_id, strrep("a", 64))
  expect_identical(env$resolve_git_version(directory)$build_id, strrep("c", 64))
})


test_that("malformed deployment stamps do not acquire a misleading fallback", {
  env = pwa_build_env()
  directory = withr::local_tempdir()
  dir.create(file.path(directory, "www"))
  for (value in c("not JSON", '{"id":"short"}', '{"id":["bad","bad"]}', '{"id":null}')) {
    writeLines(value, file.path(directory, "www", "build.json"))
    expect_identical(env$resolve_git_version(directory, local_preview = FALSE)$build_id, "unknown")
  }
})


test_that("local preview remains explicit and keeps its dirty marker", {
  env = pwa_build_env()
  env$git_local_head_id = function(...) "abcdef1"
  env$git_commit_time = function(...) NULL
  env$git_worktree_dirty = function(...) TRUE
  version = env$resolve_git_version(tempdir(), local_preview = TRUE)
  expect_true(version$local)
  expect_true(version$dirty)
  expect_identical(env$git_version_label_text(version), "local-abcdef1")
})


test_that("the process build is displayed without network polling", {
  env = pwa_build_env()
  env$git_version = list(id = "abcdef1", build_id = strrep("a", 64), source = "deployment:build.json", local = FALSE)
  env$renderUI = shiny::renderUI
  env$tags = shiny::tags
  server = parse(app_file("main", "server.R"))[[1L]]
  render = Filter(function(expr) is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
    identical(expr[[2L]], quote(output$git_version_label)), as.list(server[[3L]])[-1L])
  expect_length(render, 1L)
  env$render = render[[1L]]
  wrapper = function(input, output, session) eval(render, environment())
  environment(wrapper) = env
  shiny::testServer(wrapper, {
    expect_match(output$git_version_label$html, paste("Build", strrep("a", 12)), fixed = TRUE)
    expect_match(output$git_version_label$html, "abcdef1", fixed = TRUE)
  })
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
