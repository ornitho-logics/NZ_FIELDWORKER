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
        has_positive_nest_id <- function(v) {
            raw <- trimws(as.character(v))
            !is.na(v) & nzchar(raw) & toupper(raw) != "NA" & toupper(raw) != "NO_NEST" & !grepl("^-", raw)
        }
        has_negative_brood_id <- function(v) {
            raw <- trimws(as.character(v))
            !is.na(v) & nzchar(raw) & grepl("^-", raw)
        }
        required_out <- is.na_validator(
            z[, .(species, observer, date, rclass, sex, age, rowid)],
            reason = "Required resighting field."
        )
        negative_brood_flag <- has_negative_brood_id(z$nest_id)
        rclass_key <- toupper(trimws(as.character(z$rclass)))
        h_flag <- !is.na(rclass_key) & rclass_key == "H"
        h_required_out <- data.table::rbindlist(lapply(c("species", "observer", "date", "rclass", "sex", "age"), function(col) {
            raw <- trimws(as.character(z[[col]]))
            bad_idx <- which(!is.na(z[[col]]) & rclass_key == "H" & (!nzchar(raw) | toupper(raw) == "NA"))
            if (length(bad_idx) == 0) {
                data.table::data.table(rowid = integer(), variable = character(), reason = character())
            } else {
                data.table::data.table(rowid = z$rowid[bad_idx], variable = col, reason = "H-class resighting fields must be present.")
            }
        }), use.names = TRUE, fill = TRUE)
        gps_required <- !has_positive_nest_id(z$nest_id) | h_flag
        z[, neg_flag := negative_brood_flag]
        positive_partial_gps <- z[
            !gps_required & xor(blankish(gps_id), blankish(gps_point)),
            .(
                rowid,
                variable = ifelse(blankish(gps_id), "gps_id", "gps_point"),
                reason = "gps_id and gps_point must be entered together; positive nest-linked rows should ordinarily leave both blank."
            )
        ]
        gps_id_missing <- z[
            gps_required & blankish(gps_id),
            .(
                rowid,
                variable = "gps_id",
                reason = ifelse(
                    h_flag,
                    "Hiding-spot photo events require both gps_id and gps_point, even when nest_id is recorded.",
                    ifelse(neg_flag, "Negative nest_id values identify broods found after hatching and require both gps_id and gps_point because there is no NESTS location.", "A GPS ID and GPS point are required when this resighting is not linked to a positive nest.")
                )
            )
        ]
        gps_point_missing <- z[
            gps_required & blankish(gps_point),
            .(
                rowid,
                variable = "gps_point",
                reason = ifelse(
                    h_flag,
                    "Hiding-spot photo events require both gps_id and gps_point, even when nest_id is recorded.",
                    ifelse(neg_flag, "Negative nest_id values identify broods found after hatching and require both gps_id and gps_point because there is no NESTS location.", "A GPS ID and GPS point are required when this resighting is not linked to a positive nest.")
                )
            )
        ]
        behav_missing <- z[
            !is.na(rclass_key) & rclass_key != "H" & blankish(behav),
            .(
                rowid,
                variable = "behav",
                reason = "Required resighting field."
            )
        ]
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
                h_required_out,
                gps_id_missing,
                gps_point_missing,
                positive_partial_gps,
                behav_missing,
                leg_missing
            ),
            use.names = TRUE,
            fill = TRUE
        )
    }, nam = "RES_001 mandatory")
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
        if (!"rclass" %in% names(z)) {
            z[, rclass := NA_character_]
        }
        if (!"UL" %in% names(z)) z[, UL := NA_character_]
        if (!"LL" %in% names(z)) z[, LL := NA_character_]
        if (!"UR" %in% names(z)) z[, UR := NA_character_]
        if (!"LR" %in% names(z)) z[, LR := NA_character_]
        blankish <- function(v) {
            raw <- trimws(as.character(v))
            is.na(v) | !nzchar(raw) | toupper(raw) == "NA"
        }
        rclass_key <- toupper(trimws(as.character(z$rclass)))
        ul_key <- toupper(trimws(as.character(z$UL)))
        ll_key <- toupper(trimws(as.character(z$LL)))
        ur_key <- toupper(trimws(as.character(z$UR)))
        lr_key <- toupper(trimws(as.character(z$LR)))
        single_colour <- c("B", "G", "R", "O", "W", "L", "Y")
        h_idx <- !is.na(rclass_key) & rclass_key == "H"
        out <- data.table::rbindlist(
            list(
                z[h_idx & ur_key == "M" & !blankish(UL), .(rowid, variable = "UL", reason = "For an H-class chick, UR = M means UL must be blank.")],
                z[h_idx & blankish(UR) & (is.na(ul_key) | ul_key != "M"), .(rowid, variable = "UL", reason = "For an H-class chick, if UR is blank, UL must contain the single metal band M.")],
                z[h_idx & ll_key %in% single_colour & !blankish(LR), .(rowid, variable = "LR", reason = "For an H-class chick, a single colour band in LL means LR must be blank.")],
                z[h_idx & blankish(LL) & !(lr_key %in% single_colour), .(rowid, variable = "LR", reason = "For an H-class chick, if LL is blank, LR must contain one colour band: B, G, R, O, W, L, or Y.")]
            ),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "RES_011 H chick band layout")
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
        if (!"rclass" %in% names(z)) {
            z[, rclass := NA_character_]
        }
        if (!"ring" %in% names(z)) {
            z[, ring := NA_character_]
        }
        rclass_key <- toupper(trimws(as.character(z$rclass)))
        ring_key <- trimws(as.character(z$ring))
        missing_ring <- is.na(z$ring) | is.na(ring_key) | !nzchar(ring_key) | toupper(ring_key) == "NA"
        z[
            !is.na(rclass_key) & rclass_key == "H" & missing_ring,
            .(
                rowid,
                variable = "ring",
                reason = "A metal-ring code is required for a hiding-spot-photo event (rclass H)."
            )
        ]
    }, nam = "RES_010 H ring")
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
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        is_positive_nest <- function(v) {
            raw <- trimws(as.character(v))
            !is.na(raw) & nzchar(raw) & raw != "NA" & toupper(raw) != "NO_NEST" & !grepl("^-", raw)
        }
        nests_dt <- data.table::as.data.table(db_get("SELECT nest_id, date, nest_state FROM NESTS"))
        if (nrow(nests_dt) > 0) {
            nests_dt <- data.table::copy(nests_dt)
            nests_dt[, `:=`(event_date_nest, suppressWarnings(as.Date(date)))]
            nests_dt <- nests_dt[
                nest_state %in% c("F", "I", "H") &
                !is.na(event_date_nest) &
                !is.na(nest_id) &
                nzchar(trimws(as.character(nest_id))),
                .(nest_id = trimws(as.character(nest_id)), event_date_nest)
            ]
            if (nrow(nests_dt) > 0) {
                data.table::setorder(nests_dt, nest_id, event_date_nest)
                nests_dt <- nests_dt[, .SD[1], by = nest_id]
            }
        } else {
            nests_dt <- data.table::data.table(nest_id = character(), event_date_nest = as.Date(character()))
        }
        z[, `:=`(event_date, suppressWarnings(as.Date(date)))]
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            nest_key <- trimws(as.character(row$nest_id[[1]]))
            event_date_val <- row$event_date[[1]]
            if (!is_positive_nest(nest_key) || is.na(event_date_val)) {
                return(empty)
            }
            first_f <- nests_dt[nest_id == nest_key]
            if (nrow(first_f) == 0) {
                return(data.table::data.table(
                    rowid = row$rowid,
                    variable = "nest_id",
                    reason = "Positive nest-linked RESIGHTINGS events require a same-day-or-earlier NESTS F, I, or H event for this nest_id."
                ))
            }
            first_date <- first_f$event_date_nest[[1]]
            if (event_date_val < first_date) {
                return(data.table::data.table(
                    rowid = row$rowid,
                    variable = "nest_id",
                    reason = "Positive nest-linked RESIGHTINGS events require a same-day-or-earlier NESTS F, I, or H event for this nest_id."
                ))
            }
            empty
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "RES_005F first nest event")
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
        present <- function(v) {
            raw <- trimws(as.character(v))
            !is.na(v) & nzchar(raw) & raw != "NA"
        }
        out <- z[
            present(cam_id) & present(photo_start) & present(photo_end) &
            !trimws(as.character(rclass)) %in% c("V", "P", "H"),
            .(rowid, variable = "rclass", reason = "When cam_id, photo_start, and photo_end are entered, rclass must be V, P, or H.")
        ]
        if (nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            unique(out)
        }
    }, nam = "RES_009B photo rclass")
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
        allowed_sites <- c("AR", "AU", "CH", "CL", "CR", "HC", "HR", "KK", "KP", "KT", "MB", "MR", "MS", "OD", "OK", "OM", "PB", "PR", "TA", "TO", "TP", "TR", "TS", "WA", "WN", "WS")
        raw <- trimws(as.character(z$site))
        present_idx <- which(!is.na(z$site) & nzchar(raw))
        bad_idx <- present_idx[!raw[present_idx] %in% allowed_sites]
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "site", reason = "Site must be a valid BDOT site code.")
        }
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
        out_parts <- list()
        if ("falcon_upload" %in% names(z)) {
            raw_falcon <- trimws(as.character(z[["falcon_upload"]]))
            bad_falcon <- which(
                !is.na(z[["falcon_upload"]]) &
                nzchar(raw_falcon) &
                !raw_falcon %in% c("0", "1")
            )
            if (length(bad_falcon) > 0) {
                out_parts[[length(out_parts) + 1L]] <- data.table::data.table(rowid = z$rowid[bad_falcon], variable = "falcon_upload", reason = "FALCON upload must be blank, 0, or 1.")
            }
        }
        if ("nov" %in% names(z)) {
            raw_nov <- trimws(as.character(z[["nov"]]))
            bad_nov <- which(!is.na(z[["nov"]]) & nzchar(raw_nov))
            if (length(bad_nov) > 0) {
                out_parts[[length(out_parts) + 1L]] <- data.table::data.table(rowid = z$rowid[bad_nov], variable = "nov", reason = "Validation flag must stay blank in this workflow.")
            }
        }
        out <- if (length(out_parts) == 0L) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE)
        }
        if (nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            unique(out)
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
            data.table::data.table(rowid = bad_idx, variable = "observer", reason = "Observer must exist in OBSERVERS and be active on the resighting date.")
        }
    }, nam = "RES_002 observer active")
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
        raw <- trimws(as.character(z$rclass))
        present_idx <- which(!is.na(z$rclass) & nzchar(raw))
        bad_idx <- present_idx[!raw[present_idx] %in% c("R", "V", "P", "C", "H")]
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "rclass", reason = "Resighting class must be R, V, P, C, or H.")
        }
    }, nam = "RES_003 rclass")
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
        rclass_key <- toupper(trimws(as.character(z$rclass)))
        age_key <- trimws(as.character(z$age))
        out <- data.table::rbindlist(
            list(
                z[!(sex %in% c("M", "MU", "F", "FU", "U")), .(rowid, variable = "sex", reason = "Sex must be M, MU, F, FU, or U.")],
                z[!(age %in% c("A", "J", "C")), .(rowid, variable = "age", reason = "Age must be A, J, or C.")],
                z[age %in% c("C", "J") & sex != "U", .(rowid, variable = "sex", reason = "Chick and juvenile resightings must use sex U.")],
                z[!is.na(rclass_key) & rclass_key == "H" & !is.na(age_key) & nzchar(age_key) & age_key != "C", .(rowid, variable = "age", reason = "Hiding-spot-photo resightings (rclass H) must use age C.")]
            ),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            unique(out)
        }
    }, nam = "RES_004 sex age")
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
        parse_behav <- function(v) {
            if (is.na(v) || !nzchar(trimws(as.character(v)))) {
                character()
            } else {
                trimws(unlist(strsplit(as.character(v), ",", fixed = TRUE)))
            }
        }
        allowed_cj_behav <- c("OB", "FT", "AT", "LF", "RS", "FF", "FA", "FC", "PR")
        bad_idx <- which(z$age %in% c("C", "J") & vapply(z$behav, function(v) {
            tokens <- parse_behav(v)
            length(tokens) > 0 && !all(tokens %in% allowed_cj_behav)
        }, logical(1)))
        if (length(bad_idx) == 0) {
            empty
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "behav", reason = "Chick and juvenile resightings can only use OB, FT, AT, LF, RS, FF, FA, FC, or PR.")
        }
    }, nam = "RES_004B behav age")
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
        prefix_map <- c(BADO = "BA", WRYB = "WR", SNZD = "SN", BFDO = "BF")
        raw_nest <- trimws(as.character(z$nest_id))
        is_no_nest <- function(v) {
            !is.na(v) & toupper(trimws(as.character(v))) == "NO_NEST"
        }
        nest_ok <- mapply(function(site, species, nest_id) {
            if (is.na(nest_id) || !nzchar(nest_id) || is_no_nest(nest_id)) {
                return(TRUE)
            }
            if (!is.na(site) && site == "CR") {
                return(grepl("^-?[ABC][0-9]{4}$", nest_id))
            }
            if (!is.na(species) && species %in% names(prefix_map)) {
                return(grepl(paste0("^-?", prefix_map[[species]], "[0-9]{4}$"), nest_id))
            }
            grepl("^(^-?[ABC][0-9]{4}$)|(^-?(BA|WR|SN|BF)[0-9]{4}$)$", nest_id)
        }, z$site, z$species, raw_nest, USE.NAMES = FALSE)
        bad_idx <- which(!nest_ok)
        if (length(bad_idx) == 0) {
            empty
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "nest_id", reason = ifelse(z$site[bad_idx] == "CR", "Cass River nest_id must use plot + gps_id + sequence, e.g. B0112 or -B0203.", "Non-CR nest_id values must use the species prefix plus four digits, e.g. BA0804 or -BA0804."))
        }
    }, nam = "RES_004C nest id")
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
        blankish <- function(v) {
            raw <- trimws(as.character(v))
            is.na(v) | !nzchar(raw) | toupper(raw) == "NA"
        }
        parse_behav <- function(v) {
            if (is.na(v) || !nzchar(trimws(as.character(v)))) {
                character()
            } else {
                trimws(unlist(strsplit(as.character(v), ",", fixed = TRUE)))
            }
        }
        is_no_nest <- function(v) {
            !is.na(v) & toupper(trimws(as.character(v))) == "NO_NEST"
        }
        clean_segment <- function(v) {
            raw <- trimws(as.character(v))
            raw[is.na(v) | !nzchar(raw) | raw == "NA"] <- NA_character_
            raw
        }
        is_unbanded_resighting <- function(ul, ll, ur, lr) {
            segs <- c(ul, ll, ur, lr)
            segs <- trimws(as.character(segs))
            segs[is.na(segs) | !nzchar(segs) | toupper(segs) == "NA"] <- NA_character_
            segs[toupper(segs) == "XX"] <- "X"
            all(is.na(segs) | segs %in% c("X", "M"))
        }
        normalize_tag_ur <- function(v) {
            raw <- clean_segment(v)
            out <- raw
            tag_like <- !is.na(raw) & grepl("^T[A-Z0-9]*[RBGWOLY]$", raw)
            out[tag_like] <- paste0("T", sub("^.*([RBGWOLY])$", "\\1", raw[tag_like]))
            out
        }
        normalize_mark_string <- function(v) {
            raw <- clean_segment(v)
            out <- vapply(raw, function(one) {
                if (is.na(one) || !nzchar(one)) {
                    return(NA_character_)
                }
                sides <- strsplit(one, "-", fixed = TRUE)[[1]]
                if (length(sides) != 2) {
                    return(one)
                }
                normalize_side <- function(side) {
                    if (is.na(side) || !nzchar(side) || side == "X") {
                        return("X")
                    }
                    segs <- trimws(unlist(strsplit(side, ".", fixed = TRUE)))
                    segs <- segs[nzchar(segs)]
                    if (!length(segs)) {
                        return("X")
                    }
                    segs <- vapply(segs, function(seg) {
                        if (grepl("^T[A-Z0-9]*[RBGWOLY]$", seg)) {
                            paste0("T", sub("^.*([RBGWOLY])$", "\\1", seg))
                        } else {
                            seg
                        }
                    }, character(1))
                    paste(segs, collapse = ".")
                }
                paste0(normalize_side(sides[1]), "-", normalize_side(sides[2]))
            }, character(1))
            out
        }
        make_mark <- function(ul, ll, ur, lr) {
            ul1 <- clean_segment(ul)
            ll1 <- clean_segment(ll)
            ur1 <- clean_segment(normalize_tag_ur(ur))
            lr1 <- clean_segment(lr)
            left <- c()
            right <- c()
            if (!is.na(ul1) && !ul1 %in% c("X", "M")) {
                left <- c(left, ul1)
            }
            if (!is.na(ll1) && !ll1 %in% c("X", "M")) {
                left <- c(left, ll1)
            }
            if (!is.na(ur1) && !ur1 %in% c("X", "M")) {
                right <- c(right, ur1)
            }
            if (!is.na(lr1) && !lr1 %in% c("X", "M")) {
                right <- c(right, lr1)
            }
            paste0(
                if (length(left)) paste(left, collapse = ".") else "X",
                "-",
                if (length(right)) paste(right, collapse = ".") else "X"
            )
        }
        normalize_time <- function(v) {
            raw <- trimws(as.character(v))
            raw[is.na(v) | !nzchar(raw) | raw == "NA"] <- "99:99"
            with_seconds <- grepl("^\\d{2}:\\d{2}:\\d{2}$", raw)
            raw[with_seconds] <- substr(raw[with_seconds], 1, 5)
            raw
        }
        split_marks <- function(v) {
            raw <- clean_segment(v)
            if (!length(raw) || is.na(raw[1])) {
                return(character())
            }
            vals <- trimws(unlist(strsplit(raw[1], ",", fixed = TRUE)))
            vals <- vals[nzchar(vals)]
            if (!length(vals)) {
                character()
            } else {
                unique(normalize_mark_string(vals))
            }
        }
        is_active_link <- function(nest_key, event_date, event_time_key, nests_dt, terminal_states) {
            nk <- trimws(as.character(nest_key))
            if (is.na(nk) || !nzchar(nk)) {
                return(FALSE)
            }
            if (is_no_nest(nk)) {
                return(FALSE)
            }
            if (grepl("^-", nk)) {
                return(TRUE)
            }
            tmp <- nests_dt[
                nest_id == nk &
                !is.na(event_date_nest) &
                (
                    event_date_nest < event_date |
                    (event_date_nest == event_date & time_visit_key <= event_time_key)
                )
            ]
            if (nrow(tmp) == 0) {
                return(FALSE)
            }
            data.table::setorder(tmp, event_date_nest, time_visit_key)
            !(as.character(tmp$nest_state[nrow(tmp)]) %in% terminal_states)
        }
        current_caps <- data.table::as.data.table(db_get("SELECT date, caught, nest_id, age, field_sex, UL, LL, UR, LR FROM CAPTURES"))
        current_nests <- data.table::as.data.table(db_get("SELECT nest_id, date, time_visit, nest_state FROM NESTS"))
        nests_latest <- data.table::as.data.table(db_get("SELECT nest_id, nest_state, last_visit_datetime, M_mark, F_mark FROM NESTS_LATEST"))
        link_terminal_states <- c("pP", "P", "D", "notA")
        if (nrow(current_caps) > 0) {
            current_caps[, `:=`(mark, mapply(make_mark, UL, LL, UR, LR, USE.NAMES = FALSE))]
            current_caps[, `:=`(date, suppressWarnings(as.Date(date)))]
            current_caps[, `:=`(caught_key, normalize_time(caught))]
        } else {
            current_caps <- data.table::data.table(date = as.Date(character()), caught_key = character(), nest_id = character(), age = character(), field_sex = character(), mark = character())
        }
        if (nrow(current_nests) > 0) {
            current_nests[, `:=`(event_date_nest, suppressWarnings(as.Date(date)))]
            current_nests[, `:=`(time_visit_key, normalize_time(time_visit))]
        } else {
            current_nests <- data.table::data.table(nest_id = character(), nest_state = character(), event_date_nest = as.Date(character()), time_visit_key = character())
        }
        if (nrow(nests_latest) > 0) {
            empty_links <- data.table::data.table(nest_id = character(), sex_key = character(), mark = character())
            latest_links <- data.table::rbindlist(lapply(c("M", "F"), function(sex_key) {
                col <- paste0(sex_key, "_mark")
                if (!col %in% names(nests_latest)) {
                    return(empty_links)
                }
                tmp <- nests_latest[, .(nest_id, sex_key = sex_key, mark_blob = get(col))]
                tmp <- tmp[!is.na(mark_blob) & nzchar(trimws(as.character(mark_blob)))]
                if (nrow(tmp) == 0) {
                    return(empty_links)
                }
                tmp[, mark_list := lapply(mark_blob, split_marks)]
                tmp <- tmp[lengths(mark_list) > 0]
                if (nrow(tmp) == 0) {
                    return(empty_links)
                }
                tmp[, .(mark = unlist(mark_list)), by = .(nest_id, sex_key)]
            }), use.names = TRUE, fill = TRUE)
            latest_links <- unique(latest_links[!is.na(mark) & nzchar(mark)])
        } else {
            latest_links <- data.table::data.table(nest_id = character(), sex_key = character(), mark = character())
        }
        z[, `:=`(mark, mapply(make_mark, UL, LL, UR, LR, USE.NAMES = FALSE))]
        z[, `:=`(event_date, suppressWarnings(as.Date(date)))]
        z[, `:=`(event_time_key, "99:99")]
        z[, `:=`(age_key, trimws(as.character(age)))]
        z[, `:=`(rclass_key, toupper(trimws(as.character(rclass))))]
        z[, `:=`(behav_tokens, lapply(behav, parse_behav))]
        z[, `:=`(is_chick, !is.na(age_key) & age_key == "C")]
        parent_behaviour_codes <- c("IN", "NM", "BW", "BC", "FC")
        z[, `:=`(
            is_parent_behaviour = !is.na(age_key) & age_key == "A" &
                vapply(behav_tokens, function(tok) any(tok %in% parent_behaviour_codes), logical(1))
        )]
        if (!"ring" %in% names(z)) {
            z[, ring := NA_character_]
        }
        gps_id_key <- trimws(as.character(z$gps_id))
        gps_point_key <- trimws(as.character(z$gps_point))
        parent_same_gps <- vapply(seq_len(nrow(z)), function(i) {
            if (isTRUE(blankish(z$gps_id[i])) || isTRUE(blankish(z$gps_point[i]))) {
                return(FALSE)
            }
            any(
                !is.na(z$age) & trimws(as.character(z$age)) == "A" &
                    !blankish(z$gps_id) & !blankish(z$gps_point) &
                    !blankish(z$LL) & !blankish(z$LR) &
                    gps_id_key == gps_id_key[i] &
                    gps_point_key == gps_point_key[i]
            )
        }, logical(1))
        z[, `:=`(parent_same_gps, parent_same_gps)]
        z[, `:=`(ring_present, !blankish(ring))]
        z[, `:=`(
            allow_unlinked_h_chick =
                blankish(nest_id) &
                rclass_key == "H" &
                age_key == "C" &
                !blankish(gps_id) &
                !blankish(gps_point) &
                (ring_present | parent_same_gps)
        )]
        z[, `:=`(needs_nest_id, (is_chick & !allow_unlinked_h_chick) | is_parent_behaviour)]
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            row_is_chick <- isTRUE(row$is_chick)
            row_is_parent_behaviour <- isTRUE(row$is_parent_behaviour)
            row_is_h <- isTRUE(row$rclass_key == "H")
            missing_chick_nest_reason <- if (row_is_h) {
                "An H-class chick may omit nest_id only when ring is entered or a same-session age-A parent with LL and LR is recorded at the same GPS pair."
            } else {
                "Chick resightings must record nest_id."
            }
            missing_parent_nest_reason <- "This adult IN/NM/BW/BC/FC resighting is the first active-nest record for this breeding attempt, so please enter nest_id."
            if (!isTRUE(row$needs_nest_id)) {
                return(empty)
            }
            if ((is.na(row$nest_id) || !nzchar(trimws(as.character(row$nest_id)))) && row_is_chick) {
                return(data.table::data.table(rowid = row$rowid, variable = "nest_id", reason = missing_chick_nest_reason))
            }
            if ((is.na(row$nest_id) || !nzchar(trimws(as.character(row$nest_id)))) && row_is_parent_behaviour) {
                return(data.table::data.table(rowid = row$rowid, variable = "nest_id", reason = missing_parent_nest_reason))
            }
            row_nest <- trimws(as.character(row$nest_id))
            row_has_real_nest <- !is.na(row_nest) && nzchar(row_nest) && !is_no_nest(row_nest)
            row_is_unbanded <- is_unbanded_resighting(row$UL[[1]], row$LL[[1]], row$UR[[1]], row$LR[[1]])
            if (row_has_real_nest && row_is_unbanded) {
                return(empty)
            }
            row_mark <- clean_segment(row$mark)
            row_sex <- trimws(as.character(row$sex))
            if ((!row_has_real_nest) && (row_is_unbanded || is.na(row_mark) || !nzchar(row_mark) || row_mark == "X-X")) {
                return(data.table::data.table(rowid = row$rowid, variable = "nest_id", reason = missing_parent_nest_reason))
            }
            sex_key_val <- substr(row_sex, 1, 1)
            latest_candidates <- if (sex_key_val %in% c("M", "F")) {
                unique(latest_links[sex_key == sex_key_val & mark == row_mark, nest_id])
            } else {
                unique(latest_links[mark == row_mark, nest_id])
            }
            latest_candidates <- trimws(as.character(latest_candidates))
            latest_candidates <- latest_candidates[
                !is.na(latest_candidates) &
                nzchar(latest_candidates) &
                !is_no_nest(latest_candidates)
            ]
            linked_active <- length(latest_candidates) > 0 && any(vapply(latest_candidates, function(nk) {
                is_active_link(nk, row$event_date, row$event_time_key, current_nests, link_terminal_states)
            }, logical(1)))
            problems <- list()
            if (!row_has_real_nest && row_is_chick) {
                return(data.table::data.table(rowid = row$rowid, variable = "nest_id", reason = missing_chick_nest_reason))
            }
            if (!row_has_real_nest && row_is_parent_behaviour) {
                return(data.table::data.table(rowid = row$rowid, variable = "nest_id", reason = missing_parent_nest_reason))
            }
            if (!row_has_real_nest) {
                if (!linked_active) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "nest_id", reason = missing_parent_nest_reason)
                }
            }
            if (length(problems) == 0) {
                empty
            } else {
                data.table::rbindlist(problems)
            }
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "RES_005B nest link")
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
        parse_behav <- function(v) {
            if (is.na(v) || !nzchar(trimws(as.character(v)))) {
                character()
            } else {
                trimws(unlist(strsplit(as.character(v), ",", fixed = TRUE)))
            }
        }
        is_no_nest <- function(v) {
            !is.na(v) & toupper(trimws(as.character(v))) == "NO_NEST"
        }
        nests_dt <- data.table::as.data.table(db_get("SELECT nest_id, date, time_visit, nest_state FROM NESTS"))
        if (nrow(nests_dt) > 0) {
            nests_dt[, `:=`(event_date_nest, suppressWarnings(as.Date(date)))]
            nests_dt[, `:=`(time_visit_key, trimws(as.character(time_visit)))]
            nests_dt[is.na(time_visit_key) | !nzchar(time_visit_key), `:=`(time_visit_key, "99:99")]
        } else {
            nests_dt <- data.table::data.table(nest_id = character(), nest_state = character(), event_date_nest = as.Date(character()), time_visit_key = character())
        }
        z[, `:=`(event_date, suppressWarnings(as.Date(date)))]
        z[, `:=`(behav_tokens, lapply(behav, parse_behav))]
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            nest_key <- trimws(as.character(row$nest_id))
            parent_behaviour_codes <- c("IN", "NM", "BW", "BC", "FC")
            if (row$age != "A" || is.na(nest_key) || !nzchar(nest_key) || is_no_nest(nest_key) || grepl("^-", nest_key) || is.na(row$event_date) || !any(row$behav_tokens[[1]] %in% parent_behaviour_codes)) {
                return(empty)
            }
            tmp <- nests_dt[nest_id == nest_key & !is.na(event_date_nest) & event_date_nest <= row$event_date]
            if (nrow(tmp) == 0) {
                return(empty)
            }
            data.table::setorder(tmp, event_date_nest, time_visit_key)
            latest_state <- as.character(tmp$nest_state[nrow(tmp)])
            if (latest_state %in% c("H", "pP", "P", "D", "notA")) {
                data.table::data.table(rowid = row$rowid, variable = "nest_id", reason = "This nest_id had already hatched or otherwise ended by this date. If this is a new breeding attempt, enter the new nest_id.")
            } else {
                empty
            }
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "RES_005D ended nest")
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
        clean_segment <- function(v) {
            raw <- trimws(as.character(v))
            raw[is.na(v) | !nzchar(raw) | raw == "NA"] <- NA_character_
            raw
        }
        normalize_scalar_chr <- function(v) {
            out <- clean_segment(v)
            out
        }
        normalize_tag_ur <- function(v) {
            raw <- normalize_scalar_chr(v)
            out <- raw
            tag_like <- !is.na(raw) & grepl("^T[A-Z0-9]*[RBGWOLY]$", raw)
            out[tag_like] <- paste0("T", sub("^.*([RBGWOLY])$", "\\1", raw[tag_like]))
            out
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
                    !is.na(lr1) & grepl("^[RBGWOLY]{2}$", lr1),
                lr1,
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
        make_combo <- function(dt) {
            mapply(combo_identity, dt$UL, dt$LL, dt$UR, dt$LR, USE.NAMES = FALSE)
        }
        make_signature_dt <- function(dt, ul_col = "UL", ll_col = "LL", ur_col = "UR", lr_col = "LR") {
            tmp <- data.table::copy(dt)
            ul_vals <- tmp[[ul_col]]
            ll_vals <- tmp[[ll_col]]
            ur_vals <- tmp[[ur_col]]
            lr_vals <- tmp[[lr_col]]
            flag_ul <- normalize_scalar_chr(ul_vals)
            flag_ul[is.na(flag_ul) | !grepl("^F[A-Z0-9]+$", flag_ul)] <- NA_character_
            flag_ur <- normalize_scalar_chr(ur_vals)
            flag_ur[is.na(flag_ur) | !grepl("^F[A-Z0-9]+$", flag_ur)] <- NA_character_
            tmp[, `:=`(
                left_pair = canonical_left_pair(ul_vals, ll_vals),
                right_pair = canonical_right_pair(ur_vals, lr_vals),
                flag_ul = flag_ul,
                flag_ur = flag_ur
            )]
            tmp[, `:=`(has_signature, !is.na(left_pair) | !is.na(right_pair) | !is.na(flag_ul) | !is.na(flag_ur))]
            tmp
        }
        matches_signature <- function(row, hist) {
            if (!nrow(hist) || !isTRUE(row$has_signature[[1]])) {
                return(FALSE)
            }
            keep <- rep(TRUE, nrow(hist))
            if (!is.na(row$left_pair[[1]])) {
                keep <- keep & !is.na(hist$left_pair) & hist$left_pair == row$left_pair[[1]]
            }
            if (!is.na(row$right_pair[[1]])) {
                keep <- keep & !is.na(hist$right_pair) & hist$right_pair == row$right_pair[[1]]
            }
            if (!is.na(row$flag_ul[[1]])) {
                keep <- keep & !is.na(hist$flag_ul) & hist$flag_ul == row$flag_ul[[1]]
            }
            if (!is.na(row$flag_ur[[1]])) {
                keep <- keep & !is.na(hist$flag_ur) & hist$flag_ur == row$flag_ur[[1]]
            }
            any(keep)
        }
        dead_caps <- data.table::as.data.table(db_get("SELECT date, capture_status, UL_in, LL_in, UR_in, LR_in FROM CAPTURES"))
        if (nrow(dead_caps) == 0) {
            empty
        } else {
            dead_caps <- dead_caps[capture_status == "D"]
            if (nrow(dead_caps) == 0) {
                empty
            } else {
                dead_caps[, `:=`(death_date = suppressWarnings(as.Date(date)))]
                dead_caps <- make_signature_dt(dead_caps, ul_col = "UL_in", ll_col = "LL_in", ur_col = "UR_in", lr_col = "LR_in")
                dead_caps <- dead_caps[!is.na(death_date) & !is.na(has_signature) & has_signature]
                if (nrow(dead_caps) == 0) {
                    empty
                } else {
                    z <- make_signature_dt(z)
                    z[, `:=`(event_date, suppressWarnings(as.Date(date)))]
                    out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
                        row <- z[i]
                        rowid_val <- row$rowid[[1]]
                        event_date_val <- row$event_date[[1]]
                        if (is.na(event_date_val) || !isTRUE(row$has_signature[[1]])) {
                            return(empty)
                        }
                        if (matches_signature(row, dead_caps[death_date < event_date_val])) {
                            data.table::data.table(
                                rowid = rowid_val,
                                variable = "UL",
                                reason = "This combo was already recorded dead in CAPTURES before this resighting date."
                            )
                        } else {
                            empty
                        }
                    }), use.names = TRUE, fill = TRUE)
                    if (nrow(out) == 0) empty else unique(out)
                }
            }
        }
    }, nam = "RES_005E post-death")
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
        is_present <- function(v) {
            raw <- trimws(as.character(v))
            !is.na(v) & nzchar(raw) & raw != "NA"
        }
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            problems <- list()
            photo_required <- !is.na(row$rclass) && trimws(as.character(row$rclass)) %in% c("V", "P", "H")
            has_cam <- is_present(row$cam_id)
            has_start <- is_present(row$photo_start)
            has_end <- is_present(row$photo_end)
            any_present <- has_cam || has_start || has_end
            all_present <- has_cam && has_start && has_end
            if (photo_required && !all_present) {
                if (!has_cam) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "cam_id", reason = "rclass V, P, and H require cam_id, photo_start, and photo_end.")
                }
                if (!has_start) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_start", reason = "rclass V, P, and H require cam_id, photo_start, and photo_end.")
                }
                if (!has_end) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_end", reason = "rclass V, P, and H require cam_id, photo_start, and photo_end.")
                }
            } else if (any_present && !all_present) {
                if (!has_cam) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "cam_id", reason = "cam_id, photo_start, and photo_end must all be entered together.")
                }
                if (!has_start) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_start", reason = "cam_id, photo_start, and photo_end must all be entered together.")
                }
                if (!has_end) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_end", reason = "cam_id, photo_start, and photo_end must all be entered together.")
                }
            }
            if (all_present) {
                start_no <- photo_seq_num(row$photo_start)
                end_no <- photo_seq_num(row$photo_end)
                if (is.na(start_no) || is.na(end_no)) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_start", reason = "Photo filenames must end with numeric suffixes.")
                } else if (start_no > end_no) {
                  problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "photo_end", reason = "photo_end sequence must not be earlier than photo_start.")
                }
            }
            if (length(problems) == 0) empty else data.table::rbindlist(problems)
        }), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "RES_009 photo metadata")
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
            out <- tmp[, .(photo_no = seq.int(start_no, end_no)), by = rowid]
            out[, `:=`(table_name, table_name)]
            out[, .(table_name, rowid, photo_no)]
        }
        other_caps <- data.table::as.data.table(db_get("SELECT photo_start, photo_end FROM CAPTURES"))
        other_nests <- data.table::as.data.table(db_get("SELECT photo_start, photo_end FROM NESTS"))
        current_expanded <- expand_ranges(z[, .(rowid, photo_start, photo_end)], "RESIGHTINGS")
        other_caps_expanded <- expand_ranges(other_caps[, .(photo_start, photo_end)], "CAPTURES")
        other_nests_expanded <- expand_ranges(other_nests[, .(photo_start, photo_end)], "NESTS")
        all_expanded <- data.table::rbindlist(list(current_expanded, other_caps_expanded, other_nests_expanded), use.names = TRUE, fill = TRUE)
        dup_photo <- all_expanded[, .N, by = photo_no][N > 1, photo_no]
        if (length(dup_photo) == 0) {
            empty
        } else {
            flagged <- unique(current_expanded[photo_no %in% dup_photo, rowid])
            if (length(flagged) == 0) {
                empty
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
        raw <- trimws(as.character(z$gps_id))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$gps_id) & nzchar(raw) & (is.na(parsed) | parsed < 1 | parsed != floor(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "gps_id", reason = "GPS ID must be a positive whole number.")
        }
    }, nam = "gps id format")
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
        raw <- trimws(as.character(z$gps_point))
        parsed <- suppressWarnings(as.numeric(raw))
        bad_idx <- which(!is.na(z$gps_point) & nzchar(raw) & (is.na(parsed) | parsed < 1 | parsed != floor(parsed)))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "gps_point", reason = "GPS point must be a positive whole number.")
        }
    }, nam = "gps point format")
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
        is.regexp_validator(z, regexp = "^(X|[OYWBRGLM]{1,2}|F[OYWBRGLM][A-Z0-9]{2,3})$", reason = "Left tibia code does not match the current RESIGHTINGS format.")
    }, nam = "left tibia format")
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
        is.regexp_validator(z, regexp = "^(X|XX|[OYWBRGLM]{1,2})$", reason = "Left tarsus code does not match the current RESIGHTINGS format.")
    }, nam = "left tarsus format")
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
        is.regexp_validator(z, regexp = "^(X|[OYWBRGLM]{1,2}|T[A-Z0-9]{0,5}[RBGWOLY]|F[OYWBRGLM][A-Z0-9]{2,3})$", reason = "Right tibia code does not match the current RESIGHTINGS format.")
    }, nam = "right tibia format")
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
        is.regexp_validator(z, regexp = "^(X|XX|[OYWBRGLM]{1,2})$", reason = "Right tarsus code does not match the current RESIGHTINGS format.")
    }, nam = "right tarsus format")
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
        allowed <- c("IN", "CO", "PR", "BW", "BC", "NM", "SC", "FC", "FA", "FM", "FF", "RS", "LF", "AT", "FT", "OB")
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
    }, nam = "behaviour tokens")
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
    out <- try_validator(is.regexp_validator(x[, .(cam_id)], regexp = "^[A-Za-z0-9]{2,3}$", reason = "Camera ID must use the current two- or three-character format."), nam = "camera id format")
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
        present <- function(v) {
            raw <- trimws(as.character(v))
            !is.na(v) & nzchar(raw) & raw != "NA"
        }
        filename_ok <- function(v) {
            grepl("^[A-Za-z0-9._-]+$", trimws(as.character(v)))
        }
        out <- data.table::rbindlist(lapply(c("photo_start", "photo_end"), function(col) {
            bad_idx <- which(present(z[[col]]) & !filename_ok(z[[col]]))
            if (length(bad_idx) == 0) {
                return(NULL)
            }
            data.table::data.table(rowid = z$rowid[bad_idx], variable = col, reason = "Photo filename has unexpected characters.")
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) {
            empty
        } else {
            out
        }
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
}, {
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        if (!"rclass" %in% names(z)) {
            z[, rclass := NA_character_]
        }
        if (!"ring" %in% names(z)) {
            z[, ring := NA_character_]
        }
        rclass_key <- toupper(trimws(as.character(z$rclass)))
        ring_key <- toupper(trimws(as.character(z$ring)))
        missing_ring <- is.na(z$ring) | is.na(ring_key) | !nzchar(ring_key) | ring_key == "NA"
        bad_idx <- which(
            !is.na(rclass_key) & rclass_key == "H" & !missing_ring &
                !grepl("^CP-?[0-9]{5}$", ring_key)
        )
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(
                rowid = z$rowid[bad_idx],
                variable = "ring",
                reason = "For an H-class chick, ring must use the CP metal-ring format, e.g. CP20315 or CP-20315."
            )
        }
    }, nam = "RES_010A H ring format")
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
        if (!"rclass" %in% names(z)) {
            z[, rclass := NA_character_]
        }
        if (!"ring" %in% names(z)) {
            z[, ring := NA_character_]
        }
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        rclass_key <- toupper(trimws(as.character(z$rclass)))
        ring_key <- toupper(trimws(as.character(z$ring)))
        missing_ring <- is.na(z$ring) | is.na(ring_key) | !nzchar(ring_key) | ring_key == "NA"
        valid_h <- !is.na(rclass_key) & rclass_key == "H" & !missing_ring & grepl("^CP-?[0-9]{5}$", ring_key)
        if (!any(valid_h)) {
            empty
        } else {
            captured <- tryCatch(
                data.table::as.data.table(db_get("SELECT ring, UL, LL, UR, LR FROM CAPTURES")),
                error = function(e) NULL
            )
            if (is.null(captured) || !"ring" %in% names(captured)) {
                z[valid_h, .(
                    rowid,
                    variable = "ring",
                    reason = "The H-class chick ring could not be confirmed in CAPTURES. Enter a CP ring that has already been recorded in CAPTURES."
                )]
            } else {
                captured_key <- toupper(trimws(as.character(captured$ring)))
                captured_key <- sub("^CP-", "CP", captured_key)
                captured_key <- captured_key[!is.na(captured_key) & nzchar(captured_key) & captured_key != "NA"]
                entered_key <- sub("^CP-", "CP", ring_key)
                missing_history <- valid_h & !(entered_key %in% unique(captured_key))
                z[missing_history, .(
                    rowid,
                    variable = "ring",
                    reason = "An H-class chick ring must already exist in CAPTURES because the chick must have been banded before its hiding-spot photo was taken."
                )]
            }
        }
    }, nam = "RES_010B H ring in CAPTURES")
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
