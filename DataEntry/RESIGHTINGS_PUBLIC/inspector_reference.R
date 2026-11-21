list(
  # Required.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    req_res <- is.na_validator(dat[, .(
      species, observer, date, sex, source, source_identifier,
      country, rowid
    )], reason = "Required.")
    as.data.table(req_res)
  } |> try_validator(nam = "val1"),

  # Enter at least one leg mark.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    blank <- function(v) {
      txt <- (v |> as.character() |> str_trim())
      is.na(v) | !nzchar(txt) | (txt |> toupper()) == "NA"
    }
    leg_blank <- dat[blank(UL) & blank(LL) & blank(UR) & blank(LR), .(rowid,
      variable = "UL",
      reason = "Enter at least one leg mark."
    )]
    leg_blank
  } |> try_validator(nam = "val2"),

  # Check the field-season dates.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    none <- data.table(rowid = integer(), variable = character(), reason = character())
    d <- (dat$date |> as.Date())
    bad_idx <- which(!is.na(dat$date) & (is.na(d) | d < ("2026-07-01" |> as.Date()) | d > ("2027-07-31" |> as.Date())))
    if (length(bad_idx) == 0) {
      none
    } else {
      data.table(rowid = dat$rowid[bad_idx], variable = "date", reason = "Use a date in the 2026–2027 season.")
    }
  } |> try_validator(nam = "val3"),

  # Restrict public observations to BADO.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(species) & nzchar((species |> as.character() |> str_trim())), .(species, rowid)]
    if (nrow(dat) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      is.element_validator(dat, v = data.table(variable = "species", set = list("BADO")), reason = "Use BADO.")
    }
  } |> try_validator(nam = "val4"),

  # Check the observation time.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(time) & nzchar((time |> as.character() |> str_trim()))]
    dat[, let(time, (time |> as.character() |> str_trim()))]
    hhmm_validator(dat[, .(rowid, time)], reason = "Use hh:mm.")
  } |> try_validator(nam = "val5"),

  # Check species allowed codes.
  is.element_validator(x[, .(species)], v = data.table(variable = "species", set = list(c(
    "BADO",
    "WRYB", "SNZD", "BFDO"
  ))), reason = "Invalid code.") |> try_validator(nam = "val6"),

  # Check sex allowed codes.
  is.element_validator(x[, .(sex)], v = data.table(variable = "sex", set = list(c(
    "M", "M?",
    "F", "F?", "U"
  ))), reason = "Invalid code.") |> try_validator(nam = "val7"),

  # Check country allowed codes.
  is.element_validator(x[, .(country)], v = data.table(variable = "country", set = list(c(
    "NZ",
    "AU", "O"
  ))), reason = "Invalid code.") |> try_validator(nam = "val8"),

  # Check site allowed codes.
  is.element_validator(x[, .(site)], v = data.table(variable = "site", set = list(c(
    "AR", "AU",
    "CH", "CL", "CR", "HC", "HR", "KK", "KP", "KT", "MB", "MR", "MS", "OD", "OK", "OM", "PB",
    "PR", "TA", "TO", "TP", "TR", "TS", "WA", "WN", "WS"
  ))), reason = "Invalid code.") |> try_validator(nam = "val9"),

  # Check falcon upload allowed codes.
  is.element_validator(x[, .(falcon_upload)], v = data.table(variable = "falcon_upload", set = list(c(
    "0",
    "1"
  ))), reason = "Invalid code.") |> try_validator(nam = "val10"),

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
  } |> try_validator(nam = "val11"),

  # Check latitude is numeric.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(latitude) & nzchar((latitude |> as.character() |> str_trim()))]
    dat[, let(latitude, (latitude |> as.character() |> str_trim() |> as.numeric()))]
    is.na_validator(dat[, .(rowid, latitude)], reason = "Use decimal degrees from -90 to 90.")
  } |> try_validator(nam = "val12"),

  # Check the latitude range.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(latitude) & nzchar((latitude |> as.character() |> str_trim()))]
    dat[, let(latitude, (latitude |> as.character() |> str_trim() |> as.numeric()))]
    interval_validator(dat[, .(rowid, latitude)], v = data.table(
      variable = "latitude", lq = -90,
      uq = 90
    ), reason = "Use decimal degrees from -90 to 90.")
  } |> try_validator(nam = "val13"),

  # Check longitude is numeric.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(longitude) & nzchar((longitude |> as.character() |> str_trim()))]
    dat[, let(longitude, (longitude |> as.character() |> str_trim() |> as.numeric()))]
    is.na_validator(dat[, .(rowid, longitude)], reason = "Use decimal degrees from -180 to 180.")
  } |> try_validator(nam = "val14"),

  # Check the longitude range.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(longitude) & nzchar((longitude |> as.character() |> str_trim()))]
    dat[, let(longitude, (longitude |> as.character() |> str_trim() |> as.numeric()))]
    interval_validator(dat[, .(rowid, longitude)], v = data.table(
      variable = "longitude", lq = -180,
      uq = 180
    ), reason = "Use decimal degrees from -180 to 180.")
  } |> try_validator(nam = "val15"),

  # Check easting numeric.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    txt <- (dat$easting |> as.character() |> str_trim())
    conv <- (txt |> as.numeric())
    bad_idx <- which(!is.na(dat$easting) & nzchar(txt) & is.na(conv))
    if (length(bad_idx) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      data.table(rowid = dat$rowid[bad_idx], variable = "easting", reason = "Easting must be numeric.")
    }
  } |> try_validator(nam = "val16"),

  # Check northing numeric.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    txt <- (dat$northing |> as.character() |> str_trim())
    conv <- (txt |> as.numeric())
    bad_idx <- which(!is.na(dat$northing) & nzchar(txt) & is.na(conv))
    if (length(bad_idx) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      data.table(rowid = dat$rowid[bad_idx], variable = "northing", reason = "Northing must be numeric.")
    }
  } |> try_validator(nam = "val17"),

  # Check left tibia.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    is.regexp_validator(dat[, .(UL, rowid)], regexp = "^(X|[OYWBRGLM]{1,2}|F[OYWBRGLM][A-Z0-9]{2})$", reason = "Invalid left-tibia code.")
  } |> try_validator(nam = "val18"),

  # Check left tarsus.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    is.regexp_validator(dat[, .(LL, rowid)], regexp = "^(X|XX|[OYWBRGLM]{1,2})$", reason = "Invalid left-tarsus code.")
  } |> try_validator(nam = "val19"),

  # Check right tibia.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    is.regexp_validator(dat[, .(UR, rowid)], regexp = "^(X|T|[OYWBRGLM]{1,2}|F[OYWBRGLM][A-Z0-9]{2})$", reason = "Invalid right-tibia code.")
  } |> try_validator(nam = "val20"),

  # Check right tarsus.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    is.regexp_validator(dat[, .(LR, rowid)], regexp = "^(X|XX|[OYWBRGLM]{1,2})$", reason = "Invalid right-tarsus code.")
  } |> try_validator(nam = "val21"),

  # Check behaviour codes.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    allowed <- c(
      "IN", "CO", "PR", "BW", "BC", "NM", "FC", "FA", "FM", "FF", "RS", "LF", "AT",
      "FT", "OB"
    )
    txt <- (dat$behav |> as.character() |> str_trim())
    set_i <- which(!is.na(dat$behav) & nzchar(txt))
    bad_idx <- set_i[!vapply((txt[set_i] |> str_split(",") |> lapply(function(parts) {
      if (identical(tail(parts, 1), "")) {
        head(parts, -1)
      } else {
        parts
      }
    })), FUN.VALUE = logical(1), FUN = function(tkns) {
      tkns <- (tkns |> str_trim())
      length(tkns) > 0 && all(nzchar(tkns)) && all(tkns %in% allowed)
    })]
    if (length(bad_idx) == 0) {
      data.table(rowid = integer(), variable = character(), reason = character())
    } else {
      data.table(rowid = dat$rowid[bad_idx], variable = "behav", reason = "Use valid comma-separated behaviour codes.")
    }
  } |> try_validator(nam = "val22"),

  # Check num_photos is numeric.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(num_photos) & nzchar((num_photos |> as.character() |> str_trim()))]
    dat[, let(num_photos, (num_photos |> as.character() |> str_trim() |> as.numeric()))]
    is.na_validator(dat[, .(rowid, num_photos)], reason = "Use a non-negative integer.")
  } |> try_validator(nam = "val23"),

  # Check the num_photos range.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(num_photos) & nzchar((num_photos |> as.character() |> str_trim()))]
    dat[, let(num_photos, (num_photos |> as.character() |> str_trim() |> as.numeric()))]
    interval_validator(dat[, .(rowid, num_photos)], v = data.table(
      variable = "num_photos", lq = 0,
      uq = Inf
    ), reason = "Use a non-negative integer.")
  } |> try_validator(nam = "val24"),

  # Require a whole number for num_photos.
  {
    dat <- copy(x)
    if (!"rowid" %in% names(dat)) {
      dat[, let(rowid, .I)]
    }
    dat <- dat[!is.na(num_photos) & nzchar((num_photos |> as.character() |> str_trim()))]
    dat[, let(num_photos, (num_photos |> as.character() |> str_trim() |> as.numeric()))]
    dat[!is.na(num_photos) & num_photos != floor(num_photos), .(rowid,
      variable = "num_photos",
      reason = "Use a non-negative integer."
    )]
  } |> try_validator(nam = "val25")
)
