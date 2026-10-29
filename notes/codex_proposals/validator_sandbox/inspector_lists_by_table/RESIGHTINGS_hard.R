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
        age_key <- toupper(trimws(as.character(z$age)))
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
            !is.na(rclass_key) &
                rclass_key != "H" &
                !(rclass_key == "R" & age_key == "C") &
                blankish(behav),
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
            is.na(v) | !nzchar(raw) | toupper(raw) %in% c("NA", "X", "XX")
        }
        is_uncertain <- function(v) {
            raw <- trimws(as.character(v))
            !is.na(v) & grepl("?", raw, fixed = TRUE)
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
                z[h_idx & ur_key == "M" & !blankish(UL) & !is_uncertain(UL), .(rowid, variable = "UL", reason = "For an H-class chick, UR = M means UL must be blank.")],
                z[h_idx & blankish(UR) & !is_uncertain(UR) & !is_uncertain(UL) & (is.na(ul_key) | ul_key != "M"), .(rowid, variable = "UL", reason = "For an H-class chick, if UR is blank, UL must contain the single metal band M.")],
                z[h_idx & ll_key %in% single_colour & !blankish(LR) & !is_uncertain(LR), .(rowid, variable = "LR", reason = "For an H-class chick, a single colour band in LL means LR must be blank.")],
                z[h_idx & blankish(LL) & !is_uncertain(LL) & !is_uncertain(LR) & !(lr_key %in% single_colour), .(rowid, variable = "LR", reason = "For an H-class chick, if LL is blank, LR must contain one colour band: B, G, R, O, W, L, or Y.")]
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
        nests_dt <- data.table::as.data.table(db_get("SELECT nest_id, date, time_visit, nest_state, pk FROM NESTS"))
        if (nrow(nests_dt) > 0) {
            nests_dt <- data.table::copy(nests_dt)
            if (!"time_visit" %in% names(nests_dt)) {
                nests_dt[, time_visit := NA_character_]
            }
            if (!"pk" %in% names(nests_dt)) {
                nests_dt[, pk := NA_real_]
            }
            nests_dt[, `:=`(
                event_date_nest = suppressWarnings(as.Date(date)),
                nest_key = trimws(as.character(nest_id)),
                state_key = toupper(trimws(as.character(nest_state))),
                time_visit_key = trimws(as.character(time_visit)),
                pk_key = suppressWarnings(as.numeric(as.character(pk)))
            )]
            nests_dt[is.na(time_visit_key) | !nzchar(time_visit_key) | toupper(time_visit_key) == "NA", time_visit_key := "99:99:99"]
            nests_dt[is.na(pk_key), pk_key := -Inf]
            nests_dt <- nests_dt[
                !is.na(event_date_nest) &
                is_positive_nest(nest_key),
                .(nest_id = nest_key, event_date_nest, state_key, time_visit_key, pk_key)
            ]
            if (nrow(nests_dt) > 0) {
                data.table::setorder(nests_dt, nest_id, event_date_nest, time_visit_key, pk_key)
            }
        } else {
            nests_dt <- data.table::data.table(
                nest_id = character(), event_date_nest = as.Date(character()),
                state_key = character(), time_visit_key = character(), pk_key = numeric()
            )
        }
        z[, `:=`(event_date, suppressWarnings(as.Date(date)))]
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            nest_key <- trimws(as.character(row$nest_id[[1]]))
            event_date_val <- row$event_date[[1]]
            if (!is_positive_nest(nest_key) || is.na(event_date_val)) {
                return(empty)
            }
            history <- nests_dt[
                nest_id == nest_key &
                    !is.na(event_date_nest) &
                    event_date_nest <= event_date_val
            ]
            history <- history[order(event_date_nest, time_visit_key, pk_key)]
            age_key <- toupper(trimws(as.character(row$age[[1]])))
            behav_raw <- toupper(trimws(as.character(row$behav[[1]])))
            behav_tokens <- if (is.na(behav_raw) || !nzchar(behav_raw) || behav_raw == "NA") {
                character()
            } else {
                trimws(unlist(strsplit(behav_raw, ",", fixed = TRUE)))
            }
            scrape_exception <- nrow(history) > 0L &&
                identical(age_key, "A") &&
                identical(history$state_key[[nrow(history)]], "S") &&
                !any(behav_tokens %in% c("IN", "NM", "BW", "BC", "FC", "AC"))
            if (isTRUE(scrape_exception)) {
                return(empty)
            }
            first_f <- history[state_key %in% c("F", "I", "H")]
            if (nrow(first_f) == 0L || event_date_val < first_f$event_date_nest[[1]]) {
                return(data.table::data.table(
                    rowid = row$rowid,
                    variable = "nest_id",
                    reason = paste(
                        "Positive nest-linked RESIGHTINGS events require a same-day-or-earlier NESTS F, I, or H event.",
                        "Adult scraping (SC) or nonconfirming observations may instead use a same-day-or-earlier S scrape while S is still the latest nest state; IN/NM, BW, and BC/FC/AC follow their separate nest-stage rules."
                    )
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
            if (is.na(nest_id) || !nzchar(nest_id)) {
                return(TRUE)
            }
            if (is_no_nest(nest_id)) {
                return(FALSE)
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
            data.table::data.table(
                rowid = z$rowid[bad_idx],
                variable = "nest_id",
                reason = ifelse(
                    is_no_nest(raw_nest[bad_idx]),
                    "NO_NEST is no longer accepted. Leave nest_id blank for an unrelated resighting and enter both gps_id and gps_point, or enter the appropriate positive or negative nest_id.",
                    ifelse(
                        z$site[bad_idx] == "CR",
                        "Cass River nest_id must use plot + gps_id + sequence, e.g. B0112 or -B0203.",
                        "Non-CR nest_id values must use the species prefix plus four digits, e.g. BA0804 or -BA0804."
                    )
                )
            )
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
                if (grepl("?", one, fixed = TRUE)) {
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
            if (any(grepl("?", c(ul1, ll1, ur1, lr1), fixed = TRUE), na.rm = TRUE)) {
                return(NA_character_)
            }
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
        sex_key <- function(v) {
            raw <- toupper(trimws(as.character(v)))
            raw[is.na(v) | !nzchar(raw) | raw == "NA"] <- NA_character_
            out <- substr(raw, 1, 1)
            out[!out %in% c("M", "F")] <- NA_character_
            out
        }
        normalize_chr <- function(v) {
            raw <- trimws(as.character(v))
            raw[is.na(v) | !nzchar(raw) | toupper(raw) == "NA"] <- NA_character_
            raw
        }
        normalize_ring_key <- function(v) {
            raw <- toupper(trimws(as.character(v)))
            raw[is.na(v) | !nzchar(raw) | raw %in% c("NA", "N/A", "NULL")] <- NA_character_
            raw <- sub("^CP-?", "CP", raw)
            raw[!is.na(raw) & !grepl("^CP[0-9]{5}$", raw)] <- NA_character_
            raw
        }
        safe_db_get <- function(sql, columns) {
            result <- tryCatch(db_get(sql), error = function(e) NULL)
            if (is.null(result) || !is.data.frame(result)) {
                return(list(
                    ok = FALSE,
                    data = data.table::as.data.table(stats::setNames(
                        rep(list(character()), length(columns)), columns
                    ))
                ))
            }
            result <- data.table::as.data.table(result)
            for (column in setdiff(columns, names(result))) {
                result[, (column) := NA_character_]
            }
            list(ok = TRUE, data = result[, ..columns])
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
        current_nests <- data.table::as.data.table(db_get("SELECT nest_id, date, time_visit, nest_state FROM NESTS"))
        nests_latest <- data.table::as.data.table(db_get("SELECT nest_id, nest_state, last_visit_datetime, M_mark, F_mark FROM NESTS_LATEST"))
        link_terminal_states <- c("pP", "P", "D", "notA")
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
        if (!"site" %in% names(z)) {
            z[, site_key := NA_character_]
        } else {
            z[, `:=`(site_key, trimws(as.character(site)))]
            z[is.na(site) | !nzchar(site_key) | toupper(site_key) == "NA", site_key := NA_character_]
        }
        z[, `:=`(event_time_key, "99:99")]
        z[, `:=`(age_key, trimws(as.character(age)))]
        z[, `:=`(rclass_key, toupper(trimws(as.character(rclass))))]
        z[, `:=`(behav_tokens, lapply(behav, parse_behav))]
        z[, `:=`(is_chick, !is.na(age_key) & age_key == "C")]
        if (!"ring" %in% names(z)) {
            z[, ring := NA_character_]
        }
        z[, `:=`(ring_key, normalize_ring_key(ring))]
        has_uncertain_mark <- function(...) {
            values <- list(...)
            any(vapply(values, function(value) {
                raw <- trimws(as.character(value))
                !is.na(value) && nzchar(raw) && grepl("?", raw, fixed = TRUE)
            }, logical(1)))
        }
        z[, `:=`(uncertain_mark, vapply(seq_len(.N), function(i) {
            has_uncertain_mark(UL[[i]], LL[[i]], UR[[i]], LR[[i]])
        }, logical(1)))]
        z[, `:=`(
            lower_pair_observed = !blankish(LL) & !blankish(LR)
        )]
        parent_behaviour_codes <- c("IN", "NM", "BW", "BC", "FC", "AC", "SC")
        parent_with_chicks_codes <- c("BC", "FC", "AC")
        z[, `:=`(
            is_parent_behaviour = !is.na(age_key) & age_key == "A" &
                vapply(behav_tokens, function(tok) any(tok %in% parent_behaviour_codes), logical(1))
        )]
        z[, `:=`(
            is_parent_with_chicks = !is.na(age_key) & age_key == "A" &
                vapply(behav_tokens, function(tok) any(tok %in% parent_with_chicks_codes), logical(1))
        )]
        is_valid_brood_link <- function(v) {
            raw <- trimws(as.character(v))
            !is.na(v) & nzchar(raw) & toupper(raw) != "NA" & toupper(raw) != "NO_NEST"
        }
        parent_history_available <- TRUE
        parent_history <- data.table::data.table(
            history_mark = character(),
            history_ring_key = character(),
            history_sex_key = character(),
            history_date = as.Date(character()),
            history_nest_id = character(),
            history_pk = numeric()
        )
        parent_marks_to_check <- unique(z[
            is_parent_with_chicks & blankish(nest_id),
            mark
        ])
        parent_marks_to_check <- parent_marks_to_check[
            !is.na(parent_marks_to_check) &
                nzchar(parent_marks_to_check) &
                parent_marks_to_check != "X-X"
        ]
        parent_rings_to_check <- unique(z[
            is_parent_with_chicks & uncertain_mark & !blankish(ring),
            ring_key
        ])
        parent_rings_to_check <- parent_rings_to_check[
            !is.na(parent_rings_to_check) & nzchar(parent_rings_to_check)
        ]
        if (length(parent_marks_to_check) > 0L || length(parent_rings_to_check) > 0L) {
            capture_history <- safe_db_get(
                paste(
                    "SELECT pk, date, nest_id, age, field_sex, capture_status,",
                    "ring, UL_in, LL_in, UR_in, LR_in, UL, LL, UR, LR FROM CAPTURES",
                    "WHERE age = 'A'"
                ),
                c("pk", "date", "nest_id", "age", "field_sex", "capture_status",
                  "ring", "UL_in", "LL_in", "UR_in", "LR_in", "UL", "LL", "UR", "LR")
            )
            resighting_history <- safe_db_get(
                paste(
                    "SELECT pk, date, nest_id, age, sex, ring, UL, LL, UR, LR",
                    "FROM RESIGHTINGS WHERE age = 'A'"
                ),
                c("pk", "date", "nest_id", "age", "sex", "ring", "UL", "LL", "UR", "LR")
            )
            archive_capture_history <- safe_db_get(
                "SELECT date, nest_id, ring, field_sex FROM CAPTURES_ARCHIVE WHERE age = 'A'",
                c("date", "nest_id", "ring", "field_sex")
            )
            parent_history_available <- isTRUE(capture_history$ok) && isTRUE(resighting_history$ok)
            if (parent_history_available) {
                history_parts <- list()
                captures <- capture_history$data
                if (nrow(captures) > 0L) {
                    captures[, capture_status_key := toupper(trimws(as.character(capture_status)))]
                    deploy_mark <- !is.na(captures$capture_status_key) & captures$capture_status_key == "D"
                    captures[, `:=`(
                        history_mark = mapply(
                            make_mark,
                            ifelse(deploy_mark & !blankish(UL_in), UL_in, UL),
                            ifelse(deploy_mark & !blankish(LL_in), LL_in, LL),
                            ifelse(deploy_mark & !blankish(UR_in), UR_in, UR),
                            ifelse(deploy_mark & !blankish(LR_in), LR_in, LR),
                            USE.NAMES = FALSE
                        ),
                        history_ring_key = normalize_ring_key(ring),
                        history_sex_key = sex_key(field_sex),
                        history_date = suppressWarnings(as.Date(as.character(date))),
                        history_nest_id = trimws(as.character(nest_id)),
                        history_pk = suppressWarnings(as.numeric(pk))
                    )]
                    history_parts[[length(history_parts) + 1L]] <- captures[, .(
                        history_mark, history_ring_key, history_sex_key, history_date, history_nest_id, history_pk
                    )]
                }
                resightings <- resighting_history$data
                if (nrow(resightings) > 0L) {
                    resightings[, `:=`(
                        history_mark = mapply(make_mark, UL, LL, UR, LR, USE.NAMES = FALSE),
                        history_ring_key = normalize_ring_key(ring),
                        history_sex_key = sex_key(sex),
                        history_date = suppressWarnings(as.Date(as.character(date))),
                        history_nest_id = trimws(as.character(nest_id)),
                        history_pk = suppressWarnings(as.numeric(pk))
                    )]
                    history_parts[[length(history_parts) + 1L]] <- resightings[, .(
                        history_mark, history_ring_key, history_sex_key, history_date, history_nest_id, history_pk
                    )]
                }
                if (length(history_parts) > 0L) {
                    parent_history <- data.table::rbindlist(history_parts, use.names = TRUE, fill = TRUE)
                    parent_history <- parent_history[
                        (
                            (!is.na(history_mark) & nzchar(history_mark)) |
                                (!is.na(history_ring_key) & nzchar(history_ring_key))
                        ) &
                            !is.na(history_date)
                    ]
                }
            }
        }
        current_capture_ring_history <- data.table::data.table(
            history_ring_key = character(), history_sex_key = character(),
            history_date = as.Date(character()), history_nest_id = character()
        )
        capture_ring_identity <- data.table::data.table(
            history_ring_key = character(), history_sex_key = character(),
            history_date = as.Date(character())
        )
        if (exists("capture_history") && isTRUE(capture_history$ok)) {
            current_capture_rings <- capture_history$data[, .(
                history_ring_key = normalize_ring_key(ring),
                history_sex_key = sex_key(field_sex),
                history_date = suppressWarnings(as.Date(as.character(date))),
                history_nest_id = normalize_chr(nest_id)
            )]
            current_capture_ring_history <- current_capture_rings[
                !is.na(history_ring_key) & nzchar(history_ring_key) &
                    !is.na(history_date)
            ]
            identity_parts <- list(current_capture_rings[, .(
                history_ring_key, history_sex_key, history_date
            )])
            archive_rings <- if (exists("archive_capture_history") && isTRUE(archive_capture_history$ok)) {
                archive_capture_history$data[, .(
                    history_ring_key = normalize_ring_key(ring),
                    history_sex_key = sex_key(field_sex),
                    history_date = suppressWarnings(as.Date(as.character(date))),
                    history_nest_id = normalize_chr(nest_id)
                )]
            } else {
                current_capture_ring_history
            }
            identity_parts[[length(identity_parts) + 1L]] <- archive_rings[, .(
                history_ring_key, history_sex_key, history_date
            )]
            capture_ring_identity <- data.table::rbindlist(
                identity_parts,
                use.names = TRUE,
                fill = TRUE
            )[
                !is.na(history_ring_key) & nzchar(history_ring_key) &
                    !is.na(history_date)
            ]
        }
        parent_history_nest_ids <- function(mark_value, sex_value, event_date_value) {
            if (!parent_history_available ||
                is.na(mark_value) || !nzchar(mark_value) ||
                mark_value == "X-X" || is.na(event_date_value)) {
                return(character())
            }
            parent_sex_key <- sex_key(sex_value)[[1L]]
            candidates <- parent_history[
                history_mark == mark_value &
                    history_date <= event_date_value &
                    (
                        is.na(parent_sex_key) |
                        is.na(history_sex_key) |
                        history_sex_key == parent_sex_key
                    )
            ]
            if (nrow(candidates) == 0L) {
                return(character())
            }
            latest_date <- max(candidates$history_date)
            latest <- candidates[history_date == latest_date]
            valid_ids <- unique(latest[is_valid_brood_link(history_nest_id), history_nest_id])
            has_unresolved_latest <- any(!is_valid_brood_link(latest$history_nest_id))
            if (has_unresolved_latest || length(valid_ids) != 1L) {
                character()
            } else {
                valid_ids
            }
        }
        parent_history_resolvable <- function(mark_value, sex_value, event_date_value) {
            length(parent_history_nest_ids(mark_value, sex_value, event_date_value)) == 1L
        }
        parent_ring_history_nest_ids <- function(ring_value, sex_value, event_date_value) {
            if (nrow(current_capture_ring_history) == 0L ||
                is.na(ring_value) || !nzchar(ring_value) ||
                is.na(event_date_value)) {
                return(character())
            }
            parent_sex_key <- sex_key(sex_value)[[1L]]
            candidates <- current_capture_ring_history[
                history_ring_key == ring_value &
                    history_date <= event_date_value &
                    (
                        is.na(parent_sex_key) |
                            is.na(history_sex_key) |
                            history_sex_key == parent_sex_key
                    )
            ]
            if (nrow(candidates) == 0L) {
                return(character())
            }
            latest_date <- max(candidates$history_date)
            latest <- candidates[history_date == latest_date]
            valid_ids <- unique(latest[is_valid_brood_link(history_nest_id), history_nest_id])
            has_unresolved_latest <- any(!is_valid_brood_link(latest$history_nest_id))
            if (has_unresolved_latest || length(valid_ids) != 1L) character() else valid_ids
        }
        authoritative_parent_status <- safe_db_get(
            paste(
                "SELECT nest_id, M_selected_identity_key, F_selected_identity_key,",
                "M_selected_mark, F_selected_mark, M_association_pending,",
                "F_association_pending, M_association_ambiguous, F_association_ambiguous",
                "FROM ADULT_PARENT_STATUS",
                "WHERE LEFT(TRIM(nest_id), 1) = '-'"
            ),
            c(
                "nest_id", "M_selected_identity_key", "F_selected_identity_key",
                "M_selected_mark", "F_selected_mark", "M_association_pending",
                "F_association_pending", "M_association_ambiguous", "F_association_ambiguous"
            )
        )
        authoritative_status_available <- isTRUE(authoritative_parent_status$ok)
        authoritative_status <- authoritative_parent_status$data
        if (nrow(authoritative_status) > 0L) {
            authoritative_status[, `:=`(
                nest_key = normalize_chr(nest_id),
                M_identity_key = normalize_chr(M_selected_identity_key),
                F_identity_key = normalize_chr(F_selected_identity_key),
                M_mark_key = normalize_mark_string(M_selected_mark),
                F_mark_key = normalize_mark_string(F_selected_mark),
                M_pending_key = suppressWarnings(as.integer(M_association_pending)),
                F_pending_key = suppressWarnings(as.integer(F_association_pending)),
                M_ambiguous_key = suppressWarnings(as.integer(M_association_ambiguous)),
                F_ambiguous_key = suppressWarnings(as.integer(F_association_ambiguous))
            )]
            authoritative_status <- authoritative_status[
                grepl("^-", nest_key) &
                    !is.na(M_identity_key) & !is.na(F_identity_key) &
                    M_pending_key == 0L & F_pending_key == 0L &
                    M_ambiguous_key == 0L & F_ambiguous_key == 0L
            ]
        }
        authoritative_negative_nests <- function(parent_i) {
            if (!authoritative_status_available || nrow(authoritative_status) == 0L) {
                return(character())
            }
            parent_mark <- z$mark[[parent_i]]
            parent_sex <- sex_key(z$sex[[parent_i]])[[1L]]
            if (is.na(parent_mark) || !nzchar(parent_mark) || parent_mark == "X-X" || is.na(parent_sex)) {
                return(character())
            }
            if (parent_sex == "M") {
                unique(authoritative_status[!is.na(M_mark_key) & M_mark_key == parent_mark, nest_key])
            } else if (parent_sex == "F") {
                unique(authoritative_status[!is.na(F_mark_key) & F_mark_key == parent_mark, nest_key])
            } else {
                character()
            }
        }
        parent_ring_identity_known <- function(ring_value, sex_value, event_date_value) {
            if (nrow(capture_ring_identity) == 0L ||
                is.na(ring_value) || !nzchar(ring_value) ||
                is.na(event_date_value)) {
                return(FALSE)
            }
            parent_sex_key <- sex_key(sex_value)[[1L]]
            candidates <- capture_ring_identity[
                history_ring_key == ring_value &
                    history_date <= event_date_value
            ]
            if (nrow(candidates) == 0L) {
                return(FALSE)
            }
            known_sexes <- unique(candidates[!is.na(history_sex_key), history_sex_key])
            length(known_sexes) <= 1L &&
                (is.na(parent_sex_key) ||
                    !length(known_sexes) ||
                    all(known_sexes == parent_sex_key))
        }
        parent_evidence_ok <- function(parent_i) {
            if (!isTRUE(z$uncertain_mark[[parent_i]])) {
                return(TRUE)
            }
            parent_ring_identity_known(
                z$ring_key[[parent_i]],
                z$sex[[parent_i]],
                z$event_date[[parent_i]]
            )
        }
        gps_id_key <- trimws(as.character(z$gps_id))
        gps_point_key <- trimws(as.character(z$gps_point))
        same_family_parent_rows <- lapply(seq_len(nrow(z)), function(i) {
            event_date_i <- z$event_date[[i]]
            site_i <- z$site_key[[i]]
            gps_id_i <- gps_id_key[[i]]
            gps_point_i <- gps_point_key[[i]]
            if (is.na(event_date_i) || is.na(site_i) ||
                isTRUE(blankish(z$site[[i]])) ||
                isTRUE(blankish(z$gps_id[[i]])) ||
                isTRUE(blankish(z$gps_point[[i]]))) {
                return(integer())
            }
            which(
                z$is_parent_with_chicks &
                    vapply(seq_len(nrow(z)), parent_evidence_ok, logical(1)) &
                    !is.na(z$event_date) &
                    z$event_date == event_date_i &
                    z$site_key == site_i &
                    !blankish(z$gps_id) &
                    !blankish(z$gps_point) &
                    gps_id_key == gps_id_i &
                    gps_point_key == gps_point_i
            )
        })
        parent_candidate_nests <- function(parent_i) {
            if (!parent_evidence_ok(parent_i)) {
                return(character())
            }
            explicit_nest <- normalize_chr(z$nest_id[[parent_i]])
            if (isTRUE(z$uncertain_mark[[parent_i]])) {
                if (is_valid_brood_link(explicit_nest)) {
                    return(explicit_nest)
                }
                return(parent_ring_history_nest_ids(
                    z$ring_key[[parent_i]],
                    z$sex[[parent_i]],
                    z$event_date[[parent_i]]
                ))
            }
            if (is_valid_brood_link(explicit_nest)) {
                return(explicit_nest)
            }
            historical <- parent_history_nest_ids(
                z$mark[[parent_i]],
                z$sex[[parent_i]],
                z$event_date[[parent_i]]
            )
            if (length(historical) == 1L) {
                historical
            } else {
                authoritative_negative_nests(parent_i)
            }
        }
        negative_family_nests <- lapply(same_family_parent_rows, function(parent_rows) {
            if (length(parent_rows) == 0L) {
                return(character())
            }
            candidate_sets <- lapply(parent_rows, authoritative_negative_nests)
            if (any(lengths(candidate_sets) == 0L)) {
                return(character())
            }
            shared <- Reduce(intersect, candidate_sets)
            shared[grepl("^-", shared)]
        })
        same_session_parent_rows <- lapply(seq_len(nrow(z)), function(i) {
            event_date_i <- z$event_date[[i]]
            gps_id_i <- gps_id_key[[i]]
            gps_point_i <- gps_point_key[[i]]
            if (!isTRUE(z$is_chick[[i]]) ||
                is.na(event_date_i) ||
                isTRUE(blankish(z$gps_id[[i]])) ||
                isTRUE(blankish(z$gps_point[[i]]))) {
                return(integer())
            }
            which(
                z$is_parent_with_chicks &
                    vapply(seq_len(nrow(z)), parent_evidence_ok, logical(1)) &
                    !is.na(z$event_date) &
                    z$event_date == event_date_i &
                    !blankish(z$gps_id) &
                    !blankish(z$gps_point) &
                    gps_id_key == gps_id_i &
                    gps_point_key == gps_point_i
            )
        })
        same_session_parent_nests <- lapply(seq_along(same_session_parent_rows), function(i) {
            parent_rows <- same_session_parent_rows[[i]]
            if (!length(parent_rows)) return(character())
            unique(unlist(lapply(parent_rows, parent_candidate_nests), use.names = FALSE))
        })
        same_session_parent_positive_links <- lapply(same_session_parent_rows, function(parent_rows) {
            if (length(parent_rows) == 0L) {
                return(character())
            }
            unique(unlist(lapply(parent_rows, function(parent_i) {
                candidate_ids <- parent_candidate_nests(parent_i)
                candidate_ids[!grepl("^-", candidate_ids)]
            }), use.names = FALSE))
        })
        same_session_parent_links_resolvable <- lapply(seq_along(same_session_parent_rows), function(i) {
            parent_rows <- same_session_parent_rows[[i]]
            if (length(parent_rows) == 0L) {
                return(logical())
            }
            vapply(parent_rows, function(parent_i) {
                length(parent_candidate_nests(parent_i)) == 1L
            }, logical(1))
        })
        same_session_parent_unique_links <- lapply(same_session_parent_rows, function(parent_rows) {
            if (!length(parent_rows)) return(character())
            candidate_sets <- lapply(parent_rows, parent_candidate_nests)
            if (any(lengths(candidate_sets) != 1L)) return(character())
            candidate_ids <- unique(unlist(candidate_sets, use.names = FALSE))
            if (length(candidate_ids) == 1L) candidate_ids else character()
        })
        z[, `:=`(
            same_session_parent_nest_count = lengths(same_session_parent_nests),
            same_session_parent_count = lengths(same_session_parent_rows),
            same_session_parent_positive_count = lengths(same_session_parent_positive_links),
            same_session_parent_unique_nest_count = lengths(same_session_parent_unique_links),
            negative_family_nest_count = lengths(negative_family_nests),
            parent_links_resolvable = vapply(
                same_session_parent_links_resolvable,
                function(x) length(x) > 0L && all(x),
                logical(1)
            ),
            negative_family_resolvable = lengths(negative_family_nests) == 1L
        )]
        z[, `:=`(
            allow_unlinked_ordinary_chick =
                blankish(nest_id) &
                age_key == "C" &
                rclass_key %in% c("R", "P", "V", "C") &
                !blankish(gps_id) &
                !blankish(gps_point) &
                parent_links_resolvable &
                same_session_parent_unique_nest_count == 1L,
            allow_unlinked_negative_family =
                blankish(nest_id) &
                is_parent_with_chicks &
                negative_family_resolvable &
                !blankish(gps_id) &
                !blankish(gps_point)
        )]
        z[, `:=`(
            needs_nest_id,
            (is_chick & !allow_unlinked_ordinary_chick) |
                (is_parent_behaviour & !allow_unlinked_negative_family)
        )]
        saved_resightings <- safe_db_get(
            paste(
                "SELECT date, site, nest_id, age, behav, rclass, gps_id, gps_point",
                "FROM RESIGHTINGS"
            ),
            c("date", "site", "nest_id", "age", "behav", "rclass", "gps_id", "gps_point")
        )
        saved_captures <- safe_db_get(
            paste(
                "SELECT date, site, nest_id, age, gps_id, gps_point",
                "FROM CAPTURES"
            ),
            c("date", "site", "nest_id", "age", "gps_id", "gps_point")
        )
        saved_family_occasion_rows <- list()
        if (isTRUE(saved_resightings$ok) && nrow(saved_resightings$data) > 0L) {
            saved_res <- saved_resightings$data
            saved_res[, `:=`(
                occasion_date = suppressWarnings(as.Date(as.character(date))),
                occasion_site = normalize_chr(site),
                occasion_gps_id = normalize_chr(gps_id),
                occasion_gps_point = normalize_chr(gps_point),
                occasion_nest_id = normalize_chr(nest_id),
                age_key_saved = toupper(trimws(as.character(age))),
                behav_tokens_saved = lapply(behav, parse_behav)
            )]
            saved_res <- saved_res[
                !is.na(occasion_date) & !is.na(occasion_site) &
                    !is.na(occasion_gps_id) & !is.na(occasion_gps_point) &
                    (age_key_saved == "C" | (
                        age_key_saved == "A" &
                            vapply(behav_tokens_saved, function(tok) any(tok %in% parent_with_chicks_codes), logical(1))
                    ))
            ]
            if (nrow(saved_res) > 0L) {
                saved_family_occasion_rows[[length(saved_family_occasion_rows) + 1L]] <- saved_res[, .(
                    occasion_date, occasion_site, occasion_gps_id, occasion_gps_point,
                    occasion_nest_id
                )]
            }
        }
        if (isTRUE(saved_captures$ok) && nrow(saved_captures$data) > 0L) {
            saved_cap <- saved_captures$data
            saved_cap[, `:=`(
                occasion_date = suppressWarnings(as.Date(as.character(date))),
                occasion_site = normalize_chr(site),
                occasion_gps_id = normalize_chr(gps_id),
                occasion_gps_point = normalize_chr(gps_point),
                occasion_nest_id = normalize_chr(nest_id),
                age_key_saved = toupper(trimws(as.character(age)))
            )]
            saved_cap <- saved_cap[
                age_key_saved == "C" &
                    !is.na(occasion_date) & !is.na(occasion_site) &
                    !is.na(occasion_gps_id) & !is.na(occasion_gps_point)
            ]
            if (nrow(saved_cap) > 0L) {
                saved_family_occasion_rows[[length(saved_family_occasion_rows) + 1L]] <- saved_cap[, .(
                    occasion_date, occasion_site, occasion_gps_id, occasion_gps_point,
                    occasion_nest_id
                )]
            }
        }
        current_family_occasion_rows <- z[
            (is_chick | is_parent_with_chicks) &
                !is.na(event_date) & !is.na(site_key) &
                !blankish(gps_id) & !blankish(gps_point),
            .(
                rowid,
                occasion_date = event_date,
                occasion_site = site_key,
                occasion_gps_id = normalize_chr(gps_id),
                occasion_gps_point = normalize_chr(gps_point),
                occasion_nest_id = normalize_chr(nest_id)
            )
        ]
        family_occasion_conflicts <- data.table::data.table(
            rowid = integer(), variable = character(), reason = character()
        )
        if (nrow(current_family_occasion_rows) > 0L) {
            saved_family <- if (length(saved_family_occasion_rows)) {
                data.table::rbindlist(saved_family_occasion_rows, use.names = TRUE, fill = TRUE)
            } else {
                data.table::data.table(
                    occasion_date = as.Date(character()), occasion_site = character(),
                    occasion_gps_id = character(), occasion_gps_point = character(),
                    occasion_nest_id = character()
                )
            }
            for (occasion_i in seq_len(nrow(current_family_occasion_rows))) {
                occasion <- current_family_occasion_rows[occasion_i]
                current_group <- current_family_occasion_rows[
                    occasion_date == occasion$occasion_date[[1L]] &
                        occasion_site == occasion$occasion_site[[1L]] &
                        occasion_gps_id == occasion$occasion_gps_id[[1L]] &
                        occasion_gps_point == occasion$occasion_gps_point[[1L]]
                ]
                saved_group <- saved_family[
                    occasion_date == occasion$occasion_date[[1L]] &
                        occasion_site == occasion$occasion_site[[1L]] &
                        occasion_gps_id == occasion$occasion_gps_id[[1L]] &
                        occasion_gps_point == occasion$occasion_gps_point[[1L]]
                ]
                nest_ids <- unique(c(
                    current_group$occasion_nest_id[is_valid_brood_link(current_group$occasion_nest_id)],
                    saved_group$occasion_nest_id[is_valid_brood_link(saved_group$occasion_nest_id)]
                ))
                if (length(nest_ids) > 1L) {
                    family_occasion_conflicts <- data.table::rbindlist(list(
                        family_occasion_conflicts,
                        data.table::data.table(
                            rowid = current_group$rowid,
                            variable = "nest_id",
                            reason = "This same family occasion contains conflicting nest_id values across the parent/chick records. Keep one nest_id for the same date, site, gps_id, and gps_point; use a different nest_id only for a separate encounter or a genuinely different brood association."
                        )
                    ), use.names = TRUE, fill = TRUE)
                    break
                }
            }
            if (nrow(family_occasion_conflicts) > 0L) {
                family_occasion_conflicts <- unique(family_occasion_conflicts)
            }
        }
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            row_is_chick <- isTRUE(row$is_chick)
            row_is_parent_behaviour <- isTRUE(row$is_parent_behaviour)
            row_is_h <- isTRUE(row$rclass_key == "H")
            missing_chick_nest_reason <- if (row_is_h) {
                "Age-C H hiding-spot-photo events must include an explicit valid positive or negative nest_id. A same-session parent, ring, or prior history cannot replace this field."
            } else if (isTRUE(row$same_session_parent_count[[1]] > 0L)) {
                "This ordinary age-C resighting may omit nest_id only when every same-date, same-GPS age-A parent using BC, FC, or AC has either a valid current nest/brood link or a resolvable historical CAPTURES/RESIGHTINGS nest link. Enter nest_id when any parent identity cannot be resolved."
            } else {
                "An ordinary age-C resighting may omit nest_id only with a complete GPS pair and a same-date, same-GPS age-A parent using BC, FC, or AC whose current or historical nest/brood link is resolvable; otherwise enter nest_id."
            }
            missing_parent_nest_reason <- if (any(row$behav_tokens[[1]] %in% c("BC", "FC", "AC"))) {
                "Adult BC/FC/AC resightings that associate a parent with chicks must include nest_id. If the brood is mobile after notA, also enter both gps_id and gps_point."
            } else if (any(row$behav_tokens[[1]] %in% "BW")) {
                "Adult BW (broken-wing display) resightings must include nest_id so the parent observation is linked to the nest or brood."
            } else {
                "This adult IN/NM/SC resighting is the first active-nest record for this breeding attempt, so please enter nest_id."
            }
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
            if (row_is_parent_behaviour && row_has_real_nest &&
                !isTRUE(row$lower_pair_observed[[1]])) {
                missing_lower_variable <- if (isTRUE(blankish(row$LL[[1]]))) "LL" else "LR"
                return(data.table::data.table(
                    rowid = row$rowid,
                    variable = missing_lower_variable,
                    reason = paste(
                        "Adult IN/NM/SC/BW/BC/FC/AC nest-association resightings must record both LL and LR.",
                        "Enter X or XX when the lower leg is explicitly unbanded; blank lower fields cannot independently confirm the nest or brood link."
                    )
                ))
            }
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
        out <- data.table::rbindlist(
            list(family_occasion_conflicts, out),
            use.names = TRUE,
            fill = TRUE
        )
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
        nests_dt <- data.table::as.data.table(db_get("SELECT nest_id, date, time_visit, nest_state, clutch_size, brood_size, pk FROM NESTS"))
        if (nrow(nests_dt) > 0) {
            nests_dt[, `:=`(event_date_nest, suppressWarnings(as.Date(date)))]
            nests_dt[, `:=`(time_visit_key, trimws(as.character(time_visit)))]
            nests_dt[is.na(time_visit_key) | !nzchar(time_visit_key), `:=`(time_visit_key, "99:99")]
            nests_dt[, `:=`(
                clutch_num = suppressWarnings(as.numeric(as.character(clutch_size))),
                brood_num = suppressWarnings(as.numeric(as.character(brood_size))),
                pk_key = suppressWarnings(as.numeric(as.character(pk)))
            )]
            nests_dt[is.na(pk_key), `:=`(pk_key, -Inf)]
        } else {
            nests_dt <- data.table::data.table(
                nest_id = character(),
                nest_state = character(),
                event_date_nest = as.Date(character()),
                time_visit_key = character(),
                clutch_num = numeric(),
                brood_num = numeric(),
                pk_key = numeric()
            )
        }
        z[, `:=`(event_date, suppressWarnings(as.Date(date)))]
        z[, `:=`(behav_tokens, lapply(behav, parse_behav))]
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            nest_key <- trimws(as.character(row$nest_id))
            if (!identical(as.character(row$age[[1]]), "A") || is.na(nest_key) || !nzchar(nest_key) || is_no_nest(nest_key) || grepl("^-", nest_key) || is.na(row$event_date) || !any(row$behav_tokens[[1]] %in% c("IN", "NM"))) {
                return(empty)
            }
            tmp <- nests_dt[nest_id == nest_key & !is.na(event_date_nest) & event_date_nest <= row$event_date]
            if (nrow(tmp) == 0) {
                return(empty)
            }
            data.table::setorder(tmp, event_date_nest, time_visit_key, pk_key)
            latest <- tmp[nrow(tmp)]
            latest_state <- as.character(latest$nest_state[[1]])
            if (!latest_state %in% c("F", "I", "H")) {
                data.table::data.table(rowid = row$rowid, variable = "nest_id", reason = "Adult IN/NM resightings require a nest_id whose latest nest_state is F, I, or H. If this nest has reached another state, check the nest linkage or enter the new nest_id for a new breeding attempt.")
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
        normalize_chr <- function(v) {
            out <- toupper(trimws(as.character(v)))
            out[is.na(v) | !nzchar(out) | out == "NA"] <- NA_character_
            out
        }
        parse_behav <- function(v) {
            one <- normalize_chr(v)
            if (is.na(one)) character() else trimws(unlist(strsplit(one, ",", fixed = TRUE)))
        }
        is_linked_nest <- function(v) {
            !is.na(v) & nzchar(v) & v != "NO_NEST"
        }
        has_gps_pair <- function(id, point) {
            !is.na(id) & !is.na(point) & nzchar(id) & nzchar(point)
        }
        same_link <- function(row, other) {
            same_date <- !is.na(row$date_key[[1]]) &&
                !is.na(other$date_key) &&
                as.character(row$date_key[[1]]) == as.character(other$date_key)
            same_site <- !is.na(row$site_key[[1]]) &&
                !is.na(other$site_key) &&
                row$site_key[[1]] == other$site_key
            same_nest <- is_linked_nest(row$nest_key[[1]]) &&
                is_linked_nest(other$nest_key) &&
                row$nest_key[[1]] == other$nest_key
            same_gps <- has_gps_pair(row$gps_id_key[[1]], row$gps_point_key[[1]]) &&
                has_gps_pair(other$gps_id_key, other$gps_point_key) &&
                row$gps_id_key[[1]] == other$gps_id_key &&
                row$gps_point_key[[1]] == other$gps_point_key
            same_date && same_site && (same_nest || same_gps)
        }
        capture_lookup <- tryCatch(
            data.table::as.data.table(db_get(
                "SELECT pk, date, site, gps_id, gps_point, age, nest_id FROM CAPTURES WHERE age = 'C'"
            )),
            error = function(e) NULL
        )
        if (is.null(capture_lookup) || !is.data.frame(capture_lookup)) {
            capture_lookup <- data.table::data.table(
                pk = numeric(), date = as.Date(character()), site = character(),
                gps_id = character(), gps_point = character(), age = character(),
                nest_id = character()
            )
        } else {
            for (column in c("pk", "date", "site", "gps_id", "gps_point", "age", "nest_id")) {
                if (!column %in% names(capture_lookup)) {
                    capture_lookup[, (column) := NA_character_]
                }
            }
            capture_lookup[, `:=`(
                date_key = suppressWarnings(as.Date(as.character(date))),
                site_key = normalize_chr(site),
                gps_id_key = normalize_chr(gps_id),
                gps_point_key = normalize_chr(gps_point),
                age_key = normalize_chr(age)
            )]
            capture_lookup <- capture_lookup[age_key == "C"]
        }
        same_capture_occasion <- function(parent, capture) {
            same_date <- !is.na(parent$date_key[[1]]) &&
                !is.na(capture$date_key) &&
                as.character(parent$date_key[[1]]) == as.character(capture$date_key)
            same_site <- !is.na(parent$site_key[[1]]) &&
                !is.na(capture$site_key) &&
                parent$site_key[[1]] == capture$site_key
            same_gps <- !is.na(parent$gps_id_key[[1]]) &&
                !is.na(parent$gps_point_key[[1]]) &&
                !is.na(capture$gps_id_key) &&
                !is.na(capture$gps_point_key) &&
                parent$gps_id_key[[1]] == capture$gps_id_key &&
                parent$gps_point_key[[1]] == capture$gps_point_key
            isTRUE(same_date && same_site && same_gps)
        }
        z[, `:=`(
            date_key = suppressWarnings(as.Date(as.character(date))),
            site_key = normalize_chr(site),
            age_key = normalize_chr(age),
            nest_key = normalize_chr(nest_id),
            gps_id_key = normalize_chr(gps_id),
            gps_point_key = normalize_chr(gps_point),
            behav_tokens = lapply(behav, parse_behav)
        )]
        z[, `:=`(
            parent_with_chicks = !is.na(age_key) & age_key == "A" & vapply(behav_tokens, function(tokens) any(tokens %in% c("BC", "FC", "AC")), logical(1)),
            chick_event = !is.na(age_key) & age_key == "C"
        )]
        parents <- z[parent_with_chicks & !is.na(date_key)]
        chicks <- z[chick_event & !is.na(date_key)]
        out_parts <- list()
        if (nrow(chicks) > 0L) {
            missing_parent <- vapply(seq_len(nrow(chicks)), function(i) {
                !any(vapply(seq_len(nrow(parents)), function(j) same_link(chicks[i], parents[j]), logical(1)))
            }, logical(1))
            if (any(missing_parent)) {
                out_parts[[length(out_parts) + 1L]] <- data.table::data.table(
                    rowid = chicks$rowid[missing_parent],
                    variable = "age",
                    reason = "Each age-C RESIGHTINGS event must be accompanied in this portal session by an age-A parent event with behav BC, FC, or AC, linked by the same nest_id or gps_id/gps_point. Enter the parent event and keep the linkage consistent."
                )
            }
        }
        if (nrow(parents) > 0L) {
            missing_chick <- vapply(seq_len(nrow(parents)), function(i) {
                has_resighting_chick <- any(vapply(
                    seq_len(nrow(chicks)),
                    function(j) same_link(parents[i], chicks[j]),
                    logical(1)
                ))
                has_capture_chick <- nrow(capture_lookup) > 0L && any(vapply(
                    seq_len(nrow(capture_lookup)),
                    function(j) same_capture_occasion(parents[i], capture_lookup[j]),
                    logical(1)
                ))
                !(has_resighting_chick || has_capture_chick)
            }, logical(1))
            if (any(missing_chick)) {
                out_parts[[length(out_parts) + 1L]] <- data.table::data.table(
                    rowid = parents$rowid[missing_chick],
                    variable = "behav",
                    reason = "Awesome that you saw a banded parent with chicks! However, no associated age-C event was found for this field occasion. If the chicks were captured, save the genuine age-C CAPTURES rows first and make sure they use the same date, site, gps_id, and gps_point as the parent. If they were observed but not captured, enter a rclass 'R' RESIGHTINGS event for each chick with the colour band seen, linked to the tending parent with the same gps_id and gps_point. 'ring' can be left blank."
                )
            }
        }
        if (!length(out_parts)) empty else unique(data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE))
    }, nam = "RES_005J same-session family link")
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
        normalize_chr <- function(v) {
            out <- toupper(trimws(as.character(v)))
            out[is.na(v) | !nzchar(out) | out == "NA"] <- NA_character_
            out
        }
        parse_behav <- function(v) {
            one <- normalize_chr(v)
            if (is.na(one)) character() else trimws(unlist(strsplit(one, ",", fixed = TRUE)))
        }
        is_positive_nest <- function(v) {
            !is.na(v) & nzchar(v) & v != "NO_NEST" & !grepl("^-", v)
        }
        has_gps_pair <- function(id, point) {
            !is.na(id) & !is.na(point) & nzchar(id) & nzchar(point)
        }
        nests_dt <- data.table::as.data.table(db_get("SELECT nest_id, date, time_visit, nest_state, brood_size, pk FROM NESTS"))
        if (!nrow(nests_dt)) {
            empty
        } else {
            nests_dt[, `:=`(
                nest_key = normalize_chr(nest_id),
                event_date_nest = suppressWarnings(as.Date(as.character(date))),
                time_visit_key = trimws(as.character(time_visit)),
                pk_key = suppressWarnings(as.numeric(as.character(pk))),
                state_key = normalize_chr(nest_state),
                brood_num = suppressWarnings(as.numeric(as.character(brood_size)))
            )]
            nests_dt[is.na(time_visit_key) | !nzchar(time_visit_key) | time_visit_key == "NA", `:=`(time_visit_key, "99:99:99")]
            nests_dt[is.na(pk_key), `:=`(pk_key, -Inf)]
            z[, `:=`(
                date_key = suppressWarnings(as.Date(as.character(date))),
                age_key = normalize_chr(age),
                nest_key = normalize_chr(nest_id),
                gps_id_key = normalize_chr(gps_id),
                gps_point_key = normalize_chr(gps_point),
                behav_tokens = lapply(behav, parse_behav)
            )]
            latest_for <- function(nest_key, event_date) {
                if (!is_positive_nest(nest_key) || is.na(event_date)) return(NULL)
                key_val <- nest_key
                tmp <- nests_dt[nest_key == key_val & !is.na(event_date_nest) & event_date_nest <= event_date]
                if (!nrow(tmp)) return(NULL)
                data.table::setorder(tmp, event_date_nest, time_visit_key, pk_key)
                tmp[nrow(tmp)]
            }
            out_parts <- list()
            for (i in seq_len(nrow(z))) {
                row <- z[i]
                if (is.na(row$date_key[[1]]) || !is_positive_nest(row$nest_key[[1]])) next
                latest <- latest_for(row$nest_key[[1]], row$date_key[[1]])
                if (is.null(latest)) next
                state_key <- latest$state_key[[1]]
                tokens <- row$behav_tokens[[1]]
                if (isTRUE(row$age_key[[1]] == "A") && any(tokens %in% c("BC", "FC", "AC")) && !state_key %in% c("H", "NOTA")) {
                    out_parts[[length(out_parts) + 1L]] <- data.table::data.table(
                        rowid = row$rowid,
                        variable = "nest_id",
                        reason = "Parent-with-chicks behavior BC/FC/AC requires a linked nest_id whose latest nest_state is H or notA. Check the nest state or nest linkage."
                    )
                }
                mobile_brood <- state_key == "NOTA" && !is.na(latest$brood_num[[1]]) && latest$brood_num[[1]] > 0
                needs_mobile_gps <- mobile_brood && (
                    isTRUE(row$age_key[[1]] == "C") ||
                    (isTRUE(row$age_key[[1]] == "A") && any(tokens %in% c("BW", "BC", "FC", "AC")))
                )
                if (needs_mobile_gps && !has_gps_pair(row$gps_id_key[[1]], row$gps_point_key[[1]])) {
                    if (is.na(row$gps_id_key[[1]]) || !nzchar(row$gps_id_key[[1]])) {
                        out_parts[[length(out_parts) + 1L]] <- data.table::data.table(
                            rowid = row$rowid,
                            variable = "gps_id",
                            reason = "This nest_id has reached notA while chicks remain mobile; enter both gps_id and gps_point for the parent/chick association."
                        )
                    }
                    if (is.na(row$gps_point_key[[1]]) || !nzchar(row$gps_point_key[[1]])) {
                        out_parts[[length(out_parts) + 1L]] <- data.table::data.table(
                            rowid = row$rowid,
                            variable = "gps_point",
                            reason = "This nest_id has reached notA while chicks remain mobile; enter both gps_id and gps_point for the parent/chick association."
                        )
                    }
                }
            }
            if (!length(out_parts)) empty else unique(data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE))
        }
    }, nam = "RES_005K brood-stage state")
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
            values <- normalize_scalar_chr(c(ul, ll, ur, lr))
            if (any(!is.na(values) & grepl("?", values, fixed = TRUE))) {
                return(NA_character_)
            }
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
        normalize_photo_text <- function(v) {
            raw <- toupper(trimws(as.character(v)))
            raw[is.na(v) | !nzchar(raw) | raw == "NA"] <- NA_character_
            raw
        }
        expand_ranges <- function(dt, table_name, rowid_col = "rowid") {
            if (nrow(dt) == 0) {
                return(data.table::data.table(
                    table_name = character(), rowid = integer(), photo_no = integer(),
                    cam_key = character(), date_key = character(), observer_key = character(),
                    nest_key = character(), gps_id_key = character(), gps_point_key = character(),
                    rclass_key = character(), age_key = character(), pk_key = character()
                ))
            }
            photo_seq_num <- function(v) {
                raw <- sub("\\.[A-Za-z0-9]{1,5}$", "", trimws(as.character(v)), perl = TRUE)
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
            if (!rowid_col %in% names(tmp)) {
                tmp[, `:=`(rowid, .I)]
            } else if (rowid_col != "rowid") {
                tmp[, `:=`(rowid, get(rowid_col))]
            }
            for (column in c("cam_id", "date", "observer", "nest_id", "gps_id", "gps_point", "rclass", "age", "pk")) {
                if (!column %in% names(tmp)) {
                    tmp[, (column) := NA_character_]
                }
            }
            tmp[, `:=`(
                table_name = table_name,
                cam_key = normalize_photo_text(cam_id),
                date_key = normalize_photo_text(date),
                observer_key = normalize_photo_text(observer),
                nest_key = normalize_photo_text(nest_id),
                gps_id_key = normalize_photo_text(gps_id),
                gps_point_key = normalize_photo_text(gps_point),
                rclass_key = normalize_photo_text(rclass),
                age_key = normalize_photo_text(age),
                pk_key = normalize_photo_text(pk)
            )]
            tmp[, `:=`(start_no, photo_seq_num(photo_start))]
            tmp[, `:=`(end_no, photo_seq_num(photo_end))]
            tmp <- tmp[!is.na(start_no) & !is.na(end_no) & start_no <= end_no]
            if (nrow(tmp) == 0) {
                return(data.table::data.table(
                    table_name = character(), rowid = integer(), photo_no = integer(),
                    cam_key = character(), date_key = character(), observer_key = character(),
                    nest_key = character(), gps_id_key = character(), gps_point_key = character(),
                    rclass_key = character(), age_key = character(), pk_key = character()
                ))
            }
            pieces <- lapply(seq_len(nrow(tmp)), function(i) {
                data.table::data.table(
                    table_name = tmp$table_name[i],
                    rowid = tmp$rowid[i],
                    photo_no = seq.int(tmp$start_no[i], tmp$end_no[i]),
                    cam_key = tmp$cam_key[i],
                    date_key = tmp$date_key[i],
                    observer_key = tmp$observer_key[i],
                    nest_key = tmp$nest_key[i],
                    gps_id_key = tmp$gps_id_key[i],
                    gps_point_key = tmp$gps_point_key[i],
                    rclass_key = tmp$rclass_key[i],
                    age_key = tmp$age_key[i],
                    pk_key = tmp$pk_key[i]
                )
            })
            data.table::rbindlist(pieces, use.names = TRUE, fill = TRUE)
        }
        same_h_photo_session <- function(a, b) {
            if (!identical(a$table_name[[1]], "RESIGHTINGS") || !identical(b$table_name[[1]], "RESIGHTINGS")) {
                return(FALSE)
            }
            if (!identical(a$rclass_key[[1]], "H") || !identical(b$rclass_key[[1]], "H") ||
                !identical(a$age_key[[1]], "C") || !identical(b$age_key[[1]], "C")) {
                return(FALSE)
            }
            if (any(is.na(c(a$cam_key[[1]], b$cam_key[[1]], a$date_key[[1]], b$date_key[[1]])))) {
                return(FALSE)
            }
            if (!identical(a$cam_key[[1]], b$cam_key[[1]]) ||
                !identical(a$date_key[[1]], b$date_key[[1]])) {
                return(FALSE)
            }
            nest_complete <- !is.na(a$nest_key[[1]]) && !is.na(b$nest_key[[1]])
            if (nest_complete) {
                return(identical(a$nest_key[[1]], b$nest_key[[1]]))
            }
            gps_complete <- !is.na(a$gps_id_key[[1]]) && !is.na(b$gps_id_key[[1]]) &&
                !is.na(a$gps_point_key[[1]]) && !is.na(b$gps_point_key[[1]])
            gps_complete &&
                identical(a$gps_id_key[[1]], b$gps_id_key[[1]]) &&
                identical(a$gps_point_key[[1]], b$gps_point_key[[1]])
        }
        photo_conflict <- function(a, b) {
            same_saved_row <- !is.na(a$pk_key[[1]]) && !is.na(b$pk_key[[1]]) &&
                identical(a$table_name[[1]], b$table_name[[1]]) &&
                identical(a$pk_key[[1]], b$pk_key[[1]])
            if (same_saved_row) {
                return(FALSE)
            }
            if (is.na(a$cam_key[[1]]) || is.na(b$cam_key[[1]]) ||
                !identical(a$cam_key[[1]], b$cam_key[[1]]) ||
                !identical(a$photo_no[[1]], b$photo_no[[1]])) {
                return(FALSE)
            }
            !same_h_photo_session(a, b)
        }
        other_res <- data.table::as.data.table(db_get("SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, rclass, age, photo_start, photo_end FROM RESIGHTINGS"))
        other_caps <- data.table::as.data.table(db_get("SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, age, photo_start, photo_end FROM CAPTURES"))
        other_nests <- data.table::as.data.table(db_get("SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, photo_start, photo_end FROM NESTS"))
        current_expanded <- expand_ranges(z, "RESIGHTINGS")
        other_res_expanded <- expand_ranges(other_res, "RESIGHTINGS", rowid_col = "missing_rowid")
        other_caps_expanded <- expand_ranges(other_caps, "CAPTURES", rowid_col = "missing_rowid")
        other_nests_expanded <- expand_ranges(other_nests, "NESTS", rowid_col = "missing_rowid")
        rows_dup_current <- integer()
        if (nrow(current_expanded) > 1) {
            for (i in seq_len(nrow(current_expanded))) {
                hits <- which(current_expanded$photo_no == current_expanded$photo_no[i] & current_expanded$rowid != current_expanded$rowid[i])
                if (length(hits) > 0) {
                    for (j in hits) {
                        if (photo_conflict(current_expanded[i], current_expanded[j])) {
                            rows_dup_current <- c(rows_dup_current, current_expanded$rowid[i], current_expanded$rowid[j])
                        }
                    }
                }
            }
        }
        ref <- data.table::rbindlist(list(other_res_expanded, other_caps_expanded, other_nests_expanded), use.names = TRUE, fill = TRUE)
        rows_dup_ref <- integer()
        if (nrow(ref) > 0) {
            for (i in seq_len(nrow(current_expanded))) {
                hits <- which(ref$photo_no == current_expanded$photo_no[i])
                if (length(hits) > 0) {
                    for (j in hits) {
                        if (photo_conflict(current_expanded[i], ref[j])) {
                            rows_dup_ref <- c(rows_dup_ref, current_expanded$rowid[i])
                        }
                    }
                }
            }
        }
        flagged <- sort(unique(c(rows_dup_current, rows_dup_ref)))
        if (length(flagged) == 0) {
            empty
        } else {
            data.table::data.table(rowid = flagged, variable = "photo_start", reason = "Photo range overlaps an image number already used by the same camera in another event. Multiple age-C H rows may share a range when they document the same nest/brood photo session.")
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
        is.regexp_validator(z, regexp = "^(X|\\?|[OYWBRGLM]{1,2}|\\?[OYWBRGL]|[OYWBRGL]\\?|F[OYWBRGLM][A-Z0-9]{2,3})$", reason = "Left tibia code does not match the current RESIGHTINGS format.")
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
        is.regexp_validator(z, regexp = "^(X|XX|\\?|[OYWBRGLM]{1,2}|\\?[OYWBRGL]|[OYWBRGL]\\?)$", reason = "Left tarsus code does not match the current RESIGHTINGS format.")
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
        is.regexp_validator(z, regexp = "^(X|\\?|[OYWBRGLM]{1,2}|\\?[OYWBRGL]|[OYWBRGL]\\?|T\\?|T[A-Z0-9]{0,5}[RBGWOLY]|F[OYWBRGLM][A-Z0-9]{2,3})$", reason = "Right tibia code does not match the current RESIGHTINGS format.")
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
        is.regexp_validator(z, regexp = "^(X|XX|\\?|[OYWBRGLM]{1,2}|\\?[OYWBRGL]|[OYWBRGL]\\?)$", reason = "Right tarsus code does not match the current RESIGHTINGS format.")
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
        allowed <- c("IN", "CO", "PR", "BW", "BC", "AC", "NM", "SC", "FC", "FA", "FM", "FF", "RS", "LF", "AT", "FT", "OB")
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
                    reason = "This H-class chick ring is not yet recorded in CAPTURES. Check the ring code or enter the chick's CAPTURES record so this hiding-spot resighting can be linked to the captured chick."
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
