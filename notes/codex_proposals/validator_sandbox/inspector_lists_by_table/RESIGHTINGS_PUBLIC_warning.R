list({
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        z <- z[!is.na(source) & nzchar(trimws(as.character(source))), .(source = tolower(trimws(as.character(source))), rowid)]
        if (nrow(z) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            is.element_validator(z, v = data.table::data.table(variable = "source", set = list(c("falcon", "email", "ebird", "birdsnz", "facebook", "inaturalist", "instagram"))), reason = "Source is not in the usual public-source list.")
        }
    }, nam = "PUB_004 source")
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
                reason = "This looks like coloured bands may have been entered on the tibia. Please check whether these should instead be recorded on the tarsi (LL/LR). On the tibia, only flags, metal (M), geolocator tag codes such as TY, or blank (X) are normally expected."
            )
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) empty else unique(out)
    }, nam = "PUB_005 tibia placement")
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
            out[is.na(v) | !nzchar(out) | out == "NA"] <- NA_character_
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
        make_combo <- function(dt, cols = c("UL", "LL", "UR", "LR")) {
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
        history <- db_get("SELECT date, UL, LL, UR, LR FROM CAPTURES_ARCHIVE")
        current_caps <- db_get("SELECT date, capture_status, UL_in, LL_in, UR_in, LR_in, UL, LL, UR, LR FROM CAPTURES")
        history <- data.table::as.data.table(history)
        current_caps <- data.table::as.data.table(current_caps)
        if (nrow(history) > 0) {
            history[, `:=`(date, suppressWarnings(as.Date(date)))]
            history <- make_signature_dt(history)
        } else {
            history <- data.table::data.table(date = as.Date(character()), left_pair = character(), right_pair = character(), flag_ul = character(), flag_ur = character(), has_signature = logical())
        }
        if (nrow(current_caps) > 0) {
            current_caps[, `:=`(date, suppressWarnings(as.Date(date)))]
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
            current_caps <- make_signature_dt(current_caps, ul_col = "sig_UL", ll_col = "sig_LL", ur_col = "sig_UR", lr_col = "sig_LR")
        } else {
            current_caps <- data.table::data.table(date = as.Date(character()), left_pair = character(), right_pair = character(), flag_ul = character(), flag_ur = character(), has_signature = logical())
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
            event_date_val <- row$event_date[[1]]
            if (!isTRUE(row$has_signature[[1]]) || is.na(event_date_val)) {
                return(empty)
            }
            prior_archive <- matches_signature(row, history[!is.na(date) & date < event_date_val])
            prior_current <- matches_signature(row, current_caps[!is.na(date) & date < event_date_val])
            if (prior_archive || prior_current) {
                empty
            } else {
                data.table::data.table(rowid = rowid_val, variable = "UL", reason = "Public combo should usually already exist in capture history before this date.")
            }
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) {
            empty
        } else {
            unique(out)
        }
    }, nam = "PUB_006 combo history")
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
