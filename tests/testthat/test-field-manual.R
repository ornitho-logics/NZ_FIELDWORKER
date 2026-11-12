# These checks never load main/global.R, server.R or database configuration.
manual_root <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
manual_archive <- file.path(manual_root, "docs", "field-manual-archive", "2026-11-08")
manual_file <- function(...) file.path(manual_root, "main", "www", "field-manual", ...)
manual_renderer <- file.path(manual_root, "main", "tools", "render_field_manual.R")

test_that("both manuals are published through one app panel and separate-window link", {
  ui <- paste(readLines(file.path(manual_root, "main", "ui.R")), collapse = "\n")
  expect_match(ui, 'tabName = "field_manual"', fixed = TRUE)
  expect_match(ui, 'src = "field-manual/core-guide.html"', fixed = TRUE)
  expect_match(ui, 'href = "field-manual/core-guide.html"', fixed = TRUE)
  expect_match(ui, "Open Field Manual in a separate window", fixed = TRUE)
  expect_match(ui, 'target = "_blank"', fixed = TRUE)
  expect_silent(parse(file.path(manual_root, "main", "ui.R")))
  expect_length(list.files(file.path(manual_root, "main", "www", "field-manual")), 11L)
  expect_true(file.exists(manual_renderer))
  for (name in c("manual.md", "manual-de.md", "core-guide.md", "core-guide-de.md",
                 "index.html", "index-de.html", "core-guide.html", "core-guide-de.html")) {
    expect_true(file.exists(manual_file(name)))
  }
})

test_that("restored manual preserves disclosure, sections, and expected event table", {
  md <- paste(readLines(manual_file("manual.md"), encoding = "UTF-8"), collapse = "\n")
  html <- paste(readLines(manual_file("index.html"), encoding = "UTF-8"), collapse = "\n")
  expect_gt(regexpr("## Authorship and use of AI", md)[1], regexpr("## Appendix B.", md, fixed = TRUE)[1])
  expect_match(md, "[Authorship and use of AI](#authorship)", fixed = TRUE)
  expect_lt(regexpr("[Appendix B.", md, fixed = TRUE)[1],
            regexpr("[Authorship and use of AI](#authorship)", md, fixed = TRUE)[1])
  expect_match(html, '<a id="authorship"></a>', fixed = TRUE)
  expect_match(md, "remains responsible for the methods and final", fixed = TRUE)
  expect_match(md, "mailto:luke.eberhart@bi.mpg.de", fixed = TRUE)
  expect_match(md, "AI assistance did not replace his scientific judgement", fixed = TRUE)
  expect_match(md, "Luke Eberhart-Hertel developed", fixed = TRUE)
  expect_false(grepl("\\bLuke\\b(?! Eberhart-Hertel)", md, perl = TRUE))
  expect_false(grepl("\\bLuke\\b(?! Eberhart-Hertel)", html, perl = TRUE))
  expect_match(md, "| Chick 1 handled | CAPTURES, 1 |", fixed = TRUE)
  expect_match(html, unname(tools::md5sum(manual_file("manual.md"))), fixed = TRUE)
  expect_equal(lengths(regmatches(html, gregexpr('<a id="(?:section-[0-9]+|appendix-[ab])"></a>', html, perl = TRUE))), 17L)
  expect_equal(lengths(regmatches(html, gregexpr("<table>", html, fixed = TRUE))), 83L)
  expect_match(md, "One origin-linked juvenile resolves chick-stage work", fixed = TRUE)
  expect_match(md, "including a confirmed age-J dead recovery", fixed = TRUE)
  expect_match(md, "An age-C dead recovery does not supply this juvenile-stage evidence.", fixed = TRUE)
  expect_match(md, "Neither juvenile resolution nor presumed loss replaces an independently", fixed = TRUE)
  expect_match(md, "An associated scrape is", fixed = TRUE)
  expect_match(md, "Required for every new H row", fixed = TRUE)
  expect_match(md, "Ring or parent history does not waive this entry.", fixed = TRUE)
  expect_false(grepl("approved blank-ID hiding-photo procedure", md, fixed = TRUE))
  expect_match(md, "first recorded two-egg date as a conservative proxy", fixed = TRUE)
  expect_match(md, "Reset the completion basis to the third/final egg", fixed = TRUE)
  expect_match(md, "task decision and the PDF's **N chicks / N seen** use the same SQL result.", fixed = TRUE)
  expect_match(md, "Distinct known chicks count once", fixed = TRUE)
  expect_match(md, "same ring's earlier capture", fixed = TRUE)
  expect_match(md, "tag X-X M (pair completion)", fixed = TRUE)
  expect_match(md, "Local v1.3.20", fixed = TRUE)
  expect_match(md, "### Read the Nest Map popup", fixed = TRUE)
  expect_match(md, "These parent annotations come from the latest successful To-Do snapshot", fixed = TRUE)
  expect_match(md, "**Hatch timing (days)** follows the PDF's **Est. Hatch** display", fixed = TRUE)
  expect_match(md, "Zero is\nthe hatch-day estimate, not proof of hatching", fixed = TRUE)
  expect_match(html, 'id="manual-search"', fixed = TRUE)
  expect_match(html, 'id="manual-contents"', fixed = TRUE)
  expect_match(html, 'aria-live="polite"', fixed = TRUE)
  expect_false(grepl("<(?:script|link)[^>]+(?:src|href)=\"https?://", html, perl = TRUE))
  expect_false(grepl("/Users/|dbConnect|db_con\\(", html))
})

test_that("manual presents nationwide scope and clear tracking-tag terminology", {
  md <- paste(readLines(manual_file("manual.md"), encoding = "UTF-8"), collapse = "\n")
  expect_match(md, "Protocols for studying breeding Banded Dotterel / Pohowera", fixed = TRUE)
  expect_false(grepl("Cass River · Banded Dotterel", md, fixed = TRUE))
  expect_match(md, "work throughout New Zealand", fixed = TRUE)
  expect_false(grepl("throghout", md, fixed = TRUE))
  expect_false(grepl("preceeding", md, fixed = TRUE))
  expect_match(md, "a **geolocator/tag** is a tracking unit fitted to a bird", fixed = TRUE)
  expect_match(md, "Was there a geolocator/tag action, hatch, failure, or closure?", fixed = TRUE)
  expect_false(grepl("\\bdevices?\\b", md, ignore.case = TRUE, perl = TRUE))
  expect_match(md, "For example, Cass River BADO IDs", fixed = TRUE)
  expect_match(md, "In the current Cass River To-Do implementation", fixed = TRUE)
})

test_that("AI disclosure links public evidence and states its privacy boundaries", {
  md <- paste(readLines(manual_file("manual.md"), encoding = "UTF-8"), collapse = "\n")
  html <- paste(readLines(manual_file("index.html"), encoding = "UTF-8"), collapse = "\n")
  section <- strsplit(md, "## Authorship and use of AI", fixed = TRUE)[[1L]][2L]
  expect_match(section, "If the GitHub links below do not open in the FIELDWORKER app", fixed = TRUE)
  expect_match(section, "**Open Field Manual in a separate window** above the manual", fixed = TRUE)
  expect_match(html, "<strong>Open Field Manual in a separate window</strong> above the manual", fixed = TRUE)
  urls <- c(
    "https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/main/notes/CODEX_USAGE_TRANSPARENCY.md",
    "https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/main/AGENTS.md",
    "https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/main/notes/codex_logs/INDEX.md",
    "https://github.com/ornitho-logics/NZ_FIELDWORKER/tree/main/notes/codex_proposals",
    "https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/main/notes/codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md#mock-data-and-tests",
    "https://github.com/ornitho-logics/NZ_FIELDWORKER/tree/main/notes/codex_proposals/validator_sandbox/inspector_lists_by_table",
    "https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/main/notes/codex_proposals/THREAD4_TODO_MAP_LIST_DEBUG_PLAN.md",
    "https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/1559b166e77d177fe01e278e1b112d912f032b1a/docs/reconstruction/README.md",
    "https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/1559b166e77d177fe01e278e1b112d912f032b1a/tools/reconstruction/fixtures.sql"
  )
  for (url in urls) {
    expect_match(section, url, fixed = TRUE)
    expect_match(html, paste0('href="', url, '"'), fixed = TRUE)
  }
  expect_match(section, "reviewed changes and personally installed updates on the field server", fixed = TRUE)
  expect_match(section, "The initial data-entry checks were developed using invented records", fixed = TRUE)
  expect_match(section, "Later development and troubleshooting also used selected real records", fixed = TRUE)
  expect_match(section, "the complete season's dataset was not\nincluded in prompts", fixed = TRUE)
  expect_match(section, "Larger database checks were carried out locally", fixed = TRUE)
  expect_match(section, "notes and summaries, rather than every conversation or private working file", fixed = TRUE)
  expect_false(grepl("no real data was ever (used|submitted)", section, ignore.case = TRUE))
})

test_that("malformed fragments do not disable the reader controls", {
  js <- paste(readLines(manual_file("manual.js")), collapse = "\n")
  expect_match(js, 'catch (error) { return ""; }', fixed = TRUE)
  expect_match(js, "fragmentId(location.hash)", fixed = TRUE)
  expect_false(grepl("decodeURIComponent(location.hash", js, fixed = TRUE))
})

test_that("hiding-photo guidance distinguishes banding from observation only", {
  md <- paste(readLines(manual_file("manual.md"), encoding = "UTF-8"), collapse = "\n")
  section <- strsplit(md, "## 7. Photographs and media handling", fixed = TRUE)[[1L]][2L]
  section <- strsplit(section, '<a id="section-8"></a>', fixed = TRUE)[[1L]][1L]
  expect_match(md, "siblings have the same colour band", fixed = TRUE)
  expect_false(grepl("\\b(?:wear|wears|wearing)\\s+[^.\\n]*\\bbands?\\b",
                     md, ignore.case = TRUE, perl = TRUE))
  expect_match(section, "If the chick is unbanded when the hiding photograph is taken", fixed = TRUE)
  expect_match(section, "enter only the H resighting; do not add a new capture record.", fixed = TRUE)
  expect_match(section, "actually caught again, record that genuine recapture in CAPTURES", fixed = TRUE)
  expect_match(section, "Its earlier\ncapture must already be saved", fixed = TRUE)
})

test_that("brood absence guidance uses the fixed window and truthful reopening", {
  md <- paste(readLines(manual_file("manual.md"), encoding = "UTF-8"), collapse = "\n")
  section <- strsplit(md, "### Route 3 —", fixed = TRUE)[[1L]][2L]
  section <- strsplit(section, "### One origin-linked juvenile", fixed = TRUE)[[1L]][1L]
  expect_match(section, "21 and 35 days, inclusive", fixed = TRUE)
  expect_match(section, "first possible suppression date is day 36", fixed = TRUE)
  expect_match(section, "fixed window, not a rolling absence period", fixed = TRUE)
  expect_match(section, "discovery-date proxy", fixed = TRUE)
  expect_match(section, "not its egg-stage discovery", fixed = TRUE)
  expect_match(section, "parent capture and\nresighting tasks", fixed = TRUE)
  expect_match(section, "Parent–Nest summary", fixed = TRUE)
  expect_match(section, "late upload\nof a genuine day-25 encounter", fixed = TRUE)
  expect_match(section, "dead chick recovery alone does not count", fixed = TRUE)
  expect_match(section, "required positive-nest notA\nvisit remains separate", fixed = TRUE)
})

test_that("static reader rebuild is deterministic and needs no database", {
  skip_if_not_installed("commonmark")
  folder <- withr::local_tempdir()
  dir.create(file.path(folder, "main", "tools"), recursive = TRUE)
  dir.create(file.path(folder, "main", "www", "field-manual"), recursive = TRUE)
  script <- file.path(folder, "main", "tools", "render_field_manual.R")
  file.copy(manual_renderer, script)
  target <- file.path(folder, "main", "www", "field-manual")
  for (name in c("manual.md", "core-guide.md", "manual-de.md", "core-guide-de.md", "manual.css", "manual.js")) file.copy(manual_file(name), target)
  output <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script)), stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"))
  expect_identical(unname(tools::md5sum(file.path(target, "index.html"))), unname(tools::md5sum(manual_file("index.html"))))
  expect_identical(unname(tools::md5sum(file.path(target, "core-guide.html"))), unname(tools::md5sum(manual_file("core-guide.html"))))
  expect_identical(unname(tools::md5sum(file.path(target, "index-de.html"))), unname(tools::md5sum(manual_file("index-de.html"))))
  expect_identical(unname(tools::md5sum(file.path(target, "core-guide-de.html"))), unname(tools::md5sum(manual_file("core-guide-de.html"))))
})

test_that("English and German readers switch languages without losing the manual kind", {
  for (core in c(TRUE, FALSE)) for (german in c(TRUE, FALSE)) {
    page <- if (core) { if (german) "core-guide-de.html" else "core-guide.html" } else {
      if (german) "index-de.html" else "index.html"
    }
    input <- if (core) { if (german) "core-guide-de.md" else "core-guide.md" } else {
      if (german) "manual-de.md" else "manual.md"
    }
    english <- if (core) "core-guide.html" else "index.html"
    deutsch <- if (core) "core-guide-de.html" else "index-de.html"
    html <- paste(readLines(manual_file(page), encoding = "UTF-8"), collapse = "\n")
    expect_match(html, paste0('<html lang="', if (german) 'de' else 'en-NZ', '">'), fixed = TRUE)
    expect_match(html, paste0('data-language-link href="', english, '" lang="en" hreflang="en-NZ"'), fixed = TRUE)
    expect_match(html, paste0('data-language-link href="', deutsch, '" lang="de" hreflang="de"'), fixed = TRUE)
    expect_match(html, if (german) 'href="core-guide-de.html"' else 'href="core-guide.html"', fixed = TRUE)
    expect_match(html, if (german) 'href="index-de.html"' else 'href="index.html"', fixed = TRUE)
    expect_match(html, paste0('href="', input, '" download'), fixed = TRUE)
    expect_match(html, unname(tools::md5sum(manual_file(input))), fixed = TRUE)
    expect_match(html, 'id="manual-search"', fixed = TRUE)
    expect_match(html, 'id="manual-print"', fixed = TRUE)
    if (german) {
      expect_match(html, "Bei Unklarheiten gilt das englische Original", fixed = TRUE)
      expect_match(html, "Keine passenden Textstellen", fixed = TRUE)
      expect_match(html, 'aria-label="Suchergebnisse"', fixed = TRUE)
      expect_match(html, if (core) 'href="index-de.html#authorship"' else 'href="#authorship"', fixed = TRUE)
    }
  }
})

test_that("German translation sources retain full section and table coverage", {
  for (core in c(TRUE, FALSE)) {
    english <- paste(readLines(manual_file(if (core) "core-guide.md" else "manual.md"), encoding = "UTF-8"), collapse = "\n")
    german <- paste(readLines(manual_file(if (core) "core-guide-de.md" else "manual-de.md"), encoding = "UTF-8"), collapse = "\n")
    anchors <- function(text) regmatches(text, gregexpr('<a id="[^"]+"></a>', text, perl = TRUE))[[1L]]
    table_rows <- function(text) sum(grepl("^\\|", strsplit(text, "\n", fixed = TRUE)[[1L]]))
    literals <- function(text) sort(regmatches(text, gregexpr("`[^`\n]+`", text, perl = TRUE))[[1L]])
    numbers <- function(text) regmatches(text, gregexpr("\\b[0-9]+(?:\\.[0-9]+)*\\b", text, perl = TRUE))[[1L]]
    # The source digest is metadata, not a translated number or field code.
    translated_body <- sub("<!-- English-source-md5: [a-f0-9]{32} -->", "", german)
    expect_identical(anchors(german), anchors(english))
    expect_identical(table_rows(german), table_rows(english))
    expect_identical(literals(translated_body), literals(english))
    expect_identical(numbers(translated_body), numbers(english))
    expect_false(grepl("\\bLuke\\b(?! Eberhart-Hertel)", german, perl = TRUE))
    expect_match(german, "English-source-md5:", fixed = TRUE)
    expect_false(grepl("(?i)\\b(boarisch|bairisch|bavarian)\\b", german, perl = TRUE))
  }
})

test_that("a stale German translation stops the build before any HTML publication", {
  skip_if_not_installed("commonmark")
  folder <- withr::local_tempdir()
  dir.create(file.path(folder, "main", "tools"), recursive = TRUE)
  target <- file.path(folder, "main", "www", "field-manual")
  dir.create(target, recursive = TRUE)
  script <- file.path(folder, "main", "tools", "render_field_manual.R")
  file.copy(manual_renderer, script)
  for (name in c("manual.md", "core-guide.md", "manual-de.md", "core-guide-de.md", "manual.css", "manual.js",
                 "index.html", "core-guide.html", "index-de.html", "core-guide-de.html")) file.copy(manual_file(name), target)
  pages <- file.path(target, c("index.html", "core-guide.html", "index-de.html", "core-guide-de.html"))
  before <- tools::md5sum(pages)
  cat("\nAn invented English revision.\n", file = file.path(target, "manual.md"), append = TRUE)
  output <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script)), stdout = TRUE, stderr = TRUE))
  expect_identical(attr(output, "status"), 1L)
  expect_true(any(grepl("Review the German translation", output, fixed = TRUE)))
  expect_identical(tools::md5sum(pages), before)
})

test_that("both manual readers expose navigation, scoped search, and publication sources", {
  for (core in c(TRUE, FALSE)) {
    page <- if (core) "core-guide.html" else "index.html"
    input <- if (core) "core-guide.md" else "manual.md"
    html <- paste(readLines(manual_file(page), encoding = "UTF-8"), collapse = "\n")
    expect_match(html, '<nav class="reader-switch" aria-label="Choose a manual">', fixed = TRUE)
    expect_match(html, 'href="core-guide.html"', fixed = TRUE)
    expect_match(html, 'href="index.html"', fixed = TRUE)
    expect_match(html, paste0('href="', page, '" aria-current="page"'), fixed = TRUE)
    expect_match(html, paste0('href="', input, '" download'), fixed = TRUE)
    expect_match(html, paste0('href="', page, '" target="_blank" rel="noopener"'), fixed = TRUE)
    expect_match(html, 'id="manual-print"', fixed = TRUE)
    expect_match(html, 'id="manual-contents"', fixed = TRUE)
    expect_match(html, 'id="manual-search"', fixed = TRUE)
    expect_match(html, if (core) 'Search this guide' else 'Search full manual', fixed = TRUE)
    expect_match(html, unname(tools::md5sum(manual_file(input))), fixed = TRUE)
    expect_false(grepl("<(?:script|link)[^>]+(?:src|href)=\"https?://", html, perl = TRUE))
    expect_false(grepl("/Users/|dbConnect|db_con\\(", html))
    expect_identical(grepl('id="manual-expand"', html, fixed = TRUE), !core)
    expect_identical(grepl('id="manual-collapse"', html, fixed = TRUE), !core)
  }
})

test_that("the core guide retains critical rules and links to complete HTML procedures", {
  guide <- paste(readLines(manual_file("core-guide.md"), encoding = "UTF-8"), collapse = "\n")
  full <- paste(readLines(manual_file("manual.md"), encoding = "UTF-8"), collapse = "\n")
  html <- paste(readLines(manual_file("core-guide.html"), encoding = "UTF-8"), collapse = "\n")
  for (text in c("Comments supplement events; they do not replace them.",
                 "NESTS.comments", "bird_inc", "RESIGHTINGS")) {
    expect_match(guide, text, fixed = TRUE)
    expect_match(full, text, fixed = TRUE)
  }
  for (text in c("seven-day and 36-hour", "ages 21–35 inclusive", "22 g or 27 mm",
                 "explicit valid", "known metal ring")) {
    expect_match(guide, text, fixed = TRUE)
  }
  for (id in paste0("core-section-", 1:7)) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
    expect_match(html, paste0('href="#', id, '"'), fixed = TRUE)
  }
  links <- regmatches(guide, gregexpr('manual\\.md(?:#[a-z0-9-]+)?', guide, perl = TRUE))[[1L]]
  expect_gt(length(links), 5L)
  for (link in links) {
    expect_match(html, paste0('href="', sub("manual.md", "index.html", link, fixed = TRUE), '"'), fixed = TRUE)
    if (grepl("#", link, fixed = TRUE)) {
      expect_match(full, paste0('id="', sub(".*#", "", link), '"'), fixed = TRUE)
    }
  }
  expect_match(full, "[Core Team Field Guide](core-guide.md)", fixed = TRUE)
  expect_false(grepl("Draft|Reviewer note|Human-review", guide))
  expect_false(grepl("\\bLuke\\b(?! Eberhart-Hertel)", guide, perl = TRUE))
  for (name in c("README.md", "core-team-field-guide.md", "relocation-checklist.md")) {
    expect_false(file.exists(file.path(manual_root, "docs", "field-manual-review", name)))
  }
  for (path in c("README.md", "CURRENT_SYSTEM.md", "workflow.json", "workflow.schema.json",
                 "rules.json", "parent-association-cases.json", "ADAPTATION.md")) {
    expect_true(file.exists(file.path(manual_root, "docs", "reconstruction", path)))
  }
  expect_true(file.exists(file.path(manual_root, "tools", "reconstruction", "fixtures.sql")))
})

test_that("manual archive members match the preserved manifest and reconstruction reference", {
  skip_if_not_installed("jsonlite")
  manifest <- jsonlite::read_json(file.path(manual_archive, "manifest.json"))
  expect_length(manifest$members, 12L)
  for (member in manifest$members) {
    path <- file.path(manual_root, member$archived_path)
    expect_true(file.exists(path))
    expect_equal(unname(file.info(path)$size), member$bytes)
    expect_identical(unname(tools::md5sum(path)), member$md5)
    restored <- file.path(manual_root, member$original_path)
    expect_true(file.exists(restored))
    expect_identical(unname(tools::md5sum(restored)), member$md5)
  }
  rules <- jsonlite::read_json(file.path(manual_root, "docs", "reconstruction", "rules.json"))
  expect_identical(normalizePath(file.path(manual_root, rules$manual)),
                   normalizePath(manual_file("manual.md")))
  md <- paste(readLines(manual_file("manual.md"), encoding = "UTF-8"), collapse = "\n")
  for (rule in rules$rules) {
    expect_match(md, paste0('id="', rule$manual_anchor, '"'), fixed = TRUE)
  }
})

test_that("MM guidance distinguishes identifiable birds from unbanded chronology", {
  md <- paste(readLines(manual_file("manual.md"), encoding = "UTF-8"), collapse = "\n")
  expect_match(md, "eligible observations from before and after MM can count together", fixed = TRUE)
  expect_match(md, "later MM capture does not erase independently established association", fixed = TRUE)
  expect_match(md, "That different-day X-X evidence is not transferred", fixed = TRUE)
  expect_match(md, "Apply the same rule independently to females", fixed = TRUE)
  expect_match(md, "That same-day confirmation transfers", fixed = TRUE)
  expect_match(md, "without requiring later sightings", fixed = TRUE)
  expect_match(md, "This derived timestamp is not an observed resighting time", fixed = TRUE)
  expect_match(md, "all eligible F identity keys", fixed = TRUE)
  expect_match(md, "A later X-X stays separate", fixed = TRUE)
  expect_false(grepl("a same-day record alone cannot", md, fixed = TRUE))
})
