list({
    out <- try_validator(is.regexp_validator(x[, .(observer)], regexp = "^[A-Z]{2,3}$", reason = "Observer initials must use two or three uppercase letters."), nam = "observer initials")
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
        raw <- trimws(as.character(z$start))
        parsed <- suppressWarnings(as.Date(raw, format = "%Y-%m-%d"))
        bad_idx <- which(!is.na(z$start) & nzchar(raw) & (!grepl("^\\d{4}-\\d{2}-\\d{2}$", raw) | is.na(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "start", reason = "Start date must use YYYY-MM-DD.")
        }
    }, nam = "start date")
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
        raw <- trimws(as.character(z$stop))
        parsed <- suppressWarnings(as.Date(raw, format = "%Y-%m-%d"))
        bad_idx <- which(!is.na(z$stop) & nzchar(raw) & (!grepl("^\\d{4}-\\d{2}-\\d{2}$", raw) | is.na(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "stop", reason = "Stop date must use YYYY-MM-DD.")
        }
    }, nam = "stop date")
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
        raw <- trimws(as.character(z$gps_id))
        ok_gps_list <- function(v) {
            v <- trimws(as.character(v))
            if (is.na(v) || !nzchar(v) || v == "NA") {
                return(TRUE)
            }
            parts <- trimws(unlist(strsplit(v, ",", fixed = TRUE)))
            if (!length(parts) || any(!nzchar(parts))) {
                return(FALSE)
            }
            vals <- suppressWarnings(as.numeric(parts))
            all(!is.na(vals) & vals >= 1 & vals <= 255 & vals == floor(vals))
        }
        bad_idx <- which(!vapply(raw, ok_gps_list, logical(1)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "gps_id", reason = "GPS ID must be a whole number from 1 to 255, or a comma-separated list of those values.")
        }
    }, nam = "gps id")
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
    out <- try_validator(is.regexp_validator(x[, .(nznbbs_number)], regexp = "^[A-Za-z0-9]{4}$", reason = "NZNBBS number must use four letters or numbers."), nam = "nznbbs number")
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
        start_date <- suppressWarnings(as.Date(z$start))
        stop_date <- suppressWarnings(as.Date(z$stop))
        bad_idx <- which(!is.na(z$start) & !is.na(z$stop) & !is.na(start_date) & !is.na(stop_date) & start_date > stop_date)
        if (length(bad_idx) == 0) {
            empty
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "start", reason = "Observer start must be on or before stop.")
        }
    }, nam = "OBS_002 start stop")
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
        dup_codes <- z[!is.na(observer) & nzchar(trimws(as.character(observer))), .N, by = observer][N > 1, observer]
        if (length(dup_codes) == 0) {
            empty
        } else {
            z[observer %in% dup_codes, .(rowid, variable = "observer", reason = "Observer code must be unique.")]
        }
    }, nam = "OBS_003 unique observer")
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
