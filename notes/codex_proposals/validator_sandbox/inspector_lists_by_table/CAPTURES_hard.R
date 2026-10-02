list({
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        missing_like <- function(v) {
            raw <- trimws(as.character(v))
            is.na(v) | !nzchar(raw) | raw == "NA"
        }
        status_chr <- trimws(as.character(z$capture_status))
        status_chr[is.na(z$capture_status) | !nzchar(status_chr) | status_chr == "NA"] <- NA_character_
        age_chr <- trimws(as.character(z$age))
        age_chr[is.na(z$age) | !nzchar(age_chr) | age_chr == "NA"] <- NA_character_
        caught_with_chr <- trimws(as.character(z$caught_with))
        caught_with_chr[is.na(z$caught_with) | !nzchar(caught_with_chr) | caught_with_chr == "NA"] <- NA_character_
        always_required <- c("date", "caught", "species", "site", "observer", "capture_status", "capture_method", "field_sex", "age", "ring")
        conditional_required <- c("UL", "LL", "UR", "LR")
        nest_key <- trimws(as.character(z$nest_id))
        has_positive_nest <- !missing_like(z$nest_id) & toupper(nest_key) != "NO_NEST" & !grepl("^-", nest_key)
        has_negative_brood <- !missing_like(z$nest_id) & grepl("^-", nest_key)
        first_chick_capture <- !is.na(age_chr) & toupper(age_chr) == "C" & status_chr == "F"
        adult_captured_with_chicks <- !is.na(age_chr) & toupper(age_chr) == "A" &
            !is.na(caught_with_chr) & grepl("(^|,)\\s*[0-9]*C\\s*(,|$)", caught_with_chr, perl = TRUE)
        has_real_nest_or_brood <- has_positive_nest | has_negative_brood
        optional_positive_nest_gps <- has_positive_nest & (first_chick_capture | adult_captured_with_chicks)
        adult_with_chicks_positive_nest <- has_positive_nest & adult_captured_with_chicks
        gps_id_entered <- !missing_like(z$gps_id)
        gps_point_entered <- !missing_like(z$gps_point)
        has_any_gps <- gps_id_entered | gps_point_entered
        gps_required <- (!has_positive_nest & !first_chick_capture) | has_negative_brood | adult_with_chicks_positive_nest
        optional_positive_nest_partial_gps <- has_positive_nest & first_chick_capture & xor(gps_id_entered, gps_point_entered)
        nest_gps_conflicts <- {
            bad_idx <- which(has_positive_nest & has_any_gps & !optional_positive_nest_gps)
            if (length(bad_idx) == 0) {
                NULL
            } else {
                data.table::rbindlist(lapply(bad_idx, function(i) {
                    variables <- c(
                        if (isTRUE(gps_id_entered[i])) "gps_id" else NULL,
                        if (isTRUE(gps_point_entered[i])) "gps_point" else NULL
                    )
                    data.table::data.table(
                        rowid = z$rowid[i],
                        variable = variables,
                        reason = "Positive nest-linked captures normally leave gps_id and gps_point blank and use the nest location. If an adult was captured with chicks from this nest, enter both GPS fields and record the chicks in caught_with (for example, 2C)."
                    )
                }), use.names = TRUE, fill = TRUE)
            }
        }
        out_parts <- c(
            lapply(always_required, function(col) {
                bad_idx <- which(missing_like(z[[col]]))
                if (length(bad_idx) == 0) {
                    return(NULL)
                }
                data.table::data.table(
                    rowid = z$rowid[bad_idx],
                    variable = col,
                    reason = "Required capture field."
                )
            }),
            lapply(conditional_required, function(col) {
                bad_idx <- which(status_chr != "D" & missing_like(z[[col]]))
                if (length(bad_idx) == 0) {
                    return(NULL)
                }
                data.table::data.table(
                    rowid = z$rowid[bad_idx],
                    variable = col,
                    reason = "Required capture field."
                )
            }),
            list({
                bad_idx <- which(first_chick_capture & !has_real_nest_or_brood)
                if (length(bad_idx) == 0) {
                    NULL
                } else {
                    data.table::data.table(
                        rowid = z$rowid[bad_idx],
                        variable = "nest_id",
                        reason = "An age-C first-capture event (capture_status F) must include a positive nest_id or a negative nest_id (i.e., found at the brood stage)."
                    )
                }
            }),
            lapply(c("gps_id", "gps_point"), function(col) {
                bad_idx <- which(gps_required & missing_like(z[[col]]))
                if (length(bad_idx) == 0) {
                    return(NULL)
                }
                negative_idx <- bad_idx[has_negative_brood[bad_idx]]
                adult_brood_idx <- bad_idx[adult_with_chicks_positive_nest[bad_idx]]
                ordinary_idx <- setdiff(bad_idx, c(negative_idx, adult_brood_idx))
                pieces <- list()
                if (length(negative_idx) > 0) {
                    pieces[[length(pieces) + 1L]] <- data.table::data.table(
                        rowid = z$rowid[negative_idx],
                        variable = col,
                        reason = "Negative nest_id values identify broods found after hatching and require both gps_id and gps_point because there is no NESTS location."
                    )
                }
                if (length(adult_brood_idx) > 0) {
                    pieces[[length(pieces) + 1L]] <- data.table::data.table(
                        rowid = z$rowid[adult_brood_idx],
                        variable = col,
                        reason = "An adult captured with chicks from a positive nest must record both gps_id and gps_point because the capture may be away from the nest."
                    )
                }
                if (length(ordinary_idx) > 0) {
                    pieces[[length(pieces) + 1L]] <- data.table::data.table(
                        rowid = z$rowid[ordinary_idx],
                        variable = col,
                        reason = "A GPS ID and GPS point are required when this capture is not linked to a positive nest."
                    )
                }
                data.table::rbindlist(pieces, use.names = TRUE, fill = TRUE)
            }),
            list({
                bad_idx <- which(optional_positive_nest_partial_gps)
                if (length(bad_idx) == 0) {
                    NULL
                } else {
                    data.table::rbindlist(lapply(bad_idx, function(i) {
                        variables <- c(
                            if (!isTRUE(gps_id_entered[i])) "gps_id" else NULL,
                            if (!isTRUE(gps_point_entered[i])) "gps_point" else NULL
                        )
                        data.table::data.table(
                            rowid = z$rowid[i],
                            variable = variables,
                            reason = "gps_id and gps_point must be entered together when a positive-nest chick is captured away from the nest or an adult is captured with chicks."
                        )
                    }), use.names = TRUE, fill = TRUE)
                }
            }),
            list(nest_gps_conflicts)
        )
        out_parts <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, out_parts)
        if (length(out_parts) == 0) {
            empty
        } else {
            unique(data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE))
        }
    }, nam = "CAP_001 mandatory")
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
        ring_key <- trimws(as.character(z$ring))
        bad_idx <- which(!is.na(z$ring) & nzchar(ring_key) & !grepl("^CP-?[0-9]{5}$", ring_key))
        if (length(bad_idx) == 0) {
            empty
        } else {
            data.table::data.table(
                rowid = z$rowid[bad_idx],
                variable = "ring",
                reason = "Ring must use CP followed by five digits, with an optional dash, e.g. CP12345 or CP-12345."
            )
        }
    }, nam = "CAP_001A ring format")
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
        z[, `:=`(rowid, .I)]
        is.element_validator(z[!is.na(site), .(site, rowid)], v = data.table::data.table(variable = "site", set = list(c("AR", "AU", "CH", "CL", "CR", "HC", "HR", "KK", "KP", "KT", "MB", "MR", "MS", "OD", "OK", "OM", "PB", "PR", "TA", "TO", "TP", "TR", "TS", "WA", "WN", "WS"))), reason = "Site must be a valid BDOT site code.")
    }, nam = "GLOBAL_003 site")
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
        raw_id <- trimws(as.character(z$gps_id))
        raw_point <- trimws(as.character(z$gps_point))
        gps_id_num <- suppressWarnings(as.integer(raw_id))
        gps_point_num <- suppressWarnings(as.integer(raw_point))
        check_idx <- which(!is.na(z$gps_id) & nzchar(raw_id) & !is.na(z$gps_point) & nzchar(raw_point) & !is.na(gps_id_num) & !is.na(gps_point_num))
        if (length(check_idx) == 0) {
            empty
        } else {
            ref0 <- tryCatch(db_get("SELECT gps_id, gps_point FROM GPS_POINTS"), error = function(e) NULL)
            if (is.null(ref0)) {
                data.table::data.table(rowid = z$rowid[check_idx], variable = "gps_point", reason = "Could not confirm gps_id and gps_point against GPS_POINTS. Confirm the GPS was uploaded via gpxui before entering events.")
            } else {
                ref <- data.table::as.data.table(ref0)
                ref[, `:=`(gps_id_num, suppressWarnings(as.integer(as.character(gps_id))))]
                ref[, `:=`(gps_point_num, suppressWarnings(as.integer(as.character(gps_point))))]
                ref_key <- unique(ref[!is.na(gps_id_num) & !is.na(gps_point_num), .(gps_id_num, gps_point_num)])
                current <- data.table::data.table(rowid = z$rowid[check_idx], gps_id_num = gps_id_num[check_idx], gps_point_num = gps_point_num[check_idx])
                out <- current[!ref_key, on = .(gps_id_num, gps_point_num)]
                if (nrow(out) == 0) {
                    empty
                } else {
                    out[, .(rowid, variable = "gps_point", reason = "gps_id and gps_point must already exist in GPS_POINTS. Upload the GPS first via gpxui.")]
                }
            }
        }
    }, nam = "GLOBAL_005A gps points")
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
        if (!"nov" %in% names(z)) {
            empty
        } else {
            out <- z[!is.na(nov), .(rowid, variable = "nov", reason = "Validation flag must stay blank.")]
            if (nrow(out) == 0) {
                empty
            } else {
                unique(out)
            }
        }
    }, nam = "GLOBAL_004 system blank")
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
            data.table::data.table(rowid = bad_idx, variable = "observer", reason = "Observer must exist in OBSERVERS and be active on the capture date.")
        }
    }, nam = "CAP_002 observer active")
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
        out <- data.table::rbindlist(list(z[is.na(book_id) | !(book_id %in% 1:5), .(rowid, variable = "book_id", reason = "book_id must be one of 1 to 5.")], z[is.na(form_id) | form_id < 1, .(rowid, variable = "form_id", reason = "form_id must be a positive integer.")]), use.names = TRUE, fill = TRUE)
        dup <- z[!is.na(book_id) & !is.na(form_id), .N, by = .(book_id, form_id)][N > 1]
        if (nrow(dup) > 0) {
            out <- data.table::rbindlist(list(out, merge(z, dup, by = c("book_id", "form_id"))[, .(rowid, variable = "form_id", reason = "Each [book_id, form_id] pair must represent only one capture event.")]), use.names = TRUE, fill = TRUE)
        }
        if (nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            unique(out)
        }
    }, nam = "CAP_003 004 book form")
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
        one_chr <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            if (length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA") {
                NA_character_
            } else {
                raw
            }
        }
        to_minutes <- function(v) {
            raw <- one_chr(v)
            if (is.na(raw)) {
                return(NA_real_)
            }
            raw <- substr(raw, 1, 5)
            if (!grepl("^\\d{2}:\\d{2}$", raw)) {
                return(NA_real_)
            }
            hh <- suppressWarnings(as.integer(substr(raw, 1, 2)))
            mm <- suppressWarnings(as.integer(substr(raw, 4, 5)))
            if (is.na(hh) || is.na(mm) || hh < 0 || hh > 23 || mm < 0 || mm > 59) {
                return(NA_real_)
            }
            hh * 60 + mm
        }
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            status_val <- one_chr(row$capture_status)
            caught_t <- to_minutes(row$caught)
            rel_t <- to_minutes(row$released)
            released_raw <- one_chr(row$released)
            problems <- list()
            if (identical(status_val, "D")) {
                if (!is.na(released_raw)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "released", reason = "Released must be blank when capture_status is D.")
                }
            } else {
                if (!is.na(caught_t) && !is.na(rel_t) && caught_t >= rel_t) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "released", reason = "Caught must be before released.")
                }
            }
            if (length(problems) == 0) empty else data.table::rbindlist(problems)
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "CAP_005 time order")
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
        z <- x[, .(capture_status)]
        is.element_validator(z, v = data.table::data.table(variable = "capture_status", set = list(c("F", "R", "C", "D"))), reason = "capture_status must be F, R, C, or D.")
    }, nam = "CAP_006 status")
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
        one_chr <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            if (length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA") {
                NA_character_
            } else {
                raw
            }
        }
        is_positive_nest <- function(v) {
            !is.na(v) && nzchar(v) && toupper(v) != "NO_NEST" && !grepl("^-", v)
        }
        is_real_nest <- function(v) {
            !is.na(v) && nzchar(v) && toupper(v) != "NO_NEST"
        }
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            method_val <- one_chr(row$capture_method)
            nest_val <- one_chr(row$nest_id)
            if (is.na(method_val)) {
                return(empty)
            }
            if (identical(method_val, "TN") && !is_positive_nest(nest_val)) {
                return(data.table::data.table(
                    rowid = row$rowid,
                    variable = "capture_method",
                    reason = "capture_method TN requires a positive nest_id."
                ))
            }
            if (identical(method_val, "TB") && !is_real_nest(nest_val)) {
                return(data.table::data.table(
                    rowid = row$rowid,
                    variable = "capture_method",
                    reason = "capture_method TB requires either a positive nest_id or a negative nest_id (i.e., found at the brood stage). Please check the nest linkage."
                ))
            }
            empty
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "CAP_006B method nest")
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
        cr_pos <- "^[ABC][0-9]{4}$"
        noncr_pos <- "^BA[0-9]{4}$"
        cr_neg <- "^-[ABC][0-9]{4}$"
        noncr_neg <- "^-BA[0-9]{4}$"
        nest_chr <- trimws(as.character(z$nest_id))
        bad_idx <- which(
            !is.na(z$nest_id) &
                nzchar(nest_chr) &
                nest_chr != "NO_NEST" &
                !(
                    (z$site == "CR" & grepl(cr_pos, nest_chr) & !grepl("^-", nest_chr)) |
                    (z$site == "CR" & grepl(cr_neg, nest_chr)) |
                    (z$site != "CR" & grepl(noncr_pos, nest_chr) & !grepl("^-", nest_chr)) |
                    (z$site != "CR" & grepl(noncr_neg, nest_chr))
                )
        )
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "nest_id", reason = "nest_id must be NO_NEST or match the current site-specific nest_id format.")
        }
    }, nam = "CAP_009 nest id")
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
        bad_idx <- z[(age %in% c("C", "J") & field_sex != "U") | (age == "A" & !(field_sex %in% c("M", "MU", "F", "FU"))), rowid]
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = bad_idx, variable = "field_sex", reason = "field_sex must follow the age-specific coding rule.")
        }
    }, nam = "CAP_010 field sex")
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
        chick_colours <- c("R", "B", "G", "W", "O", "L", "Y")
        cr_adult_ll <- c("YR", "YO", "YY", "GY", "BY", "WY", "OY", "LY")
        juvenile_flag <- "^FW[A-Z0-9]{2}$"
        geotag_upper <- "^T([RBGWOLY])?$"
        normalize_tag_code <- function(v) {
            out <- trimws(as.character(v))
            out[out %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(out) & grepl("^T[A-Z0-9]*[RBGWOLY]$", out)
            out[tag_like] <- paste0("T", sub("^.*([RBGWOLY])$", "\\1", out[tag_like]))
            out
        }
        one_chr <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            if (length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA") {
                NA_character_
            } else {
                raw
            }
        }
        has_upper_tag <- function(v) {
            !is.na(v) && grepl(geotag_upper, v)
        }
        count_upper_tags <- function(left_code, right_code) {
            sum(vapply(c(left_code, right_code), has_upper_tag, logical(1)))
        }
        is_blank_band <- function(v) {
            is.na(v) || identical(v, "X")
        }
        is_cr_chick_scheme <- function(ul, ll, ur, lr) {
            is_blank_band(ul) && ll %in% chick_colours && ur == "M" && is_blank_band(lr)
        }
        is_noncr_chick_scheme <- function(ul, ll, ur, lr) {
            ul == "M" && is_blank_band(ll) && is_blank_band(ur) && lr %in% chick_colours
        }
        is_juvenile_scheme <- function(ul, ll, ur, lr) {
            !is.na(ul) && grepl(juvenile_flag, ul) && is_blank_band(ll) && ur == "M" && is_blank_band(lr)
        }
        normalize_history_ring <- function(v) {
            out <- trimws(as.character(v))
            out[is.na(v) | out %in% c("", "NA")] <- NA_character_
            toupper(out)
        }
        # A ring in CAPTURES_ARCHIVE is an unambiguous prior individual.  A
        # ring already present in current-season CAPTURES is also prior
        # history for the normal append workflow (for example, CP19847 has a
        # current-season F row before its R row).  Keep this lookup advisory:
        # CAP_013 still enforces the row-level R/C combo rules independently.
        archived_ring_keys <- tryCatch(
            normalize_history_ring(
                data.table::as.data.table(db_get("SELECT ring FROM CAPTURES_ARCHIVE"))$ring
            ),
            error = function(e) character()
        )
        current_ring_keys <- tryCatch(
            normalize_history_ring(
                data.table::as.data.table(db_get("SELECT ring FROM CAPTURES"))$ring
            ),
            error = function(e) character()
        )
        recapture_ring_keys <- unique(c(
            archived_ring_keys[!is.na(archived_ring_keys)],
            current_ring_keys[!is.na(current_ring_keys)]
        ))
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            problems <- list()
            norm_mark_vec <- function(vals, blank_as = NA_character_) {
                out <- trimws(as.character(vals))
                out[is.na(out) | out == ""] <- blank_as
                out <- normalize_tag_code(out)
                out
            }
            input_marks_first <- norm_mark_vec(unlist(row[, .(UL_in, LL_in, UR_in, LR_in)]), blank_as = "X")
            names(input_marks_first) <- c("UL_in", "LL_in", "UR_in", "LR_in")
            input_marks <- norm_mark_vec(unlist(row[, .(UL_in, LL_in, UR_in, LR_in)]), blank_as = NA_character_)
            names(input_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
            release_marks <- norm_mark_vec(unlist(row[, .(UL, LL, UR, LR)]), blank_as = NA_character_)
            names(release_marks) <- c("UL", "LL", "UR", "LR")
            release_marks_scheme <- norm_mark_vec(unlist(row[, .(UL, LL, UR, LR)]), blank_as = "X")
            names(release_marks_scheme) <- c("UL", "LL", "UR", "LR")
            input_all_x <- all(input_marks_first == "X")
            release_all_x <- all(replace(release_marks, is.na(release_marks), "") == "X")
            same_combo <- identical(unname(input_marks), unname(release_marks))
            age_val <- one_chr(row$age)
            status_val <- one_chr(row$capture_status)
            site_val <- one_chr(row$site)
            if (identical(status_val, "F")) {
                if (!input_all_x) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UL_in", reason = "First-marking captures must have all input band positions set to X or left blank.")
                }
                if (release_all_x) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UL", reason = "First-marking captures must not leave all release band positions as X.")
                }
            }
            if (status_val %in% c("R", "C") && (any(is.na(input_marks)) || any(is.na(release_marks)))) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UL_in", reason = "Statuses R and C require all input and release band positions to be entered.")
            }
            r_mark_mismatch <- any(
                !is.na(input_marks) &
                    (is.na(release_marks) | input_marks != release_marks)
            )
            if (identical(status_val, "R") && r_mark_mismatch) {
                ring_key <- normalize_history_ring(row$ring)[[1]]
                ring_has_history <- !is.na(ring_key) && ring_key %in% recapture_ring_keys
                problems[[length(problems) + 1L]] <- data.table::data.table(
                    rowid = row$rowid,
                    variable = if (ring_has_history) "capture_status" else "UL",
                    reason = if (ring_has_history) {
                        "Looks like you changed the bands on this bird after recapture, capture_status should be 'C'"
                    } else {
                        "Recaptures with status R must keep the same band positions before and after handling."
                    }
                )
            }
            if (identical(status_val, "C") && input_all_x) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UL_in", reason = "Status C requires at least one non-X input mark before the release combo is changed.")
            }
            if (identical(status_val, "C") && !any(is.na(input_marks)) && !any(is.na(release_marks)) && same_combo) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UL", reason = "Status C requires at least one change between input and release band positions.")
            }
            if (identical(status_val, "D")) {
                if (any(is.na(input_marks))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UL_in", reason = "Dead-on-capture rows must record the recovered combo in all input band positions.")
                }
                if (any(!is.na(release_marks))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UL", reason = "Dead-on-capture rows must leave all release band positions blank.")
                }
            }
            if (count_upper_tags(input_marks["UL_in"], input_marks["UR_in"]) > 1) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UL_in", reason = "Only one T allowed across upper leg positions.")
            }
            if (count_upper_tags(release_marks["UL"], release_marks["UR"]) > 1) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UL", reason = "Only one T allowed across upper leg positions.")
            }
            for (nm in c("LL_in", "LR_in")) {
                if (!is.na(input_marks[nm]) && grepl("^T", input_marks[nm])) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = nm, reason = "T codes are only allowed in upper leg positions.")
                }
            }
            for (nm in c("LL", "LR")) {
                if (!is.na(release_marks[nm]) && grepl("^T", release_marks[nm])) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = nm, reason = "T codes are only allowed in upper leg positions.")
                }
            }
            if (identical(age_val, "C")) {
                chick_ok <- if (identical(site_val, "CR")) {
                    is_cr_chick_scheme(
                      one_chr(release_marks_scheme["UL"]),
                      one_chr(release_marks_scheme["LL"]),
                      one_chr(release_marks_scheme["UR"]),
                      one_chr(release_marks_scheme["LR"])
                    )
                } else {
                    is_noncr_chick_scheme(
                      one_chr(release_marks_scheme["UL"]),
                      one_chr(release_marks_scheme["LL"]),
                      one_chr(release_marks_scheme["UR"]),
                      one_chr(release_marks_scheme["LR"])
                    )
                }
                if (!chick_ok || !(status_val %in% c("F", "R"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(
                    rowid = row$rowid,
                    variable = "UL",
                    reason = if (identical(site_val, "CR")) {
                      "CR chick captures must use LL as a single colour, UR as M, and blank UL/LR positions, with status F or R."
                    } else {
                      "Non-CR chick captures must use UL as M, LR as a single colour, and blank LL/UR positions, with status F or R."
                    }
                  )
                }
            }
            if (identical(age_val, "J")) {
                if (!is_juvenile_scheme(
                  one_chr(release_marks_scheme["UL"]),
                  one_chr(release_marks_scheme["LL"]),
                  one_chr(release_marks_scheme["UR"]),
                  one_chr(release_marks_scheme["LR"])
                ) || !(status_val %in% c("F", "C"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UL", reason = "Juvenile captures must use a flag code on UL, blank LL/LR positions, UR as M, and status F or C.")
                }
            }
            if (identical(age_val, "A")) {
                if (!identical(status_val, "D") && identical(site_val, "CR") && !is.na(one_chr(release_marks_scheme["LL"])) && !(one_chr(release_marks_scheme["LL"]) %in% cr_adult_ll)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "LL", reason = "CR adult captures must use LL as one of YR, YO, YY, GY, BY, WY, OY, or LY; dead-on-capture status D rows may leave UL, LL, UR, and LR blank.")
                }
                if (!identical(status_val, "D") && !is.na(site_val) && site_val != "CR" && !is.na(one_chr(release_marks_scheme["LL"])) && one_chr(release_marks_scheme["LL"]) %in% cr_adult_ll) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "LL", reason = "Non-CR adult captures must not use the CR adult LL combinations YR, YO, YY, GY, BY, WY, OY, or LY.")
                }
                if (is_cr_chick_scheme(
                  one_chr(release_marks_scheme["UL"]),
                  one_chr(release_marks_scheme["LL"]),
                  one_chr(release_marks_scheme["UR"]),
                  one_chr(release_marks_scheme["LR"])
                ) || is_noncr_chick_scheme(
                  one_chr(release_marks_scheme["UL"]),
                  one_chr(release_marks_scheme["LL"]),
                  one_chr(release_marks_scheme["UR"]),
                  one_chr(release_marks_scheme["LR"])
                ) || is_juvenile_scheme(
                  one_chr(release_marks_scheme["UL"]),
                  one_chr(release_marks_scheme["LL"]),
                  one_chr(release_marks_scheme["UR"]),
                  one_chr(release_marks_scheme["LR"])
                )) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UL", reason = "Adult captures may not use the chick or juvenile release marking schemes.")
                }
            }
            tag_id_val <- one_chr(row$tag_id)
            tag_id_in_val <- one_chr(row$tag_id_in)
            tag_type_val <- one_chr(row$tag_type)
            tag_action_val <- one_chr(row$tag_action)
            release_ul_tag <- has_upper_tag(one_chr(release_marks["UL"]))
            release_ur_tag <- has_upper_tag(one_chr(release_marks["UR"]))
            input_ul_tag <- has_upper_tag(one_chr(input_marks["UL_in"]))
            input_ur_tag <- has_upper_tag(one_chr(input_marks["UR_in"]))
            release_geotag <- release_ul_tag || release_ur_tag
            input_geotag <- input_ul_tag || input_ur_tag
            tag_involved <- release_geotag || input_geotag || !is.na(tag_id_val) || !is.na(tag_id_in_val) || !is.na(tag_action_val) || !is.na(tag_type_val)
            if (age_val %in% c("C", "J") && tag_involved) {
                if (release_geotag || input_geotag) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UR", reason = "Chick and juvenile captures must leave tag-related leg codes blank.")
                }
                if (!is.na(tag_id_val)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id", reason = "Chick and juvenile captures must leave tag fields blank.")
                }
                if (!is.na(tag_id_in_val)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id_in", reason = "Chick and juvenile captures must leave tag fields blank.")
                }
                if (!is.na(tag_type_val)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_type", reason = "Chick and juvenile captures must leave tag fields blank.")
                }
                if (!is.na(tag_action_val)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_action", reason = "Chick and juvenile captures must leave tag fields blank.")
                }
            } else if (release_geotag || input_geotag) {
                if (!identical(tag_type_val, "GEO")) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_type", reason = "Short UR tag codes such as TY are reserved for GEO tags.")
                }
                if (release_geotag && is.na(tag_id_val)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id", reason = "Release GEO tag code requires tag_id.")
                }
                if (input_geotag && is.na(tag_id_in_val)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id_in", reason = "Input GEO tag code requires tag_id_in.")
                }
                if (identical(tag_type_val, "GEO") && tag_action_val %in% c("D", "S", "N") && !release_geotag) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UR", reason = "Release GEO tags must use a short upper-leg T code such as TY.")
                }
                if (identical(tag_type_val, "GEO") && tag_action_val %in% c("S", "N", "R") && !input_geotag) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UR_in", reason = "Input GEO tags must use a short upper-leg T code such as TY.")
                }
                if (release_geotag && !(tag_action_val %in% c("D", "S", "N"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_action", reason = "Release GEO tag codes require tag_action D, S, or N.")
                }
                if (input_geotag && !(tag_action_val %in% c("S", "N", "R"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_action", reason = "Input GEO tag codes require tag_action S, N, or R.")
                }
                if (identical(tag_action_val, "D")) {
                  if (input_geotag) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UR_in", reason = "tag_action D means the bird must not already carry a tag in the input combo.")
                  }
                }
                if (identical(tag_action_val, "R")) {
                  if (release_geotag) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "UR", reason = "tag_action R means the bird must not retain a tag in the release combo.")
                  }
                }
                if (identical(tag_action_val, "O") && (!is.na(tag_id_val) || !is.na(tag_id_in_val) || release_geotag || input_geotag)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_action", reason = "tag_action O can only be used when no tag is present at capture or release.")
                }
                if (is.na(tag_id_val) && is.na(tag_id_in_val) && !release_geotag && !input_geotag) {
                  if (!is.na(tag_type_val)) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_type", reason = "tag_type must be blank when no tag is present.")
                  }
                  if (!identical(tag_action_val, "O")) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_action", reason = "tag_action must be O when no tag is present.")
                  }
                }
            }
            if (identical(age_val, "A")) {
                if (identical(tag_action_val, "D")) {
                  if (is.na(tag_id_val)) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id", reason = "tag_action D requires the newly deployed tag in tag_id.")
                  }
                  if (!is.na(tag_id_in_val)) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id_in", reason = "tag_action D requires tag_id_in to be blank.")
                  }
                }
                if (identical(tag_action_val, "R")) {
                  if (is.na(tag_id_in_val)) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id_in", reason = "tag_action R requires the retrieved tag in tag_id_in.")
                  }
                  if (!is.na(tag_id_val)) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id", reason = "tag_action R requires release tag_id to be blank.")
                  }
                }
                if (identical(tag_action_val, "S")) {
                  if (is.na(tag_id_in_val)) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id_in", reason = "tag_action S requires the retained tag in tag_id_in.")
                  }
                  if (is.na(tag_id_val)) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id", reason = "tag_action S requires the retained tag in tag_id.")
                  }
                  if (!is.na(tag_id_val) && !is.na(tag_id_in_val) && tag_id_val != tag_id_in_val) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id", reason = "tag_action S requires the same tag_id before and after release.")
                  }
                }
                if (identical(tag_action_val, "N")) {
                  if (is.na(tag_id_in_val)) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id_in", reason = "tag_action N requires the removed tag in tag_id_in.")
                  }
                  if (is.na(tag_id_val)) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id", reason = "tag_action N requires the newly deployed tag in tag_id.")
                  }
                  if (!is.na(tag_id_val) && !is.na(tag_id_in_val) && tag_id_val == tag_id_in_val) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "tag_id", reason = "tag_action N requires different input and release tag IDs.")
                  }
                }
            }
            if (release_geotag || input_geotag || !is.na(tag_id_val) || !is.na(tag_id_in_val) || !is.na(tag_action_val) || !is.na(tag_type_val)) {
                wt_w_tag_val <- one_chr(row$wt_w_tag)
                if (is.na(wt_w_tag_val) || !(wt_w_tag_val %in% c("0", "1"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "wt_w_tag", reason = "wt_w_tag must be 0 or 1 when a capture involves a tag.")
                }
            }
            if (length(problems) == 0) empty else data.table::rbindlist(problems)
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "CAP_013 014 017 marks")
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
        clean_text <- function(v) {
            raw <- toupper(trimws(as.character(v)))
            raw[is.na(v) | !nzchar(raw) | raw == "NA"] <- NA_character_
            raw
        }
        parse_event_datetime <- function(date_v, time_v) {
            date_raw <- substr(trimws(as.character(date_v)), 1, 10)
            time_raw <- trimws(as.character(time_v))
            time_raw[is.na(time_v) | !nzchar(time_raw) | time_raw == "NA"] <- NA_character_
            short_time <- !is.na(time_raw) & nchar(time_raw) == 5
            time_raw[short_time] <- paste0(time_raw[short_time], ":00")
            suppressWarnings(as.POSIXct(
                paste(date_raw, time_raw),
                format = "%Y-%m-%d %H:%M:%S",
                tz = "Pacific/Auckland"
            ))
        }
        z[, `:=`(
            ring_key = clean_text(ring),
            tag_id_in_key = clean_text(tag_id_in),
            tag_id_key = clean_text(tag_id),
            tag_action_key = clean_text(tag_action)
        )]
        z[, `:=`(event_dt = parse_event_datetime(date, caught))]
        candidates <- z[
            tag_action_key %in% c("D", "R", "S", "N") &
            !is.na(event_dt) &
            !is.na(ring_key) &
            (
              (tag_action_key == "D" & !is.na(tag_id_key) & is.na(tag_id_in_key)) |
              (tag_action_key == "R" & is.na(tag_id_key) & !is.na(tag_id_in_key)) |
              (tag_action_key == "S" & !is.na(tag_id_key) & !is.na(tag_id_in_key) & tag_id_key == tag_id_in_key) |
              (tag_action_key == "N" & !is.na(tag_id_key) & !is.na(tag_id_in_key) & tag_id_key != tag_id_in_key)
            )
        ]
        if (nrow(candidates) == 0) {
            empty
        } else {
            saved_result <- tryCatch(
                db_get("SELECT date, caught, ring, tag_id_in, tag_id, tag_action, pk FROM CAPTURES"),
                error = function(e) e
            )
            if (inherits(saved_result, "error") || inherits(saved_result, "try-error")) {
                unique(candidates[, .(
                    rowid,
                    variable = "tag_action",
                    reason = "Tag history could not be checked because saved CAPTURES records were unavailable."
                )])
            } else {
                saved <- data.table::as.data.table(saved_result)
                needed <- c("date", "caught", "ring", "tag_id_in", "tag_id", "tag_action", "pk")
                for (col in setdiff(needed, names(saved))) {
                  saved[, (col) := NA]
                }
                if (nrow(saved) > 0) {
                  saved[, `:=`(
                    ring_key = clean_text(ring),
                    tag_id_in_key = clean_text(tag_id_in),
                    tag_id_key = clean_text(tag_id),
                    tag_action_key = clean_text(tag_action),
                    event_dt = parse_event_datetime(date, caught),
                    current_rowid = NA_integer_,
                    source_rank = 0L,
                    order_id = suppressWarnings(as.numeric(pk))
                  )]
                  saved[is.na(order_id), `:=`(order_id, .I)]
                } else {
                  saved <- data.table::data.table(
                    ring_key = character(), tag_id_in_key = character(), tag_id_key = character(),
                    tag_action_key = character(), event_dt = as.POSIXct(character()),
                    current_rowid = integer(), source_rank = integer(), order_id = numeric()
                  )
                }
                current <- z[, .(
                  ring_key, tag_id_in_key, tag_id_key, tag_action_key, event_dt,
                  current_rowid = rowid, source_rank = 1L, order_id = as.numeric(rowid)
                )]
                history <- data.table::rbindlist(
                  list(
                    saved[, .(ring_key, tag_id_in_key, tag_id_key, tag_action_key, event_dt, current_rowid, source_rank, order_id)],
                    current
                  ),
                  use.names = TRUE,
                  fill = TRUE
                )
                history <- history[!is.na(event_dt)]
                data.table::setorder(history, event_dt, source_rank, order_id, na.last = TRUE)
                history[, `:=`(event_seq, .I)]
                problems <- list()
                invalid_current <- integer()
                candidate_order <- candidates[order(event_dt, rowid), rowid]
                for (rid in candidate_order) {
                  row <- history[current_rowid == rid][1]
                  if (nrow(row) == 0 || is.na(row$event_seq)) {
                    next
                  }
                  prior <- history[
                    event_seq < row$event_seq &
                    !(source_rank == 1L & current_rowid %in% invalid_current)
                  ]
                  action <- row$tag_action_key[[1]]
                  ring_now <- row$ring_key[[1]]
                  tag_in <- row$tag_id_in_key[[1]]
                  tag_out <- row$tag_id_key[[1]]
                  tag_history <- function(tag) {
                    if (is.na(tag)) {
                      return(prior[0])
                    }
                    prior[
                      (!is.na(tag_id_key) & tag_id_key == tag) |
                      (!is.na(tag_id_in_key) & tag_id_in_key == tag)
                    ]
                  }
                  tag_is_active_on_ring <- function(tag) {
                    events <- tag_history(tag)
                    if (nrow(events) == 0) {
                      return(FALSE)
                    }
                    latest <- events[.N]
                    latest_action <- latest$tag_action_key[[1]]
                    latest_ring <- latest$ring_key[[1]]
                    active <-
                      (identical(latest_action, "D") && identical(latest$tag_id_key[[1]], tag)) ||
                      (identical(latest_action, "S") && identical(latest$tag_id_key[[1]], tag)) ||
                      (identical(latest_action, "N") && identical(latest$tag_id_key[[1]], tag))
                    isTRUE(active) && identical(latest_ring, ring_now)
                  }
                  out <- list()
                  if (identical(action, "D")) {
                    earlier <- tag_history(tag_out)
                    earlier_deployment <- earlier[
                      tag_action_key %in% c("D", "N") &
                      !is.na(tag_id_key) & tag_id_key == tag_out
                    ]
                    if (nrow(earlier_deployment) > 0) {
                      latest <- earlier[.N]
                      reusable <- identical(latest$tag_action_key[[1]], "R") && identical(latest$tag_id_in_key[[1]], tag_out)
                      if (!isTRUE(reusable)) {
                        out[[length(out) + 1L]] <- data.table::data.table(
                          rowid = rid,
                          variable = "tag_id",
                          reason = "This tag_id was already deployed and may only be deployed again after an earlier retrieval recorded with tag_action R and the tag in tag_id_in."
                        )
                      }
                    }
                  }
                  if (identical(action, "S") && !tag_is_active_on_ring(tag_in)) {
                    out[[length(out) + 1L]] <- data.table::data.table(
                      rowid = rid,
                      variable = "tag_action",
                      reason = "tag_action S requires this tag to be active on the same ring from an earlier deployment."
                    )
                  }
                  if (identical(action, "R") && !tag_is_active_on_ring(tag_in)) {
                    out[[length(out) + 1L]] <- data.table::data.table(
                      rowid = rid,
                      variable = "tag_action",
                      reason = "tag_action R requires tag_id_in to be active on the same ring from an earlier deployment."
                    )
                  }
                  if (identical(action, "N")) {
                    prior_d_same_ring <- prior[
                      tag_action_key == "D" &
                      !is.na(tag_id_key) & tag_id_key == tag_in &
                      !is.na(ring_key) & ring_key == ring_now
                    ]
                    if (nrow(prior_d_same_ring) == 0 || !tag_is_active_on_ring(tag_in)) {
                      out[[length(out) + 1L]] <- data.table::data.table(
                        rowid = rid,
                        variable = "tag_id_in",
                        reason = "tag_action N requires tag_id_in to identify an active tag previously deployed with tag_action D to this ring."
                      )
                    }
                    prior_new_tag <- prior[
                      tag_action_key %in% c("D", "N") &
                      !is.na(tag_id_key) & tag_id_key == tag_out
                    ]
                    if (nrow(prior_new_tag) > 0) {
                      out[[length(out) + 1L]] <- data.table::data.table(
                        rowid = rid,
                        variable = "tag_id",
                        reason = "tag_action N requires a new release tag_id that has not previously been deployed to any bird."
                      )
                    }
                  }
                  if (length(out) > 0) {
                    problems[[length(problems) + 1L]] <- data.table::rbindlist(out, use.names = TRUE, fill = TRUE)
                    invalid_current <- c(invalid_current, rid)
                  }
                }
                out <- data.table::rbindlist(problems, use.names = TRUE, fill = TRUE)
                if (nrow(out) == 0) empty else unique(out)
            }
        }
    }, nam = "CAP_017B tag history")
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
        data.table::data.table(rowid = integer(), variable = character(), reason = character())
    }, nam = "CAP_015 hatch evidence")
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
        one_chr <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            if (length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA") {
                NA_character_
            } else {
                raw
            }
        }
        normalize_time <- function(v) {
            raw <- trimws(as.character(v))
            raw[is.na(v) | !nzchar(raw) | raw == "NA"] <- "99:99"
            raw
        }
        is_positive_nest <- function(v) {
            raw <- trimws(as.character(v))
            !is.na(raw) & nzchar(raw) & raw != "NA" & toupper(raw) != "NO_NEST" & !grepl("^-", raw)
        }
        nests_dt <- data.table::as.data.table(db_get("SELECT nest_id, date, time_visit, nest_state FROM NESTS"))
        if (nrow(nests_dt) > 0) {
            nests_dt <- data.table::copy(nests_dt)
            nests_dt[, `:=`(event_date_nest, suppressWarnings(as.Date(date)))]
            nests_dt[, `:=`(time_visit_key, normalize_time(time_visit))]
            nests_dt <- nests_dt[
                nest_state == "F" &
                !is.na(event_date_nest) &
                !is.na(nest_id) &
                nzchar(trimws(as.character(nest_id))),
                .(nest_id = trimws(as.character(nest_id)), event_date_nest, time_visit_key)
            ]
            if (nrow(nests_dt) > 0) {
                data.table::setorder(nests_dt, nest_id, event_date_nest, time_visit_key)
                nests_dt <- nests_dt[, .SD[1], by = nest_id]
            }
        } else {
            nests_dt <- data.table::data.table(nest_id = character(), event_date_nest = as.Date(character()), time_visit_key = character())
        }
        z[, `:=`(event_date, suppressWarnings(as.Date(date)))]
        z[, `:=`(caught_key, normalize_time(caught))]
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            nest_key <- one_chr(row$nest_id)
            event_date_val <- row$event_date[[1]]
            caught_key_val <- row$caught_key[[1]]
            if (!is_positive_nest(nest_key) || is.na(event_date_val)) {
                return(empty)
            }
            first_f <- nests_dt[nest_id == nest_key]
            if (nrow(first_f) == 0) {
                return(data.table::data.table(
                    rowid = row$rowid,
                    variable = "nest_id",
                    reason = "Positive nest-linked capture events require a same-day-or-earlier NESTS F discovery event for this nest_id."
                ))
            }
            first_date <- first_f$event_date_nest[[1]]
            first_time <- first_f$time_visit_key[[1]]
            if (event_date_val < first_date || (event_date_val == first_date && caught_key_val < first_time)) {
                return(data.table::data.table(
                    rowid = row$rowid,
                    variable = "nest_id",
                    reason = "Positive nest-linked capture events require a same-day-or-earlier NESTS F discovery event for this nest_id."
                ))
            }
            empty
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "CAP_015B first nest event")
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
        normalize_scalar_chr <- function(v) {
            out <- trimws(as.character(v))
            out[is.na(v) | out %in% c("", "NA")] <- NA_character_
            out
        }
        normalize_tag_ur <- function(v) {
            out <- normalize_scalar_chr(v)
            tag_like <- !is.na(out) & grepl("^T[A-Z0-9]*[RBGWOLY]$", out)
            out[tag_like] <- paste0("T", sub("^.*([RBGWOLY])$", "\\1", out[tag_like]))
            out
        }
        one_chr <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            if (length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA") {
                NA_character_
            } else {
                raw
            }
        }
        canonical_left_pair <- function(ul, ll) {
            ul1 <- normalize_scalar_chr(ul)
            ll1 <- normalize_scalar_chr(ll)
            ifelse(
                !is.na(ul1) & grepl("^[RBGWOLY]$", ul1) &
                    !is.na(ll1) & grepl("^[RBGWOLY]$", ll1),
                paste0(ul1, ll1),
                ifelse(
                    (is.na(ul1) | ul1 %in% c("X", "M")) &
                        !is.na(ll1) & grepl("^[RBGWOLY]{2}$", ll1),
                    ll1,
                    ifelse(
                        (is.na(ll1) | ll1 %in% c("X", "M")) &
                            !is.na(ul1) & grepl("^[RBGWOLY]{2}$", ul1),
                        ul1,
                        NA_character_
                    )
                )
            )
        }
        canonical_right_pair <- function(ur, lr) {
            ur1 <- normalize_tag_ur(ur)
            lr1 <- normalize_scalar_chr(lr)
            ifelse(
                !is.na(ur1) & grepl("^T[RBGWOLY]$", ur1) &
                    !is.na(lr1) & grepl("^[RBGWOLY]$", lr1),
                paste0(sub("^T", "", ur1), lr1),
                ifelse(
                    !is.na(ur1) & grepl("^[RBGWOLY]$", ur1) &
                        !is.na(lr1) & grepl("^[RBGWOLY]$", lr1),
                    paste0(ur1, lr1),
                    ifelse(
                        (is.na(ur1) | ur1 %in% c("X", "M")) &
                            !is.na(lr1) & grepl("^[RBGWOLY]{2}$", lr1),
                        lr1,
                        ifelse(
                            (is.na(lr1) | lr1 %in% c("X", "M")) &
                                !is.na(ur1) & grepl("^[RBGWOLY]{2}$", ur1),
                            ur1,
                            NA_character_
                        )
                    )
                )
            )
        }
        raw_combo <- function(ul, ll, ur, lr) {
            ul1 <- normalize_scalar_chr(ul)
            ll1 <- normalize_scalar_chr(ll)
            ur1 <- normalize_tag_ur(ur)
            lr1 <- normalize_scalar_chr(lr)
            ifelse(
                is.na(ul1) | is.na(ll1) | is.na(ur1) | is.na(lr1),
                NA_character_,
                paste0(ul1, ll1, ur1, lr1)
            )
        }
        combo_identity <- function(ul, ll, ur, lr) {
            left_pair <- canonical_left_pair(ul, ll)
            right_pair <- canonical_right_pair(ur, lr)
            canonical <- ifelse(
                !is.na(left_pair) & !is.na(right_pair),
                paste0("X", left_pair, "X", right_pair),
                NA_character_
            )
            raw <- raw_combo(ul, ll, ur, lr)
            ifelse(!is.na(canonical), canonical, raw)
        }
        make_combo <- function(dt, cols) {
            mapply(
                combo_identity,
                dt[[cols[1]]],
                dt[[cols[2]]],
                dt[[cols[3]]],
                dt[[cols[4]]],
                USE.NAMES = FALSE
            )
        }
        make_raw_combo <- function(dt, cols) {
            mapply(
                raw_combo,
                dt[[cols[1]]],
                dt[[cols[2]]],
                dt[[cols[3]]],
                dt[[cols[4]]],
                USE.NAMES = FALSE
            )
        }
        # A failed archive lookup means that capture history is unknown. Keep
        # that state distinct from a successful query that returned no rows.
        archive_lookup <- tryCatch(
            list(
                ok = TRUE,
                data = data.table::as.data.table(
                    db_get("SELECT date, UL, LL, UR, LR FROM CAPTURES_ARCHIVE")
                )
            ),
            error = function(e) {
                list(
                    ok = FALSE,
                    data = data.table::data.table(
                        date = as.Date(character()),
                        UL = character(),
                        LL = character(),
                        UR = character(),
                        LR = character()
                    )
                )
            }
        )
        archive_available <- isTRUE(archive_lookup$ok)
        archive <- archive_lookup$data
        if (archive_available && nrow(archive) > 0) {
            archive[, `:=`(combo, make_combo(.SD, c("UL", "LL", "UR", "LR")))]
            archive[, `:=`(date, suppressWarnings(as.Date(date)))]
        } else {
            archive <- data.table::data.table(date = as.Date(character()), combo = character())
        }
        z[, `:=`(date, suppressWarnings(as.Date(date)))]
        z[, `:=`(combo_release, make_combo(.SD, c("UL", "LL", "UR", "LR")))]
        z[, `:=`(combo_in, make_combo(.SD, c("UL_in", "LL_in", "UR_in", "LR_in")))]
        z[, `:=`(combo_in_raw, make_raw_combo(.SD, c("UL_in", "LL_in", "UR_in", "LR_in")))]
        earlier_current <- function(i, combo_col) {
            any(
                z$rowid != z$rowid[i] &
                    !is.na(z$date) &
                    z$date < z$date[i] &
                    z[[combo_col]] == z[[combo_col]][i],
                na.rm = TRUE
            )
        }
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            status_val <- one_chr(row$capture_status)
            if (identical(status_val, "R")) {
                prior_current_batch <- earlier_current(i, "combo_release")
                prior_archive <- archive_available && any(
                    archive$combo == row$combo_release & archive$date <= row$date,
                    na.rm = TRUE
                )
                prior_exists <- prior_archive || prior_current_batch
                if (!prior_exists) {
                  if (!archive_available) {
                    return(data.table::data.table(
                        rowid = row$rowid,
                        variable = "UL",
                        reason = paste(
                            "Prior-combination checks could not be completed because",
                            "CAPTURES_ARCHIVE is unavailable; no conclusion was made about",
                            "whether this release combination exists. Please retry after",
                            "the database connection is restored."
                        )
                    ))
                  }
                  return(data.table::data.table(rowid = row$rowid, variable = "UL", reason = "Status R requires a release combo already present in capture history."))
                }
            }
            if (identical(status_val, "C")) {
                if (identical(one_chr(row$combo_in_raw), "XXXX")) {
                  return(empty)
                }
                prior_current_batch <- earlier_current(i, "combo_in")
                prior_archive <- archive_available && any(
                    archive$combo == row$combo_in & archive$date <= row$date,
                    na.rm = TRUE
                )
                prior_exists <- prior_archive || prior_current_batch
                if (!prior_exists) {
                  if (!archive_available) {
                    return(data.table::data.table(
                        rowid = row$rowid,
                        variable = "UL_in",
                        reason = paste(
                            "Prior-combination checks could not be completed because",
                            "CAPTURES_ARCHIVE is unavailable; no conclusion was made about",
                            "whether this input combination exists. Please retry after",
                            "the database connection is restored."
                        )
                    ))
                  }
                  return(data.table::data.table(rowid = row$rowid, variable = "UL_in", reason = "Status C requires an input combo already present in capture history."))
                }
            }
            empty
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "CAP_016 prior combo")
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
        one_chr <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            if (length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA") {
                NA_character_
            } else {
                raw
            }
        }
        int_val <- function(v) {
            raw <- one_chr(v)
            if (is.na(raw)) {
                NA_integer_
            } else {
                suppressWarnings(as.integer(raw))
            }
        }
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            problems <- list()
            age_val <- one_chr(row$age)
            if (identical(age_val, "A")) {
                adult_missing <- c(tarsus = is.na(row$tarsus), culmen = is.na(row$culmen), total_head = is.na(row$total_head), head_white = is.na(row$head_white), head_black = is.na(row$head_black), rufous_band = is.na(row$rufous_band), wing = is.na(row$wing), weight = is.na(row$weight))
                for (nm in names(adult_missing)[adult_missing]) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = nm, reason = "Adult captures require this morphometric field.")
                }
                if (!(row$brood_patch %in% c("0", "1"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "brood_patch", reason = "Adult captures must record brood_patch as 0 or 1.")
                }
                if (is.na(row$moult_left) && is.na(row$moult_right)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "moult_left", reason = "Adult captures require at least one moult score in moult_left or moult_right.")
                }
                if (!(one_chr(row$breast_samp) %in% c("0", "1"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "breast_samp", reason = "Adult captures must record breast_samp as 0 or 1.")
                }
                if (!(one_chr(row$primary_samp) %in% c("0", "1"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "primary_samp", reason = "Adult captures must record primary_samp as 0 or 1.")
                }
                feather_val <- one_chr(row$feather_wear)
                if (is.na(feather_val)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "feather_wear", reason = "Adult captures require feather_wear from 0 to 3.")
                }
                if (!is.na(feather_val) && !(feather_val %in% c("0", "1", "2", "3"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "feather_wear", reason = "Adult captures require feather_wear from 0 to 3 when entered.")
                }
                fat_num <- int_val(row$fat)
                if (is.na(fat_num)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "fat", reason = "Adult captures require fat from 1 to 8.")
                }
                if (!is.na(fat_num) && !(fat_num %in% 1:8)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "fat", reason = "Adult captures require fat from 1 to 8.")
                }
                if (!is.na(row$parents)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "parents", reason = "parents must be blank for adult captures.")
                }
                if (!(one_chr(row$mugshot_photo) %in% c("0", "1"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "mugshot_photo", reason = "Adult captures must record mugshot_photo as 0 or 1.")
                }
                if (!(one_chr(row$wing_photo) %in% c("0", "1"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "wing_photo", reason = "Adult captures must record wing_photo as 0 or 1.")
                }
                adult_chick_tent <- trimws(as.character(row$chick_tent_photo))
                adult_chick_hide <- trimws(as.character(row$chick_hide_photo))
                if (!(is.na(row$chick_tent_photo) || adult_chick_tent %in% c("", "0"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "chick_tent_photo", reason = "Adult captures must leave chick_tent_photo blank or use 0.")
                }
                if (!(is.na(row$chick_hide_photo) || adult_chick_hide %in% c("", "0"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "chick_hide_photo", reason = "Adult captures must leave chick_hide_photo blank or use 0.")
                }
            }
            if (identical(age_val, "C")) {
                chick_missing <- c(tarsus = is.na(row$tarsus), culmen = is.na(row$culmen), weight = is.na(row$weight))
                for (nm in names(chick_missing)[chick_missing]) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = nm, reason = "Chick captures require this morphometric field.")
                }
                for (nm in c("total_head", "head_white", "head_black", "rufous_band", "wing")) {
                  if (!is.na(row[[nm]])) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = nm, reason = "This morphometric field must be blank for chick captures.")
                  }
                }
                if (!is.na(row$brood_patch)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "brood_patch", reason = "brood_patch must be blank for chick captures.")
                }
                if (!is.na(row$moult_left) || !is.na(row$moult_right)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "moult_left", reason = "Moult fields must be blank for chick captures.")
                }
                if (!is.na(row$feather_wear)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "feather_wear", reason = "feather_wear must be blank for chick captures.")
                }
                if (!is.na(row$fat)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "fat", reason = "fat must be blank for chick captures.")
                }
                if (!is.na(row$parents) && !(row$parents %in% c("MF", "F", "M", "U1", "U2", "O"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "parents", reason = "parents for chicks must be MF, F, M, U1, U2, or O.")
                }
                if (!(row$breast_samp %in% c("0", NA_character_))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "breast_samp", reason = "Chick captures must use breast_samp 0 or blank.")
                }
                if (!(row$primary_samp %in% c("0", NA_character_))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "primary_samp", reason = "Chick captures must use primary_samp 0 or blank.")
                }
                if (!(one_chr(row$chick_tent_photo) %in% c("0", "1"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "chick_tent_photo", reason = "All chick captures must record chick_tent_photo as 0 or 1.")
                }
                chick_hide_val <- one_chr(row$chick_hide_photo)
                if (!is.na(chick_hide_val) && chick_hide_val != "0") {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "chick_hide_photo", reason = "Hiding-spot photos belong in a separate age-C, rclass-H RESIGHTINGS row; leave chick_hide_photo blank or use 0.")
                }
                for (nm in c("mugshot_photo", "wing_photo")) {
                    if (!is.na(one_chr(row[[nm]]))) {
                      problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = nm, reason = paste0(nm, " must be blank for chick captures."))
                    }
                }
            }
            if (identical(age_val, "J")) {
                juv_missing <- c(tarsus = is.na(row$tarsus), culmen = is.na(row$culmen), weight = is.na(row$weight))
                for (nm in names(juv_missing)[juv_missing]) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = nm, reason = "Juvenile captures require this morphometric field.")
                }
                for (nm in c("total_head", "head_white", "head_black", "rufous_band")) {
                  if (!is.na(row[[nm]])) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = nm, reason = "This morphometric field must be blank for juvenile captures.")
                  }
                }
                if (!is.na(row$brood_patch)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "brood_patch", reason = "brood_patch must be blank for juvenile captures.")
                }
                if (!is.na(row$parents) && !(row$parents %in% c("MF", "F", "M", "U1", "U2", "O"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "parents", reason = "parents for juveniles must be MF, F, M, U1, U2, or O.")
                }
                if (!(row$breast_samp %in% c("0", NA_character_))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "breast_samp", reason = "Juvenile captures must use breast_samp 0 or blank.")
                }
                if (!(row$primary_samp %in% c("0", NA_character_))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "primary_samp", reason = "Juvenile captures must use primary_samp 0 or blank.")
                }
                juv_chick_tent <- trimws(as.character(row$chick_tent_photo))
                juv_chick_hide <- trimws(as.character(row$chick_hide_photo))
                if (!(is.na(row$chick_tent_photo) || juv_chick_tent %in% c("", "0"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "chick_tent_photo", reason = "Juvenile captures must leave chick_tent_photo blank or use 0.")
                }
                if (!(is.na(row$chick_hide_photo) || juv_chick_hide %in% c("", "0"))) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "chick_hide_photo", reason = "Juvenile captures must leave chick_hide_photo blank or use 0.")
                }
            }
            if (!is.na(row$blood_samp) && !(row$blood_samp %in% c("BQ", "BF", "BE"))) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "blood_samp", reason = "All captures must record blood_samp as blank, BQ, BF, or BE.")
            }
            if (length(problems) == 0) empty else data.table::rbindlist(problems)
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "CAP_018 024 027 age fields")
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
        one_chr <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            if (length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA") {
                NA_character_
            } else {
                raw
            }
        }
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            problems <- list()
            age_val <- one_chr(row$age)
            nest_val <- one_chr(row$nest_id)
            eggs_val <- one_chr(row$eggs_handled)
            if (!is.na(eggs_val) && !(eggs_val %in% c("0", "1"))) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "eggs_handled", reason = "eggs_handled must be 0 or 1 when entered.")
            }
            is_real_nest <- !is.na(nest_val) && nest_val != "NO_NEST" && substr(nest_val, 1, 1) != "-"
            if (identical(age_val, "A") && is_real_nest && is.na(eggs_val)) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "eggs_handled", reason = "Adult captures with nest_id must record eggs_handled as 0 or 1.")
            }
            if (identical(age_val, "C") && !is.na(eggs_val)) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "eggs_handled", reason = "eggs_handled must be blank for chick captures.")
            }
            if (identical(age_val, "J") && !is.na(eggs_val)) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "eggs_handled", reason = "eggs_handled must be blank for juvenile captures.")
            }
            if (length(problems) == 0) empty else data.table::rbindlist(problems)
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "CAP_021B eggs handled")
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
        one_chr <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            if (length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA") {
                NA_character_
            } else {
                raw
            }
        }
        photo_seq_num <- function(v) {
            raw <- trimws(as.character(v))
            out <- rep(NA_integer_, length(raw))
            valid <- !is.na(raw) & nzchar(raw) & raw != "NA"
            if (!any(valid)) {
                return(out)
            }
            roll_valid <- valid & grepl("([0-9]+)-([0-9]{4})$", raw, perl = TRUE)
            if (any(roll_valid)) {
                out[roll_valid] <- suppressWarnings(
                    as.integer(sub("^.*?([0-9]+)-([0-9]{4})$", "\\1", raw[roll_valid], perl = TRUE)) * 10000L +
                    as.integer(sub("^.*?([0-9]+)-([0-9]{4})$", "\\2", raw[roll_valid], perl = TRUE))
                )
            }
            suffix_valid <- valid & !roll_valid & grepl("\\d+$", raw, perl = TRUE)
            if (any(suffix_valid)) {
                out[suffix_valid] <- suppressWarnings(as.integer(sub("^.*?(\\d+)$", "\\1", raw[suffix_valid], perl = TRUE)))
            }
            out
        }
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            problems <- list()
            flag_vals <- vapply(c("mugshot_photo", "wing_photo", "chick_tent_photo", "chick_hide_photo"), function(nm) one_chr(row[[nm]]), character(1))
            any_flag_yes <- any(flag_vals == "1", na.rm = TRUE)
            has_cam <- !is.na(one_chr(row$cam_id))
            has_start <- !is.na(one_chr(row$photo_start))
            has_end <- !is.na(one_chr(row$photo_end))
            meta_count <- sum(c(has_cam, has_start, has_end))
            if (any_flag_yes && !has_cam) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "cam_id", reason = "cam_id is required when any photo flag is 1.")
            }
            if (any_flag_yes && !has_start) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_start", reason = "photo_start is required when any photo flag is 1.")
            }
            if (any_flag_yes && !has_end) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_end", reason = "photo_end is required when any photo flag is 1.")
            }
            if (meta_count > 0 && meta_count < 3) {
                if (!has_cam) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "cam_id", reason = "cam_id, photo_start, and photo_end must all be filled together.")
                }
                if (!has_start) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_start", reason = "cam_id, photo_start, and photo_end must all be filled together.")
                }
                if (!has_end) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_end", reason = "cam_id, photo_start, and photo_end must all be filled together.")
                }
            }
            start_no <- photo_seq_num(row$photo_start)
            end_no <- photo_seq_num(row$photo_end)
            if (!is.na(start_no) && !is.na(end_no) && start_no > end_no) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_end", reason = "photo_end sequence must not be earlier than photo_start.")
            }
            if (length(problems) == 0) empty else data.table::rbindlist(problems)
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "CAP_028 photo fields")
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
        grp <- z[age == "C", .(chick_n = .N), by = .(date, caught, nest_id)][chick_n > 3]
        if (nrow(grp) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            merge(z, grp, by = c("date", "caught", "nest_id"))[age == "C", .(rowid, variable = "age", reason = "No simultaneous capture event may contain more than three chicks.")]
        }
    }, nam = "CAP_026 max chicks")
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
        expand_ranges <- function(dt, table_name) {
            if (nrow(dt) == 0) {
                return(data.table::data.table(table_name = character(), rowid = integer(), photo_no = integer()))
            }
            photo_seq_num <- function(v) {
                raw <- trimws(as.character(v))
                out <- rep(NA_integer_, length(raw))
                valid <- !is.na(raw) & nzchar(raw) & raw != "NA"
                if (!any(valid)) {
                    return(out)
                }
                roll_valid <- valid & grepl("([0-9]+)-([0-9]{4})$", raw, perl = TRUE)
                if (any(roll_valid)) {
                    out[roll_valid] <- suppressWarnings(
                        as.integer(sub("^.*?([0-9]+)-([0-9]{4})$", "\\1", raw[roll_valid], perl = TRUE)) * 10000L +
                        as.integer(sub("^.*?([0-9]+)-([0-9]{4})$", "\\2", raw[roll_valid], perl = TRUE))
                    )
                }
                suffix_valid <- valid & !roll_valid & grepl("\\d+$", raw, perl = TRUE)
                if (any(suffix_valid)) {
                    out[suffix_valid] <- suppressWarnings(as.integer(sub("^.*?(\\d+)$", "\\1", raw[suffix_valid], perl = TRUE)))
                }
                out
            }
            tmp <- data.table::copy(dt)
            if (!"rowid" %in% names(tmp)) {
                tmp[, `:=`(rowid, .I)]
            }
            tmp[, `:=`(start_no, photo_seq_num(photo_start))]
            tmp[, `:=`(end_no, photo_seq_num(photo_end))]
            tmp <- tmp[!is.na(start_no) & !is.na(end_no) & start_no <= end_no]
            if (nrow(tmp) == 0) {
                return(data.table::data.table(table_name = character(), rowid = integer(), photo_no = integer()))
            }
            tmp[, .(photo_no = seq.int(start_no, end_no)), by = rowid][, `:=`(table_name, table_name)][, .(table_name, rowid, photo_no)]
        }
        other_res <- data.table::as.data.table(db_get("SELECT photo_start, photo_end FROM RESIGHTINGS"))
        other_nests <- data.table::as.data.table(db_get("SELECT photo_start, photo_end FROM NESTS"))
        current_expanded <- expand_ranges(z[, .(rowid, photo_start, photo_end)], "CAPTURES")
        other_res_expanded <- expand_ranges(other_res[, .(photo_start, photo_end)], "RESIGHTINGS")
        other_nests_expanded <- expand_ranges(other_nests[, .(photo_start, photo_end)], "NESTS")
        all_expanded <- data.table::rbindlist(list(current_expanded, other_res_expanded, other_nests_expanded), use.names = TRUE, fill = TRUE)
        dup_photo <- all_expanded[, .N, by = photo_no][N > 1, photo_no]
        if (length(dup_photo) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            flagged <- unique(current_expanded[photo_no %in% dup_photo, rowid])
            if (length(flagged) == 0) {
                data.table::data.table(rowid = integer(), variable = character(), reason = character())
            } else {
                data.table::data.table(rowid = flagged, variable = "photo_start", reason = "Photo range overlaps an image number already used in another event.")
            }
        }
    }, nam = "GLOBAL_005 photo unique")
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
        raw <- trimws(as.character(z$observer_upload))
        out <- data.table::rbindlist(list(z[is.na(observer_upload) | !nzchar(raw), .(rowid, variable = "observer_upload", reason = "all capture events require the initials of the observer entering the record to the database")], z[!is.na(observer_upload) & nzchar(raw) & !grepl("^[A-Z]{2,3}$", raw), .(rowid, variable = "observer_upload", reason = "Observer-upload initials must use two or three uppercase letters.")]), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "observer upload initials")
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
        out <- is.regexp_validator(x[, .(caught_with)], regexp = "^(?:[0-9]*C|M\\?|M|S)(?:,\\s*(?:[0-9]*C|M\\?|M|S))*$", reason = "Caught-with entry must use the current comma-separated format.")
        out
    }, nam = "caught with format")
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
        mark_cols <- intersect(c("UL_in", "LL_in", "UR_in", "LR_in", "UL", "LL", "UR", "LR"), names(z))
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
        raw <- trimws(as.character(z$UL_in))
        z <- z[is.na(UL_in) | !nzchar(raw) | !grepl(",", raw), .(UL_in, rowid)]
        out <- is.regexp_validator(z, regexp = "^(X|T|T[RBGWOLY]|[OYWBRGLM]{1,2}|F[OYWBRGLM][A-Z0-9]{2})$", reason = "Left tibia code at capture does not match the current format.")
        out
    }, nam = "left tibia in")
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
        raw <- trimws(as.character(z$LL_in))
        z <- z[is.na(LL_in) | !nzchar(raw) | !grepl(",", raw), .(LL_in, rowid)]
        out <- is.regexp_validator(z, regexp = "^(X|[OYWBRGLM]{1,2})$", reason = "Left tarsus code at capture does not match the current format.")
        out
    }, nam = "left tarsus in")
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
        raw <- trimws(as.character(z$UR_in))
        z <- z[is.na(UR_in) | !nzchar(raw) | !grepl(",", raw), .(UR_in, rowid)]
        out <- is.regexp_validator(z, regexp = "^(X|T|T[RBGWOLY]|[OYWBRGLM]{1,2}|F[OYWBRGLM][A-Z0-9]{2})$", reason = "Right tibia code at capture does not match the current format.")
        out
    }, nam = "right tibia in")
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
        raw <- trimws(as.character(z$LR_in))
        z <- z[is.na(LR_in) | !nzchar(raw) | !grepl(",", raw), .(LR_in, rowid)]
        out <- is.regexp_validator(z, regexp = "^(X|[OYWBRGLM]{1,2})$", reason = "Right tarsus code at capture does not match the current format.")
        out
    }, nam = "right tarsus in")
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
        moult_cols <- c("moult_left", "moult_right")
        pat <- "^([0-9]\\([0-9]{1,2}\\))( [0-9]\\([0-9]{1,2}\\))*$"
        out <- data.table::rbindlist(lapply(moult_cols, function(col) {
            raw <- trimws(as.character(z[[col]]))
            bad_idx <- which(!is.na(z[[col]]) & nzchar(raw) & !grepl(pat, raw))
            if (length(bad_idx) == 0) {
                return(NULL)
            }
            data.table::data.table(rowid = z$rowid[bad_idx], variable = col, reason = "Moult score must use the current scoring format, e.g. 0(10) or 2(1) 0(9).")
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            out
        }
    }, nam = "moult format")
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
        out <- z[!is.na(tag_id) & is.na(tag_type), .(rowid, variable = "tag_type", reason = "Tag type is required when tag ID is entered.")]
        if (nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            out
        }
    }, nam = "tag type required")
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
        out <- is.regexp_validator(x[, .(tag_id_in)], regexp = "^[A-Za-z0-9_-]+$", reason = "Tag ID at capture has unexpected characters.")
        out
    }, nam = "tag id in format")
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
        out <- is.regexp_validator(x[, .(tag_id)], regexp = "^[A-Za-z0-9_-]+$", reason = "Tag ID at release has unexpected characters.")
        out
    }, nam = "tag id format")
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
        out <- is.regexp_validator(x[, .(cam_id)], regexp = "^[A-Za-z0-9]{2,3}$", reason = "Camera ID must use the current two- or three-character format.")
        out
    }, nam = "camera id format")
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
        out <- is.regexp_validator(x[, .(photo_start, photo_end)], regexp = "^[A-Za-z0-9._-]+$", reason = "Photo filename has unexpected characters.")
        out
    }, nam = "photo filename format")
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
