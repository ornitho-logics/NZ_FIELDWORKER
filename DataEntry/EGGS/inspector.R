list(
  # Required egg fields.
  is.na_validator(x[, .(species, observer, date, time_visit, nest_id, egg_id)], reason = "Required.") |> try_validator(nam = "val1"),

  # Check the observer is active on the egg date.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    src <- as.data.table(db_get("SELECT observer, start, stop FROM OBSERVERS"))
    src[, let(start, (start |> as.Date()))]
    src[, let(stop, (stop |> as.Date()))]
    dat[, let(date, (date |> as.Date()))]
    m <- merge(dat[, .(rowid, observer, date)], src, by = "observer", all.x = TRUE)
    bad_idx <- m[is.na(start) | is.na(stop) | is.na(date) | date < start | date > stop, rowid]
    if (length(bad_idx) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      data.table(rowid = bad_idx, variable = "observer", reason = "Observer missing or inactive on egg date.")
    }
  } |> try_validator(nam = "val2"),

  # One egg-check event requires one date.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    to_mins <- function(v) {
      txt <- (v |> as.character() |> str_trim())
      conv <- strptime(txt, format = "%H:%M")
      res <- rep(NA_integer_, length(txt))
      ok <- !is.na(conv)
      res[ok] <- (format(conv[ok], "%H") |> as.integer()) * 60 + (format(conv[ok], "%M") |> as.integer())
      res
    }
    clean_clock_key <- function(v) {
      txt <- (v |> as.character() |> str_trim())
      res <- rep(NA_character_, length(txt))
      parsed_hm <- strptime(txt, format = "%H:%M")
      ok_hm <- !is.na(parsed_hm)
      res[ok_hm] <- format(parsed_hm[ok_hm], "%H:%M")
      parsed_hms <- strptime(txt, format = "%H:%M:%S")
      ok_hms <- is.na(res) & !is.na(parsed_hms)
      res[ok_hms] <- format(parsed_hms[ok_hms], "%H:%M")
      res
    }
    current <- dat[, .(rowid,
      nest_key = (nest_id |> as.character() |> str_trim()), observer_key = (observer |> as.character() |> str_trim()),
      date_key = (date |> as.Date()), time_key = clean_clock_key(time_visit), time_min = to_mins(time_visit)
    )]
    current <- current[!is.na(nest_key) & nzchar(nest_key) & !is.na(observer_key) & nzchar(observer_key)]
    time_date_clash <- current[!is.na(time_key) & nzchar(time_key), .(date_n = uniqueN(date_key[!is.na(date_key)])),
      by = .(nest_key, observer_key, time_key)
    ][date_n > 1]
    date_res <- if (nrow(time_date_clash) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      merge(current[, .(rowid, nest_key, observer_key, time_key)], time_date_clash[
        ,
        .(nest_key, observer_key, time_key)
      ], by = c("nest_key", "observer_key", "time_key"))[
        ,
        .(rowid, variable = "date", reason = "One egg-check event requires one date.")
      ]
    }
    date_res
  } |> try_validator(nam = "val3"),

  # Same nest/date: time_visit must be within 5 minutes.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    to_mins <- function(v) {
      txt <- (v |> as.character() |> str_trim())
      conv <- strptime(txt, format = "%H:%M")
      res <- rep(NA_integer_, length(txt))
      ok <- !is.na(conv)
      res[ok] <- (format(conv[ok], "%H") |> as.integer()) * 60 + (format(conv[ok], "%M") |> as.integer())
      res
    }
    clean_clock_key <- function(v) {
      txt <- (v |> as.character() |> str_trim())
      res <- rep(NA_character_, length(txt))
      parsed_hm <- strptime(txt, format = "%H:%M")
      ok_hm <- !is.na(parsed_hm)
      res[ok_hm] <- format(parsed_hm[ok_hm], "%H:%M")
      parsed_hms <- strptime(txt, format = "%H:%M:%S")
      ok_hms <- is.na(res) & !is.na(parsed_hms)
      res[ok_hms] <- format(parsed_hms[ok_hms], "%H:%M")
      res
    }
    current <- dat[, .(rowid,
      nest_key = (nest_id |> as.character() |> str_trim()), observer_key = (observer |> as.character() |> str_trim()),
      date_key = (date |> as.Date()), time_key = clean_clock_key(time_visit), time_min = to_mins(time_visit)
    )]
    current <- current[!is.na(nest_key) & nzchar(nest_key) & !is.na(observer_key) & nzchar(observer_key)]
    bad_time_ids <- current[!is.na(date_key), .(time_span = if (all(is.na(time_min))) {
      NA_real_
    } else {
      max(time_min, na.rm = TRUE) - min(time_min, na.rm = TRUE)
    }), by = .(nest_key, observer_key, date_key)][!is.na(time_span) & time_span > 5]
    time_res <- if (nrow(bad_time_ids) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      merge(current[, .(rowid, nest_key, observer_key, date_key)], bad_time_ids[, .(
        nest_key,
        observer_key, date_key
      )], by = c("nest_key", "observer_key", "date_key"))[, .(rowid,
        variable = "time_visit", reason = "Same nest/date: time_visit must be within 5 minutes."
      )]
    }
    time_res
  } |> try_validator(nam = "val4"),

  # Check the field-season dates.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    txt <- (dat$date |> as.character() |> str_trim())
    conv <- (txt |> as.Date(format = "%Y-%m-%d"))
    bad_idx <- which(!is.na(dat$date) & nzchar(txt) & !is.na(conv) & (conv < ("2026-07-01" |> as.Date()) |
      conv > ("2027-07-31" |> as.Date())))
    if (length(bad_idx) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      data.table(rowid = dat$rowid[bad_idx], variable = "date", reason = "Use a date in the 2026–2027 season.")
    }
  } |> try_validator(nam = "val5"),

  # Require a positive nest identifier.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    cr_pat <- "^[ABC](0[1-9]|[1-9][0-9])(0[1-9]|[1-9][0-9])$"
    legacy_pat <- "^(BA|WR|SN|BF)(0[1-9]|[1-9][0-9])(0[1-9]|[1-9][0-9])$"
    txt <- (dat$nest_id |> as.character() |> str_trim())
    bad_idx <- which(!is.na(dat$nest_id) & nzchar(txt) & ((txt |> str_detect("^-")) %in% TRUE | !((txt |> str_detect(cr_pat)) %in%
      TRUE | (txt |> str_detect(legacy_pat)) %in% TRUE)))
    if (length(bad_idx) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      data.table(rowid = dat$rowid[bad_idx], variable = "nest_id", reason = "EGGS requires a positive nest_id; use CAPTURES or RESIGHTINGS for negative broods.")
    }
  } |> try_validator(nam = "val6"),

  # float_surface must be blank when float_location is bottom.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    none <- data.table(rowid = integer(), variable = character(), reason = character())
    res <- rbindlist(lapply(seq_len(nrow(dat)), function(i) {
      rec <- dat[i]
      errs <- list()
      loc <- (rec$float_location |> as.character() |> str_trim())
      if (is.na(rec$float_location) || !nzchar(loc)) {
        loc <- NA_character_
      }
      surface <- (rec$float_surface |> as.character() |> as.numeric())
      if (identical(loc, "bottom")) {
        if (!is.na(surface)) {
          return(data.table(rowid = rec$rowid, variable = "float_surface", reason = "float_surface must be blank when float_location is bottom."))
        }
      }
      if (length(errs) == 0) {
        none
      } else {
        rbindlist(errs, use.names = TRUE, fill = TRUE)
      }
    }), use.names = TRUE, fill = TRUE)
    if (nrow(res) == 0) {
      none
    } else {
      unique(res)
    }
  } |> try_validator(nam = "val7"),

  # float_surface must be blank when float_location is suspended.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    none <- data.table(rowid = integer(), variable = character(), reason = character())
    res <- rbindlist(lapply(seq_len(nrow(dat)), function(i) {
      rec <- dat[i]
      errs <- list()
      loc <- (rec$float_location |> as.character() |> str_trim())
      if (is.na(rec$float_location) || !nzchar(loc)) {
        loc <- NA_character_
      }
      surface <- (rec$float_surface |> as.character() |> as.numeric())
      if (identical(loc, "suspended")) {
        if (!is.na(surface)) {
          return(data.table(rowid = rec$rowid, variable = "float_surface", reason = "float_surface must be blank when float_location is suspended."))
        }
      }
      if (length(errs) == 0) {
        none
      } else {
        rbindlist(errs, use.names = TRUE, fill = TRUE)
      }
    }), use.names = TRUE, fill = TRUE)
    if (nrow(res) == 0) {
      none
    } else {
      unique(res)
    }
  } |> try_validator(nam = "val8"),

  # Surface float requires float_surface 0–3 mm.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    none <- data.table(rowid = integer(), variable = character(), reason = character())
    res <- rbindlist(lapply(seq_len(nrow(dat)), function(i) {
      rec <- dat[i]
      errs <- list()
      loc <- (rec$float_location |> as.character() |> str_trim())
      if (is.na(rec$float_location) || !nzchar(loc)) {
        loc <- NA_character_
      }
      surface <- (rec$float_surface |> as.character() |> as.numeric())
      if (identical(loc, "surface")) {
        if (is.na(surface) || !(surface %in% 0:3)) {
          return(data.table(rowid = rec$rowid, variable = "float_surface", reason = "Surface float requires float_surface 0–3 mm."))
        }
      }
      if (length(errs) == 0) {
        none
      } else {
        rbindlist(errs, use.names = TRUE, fill = TRUE)
      }
    }), use.names = TRUE, fill = TRUE)
    if (nrow(res) == 0) {
      none
    } else {
      unique(res)
    }
  } |> try_validator(nam = "val9"),

  # egg_id must be unique within an EGGS event.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    clock_key <- function(v) {
      txt <- (v |> as.character() |> str_trim())
      parsed_hm <- strptime(txt, format = "%H:%M")
      res <- rep(NA_character_, length(txt))
      ok_hm <- !is.na(parsed_hm)
      res[ok_hm] <- format(parsed_hm[ok_hm], "%H:%M")
      parsed_hms <- strptime(txt, format = "%H:%M:%S")
      ok_hms <- is.na(res) & !is.na(parsed_hms)
      res[ok_hms] <- format(parsed_hms[ok_hms], "%H:%M")
      res
    }
    to_mins <- function(v) {
      txt <- (v |> as.character() |> str_trim())
      res <- rep(NA_real_, length(txt))
      parsed_hm <- strptime(txt, format = "%H:%M")
      ok_hm <- !is.na(parsed_hm)
      res[ok_hm] <- (format(parsed_hm[ok_hm], "%H") |> as.numeric()) * 60 + (format(parsed_hm[ok_hm], "%M") |> as.numeric())
      parsed_hms <- strptime(txt, format = "%H:%M:%S")
      ok_hms <- is.na(res) & !is.na(parsed_hms)
      res[ok_hms] <- (format(parsed_hms[ok_hms], "%H") |> as.numeric()) * 60 + (format(parsed_hms[ok_hms], "%M") |> as.numeric())
      res
    }
    dat[, let(date_key, (date |> as.Date()))]
    dat[, let(time_key, clock_key(time_visit))]
    dat[, let(time_min, to_mins(time_visit))]
    dat[, let(observer_key, (observer |> as.character() |> str_trim()))]
    dat[, let(nest_key, (nest_id |> as.character() |> str_trim()))]
    dat[, let(egg_num, (egg_id |> as.character() |> as.numeric()))]
    nests <- as.data.table(db_get("SELECT nest_id, date, time_visit, observer, clutch_size FROM NESTS"))
    nests[, let(nest_key, (nest_id |> as.character() |> str_trim()))]
    nests[, let(date_key, (date |> as.Date()))]
    nests[, let(time_key, clock_key(time_visit))]
    nests[, let(time_min_nest, to_mins(time_visit))]
    nests[, let(observer_key, (observer |> as.character() |> str_trim()))]
    nests[, let(clutch_num, (clutch_size |> as.character() |> as.numeric()))]
    dup_recs <- dat[, .N, by = .(nest_key, date_key, time_key, observer_key, egg_num)][N > 1]
    dup_res <- if (nrow(dup_recs) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      merge(dat[, .(rowid, nest_key, date_key, time_key, observer_key, egg_num)], dup_recs[
        ,
        .(nest_key, date_key, time_key, observer_key, egg_num)
      ], by = c(
        "nest_key", "date_key",
        "time_key", "observer_key", "egg_num"
      ))[, .(rowid, variable = "egg_id", reason = "egg_id must be unique within an EGGS event.")]
    }
    dup_res
  } |> try_validator(nam = "val10"),

  # egg_id must not exceed the clutch_size of the matching NESTS event.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    clock_key <- function(v) {
      txt <- (v |> as.character() |> str_trim())
      parsed_hm <- strptime(txt, format = "%H:%M")
      res <- rep(NA_character_, length(txt))
      ok_hm <- !is.na(parsed_hm)
      res[ok_hm] <- format(parsed_hm[ok_hm], "%H:%M")
      parsed_hms <- strptime(txt, format = "%H:%M:%S")
      ok_hms <- is.na(res) & !is.na(parsed_hms)
      res[ok_hms] <- format(parsed_hms[ok_hms], "%H:%M")
      res
    }
    to_mins <- function(v) {
      txt <- (v |> as.character() |> str_trim())
      res <- rep(NA_real_, length(txt))
      parsed_hm <- strptime(txt, format = "%H:%M")
      ok_hm <- !is.na(parsed_hm)
      res[ok_hm] <- (format(parsed_hm[ok_hm], "%H") |> as.numeric()) * 60 + (format(parsed_hm[ok_hm], "%M") |> as.numeric())
      parsed_hms <- strptime(txt, format = "%H:%M:%S")
      ok_hms <- is.na(res) & !is.na(parsed_hms)
      res[ok_hms] <- (format(parsed_hms[ok_hms], "%H") |> as.numeric()) * 60 + (format(parsed_hms[ok_hms], "%M") |> as.numeric())
      res
    }
    dat[, let(date_key, (date |> as.Date()))]
    dat[, let(time_key, clock_key(time_visit))]
    dat[, let(time_min, to_mins(time_visit))]
    dat[, let(observer_key, (observer |> as.character() |> str_trim()))]
    dat[, let(nest_key, (nest_id |> as.character() |> str_trim()))]
    dat[, let(egg_num, (egg_id |> as.character() |> as.numeric()))]
    nests <- as.data.table(db_get("SELECT nest_id, date, time_visit, observer, clutch_size FROM NESTS"))
    nests[, let(nest_key, (nest_id |> as.character() |> str_trim()))]
    nests[, let(date_key, (date |> as.Date()))]
    nests[, let(time_key, clock_key(time_visit))]
    nests[, let(time_min_nest, to_mins(time_visit))]
    nests[, let(observer_key, (observer |> as.character() |> str_trim()))]
    nests[, let(clutch_num, (clutch_size |> as.character() |> as.numeric()))]
    max_egg <- dat[, .(max_egg = max(egg_num, na.rm = TRUE)), by = .(
      nest_key, date_key, time_key,
      observer_key
    )]
    max_egg[!is.finite(max_egg), let(max_egg, NA_real_)]
    evt_ref <- unique(dat[, .(nest_key, date_key, time_key, time_min, observer_key)])
    evt_ref <- merge(max_egg, evt_ref, by = c(
      "nest_key", "date_key", "time_key",
      "observer_key"
    ), all.x = TRUE)
    clutch_opts <- merge(evt_ref, nests[, .(
      nest_key, date_key, observer_key, time_min_nest,
      clutch_num
    )], by = c("nest_key", "date_key", "observer_key"), all.x = TRUE, allow.cartesian = TRUE)
    clutch_opts <- clutch_opts[!is.na(time_min) & !is.na(time_min_nest), let(
      time_diff,
      abs(time_min - time_min_nest)
    )][!is.na(time_diff) & time_diff <= 60]
    best_nest_fit <- if (nrow(clutch_opts) == 0) {
      data.table(
        nest_key = character(), date_key = (character() |> as.Date()), time_key = character(),
        observer_key = character(), clutch_num = numeric()
      )
    } else {
      clutch_opts[order(time_diff)][, .SD[1], by = .(
        nest_key, date_key, time_key,
        observer_key
      )][, .(nest_key, date_key, time_key, observer_key, clutch_num)]
    }
    clutch_check <- merge(max_egg, best_nest_fit, by = c(
      "nest_key", "date_key", "time_key",
      "observer_key"
    ), all.x = TRUE)[!is.na(max_egg) & !is.na(clutch_num) & max_egg > clutch_num]
    clutch_res <- if (nrow(clutch_check) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      merge(dat[, .(rowid, nest_key, date_key, time_key, observer_key)], clutch_check[, .(
        nest_key,
        date_key, time_key, observer_key
      )], by = c(
        "nest_key", "date_key", "time_key",
        "observer_key"
      ))[, .(rowid, variable = "egg_id", reason = "egg_id must not exceed the clutch_size of the matching NESTS event.")]
    }
    clutch_res
  } |> try_validator(nam = "val11"),

  # Check species allowed codes.
  is.element_validator(x[, .(species)], v = data.table(variable = "species", set = list(c(
    "BADO",
    "WRYB", "SNZD", "BFDO"
  ))), reason = "Invalid code.") |> try_validator(nam = "val12"),

  # Check float location allowed codes.
  is.element_validator(x[, .(float_location)], v = data.table(variable = "float_location", set = list(c(
    "bottom",
    "suspended", "surface"
  ))), reason = "Invalid code.") |> try_validator(nam = "val13"),

  # Check observer initials.
  is.regexp_validator(x[, .(observer)], regexp = "^[A-Z0-9]{2,3}$", reason = "Use 2–3 uppercase letters or digits.") |> try_validator(nam = "val14"),

  # Check date format.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    txt <- (dat$date |> as.character() |> str_trim())
    conv <- (txt |> as.Date(format = "%Y-%m-%d"))
    bad_idx <- which(!is.na(dat$date) & nzchar(txt) & (!(txt |> str_detect("^\\d{4}-\\d{2}-\\d{2}$")) %in% TRUE | is.na(conv)))
    if (length(bad_idx) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      data.table(rowid = dat$rowid[bad_idx], variable = "date", reason = "Use YYYY-MM-DD.")
    }
  } |> try_validator(nam = "val15"),

  # Check time format.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    txt <- (dat$time_visit |> as.character() |> str_trim())
    conv <- strptime(txt, format = "%H:%M")
    bad_idx <- which(!is.na(dat$time_visit) & nzchar(txt) & (!(txt |> str_detect("^\\d{2}:\\d{2}$")) %in% TRUE |
      is.na(conv)))
    if (length(bad_idx) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      data.table(rowid = dat$rowid[bad_idx], variable = "time_visit", reason = "Use hh:mm.")
    }
  } |> try_validator(nam = "val16"),

  # Check egg_id is numeric.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(egg_id) & nzchar((egg_id |> as.character() |> str_trim()))]
    dat[, let(egg_id, (egg_id |> as.character() |> str_trim() |> as.numeric()))]
    is.na_validator(dat[, .(rowid, egg_id)], reason = "Use egg_id 1–4.")
  } |> try_validator(nam = "val17"),

  # Check the egg_id range.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(egg_id) & nzchar((egg_id |> as.character() |> str_trim()))]
    dat[, let(egg_id, (egg_id |> as.character() |> str_trim() |> as.numeric()))]
    interval_validator(dat[, .(rowid, egg_id)],
      v = data.table(variable = "egg_id", lq = 1, uq = 4),
      reason = "Use egg_id 1–4."
    )
  } |> try_validator(nam = "val18"),

  # Require a whole number for egg_id.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(egg_id) & nzchar((egg_id |> as.character() |> str_trim()))]
    dat[, let(egg_id, (egg_id |> as.character() |> str_trim() |> as.numeric()))]
    dat[!is.na(egg_id) & egg_id != floor(egg_id), .(rowid, variable = "egg_id", reason = "Use egg_id 1–4.")]
  } |> try_validator(nam = "val19"),

  # Check float_angle is numeric.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(float_angle) & nzchar((float_angle |> as.character() |> str_trim()))]
    dat[, let(float_angle, (float_angle |> as.character() |> str_trim() |> as.numeric()))]
    is.na_validator(dat[, .(rowid, float_angle)], reason = "Use an integer from 0 to 90.")
  } |> try_validator(nam = "val20"),

  # Check the float_angle range.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(float_angle) & nzchar((float_angle |> as.character() |> str_trim()))]
    dat[, let(float_angle, (float_angle |> as.character() |> str_trim() |> as.numeric()))]
    interval_validator(dat[, .(rowid, float_angle)], v = data.table(
      variable = "float_angle",
      lq = 0, uq = 90
    ), reason = "Use an integer from 0 to 90.")
  } |> try_validator(nam = "val21"),

  # Require a whole number for float_angle.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(float_angle) & nzchar((float_angle |> as.character() |> str_trim()))]
    dat[, let(float_angle, (float_angle |> as.character() |> str_trim() |> as.numeric()))]
    dat[!is.na(float_angle) & float_angle != floor(float_angle), .(rowid,
      variable = "float_angle",
      reason = "Use an integer from 0 to 90."
    )]
  } |> try_validator(nam = "val22"),

  # Check float_surface is numeric.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(float_surface) & nzchar((float_surface |> as.character() |> str_trim()))]
    dat[, let(float_surface, (float_surface |> as.character() |> str_trim() |> as.numeric()))]
    is.na_validator(dat[, .(rowid, float_surface)], reason = "Use a non-negative integer.")
  } |> try_validator(nam = "val23"),

  # Check the float_surface range.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(float_surface) & nzchar((float_surface |> as.character() |> str_trim()))]
    dat[, let(float_surface, (float_surface |> as.character() |> str_trim() |> as.numeric()))]
    interval_validator(dat[, .(rowid, float_surface)], v = data.table(
      variable = "float_surface",
      lq = 0, uq = Inf
    ), reason = "Use a non-negative integer.")
  } |> try_validator(nam = "val24"),

  # Require a whole number for float_surface.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(float_surface) & nzchar((float_surface |> as.character() |> str_trim()))]
    dat[, let(float_surface, (float_surface |> as.character() |> str_trim() |> as.numeric()))]
    dat[!is.na(float_surface) & float_surface != floor(float_surface), .(rowid,
      variable = "float_surface",
      reason = "Use a non-negative integer."
    )]
  } |> try_validator(nam = "val25"),

  # Match the egg event to a nest visit.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    clock_key <- function(v) {
      txt <- (v |> as.character() |> str_trim())
      parsed_hm <- strptime(txt, format = "%H:%M")
      res <- rep(NA_character_, length(txt))
      ok_hm <- !is.na(parsed_hm)
      res[ok_hm] <- format(parsed_hm[ok_hm], "%H:%M")
      parsed_hms <- strptime(txt, format = "%H:%M:%S")
      ok_hms <- is.na(res) & !is.na(parsed_hms)
      res[ok_hms] <- format(parsed_hms[ok_hms], "%H:%M")
      res
    }
    to_mins <- function(v) {
      txt <- (v |> as.character() |> str_trim())
      res <- rep(NA_real_, length(txt))
      parsed_hm <- strptime(txt, format = "%H:%M")
      ok_hm <- !is.na(parsed_hm)
      res[ok_hm] <- (format(parsed_hm[ok_hm], "%H") |> as.numeric()) * 60 + (format(parsed_hm[ok_hm], "%M") |> as.numeric())
      parsed_hms <- strptime(txt, format = "%H:%M:%S")
      ok_hms <- is.na(res) & !is.na(parsed_hms)
      res[ok_hms] <- (format(parsed_hms[ok_hms], "%H") |> as.numeric()) * 60 + (format(parsed_hms[ok_hms], "%M") |> as.numeric())
      res
    }
    evt_ids <- unique(dat[, .(
      nest_id = (nest_id |> as.character() |> str_trim()), date = (date |> as.Date()),
      time_visit = clock_key(time_visit), time_min = to_mins(time_visit), observer = (observer |> as.character() |> str_trim())
    )])
    nests <- as.data.table(db_get("SELECT nest_id, date, time_visit, observer FROM NESTS"))
    nests[, let(nest_id, (nest_id |> as.character() |> str_trim()))]
    nests[, let(date, (date |> as.Date()))]
    nests[, let(time_visit, clock_key(time_visit))]
    nests[, let(time_min_nest, to_mins(time_visit))]
    nests[, let(observer, (observer |> as.character() |> str_trim()))]
    fit_opts <- merge(evt_ids, nests[, .(nest_id, date, observer, time_min_nest)],
      by = c("nest_id", "date", "observer"), all.x = TRUE, allow.cartesian = TRUE
    )
    matched_ids <- if (nrow(fit_opts) == 0) {
      data.table(
        nest_id = character(), date = (character() |> as.Date()), time_visit = character(),
        observer = character()
      )
    } else {
      unique(fit_opts[!is.na(time_min) & !is.na(time_min_nest) & abs(time_min - time_min_nest) <=
        60, .(nest_id, date, time_visit, observer)])
    }
    bad_ids <- evt_ids[!matched_ids, on = c("nest_id", "date", "time_visit", "observer")]
    if (nrow(bad_ids) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      merge(dat[, .(rowid,
        nest_id = (nest_id |> as.character() |> str_trim()), date = (date |> as.Date()),
        time_visit = clock_key(time_visit), observer = (observer |> as.character() |> str_trim())
      )], bad_ids[
        ,
        .(nest_id, date, time_visit, observer)
      ], by = c(
        "nest_id", "date", "time_visit",
        "observer"
      ))[, .(rowid, variable = "nest_id", reason = "No matching NESTS visit; check nest_id, date, observer, and time_visit.")][
        ,
        unique(.SD)
      ]
    }
  } |> try_validator(nam = "val26")
)
