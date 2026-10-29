# Display guard only; site-specific ID formats are enforced by inspectors.
# Retain the retired literal here solely to reject historical non-links.
.display_has_nest_id <- function(x) {
  value <- toupper(trimws(as.character(x)))
  !is.na(value) & !(value %in% c("", "NA", "NULL", "N/A", "NO_NEST"))
}


.display_nest_id_sql <- function(column) {
  # column is an internal SQL identifier, never user input.
  paste0(
    "(NULLIF(TRIM(", column, "), '') IS NOT NULL AND UPPER(TRIM(",
    column, ")) NOT IN ('NA', 'NULL', 'N/A', 'NO_NEST'))"
  )
}
