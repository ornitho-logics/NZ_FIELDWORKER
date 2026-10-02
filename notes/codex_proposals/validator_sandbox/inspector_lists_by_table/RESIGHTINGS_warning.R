list({
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
        safe_db_get <- function(sql, columns) {
            # Keep query success separate from an empty result. A failed
            # reference lookup is unknown history, not evidence of no match.
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
            missing_columns <- setdiff(columns, names(result))
            for (column in missing_columns) {
                result[, (column) := NA_character_]
            }
            list(ok = TRUE, data = result[, ..columns])
        }
        is_no_nest <- function(v) {
            !is.na(v) & toupper(trimws(as.character(v))) == "NO_NEST"
        }
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
                # A complete two-band LR supplies the colour pair; the tag
                # and spacer recorded on UR remain visible but are not needed
                # when matching a partial resighting.
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
        archive_lookup <- safe_db_get(
            "SELECT date, UL, LL, UR, LR FROM CAPTURES_ARCHIVE",
            c("date", "UL", "LL", "UR", "LR")
        )
        current_caps_lookup <- safe_db_get(
            "SELECT date, caught, nest_id, capture_status, UL_in, LL_in, UR_in, LR_in, UL, LL, UR, LR FROM CAPTURES",
            c(
                "date", "caught", "nest_id", "capture_status",
                "UL_in", "LL_in", "UR_in", "LR_in", "UL", "LL", "UR", "LR"
            )
        )
        archive_available <- isTRUE(archive_lookup$ok)
        current_caps_available <- isTRUE(current_caps_lookup$ok)
        archive <- archive_lookup$data
        current_caps <- current_caps_lookup$data
        if (nrow(archive) > 0) {
            archive[, `:=`(date, suppressWarnings(as.Date(date)))]
            archive <- make_signature_dt(archive)
        } else {
            archive <- data.table::data.table(date = as.Date(character()), left_pair = character(), right_pair = character(), flag_ul = character(), flag_ur = character(), has_signature = logical())
        }
        if (nrow(current_caps) > 0) {
            current_caps[, `:=`(
                sig_UL = UL,
                sig_LL = LL,
                sig_UR = UR,
                sig_LR = LR
            )]
            current_caps[capture_status == "D", `:=`(
                sig_UL = UL_in,
                sig_LL = LL_in,
                sig_UR = UR_in,
                sig_LR = LR_in
            )]
            current_caps[, `:=`(date, suppressWarnings(as.Date(date)))]
            current_caps[, `:=`(nest_key = normalize_scalar_chr(nest_id))]
            current_caps <- make_signature_dt(current_caps, ul_col = "sig_UL", ll_col = "sig_LL", ur_col = "sig_UR", lr_col = "sig_LR")
        } else {
            current_caps <- data.table::data.table(date = as.Date(character()), nest_key = character(), left_pair = character(), right_pair = character(), flag_ul = character(), flag_ur = character(), has_signature = logical())
        }
        z <- make_signature_dt(z)
        z[, `:=`(event_date, suppressWarnings(as.Date(date)))]
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
            rowid_val <- row$rowid[[1]]
            age_val <- one_chr(row$age)
            nest_key_val <- one_chr(row$nest_id)
            event_date_val <- row$event_date[[1]]
            if (!identical(age_val, "A") || !isTRUE(row$has_signature[[1]]) || is.na(event_date_val)) {
                return(empty)
            }
            prior_archive <- matches_signature(row, archive[!is.na(date) & date <= event_date_val])
            prior_current <- matches_signature(row, current_caps[!is.na(date) & date <= event_date_val])
            prior_resight <- matches_signature(
                row,
                z[
                    rowid != rowid_val &
                        trimws(as.character(age)) == "A" &
                        !is.na(event_date) &
                        (event_date < event_date_val | (event_date == event_date_val & rowid < rowid_val))
                ]
            )
            same_attempt_confirmation <- FALSE
            if (!is.na(nest_key_val) && !is_no_nest(nest_key_val)) {
                same_attempt_confirmation <- matches_signature(row, current_caps[!is.na(nest_key) & nest_key == nest_key_val])
            }
            if (prior_archive || prior_current || prior_resight || same_attempt_confirmation) {
                empty
            } else if (!archive_available || !current_caps_available) {
                data.table::data.table(
                    rowid = rowid_val,
                    variable = "UL",
                    reason = paste(
                        "I could not check this combination because CAPTURES history is temporarily unavailable.",
                        "Please retry when the database connection is restored; no conclusion has been made about the marks."
                    )
                )
            } else {
                data.table::data.table(rowid = rowid_val, variable = "UL", reason = "This adult’s combination does not yet match the available capture history. Please recheck the leg marks; it may be a new record, a later confirmation, or a small transcription slip.")
            }
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) {
            empty
        } else {
            unique(out)
        }
    }, nam = "RES_005 combo history")
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
        norm_chr <- function(v) {
            out <- toupper(trimws(as.character(v)))
            out[is.na(v) | !nzchar(out) | out == "NA"] <- NA_character_
            out
        }
        has_chick_behaviour <- function(v) {
            one <- norm_chr(v)
            if (is.na(one)) {
                return(FALSE)
            }
            tokens <- trimws(unlist(strsplit(one, ",", fixed = TRUE)))
            any(tokens %in% c("BW", "BC", "FC"))
        }
        z[, `:=`(
            date_key = suppressWarnings(as.Date(as.character(date))),
            gps_id_key = norm_chr(gps_id),
            gps_point_key = norm_chr(gps_point),
            age_key = norm_chr(age),
            has_chick_behaviour = vapply(behav, has_chick_behaviour, logical(1))
        )]
        adult_keys <- unique(z[
            age_key == "A" &
            has_chick_behaviour &
            !is.na(date_key) &
            !is.na(gps_id_key) &
            !is.na(gps_point_key),
            .(rowid, date_key, gps_id_key, gps_point_key)
        ])
        chick_keys <- unique(z[
            age_key == "C" &
            !is.na(date_key) &
            !is.na(gps_id_key) &
            !is.na(gps_point_key),
            .(date_key, gps_id_key, gps_point_key)
        ])
        if (nrow(adult_keys) == 0L) {
            empty
        } else {
            missing_chicks <- adult_keys[!chick_keys, on = .(date_key, gps_id_key, gps_point_key)]
            if (nrow(missing_chicks) == 0L) {
                empty
            } else {
                missing_chicks[, .(
                    rowid,
                    variable = "behav",
                    reason = "Awesome that you saw a banded parent with chicks! Please add one rclass 'R' RESIGHTINGS event for each chick, recording the colour band you saw and using the same gps_id and gps_point as the tending parent. You can leave ring blank."
                )]
            }
        }
    }, nam = "RES_007 adult with chicks")
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
        normalize_chr <- function(v) {
            out <- toupper(trimws(as.character(v)))
            out[is.na(v) | !nzchar(out) | out == "NA"] <- NA_character_
            out
        }
        sex_group <- function(v) {
            out <- substr(normalize_chr(v), 1, 1)
            out[!out %in% c("M", "F")] <- NA_character_
            out
        }
        normalize_tag_ur <- function(v) {
            out <- normalize_chr(v)
            tag_like <- !is.na(out) & grepl("^T[A-Z0-9]*[RBGWOLY]$", out)
            out[tag_like] <- paste0("T", sub("^.*([RBGWOLY])$", "\\1", out[tag_like]))
            out
        }
        canonical_left_pair <- function(ul, ll) {
            ul1 <- normalize_chr(ul)
            ll1 <- normalize_chr(ll)
            ifelse(
                !is.na(ul1) & grepl("^[RBGWOLY]$", ul1) & !is.na(ll1) & grepl("^[RBGWOLY]$", ll1),
                paste0(ul1, ll1),
                ifelse(
                    (is.na(ul1) | ul1 %in% c("X", "M")) & !is.na(ll1) & grepl("^[RBGWOLY]{2}$", ll1),
                    ll1,
                    ifelse(
                        (is.na(ll1) | ll1 %in% c("X", "M")) & !is.na(ul1) & grepl("^[RBGWOLY]{2}$", ul1),
                        ul1,
                        NA_character_
                    )
                )
            )
        }
        canonical_right_pair <- function(ur, lr) {
            ur1 <- normalize_tag_ur(ur)
            lr1 <- normalize_chr(lr)
            ifelse(
                !is.na(ur1) & grepl("^T[RBGWOLY]$", ur1) & !is.na(lr1) & grepl("^[RBGWOLY]{2}$", lr1),
                lr1,
                ifelse(
                    !is.na(ur1) & grepl("^T[RBGWOLY]$", ur1) & !is.na(lr1) & grepl("^[RBGWOLY]$", lr1),
                    paste0(sub("^T", "", ur1), lr1),
                    ifelse(
                        !is.na(ur1) & grepl("^[RBGWOLY]$", ur1) & !is.na(lr1) & grepl("^[RBGWOLY]$", lr1),
                        paste0(ur1, lr1),
                        ifelse(
                            (is.na(ur1) | ur1 %in% c("X", "M")) & !is.na(lr1) & grepl("^[RBGWOLY]{2}$", lr1),
                            lr1,
                            ifelse(
                                (is.na(lr1) | lr1 %in% c("X", "M")) & !is.na(ur1) & grepl("^[RBGWOLY]{2}$", ur1),
                                ur1,
                                NA_character_
                            )
                        )
                    )
                )
            )
        }
        make_signature_dt <- function(dt, ul_col = "UL", ll_col = "LL", ur_col = "UR", lr_col = "LR") {
            tmp <- data.table::copy(dt)
            ul_vals <- tmp[[ul_col]]
            ll_vals <- tmp[[ll_col]]
            ur_vals <- tmp[[ur_col]]
            lr_vals <- tmp[[lr_col]]
            flag_ul <- normalize_chr(ul_vals)
            flag_ul[is.na(flag_ul) | !grepl("^F[A-Z0-9]+$", flag_ul)] <- NA_character_
            flag_ur <- normalize_chr(ur_vals)
            flag_ur[is.na(flag_ur) | !grepl("^F[A-Z0-9]+$", flag_ur)] <- NA_character_
            tmp[, `:=`(
                left_pair = canonical_left_pair(ul_vals, ll_vals),
                right_pair = canonical_right_pair(ur_vals, lr_vals),
                flag_ul = flag_ul,
                flag_ur = flag_ur
            )]
            tmp[, has_signature := !is.na(left_pair) | !is.na(right_pair) | !is.na(flag_ul) | !is.na(flag_ur)]
            tmp
        }
        identity_matches <- function(row, history) {
            if (!nrow(history)) {
                return(logical())
            }
            keep <- rep(FALSE, nrow(history))
            if (!is.na(row$ring_key[[1]])) {
                keep <- keep | (!is.na(history$ring_key) & history$ring_key == row$ring_key[[1]])
            }
            if (isTRUE(row$has_signature[[1]])) {
                signature_keep <- rep(TRUE, nrow(history))
                if (!is.na(row$left_pair[[1]])) {
                    signature_keep <- signature_keep & !is.na(history$left_pair) & history$left_pair == row$left_pair[[1]]
                }
                if (!is.na(row$right_pair[[1]])) {
                    signature_keep <- signature_keep & !is.na(history$right_pair) & history$right_pair == row$right_pair[[1]]
                }
                if (!is.na(row$flag_ul[[1]])) {
                    signature_keep <- signature_keep & !is.na(history$flag_ul) & history$flag_ul == row$flag_ul[[1]]
                }
                if (!is.na(row$flag_ur[[1]])) {
                    signature_keep <- signature_keep & !is.na(history$flag_ur) & history$flag_ur == row$flag_ur[[1]]
                }
                keep <- keep | signature_keep
            }
            keep
        }

        archive_lookup <- safe_db_get(
            "SELECT ring, date, field_sex, gen_sex, UL, LL, UR, LR FROM CAPTURES_ARCHIVE",
            c("ring", "date", "field_sex", "gen_sex", "UL", "LL", "UR", "LR")
        )
        current_lookup <- safe_db_get(
            "SELECT pk, ring, date, caught, capture_status, field_sex, UL_in, LL_in, UR_in, LR_in, UL, LL, UR, LR FROM CAPTURES",
            c("pk", "ring", "date", "caught", "capture_status", "field_sex", "UL_in", "LL_in", "UR_in", "LR_in", "UL", "LL", "UR", "LR")
        )
        archive <- archive_lookup$data
        current <- current_lookup$data
        if (!"ring" %in% names(z)) z[, ring := NA_character_]
        z[, `:=`(
            ring_key = normalize_chr(ring),
            res_sex_group = sex_group(sex),
            event_date = suppressWarnings(as.Date(as.character(date)))
        )]
        z <- make_signature_dt(z)
        z <- z[!is.na(res_sex_group) & (!is.na(ring_key) | has_signature)]
        if (!nrow(z)) {
            empty
        } else if (!isTRUE(archive_lookup$ok) || !isTRUE(current_lookup$ok)) {
            data.table::data.table(
                rowid = z$rowid,
                variable = "sex",
                reason = "I could not check this sex entry because CAPTURES or CAPTURES_ARCHIVE history is temporarily unavailable. Please retry when the database connection is restored; no conclusion has been made about the sex."
            )
        } else {
            archive[, `:=`(
                ring_key = normalize_chr(ring),
                baseline_group = sex_group(ifelse(!is.na(normalize_chr(gen_sex)), gen_sex, field_sex)),
                baseline_label = normalize_chr(ifelse(!is.na(normalize_chr(gen_sex)), gen_sex, field_sex)),
                capture_date = suppressWarnings(as.Date(as.character(date))),
                capture_time = NA_character_,
                capture_pk = NA_real_,
                source_label = ifelse(!is.na(normalize_chr(gen_sex)), "CAPTURES_ARCHIVE gen_sex", "CAPTURES_ARCHIVE field_sex")
            )]
            archive <- make_signature_dt(archive)
            current[, `:=`(
                ring_key = normalize_chr(ring),
                baseline_group = sex_group(field_sex),
                baseline_label = normalize_chr(field_sex),
                capture_date = suppressWarnings(as.Date(as.character(date))),
                capture_time = normalize_chr(caught),
                capture_pk = suppressWarnings(as.numeric(pk)),
                sig_UL = UL,
                sig_LL = LL,
                sig_UR = UR,
                sig_LR = LR
            )]
            current[capture_status == "D", `:=`(sig_UL = UL_in, sig_LL = LL_in, sig_UR = UR_in, sig_LR = LR_in)]
            current <- make_signature_dt(current, ul_col = "sig_UL", ll_col = "sig_LL", ur_col = "sig_UR", lr_col = "sig_LR")
            out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
                row <- z[i]
                archive_matches <- archive[identity_matches(row, archive)]
                archive_matches <- archive_matches[baseline_group %in% c("M", "F")]
                current_matches <- current[identity_matches(row, current)]
                current_matches <- current_matches[baseline_group %in% c("M", "F")]
                history <- if (nrow(archive_matches)) archive_matches else current_matches
                if (!nrow(history)) {
                    return(empty)
                }
                if (data.table::uniqueN(history$baseline_group) != 1L) {
                    return(empty)
                }
                data.table::setorder(history, capture_date, capture_time, capture_pk, na.last = TRUE)
                expected <- history$baseline_group[[1]]
                observed <- row$res_sex_group[[1]]
                if (identical(expected, observed)) {
                    return(empty)
                }
                expected_label <- if (expected == "M") "M or MU (male)" else "F or FU (female)"
                data.table::data.table(
                    rowid = row$rowid,
                    variable = "sex",
                    reason = paste0(
                        "This bird’s recorded sex does not match its original capture history (",
                        expected_label, "). Please check the RESIGHTINGS entry; M/MU and F/FU are treated as the same sex group."
                    )
                )
            }), use.names = TRUE, fill = TRUE)
            if (is.null(out) || !nrow(out)) empty else unique(out)
        }
    }, nam = "RES_005H resighting sex history")
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

        empty <- data.table::data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )

        normalize_chr <- function(v) {
            out <- toupper(trimws(as.character(v)))
            out[is.na(v) | !nzchar(out) | out == "NA"] <- NA_character_
            out
        }

        normalize_sex <- function(v) {
            out <- normalize_chr(v)
            out[out %in% c("M", "MU")] <- "M"
            out[out %in% c("F", "FU")] <- "F"
            out[!out %in% c("M", "F")] <- NA_character_
            out
        }

        has_parent_behaviour <- function(v) {
            raw <- normalize_chr(v)
            vapply(raw, function(value) {
                if (is.na(value)) {
                    return(FALSE)
                }
                tokens <- trimws(strsplit(value, ",", fixed = TRUE)[[1]])
                any(tokens %in% c("IN", "NM", "BW", "BC", "FC"))
            }, logical(1))
        }

        normalize_mark <- function(ul, ll, ur, lr) {
            values <- normalize_chr(c(ul, ll, ur, lr))
            ul1 <- values[1]
            ll1 <- values[2]
            ur1 <- values[3]
            lr1 <- values[4]

            explicit_unbanded <-
                !is.na(ll1) && ll1 %in% c("X", "XX") &&
                !is.na(lr1) && lr1 %in% c("X", "XX")

            informative <- explicit_unbanded || any(
                !is.na(values) & !values %in% c("X", "XX", "M")
            )

            if (!informative) {
                return(NA_character_)
            }
            if (explicit_unbanded) {
                return("X-X")
            }

            left <- values[c(1, 2)]
            left <- left[!is.na(left) & !left %in% c("X", "XX", "M")]
            right <- values[c(3, 4)]
            right <- right[!is.na(right) & !right %in% c("X", "XX", "M")]

            paste0(
                if (length(left)) paste(left, collapse = ".") else "X",
                "-",
                if (length(right)) paste(right, collapse = ".") else "X"
            )
        }

        choose_capture_segment <- function(release_value, input_value) {
            release_value <- normalize_chr(release_value)
            input_value <- normalize_chr(input_value)
            ifelse(is.na(release_value), input_value, release_value)
        }

        resighting_matches_capture <- function(row, capture) {
            observed <- normalize_chr(c(
                row$UL[[1]], row$LL[[1]], row$UR[[1]], row$LR[[1]]
            ))
            known <- normalize_chr(c(
                capture$mark_UL[[1]], capture$mark_LL[[1]],
                capture$mark_UR[[1]], capture$mark_LR[[1]]
            ))

            explicit_unbanded <-
                !is.na(observed[2]) && observed[2] %in% c("X", "XX") &&
                !is.na(observed[4]) && observed[4] %in% c("X", "XX")
            if (explicit_unbanded) {
                return(
                    !is.na(known[2]) && known[2] %in% c("X", "XX") &&
                    !is.na(known[4]) && known[4] %in% c("X", "XX")
                )
            }

            # Blank/X segments are omitted observations. Every segment that
            # was actually reported must still agree with capture history.
            required <- !is.na(observed) & !observed %in% c("X", "XX")
            any(required) && all(
                !is.na(known[required]) &
                    observed[required] == known[required]
            )
        }

        z[, `:=`(
            nest_key = normalize_chr(nest_id),
            sex_key = normalize_sex(sex),
            event_date = suppressWarnings(as.Date(as.character(date))),
            parent_behaviour = has_parent_behaviour(behav),
            resighting_mark = mapply(
                normalize_mark,
                UL,
                LL,
                UR,
                LR,
                USE.NAMES = FALSE
            )
        )]

        candidates <- z[
            age == "A" &
                !is.na(nest_key) &
                nest_key != "NO_NEST" &
                !is.na(sex_key) &
                parent_behaviour &
                !is.na(event_date) &
                !is.na(resighting_mark)
        ]

        if (!nrow(candidates)) {
            empty
        } else {
            capture_lookup <- tryCatch(
                db_get(paste(
                    "SELECT pk, date, caught, nest_id, age, field_sex, capture_method,",
                    "UL, LL, UR, LR, UL_in, LL_in, UR_in, LR_in FROM CAPTURES"
                )),
                error = function(e) NULL
            )

            if (is.null(capture_lookup) || !is.data.frame(capture_lookup)) {
                candidates[, .(
                    rowid,
                    variable = "UL",
                    reason = paste(
                        "I could not compare these social-parent marks because CAPTURES history is temporarily unavailable.",
                        "Please retry when the database connection is restored; no conclusion has been made about the match."
                    )
                )]
            } else {
                captures <- data.table::as.data.table(capture_lookup)
                required_columns <- c(
                    "pk", "date", "caught", "nest_id", "age", "field_sex", "capture_method",
                    "UL", "LL", "UR", "LR", "UL_in", "LL_in", "UR_in", "LR_in"
                )
                for (column in setdiff(required_columns, names(captures))) {
                    captures[, (column) := NA_character_]
                }

                captures[, `:=`(
                    nest_key = normalize_chr(nest_id),
                    sex_key = normalize_sex(field_sex),
                    capture_date = suppressWarnings(as.Date(as.character(date))),
                    capture_time = normalize_chr(caught),
                    capture_pk = suppressWarnings(as.numeric(pk)),
                    mark_UL = choose_capture_segment(UL, UL_in),
                    mark_LL = choose_capture_segment(LL, LL_in),
                    mark_UR = choose_capture_segment(UR, UR_in),
                    mark_LR = choose_capture_segment(LR, LR_in)
                )]
                captures[, `:=`(capture_mark = mapply(
                    normalize_mark,
                    mark_UL,
                    mark_LL,
                    mark_UR,
                    mark_LR,
                    USE.NAMES = FALSE
                ))]
                captures <- captures[
                    age == "A" &
                        !is.na(nest_key) &
                        nest_key != "NO_NEST" &
                        !is.na(sex_key) &
                        !is.na(capture_date) &
                        !is.na(capture_mark)
                ]

                out <- data.table::rbindlist(lapply(seq_len(nrow(candidates)), function(i) {
                    row <- candidates[i]
                    prior <- captures[
                        nest_key == row$nest_key[[1]] &
                            sex_key == row$sex_key[[1]] &
                            capture_date < row$event_date[[1]]
                    ]

                    if (!nrow(prior)) {
                        return(NULL)
                    }

                    data.table::setorder(
                        prior,
                        -capture_date,
                        -capture_time,
                        -capture_pk,
                        na.last = TRUE
                    )
                    latest <- prior[1]

                    if (isTRUE(resighting_matches_capture(row, latest))) {
                        return(NULL)
                    }

                    reason <- if (identical(normalize_chr(latest$capture_method)[1], "MM")) {
                        paste(
                            "These marks differ from the latest earlier adult capture for this nest_id and sex.",
                            "Because the earlier capture used MM, it may have been a different bird rather than the social parent—please check the marks and linkage."
                        )
                    } else {
                        paste(
                            "These social-parent marks differ from the latest earlier adult capture for this nest_id and sex.",
                            "Please recheck the marks and nest linkage; the bird may have changed bands or the earlier bird may not have been the social parent."
                        )
                    }

                    data.table::data.table(
                        rowid = row$rowid[[1]],
                        variable = "UL",
                        reason = reason
                    )
                }), use.names = TRUE, fill = TRUE)

                if (is.null(out) || !nrow(out)) empty else unique(out)
            }
        }
    }, nam = "RES_005G social parent mark")
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
        norm_chr <- function(v) {
            out <- trimws(as.character(v))
            out[is.na(v) | out == "NA" | !nzchar(out)] <- NA_character_
            out
        }
        is_no_nest <- function(v) {
            !is.na(v) & toupper(trimws(as.character(v))) == "NO_NEST"
        }
        z[, `:=`(
            date_key = suppressWarnings(as.Date(date)),
            site_key = norm_chr(site),
            nest_key = norm_chr(nest_id),
            gps_id_key = norm_chr(gps_id),
            gps_point_key = norm_chr(gps_point),
            age_key = norm_chr(age)
        )]
        adult_nest <- unique(z[
            age_key == "A" &
            !is.na(date_key) &
            !is.na(site_key) &
            !is.na(nest_key) &
            !is_no_nest(nest_key),
            .(date_key, site_key, nest_key)
        ])
        adult_gps <- unique(z[
            age_key == "A" &
            !is.na(date_key) &
            !is.na(gps_id_key) &
            !is.na(gps_point_key),
            .(date_key, gps_id_key, gps_point_key)
        ])
        chick_nest <- z[
            age_key == "C" &
            !is.na(date_key) &
            !is.na(site_key) &
            !is.na(nest_key) &
            !is_no_nest(nest_key),
            .(rowid, date_key, site_key, nest_key)
        ]
        chick_gps <- z[
            age_key == "C" &
            (is.na(nest_key) | !nzchar(nest_key) | is_no_nest(nest_key)) &
            !is.na(date_key) &
            !is.na(gps_id_key) &
            !is.na(gps_point_key),
            .(rowid, date_key, gps_id_key, gps_point_key)
        ]
        out_parts <- list(
            chick_nest[!adult_nest, on = .(date_key, site_key, nest_key)][, .(rowid, variable = "age", reason = "This chick resighting does not yet have a matching adult resighting. If you saw the tending parent, please add that adult row too; it may have been entered in another portal session.")],
            chick_gps[!adult_gps, on = .(date_key, gps_id_key, gps_point_key)][, .(rowid, variable = "age", reason = "This chick resighting does not yet have a matching adult resighting. If you saw the tending parent, please add that adult row too; it may have been entered in another portal session.")]
        )
        out_parts <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, out_parts)
        out <- if (length(out_parts) == 0) {
            empty
        } else {
            data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE)
        }
        if (nrow(out) == 0) empty else unique(out)
    }, nam = "RES_006 chick with adult")
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
        norm_nest <- trimws(as.character(z$nest_id))
        grp <- z[
            !is.na(nest_id) &
            nzchar(norm_nest) &
            toupper(norm_nest) != "NO_NEST" &
            !grepl("^-", norm_nest) &
            age == "C",
            .(chick_n = .N, ll_n = data.table::uniqueN(LL)),
            by = .(date, gps_id, gps_point, nest_id)
        ][chick_n > 3 & ll_n == 1]
        if (nrow(grp) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            merge(z, grp, by = c("date", "gps_id", "gps_point", "nest_id"))[age == "C", .(rowid, variable = "LL", reason = "More than three chicks are linked to this positive nest event, but their LL marks do not show much variation. Please check the chick rows and nest linkage in case records from another brood were mixed in.")]
        }
    }, nam = "RES_008 mixed brood")
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
        one_chr <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            if (length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA") {
                NA_character_
            } else {
                raw
            }
        }
        csv_tokens <- function(v) {
            raw <- one_chr(v)
            if (is.na(raw)) {
                return(character())
            }
            toks <- trimws(strsplit(raw, ",", fixed = TRUE)[[1]])
            toks[nzchar(toks)]
        }
        matches_csv_value <- function(value, allowed_csv) {
            val <- one_chr(value)
            if (is.na(val)) {
                return(TRUE)
            }
            allowed <- csv_tokens(allowed_csv)
            if (!length(allowed)) {
                return(TRUE)
            }
            val %in% allowed
        }
        ref <- data.table::as.data.table(db_get("SELECT observer, cam_id FROM OBSERVERS"))
        m <- merge(z, ref, by = "observer", all.x = TRUE, suffixes = c("", "_ref"))
        bad_idx <- m[
            (!is.na(photo_start) | !is.na(photo_end)) &
                !vapply(seq_len(.N), function(i) matches_csv_value(cam_id[i], cam_id_ref[i]), logical(1)),
            rowid
        ]
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = bad_idx, variable = "cam_id", reason = "This camera is different from the observer’s usual camera. Please check the camera ID against the photo files and keep it only if another camera was genuinely used.")
        }
    }, nam = "RES_W001 cam default")
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
        one_chr <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            if (length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA") {
                NA_character_
            } else {
                raw
            }
        }
        csv_tokens <- function(v) {
            raw <- one_chr(v)
            if (is.na(raw)) {
                return(character())
            }
            toks <- trimws(strsplit(raw, ",", fixed = TRUE)[[1]])
            toks[nzchar(toks)]
        }
        matches_csv_value <- function(value, allowed_csv) {
            val <- one_chr(value)
            if (is.na(val)) {
                return(TRUE)
            }
            allowed <- csv_tokens(allowed_csv)
            if (!length(allowed)) {
                return(TRUE)
            }
            val %in% allowed
        }
        ref <- data.table::as.data.table(db_get("SELECT observer, gps_id FROM OBSERVERS"))
        m <- merge(z, ref, by = "observer", all.x = TRUE, suffixes = c("", "_ref"))
        bad_idx <- m[
            !vapply(seq_len(.N), function(i) matches_csv_value(gps_id[i], gps_id_ref[i]), logical(1)),
            rowid
        ]
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = bad_idx, variable = "gps_id", reason = "This GPS ID is different from the observer’s usual GPS. Please check that the correct device and waypoint were entered.")
        }
    }, nam = "RES_W002 gps default")
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
        normalize_mark <- function(v) {
            raw <- trimws(as.character(v))
            raw[is.na(v) | !nzchar(raw) | raw == "NA"] <- NA_character_
            raw
        }
        is_tibia_colour_only <- function(v) {
            v <- normalize_mark(v)
            !is.na(v) && grepl("^[OYWBRGL]{1,2}$", v)
        }
        out <- data.table::rbindlist(lapply(c("UL", "UR"), function(nm) {
            bad_idx <- which(vapply(z[[nm]], is_tibia_colour_only, logical(1)))
            if (!length(bad_idx)) {
                return(NULL)
            }
            data.table::data.table(
                rowid = z$rowid[bad_idx],
                variable = nm,
                reason = "These look like coloured bands may have been entered on the tibia. Please check whether they belong on the tarsus fields LL/LR; tibia fields normally contain flags, metal M, a geolocator code such as TY, or X/blank."
            )
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) empty else unique(out)
    }, nam = "RES_W003 tibia placement")
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
            raw <- trimws(as.character(v))
            raw[is.na(v) | !nzchar(raw) | raw == "NA"] <- NA_character_
            raw
        }

        parse_date_chr <- function(v) {
            suppressWarnings(as.Date(normalize_chr(v), format = "%Y-%m-%d"))
        }

        normalize_event_ref <- function(dt, date_col) {
            if (!nrow(dt)) {
                return(data.table::data.table(
                    gps_id = character(),
                    gps_point = character(),
                    event_date = as.Date(character())
                ))
            }

            dt <- data.table::copy(dt)
            dt[, `:=`(
                gps_id = normalize_chr(gps_id),
                gps_point = normalize_chr(gps_point),
                event_date = parse_date_chr(get(date_col))
            )]

            dt[
                !is.na(gps_id) &
                    !is.na(gps_point) &
                    !is.na(event_date),
                .(gps_id, gps_point, event_date)
            ]
        }

        point_ref <- data.table::as.data.table(db_get("SELECT gps_id, gps_point, datetime_ FROM GPS_POINTS"))
        if (!nrow(point_ref)) {
            empty
        } else {
            point_ref[, `:=`(
                gps_id = normalize_chr(gps_id),
                gps_point = normalize_chr(gps_point),
                point_dt_local = suppressWarnings(as.POSIXct(datetime_, tz = "Pacific/Auckland")),
                point_dt_utc = suppressWarnings(as.POSIXct(datetime_, tz = "UTC"))
            )]
            point_ref[, `:=`(
                point_date_local = suppressWarnings(as.Date(point_dt_local)),
                point_date_utc_nz = suppressWarnings(as.Date(format(point_dt_utc, tz = "Pacific/Auckland", usetz = FALSE)))
            )]

            current <- z[, .(
                rowid,
                gps_id = normalize_chr(gps_id),
                gps_point = normalize_chr(gps_point),
                event_date = parse_date_chr(date)
            )][
                !is.na(gps_id) &
                    !is.na(gps_point) &
                    !is.na(event_date)
            ]

            current <- merge(
                current,
                point_ref[, .(gps_id, gps_point, point_date_local, point_date_utc_nz)],
                by = c("gps_id", "gps_point"),
                all.x = TRUE,
                sort = FALSE
            )

            if (!nrow(current)) {
                empty
            } else {
                cap_ref <- normalize_event_ref(
                    data.table::as.data.table(db_get("SELECT date, gps_id, gps_point FROM CAPTURES")),
                    date_col = "date"
                )
                nest_ref <- normalize_event_ref(
                    data.table::as.data.table(db_get("SELECT date, gps_id, gps_point FROM NESTS")),
                    date_col = "date"
                )
                res_ref <- normalize_event_ref(
                    data.table::as.data.table(db_get("SELECT date, gps_id, gps_point FROM RESIGHTINGS")),
                    date_col = "date"
                )

                other <- data.table::rbindlist(list(cap_ref, nest_ref, res_ref), use.names = TRUE, fill = TRUE)

                current[, earlier_in_x := vapply(seq_len(.N), function(i) {
                    any(
                        current$gps_id == current$gps_id[i] &
                            current$gps_point == current$gps_point[i] &
                            (
                                current$event_date < current$event_date[i] |
                                    (current$event_date == current$event_date[i] & current$rowid < current$rowid[i])
                            )
                    )
                }, logical(1))]

                current[, earlier_in_db := vapply(seq_len(.N), function(i) {
                    any(
                        other$gps_id == current$gps_id[i] &
                            other$gps_point == current$gps_point[i] &
                            other$event_date < current$event_date[i]
                    )
                }, logical(1))]

                out <- current[
                    !(earlier_in_x | earlier_in_db) &
                        !(
                            (!is.na(point_date_local) & point_date_local == event_date) |
                                (!is.na(point_date_utc_nz) & point_date_utc_nz == event_date)
                        ),
                    .(
                        rowid,
                        variable = "date",
                        reason = "The GPS waypoint date does not match the first use of this gps_id/gps_point. Please check the gps_id/gps_point and event date; an old waypoint or device-date mismatch may be involved."
                    )
                ]

                if (nrow(out) == 0) empty else unique(out)
            }
        }
    }, nam = "GLOBAL_W004 gps date")
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
