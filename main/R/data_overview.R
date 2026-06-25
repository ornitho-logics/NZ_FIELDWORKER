OVERVIEW <- function() {
  x <- db_get(
    'select distinct ring,date,study_year year FROM CAPTURES_ARCHIVE where site_code = "CR" and age = "A"'
  )

  x <- x[,
    .(n = .N),
    by = .(
      year,
      date_std = as.IDate(sprintf("2000-%s", format(date, "%m-%d")))
    )
  ]

  x[,
    year := factor(year, levels = sort(unique(year), decreasing = TRUE))
  ]

  x
}
