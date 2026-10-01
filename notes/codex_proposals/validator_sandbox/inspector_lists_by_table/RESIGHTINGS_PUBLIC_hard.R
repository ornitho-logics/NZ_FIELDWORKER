list({
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        blankish <- function(v) {
            raw <- trimws(as.character(v))
            is.na(v) | !nzchar(raw) | toupper(raw) == "NA"
        }
        required_out <- is.na_validator(
            z[, .(species, observer, date, sex, source, source_identifier, country, rowid)],
            reason = "Required public resighting field."
        )
        leg_missing <- z[
            blankish(UL) & blankish(LL) & blankish(UR) & blankish(LR),
            .(
                rowid,
                variable = "UL",
                reason = "At least one leg-mark segment must be entered."
            )
        ]
        data.table::rbindlist(
            list(
                data.table::as.data.table(required_out),
                leg_missing
            ),
            use.names = TRUE,
            fill = TRUE
        )
    }, nam = "PUB_001 mandatory")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        d <- suppressWarnings(as.Date(z$date))
        bad_idx <- which(!is.na(z$date) & (is.na(d) | d < as.Date("2026-07-01") | d > as.Date("2027-07-31")))
        if (length(bad_idx) == 0) {
            empty
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "date", reason = "Date must fall within the 2026-2027 field season.")
        }
    }, nam = "GLOBAL_002 season")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        z <- z[!is.na(species) & nzchar(trimws(as.character(species))), .(species, rowid)]
        if (nrow(z) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            is.element_validator(z, v = data.table::data.table(variable = "species", set = list("BADO")), reason = "Public resightings are restricted to BADO.")
        }
    }, nam = "PUB_002 species")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        z <- z[!is.na(country) & nzchar(trimws(as.character(country))), .(country, rowid)]
        if (nrow(z) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            is.element_validator(z, v = data.table::data.table(variable = "country", set = list(c("NZ", "AU", "O"))), reason = "Country must be NZ, AU, or O.")
        }
    }, nam = "PUB_003 country")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        raw <- trimws(as.character(z$time))
        parsed <- suppressWarnings(strptime(raw, format = "%H:%M"))
        bad_idx <- which(!is.na(z$time) & nzchar(raw) & (!grepl("^([01][0-9]|2[0-3]):[0-5][0-9]$", raw) | is.na(parsed)))
        if (length(bad_idx) == 0) {
            empty
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "time", reason = "Time must use hh:mm when entered.")
        }
    }, nam = "PUB_007 time")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- x[, .(species, sex, country, site, falcon_upload)]
        v <- data.table::data.table(variable = c("species", "sex", "country", "site", "falcon_upload"), set = list(c("BADO", "WRYB", "SNZD", "BFDO"), c("M", "M?", "F", "F?", "U"), c("NZ", "AU", "O"), c("AR", "AU", "CH", "CL", "CR", "HC", "HR", "KK", "KP", "KT", "MB", "MR", "MS", "OD", "OK", "OM", "PB", "PR", "TA", "TO", "TP", "TR", "TS", "WA", "WN", "WS"), c("0", "1")))
        is.element_validator(z, v = v, reason = "Value is not in the current allowed set.")
    }, nam = "coded values")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        raw <- trimws(as.character(z$date))
        parsed <- suppressWarnings(as.Date(raw, format = "%Y-%m-%d"))
        bad_idx <- which(!is.na(z$date) & nzchar(raw) & (!grepl("^\\d{4}-\\d{2}-\\d{2}$", raw) | is.na(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "date", reason = "Date must use YYYY-MM-DD.")
        }
    }, nam = "date format")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        raw <- trimws(as.character(z$latitude))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$latitude) & nzchar(raw) & (is.na(parsed) | parsed < -90 | parsed > 90))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "latitude", reason = "Latitude must be a decimal degree value between -90 and 90.")
        }
    }, nam = "latitude range")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        raw <- trimws(as.character(z$longitude))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$longitude) & nzchar(raw) & (is.na(parsed) | parsed < -180 | parsed > 180))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "longitude", reason = "Longitude must be a decimal degree value between -180 and 180.")
        }
    }, nam = "longitude range")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        raw <- trimws(as.character(z$easting))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$easting) & nzchar(raw) & is.na(parsed))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "easting", reason = "Easting must be numeric.")
        }
    }, nam = "easting numeric")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        raw <- trimws(as.character(z$northing))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$northing) & nzchar(raw) & is.na(parsed))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "northing", reason = "Northing must be numeric.")
        }
    }, nam = "northing numeric")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        mark_cols <- intersect(c("UL", "LL", "UR", "LR"), names(z))
        out <- data.table::rbindlist(lapply(mark_cols, function(col) {
            raw <- trimws(as.character(z[[col]]))
            bad_idx <- which(!is.na(z[[col]]) & nzchar(raw) & grepl(",", raw))
            if (length(bad_idx) == 0) {
                return(NULL)
            }
            data.table::data.table(rowid = z$rowid[bad_idx], variable = col, reason = "do not comma-seperate leg markings, e.g., \"R,R\" should be \"RR\"")
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            unique(out)
        }
    }, nam = "comma leg markings")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        raw <- trimws(as.character(z$UL))
        z <- z[is.na(UL) | !nzchar(raw) | !grepl(",", raw), .(UL, rowid)]
        is.regexp_validator(z, regexp = "^(X|[OYWBRGLM]{1,2}|F[OYWBRGLM][A-Z0-9]{2})$", reason = "Left tibia code does not match the current format.")
    }, nam = "left tibia")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        raw <- trimws(as.character(z$LL))
        z <- z[is.na(LL) | !nzchar(raw) | !grepl(",", raw), .(LL, rowid)]
        is.regexp_validator(z, regexp = "^(X|XX|[OYWBRGLM]{1,2})$", reason = "Left tarsus code does not match the current format.")
    }, nam = "left tarsus")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        raw <- trimws(as.character(z$UR))
        z <- z[is.na(UR) | !nzchar(raw) | !grepl(",", raw), .(UR, rowid)]
        is.regexp_validator(z, regexp = "^(X|T|[OYWBRGLM]{1,2}|F[OYWBRGLM][A-Z0-9]{2})$", reason = "Right tibia code does not match the current format.")
    }, nam = "right tibia")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        raw <- trimws(as.character(z$LR))
        z <- z[is.na(LR) | !nzchar(raw) | !grepl(",", raw), .(LR, rowid)]
        is.regexp_validator(z, regexp = "^(X|XX|[OYWBRGLM]{1,2})$", reason = "Right tarsus code does not match the current format.")
    }, nam = "right tarsus")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        allowed <- c("IN", "CO", "PR", "BW", "BC", "NM", "FC", "FA", "FM", "FF", "RS", "LF", "AT", "FT", "OB")
        raw <- trimws(as.character(z$behav))
        present_idx <- which(!is.na(z$behav) & nzchar(raw))
        bad_idx <- present_idx[!vapply(strsplit(raw[present_idx], ","), FUN.VALUE = logical(1), FUN = function(tokens) {
            tokens <- trimws(tokens)
            length(tokens) > 0 && all(nzchar(tokens)) && all(tokens %in% allowed)
        })]
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "behav", reason = "Behaviour codes must use the current comma-separated tokens.")
        }
    }, nam = "behaviour codes")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        raw <- trimws(as.character(z$num_photos))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$num_photos) & nzchar(raw) & (is.na(parsed) | parsed < 0 | parsed != floor(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "num_photos", reason = "Number of photos must be a non-negative whole number.")
        }
    }, nam = "photo count")
    out <- data.table::as.data.table(out)
    if ("reason" %in% names(out)) {
        out[, `:=`(reason, {
            cleaned <- sub("^(ERROR|WARNING):\\s*", "", as.character(reason))
            cleaned[is.na(reason)] <- NA_character_
            ok_idx <- !is.na(cleaned) & nzchar(cleaned)
            cleaned[ok_idx] <- paste0(
                cleaned[ok_idx],
                " Please double-check this entry. If it is correct, add a validator bypass comment to the event."
            )
            cleaned
        })]
    }
    if ("type" %in% names(out)) {
        out[, `:=`(type, NULL)]
    }
    out
})
