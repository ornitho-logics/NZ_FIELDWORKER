# Build the static reader, never sourced by the running app.
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
source <- paste(readLines(input, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
body <- commonmark::markdown_html(source, extensions = TRUE)
body <- gsub('(?m)^<p>(<a id="[^"]+"></a>)</p>$', '\\1', body, perl = TRUE)
body <- sub(
  "(?s)(<h2>Contents</h2>\\s*<ul>.*?</ul>)",
  '<nav id="manual-contents" aria-label="Manual contents">\\1</nav>',
  body, perl = TRUE
)
body <- gsub(
  "<table>",
  '<div class="table-scroll" tabindex="0" role="region" aria-label="Supporting table; scroll sideways if needed"><table>',
  body, fixed = TRUE
)
body <- gsub("</table>", "</table></div>", body, fixed = TRUE)
css <- paste(readLines(file.path(folder, "manual.css"), warn = FALSE), collapse = "\n")
js <- paste(readLines(file.path(folder, "manual.js"), warn = FALSE), collapse = "\n")
html <- paste0(
  '<!doctype html>\n<html lang="en-NZ"><head><meta charset="utf-8">',
  '<meta name="viewport" content="width=device-width, initial-scale=1">',
  '<meta name="manual-source-md5" content="', unname(tools::md5sum(input)), '">',
  '<title>BADO Field Manual 2026</title><style>', css, '</style></head><body>',
  '<a class="skip-link" href="#manual-content">Skip to manual</a>',
  '<header class="reader-tools" aria-label="Manual controls">',
  '<div class="reader-tools-inner"><a class="contents-button" href="#manual-contents">Contents</a>',
  '<label for="manual-search">Search manual</label>',
  '<input id="manual-search" type="search" placeholder="e.g. hiding photographs" ',
  'aria-controls="manual-search-results" aria-describedby="manual-search-help" autocomplete="off">',
  '<button id="manual-clear" type="button">Clear</button>',
  '<button id="manual-expand" type="button">Expand all</button>',
  '<button id="manual-collapse" type="button">Collapse all</button>',
  '</div></header><main>',
  '<p id="manual-search-help" class="reader-hint">Search words or field names; choose a result to open its section. ',
  '<a href="manual.md" download>Download Markdown</a></p>',
  '<p id="manual-search-status" role="status" aria-live="polite"></p>',
  '<section id="manual-search-results" aria-label="Search results" hidden></section>',
  '<noscript><p>Search and expand/collapse controls need JavaScript. ',
  'The manual remains readable: open each section using its heading.</p></noscript>',
  '<article id="manual-content" tabindex="-1">', body, '</article></main>',
  '<script>', js, '</script></body></html>'
)
writeLines(html, file.path(folder, "index.html"), useBytes = TRUE)
message("Built static Field Manual reader from the app Markdown source.")
