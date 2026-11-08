# Build both static readers in English and German; never sourced by the app.
# From the repository root: Rscript --vanilla main/tools/render_field_manual.R
# To import a reviewed draft, pass its path as the sole argument. Only import
# material approved for app publication: everything under www is browser-readable.

script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
root <- normalizePath(file.path(dirname(script), "..", ".."), mustWork = TRUE)
folder <- file.path(root, "main", "www", "field-manual")
input <- file.path(folder, "manual.md")
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) <= 1L)
if (length(args)) {
  reviewed <- normalizePath(args[[1]], mustWork = TRUE)
  if (reviewed != normalizePath(input, mustWork = FALSE)) {
    stopifnot(file.copy(reviewed, input, overwrite = TRUE))
  }
}

# commonmark is already a Shiny dependency; no runtime renderer or CDN is needed.
stopifnot(requireNamespace("commonmark", quietly = TRUE))
css <- paste(readLines(file.path(folder, "manual.css"), warn = FALSE), collapse = "\n")
js <- paste(readLines(file.path(folder, "manual.js"), warn = FALSE), collapse = "\n")

# Check every translation before writing any HTML. English edits require a
# corresponding translation review, not a silent stale-language publication.
for (name in c("manual", "core-guide")) {
  translated <- file.path(folder, paste0(name, "-de.md"))
  text <- paste(readLines(translated, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  recorded <- regmatches(text, regexpr("(?<=English-source-md5: )[a-f0-9]{32}", text, perl = TRUE))
  actual <- unname(tools::md5sum(file.path(folder, paste0(name, ".md"))))
  if (length(recorded) != 1L || !identical(recorded, actual)) {
    stop("Review the German translation against the current English source: ", translated)
  }
}

render_manual <- function(input_name, output_name, title, core = FALSE, german = FALSE) {
  input_path <- file.path(folder, input_name)
  core_page <- if (german) "core-guide-de.html" else "core-guide.html"
  full_page <- if (german) "index-de.html" else "index.html"
  english_page <- if (core) "core-guide.html" else "index.html"
  german_page <- if (core) "core-guide-de.html" else "index-de.html"
  labels <- if (german) {
    list(choose = "Handbuch auswählen", core = "Kurzleitfaden fürs Kernteam",
         full = "Vollständiges Protokollhandbuch", contents = "Inhalt",
         search = if (core) "Kurzleitfaden durchsuchen" else "Handbuch durchsuchen",
         placeholder = "z. B. Versteckfoto", clear = "Leeren", expand = "Alle öffnen",
         collapse = "Alle schließen", print = "Drucken", download = "Markdown herunterladen",
         standalone = "Handbuch in einem separaten Fenster öffnen",
         hint = if (core) "Die Suche gilt für diesen Kurzleitfaden. Alle Anforderungen und Ausnahmen stehen im vollständigen Protokollhandbuch. " else "Die Suche gilt für dieses vollständige Handbuch. Ein Suchergebnis öffnet den betreffenden Abschnitt. ")
  } else {
    list(choose = "Choose a manual", core = "Core Team Field Guide",
         full = "Full Protocol Manual", contents = "Contents",
         search = if (core) "Search this guide" else "Search full manual",
         placeholder = "e.g. hiding photographs", clear = "Clear", expand = "Expand all",
         collapse = "Collapse all", print = "Print", download = "Download Markdown",
         standalone = "Open Field Manual in a separate window",
         hint = if (core) "Search applies to this short guide. Switch to the Full Protocol Manual for all requirements and exceptions. " else "Search applies to this full manual. Choose a search result to open its section. ")
  }
  source_text <- paste(readLines(input_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  body <- commonmark::markdown_html(source_text, extensions = TRUE)
  body <- gsub('(?m)^<p>(<a id="[^"]+"></a>)</p>$', '\\1', body, perl = TRUE)
  # Markdown sources link to each other for GitHub; browser readers link to HTML.
  body <- gsub('href="manual(?:-de)?\\.md(?=[#"])', paste0('href="', full_page), body, perl = TRUE)
  body <- gsub('href="core-guide(?:-de)?\\.md(?=[#"])', paste0('href="', core_page), body, perl = TRUE)
  body <- sub(
    "(?s)(<h2>(?:Contents|Inhalt|Inhaltsverzeichnis)</h2>\\s*<ul>.*?</ul>)",
    paste0('<nav id="manual-contents" aria-label="', if (german) 'Handbuchinhalt' else 'Manual contents', '">\\1</nav>'),
    body, perl = TRUE
  )
  body <- gsub(
    "<table>",
    paste0('<div class="table-scroll" tabindex="0" role="region" aria-label="', if (german) 'Begleittabelle; bei Bedarf seitlich scrollen' else 'Supporting table; scroll sideways if needed', '"><table>'),
    body, fixed = TRUE
  )
  body <- gsub("</table>", "</table></div>", body, fixed = TRUE)
  html <- paste0(
    '<!doctype html>\n<html lang="', if (german) 'de' else 'en-NZ', '"><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    '<meta name="manual-source-md5" content="', unname(tools::md5sum(input_path)), '">',
    '<meta name="manual-reference-md5" content="', unname(tools::md5sum(file.path(folder, if (core) "core-guide.md" else "manual.md"))), '">',
    '<title>', title, '</title><style>', css, '</style></head><body>',
    '<a class="skip-link" href="#manual-content">', if (german) 'Zum Handbuch springen' else 'Skip to manual', '</a>',
    '<header class="reader-tools" aria-label="', if (german) 'Handbuchsteuerung' else 'Manual controls', '">',
    '<nav class="reader-switch" aria-label="', labels$choose, '">',
    '<a href="', core_page, '"', if (core) ' aria-current="page"' else '', '>', labels$core, '</a>',
    '<a href="', full_page, '"', if (!core) ' aria-current="page"' else '', '>', labels$full, '</a></nav>',
    '<nav class="language-switch" aria-label="', if (german) 'Sprache' else 'Language', '">',
    '<a data-language-link href="', english_page, '" lang="en" hreflang="en-NZ"', if (!german) ' aria-current="page"' else '', '>English</a>',
    '<a data-language-link href="', german_page, '" lang="de" hreflang="de"', if (german) ' aria-current="page"' else '', '>Deutsch</a></nav>',
    '<div class="reader-tools-inner"><a class="contents-button" href="#manual-contents">', labels$contents, '</a>',
    '<label for="manual-search">', labels$search, '</label>',
    '<input id="manual-search" type="search" placeholder="', labels$placeholder, '" ',
    'aria-controls="manual-search-results" aria-describedby="manual-search-help" autocomplete="off">',
    '<button id="manual-clear" type="button">', labels$clear, '</button>',
    if (!core) paste0('<button id="manual-expand" type="button">', labels$expand, '</button>',
                     '<button id="manual-collapse" type="button">', labels$collapse, '</button>') else '',
    '<button id="manual-print" type="button">', labels$print, '</button>',
    '</div></header><main>',
    if (german) '<p class="translation-note">Deutsche Übersetzung: Bei Unklarheiten gilt das englische Original. Bitte die Übersetzung im Team gegenlesen.</p>' else '',
    '<p id="manual-search-help" class="reader-hint">', labels$hint,
    '<a href="', input_name, '" download>', labels$download, '</a> · ',
    '<a href="', output_name, '" target="_blank" rel="noopener">', labels$standalone, '</a></p>',
    '<p id="manual-search-status" role="status" aria-live="polite"></p>',
    '<section id="manual-search-results" aria-label="', if (german) 'Suchergebnisse' else 'Search results', '" hidden></section>',
    '<noscript><p>', if (german) 'Suche und Druckschaltfläche benötigen JavaScript. Beide Handbücher bleiben lesbar; zum Drucken die Browserfunktion verwenden und geschlossene Abschnitte über ihre Überschrift öffnen.' else 'Search and print controls need JavaScript. Both manuals remain readable; use your browser to print, and open any collapsed section using its heading.', '</p></noscript>',
    '<article id="manual-content" tabindex="-1">', body, '</article></main>',
    '<script>', js, '</script></body></html>'
  )
  writeLines(html, file.path(folder, output_name), useBytes = TRUE)
}

render_manual("manual.md", "index.html", "BADO Field Manual 2026 — Full Protocol Manual")
render_manual("core-guide.md", "core-guide.html", "BADO Field Manual 2026 — Core Team Field Guide", core = TRUE)
render_manual("manual-de.md", "index-de.html", "BADO Field Manual 2026 — Vollständiges Protokollhandbuch", german = TRUE)
render_manual("core-guide-de.md", "core-guide-de.html", "BADO Field Manual 2026 — Kurzleitfaden fürs Kernteam", core = TRUE, german = TRUE)
message("Built both static Field Manual readers in English and German.")
