list({
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        warn_reason <- paste0("Usually an EGGS event has floatation data. If the egg was not floated (e.g., hatch sign), then make a comment and make the correct event in NESTS (e.g., fill out ", "\"hatch_state\"", intToUtf8(41L))
        missing_like <- function(v) {
            raw <- trimws(as.character(v))
            is.na(v) | !nzchar(raw) | raw == "NA"
        }
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            problems <- list()
            if (missing_like(row$float_angle)) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "float_angle", reason = warn_reason)
            }
            if (missing_like(row$float_location)) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "float_location", reason = warn_reason)
            }
            if (length(problems) == 0) {
                empty
            } else {
                data.table::rbindlist(problems, use.names = TRUE, fill = TRUE)
            }
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) {
            empty
        } else {
            unique(out)
        }
    }, nam = "EGG_W003 missing float data")
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
            loc <- trimws(as.character(row$float_location))
            if (is.na(row$float_location) || !nzchar(loc)) {
                return(empty)
            }
            angle <- suppressWarnings(as.numeric(as.character(row$float_angle)))
            if (is.na(angle)) {
                return(empty)
            }
            if (identical(loc, "bottom") && (angle < 0 || angle > 90)) {
                return(data.table::data.table(rowid = row$rowid, variable = "float_angle", reason = "When float_location is \"bottom\", the angle is typically between 0 and 90."))
            }
            if (identical(loc, "suspended") && (angle < 85 || angle > 90)) {
                return(data.table::data.table(rowid = row$rowid, variable = "float_angle", reason = "When float_location is \"suspended\", the angle is typically between 85 and 90."))
            }
            if (identical(loc, "surface") && (angle < 75 || angle > 90)) {
                return(data.table::data.table(rowid = row$rowid, variable = "float_angle", reason = "When float_location is \"surface\", the angle is typically between 75 and 90."))
            }
            empty
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) {
            empty
        } else {
            unique(out)
        }
    }, nam = "EGG_W003A angle by location")
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
        nearest_prediction <- function(dt, calib) {
            if (nrow(dt) == 0 || nrow(calib) == 0) {
                dt[, `:=`(predicted_days_since_laying, NA_real_)]
                return(dt)
            }
            scored <- data.table::rbindlist(lapply(seq_len(nrow(dt)), function(i) {
                row <- dt[i]
                cand <- data.table::copy(calib[float_location_key == row$float_location_key])
                if (nrow(cand) == 0) {
                    return(data.table::data.table(rowid = row$rowid, predicted_days_since_laying = NA_real_))
                }
                cand[, `:=`(exact_match, data.table::fifelse(float_angle_num == row$float_angle_num & ((is.na(float_surface_num) & is.na(row$float_surface_num)) | (!is.na(float_surface_num) & !is.na(row$float_surface_num) & float_surface_num == row$float_surface_num)), 0, 1))]
                cand[, `:=`(angle_diff, abs(float_angle_num - row$float_angle_num))]
                cand[, `:=`(surface_diff, data.table::fifelse(is.na(float_surface_num) & is.na(row$float_surface_num), 0, data.table::fifelse(is.na(float_surface_num) | is.na(row$float_surface_num), 9999, abs(float_surface_num - row$float_surface_num))))]
                data.table::setorder(cand, exact_match, angle_diff, surface_diff, -n_calibration, float_angle_num, float_surface_num)
                data.table::data.table(rowid = row$rowid, predicted_days_since_laying = cand$predicted_days_since_laying[1])
            }), use.names = TRUE, fill = TRUE)
            merge(dt, scored, by = "rowid", all.x = TRUE, sort = FALSE)
        }
        calib0 <- tryCatch(db_get("SELECT float_angle, float_surface, float_location, days_since_laying FROM predict_hatching"), error = function(e) NULL)
        if (is.null(calib0)) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            calib <- data.table::as.data.table(calib0)
            calib[, `:=`(float_location_key, trimws(as.character(float_location)))]
            calib[, `:=`(float_angle_num, suppressWarnings(as.numeric(as.character(float_angle))))]
            calib[, `:=`(float_surface_num, suppressWarnings(as.numeric(as.character(float_surface))))]
            calib[, `:=`(days_num, suppressWarnings(as.numeric(as.character(days_since_laying))))]
            calib <- calib[!is.na(float_location_key) & nzchar(float_location_key) & !is.na(float_angle_num) & !is.na(days_num), .(predicted_days_since_laying = mean(days_num, na.rm = TRUE), n_calibration = .N), by = .(float_location_key, float_angle_num, float_surface_num)]
            norm_time_key <- function(v) {
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
            current <- z[, .(rowid, nest_key = trimws(as.character(nest_id)), date_key = suppressWarnings(as.Date(date)), time_key = norm_time_key(time_visit), observer_key = trimws(as.character(observer)), float_location_key = trimws(as.character(float_location)), float_angle_num = suppressWarnings(as.numeric(as.character(float_angle))), float_surface_num = suppressWarnings(as.numeric(as.character(float_surface))))]
            current <- current[!is.na(nest_key) & nzchar(nest_key) & !is.na(date_key) & !is.na(time_key) & nzchar(time_key) & !is.na(observer_key) & nzchar(observer_key) & !is.na(float_location_key) & nzchar(float_location_key) & !is.na(float_angle_num)]
            ref0 <- tryCatch(db_get("SELECT nest_id, date, time_visit, observer, float_angle, float_surface, float_location FROM EGGS"), error = function(e) NULL)
            if (is.null(ref0)) {
                combined <- current
            } else {
                ref <- data.table::as.data.table(ref0)
                ref[, `:=`(rowid, -seq_len(.N))]
                ref[, `:=`(nest_key, trimws(as.character(nest_id)))]
                ref[, `:=`(date_key, suppressWarnings(as.Date(date)))]
                ref[, `:=`(time_key, norm_time_key(time_visit))]
                ref[, `:=`(observer_key, trimws(as.character(observer)))]
                ref[, `:=`(float_location_key, trimws(as.character(float_location)))]
                ref[, `:=`(float_angle_num, suppressWarnings(as.numeric(as.character(float_angle))))]
                ref[, `:=`(float_surface_num, suppressWarnings(as.numeric(as.character(float_surface))))]
                ref <- ref[!is.na(nest_key) & nzchar(nest_key) & !is.na(date_key) & !is.na(time_key) & nzchar(time_key) & !is.na(observer_key) & nzchar(observer_key) & !is.na(float_location_key) & nzchar(float_location_key) & !is.na(float_angle_num), .(rowid, nest_key, date_key, time_key, observer_key, float_location_key, float_angle_num, float_surface_num)]
                combined <- data.table::rbindlist(list(current, ref), use.names = TRUE, fill = TRUE)
            }
            if (nrow(combined) == 0) {
                data.table::data.table(rowid = integer(), variable = character(), reason = character())
            } else {
                predicted <- nearest_prediction(combined, calib)
                current_keys <- unique(current[, .(nest_key, date_key, time_key, observer_key)])
                spreads <- predicted[current_keys, on = c("nest_key", "date_key", "time_key", "observer_key"), nomatch = 0L][!is.na(predicted_days_since_laying), .(day_span = max(predicted_days_since_laying) - min(predicted_days_since_laying)), by = .(nest_key, date_key, time_key, observer_key)]
                bad_keys <- spreads[day_span > 7, .(nest_key, date_key, time_key, observer_key)]
                if (nrow(bad_keys) == 0) {
                    data.table::data.table(rowid = integer(), variable = character(), reason = character())
                } else {
                    merge(current[, .(rowid, nest_key, date_key, time_key, observer_key)], bad_keys, by = c("nest_key", "date_key", "time_key", "observer_key"))[, .(rowid, variable = "float_angle", reason = "Based on their floatation data, the developmental stage of this nest's eggs differ by more than 7 days, please double-check your floatation data")][, unique(.SD)]
                }
            }
        }
    }, nam = "EGG_W004 stage spread")
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
        event_keys <- unique(z[, .(nest_id = trimws(as.character(nest_id)), date = suppressWarnings(as.Date(date)), time_visit = norm_time_key(time_visit), time_min = to_minutes(time_visit), observer = trimws(as.character(observer)))])
        nests <- data.table::as.data.table(db_get("SELECT nest_id, date, time_visit, observer FROM NESTS"))
        nests[, `:=`(nest_id, trimws(as.character(nest_id)))]
        nests[, `:=`(date, suppressWarnings(as.Date(date)))]
        nests[, `:=`(time_visit, norm_time_key(time_visit))]
        nests[, `:=`(time_min_nest, to_minutes(time_visit))]
        nests[, `:=`(observer, trimws(as.character(observer)))]
        match_candidates <- merge(
            event_keys,
            nests[, .(nest_id, date, observer, time_min_nest)],
            by = c("nest_id", "date", "observer"),
            all.x = TRUE,
            allow.cartesian = TRUE
        )
        matched_keys <- if (nrow(match_candidates) == 0) {
            data.table::data.table(nest_id = character(), date = as.Date(character()), time_visit = character(), observer = character())
        } else {
            unique(match_candidates[
                !is.na(time_min) & !is.na(time_min_nest) & abs(time_min - time_min_nest) <= 60,
                .(nest_id, date, time_visit, observer)
            ])
        }
        bad_keys <- event_keys[!matched_keys, on = c("nest_id", "date", "time_visit", "observer")]
        if (nrow(bad_keys) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            merge(z[, .(rowid, nest_id = trimws(as.character(nest_id)), date = suppressWarnings(as.Date(date)), time_visit = norm_time_key(time_visit), observer = trimws(as.character(observer)))], bad_keys[, .(nest_id, date, time_visit, observer)], by = c("nest_id", "date", "time_visit", "observer"))[, .(rowid, variable = "nest_id", reason = "Each EGGS event should usually match a NESTS event with the same nest_id, date, and observer, with time_visit within one hour.")][, unique(.SD)]
        }
    }, nam = "EGG_005 event match")
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
        flagged <- z[grepl("star|starred|pip|pipping", trimws(as.character(comments)), ignore.case = TRUE) & (!is.na(float_location) | !is.na(float_angle) | !is.na(float_surface)), .(rowid, variable = "float_location", reason = "Starred or pipping eggs should usually not be floated.")]
        if (nrow(flagged) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            flagged
        }
    }, nam = "EGG_007 starred no float")
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
