# Optional synthetic PDF only; bootstrap.py passes its owned socket and marker.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 4L)
root <- normalizePath(args[[1L]])
socket <- args[[2L]]
output <- args[[3L]]
marker <- jsonlite::read_json(args[[4L]])
stopifnot(grepl("^(/private)?/tmp/fw-reconstruct-[a-f0-9]+[.]sock$", socket), file.exists(socket),
          identical(marker$socket, socket), identical(marker$purpose, "synthetic_reconstruction"))
suppressPackageStartupMessages({
  library(DBI); library(RMariaDB); library(data.table); library(glue)
  library(ggplot2); library(sf); library(patchwork); library(ggrepel)
  library(stringr); library(htmltools); library(quarto)
})
con <- DBI::dbConnect(RMariaDB::MariaDB(), user = "root", host = "localhost", unix.socket = socket, dbname = "FIELD_2026_BADOatNZ")
stopifnot(identical(DBI::dbGetQuery(con, "SELECT token FROM reconstruction_owner")$token, marker$token))
DBq <- function(sql, ...) as.data.table(DBI::dbGetQuery(con, sql))
get_reference_date <- function() as.Date(DBI::dbGetQuery(con, "SELECT value FROM settings WHERE variable='reference_date'")$value[[1L]])
git_version <- list(id="SYNTHETIC-9e010e5", local=TRUE, dirty=FALSE)
preferred_timezone <- "Pacific/Auckland"
for (file in c("display_nest_ids.R", "pdf_todo_map.R", "pdf_todo.R")) {
  sys.source(file.path(root, "main", "R", file), envir = .GlobalEnv)
}
reference_prepare <- todo_pdf_prepare
todo_pdf_prepare <- function(...) {
  pdf <- reference_prepare(...)
  pdf$title <- paste("SYNTHETIC TEST -", pdf$title)
  pdf
}
# Test I/O adapter: retain actual table/PDF and map-panel implementations,
# supply invented landmarks/backgrounds and never invoke satellite downloads.
# This is not the production map-save integration acceptance item.
todo_pdf_map_save <- function(file, todo, spatial_objects, chick_captures, nests_latest) {
  plots <- .todo_pdf_map_prepare_plots(spatial_objects)
  nests <- .todo_pdf_map_prepare_nests(todo, chick_captures, nests_latest)
  gate <- st_as_sf(data.frame(label="synthetic gate", lon=174.002, lat=-41.005),
                   coords=c("lon","lat"), crs=4326) |> st_transform(2193)
  specs <- setNames(lapply(c("A", "B", "C"), function(id) list(
    extent=.todo_pdf_map_panel_extent(plots[plots$plot_name == id, ], nests[nests$plot_name == id, ], target_ratio=1.55),
    rotation_deg=0, local_image_rotation=FALSE,
    imagery_file=file.path(tempdir(), "no-synthetic-imagery-file.png")
  )), c("A", "B", "C"))
  panels <- lapply(names(specs), .todo_pdf_map_panel, plots=plots, nests=nests,
                   gate=gate, gate_plot="C", panel_specs=specs)
  map <- patchwork::wrap_plots(patchwork::wrap_plots(panels, nrow=1),
                               .todo_pdf_map_legend(), ncol=1, heights=c(1,.045))
  .todo_pdf_map_save_rotated(map, file)
}
# Existing renderer expects an R expression containing named WKT plot strings.
polygons <- vapply(seq_len(3), function(i) {
  x <- 173.95 + (i - 1L) * 0.02
  sprintf("POLYGON((%f -41.01,%f -41.01,%f -40.99,%f -40.99,%f -41.01))", x, x+.02, x+.02, x, x)
}, character(1))
names(polygons) <- c("A", "B", "C")
spatial <- data.table(variable = "study_area", value = paste(deparse(as.list(polygons)), collapse=""))
setwd(file.path(root, "main"))
tryCatch({
  todo_pdf_save(file = output, spatial_objects = spatial)
  stopifnot(file.exists(output), file.info(output)$size > 0)
  cat("PASS: synthetic PDF rendered; visual review still required.\n")
}, finally = DBI::dbDisconnect(con))
