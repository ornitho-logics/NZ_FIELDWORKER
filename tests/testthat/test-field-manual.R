# These checks never load main/global.R, server.R or database configuration.
manual_root <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
manual_file <- function(...) file.path(manual_root, "main", "www", "field-manual", ...)

test_that("Field Manual is wired directly below Nest Map with a static reader", {
  ui <- paste(readLines(file.path(manual_root, "main", "ui.R")), collapse = "\n")
  expect_match(ui, 'menuItem("Field Manual", tabName = "field_manual"', fixed = TRUE)
  expect_lt(regexpr('"Nest Map"', ui)[1], regexpr('"Field Manual"', ui)[1])
  expect_match(ui, 'id = "field_manual_reader"', fixed = TRUE)
  expect_match(ui, 'src = "field-manual/index.html"', fixed = TRUE)
  expect_match(ui, 'title = "BADO Field Manual', fixed = TRUE)
})

test_that("app manual preserves disclosure, sections, and expected event table", {
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
  file.copy(file.path(manual_root, "main", "tools", "render_field_manual.R"), script)
  target <- file.path(folder, "main", "www", "field-manual")
  for (name in c("manual.md", "manual.css", "manual.js")) file.copy(manual_file(name), target)
  output <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script)), stdout = TRUE, stderr = TRUE)
  expect_null(attr(output, "status"))
  expect_identical(unname(tools::md5sum(file.path(target, "index.html"))), unname(tools::md5sum(manual_file("index.html"))))
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
