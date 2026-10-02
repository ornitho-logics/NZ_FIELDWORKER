list({
    out <- try_validator({
        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }
        out <- data.table::rbindlist(list(z[age == "C" & capture_status != "F", .(rowid, variable = "capture_status", reason = "This looks like a chick capture. Please check capture_status; it is usually F for a first capture.")], z[age == "J" & !(capture_status %in% c("F", "C")), .(rowid, variable = "capture_status", reason = "This looks like a juvenile capture. Please check capture_status; juveniles usually use F or C.")], z[age == "C" & capture_method != "HA", .(rowid, variable = "capture_method", reason = "This looks like a chick capture. Please check capture_method; chick captures usually use HA.")],
            z[age %in% c("A", "J") & !(capture_method %in% c("MM", "TN")), .(rowid, variable = "capture_method", reason = "Please check capture_method. Adult and juvenile captures usually use MM or TN.")]), use.names = TRUE, fill = TRUE)
        if (nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            unique(out)
        }
    }, nam = "CAP_007 008 likely patterns")
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
        comments_text <- if ("comments" %in% names(z)) as.character(z$comments) else rep(NA_character_, nrow(z))
        phrase <- "(^|[^[:alpha:]])in[[:space:]_-]*situ([^[:alpha:]]|$)"
        bad_idx <- which(
            toupper(trimws(as.character(z$age))) == "C" &
                !is.na(comments_text) &
                grepl(phrase, comments_text, ignore.case = TRUE, perl = TRUE)
        )
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(
                rowid = z$rowid[bad_idx],
                variable = "comments",
                reason = "It looks like these are hiding-spot (in-situ) photos of a chick. Please enter them as a separate RESIGHTINGS event with age C and rclass 'H'; keep this CAPTURES row for handling, banding, and tent photos."
            )
        }
    }, nam = "CAP_W013 in situ hiding photo")
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
        z[, `:=`(nest_key, trimws(as.character(nest_id)))]
        z[nest_key %in% c("", "NA"), `:=`(nest_key, NA_character_)]
        adults <- z[
            age == "A" &
                !is.na(nest_key) &
                nzchar(nest_key) &
                nest_key != "NO_NEST" &
                !grepl("^-", nest_key),
            .(
                rowid,
                nest_id = nest_key,
                sex_group = data.table::fifelse(
                    field_sex %in% c("M", "MU"),
                    "M",
                    data.table::fifelse(field_sex %in% c("F", "FU"), "F", NA_character_)
                )
            )
        ]
        grp <- adults[!is.na(sex_group), .N, by = .(nest_id, sex_group)][N > 1]
        if (nrow(grp) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            merge(adults, grp, by = c("nest_id", "sex_group"))[, .(rowid, variable = "field_sex", reason = "This nest_id has more than one adult recorded as the same sex. That can happen, but please check the sex, nest_id, and leg marks before continuing.")]
        }
    }, nam = "CAP_011 nest sex count")
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
        as_event_dt <- function(date_v, time_v) {
            date_chr <- trimws(as.character(date_v))
            time_chr <- trimws(as.character(time_v))
            date_chr[is.na(date_v) | !nzchar(date_chr) | date_chr == "NA"] <- NA_character_
            time_chr[is.na(time_v) | !nzchar(time_chr) | time_chr == "NA"] <- NA_character_
            with_seconds <- !is.na(time_chr) & grepl("^\\d{2}:\\d{2}:\\d{2}$", time_chr)
            time_chr[with_seconds] <- substr(time_chr[with_seconds], 1, 5)
            out <- as.POSIXct(rep(NA_character_, length(date_chr)), tz = "Pacific/Auckland")
            ok <- !is.na(date_chr) & !is.na(time_chr)
            out[ok] <- as.POSIXct(paste(date_chr[ok], time_chr[ok]), format = "%Y-%m-%d %H:%M", tz = "Pacific/Auckland")
            out
        }
        sex_group <- function(v) {
            raw <- trimws(as.character(v))
            out <- ifelse(raw %in% c("M", "MU"), "M", ifelse(raw %in% c("F", "FU"), "F", NA_character_))
            out[!nzchar(raw) | raw == "NA"] <- NA_character_
            out
        }
        current <- z[, .(
            rowid,
            nest_id = trimws(as.character(nest_id)),
            age = trimws(as.character(age)),
            sex_group = sex_group(field_sex),
            event_dt = as_event_dt(date, caught)
        )]
        current <- current[
            age == "A" &
                !is.na(nest_id) &
                nzchar(nest_id) &
                nest_id != "NO_NEST" &
                !grepl("^-", nest_id) &
                !is.na(sex_group) &
                !is.na(event_dt)
        ]
        if (nrow(current) == 0) {
            empty
        } else {
            ref <- tryCatch(
                data.table::as.data.table(db_get("SELECT date, caught, nest_id, age, field_sex, UL, LL, UR, LR FROM CAPTURES")),
                error = function(e) data.table::data.table(date = character(), caught = character(), nest_id = character(), age = character(), field_sex = character(), UL = character(), LL = character(), UR = character(), LR = character())
            )
            ref[, `:=`(
                nest_id = trimws(as.character(nest_id)),
                age = trimws(as.character(age)),
                sex_group = sex_group(field_sex),
                event_dt = as_event_dt(date, caught)
            )]
            ref <- ref[
                age == "A" &
                    !is.na(nest_id) &
                    nzchar(nest_id) &
                    nest_id != "NO_NEST" &
                    !grepl("^-", nest_id) &
                    !is.na(sex_group) &
                    !is.na(event_dt),
                .(nest_id, sex_group, event_dt)
            ]
            flagged <- current[, {
                hits <- ref[
                    nest_id == .BY$nest_id &
                        sex_group != .BY$sex_group &
                        abs(as.numeric(difftime(event_dt, .BY$event_dt, units = "hours"))) < 36
                ]
                hits_current <- current[
                    rowid != .BY$rowid &
                        nest_id == .BY$nest_id &
                        sex_group != .BY$sex_group &
                        abs(as.numeric(difftime(event_dt, .BY$event_dt, units = "hours"))) < 36
                ]
                if (nrow(hits) > 0 || nrow(hits_current) > 0) {
                    .(rowid = .BY$rowid)
                } else {
                    NULL
                }
            }, by = .(rowid, nest_id, sex_group, event_dt)]
            if (is.null(flagged) || nrow(flagged) == 0) {
                empty
            } else {
                unique(flagged[, .(rowid, variable = "nest_id", reason = "These parents were caught less than 36 hours apart. Please minimise further disturbance where possible, because repeated visits can increase the risk of desertion.")])
            }
        }
    }, nam = "CAP_W011 parent spacing")
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
        chick_colours <- c("R", "B", "G", "W", "O", "L", "Y")
        juvenile_flag <- "^FW[A-Z0-9]{2}$"
        is_blank_band <- function(v) {
            is.na(v) || v == "X"
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
        z[, `:=`(nest_key, trimws(as.character(nest_id)))]
        z[nest_key %in% c("", "NA"), `:=`(nest_key, NA_character_)]
        bad_idx <- z[
            age == "A" &
            capture_status != "D" &
            !is.na(nest_key) &
            nzchar(nest_key) &
            nest_key != "NO_NEST" &
            !grepl("^-", nest_key) &
            !(
                (capture_status == "F" & UL_in == "X" & LL_in == "X" & UR_in == "X" & LR_in == "X") |
                mapply(is_cr_chick_scheme, UL_in, LL_in, UR_in, LR_in) |
                mapply(is_noncr_chick_scheme, UL_in, LL_in, UR_in, LR_in) |
                mapply(is_juvenile_scheme, UL_in, LL_in, UR_in, LR_in) |
                !is.na(tag_id)
            ),
            rowid
        ]
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(
                rowid = bad_idx,
                variable = "nest_id",
                reason = "This is a full-combination recapture. That is usually expected only for first marking, immature remarking, or tag deployment, so please check that the event and marks are correct."
            )
        }
    }, nam = "CAP_016B adult nest target")
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
            out[out %in% c("", "NA")] <- NA_character_
            out
        }
        x_rings <- z[
            trimws(as.character(capture_status)) == "F",
            .(rowid, ring_key = normalize_scalar_chr(ring))
        ]
        x_rings <- x_rings[!is.na(ring_key)]
        if (nrow(x_rings) == 0) {
            empty
        } else {
            current_rings <- tryCatch(
                data.table::as.data.table(db_get("SELECT ring FROM CAPTURES"))[
                    ,
                    .(ring_key = normalize_scalar_chr(ring))
                ],
                error = function(e) data.table::data.table(ring_key = character())
            )
            archive_rings <- tryCatch(
                data.table::as.data.table(db_get("SELECT ring FROM CAPTURES_ARCHIVE"))[
                    ,
                    .(ring_key = normalize_scalar_chr(ring))
                ],
                error = function(e) data.table::data.table(ring_key = character())
            )
            all_rings <- data.table::rbindlist(
                list(
                    x_rings[, .(ring_key)],
                    current_rings[, .(ring_key)],
                    archive_rings[, .(ring_key)]
                ),
                use.names = TRUE,
                fill = TRUE
            )
            dup_rings <- all_rings[
                !is.na(ring_key) & nzchar(ring_key),
                .N,
                by = ring_key
            ][N > 1, ring_key]
            if (length(dup_rings) == 0) {
                empty
            } else {
                x_rings[
                    ring_key %in% dup_rings,
                    .(
                        rowid,
                        variable = "ring",
                        reason = "This ring already appears in current or historical capture records. Please check that the ring was copied correctly and belongs to this bird."
                    )
                ]
            }
        }
    }, nam = "CAP_012 duplicate ring")
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
        normalize_scalar_chr <- function(v) {
            out <- trimws(as.character(v))
            out[out %in% c("", "NA")] <- NA_character_
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
        make_combo <- function(dt, cols = c("UL", "LL", "UR", "LR")) {
            mapply(
                combo_identity,
                dt[[cols[1]]],
                dt[[cols[2]]],
                dt[[cols[3]]],
                dt[[cols[4]]],
                USE.NAMES = FALSE
            )
        }
        is_cr_chick_scheme <- function(ul, ll, ur, lr) {
            !is.na(ll) && ll %in% chick_colours && ur == "M" && (is.na(ul) || ul == "X") && (is.na(lr) || lr == "X")
        }
        is_noncr_chick_scheme <- function(ul, ll, ur, lr) {
            ul == "M" && (is.na(ll) || ll == "X") && (is.na(ur) || ur == "X") && !is.na(lr) && lr %in% chick_colours
        }
        prep_pairs <- function(dt, keep_rowid = FALSE) {
            if (is.null(dt) || nrow(dt) == 0) {
                return(data.table::data.table(rowid = integer(), ring = character(), combo = character()))
            }
            tmp <- data.table::copy(dt)
            if (keep_rowid && !"rowid" %in% names(tmp)) {
                tmp[, `:=`(rowid, .I)]
            }
            for (nm in c("ring", "UL", "LL", "UR", "LR")) {
                tmp[, `:=`((nm), normalize_scalar_chr(tmp[[nm]]))]
            }
            tmp[, `:=`(UR, normalize_tag_ur(UR))]
            tmp <- tmp[!is.na(ring)]
            if (nrow(tmp) == 0) {
                return(data.table::data.table(rowid = integer(), ring = character(), combo = character()))
            }
            tmp[, `:=`(combo, make_combo(.SD)), .SDcols = c("UL", "LL", "UR", "LR")]
            tmp[, `:=`(unique_combo_ok, !is.na(UL) & !is.na(LL) & !is.na(UR) & !is.na(LR) & !(UL == "X" & LL == "X" & UR == "X" & LR == "X") & !mapply(is_cr_chick_scheme, UL, LL, UR, LR) & !mapply(is_noncr_chick_scheme, UL, LL, UR, LR))]
            tmp <- tmp[unique_combo_ok == TRUE]
            if (nrow(tmp) == 0) {
                return(data.table::data.table(rowid = integer(), ring = character(), combo = character()))
            }
            if (keep_rowid) {
                tmp[, .(rowid, ring, combo)]
            } else {
                tmp[, .(ring, combo)]
            }
        }
        archive_pairs <- tryCatch(prep_pairs(data.table::as.data.table(db_get("SELECT ring, UL, LL, UR, LR FROM CAPTURES_ARCHIVE"))), error = function(e) data.table::data.table(ring = character(), combo = character()))
        current_pairs <- tryCatch(prep_pairs(data.table::as.data.table(db_get("SELECT ring, UL, LL, UR, LR FROM CAPTURES"))), error = function(e) data.table::data.table(ring = character(), combo = character()))
        x_pairs <- prep_pairs(z[, .(rowid, ring, UL, LL, UR, LR)], keep_rowid = TRUE)
        if (nrow(x_pairs) == 0) {
            empty
        } else {
            all_pairs <- data.table::rbindlist(list(x_pairs[, .(ring, combo)], current_pairs[, .(ring, combo)], archive_pairs[, .(ring, combo)]), use.names = TRUE, fill = TRUE)
            all_pairs[, `:=`(ring, normalize_scalar_chr(ring))]
            all_pairs[, `:=`(combo, normalize_scalar_chr(combo))]
            all_pairs <- all_pairs[!is.na(ring) & nzchar(ring) & !is.na(combo) & nzchar(combo)]
            dup_combos <- all_pairs[, .(n_rings = length(unique(as.character(ring)))), by = combo][n_rings > 1, combo]
            if (length(dup_combos) == 0) {
                empty
            } else {
            x_pairs[combo %in% dup_combos, .(rowid, variable = "UL", reason = "These leg marks duplicate another record. Please check the marks; if the duplicate is genuine, add a note explaining that the bird should be recaptured for correction.")][, unique(.SD)]
            }
        }
    }, nam = "CAP_012B duplicate markings")
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
        nests <- data.table::as.data.table(db_get("SELECT nest_id, date, nest_state, hatch_state FROM NESTS"))
        nests[, `:=`(date, suppressWarnings(as.Date(date)))]
        z[, `:=`(date, suppressWarnings(as.Date(date)))]
        hatch_ok <- function(nid, event_date) {
            any(
              nests$nest_id == nid &
                !is.na(nests$date) &
                nests$date <= event_date &
                (nests$nest_state == "H" | grepl("[SC]", as.character(nests$hatch_state)))
            )
        }
        bad_idx <- z[
          age %in% c("C", "J") &
            !is.na(nest_id) &
            nzchar(trimws(as.character(nest_id))) &
            trimws(as.character(nest_id)) != "NO_NEST" &
            !grepl("^-", nest_id) &
            !vapply(seq_len(.N), function(i) hatch_ok(nest_id[i], date[i]), logical(1)),
          rowid
        ]
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(
              rowid = bad_idx,
              variable = "nest_id",
              reason = "This chick or juvenile is linked to a positive nest_id, but the nest history does not yet show prior or same-day hatch evidence. Please check NESTS and add or correct the appropriate nest_state H event if hatch signs were observed."
            )
        }
    }, nam = "CAP_015 hatch evidence warning")
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
        z[, `:=`(nest_key, trimws(as.character(nest_id)))]
        z[nest_key %in% c("", "NA"), `:=`(nest_key, NA_character_)]
        grp <- z[
            !is.na(nest_key) &
                nzchar(nest_key) &
                nest_key != "NO_NEST" &
                !grepl("^-", nest_key),
            .(chick_n = sum(age == "C", na.rm = TRUE), adult_n = sum(age == "A", na.rm = TRUE)),
            by = .(date, caught, nest_key)
        ]
        joined <- merge(
            z[, .(rowid, age, caught_with, date, caught, nest_key)],
            grp,
            by = c("date", "caught", "nest_key")
        )
        bad_idx <- joined[age == "A" & chick_n > 0 & (is.na(caught_with) | !grepl("C", as.character(caught_with))), rowid]
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = bad_idx, variable = "caught_with", reason = "Please check caught_with against the birds handled at the same time. It should usually describe the brood composition present during this capture.")
        }
    }, nam = "CAP_025 caught with")
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
        res <- data.table::as.data.table(db_get("SELECT nest_id, age, rclass FROM RESIGHTINGS"))
        hide_nests <- unique(res[age == "C" & rclass == "H" & !is.na(nest_id), nest_id])
        tent_raw <- trimws(as.character(z$chick_tent_photo))
        tent_ok <- !is.na(z$chick_tent_photo) & tent_raw == "1"
        hide_raw <- trimws(as.character(z$chick_hide_photo))
        hide_ok <- is.na(z$chick_hide_photo) | !nzchar(hide_raw) | hide_raw == "NA" | hide_raw == "0"
        bad_idx <- z[age == "C" & nest_id %in% hide_nests & (!tent_ok | !hide_ok), rowid]
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = bad_idx, variable = "chick_tent_photo", reason = "This chick also has an H-class hiding-spot photo. Please record the tent photo here with chick_tent_photo = 1, and leave chick_hide_photo blank or 0; the hiding-spot photo belongs in RESIGHTINGS.")
        }
    }, nam = "CAP_029 chick photo logic")
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
        to_time <- function(v) suppressWarnings(strptime(as.character(v), format = "%H:%M"))
        caught_t <- to_time(z$caught)
        rel_t <- to_time(z$released)
        bad_idx <- unique(c(z[!is.na(caught_t) & format(caught_t, "%H:%M") < "07:00", rowid], z[!is.na(caught_t) & format(caught_t, "%H:%M") > "19:00", rowid], z[!is.na(rel_t) & format(rel_t, "%H:%M") < "07:00", rowid], z[!is.na(rel_t) & format(rel_t, "%H:%M") > "19:00", rowid]))
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
                data.table::data.table(rowid = bad_idx, variable = "caught", reason = "This capture time is outside the usual 07:00–19:00 field window. Please check the time; if it is correct, keep it and add a brief note if helpful.")
        }
    }, nam = "CAP_W001 daylight")
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
        gps_bad <- m[!vapply(seq_len(.N), function(i) matches_csv_value(gps_id[i], gps_id_ref[i]), logical(1))]
        out <- gps_bad[, .(rowid, variable = "gps_id", reason = "This GPS ID is different from the observer’s usual GPS. Please check that the correct device and waypoint were entered.")]
        if (nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            unique(out)
        }
    }, nam = "CAP_W002 GPS default")
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
        has_col <- function(nm) nm %in% names(z)
        one_chr <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            if (length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA") {
                NA_character_
            } else {
                raw
            }
        }
        missing_scalar <- function(v) {
            raw <- trimws(as.character(v[[1]]))
            length(raw) == 0 || is.na(v[[1]]) || !nzchar(raw) || raw == "NA"
        }
        out_parts <- list()
        if (has_col("blood_samp")) {
            out_parts[[length(out_parts) + 1L]] <- z[!is.na(blood_samp) & blood_samp != "BQ", .(rowid, variable = "blood_samp", reason = "Please check blood_samp. Most capture samples use BQ, but keep this value if another sample type was genuinely collected.")]
        }
        out_parts <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, out_parts)
        if (length(out_parts) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            unique(data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE))
        }
    }, nam = "CAP_W004 blood sample review")
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
        limits <- list(
          A = data.table::data.table(
            variable = c("tarsus", "culmen", "total_head", "head_white", "head_black", "rufous_band", "wing", "weight"),
            lq = c(27.84, 15.47, 42.02, 0.00, 0.00, 5.27, 118.02, 49.47),
            uq = c(33.96, 20.42, 49.34, 8.40, 6.37, 27.68, 138.00, 77.16)
          ),
          J = data.table::data.table(
            variable = c("tarsus", "culmen", "total_head", "wing", "weight"),
            lq = c(23.22, 12.46, 40.62, 49.28, 18.58),
            uq = c(30.75, 16.36, 43.58, 124.23, 43.80)
          ),
          C = data.table::data.table(
            variable = c("tarsus", "culmen", "total_head", "wing", "weight"),
            lq = c(18.43, 6.47, 37.01, 21.99, 6.73),
            uq = c(29.52, 15.63, 39.99, 93.37, 40.38)
          )
        )
        out <- data.table::rbindlist(lapply(names(limits), function(age_key) {
            vars <- unique(c(limits[[age_key]]$variable, "rowid"))
            sub <- z[age == age_key, vars, with = FALSE]
            if (nrow(sub) == 0) {
                return(NULL)
            }
            interval_validator(
              sub,
              v = limits[[age_key]],
              reason = "This measurement is unusual for the selected age group. Please recheck the measurement and units; if it is correct, keep it and add a note if needed."
            )
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            out
        }
    }, nam = "CAP_W009 morphometric limits")
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
        normalize_mark <- function(v) {
            raw <- trimws(as.character(v))
            raw[is.na(v) | !nzchar(raw) | raw == "NA"] <- NA_character_
            raw
        }
        one_chr <- function(v) {
            out <- normalize_mark(v[[1]])
            if (length(out) == 0) {
                NA_character_
            } else {
                out
            }
        }
        is_usual_lower <- function(v) {
            if (is.na(v) || v %in% c("", "X")) {
                return(TRUE)
            }
            all(strsplit(v, "", fixed = TRUE)[[1]] %in% c("B", "G", "R", "O", "W", "L", "Y"))
        }
        is_tibia_colour_only <- function(v) {
            v <- normalize_mark(v)
            !is.na(v) && grepl("^[OYWBRGL]{1,2}$", v)
        }
        is_allowed_upper <- function(v) {
            if (is.na(v) || v %in% c("", "X")) {
                return(TRUE)
            }
            if (identical(v, "M")) {
                return(TRUE)
            }
            if (grepl("^F[OYWBRGLM][A-Z0-9]{2,3}$", v)) {
                return(TRUE)
            }
            grepl("^T[A-Z0-9]*[RBGWOLY]$", v)
        }
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            issues <- list()
            for (nm in c("LL", "LR")) {
                val <- one_chr(row[[nm]])
                if (!is_usual_lower(val)) {
                    issues[[length(issues) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = nm, reason = "This tarsus code is unusual. Please check that the colour code is correct; usual colour codes are B, G, R, O, W, L, or Y.")
                }
            }
            for (nm in c("UL_in", "UR_in", "UL", "UR")) {
                val <- one_chr(row[[nm]])
                if (is_tibia_colour_only(val)) {
                    issues[[length(issues) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = nm, reason = "These look like coloured bands may have been entered on the tibia. Please check whether they belong on the tarsus fields LL/LR; tibia fields normally contain flags, metal M, a geolocator code such as TY, or X/blank.")
                } else if (!is_allowed_upper(val)) {
                    issues[[length(issues) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = nm, reason = "This tibia code is unusual. Please check the entry; tibia fields normally contain a flag, metal M, a geolocator code such as TY, or X/blank.")
                }
            }
            if (length(issues) == 0) NULL else data.table::rbindlist(issues, use.names = TRUE, fill = TRUE)
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            out
        }
    }, nam = "CAP_W010 tibia placement")
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
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            has_cam <- !is.na(one_chr(row$cam_id))
            has_start <- !is.na(one_chr(row$photo_start))
            has_end <- !is.na(one_chr(row$photo_end))
            any_yes <- any(vapply(c("mugshot_photo", "wing_photo", "chick_tent_photo", "chick_hide_photo"), function(nm) identical(one_chr(row[[nm]]), "1"), logical(1)))
            if (has_cam && has_start && has_end && !any_yes) {
                data.table::data.table(rowid = row$rowid, variable = "cam_id", reason = "Photo details are present, but none of the photo flags is set to 1. Please check the photo flags and mark the photo type that was actually taken.")
            } else {
                NULL
            }
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            out
        }
    }, nam = "CAP_W011 photo flags")
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
            raw <- trimws(as.character(v))
            raw[is.na(v) | !nzchar(raw) | raw == "NA"] <- NA_character_
            raw
        }
        parse_event_dt <- function(date_v, time_v = NA_character_, fallback_hm = NA_character_) {
            date_chr <- norm_chr(date_v)
            time_chr <- norm_chr(time_v)
            if (!is.na(fallback_hm)) {
                time_chr[is.na(time_chr) & !is.na(date_chr)] <- fallback_hm
            }
            both <- !is.na(date_chr) & !is.na(time_chr)
            out <- as.POSIXct(rep(NA_character_, length(date_chr)), tz = "Pacific/Auckland")
            out[both] <- as.POSIXct(
                paste(date_chr[both], substr(time_chr[both], 1, 5)),
                format = "%Y-%m-%d %H:%M",
                tz = "Pacific/Auckland"
            )
            out
        }
        normalize_event_ref <- function(dt, date_col, time_col = NULL, fallback_hm = NA_character_) {
            if (is.null(dt) || nrow(dt) == 0) {
                return(data.table::data.table(gps_id = character(), gps_point = character(), event_dt = as.POSIXct(character())))
            }
            tmp <- data.table::copy(dt)
            tmp[, `:=`(
                gps_id = norm_chr(gps_id),
                gps_point = norm_chr(gps_point)
            )]
            time_vec <- if (is.null(time_col)) rep(NA_character_, nrow(tmp)) else tmp[[time_col]]
            tmp[, `:=`(event_dt, parse_event_dt(tmp[[date_col]], time_vec, fallback_hm = fallback_hm))]
            tmp[!is.na(gps_id) & !is.na(gps_point) & !is.na(event_dt), .(gps_id, gps_point, event_dt)]
        }

        z <- data.table::copy(x)
        if (!"rowid" %in% names(z)) {
            z[, `:=`(rowid, .I)]
        }

        current <- z[, .(
            rowid,
            gps_id = norm_chr(gps_id),
            gps_point = norm_chr(gps_point),
            event_dt = parse_event_dt(date, caught)
        )][!is.na(gps_id) & !is.na(gps_point) & !is.na(event_dt)]

        if (nrow(current) == 0) {
            empty
        } else {
            gps_ref <- data.table::as.data.table(db_get("SELECT gps_id, gps_point, datetime_ FROM GPS_POINTS"))
            gps_ref[, `:=`(
                gps_id = norm_chr(gps_id),
                gps_point = norm_chr(gps_point),
                point_dt_local = suppressWarnings(as.POSIXct(datetime_, tz = "Pacific/Auckland")),
                point_dt_utc = suppressWarnings(as.POSIXct(datetime_, tz = "UTC"))
            )]
            gps_ref <- gps_ref[
                !is.na(gps_id) &
                    !is.na(gps_point) &
                    (!is.na(point_dt_local) | !is.na(point_dt_utc)),
                .(gps_id, gps_point, point_dt_local, point_dt_utc)
            ]

            current <- merge(current, gps_ref, by = c("gps_id", "gps_point"), all.x = FALSE, sort = FALSE)
            if (nrow(current) == 0) {
                empty
            } else {
                cap_ref <- normalize_event_ref(
                    data.table::as.data.table(db_get("SELECT date, caught, gps_id, gps_point FROM CAPTURES")),
                    date_col = "date",
                    time_col = "caught"
                )
                nest_ref <- normalize_event_ref(
                    data.table::as.data.table(db_get("SELECT date, time_visit, gps_id, gps_point FROM NESTS")),
                    date_col = "date",
                    time_col = "time_visit"
                )
                res_ref <- normalize_event_ref(
                    data.table::as.data.table(db_get("SELECT date, gps_id, gps_point FROM RESIGHTINGS")),
                    date_col = "date",
                    fallback_hm = "12:00"
                )
                other <- data.table::rbindlist(list(cap_ref, nest_ref, res_ref), use.names = TRUE, fill = TRUE)

                current[, earlier_in_x := vapply(seq_len(.N), function(i) {
                    any(
                        current$gps_id == current$gps_id[i] &
                            current$gps_point == current$gps_point[i] &
                            (
                                current$event_dt < current$event_dt[i] |
                                    (current$event_dt == current$event_dt[i] & current$rowid < current$rowid[i])
                            )
                    )
                }, logical(1))]

                current[, earlier_in_db := vapply(seq_len(.N), function(i) {
                    any(
                        other$gps_id == current$gps_id[i] &
                            other$gps_point == current$gps_point[i] &
                            other$event_dt < current$event_dt[i]
                    )
                }, logical(1))]

                out <- current[
                    !(earlier_in_x | earlier_in_db) &
                        (
                            (is.na(point_dt_local) | abs(as.numeric(difftime(event_dt, point_dt_local, units = "mins"))) > 120) &
                                (is.na(point_dt_utc) | abs(as.numeric(difftime(event_dt, point_dt_utc, units = "mins"))) > 120)
                        ),
                    .(
                        rowid,
                        variable = "gps_point",
                        reason = "The GPS waypoint time is more than two hours from the first use of this gps_id/gps_point. Please check the gps_id/gps_point and event date/time; sometimes a device clock is the little culprit here."
                    )
                ]

                if (nrow(out) == 0) empty else unique(out)
            }
        }
    }, nam = "GLOBAL_W003 gps timestamp")
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
