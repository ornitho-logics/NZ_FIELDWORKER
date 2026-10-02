list({
    out <- try_validator(is.na_validator(x[, .(species, site, date, time_visit, observer, nest_id, nest_state)], reason = "Required nest field."), nam = "required nest fields")
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
        z <- x[, .(species, site, nest_state, bird_inc, nest_photo, tent_photo)]
        v <- data.table::data.table(variable = c("species", "site", "nest_state", "bird_inc", "nest_photo", "tent_photo"), set = list(c("BADO", "WRYB"), c("AR", "AU", "CH", "CL", "CR", "HC", "HR", "KK", "KP", "KT", "MB", "MR", "MS", "OD", "OK", "OM", "PB", "PR", "TA", "TO", "TP", "TR", "TS", "WA", "WN", "WS"), c("S", "F", "I", "H", "pP", "pD", "P", "D", "notA", "O"), c("M", "F", "FM", "MF", "U", "E"), c("0", "1"), c("0", "1")))
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
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        z <- data.table::copy(x)
        z[, rowid := .I]
        state_key <- trimws(as.character(z$nest_state))
        comment_key <- trimws(as.character(z$comments))
        comment_key[is.na(z$comments) | comment_key == "NA"] <- ""
        bad_idx <- which(state_key == "O" & !nzchar(comment_key))
        if (length(bad_idx) == 0) {
            empty
        } else {
            data.table::data.table(
                rowid = z$rowid[bad_idx],
                variable = "comments",
                reason = "nest_state O requires a comment describing the observation."
            )
        }
    }, nam = "other state comment")
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
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        obs <- tryCatch(db_get("SELECT observer, START, STOP FROM OBSERVERS"), error = function(e) NULL)
        if (is.null(obs) || nrow(obs) == 0) {
            empty
        } else {
            obs <- data.table::as.data.table(obs)
            obs[, `:=`(observer, trimws(as.character(observer)))]
            obs[, `:=`(START, suppressWarnings(as.Date(START)))]
            obs[, `:=`(STOP, suppressWarnings(as.Date(STOP)))]
            zz <- z[, .(rowid, observer = trimws(as.character(observer)), date = suppressWarnings(as.Date(date)))]
            merged <- merge(zz, obs, by = "observer", all.x = TRUE, allow.cartesian = TRUE)
            out <- merged[!is.na(date) & (is.na(observer) | observer == "" | is.na(START) | is.na(STOP) | date < START | date > STOP), .(rowid, variable = "observer", reason = "Observer must be in OBSERVERS and active on the visit date.")][, unique(.SD)]
            if (nrow(out) == 0) empty else out
        }
    }, nam = "observer active")
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
        z[, `:=`(rowid, .I)]
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        raw <- trimws(as.character(z$date))
        parsed <- suppressWarnings(as.Date(raw, format = "%Y-%m-%d"))
        bad_idx <- which(!is.na(z$date) & nzchar(raw) & (!grepl("^\\d{4}-\\d{2}-\\d{2}$", raw) | is.na(parsed) | parsed < as.Date("2026-07-01") | parsed > as.Date("2027-07-31")))
        if (length(bad_idx) == 0) {
            empty
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "date", reason = "Date must use YYYY-MM-DD and fall within the 2026-2027 field season.")
        }
    }, nam = "date season")
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
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        raw <- trimws(as.character(z$time_visit))
        parsed <- suppressWarnings(strptime(raw, format = "%H:%M"))
        bad_idx <- which(!is.na(z$time_visit) & nzchar(raw) & (!grepl("^\\d{2}:\\d{2}$", raw) | is.na(parsed)))
        if (length(bad_idx) == 0) {
            empty
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
        z[, `:=`(rowid, .I)]
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        # Both the observer/GPS code and running tally use two digits from 01 to 99.
        # This includes currently deployed GPS ID 22, e.g. C2201 or BA2201.
        cr_pat <- "^[ABC](0[1-9]|[1-9][0-9])(0[1-9]|[1-9][0-9])$"
        cr_wryb_pat <- "^WR(0[1-9]|[1-9][0-9])(0[1-9]|[1-9][0-9])$"
        noncr_bado_pat <- "^BA(0[1-9]|[1-9][0-9])(0[1-9]|[1-9][0-9])$"
        raw <- trimws(as.character(z$nest_id))
        nest_key <- toupper(raw)
        site_key <- toupper(trimws(as.character(z$site)))
        species_key <- toupper(trimws(as.character(z$species)))
        present_idx <- !is.na(z$nest_id) & nzchar(raw) & toupper(raw) != "NA"
        negative_idx <- present_idx & startsWith(raw, "-")

        # The prefix identifies the species for these field-season nest IDs:
        # WR is WRYB; A/B/C and BA are BADO. Report this as a species error
        # rather than making the fieldworker diagnose it from a nest_id pattern
        # message. Negative IDs are handled first because they are never valid
        # in NESTS regardless of their prefix.
        wr_species_bad <- present_idx & !negative_idx & grepl("^WR", nest_key) &
            !is.na(species_key) & nzchar(species_key) & species_key != "WRYB"
        bado_species_bad <- present_idx & !negative_idx & grepl("^(A|B|C|BA)", nest_key) &
            !is.na(species_key) & nzchar(species_key) & species_key != "BADO"
        prefix_species_bad <- wr_species_bad | bado_species_bad

        cr_valid <- ifelse(species_key == "WRYB", grepl(cr_wryb_pat, raw), grepl(cr_pat, raw))
        syntax_bad <- present_idx & !negative_idx & !prefix_species_bad & (
            (site_key == "CR" & !cr_valid) |
            (site_key != "CR" & species_key == "BADO" & !grepl(noncr_bado_pat, raw))
        )
        bad_idx <- which(present_idx & (negative_idx | prefix_species_bad | syntax_bad))
        if (length(bad_idx) == 0) {
            empty
        } else {
            data.table::data.table(
                rowid = z$rowid[bad_idx],
                variable = ifelse(
                    wr_species_bad[bad_idx] | bado_species_bad[bad_idx],
                    "species",
                    "nest_id"
                ),
                reason = ifelse(
                    negative_idx[bad_idx],
                    "Negative nest IDs describe broods of unknown origin and cannot be entered in NESTS. Enter each observed bird in RESIGHTINGS or each captured bird in CAPTURES using the negative nest ID.",
                    ifelse(
                        wr_species_bad[bad_idx],
                        "Nest IDs beginning with WR are WRYB nest IDs. Set species to WRYB.",
                        ifelse(
                            bado_species_bad[bad_idx],
                            "Nest IDs beginning with A, B, C, or BA are BADO nest IDs. Set species to BADO.",
                            ifelse(
                                site_key[bad_idx] == "CR" & species_key[bad_idx] == "WRYB",
                                "Cass River WRYB nest ID must use WR + gps_id + sequence, e.g. WR0201.",
                                ifelse(
                                    site_key[bad_idx] == "CR",
                                    "Cass River BADO nest ID must use plot + gps_id + sequence, e.g. B0112.",
                                    "Non-CR BADO nest ID must use BA + gps_id + sequence, e.g. BA0804."
                                )
                            )
                        )
                    )
                )
            )
        }
    }, nam = "nest id pattern")
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
        parse_hatch <- function(v) {
            s <- trimws(as.character(v))
            if (is.na(s) || !nzchar(s)) {
                return(NULL)
            }
            m <- gregexpr("([1-4])(CC|C|S|N)", s, perl = TRUE)
            toks <- regmatches(s, m)[[1]]
            if (length(toks) == 0 || paste0(toks, collapse = "") != s) {
                return(list(valid = FALSE))
            }
            states <- sub("^[1-4]", "", toks)
            states_norm <- ifelse(states == "CC", "C", states)
            counts <- as.integer(sub("(\\d).*", "\\1", toks))
            list(valid = TRUE, C = sum(counts[states_norm == "C"]), S = sum(counts[states_norm == "S"]), N = sum(counts[states_norm == "N"]), total = sum(counts), max_stage = if (any(states_norm == "C")) {
                3L
            } else if (any(states_norm == "S")) {
                2L
            } else {
                1L
            })
        }
        out <- z[, {
            p <- parse_hatch(hatch_state)
            if (is.null(p) || isTRUE(p$valid)) {
                NULL
            } else {
                data.table::data.table(rowid = rowid, variable = "hatch_state", reason = "Hatch state must use a positive count followed by C, S, N, or CC for each component; component order does not matter.")
            }
        }, by = rowid]
        if (is.null(out) || nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            out
        }
    }, nam = "hatch state format")
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
        raw <- trimws(as.character(z$gps_id))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$gps_id) & nzchar(raw) & (is.na(parsed) | parsed < 1 | parsed != floor(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "gps_id", reason = "GPS ID must be a positive whole number.")
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
    out <- try_validator({
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        raw <- trimws(as.character(z$gps_point))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$gps_point) & nzchar(raw) & (is.na(parsed) | parsed < 1 | parsed != floor(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "gps_point", reason = "GPS point must be a positive whole number.")
        }
    }, nam = "gps point")
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
        raw <- trimws(as.character(z$clutch_size))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$clutch_size) & nzchar(raw) & (is.na(parsed) | parsed < 0 | parsed != floor(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "clutch_size", reason = "Clutch size must be a non-negative whole number.")
        }
    }, nam = "clutch size")
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
        raw <- trimws(as.character(z$brood_size))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$brood_size) & nzchar(raw) & (is.na(parsed) | parsed < 0 | parsed != floor(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "brood_size", reason = "Brood size must be a non-negative whole number.")
        }
    }, nam = "brood size")
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
    out <- try_validator(is.regexp_validator(x[, .(cam_id)], regexp = "^[A-Za-z0-9]{2,3}$", reason = "Camera ID must use the current two- or three-character format."), nam = "camera id")
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
    out <- try_validator(is.regexp_validator(x[, .(photo_start, photo_end)], regexp = "^[A-Za-z0-9._-]+$", reason = "Photo filename has unexpected characters."), nam = "photo filename")
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
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            problems <- list()
            nest_photo_yes <- identical(one_chr(row$nest_photo), "1")
            tent_photo_yes <- identical(one_chr(row$tent_photo), "1")
            any_yes <- nest_photo_yes || tent_photo_yes
            has_cam <- !is.na(one_chr(row$cam_id))
            has_start <- !is.na(one_chr(row$photo_start))
            has_end <- !is.na(one_chr(row$photo_end))
            present_n <- sum(c(has_cam, has_start, has_end))
            if (any_yes) {
                if (!has_cam) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "cam_id", reason = "cam_id is required when nest_photo or tent_photo is 1.")
                }
                if (!has_start) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_start", reason = "photo_start is required when nest_photo or tent_photo is 1.")
                }
                if (!has_end) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_end", reason = "photo_end is required when nest_photo or tent_photo is 1.")
                }
            } else if (present_n > 0 && present_n < 3) {
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
            if (length(problems) == 0) {
                NULL
            } else {
                data.table::rbindlist(problems, use.names = TRUE, fill = TRUE)
            }
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) {
            empty
        } else {
            unique(out)
        }
    }, nam = "photo metadata")
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
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        norm_chr <- function(v) {
            out <- trimws(as.character(v))
            out[is.na(v) | out == "NA"] <- NA_character_
            out
        }
        norm_time_chr <- function(v) {
            out <- norm_chr(v)
            out[!is.na(out) & nzchar(out)] <- substr(out[!is.na(out) & nzchar(out)], 1, 5)
            out
        }
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        z[, `:=`(source, "current")]
        ids <- unique(trimws(as.character(z$nest_id)))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table::data.table(nest_id = character(), date = character(), time_visit = character(), nest_state = character(), clutch_size = numeric(), gps_id = character(), gps_point = character(), rowid = integer(), source = character())
        if (length(ids) > 0) {
            quoted <- paste(sprintf("'%s'", gsub("'", "''", ids)), collapse = ", ")
            hist0 <- tryCatch(db_get(sprintf(paste("SELECT nest_id, date, time_visit, nest_state, clutch_size, gps_id, gps_point", "FROM NESTS WHERE nest_id IN (%s)"), quoted)), error = function(e) NULL)
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- data.table::as.data.table(hist0)
                hist[, `:=`(nest_id, norm_chr(nest_id))]
                hist[, `:=`(date, norm_chr(date))]
                hist[, `:=`(time_visit, norm_time_chr(time_visit))]
                hist[, `:=`(nest_state, norm_chr(nest_state))]
                hist[, `:=`(clutch_size, suppressWarnings(as.numeric(as.character(clutch_size))))]
                hist[, `:=`(gps_id, norm_chr(gps_id))]
                hist[, `:=`(gps_point, norm_chr(gps_point))]
                hist[, `:=`(rowid, NA_integer_)]
                hist[, `:=`(source, "db")]
            }
        }
        current_hist <- z[, .(
            nest_id = norm_chr(nest_id),
            date = norm_chr(date),
            time_visit = norm_time_chr(time_visit),
            nest_state = norm_chr(nest_state),
            clutch_size = suppressWarnings(as.numeric(as.character(clutch_size))),
            gps_id = norm_chr(gps_id),
            gps_point = norm_chr(gps_point),
            rowid,
            source
        )]
        all_nests <- data.table::rbindlist(list(hist, current_hist), use.names = TRUE, fill = TRUE)
        all_nests[, `:=`(date_ord, suppressWarnings(as.Date(date)))]
        all_nests[, `:=`(time_ord, suppressWarnings(as.POSIXct(strptime(time_visit, format = "%H:%M"))))]
        all_nests[, `:=`(source_ord, ifelse(source == "db", 0L, 1L))]
        # A missing date or time is reported by its own required/format rule. Do not
        # infer a state sequence from an event whose chronology cannot be determined.
        all_nests <- all_nests[
            !is.na(nest_id) & nzchar(nest_id) &
                !is.na(nest_state) & nzchar(nest_state) &
                !is.na(date_ord) & !is.na(time_ord)
        ]
        data.table::setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        out_parts <- lapply(split(all_nests, by = "nest_id", keep.by = TRUE), function(dt) {
            if (nrow(dt) == 0) {
                return(NULL)
            }
            problems <- list()
            # The first event establishes the nest location. It must carry the GPS
            # pair when it is part of the current submission, whether its state is
            # S or F. A later F after an opening S does not repeat these fields.
            if (!is.na(dt$rowid[1])) {
                if (is.na(dt$nest_state[1]) || !dt$nest_state[1] %in% c("F", "S")) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(
                        rowid = dt$rowid[1],
                        variable = "nest_state",
                        reason = "The first chronological nest event must use nest_state S or F."
                    )
                }
                if (identical(dt$nest_state[1], "F") && !is.na(dt$clutch_size[1]) && dt$clutch_size[1] == 0) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(
                        rowid = dt$rowid[1],
                        variable = "clutch_size",
                        reason = "A first nest event with clutch_size 0 must use nest_state S."
                    )
                }
                if (is.na(dt$gps_id[1]) || !nzchar(dt$gps_id[1])) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(
                        rowid = dt$rowid[1],
                        variable = "gps_id",
                        reason = "The first nest event for a nest_id must record gps_id."
                    )
                }
                if (is.na(dt$gps_point[1]) || !nzchar(dt$gps_point[1])) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(
                        rowid = dt$rowid[1],
                        variable = "gps_point",
                        reason = "The first nest event for a nest_id must record gps_point."
                    )
                }
            }

            # F records the single transition from a scrape/discovery phase into
            # an active nest. Once an F exists in saved or submitted history, no
            # additional current F row is valid for the same nest_id.
            current_f <- which(dt$source == "current" & dt$nest_state == "F")
            saved_f_exists <- any(dt$source == "db" & dt$nest_state == "F")
            duplicate_f <- if (saved_f_exists) {
                current_f
            } else if (length(current_f) > 1L) {
                current_f[-1L]
            } else {
                integer()
            }
            if (length(duplicate_f) > 0) {
                problems[[length(problems) + 1L]] <- data.table::data.table(
                    rowid = dt$rowid[duplicate_f],
                    variable = "nest_state",
                    reason = "Each nest_id may contain only one nest_state F event."
                )
            }

            later_current <- which(seq_len(nrow(dt)) > 1L & !is.na(dt$rowid))
            if (length(later_current) > 0) {
                later_gps_id <- later_current[
                    !is.na(dt$gps_id[later_current]) & nzchar(dt$gps_id[later_current])
                ]
                if (length(later_gps_id) > 0) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(
                        rowid = dt$rowid[later_gps_id],
                        variable = "gps_id",
                        reason = "Only the first chronological event for a nest_id may record gps_id."
                    )
                }

                later_gps_point <- later_current[
                    !is.na(dt$gps_point[later_current]) & nzchar(dt$gps_point[later_current])
                ]
                if (length(later_gps_point) > 0) {
                    problems[[length(problems) + 1L]] <- data.table::data.table(
                        rowid = dt$rowid[later_gps_point],
                        variable = "gps_point",
                        reason = "Only the first chronological event for a nest_id may record gps_point."
                    )
                }
            }
            if (length(problems) == 0) NULL else data.table::rbindlist(problems)
        })
        out_parts <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, out_parts)
        out <- if (length(out_parts) == 0) {
            empty
        } else {
            data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE)
        }
        out <- out[!is.na(rowid)]
        if (nrow(out) == 0) empty else out[, .(rowid, variable, reason)]
    }, nam = "nest history starts")
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
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        norm_chr <- function(v) {
            out <- trimws(as.character(v))
            out[is.na(v) | out == "NA"] <- NA_character_
            out
        }
        norm_time_chr <- function(v) {
            out <- norm_chr(v)
            out[!is.na(out) & nzchar(out)] <- substr(out[!is.na(out) & nzchar(out)], 1, 5)
            out
        }
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        z[, `:=`(source, "current")]
        ids <- unique(trimws(as.character(z$nest_id)))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table::data.table(nest_id = character(), date = character(), time_visit = character(), nest_state = character(), clutch_size = character(), brood_size = character(), rowid = integer(), source = character())
        if (length(ids) > 0) {
            quoted <- paste(sprintf("'%s'", gsub("'", "''", ids)), collapse = ", ")
            hist0 <- tryCatch(db_get(sprintf(paste("SELECT nest_id, date, time_visit, nest_state, clutch_size, brood_size", "FROM NESTS WHERE nest_id IN (%s)"), quoted)), error = function(e) NULL)
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- data.table::as.data.table(hist0)
                hist[, `:=`(nest_id, norm_chr(nest_id))]
                hist[, `:=`(date, norm_chr(date))]
                hist[, `:=`(time_visit, norm_time_chr(time_visit))]
                hist[, `:=`(nest_state, norm_chr(nest_state))]
                hist[, `:=`(rowid, NA_integer_)]
                hist[, `:=`(source, "db")]
            }
        }
        current_hist <- z[, .(nest_id = norm_chr(nest_id), date = norm_chr(date), time_visit = norm_time_chr(time_visit), nest_state = norm_chr(nest_state), clutch_size, brood_size, rowid, source)]
        all_nests <- data.table::rbindlist(list(hist, current_hist), use.names = TRUE, fill = TRUE)
        all_nests[, `:=`(date_ord, suppressWarnings(as.Date(date)))]
        all_nests[, `:=`(time_ord, suppressWarnings(as.POSIXct(strptime(time_visit, format = "%H:%M"))))]
        all_nests[, `:=`(
            clutch_num = suppressWarnings(as.numeric(as.character(clutch_size))),
            brood_num = suppressWarnings(as.numeric(as.character(brood_size)))
        )]
        # When date and time are identical, saved history is the established
        # predecessor and must be assessed before the newly submitted row.
        all_nests[, `:=`(source_ord, ifelse(source == "db", 0L, 1L))]
        # A D and its closing notA may legitimately share a timestamp. Within the
        # same source, assess D before notA regardless of paste-table row order.
        all_nests[, `:=`(state_ord, ifelse(nest_state == "notA", 1L, 0L))]
        # A missing date or time is reported by its own required/format rule. Do not
        # infer a state sequence from an event whose chronology cannot be determined.
        all_nests <- all_nests[
            !is.na(nest_id) & nzchar(nest_id) &
                !is.na(nest_state) & nzchar(nest_state) &
                !is.na(date_ord) & !is.na(time_ord)
        ]
        data.table::setorder(all_nests, nest_id, date_ord, time_ord, source_ord, state_ord, rowid)
        all_nests <- all_nests[, .SD[1], by = .(nest_id, date, time_visit, nest_state)]
        data.table::setorder(all_nests, nest_id, date_ord, time_ord, source_ord, state_ord, rowid)
        out_parts <- lapply(split(all_nests, by = "nest_id", keep.by = TRUE), function(dt) {
            probs <- list()
            st <- as.character(dt$nest_state)
            if (nrow(dt) < 2L) {
                return(NULL)
            }

            # O is a documented observation rather than a change in nest status,
            # so later transitions are assessed against the last non-O state.
            last_effective <- st[1]
            for (i in 2:nrow(dt)) {
                current_state <- st[i]
                repeated_f <- current_state == "F" && any(st[seq_len(i - 1L)] == "F")
                allowed <- switch(
                    last_effective,
                    "S" = c("S", "F", "notA"),
                    "F" = c("I", "H", "pP", "P", "pD", "D", "notA", "O"),
                    "I" = c("I", "H", "pP", "P", "pD", "D", "notA", "O"),
                    "pD" = c("I", "H", "pP", "P", "pD", "D", "notA", "O"),
                    character()
                )

                # Repeated F rows are reported by the dedicated uniqueness rule.
                if (!repeated_f && length(allowed) > 0 && !current_state %in% allowed) {
                    probs[[length(probs) + 1L]] <- data.table::data.table(
                        rowid = dt$rowid[i],
                        variable = "nest_state",
                        reason = if (last_effective == "F") {
                            "After nest_state F, subsequent visits may use only I, H, pP, P, pD, D, notA, or O."
                        } else if (last_effective == "S") {
                            "After nest_state S, subsequent visits may use only S, F, or a final notA."
                        } else {
                            "This nest_state is not allowed after the latest active nest state."
                        }
                    )
                }

                if (current_state != "O") {
                    last_effective <- current_state
                }
            }
            probs <- Filter(function(x) !is.null(x) && nrow(x) > 0, probs)
            if (length(probs) == 0) {
                return(NULL)
            }
            unique(data.table::rbindlist(probs, use.names = TRUE, fill = TRUE))
        })
        out_parts <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, out_parts)
        out <- if (length(out_parts) == 0) {
            empty
        } else {
            data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE)
        }
        out <- out[!is.na(rowid)]
        if (nrow(out) == 0) empty else out[, .(rowid, variable, reason)]
    }, nam = "start state sequence")
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
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        norm_chr <- function(v) {
            out <- trimws(as.character(v))
            out[is.na(v) | out == "NA"] <- NA_character_
            out
        }
        norm_time_chr <- function(v) {
            if (inherits(v, "difftime")) {
                secs <- suppressWarnings(as.numeric(v, units = "secs"))
                out <- rep(NA_character_, length(secs))
                ok <- !is.na(secs)
                secs <- secs %% (24 * 60 * 60)
                out[ok] <- sprintf(
                    "%02d:%02d:%02d",
                    floor(secs[ok] / 3600),
                    floor((secs[ok] %% 3600) / 60),
                    floor(secs[ok] %% 60)
                )
                return(out)
            }
            out <- norm_chr(v)
            out[!is.na(out) & nzchar(out)] <- substr(out[!is.na(out) & nzchar(out)], 1, 5)
            out
        }
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        z[, `:=`(source, "current")]
        clutch_num <- suppressWarnings(as.numeric(as.character(z$clutch_size)))
        brood_num <- suppressWarnings(as.numeric(as.character(z$brood_size)))
        ids <- unique(trimws(as.character(z$nest_id)))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table::data.table(
            nest_id = character(),
            date = character(),
            time_visit = character(),
            nest_state = character(),
            clutch_num = numeric(),
            brood_num = numeric(),
            rowid = integer(),
            source = character()
        )
        if (length(ids) > 0) {
            quoted <- paste(sprintf("'%s'", gsub("'", "''", ids)), collapse = ", ")
            hist0 <- tryCatch(db_get(sprintf(paste("SELECT nest_id, date, time_visit, nest_state, clutch_size, brood_size", "FROM NESTS WHERE nest_id IN (%s)"), quoted)), error = function(e) NULL)
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- data.table::as.data.table(hist0)
                hist[, `:=`(nest_id, norm_chr(nest_id))]
                hist[, `:=`(date, norm_chr(date))]
                hist[, `:=`(time_visit, norm_time_chr(time_visit))]
                hist[, `:=`(nest_state, norm_chr(nest_state))]
                hist[, `:=`(clutch_num, suppressWarnings(as.numeric(as.character(clutch_size))))]
                hist[, `:=`(brood_num, suppressWarnings(as.numeric(as.character(brood_size))))]
                hist[, `:=`(rowid, NA_integer_)]
                hist[, `:=`(source, "db")]
            }
        }
        current_hist <- z[, .(
            nest_id = norm_chr(nest_id),
            date = norm_chr(date),
            time_visit = norm_time_chr(time_visit),
            nest_state = norm_chr(nest_state),
            clutch_num,
            brood_num,
            rowid,
            source
        )]
        all_nests <- data.table::rbindlist(list(hist, current_hist), use.names = TRUE, fill = TRUE)
        all_nests[, `:=`(date_ord, suppressWarnings(as.Date(date)))]
        all_nests[, `:=`(time_ord, suppressWarnings(as.POSIXct(strptime(time_visit, format = "%H:%M"))))]
        # When date and time are identical, saved history is the established
        # predecessor and must be assessed before the newly submitted row.
        all_nests[, `:=`(source_ord, ifelse(source == "db", 0L, 1L))]
        # A D and its closing notA may legitimately share a timestamp. Within the
        # same source, assess D before notA regardless of paste-table row order.
        all_nests[, `:=`(state_ord, ifelse(nest_state == "notA", 1L, 0L))]
        # A missing date or time is reported by its own required/format rule. Do not
        # infer a state sequence from an event whose chronology cannot be determined.
        all_nests <- all_nests[
            !is.na(nest_id) & nzchar(nest_id) &
                !is.na(nest_state) & nzchar(nest_state) &
                !is.na(date_ord) & !is.na(time_ord)
        ]
        data.table::setorder(all_nests, nest_id, date_ord, time_ord, source_ord, state_ord, rowid)
        all_nests <- all_nests[, .SD[1], by = .(nest_id, date, time_visit, nest_state, clutch_num, brood_num)]
        data.table::setorder(all_nests, nest_id, date_ord, time_ord, source_ord, state_ord, rowid)
        out_parts <- lapply(split(all_nests, by = "nest_id", keep.by = TRUE), function(dt) {
            probs <- list()
            st <- as.character(dt$nest_state)
            terminal_h <- st == "H" &
                !is.na(dt$clutch_num) & dt$clutch_num == 0 &
                !is.na(dt$brood_num) & dt$brood_num > 0
            terminal_idx <- which(st %in% c("pP", "P", "D") | terminal_h)
            nota_idx <- which(st == "notA")
            if (length(nota_idx) > 0) {
                bad_nota <- nota_idx[nota_idx != nrow(dt) | nota_idx == 1L | !st[pmax(nota_idx - 1L, 1L)] %in% c("S", "F", "H", "pD", "pP", "P", "D")]
                if (length(bad_nota) > 0) {
                  probs[[length(probs) + 1L]] <- data.table::data.table(
                    rowid = dt$rowid[bad_nota],
                    variable = "nest_state",
                    reason = paste(
                      "notA must be the final visit and can only follow S, F, H, pD, pP, P, or D.",
                      "When paired with D, notA may use the same timestamp but must not occur before D."
                    )
                  )
                }
            }
            if (length(terminal_idx) > 0) {
                first_term <- terminal_idx[1]
                after_idx <- if (first_term < nrow(dt)) {
                  seq.int(first_term + 1L, nrow(dt))
                } else {
                  integer()
                }
                allowed_after <- if (length(after_idx) == 1L && st[after_idx] == "notA") {
                  integer()
                } else {
                  after_idx
                }
                if (length(allowed_after) > 0) {
                  probs[[length(probs) + 1L]] <- data.table::data.table(
                    rowid = dt$rowid[allowed_after],
                    variable = "nest_state",
                    reason = "Only a final notA visit may follow a terminal H visit with clutch_size 0 and brood_size greater than 0, or a pP, P, or D visit."
                  )
                }
            }
            h_to_i <- which(head(st, -1L) == "H" & tail(st, -1L) == "I") + 1L
            if (length(h_to_i) > 0) {
                probs[[length(probs) + 1L]] <- data.table::data.table(rowid = dt$rowid[h_to_i], variable = "nest_state", reason = "H cannot be followed by I in the same nest history.")
            }
            probs <- Filter(function(x) !is.null(x) && nrow(x) > 0, probs)
            if (length(probs) == 0) {
                NULL
            } else {
                unique(data.table::rbindlist(probs, use.names = TRUE, fill = TRUE))
            }
        })
        out_parts <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, out_parts)
        out <- if (length(out_parts) == 0) {
            empty
        } else {
            data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE)
        }
        out <- out[!is.na(rowid)]
        if (nrow(out) == 0) empty else out[, .(rowid, variable, reason)]
    }, nam = "terminal notA")
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
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        hatch_raw <- trimws(as.character(z$hatch_state))
        hatch_present <- !is.na(z$hatch_state) & nzchar(hatch_raw)
        clutch_num <- suppressWarnings(as.numeric(as.character(z$clutch_size)))
        brood_raw <- trimws(as.character(z$brood_size))
        brood_raw[is.na(z$brood_size) | brood_raw == "NA"] <- ""
        brood_num <- suppressWarnings(as.numeric(as.character(z$brood_size)))
        z[, `:=`(
            nest_key = trimws(as.character(nest_id)),
            event_date = suppressWarnings(as.Date(as.character(date), format = "%Y-%m-%d")),
            event_time = trimws(as.character(time_visit)),
            state_ord = ifelse(as.character(nest_state) == "notA", 1L, 0L),
            clutch_num = clutch_num
        )]
        z[is.na(event_time), `:=`(event_time, "")]
        z[, `:=`(
            previous_current_state = {
                ord <- order(event_date, event_time, state_ord, rowid, na.last = TRUE)
                ans <- rep(NA_character_, .N)
                ans[ord] <- data.table::shift(as.character(nest_state)[ord])
                ans
            },
            previous_current_clutch = {
                ord <- order(event_date, event_time, state_ord, rowid, na.last = TRUE)
                ans <- rep(NA_real_, .N)
                ans[ord] <- data.table::shift(clutch_num[ord])
                ans
            }
        ), by = nest_key]
        carries_d_clutch <-
            z$nest_state == "notA" &
            z$previous_current_state == "D" &
            !is.na(clutch_num) &
            !is.na(z$previous_current_clutch) &
            clutch_num == z$previous_current_clutch
        carries_d_clutch[is.na(carries_d_clutch)] <- FALSE
        clutch_bad <-
            z$nest_state == "notA" &
            (is.na(clutch_num) | clutch_num != 0) &
            !carries_d_clutch
        scrape_clutch_bad <- z$nest_state == "S" & (is.na(clutch_num) | clutch_num != 0)
        scrape_brood_bad <- z$nest_state == "S" & nzchar(brood_raw) & (is.na(brood_num) | brood_num != 0)
        out_parts <- list(
            z[z$nest_state == "notA" & hatch_present, .(rowid, variable = "hatch_state", reason = "notA rows must leave hatch_state blank.")],
            z[clutch_bad, .(
                rowid,
                variable = "clutch_size",
                reason = paste(
                    "notA rows must set clutch_size to 0 unless they immediately follow a D row",
                    "in the same submission and retain that D row's clutch_size."
                )
            )],
            z[scrape_clutch_bad, .(rowid, variable = "clutch_size", reason = "S rows must set clutch_size to 0.")],
            z[scrape_brood_bad, .(rowid, variable = "brood_size", reason = "S rows must leave brood_size blank or set it to 0.")]
        )
        out_parts <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, out_parts)
        out <- if (length(out_parts) == 0) {
            empty
        } else {
            data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE)
        }
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "notA inactive row")
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
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        norm_chr <- function(v) {
            out <- trimws(as.character(v))
            out[is.na(v) | out == "NA"] <- NA_character_
            out
        }
        norm_time_chr <- function(v) {
            out <- norm_chr(v)
            out[!is.na(out) & nzchar(out)] <- substr(out[!is.na(out) & nzchar(out)], 1, 5)
            out
        }
        parse_hatch <- function(v) {
            s <- trimws(as.character(v))
            if (is.na(s) || !nzchar(s)) {
                return(NULL)
            }
            m <- gregexpr("([1-4])(CC|C|S|N)", s, perl = TRUE)
            toks <- regmatches(s, m)[[1]]
            if (length(toks) == 0 || paste0(toks, collapse = "") != s) {
                return(NULL)
            }
            states <- sub("^[1-4]", "", toks)
            states_norm <- ifelse(states == "CC", "C", states)
            counts <- as.integer(sub("(\\d).*", "\\1", toks))
            list(C = sum(counts[states_norm == "C"]), S = sum(counts[states_norm == "S"]), N = sum(counts[states_norm == "N"]), max_stage = if (any(states_norm == "C")) {
                3L
            } else if (any(states_norm == "S")) {
                2L
            } else {
                1L
            })
        }
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        z[, `:=`(source, "current")]
        ids <- unique(trimws(as.character(z$nest_id)))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table::data.table(nest_id = character(), date = character(), time_visit = character(), hatch_state = character(), rowid = integer(), source = character())
        if (length(ids) > 0) {
            quoted <- paste(sprintf("'%s'", gsub("'", "''", ids)), collapse = ", ")
            hist0 <- tryCatch(db_get(sprintf(paste("SELECT nest_id, date, time_visit, hatch_state", "FROM NESTS WHERE nest_id IN (%s)"), quoted)), error = function(e) NULL)
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- data.table::as.data.table(hist0)
                hist[, `:=`(nest_id, norm_chr(nest_id))]
                hist[, `:=`(date, norm_chr(date))]
                hist[, `:=`(time_visit, norm_time_chr(time_visit))]
                hist[, `:=`(hatch_state, norm_chr(hatch_state))]
                hist[, `:=`(rowid, NA_integer_)]
                hist[, `:=`(source, "db")]
            }
        }
        current_hist <- z[, .(nest_id = norm_chr(nest_id), date = norm_chr(date), time_visit = norm_time_chr(time_visit), hatch_state = norm_chr(hatch_state), rowid, source)]
        all_nests <- data.table::rbindlist(list(hist, current_hist), use.names = TRUE, fill = TRUE)
        all_nests[, `:=`(date_ord, suppressWarnings(as.Date(date)))]
        all_nests[, `:=`(time_ord, suppressWarnings(as.POSIXct(strptime(time_visit, format = "%H:%M"))))]
        all_nests[, `:=`(source_ord, ifelse(source == "db", 0L, 1L))]
        data.table::setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        out_parts <- lapply(split(all_nests, by = "nest_id", keep.by = TRUE), function(dt) {
            prev_stage <- NA_integer_
            probs <- list()
            for (i in seq_len(nrow(dt))) {
                p <- parse_hatch(dt$hatch_state[i])
                if (is.null(p)) {
                  next
                }
                if (!is.na(prev_stage) && p$max_stage < prev_stage) {
                  probs[[length(probs) + 1L]] <- data.table::data.table(rowid = dt$rowid[i], variable = "hatch_state", reason = "Hatch-state progression cannot move backward.")
                }
                prev_stage <- p$max_stage
            }
            probs <- Filter(function(x) !is.null(x) && nrow(x) > 0, probs)
            if (length(probs) == 0) {
                NULL
            } else {
                data.table::rbindlist(probs, use.names = TRUE, fill = TRUE)
            }
        })
        out_parts <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, out_parts)
        out <- if (length(out_parts) == 0) {
            empty
        } else {
            data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE)
        }
        out <- out[!is.na(rowid)]
        if (nrow(out) == 0) empty else out[, .(rowid, variable, reason)]
    }, nam = "hatch progression")
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
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
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
        expand_range <- function(start_v, end_v) {
            s <- photo_seq_num(start_v)
            e <- photo_seq_num(end_v)
            if (is.na(s) || is.na(e) || s > e) {
                integer()
            } else {
                seq.int(s, e)
            }
        }
        expand_rows <- function(dt, rowid_col = NULL) {
            pieces <- lapply(seq_len(nrow(dt)), function(i) {
                nums <- expand_range(dt$photo_start[i], dt$photo_end[i])
                if (!length(nums)) {
                  return(NULL)
                }
                data.table::data.table(rowid = if (is.null(rowid_col)) NA_integer_ else dt[[rowid_col]][i], img_num = nums)
            })
            pieces <- Filter(Negate(is.null), pieces)
            if (length(pieces) == 0) {
                data.table::data.table(rowid = integer(), img_num = integer())
            } else {
                data.table::rbindlist(pieces, use.names = TRUE, fill = TRUE)
            }
        }
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        current_seq <- expand_rows(z, rowid_col = "rowid")
        if (nrow(current_seq) == 0) {
            empty
        } else {
            ref_parts <- list()
            ref_nests <- tryCatch(db_get("SELECT photo_start, photo_end FROM NESTS"), error = function(e) NULL)
            if (!is.null(ref_nests) && nrow(ref_nests) > 0) {
                ref_parts[[length(ref_parts) + 1L]] <- expand_rows(data.table::as.data.table(ref_nests))
            }
            ref_caps <- tryCatch(db_get("SELECT photo_start, photo_end FROM CAPTURES"), error = function(e) NULL)
            if (!is.null(ref_caps) && nrow(ref_caps) > 0) {
                ref_parts[[length(ref_parts) + 1L]] <- expand_rows(data.table::as.data.table(ref_caps))
            }
            ref_res <- tryCatch(db_get("SELECT photo_start, photo_end FROM RESIGHTINGS"), error = function(e) NULL)
            if (!is.null(ref_res) && nrow(ref_res) > 0) {
                ref_parts[[length(ref_parts) + 1L]] <- expand_rows(data.table::as.data.table(ref_res))
            }
            ref <- if (length(ref_parts) == 0) {
                data.table::data.table(rowid = integer(), img_num = integer())
            } else {
                data.table::rbindlist(ref_parts, use.names = TRUE, fill = TRUE)
            }
            dup_current <- current_seq[, .N, by = img_num][N > 1]
            rows_dup_current <- if (nrow(dup_current) == 0) {
                integer()
            } else {
                current_seq[dup_current, on = "img_num", nomatch = 0L][, unique(rowid)]
            }
            rows_dup_ref <- if (nrow(ref) == 0) {
                integer()
            } else {
                current_seq[img_num %in% unique(ref$img_num), unique(rowid)]
            }
            flagged_rows <- sort(unique(c(rows_dup_current, rows_dup_ref)))
            if (!length(flagged_rows)) {
                empty
            } else {
                data.table::data.table(rowid = flagged_rows, variable = "photo_start", reason = "Photo range overlaps image numbers already used in NESTS, CAPTURES, RESIGHTINGS, or another current row.")
            }
        }
    }, nam = "photo numbers unique")
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
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        state_key <- trimws(as.character(z$nest_state))
        discovery_idx <- which(!is.na(state_key) & state_key %in% c("S", "F"))

        # Follow-up visits must never invoke the discovery-tally logic. This also
        # lets any observer enter a later I/H/pP/pD/P/D/notA visit for an existing nest.
        if (length(discovery_idx) == 0) {
            empty
        } else {
            z <- z[discovery_idx]
            z[, `:=`(
                nest_key = trimws(as.character(nest_id)),
                event_date = suppressWarnings(as.Date(date)),
                event_time = trimws(as.character(time_visit))
            )]

            # A discovery identity is shared across CR plots and the non-CR BA prefix:
            # prefix + GPS digits + the observer/GPS running tally, e.g. B0203 or BA0203.
            id_pat <- "^([ABC]|BA)([0-9]{2})([0-9]{2})$"
            valid_current <- !is.na(z$nest_key) & grepl(id_pat, z$nest_key)
            current <- z[which(valid_current), .(rowid, nest_key, event_date, event_time)]

            if (nrow(current) == 0) {
                empty
            } else {
            current[, `:=`(
                prefix = sub(id_pat, "\\1", nest_key, perl = TRUE),
                gps_code = sub(id_pat, "\\2", nest_key, perl = TRUE),
                tally = as.integer(sub(id_pat, "\\3", nest_key, perl = TRUE))
            )]

            # S and F can describe the same newly found nest, so assess each current
            # nest_id once, using its earliest submitted discovery row.
            current[is.na(event_time) | event_time == "", event_time := "99:99"]
            data.table::setorderv(current, c("event_date", "event_time", "rowid"), na.last = TRUE)
            candidates <- current[, .SD[1L], by = nest_key]

            existing0 <- tryCatch(
                db_get("SELECT nest_id, nest_state FROM NESTS"),
                error = function(e) NULL
            )
            existing <- data.table::data.table(gps_code = character(), tally = integer())
            existing_exact <- character()
            if (!is.null(existing0) && nrow(existing0) > 0) {
                existing_raw <- data.table::as.data.table(existing0)
                existing_raw[, nest_key := trimws(as.character(nest_id))]
                # An exact known nest_id makes a later S/F row a follow-up, not a discovery.
                existing_exact <- unique(existing_raw[
                    !is.na(nest_key) & nzchar(nest_key),
                    nest_key
                ])
                valid_existing <- !is.na(existing_raw$nest_key) & grepl(id_pat, existing_raw$nest_key)
                existing_raw <- existing_raw[which(
                    valid_existing & trimws(as.character(nest_state)) %in% c("S", "F")
                )]
                if (nrow(existing_raw) > 0) {
                    existing <- unique(existing_raw[, .(
                        gps_code = sub(id_pat, "\\2", nest_key, perl = TRUE),
                        tally = as.integer(sub(id_pat, "\\3", nest_key, perl = TRUE))
                    )])
                }
            }

            # Do not re-check a tally for a scrape/nest already discovered in NESTS.
            # This preserves the cross-plot conflict check for genuinely new nest IDs.
            candidates <- candidates[!nest_key %in% existing_exact]
            if (nrow(candidates) == 0) {
                empty
            } else {
            seen <- data.table::copy(existing)
            problems <- vector("list", nrow(candidates))

            for (i in seq_len(nrow(candidates))) {
                candidate <- candidates[i]
                same_tally <- seen[
                    gps_code == candidate$gps_code & tally == candidate$tally
                ]

                if (nrow(same_tally) > 0) {
                    used_tallies <- seen[gps_code == candidate$gps_code, tally]
                    next_tally <- if (length(used_tallies) == 0) 1L else max(used_tallies) + 1L
                    suggested_id <- if (next_tally <= 99L) {
                        paste0(candidate$prefix, candidate$gps_code, sprintf("%02d", next_tally))
                    } else {
                        NA_character_
                    }

                    problems[[i]] <- data.table::data.table(
                        nest_key = candidate$nest_key,
                        reason = if (is.na(suggested_id)) {
                            paste0(
                                "Nest ID tally ", candidate$gps_code, sprintf("%02d", candidate$tally),
                                " is already assigned to another discovered nest or scrape, and no unused two-digit tally remains for this GPS ID."
                            )
                        } else {
                            paste0(
                                "Nest ID tally ", candidate$gps_code, sprintf("%02d", candidate$tally),
                                " is already assigned to another discovered nest or scrape. The next available tally for this GPS ID is likely ", suggested_id, "."
                            )
                        }
                    )
                }

                seen <- unique(data.table::rbindlist(list(
                    seen,
                    candidate[, .(gps_code, tally)]
                )))
            }

            problems <- Filter(Negate(is.null), problems)
            if (length(problems) == 0) {
                empty
            } else {
                conflicts <- data.table::rbindlist(problems, use.names = TRUE)
                merge(
                    z[, .(rowid, nest_key)],
                    conflicts,
                    by = "nest_key",
                    all = FALSE,
                    sort = FALSE
                )[, .(rowid, variable = "nest_id", reason)]
            }
            }
            }
        }
    }, nam = "NEST_014 discovery tally")
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
