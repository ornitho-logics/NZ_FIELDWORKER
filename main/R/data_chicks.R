# TODO

CHICKS <- function(.refdate = input$refdate) {
  if (!exists("input", envir = .GlobalEnv)) {
    .refdate <- as.character(Sys.Date())
    warning("input not found, using ", Sys.Date() |> dQuote(), " as reference.")
  }

  x <- DBq(
    glue(
      "
      SELECT *
      FROM CAPTURES
      WHERE age = 'C'
        AND date <= {shQuote(.refdate)}
      "
    )
  )

  if (nrow(x) == 0) {
    return(data.table())
  }

  if ("nest_id" %in% names(x)) {
    setnames(x, "nest_id", "nest")
  }

  x[, date := lubridate::ymd_hms(paste(date, caught))]
  x[, pk := NULL]
  x <- unique(x)

  setorder(x, nest, date)

  x
}
