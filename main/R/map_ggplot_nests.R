#TODO

#' x = NESTS()
#' x = NESTS(DB = "FIELD_2026_BADOatNZ", .refdate = "2026-10-26")[!is.na(lat)]
#' map_nests(x)
map_nests <- function(
  x,
  size = 2.5,
  grandTotal = nrow(x),
  .refdate = input$refdate
) {
  if (!exists('input', envir = .GlobalEnv)) {
    .refdate <- as.character(Sys.Date())
    warning('input not found, using ', Sys.Date() |> dQuote(), ' as reference.')
  }

  g <- map_empty()

  print(g)
}
