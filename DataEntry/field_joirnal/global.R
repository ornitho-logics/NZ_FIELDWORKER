#' shiny::runApp("./DataEntry/field_joirnal", launch.browser = TRUE)

library(shiny)

table_name <- "field_joirnal"
group <- "nz_fieldworker"
journal_photo_limit <- 500000L

journal_today <- function() {
  as.Date(format(Sys.time(), tz = "Pacific/Auckland", format = "%Y-%m-%d"))
}

# Read dimensions before decoding, so a forged upload cannot request an
# enormous image allocation. Browser output may use baseline or progressive JPEG.
journal_jpeg_dimensions <- function(photo) {
  bytes <- as.integer(photo)
  if (length(bytes) < 4L || !identical(bytes[1:2], c(255L, 216L))) {
    stop("Choose a JPEG photo prepared by the form.", call. = FALSE)
  }
  index <- 3L
  while (index + 3L <= length(bytes)) {
    if (bytes[index] != 255L) break
    while (index <= length(bytes) && bytes[index] == 255L) index <- index + 1L
    if (index + 2L > length(bytes)) break
    marker <- bytes[index]
    if (marker %in% c(0L, 216L, 217L, 218L)) break
    size <- bytes[index + 1L] * 256L + bytes[index + 2L]
    if (size < 2L || index + size > length(bytes)) break
    if (marker %in% c(192L, 194L) && size >= 8L) {
      return(c(height = bytes[index + 4L] * 256L + bytes[index + 5L],
               width = bytes[index + 6L] * 256L + bytes[index + 7L]))
    }
    index <- index + size + 1L
  }
  stop("The photo is not a supported JPEG image.", call. = FALSE)
}

journal_photo <- function(upload) {
  if (is.null(upload) || identical(upload$state, "none")) return(NULL)
  if (!identical(upload$state, "ready")) {
    stop("Wait for the photo preview, or choose another photo before saving.", call. = FALSE)
  }
  encoded <- upload$data
  prefix <- "data:image/jpeg;base64,"
  if (!is.character(encoded) || length(encoded) != 1L || is.na(encoded) ||
      !startsWith(encoded, prefix)) {
    stop("The photo must be a JPEG image.", call. = FALSE)
  }
  if (nchar(encoded, type = "bytes") > nchar(prefix) + 4L * ceiling(journal_photo_limit / 3L)) {
    stop("The prepared photo is too large. Choose the photo again.", call. = FALSE)
  }
  photo <- jsonlite::base64_dec(substring(encoded, nchar(prefix) + 1L))
  if (length(photo) > journal_photo_limit) {
    stop("The prepared photo is too large. Choose the photo again.", call. = FALSE)
  }
  dimensions <- journal_jpeg_dimensions(photo)
  if (any(dimensions < 1L | dimensions > 1600L)) {
    stop("The photo must be resized to at most 1,600 pixels before saving.", call. = FALSE)
  }
  tryCatch(
    withCallingHandlers(jpeg::readJPEG(photo, native = TRUE),
                        warning = function(w) stop("Invalid JPEG image.", call. = FALSE)),
    error = function(e) stop("The photo could not be read. Choose the photo again.", call. = FALSE)
  )
  photo
}

journal_save <- function(date, observer, entry, photo = NULL) {
  con <- DataEntry::db_con(group = group)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbExecute(
    con,
    paste("INSERT INTO `field_joirnal` (`date`, `observer`, `entry`, `photo`)",
          "VALUES (?, ?, ?, ?)"),
    params = list(as.character(date), observer, entry, list(photo))
  )
  invisible(TRUE)
}
