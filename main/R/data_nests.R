#TODO

NESTS <- function(.refdate = input$refdate) {
  if (!exists("input", envir = .GlobalEnv)) {
    .refdate <- as.character(Sys.Date())
    warning("input not found, using ", Sys.Date() |> dQuote(), " as reference.")
  }

  x <- DBq(
    glue("SELECT * FROM NESTS WHERE date <= {shQuote(.refdate)}")
  )

  if (nrow(x) == 0) {
    return(data.table())
  }

  x[, pk := NULL]
  x <- unique(x)
  setnames(x, "nest_id", "nest")

  x[, date := lubridate::ymd_hms(paste(date, time_visit))]
  setorder(x, nest, date)

  lhond <- x[!is.na(clutch_size), .(lastHandsonDate = max(date)), by = nest]
  lhond[,
    lastHandsonCheck := difftime(
      as.Date(.refdate),
      as.Date(lastHandsonDate),
      units = "days"
    ) |>
      as.numeric() |>
      round(1)
  ]

  x[, clutch_size := nafill(clutch_size, "locf"), by = nest]
  x[, lastDate := max(date), by = nest]
  x[, collected := FALSE]

  lst <- x[,
    .SD[.N],
    by = nest
  ][,
    .(
      nest,
      last_clutch = clutch_size,
      last_brood = brood_size,
      nest_state,
      collected,
      lastDate
    )
  ]
  lst[,
    lastCheck := difftime(
      as.Date(.refdate),
      as.Date(lastDate),
      units = "days"
    ) |>
      as.numeric() |>
      round(1)
  ]
  lst <- merge(lst, lhond, by = "nest", all.x = TRUE)

  hst <- x[
    !is.na(hatch_state) & str_detect(hatch_state, "[0-9]+(S|CC|C)"),
    .(nest, hatch_state = hatch_state)
  ]
  hst <- hst[,
    .(hatch_state = paste(unique(hatch_state), collapse = ";")),
    by = nest
  ]

  gps <- DBq(
    glue(
      '
      SELECT
        n.gps_id,
        n.gps_point,
        CONCAT_WS(" ", n.date, n.time_visit) datetime_found,
        n.nest_id nest,
        g.lat,
        g.lon
      FROM NESTS n
      JOIN GPS_POINTS g
        ON n.gps_id = g.gps_id
       AND n.gps_point = g.gps_point
      WHERE n.gps_id IS NOT NULL
        AND n.nest_state = "F"
        AND n.date <= {shQuote(.refdate)}
      '
    )
  )
  if (nrow(gps) > 0) {
    gps[, datetime_ := as.POSIXct(datetime_found)]
    gps <- gps[,
      .(lat = mean(lat), lon = mean(lon), datetime_found = min(datetime_found)),
      .(nest)
    ]
  } else {
    gps <- data.table(
      nest = character(),
      lat = numeric(),
      lon = numeric(),
      datetime_found = character()
    )
  }

  trap <- DBq(
    glue(
      "
      SELECT nest_id nest, MAX(date) trap_on_date
      FROM CAPTURES
      WHERE nest_id IS NOT NULL
        AND date <= {shQuote(.refdate)}
      GROUP BY nest_id
      "
    )
  )

  mfc <- DBq(
    glue(
      "
      SELECT DISTINCT
        ring,
        nest_id nest,
        field_sex sex,
        UL, LL, UR, LR
      FROM CAPTURES
      WHERE nest_id IS NOT NULL
        AND date <= {shQuote(.refdate)}
        AND age <> 'C'
      "
    )
  )

  if (nrow(mfc) > 0) {
    mfc[, sex := substr(sex, 1, 1)]
    mfc[, combo := make_combo(.SD)]
    mfc <- mfc[combo != "~/~|~/~"]
    mfc <- dcast(
      mfc,
      nest ~ sex,
      value.var = "combo",
      fun.aggregate = function(x) paste(unique(x), collapse = ",")
    )
    if (!"F" %in% names(mfc)) {
      mfc[, F := NA_character_]
    }
    if (!"M" %in% names(mfc)) {
      mfc[, M := NA_character_]
    }
    setnames(mfc, c("F", "M"), c("F_cap", "M_cap"))
  } else {
    mfc <- data.table(
      nest = character(),
      F_cap = character(),
      M_cap = character()
    )
  }

  d2h <- DBq(
    glue(
      "
      SELECT nest_id nest, date, float_angle, float_surface surface
      FROM EGGS
      WHERE date <= {shQuote(.refdate)}
        AND float_angle IS NOT NULL
        AND float_surface IS NOT NULL
      "
    )
  )

  if (nrow(d2h) > 0) {
    d2h <- hatching_prediction(d2h, .gampath = hatch_pred_gam)
    d2h <- d2h[,
      .(
        min_days_to_hatch_at_found = median(conf.low, na.rm = TRUE),
        date = max(date, na.rm = TRUE)
      ),
      nest
    ]
    d2h[, min_pred_hatch_date := date + min_days_to_hatch_at_found]
    d2h[, date := NULL]
    d2h[,
      min_days_to_hatch := as.numeric(
        min_pred_hatch_date - as.Date(.refdate)
      ) |>
        round(1)
    ]
  } else {
    d2h <- data.table(
      nest = character(),
      min_days_to_hatch_at_found = numeric(),
      min_pred_hatch_date = as.Date(character()),
      min_days_to_hatch = numeric()
    )
  }

  o <- merge(lst, gps, by = "nest", all.x = TRUE)
  o <- merge(o, mfc, by = "nest", all.x = TRUE)
  o <- merge(o, trap, by = "nest", all.x = TRUE)
  o <- merge(o, hst, by = "nest", all.x = TRUE)
  o <- merge(o, d2h, by = "nest", all.x = TRUE)

  o[, let(F_nest = NA_character_, M_nest = NA_character_)]

  o
}
