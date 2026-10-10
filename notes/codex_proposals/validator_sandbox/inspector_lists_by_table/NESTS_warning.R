list({
    out <- try_validator({
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        empty <- data.table::data.table(rowid = integer(), variable = character(), reason = character())
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
            list(valid = TRUE, total = sum(counts))
        }
        out <- z[, {
            p <- parse_hatch(hatch_state)
            if (is.null(p) || (isTRUE(p$valid) && p$total <= 3)) {
                NULL
            } else {
                data.table::data.table(rowid = rowid, variable = "hatch_state", reason = "Please check hatch_state. Use the project’s hatch-sign format and make sure the counts are biologically plausible—usually no more than three eggs.")
            }
        }, by = rowid]
        if (is.null(out) || nrow(out) == 0) empty else out
    }, nam = "hatch state review")
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
            raw[is.na(v) | !nzchar(raw) | toupper(raw) == "NA"] <- NA_character_
            raw
        }
        norm_time_seconds <- function(v) {
            if (inherits(v, "difftime")) {
                return(suppressWarnings(as.numeric(v, units = "secs")))
            }
            raw <- norm_chr(v)
            out <- suppressWarnings(as.numeric(raw))
            hms_idx <- !is.na(raw) & grepl("^\\d{1,2}:\\d{2}(:\\d{2})?$", raw, perl = TRUE)
            if (any(hms_idx)) {
                out[hms_idx] <- vapply(strsplit(raw[hms_idx], ":", fixed = TRUE), function(parts) {
                    values <- as.numeric(parts)
                    if (length(values) == 2L) {
                        values[1] * 3600 + values[2] * 60
                    } else {
                        values[1] * 3600 + values[2] * 60 + values[3]
                    }
                }, numeric(1))
            }
            seconds_idx <- !is.na(raw) & grepl("^-?[0-9]+(?:\\.[0-9]+)?\\s+secs?$", raw, perl = TRUE, ignore.case = TRUE)
            if (any(seconds_idx)) {
                out[seconds_idx] <- suppressWarnings(as.numeric(sub("\\s+secs?$", "", raw[seconds_idx], perl = TRUE, ignore.case = TRUE)))
            }
            out
        }
        has_hatch_sign <- function(v) {
            raw <- norm_chr(v)
            !is.na(raw) & grepl("[0-9]+(?:S|CC|C)", toupper(raw), perl = TRUE)
        }
        has_hatch_state <- function(v) {
            raw <- norm_chr(v)
            !is.na(raw) & grepl("^(?:[1-4](?:S|CC|C|N))+$", toupper(raw), perl = TRUE)
        }
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        if (!"pk" %in% names(z)) {
            z[, pk := NA_real_]
        }
        z[, `:=`(
            source = "current",
            nest_key = norm_chr(nest_id),
            event_date = suppressWarnings(as.Date(norm_chr(date), format = "%Y-%m-%d")),
            event_time = norm_time_seconds(time_visit),
            pk_num = suppressWarnings(as.numeric(as.character(pk))),
            nest_state_key = toupper(norm_chr(nest_state)),
            species_key = toupper(norm_chr(species)),
            site_key = toupper(norm_chr(site)),
            clutch_num = suppressWarnings(as.numeric(as.character(clutch_size))),
            brood_num = suppressWarnings(as.numeric(as.character(brood_size))),
            hatch_state_key = norm_chr(hatch_state),
            hatch_sign = has_hatch_sign(hatch_state)
        )]
        ids <- unique(z$nest_key[!is.na(z$nest_key)])
        hist <- data.table::data.table(
            nest_key = character(),
            event_date = as.Date(character()),
            event_time = numeric(),
            pk_num = numeric(),
            nest_state = character(),
            species_key = character(),
            site_key = character(),
            clutch_num = numeric(),
            brood_num = numeric(),
            hatch_state_key = character(),
            hatch_sign = logical(),
            source = character(),
            rowid = integer()
        )
        if (length(ids) > 0L) {
            quoted <- paste(sprintf("'%s'", gsub("'", "''", ids)), collapse = ", ")
            hist0 <- tryCatch(
                db_get(sprintf(
                    paste(
                        "SELECT nest_id, date, time_visit, pk, nest_state, hatch_state,",
                        "clutch_size, brood_size FROM NESTS WHERE nest_id IN (%s)"
                    ),
                    quoted
                )),
                error = function(e) NULL
            )
            if (!is.null(hist0) && nrow(hist0) > 0L) {
                hist0 <- data.table::as.data.table(hist0)
                for (column in c("nest_id", "date", "time_visit", "pk", "nest_state", "hatch_state", "clutch_size", "brood_size")) {
                    if (!column %in% names(hist0)) {
                        hist0[, (column) := NA_character_]
                    }
                }
                hist <- hist0[, .(
                    nest_key = norm_chr(nest_id),
                    event_date = suppressWarnings(as.Date(norm_chr(date), format = "%Y-%m-%d")),
                    event_time = norm_time_seconds(time_visit),
                    pk_num = suppressWarnings(as.numeric(as.character(pk))),
                    nest_state = norm_chr(nest_state),
                    species_key = NA_character_,
                    site_key = NA_character_,
                    clutch_num = suppressWarnings(as.numeric(as.character(clutch_size))),
                    brood_num = suppressWarnings(as.numeric(as.character(brood_size))),
                    hatch_state_key = norm_chr(hatch_state),
                    hatch_sign = has_hatch_sign(hatch_state),
                    source = "db",
                    rowid = NA_integer_
                )]
            }
        }
        current_hist <- z[, .(
            nest_key,
            event_date,
            event_time,
            pk_num,
            nest_state = nest_state_key,
            species_key,
            site_key,
            clutch_num,
            brood_num,
            hatch_state_key,
            hatch_sign,
            source,
            rowid
        )]
        all_nests <- data.table::rbindlist(list(hist, current_hist), use.names = TRUE, fill = TRUE)
        all_nests <- all_nests[
            !is.na(nest_key) & nzchar(nest_key) &
                !is.na(event_date) & !is.na(event_time)
        ]
        if (nrow(all_nests) == 0L) {
            empty
        } else {
            all_nests[, `:=`(
                source_ord = ifelse(source == "db", 0L, 1L),
                pk_missing = is.na(pk_num)
            )]
            data.table::setorder(
                all_nests,
                nest_key,
                event_date,
                event_time,
                pk_missing,
                pk_num,
                source_ord,
                rowid,
                na.last = TRUE
            )
            all_nests[, `:=`(
                previous_hatch_sign = data.table::shift(hatch_sign)
            ), by = nest_key]
            current_rows <- all_nests[
                source == "current" &
                    species_key == "BADO" &
                    site_key == "CR"
            ]
            bad <- current_rows[
                nest_state == "H" &
                    !is.na(event_date) &
                    !is.na(event_time) &
                    clutch_num > 0 &
                    brood_num > 0 &
                    previous_hatch_sign == TRUE &
                    !has_hatch_state(hatch_state_key),
                .(
                    rowid,
                    variable = "hatch_state",
                    reason = "Hatching appears to be asynchronous: the previous visit recorded hatch signs, and this visit still has both egg(s) and chick(s). Please record the hatch signs you observed today in hatch_state."
                )
            ]
            if (nrow(bad) == 0L) empty else unique(bad)
        }
    }, nam = "asynchronous hatch_state")
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
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        ref <- data.table::as.data.table(db_get("SELECT observer, gps_id, cam_id FROM OBSERVERS"))
        m <- merge(z, ref, by = "observer", all.x = TRUE, suffixes = c("", "_ref"))
        out <- data.table::rbindlist(lapply(seq_len(nrow(m)), function(i) {
            row <- m[i]
            problems <- list()
            has_cam <- !is.na(one_chr(row$cam_id))
            has_start <- !is.na(one_chr(row$photo_start))
            has_end <- !is.na(one_chr(row$photo_end))
            has_nest_photo <- identical(one_chr(row$nest_photo), "1")
            has_tent_photo <- identical(one_chr(row$tent_photo), "1")
            has_photo_event <- has_cam || has_start || has_end || has_nest_photo || has_tent_photo
            if (!matches_csv_value(row$gps_id, row$gps_id_ref)) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "gps_id", reason = "This GPS ID is different from the observer’s usual GPS. Please check that the correct device and waypoint were entered.")
            }
            if (has_photo_event && !matches_csv_value(row$cam_id, row$cam_id_ref)) {
                problems[[length(problems) + 1L]] <- data.table::data.table(rowid = row$rowid, variable = "cam_id", reason = "This camera is different from the observer’s usual camera. Please check the camera ID against the photo files and keep it only if another camera was genuinely used.")
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
    }, nam = "observer defaults")
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
        norm_chr <- function(v) {
            out <- trimws(as.character(v))
            out[is.na(v) | !nzchar(out) | toupper(out) == "NA"] <- NA_character_
            out
        }
        is_photo_flag <- function(v) {
            out <- norm_chr(v)
            !is.na(out) & out == "1"
        }
        clutch_missing <- is.na(norm_chr(z$clutch_size))
        photo_evidence <- is_photo_flag(z$nest_photo) |
            is_photo_flag(z$tent_photo) |
            !is.na(norm_chr(z$cam_id)) |
            !is.na(norm_chr(z$photo_start)) |
            !is.na(norm_chr(z$photo_end))
        hatch_evidence <- !is.na(norm_chr(z$hatch_state)) &
            grepl("N", norm_chr(z$hatch_state), fixed = TRUE)
        bad_idx <- which(clutch_missing & (photo_evidence | hatch_evidence))
        if (length(bad_idx) == 0) {
            empty
        } else {
            data.table::data.table(
                rowid = z$rowid[bad_idx],
                variable = "clutch_size",
                reason = "This visit includes photo or hatch information, but clutch_size is blank. Please enter the clutch size observed today; use 0 when no eggs were present."
            )
        }
    }, nam = "photo clutch size")
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
        norm_num <- function(v) suppressWarnings(as.numeric(as.character(v)))
        has_hatch_sign <- function(v) {
            raw <- toupper(norm_chr(v))
            !is.na(raw) & grepl("[1-4](?:S|CC|C)", raw, perl = TRUE)
        }
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        z[, `:=`(source, "current")]
        ids <- unique(trimws(as.character(z$nest_id)))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table::data.table(nest_id = character(), date = character(), time_visit = character(), nest_state = character(), hatch_state = character(), hatch_sign = logical(), clutch_size = numeric(), rowid = integer(), source = character())
        if (length(ids) > 0) {
            quoted <- paste(sprintf("'%s'", gsub("'", "''", ids)), collapse = ", ")
            hist0 <- tryCatch(db_get(sprintf(paste("SELECT nest_id, date, time_visit, nest_state, hatch_state, clutch_size", "FROM NESTS WHERE nest_id IN (%s)"), quoted)), error = function(e) NULL)
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- data.table::as.data.table(hist0)
                hist[, `:=`(nest_id, norm_chr(nest_id))]
                hist[, `:=`(date, norm_chr(date))]
                hist[, `:=`(time_visit, norm_time_chr(time_visit))]
                hist[, `:=`(nest_state, norm_chr(nest_state))]
                hist[, `:=`(hatch_state, norm_chr(hatch_state))]
                hist[, `:=`(hatch_sign, has_hatch_sign(hatch_state))]
                hist[, `:=`(clutch_size, norm_num(clutch_size))]
                hist[, `:=`(rowid, NA_integer_)]
                hist[, `:=`(source, "db")]
            }
        }
        current_hist <- z[, .(nest_id = norm_chr(nest_id), date = norm_chr(date), time_visit = norm_time_chr(time_visit), nest_state = norm_chr(nest_state), hatch_state = norm_chr(hatch_state), hatch_sign = has_hatch_sign(hatch_state), clutch_size = norm_num(clutch_size), rowid, source)]
        all_nests <- data.table::rbindlist(list(hist, current_hist), use.names = TRUE, fill = TRUE)
        all_nests <- all_nests[!is.na(nest_id) & nzchar(nest_id)]
        all_nests[, `:=`(date_ord, suppressWarnings(as.Date(date)))]
        all_nests[, `:=`(time_ord, suppressWarnings(strptime(time_visit, format = "%H:%M")))]
        all_nests[, `:=`(source_ord, ifelse(source == "current", 0L, 1L))]
        data.table::setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        all_nests <- all_nests[, .SD[1], by = .(nest_id, date, time_visit, nest_state, hatch_state, hatch_sign, clutch_size)]
        data.table::setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        out_parts <- lapply(split(all_nests, by = "nest_id", keep.by = TRUE), function(dt) {
            probs <- list()
            states <- as.character(dt$nest_state)
            hatch_evidence <- states == "H" | as.logical(dt$hatch_sign)
            first_h <- if (any(hatch_evidence, na.rm = TRUE)) which(hatch_evidence)[1] else Inf
            if (nrow(dt) >= 2) {
                for (i in 2:nrow(dt)) {
                  if (i < first_h && !states[i] %in% c("pD", "D", "pP", "P", "notA") && !is.na(dt$clutch_size[i]) && !is.na(dt$clutch_size[i - 1]) && dt$clutch_size[i] < dt$clutch_size[i - 1]) {
                    probs[[length(probs) + 1L]] <- data.table::data.table(rowid = dt$rowid[i], variable = "clutch_size", reason = "Clutch size has decreased before hatch. Please check the egg count and dates; if the decrease is real, add a note explaining what happened.")
                  }
                  if (i > first_h && !states[i] %in% c("pD", "D", "pP", "P", "notA") && !is.na(dt$clutch_size[i])) {
                    prior_idx <- which(!is.na(dt$clutch_size[seq_len(i - 1)]) & !states[seq_len(i - 1)] %in% c("pD", "D", "pP", "P", "notA"))
                    if (length(prior_idx) > 0L) {
                        prior_idx <- prior_idx[length(prior_idx)]
                        if (dt$clutch_size[i] > dt$clutch_size[prior_idx]) {
                            probs[[length(probs) + 1L]] <- data.table::data.table(rowid = dt$rowid[i], variable = "clutch_size", reason = "Clutch size increased after hatch signs were observed for this nest. Please check the egg counts and dates; if an earlier count was incomplete or corrected, explain the change in comments.")
                        }
                    }
                  }
                }
            }
            if (nrow(dt) >= 2 && !states[2] %in% c("pD", "D", "pP", "P", "notA") && !is.na(dt$clutch_size[1]) && dt$clutch_size[1] %in% c(1, 2) && !is.na(dt$clutch_size[2]) && dt$clutch_size[2] < dt$clutch_size[1]) {
                probs[[length(probs) + 1L]] <- data.table::data.table(rowid = dt$rowid[2], variable = "clutch_size", reason = "This nest started below a full clutch, but the next visit did not show an increase. Please check the clutch counts and add a note if the smaller clutch is expected.")
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
    }, nam = "clutch progression")
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
        clutch_num <- suppressWarnings(as.numeric(as.character(z$clutch_size)))
        brood_num <- suppressWarnings(as.numeric(as.character(z$brood_size)))
        bad_idx <- which(!is.na(clutch_num) & !is.na(brood_num) & (clutch_num + brood_num) > 3)
        if (length(bad_idx) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            data.table::data.table(rowid = z$rowid[bad_idx], variable = "clutch_size", reason = "More than three offspring are recorded here. Please double-check clutch_size and brood_size—perhaps there is a very enthusiastic counting error hiding in the sheet.")
        }
    }, nam = "offspring total")
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
        clutch_num <- suppressWarnings(as.numeric(as.character(z$clutch_size)))
        brood_num <- suppressWarnings(as.numeric(as.character(z$brood_size)))
        z[, `:=`(
            nest_key = norm_chr(nest_id),
            event_date = norm_chr(date),
            event_time = norm_time_chr(time_visit),
            state_key = norm_chr(nest_state),
            clutch_num = clutch_num,
            brood_num = brood_num
        )]
        ids <- unique(z$nest_key)
        ids <- ids[!is.na(ids) & nzchar(ids)]
        hist <- data.table::data.table(
            nest_id = character(),
            date = character(),
            time_visit = character(),
            nest_state = character(),
            clutch_size = numeric(),
            brood_size = numeric(),
            rowid = integer(),
            source = character()
        )
        if (length(ids) > 0) {
            quoted <- paste(sprintf("'%s'", gsub("'", "''", ids)), collapse = ", ")
            hist0 <- tryCatch(
                db_get(sprintf(
                    paste(
                        "SELECT nest_id, date, time_visit, nest_state, clutch_size, brood_size",
                        "FROM NESTS WHERE nest_id IN (%s)"
                    ),
                    quoted
                )),
                error = function(e) NULL
            )
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- data.table::as.data.table(hist0)
                hist[, `:=`(
                    nest_id = norm_chr(nest_id),
                    date = norm_chr(date),
                    time_visit = norm_time_chr(time_visit),
                    nest_state = norm_chr(nest_state),
                    clutch_size = suppressWarnings(as.numeric(as.character(clutch_size))),
                    brood_size = suppressWarnings(as.numeric(as.character(brood_size))),
                    rowid = NA_integer_,
                    source = "db"
                )]
            }
        }
        current_hist <- z[, .(
            nest_id = nest_key,
            date = event_date,
            time_visit = event_time,
            nest_state = state_key,
            clutch_size = clutch_num,
            brood_size = brood_num,
            rowid,
            source = "current"
        )]
        all_nests <- data.table::rbindlist(list(hist, current_hist), use.names = TRUE, fill = TRUE)
        all_nests[, `:=`(
            date_ord = suppressWarnings(as.Date(date)),
            time_ord = suppressWarnings(as.POSIXct(strptime(time_visit, format = "%H:%M"))),
            source_ord = ifelse(source == "db", 0L, 1L),
            state_ord = ifelse(nest_state == "notA", 1L, 0L)
        )]
        all_nests <- all_nests[
            !is.na(nest_id) & nzchar(nest_id) &
                !is.na(nest_state) & nzchar(nest_state) &
                !is.na(date_ord) & !is.na(time_ord)
        ]
        if (nrow(all_nests) > 0) {
            data.table::setorder(all_nests, nest_id, date_ord, time_ord, source_ord, state_ord, rowid)
            all_nests[, `:=`(
                previous_state = data.table::shift(nest_state),
                previous_clutch = data.table::shift(clutch_size),
                previous_brood = data.table::shift(brood_size)
            ), by = nest_id]
            terminal_h_nota <- all_nests[
                source == "current" &
                    nest_state == "notA" &
                    clutch_size == 0 &
                    brood_size >= 1 &
                    previous_state == "H" &
                    !is.na(previous_clutch) &
                    previous_clutch >= 0 &
                    previous_brood >= 1,
                rowid
            ]
        } else {
            terminal_h_nota <- integer()
        }
        allowed_after_terminal_h <- rep(FALSE, nrow(z))
        terminal_h_nota <- terminal_h_nota[!is.na(terminal_h_nota)]
        if (length(terminal_h_nota) > 0) {
            allowed_after_terminal_h[terminal_h_nota] <- TRUE
        }
        bad_idx <- which(
            !is.na(clutch_num) &
                !is.na(brood_num) &
                clutch_num == 0 &
                brood_num >= 1 &
                !as.character(z$nest_state) %in% c("H", "pP", "P") &
                !allowed_after_terminal_h
        )
        if (length(bad_idx) == 0) {
            empty
        } else {
            data.table::data.table(
                rowid = z$rowid[bad_idx],
                variable = "clutch_size",
                reason = "No eggs were detected, so this is no longer an active nest record. Please record each chick as its own RESIGHTINGS event, or as a CAPTURES event if it was handled."
            )
        }
    }, nam = "brood without eggs")
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
        clutch_num <- suppressWarnings(as.numeric(as.character(z$clutch_size)))
        brood_raw <- trimws(as.character(z$brood_size))
        brood_raw[is.na(z$brood_size) | brood_raw == "NA"] <- ""
        brood_num <- suppressWarnings(as.numeric(as.character(z$brood_size)))
        clutch_bad <- which(as.character(z$nest_state) %in% c("pP", "P") & (is.na(clutch_num) | clutch_num != 0))
        brood_bad <- which(as.character(z$nest_state) %in% c("pP", "P") & nzchar(brood_raw) & (is.na(brood_num) | brood_num != 0))
        out_parts <- list(
            if (length(clutch_bad) > 0) data.table::data.table(rowid = z$rowid[clutch_bad], variable = "clutch_size", reason = "This pP/P event has a non-zero clutch_size. Please check the nest state and enter 0 if no eggs were present."),
            if (length(brood_bad) > 0) data.table::data.table(rowid = z$rowid[brood_bad], variable = "brood_size", reason = "This pP/P event has a brood_size recorded. Please check the nest state and leave brood_size blank or enter 0 unless chicks were genuinely present.")
        )
        out_parts <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, out_parts)
        if (length(out_parts) == 0) {
            data.table::data.table(rowid = integer(), variable = character(), reason = character())
        } else {
            unique(data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE))
        }
    }, nam = "predated row counts")
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
            list(
                C = sum(counts[states_norm == "C"]),
                S = sum(counts[states_norm == "S"]),
                N = sum(counts[states_norm == "N"])
            )
        }
        h_idx <- which(as.character(z$nest_state) == "H")
        out_parts <- lapply(h_idx, function(i) {
            p <- parse_hatch(z$hatch_state[i])
            brood_num <- suppressWarnings(as.numeric(as.character(z$brood_size[i])))
            clutch_num <- suppressWarnings(as.numeric(as.character(z$clutch_size[i])))
            bad <- FALSE
            if (!is.na(brood_num) && brood_num <= 0) {
                bad <- TRUE
            }
            if (!is.null(p) && (p$C + p$S + p$N) == 0) {
                bad <- TRUE
            }
            if (bad) {
                data.table::data.table(rowid = z$rowid[i], variable = "nest_state", reason = "This H event does not fully agree with brood_size, clutch_size, and hatch_state. Please check the three fields together and correct them if needed.")
            } else {
                NULL
            }
        })
        out_parts <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, out_parts)
        out <- if (length(out_parts) == 0) {
            empty
        } else {
            data.table::rbindlist(out_parts, use.names = TRUE, fill = TRUE)
        }
        if (nrow(out) == 0) empty else out
    }, nam = "H row review")
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
        norm_num <- function(v) suppressWarnings(as.numeric(as.character(v)))
        has_photo_event <- function(dt) {
            ((!is.na(dt$cam_id) & nzchar(trimws(as.character(dt$cam_id)))) | (!is.na(dt$photo_start) & nzchar(trimws(as.character(dt$photo_start)))) | (!is.na(dt$photo_end) & nzchar(trimws(as.character(dt$photo_end)))) | (!is.na(dt$nest_photo) & as.character(dt$nest_photo) == "1") | (!is.na(dt$tent_photo) & as.character(dt$tent_photo) == "1"))
        }
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        z[, `:=`(source, "current")]
        ids <- unique(trimws(as.character(z$nest_id)))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table::data.table(nest_id = character(), date = character(), time_visit = character(), nest_state = character(), clutch_size = numeric(), cam_id = character(), photo_start = character(), photo_end = character(), nest_photo = character(), tent_photo = character(), rowid = integer(), source = character())
        if (length(ids) > 0) {
            quoted <- paste(sprintf("'%s'", gsub("'", "''", ids)), collapse = ", ")
            hist0 <- tryCatch(db_get(sprintf(paste("SELECT nest_id, date, time_visit, nest_state, clutch_size,", "cam_id, photo_start, photo_end, nest_photo, tent_photo", "FROM NESTS WHERE nest_id IN (%s)"), quoted)), error = function(e) NULL)
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- data.table::as.data.table(hist0)
                hist[, `:=`(nest_id, norm_chr(nest_id))]
                hist[, `:=`(date, norm_chr(date))]
                hist[, `:=`(time_visit, norm_time_chr(time_visit))]
                hist[, `:=`(nest_state, norm_chr(nest_state))]
                hist[, `:=`(clutch_size, norm_num(clutch_size))]
                hist[, `:=`(cam_id, norm_chr(cam_id))]
                hist[, `:=`(photo_start, norm_chr(photo_start))]
                hist[, `:=`(photo_end, norm_chr(photo_end))]
                hist[, `:=`(nest_photo, norm_chr(nest_photo))]
                hist[, `:=`(tent_photo, norm_chr(tent_photo))]
                hist[, `:=`(rowid, NA_integer_)]
                hist[, `:=`(source, "db")]
            }
        }
        current_hist <- z[, .(nest_id = norm_chr(nest_id), date = norm_chr(date), time_visit = norm_time_chr(time_visit), nest_state = norm_chr(nest_state), clutch_size = norm_num(clutch_size), cam_id = norm_chr(cam_id), photo_start = norm_chr(photo_start), photo_end = norm_chr(photo_end), nest_photo = norm_chr(nest_photo), tent_photo = norm_chr(tent_photo), rowid, source)]
        all_nests <- data.table::rbindlist(list(hist, current_hist), use.names = TRUE, fill = TRUE)
        all_nests[, `:=`(date_ord, suppressWarnings(as.Date(date)))]
        all_nests[, `:=`(time_ord, suppressWarnings(strptime(time_visit, format = "%H:%M")))]
        # Prefer the current portal rows over identical DB rows when histories overlap.
        all_nests[, `:=`(source_ord, ifelse(source == "current", 0L, 1L))]
        data.table::setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        all_nests <- all_nests[, .SD[1], by = .(
            nest_id,
            date,
            time_visit,
            nest_state,
            clutch_size,
            cam_id,
            photo_start,
            photo_end,
            nest_photo,
            tent_photo
        )]
        data.table::setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        all_nests[, `:=`(photo_event, has_photo_event(.SD)), .SDcols = c("cam_id", "photo_start", "photo_end", "nest_photo", "tent_photo")]
        out_parts <- lapply(split(all_nests, by = "nest_id", keep.by = TRUE), function(dt) {
            probs <- list()
            photo_rows <- which(dt$photo_event)
            if (length(photo_rows) > 0) {
                if (length(photo_rows) > 1) {
                  allow_two <- FALSE
                  if (length(photo_rows) == 2) {
                    first_cs <- dt$clutch_size[photo_rows[1]]
                    second_cs <- dt$clutch_size[photo_rows[2]]
                    allow_two <- !is.na(first_cs) &&
                      !is.na(second_cs) &&
                      first_cs %in% c(1, 2) &&
                      second_cs > first_cs &&
                      second_cs <= 3
                  }
                  if (!allow_two) {
                    probs[[length(probs) + 1L]] <- data.table::data.table(rowid = dt$rowid[photo_rows], variable = "photo_start", reason = "This nest history contains more than one photo event. Please check whether the repeated photo record is intentional and that the photo ranges are correct.")
                  }
                }
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
    }, nam = "photo event review")
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
        z <- data.table::copy(x)
        z[, `:=`(rowid, .I)]
        out <- data.table::rbindlist(lapply(seq_len(nrow(z)), function(i) {
            row <- z[i]
            has_cam <- !is.na(one_chr(row$cam_id))
            has_start <- !is.na(one_chr(row$photo_start))
            has_end <- !is.na(one_chr(row$photo_end))
            all_meta <- has_cam && has_start && has_end
            any_yes <- any(vapply(c("nest_photo", "tent_photo"), function(nm) identical(one_chr(row[[nm]]), "1"), logical(1)))
            if (all_meta && !any_yes) {
                data.table::data.table(rowid = row$rowid, variable = "cam_id", reason = "Photo details are present, but neither nest_photo nor tent_photo is set to 1. Please mark the photo type that was actually taken.")
            } else {
                NULL
            }
        }), use.names = TRUE, fill = TRUE)
        if (is.null(out) || nrow(out) == 0) {
            empty
        } else {
            out
        }
    }, nam = "photo flags")
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
            event_dt = parse_event_dt(date, time_visit)
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
