#TODO

EGGS <- function() {
  o <- DBq(
    "
    SELECT date, nest_id nest, float_angle, float_surface surface
    FROM EGGS
    WHERE float_angle IS NOT NULL
      AND float_surface IS NOT NULL
    "
  )

  if (nrow(o) == 0) {
    return(data.table(
      nest = character(),
      min_days_to_hatch_at_found = numeric(),
      date = as.Date(character()),
      min_pred_hatch_date = as.Date(character())
    ))
  }

  d2h <- hatching_prediction(o, .gampath = hatch_pred_gam)
  d2h <- d2h[,
    .(
      min_days_to_hatch_at_found = min(conf.low, na.rm = TRUE),
      date = max(date, na.rm = TRUE)
    ),
    nest
  ]
  d2h[, min_pred_hatch_date := date + min_days_to_hatch_at_found]

  d2h
}
