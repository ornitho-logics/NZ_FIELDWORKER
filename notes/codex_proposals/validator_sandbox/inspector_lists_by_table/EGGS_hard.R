list({
    out <- try_validator(is.na_validator(x[, .(species, observer, date, time_visit, nest_id, egg_id)], reason = "Required EGGS field."), nam = "EGG_001 mandatory")
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
        ref <- data.table::as.data.table(db_get("SELECT observer, start, stop FROM OBSERVERS"))
        ref[, `:=`(start, suppressWarnings(as.Date(start)))]
        ref[, `:=`(stop, suppressWarnings(as.Date(stop)))]
        z[, `:=`(date, suppressWarnings(as.Date(date)))]
        m <- merge(z[, .(rowid, observer, date)], ref, by = "observer", all.x = TRUE)
        bad_idx <- m[is.na(start) | is.na(stop) | is.na(date) | date < start | date > stop, rowid]
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = bad_idx, variable = "observer", reason = "Observer must exist in OBSERVERS and be active on the egg date.")
        }
    }, nam = "EGG_002 observer active")
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
        to_minutes <- function(v) {
            raw <- trimws(as.character(v))
            parsed <- suppressWarnings(strptime(raw, format = "%H:%M"))
            out <- rep(NA_integer_, length(raw))
            ok <- !is.na(parsed)
            out[ok] <- as.integer(format(parsed[ok], "%H")) * 60L + as.integer(format(parsed[ok], "%M"))
            out
        }
        normalize_time_key <- function(v) {
            raw <- trimws(as.character(v))
            out <- rep(NA_character_, length(raw))
            parsed_hm <- suppressWarnings(strptime(raw, format = "%H:%M"))
            ok_hm <- !is.na(parsed_hm)
            out[ok_hm] <- format(parsed_hm[ok_hm], "%H:%M")
            parsed_hms <- suppressWarnings(strptime(raw, format = "%H:%M:%S"))
            ok_hms <- is.na(out) & !is.na(parsed_hms)
            out[ok_hms] <- format(parsed_hms[ok_hms], "%H:%M")
            out
        }
        current <- z[, .(rowid, nest_key = trimws(as.character(nest_id)), observer_key = trimws(as.character(observer)), date_key = suppressWarnings(as.Date(date)), time_key = normalize_time_key(time_visit), time_min = to_minutes(time_visit))]
        current <- current[!is.na(nest_key) & nzchar(nest_key) & !is.na(observer_key) & nzchar(observer_key)]
        # EGGS can legitimately contain repeated visits to the same nest across the season.
        # The timing rule should therefore operate within a single egg-check event, not across
        # the whole nest history. We approximate an event as rows sharing nest_id, observer,
        # and date, and only flag date inconsistencies when the same nest_id/observer/time
        # combination appears on more than one date within the submitted batch.
        same_time_multi_date <- current[!is.na(time_key) & nzchar(time_key), .(date_n = data.table::uniqueN(date_key[!is.na(date_key)])), by = .(nest_key, observer_key, time_key)][date_n > 1]
        bad_time_keys <- current[!is.na(date_key), .(time_span = if (all(is.na(time_min))) NA_real_ else max(time_min, na.rm = TRUE) - min(time_min, na.rm = TRUE)), by = .(nest_key, observer_key, date_key)][!is.na(time_span) & time_span > 5]
        date_out <- if (nrow(same_time_multi_date) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            merge(current[, .(rowid, nest_key, observer_key, time_key)], same_time_multi_date[, .(nest_key, observer_key, time_key)], by = c("nest_key", "observer_key", "time_key"))[, .(rowid, variable = "date", reason = "All EGGS rows for the same egg-check event must use the same date.")]
        }
        time_out <- if (nrow(bad_time_keys) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            merge(current[, .(rowid, nest_key, observer_key, date_key)], bad_time_keys[, .(nest_key, observer_key, date_key)], by = c("nest_key", "observer_key", "date_key"))[, .(rowid, variable = "time_visit", reason = "All EGGS rows for the same nest_id on the same date must use time_visit values within five minutes.")]
        }
        out <- data.table::rbindlist(list(date_out, time_out), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            unique(out)
        }
    }, nam = "EGG_003 event timing")
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
        bad_idx <- which(!is.na(z$date) & nzchar(raw) & !is.na(parsed) & (parsed < as.Date("2026-07-01") | parsed > as.Date("2027-07-31")))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
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
        cr_pat <- "^[ABC](0[1-9]|[1-9][0-9])(0[1-9]|[1-9][0-9])$"
        legacy_pat <- "^(BA|WR|SN|BF)(0[1-9]|[1-9][0-9])(0[1-9]|[1-9][0-9])$"
        raw <- trimws(as.character(z$nest_id))
        bad_idx <- which(!is.na(z$nest_id) & nzchar(raw) & (grepl("^-", raw) | !(grepl(cr_pat, raw) | grepl(legacy_pat, raw))))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "nest_id", reason = "Negative nest IDs describe broods of unknown origin and have no known nest or egg history. Enter the birds in RESIGHTINGS or CAPTURES instead; EGGS requires a positive nest ID.")
        }
    }, nam = "EGG_004 nest id")
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
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            problems <- list()
            loc <- trimws(as.character(row$float_location))
            if (is.na(row$float_location) || !nzchar(loc)) {
                loc <- NA_character_
            }
            surface <- suppressWarnings(as.numeric(as.character(row$float_surface)))
            if (identical(loc, "bottom")) {
                if (!is.na(surface)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "float_surface", reason = "float_surface must be blank when float_location is bottom.")
                }
            }
            if (identical(loc, "suspended")) {
                if (!is.na(surface)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "float_surface", reason = "float_surface must be blank when float_location is suspended.")
                }
            }
            if (identical(loc, "surface")) {
                if (is.na(surface) || !(surface %in% 0:3)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "float_surface", reason = "when float_location is \"surface\" a \"float_surface\" value (0, 1, 2, or 3) is needed indicating the mm above the surface")
                }
            }
            if (length(problems) == 0) {
                empty
            } else {
                data.table::rbindlist(problems, use.names = TRUE, fill = TRUE)
            }
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "EGG_006 float logic")
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
        norm_time_key <- function(v) {
            raw <- trimws(as.character(v))
            parsed_hm <- suppressWarnings(strptime(raw, format = "%H:%M"))
            out <- rep(NA_character_, length(raw))
            ok_hm <- !is.na(parsed_hm)
            out[ok_hm] <- format(parsed_hm[ok_hm], "%H:%M")
            parsed_hms <- suppressWarnings(strptime(raw, format = "%H:%M:%S"))
            ok_hms <- is.na(out) & !is.na(parsed_hms)
            out[ok_hms] <- format(parsed_hms[ok_hms], "%H:%M")
            out
        }
        to_minutes <- function(v) {
            raw <- trimws(as.character(v))
            out <- rep(NA_real_, length(raw))
            parsed_hm <- suppressWarnings(strptime(raw, format = "%H:%M"))
            ok_hm <- !is.na(parsed_hm)
            out[ok_hm] <- as.numeric(format(parsed_hm[ok_hm], "%H")) * 60 + as.numeric(format(parsed_hm[ok_hm], "%M"))
            parsed_hms <- suppressWarnings(strptime(raw, format = "%H:%M:%S"))
            ok_hms <- is.na(out) & !is.na(parsed_hms)
            out[ok_hms] <- as.numeric(format(parsed_hms[ok_hms], "%H")) * 60 + as.numeric(format(parsed_hms[ok_hms], "%M"))
            out
        }
        z[, `:=`(date_key, suppressWarnings(as.Date(date)))]
        z[, `:=`(time_key, norm_time_key(time_visit))]
        z[, `:=`(time_min, to_minutes(time_visit))]
        z[, `:=`(observer_key, trimws(as.character(observer)))]
        z[, `:=`(nest_key, trimws(as.character(nest_id)))]
        z[, `:=`(egg_num, suppressWarnings(as.numeric(as.character(egg_id))))]
        nests <- data.table::as.data.table(db_get("SELECT nest_id, date, time_visit, observer, clutch_size FROM NESTS"))
        nests[, `:=`(nest_key, trimws(as.character(nest_id)))]
        nests[, `:=`(date_key, suppressWarnings(as.Date(date)))]
        nests[, `:=`(time_key, norm_time_key(time_visit))]
        nests[, `:=`(time_min_nest, to_minutes(time_visit))]
        nests[, `:=`(observer_key, trimws(as.character(observer)))]
        nests[, `:=`(clutch_num, suppressWarnings(as.numeric(as.character(clutch_size))))]
        dup_rows <- z[, .N, by = .(nest_key, date_key, time_key, observer_key, egg_num)][N > 1]
        dup_out <- if (nrow(dup_rows) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            merge(
                z[, .(rowid, nest_key, date_key, time_key, observer_key, egg_num)],
                dup_rows[, .(nest_key, date_key, time_key, observer_key, egg_num)],
                by = c("nest_key", "date_key", "time_key", "observer_key", "egg_num")
            )[, .(rowid, variable = "egg_id", reason = "egg_id must be unique within an EGGS event.")]
        }
        max_egg <- z[
            ,
            .(max_egg = suppressWarnings(max(egg_num, na.rm = TRUE))),
            by = .(nest_key, date_key, time_key, observer_key)
        ]
        max_egg[!is.finite(max_egg), `:=`(max_egg, NA_real_)]
        event_lookup <- unique(z[, .(nest_key, date_key, time_key, time_min, observer_key)])
        event_lookup <- merge(
            max_egg,
            event_lookup,
            by = c("nest_key", "date_key", "time_key", "observer_key"),
            all.x = TRUE
        )
        clutch_candidates <- merge(
            event_lookup,
            nests[, .(nest_key, date_key, observer_key, time_min_nest, clutch_num)],
            by = c("nest_key", "date_key", "observer_key"),
            all.x = TRUE,
            allow.cartesian = TRUE
        )
        clutch_candidates <- clutch_candidates[
            !is.na(time_min) & !is.na(time_min_nest),
            `:=`(time_diff, abs(time_min - time_min_nest))
        ][
            !is.na(time_diff) & time_diff <= 60
        ]
        best_nest_match <- if (nrow(clutch_candidates) == 0) {
            data.table::data.table(
                nest_key = character(),
                date_key = as.Date(character()),
                time_key = character(),
                observer_key = character(),
                clutch_num = numeric()
            )
        } else {
            clutch_candidates[order(time_diff)][
                ,
                .SD[1],
                by = .(nest_key, date_key, time_key, observer_key)
            ][
                ,
                .(nest_key, date_key, time_key, observer_key, clutch_num)
            ]
        }
        clutch_check <- merge(
            max_egg,
            best_nest_match,
            by = c("nest_key", "date_key", "time_key", "observer_key"),
            all.x = TRUE
        )[
            !is.na(max_egg) & !is.na(clutch_num) & max_egg > clutch_num
        ]
        clutch_out <- if (nrow(clutch_check) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            merge(
                z[, .(rowid, nest_key, date_key, time_key, observer_key)],
                clutch_check[, .(nest_key, date_key, time_key, observer_key)],
                by = c("nest_key", "date_key", "time_key", "observer_key")
            )[, .(rowid, variable = "egg_id", reason = "egg_id must not exceed the clutch_size of the matching NESTS event.")]
        }
        out <- data.table::rbindlist(list(dup_out, clutch_out), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            unique(out)
        }
    }, nam = "EGG_009 egg id event")
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
        z <- x[, .(species, float_location)]
        v <- data.table::data.table(variable = c("species", "float_location"), set = list(c("BADO", "WRYB", "SNZD", "BFDO"), c("bottom", "suspended", "surface")))
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
        raw <- trimws(as.character(z$time_visit))
        parsed <- suppressWarnings(strptime(raw, format = "%H:%M"))
        bad_idx <- which(!is.na(z$time_visit) & nzchar(raw) & (!grepl("^\\d{2}:\\d{2}$", raw) | is.na(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "time_visit", reason = "Visit time must use hh:mm.")
        }
    }, nam = "time format")
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
        raw <- trimws(as.character(z$egg_id))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$egg_id) & nzchar(raw) & (is.na(parsed) | parsed < 1 | parsed > 4 | parsed != floor(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "egg_id", reason = "Egg ID must be a whole number from 1 to 4.")
        }
    }, nam = "egg id")
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
        raw <- trimws(as.character(z$float_angle))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$float_angle) & nzchar(raw) & (is.na(parsed) | parsed < 0 | parsed > 90 | parsed != floor(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "float_angle", reason = "Float angle must be a whole number from 0 to 90.")
        }
    }, nam = "float angle")
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
        raw <- trimws(as.character(z$float_surface))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$float_surface) & nzchar(raw) & (is.na(parsed) | parsed < 0 | parsed != floor(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "float_surface", reason = "Float-surface height must be a non-negative whole number.")
        }
    }, nam = "float surface")
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
