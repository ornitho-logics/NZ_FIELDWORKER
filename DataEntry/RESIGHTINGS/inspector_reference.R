list(
    # Required.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        req_res <- is.na_validator(
            dat[, .(species, observer, date, rclass, sex, age, rowid)],
            reason = "Required."
        )
        as.data.table(req_res)
    } |>
        try_validator(nam = "val1"),

    # H-class resighting fields must be present.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        h_req_res <- rbindlist(
            lapply(
                c("species", "observer", "date", "rclass", "sex", "age"),
                function(col) {
                    txt <- (dat[[col]] |> as.character() |> str_trim())
                    bad_idx <- which(
                        !is.na(dat[[col]]) &
                            rclass_key == "H" &
                            (!nzchar(txt) | (txt |> toupper()) == "NA")
                    )
                    if (length(bad_idx) == 0) {
                        data.table(
                            rowid = integer(),
                            variable = character(),
                            reason = character()
                        )
                    } else {
                        data.table(
                            rowid = dat$rowid[bad_idx],
                            variable = col,
                            reason = "H-class resighting fields must be present."
                        )
                    }
                }
            ),
            use.names = TRUE,
            fill = TRUE
        )
        h_req_res
    } |>
        try_validator(nam = "val2"),

    # Required resighting fields and links.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) == "NA"
        }
        has_pos_nest_id <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) &
                nzchar(txt) &
                (txt |> toupper()) != "NA" &
                (txt |> toupper()) != "NO_NEST" &
                !(txt |> str_detect("^-")) %in% TRUE
        }
        has_neg_brd_id <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & (txt |> str_detect("^-")) %in% TRUE
        }
        neg_brd_flag <- has_neg_brd_id(dat$nest_id)
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        h_flag <- !is.na(rclass_key) & rclass_key == "H"
        gps_req <- !has_pos_nest_id(dat$nest_id) | h_flag
        dat[, let(neg_flag = neg_brd_flag, h_photo = h_flag)]
        gps_id_blank <- dat[
            gps_req & blank(gps_id),
            .(
                rowid,
                variable = "gps_id",
                reason = ifelse(
                    h_photo,
                    "Class H requires both GPS fields, including with nest_id.",
                    ifelse(
                        neg_flag,
                        "Negative nest_id requires gps_id and gps_point.",
                        "Enter gps_id and gps_point without a positive nest link."
                    )
                )
            )
        ]
        gps_id_blank
    } |>
        try_validator(nam = "val3"),

    # Required resighting fields and links.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) == "NA"
        }
        has_pos_nest_id <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) &
                nzchar(txt) &
                (txt |> toupper()) != "NA" &
                (txt |> toupper()) != "NO_NEST" &
                !(txt |> str_detect("^-")) %in% TRUE
        }
        has_neg_brd_id <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & (txt |> str_detect("^-")) %in% TRUE
        }
        neg_brd_flag <- has_neg_brd_id(dat$nest_id)
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        h_flag <- !is.na(rclass_key) & rclass_key == "H"
        gps_req <- !has_pos_nest_id(dat$nest_id) | h_flag
        dat[, let(neg_flag = neg_brd_flag, h_photo = h_flag)]
        gps_point_blank <- dat[
            gps_req & blank(gps_point),
            .(
                rowid,
                variable = "gps_point",
                reason = ifelse(
                    h_photo,
                    "Class H requires both GPS fields, including with nest_id.",
                    ifelse(
                        neg_flag,
                        "Negative nest_id requires gps_id and gps_point.",
                        "Enter gps_id and gps_point without a positive nest link."
                    )
                )
            )
        ]
        gps_point_blank
    } |>
        try_validator(nam = "val4"),

    # Enter both GPS fields or neither; usually blank for positive nests.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) == "NA"
        }
        has_pos_nest_id <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) &
                nzchar(txt) &
                (txt |> toupper()) != "NA" &
                (txt |> toupper()) != "NO_NEST" &
                !(txt |> str_detect("^-")) %in% TRUE
        }
        has_neg_brd_id <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & (txt |> str_detect("^-")) %in% TRUE
        }
        neg_brd_flag <- has_neg_brd_id(dat$nest_id)
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        h_flag <- !is.na(rclass_key) & rclass_key == "H"
        gps_req <- !has_pos_nest_id(dat$nest_id) | h_flag
        dat[, let(neg_flag, neg_brd_flag)]
        pos_partial_gps <- dat[
            !gps_req & xor(blank(gps_id), blank(gps_point)),
            .(
                rowid,
                variable = ifelse(blank(gps_id), "gps_id", "gps_point"),
                reason = "Enter both GPS fields or neither; usually blank for positive nests."
            )
        ]
        pos_partial_gps
    } |>
        try_validator(nam = "val5"),

    # Required.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) == "NA"
        }
        has_neg_brd_id <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & (txt |> str_detect("^-")) %in% TRUE
        }
        neg_brd_flag <- has_neg_brd_id(dat$nest_id)
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        age_key <- (dat$age |> as.character() |> str_trim() |> toupper())
        dat[, let(neg_flag, neg_brd_flag)]
        behav_blank <- dat[
            !is.na(rclass_key) &
                rclass_key != "H" &
                !(rclass_key == "R" & age_key == "C") &
                blank(behav),
            .(rowid, variable = "behav", reason = "Required.")
        ]
        behav_blank
    } |>
        try_validator(nam = "val6"),

    # Enter at least one leg mark.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) == "NA"
        }
        has_neg_brd_id <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & (txt |> str_detect("^-")) %in% TRUE
        }
        neg_brd_flag <- has_neg_brd_id(dat$nest_id)
        dat[, let(neg_flag, neg_brd_flag)]
        leg_blank <- dat[
            blank(UL) & blank(LL) & blank(UR) & blank(LR),
            .(rowid, variable = "UL", reason = "Enter at least one leg mark.")
        ]
        leg_blank
    } |>
        try_validator(nam = "val7"),

    # H chick: UR = M requires blank UL.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        if (!"rclass" %in% names(dat)) {
            dat[, let(rclass, NA_character_)]
        }
        if (!"UL" %in% names(dat)) {
            dat[, let(UL, NA_character_)]
        }
        if (!"LL" %in% names(dat)) {
            dat[, let(LL, NA_character_)]
        }
        if (!"UR" %in% names(dat)) {
            dat[, let(UR, NA_character_)]
        }
        if (!"LR" %in% names(dat)) {
            dat[, let(LR, NA_character_)]
        }
        blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) %in% c("NA", "X", "XX")
        }
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        ur_key <- (dat$UR |> as.character() |> str_trim() |> toupper())
        h_i <- !is.na(rclass_key) & rclass_key == "H"
        dat[
            h_i & ur_key == "M" & !blank(UL),
            .(
                rowid,
                variable = "UL",
                reason = "H chick: UR = M requires blank UL."
            )
        ]
    } |>
        try_validator(nam = "val8"),

    # H chick: blank UR requires UL = M.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        if (!"rclass" %in% names(dat)) {
            dat[, let(rclass, NA_character_)]
        }
        if (!"UL" %in% names(dat)) {
            dat[, let(UL, NA_character_)]
        }
        if (!"LL" %in% names(dat)) {
            dat[, let(LL, NA_character_)]
        }
        if (!"UR" %in% names(dat)) {
            dat[, let(UR, NA_character_)]
        }
        if (!"LR" %in% names(dat)) {
            dat[, let(LR, NA_character_)]
        }
        blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) %in% c("NA", "X", "XX")
        }
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        ul_key <- (dat$UL |> as.character() |> str_trim() |> toupper())
        h_i <- !is.na(rclass_key) & rclass_key == "H"
        dat[
            h_i & blank(UR) & (is.na(ul_key) | ul_key != "M"),
            .(
                rowid,
                variable = "UL",
                reason = "H chick: blank UR requires UL = M."
            )
        ]
    } |>
        try_validator(nam = "val9"),

    # H chick: single LL colour requires blank LR.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        if (!"rclass" %in% names(dat)) {
            dat[, let(rclass, NA_character_)]
        }
        if (!"UL" %in% names(dat)) {
            dat[, let(UL, NA_character_)]
        }
        if (!"LL" %in% names(dat)) {
            dat[, let(LL, NA_character_)]
        }
        if (!"UR" %in% names(dat)) {
            dat[, let(UR, NA_character_)]
        }
        if (!"LR" %in% names(dat)) {
            dat[, let(LR, NA_character_)]
        }
        blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) %in% c("NA", "X", "XX")
        }
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        ll_key <- (dat$LL |> as.character() |> str_trim() |> toupper())
        single_color <- c("B", "G", "R", "O", "W", "L", "Y")
        h_i <- !is.na(rclass_key) & rclass_key == "H"
        dat[
            h_i & ll_key %in% single_color & !blank(LR),
            .(
                rowid,
                variable = "LR",
                reason = "H chick: single LL colour requires blank LR."
            )
        ]
    } |>
        try_validator(nam = "val10"),

    # H chick: blank LL requires one LR colour (B/G/R/O/W/L/Y).
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        if (!"rclass" %in% names(dat)) {
            dat[, let(rclass, NA_character_)]
        }
        if (!"UL" %in% names(dat)) {
            dat[, let(UL, NA_character_)]
        }
        if (!"LL" %in% names(dat)) {
            dat[, let(LL, NA_character_)]
        }
        if (!"UR" %in% names(dat)) {
            dat[, let(UR, NA_character_)]
        }
        if (!"LR" %in% names(dat)) {
            dat[, let(LR, NA_character_)]
        }
        blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) %in% c("NA", "X", "XX")
        }
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        lr_key <- (dat$LR |> as.character() |> str_trim() |> toupper())
        single_color <- c("B", "G", "R", "O", "W", "L", "Y")
        h_i <- !is.na(rclass_key) & rclass_key == "H"
        dat[
            h_i & blank(LL) & !(lr_key %in% single_color),
            .(
                rowid,
                variable = "LR",
                reason = "H chick: blank LL requires one LR colour (B/G/R/O/W/L/Y)."
            )
        ]
    } |>
        try_validator(nam = "val11"),

    # Require a ring for each hiding-photo chick.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        if (!"rclass" %in% names(dat)) {
            dat[, let(rclass, NA_character_)]
        }
        if (!"ring" %in% names(dat)) {
            dat[, let(ring, NA_character_)]
        }
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        ring_key <- (dat$ring |> as.character() |> str_trim())
        blank_ring <- is.na(dat$ring) |
            is.na(ring_key) |
            !nzchar(ring_key) |
            (ring_key |> toupper()) == "NA"
        dat[
            !is.na(rclass_key) & rclass_key == "H" & blank_ring,
            .(rowid, variable = "ring", reason = "Class H requires ring.")
        ]
    } |>
        try_validator(nam = "val12"),

    # Check the field-season dates.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        d <- (dat$date |> as.Date())
        bad_idx <- which(
            !is.na(dat$date) &
                (is.na(d) |
                    d < ("2026-07-01" |> as.Date()) |
                    d > ("2027-07-31" |> as.Date()))
        )
        if (length(bad_idx) == 0) {
            none
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "date",
                reason = "Use a date in the 2026–2027 season."
            )
        }
    } |>
        try_validator(nam = "val13"),

    # Require an earlier nest record for positive links.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        is_pos_nest <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(txt) &
                nzchar(txt) &
                txt != "NA" &
                (txt |> toupper()) != "NO_NEST" &
                !(txt |> str_detect("^-")) %in%
                    TRUE
        }
        nests_dt <- as.data.table(db_get(
            "SELECT nest_id, date, nest_state FROM NESTS"
        ))
        if (nrow(nests_dt) > 0) {
            nests_dt <- copy(nests_dt)
            nests_dt[, let(event_date_nest, (date |> as.Date()))]
            nests_dt <- nests_dt[
                nest_state %in%
                    c("F", "I", "H") &
                    !is.na(event_date_nest) &
                    !is.na(nest_id) &
                    nzchar((nest_id |> as.character() |> str_trim())),
                .(
                    nest_id = (nest_id |> as.character() |> str_trim()),
                    event_date_nest
                )
            ]
            if (nrow(nests_dt) > 0) {
                setorder(nests_dt, nest_id, event_date_nest)
                nests_dt <- nests_dt[, .SD[1], by = nest_id]
            }
        } else {
            nests_dt <- data.table(
                nest_id = character(),
                event_date_nest = (character() |> as.Date())
            )
        }
        dat[, let(event_date, (date |> as.Date()))]
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                nest_key <- (rec$nest_id[[1]] |> as.character() |> str_trim())
                evt_date_v <- rec$event_date[[1]]
                if (!is_pos_nest(nest_key) || is.na(evt_date_v)) {
                    return(none)
                }
                first_f <- nests_dt[nest_id == nest_key]
                if (nrow(first_f) == 0) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "nest_id",
                        reason = "nest_id requires a same-day-or-earlier NESTS F, I, or H event."
                    ))
                }
                first_date <- first_f$event_date_nest[[1]]
                if (evt_date_v < first_date) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "nest_id",
                        reason = "nest_id requires a same-day-or-earlier NESTS F, I, or H event."
                    ))
                }
                none
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val14"),

    # Check photo metadata against resighting class.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        set_v <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & txt != "NA"
        }
        res <- dat[
            set_v(cam_id) &
                set_v(photo_start) &
                set_v(photo_end) &
                !(rclass |> as.character() |> str_trim()) %in%
                    c("V", "P", "H"),
            .(
                rowid,
                variable = "rclass",
                reason = "When cam_id, photo_start, and photo_end are entered, rclass must be V, P, or H."
            )
        ]
        if (nrow(res) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val15"),

    # Check that the GPS pair has been uploaded.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        raw_id <- (dat$gps_id |> as.character() |> str_trim())
        raw_point <- (dat$gps_point |> as.character() |> str_trim())
        gps_id_num <- (raw_id |> as.integer())
        gps_point_num <- (raw_point |> as.integer())
        check_i <- which(
            !is.na(dat$gps_id) &
                nzchar(raw_id) &
                !is.na(dat$gps_point) &
                nzchar(raw_point) &
                !is.na(gps_id_num) &
                !is.na(gps_point_num)
        )
        if (length(check_i) == 0) {
            none
        } else {
            ref0 <- tryCatch(
                db_get("SELECT gps_id, gps_point FROM GPS_POINTS"),
                error = function(e) NULL
            )
            if (is.null(ref0)) {
                data.table(
                    rowid = dat$rowid[check_i],
                    variable = "gps_point",
                    reason = "GPS pair unverified; check the gpxui upload."
                )
            } else {
                src <- as.data.table(ref0)
                src[, let(
                    gps_id_num,
                    (gps_id |> as.character() |> as.integer())
                )]
                src[, let(
                    gps_point_num,
                    (gps_point |> as.character() |> as.integer())
                )]
                ref_key <- unique(src[
                    !is.na(gps_id_num) & !is.na(gps_point_num),
                    .(
                        gps_id_num,
                        gps_point_num
                    )
                ])
                current <- data.table(
                    rowid = dat$rowid[check_i],
                    gps_id_num = gps_id_num[check_i],
                    gps_point_num = gps_point_num[check_i]
                )
                res <- current[!ref_key, on = .(gps_id_num, gps_point_num)]
                if (nrow(res) == 0) {
                    none
                } else {
                    res[, .(
                        rowid,
                        variable = "gps_point",
                        reason = "GPS pair missing from GPS_POINTS; upload via gpxui."
                    )]
                }
            }
        }
    } |>
        try_validator(nam = "val16"),

    # Check the site code.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat <- dat[
            !is.na(site) & nzchar((site |> as.character() |> str_trim()))
        ]
        dat[, let(site, (site |> as.character() |> str_trim()))]
        is.element_validator(
            dat[, .(rowid, site)],
            v = data.table(
                variable = "site",
                set = list(c(
                    "AR",
                    "AU",
                    "CH",
                    "CL",
                    "CR",
                    "HC",
                    "HR",
                    "KK",
                    "KP",
                    "KT",
                    "MB",
                    "MR",
                    "MS",
                    "OD",
                    "OK",
                    "OM",
                    "PB",
                    "PR",
                    "TA",
                    "TO",
                    "TP",
                    "TR",
                    "TS",
                    "WA",
                    "WN",
                    "WS"
                ))
            ),
            reason = "Invalid site code."
        )
    } |>
        try_validator(nam = "val17"),

    # Keep the validation flag blank.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        chunks <- list()
        if ("falcon_upload" %in% names(dat)) {
            raw_falcon <- (dat[["falcon_upload"]] |>
                as.character() |>
                str_trim())
            bad_falcon <- which(
                !is.na(dat[["falcon_upload"]]) &
                    nzchar(raw_falcon) &
                    !raw_falcon %in%
                        c("0", "1")
            )
            if (length(bad_falcon) > 0) {
                chunks[[length(chunks) + 1]] <- data.table(
                    rowid = dat$rowid[bad_falcon],
                    variable = "falcon_upload",
                    reason = "FALCON upload must be blank, 0, or 1."
                )
            }
        }
        if ("nov" %in% names(dat)) {
            raw_nov <- (dat[["nov"]] |> as.character() |> str_trim())
            bad_nov <- which(!is.na(dat[["nov"]]) & nzchar(raw_nov))
            if (length(bad_nov) > 0) {
                chunks[[length(chunks) + 1]] <- data.table(
                    rowid = dat$rowid[bad_nov],
                    variable = "nov",
                    reason = "Leave blank."
                )
            }
        }
        res <- if (length(chunks) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        if (nrow(res) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val18"),

    # Check the observer is active on the resighting date.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        src <- as.data.table(db_get(
            "SELECT observer, start, stop FROM OBSERVERS"
        ))
        src[, let(start, (start |> as.Date()))]
        src[, let(stop, (stop |> as.Date()))]
        dat[, let(date, (date |> as.Date()))]
        m <- merge(
            dat[, .(rowid, observer, date)],
            src,
            by = "observer",
            all.x = TRUE
        )
        bad_idx <- m[
            is.na(start) |
                is.na(stop) |
                is.na(date) |
                date < start |
                date > stop,
            rowid
        ]
        if (length(bad_idx) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            data.table(
                rowid = bad_idx,
                variable = "observer",
                reason = "Observer missing or inactive on resighting date."
            )
        }
    } |>
        try_validator(nam = "val19"),

    # Check the resighting class.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat <- dat[
            !is.na(rclass) & nzchar((rclass |> as.character() |> str_trim()))
        ]
        dat[, let(rclass, (rclass |> as.character() |> str_trim()))]
        is.element_validator(
            dat[, .(rowid, rclass)],
            v = data.table(
                variable = "rclass",
                set = list(c(
                    "R",
                    "V",
                    "P",
                    "C",
                    "H"
                ))
            ),
            reason = "Use R, V, P, C, or H."
        )
    } |>
        try_validator(nam = "val20"),

    # Use M, MU, F, FU, or U.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat[
            !(sex %in% c("M", "MU", "F", "FU", "U")),
            .(rowid, variable = "sex", reason = "Use M, MU, F, FU, or U.")
        ]
    } |>
        try_validator(nam = "val21"),

    # Use A, J, or C.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat[
            !(age %in% c("A", "J", "C")),
            .(rowid, variable = "age", reason = "Use A, J, or C.")
        ]
    } |>
        try_validator(nam = "val22"),

    # Chick and juvenile resightings must use sex U.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat[
            age %in% c("C", "J") & sex != "U",
            .(
                rowid,
                variable = "sex",
                reason = "Chick and juvenile resightings must use sex U."
            )
        ]
    } |>
        try_validator(nam = "val23"),

    # Class H requires age C.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        age_key <- (dat$age |> as.character() |> str_trim())
        dat[
            !is.na(rclass_key) &
                rclass_key == "H" &
                !is.na(age_key) &
                nzchar(age_key) &
                age_key != "C",
            .(rowid, variable = "age", reason = "Class H requires age C.")
        ]
    } |>
        try_validator(nam = "val24"),

    # Check behaviour codes against age.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        parse_behav <- function(v) {
            if (is.na(v) || !nzchar((v |> as.character() |> str_trim()))) {
                character()
            } else {
                (unlist(
                    (v |>
                        as.character() |>
                        str_split(fixed(",")) |>
                        lapply(function(parts) {
                            if (identical(tail(parts, 1), "")) {
                                head(parts, -1)
                            } else {
                                parts
                            }
                        }))
                ) |>
                    str_trim())
            }
        }
        allowed_cj_behav <- c(
            "OB",
            "FT",
            "AT",
            "LF",
            "RS",
            "FF",
            "FA",
            "FC",
            "PR"
        )
        bad_idx <- which(
            dat$age %in%
                c("C", "J") &
                vapply(
                    dat$behav,
                    function(v) {
                        tkns <- parse_behav(v)
                        length(tkns) > 0 && !all(tkns %in% allowed_cj_behav)
                    },
                    logical(1)
                )
        )
        if (length(bad_idx) == 0) {
            none
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "behav",
                reason = "Chick and juvenile resightings can only use OB, FT, AT, LF, RS, FF, FA, FC, or PR."
            )
        }
    } |>
        try_validator(nam = "val25"),

    # Check the nest or brood identifier.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        prefix_map <- c(BADO = "BA", WRYB = "WR", SNZD = "SN", BFDO = "BF")
        raw_nest <- (dat$nest_id |> as.character() |> str_trim())
        is_no_nest <- function(v) {
            !is.na(v) &
                (v |> as.character() |> str_trim() |> toupper()) == "NO_NEST"
        }
        nest_ok <- mapply(
            function(site, species, nest_id) {
                if (is.na(nest_id) || !nzchar(nest_id) || is_no_nest(nest_id)) {
                    return(TRUE)
                }
                if (!is.na(site) && site == "CR") {
                    return(
                        (nest_id |> str_detect("^-?[ABC][0-9]{4}$")) %in% TRUE
                    )
                }
                if (!is.na(species) && species %in% names(prefix_map)) {
                    return(
                        (nest_id |>
                            str_detect(paste0(
                                "^-?",
                                prefix_map[[species]],
                                "[0-9]{4}$"
                            ))) %in%
                            TRUE
                    )
                }
                (nest_id |>
                    str_detect(
                        "^(^-?[ABC][0-9]{4}$)|(^-?(BA|WR|SN|BF)[0-9]{4}$)$"
                    )) %in%
                    TRUE
            },
            dat$site,
            dat$species,
            raw_nest,
            USE.NAMES = FALSE
        )
        bad_idx <- which(!nest_ok)
        if (length(bad_idx) == 0) {
            none
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "nest_id",
                reason = ifelse(
                    dat$site[bad_idx] == "CR",
                    "Cass River nest_id must use plot + gps_id + sequence, e.g. B0112 or -B0203.",
                    "Use species prefix + 4 digits, e.g. BA0804 or -BA0804."
                )
            )
        }
    } |>
        try_validator(nam = "val26"),

    # Check nest links for adult and chick observations.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) == "NA"
        }
        parse_behav <- function(v) {
            if (is.na(v) || !nzchar((v |> as.character() |> str_trim()))) {
                character()
            } else {
                (unlist(
                    (v |>
                        as.character() |>
                        str_split(fixed(",")) |>
                        lapply(function(parts) {
                            if (identical(tail(parts, 1), "")) {
                                head(parts, -1)
                            } else {
                                parts
                            }
                        }))
                ) |>
                    str_trim())
            }
        }
        is_no_nest <- function(v) {
            !is.na(v) &
                (v |> as.character() |> str_trim() |> toupper()) == "NO_NEST"
        }
        clean_segment <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            txt[is.na(v) | !nzchar(txt) | txt == "NA"] <- NA_character_
            txt
        }
        is_unbanded_resight <- function(ul, ll, ur, lr) {
            segs <- c(ul, ll, ur, lr)
            segs <- (segs |> as.character() |> str_trim())
            segs[
                is.na(segs) | !nzchar(segs) | (segs |> toupper()) == "NA"
            ] <- NA_character_
            segs[(segs |> toupper()) == "XX"] <- "X"
            all(is.na(segs) | segs %in% c("X", "M"))
        }
        clean_geo <- function(v) {
            txt <- clean_segment(v)
            res <- txt
            tag_like <- !is.na(txt) &
                (txt |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (txt[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
        clean_bands <- function(v) {
            txt <- clean_segment(v)
            res <- vapply(
                txt,
                function(one) {
                    if (is.na(one) || !nzchar(one)) {
                        return(NA_character_)
                    }
                    sides <- (one |>
                        str_split(fixed("-")) |>
                        lapply(function(parts) {
                            if (identical(tail(parts, 1), "")) {
                                head(parts, -1)
                            } else {
                                parts
                            }
                        }))[[1]]
                    if (length(sides) != 2) {
                        return(one)
                    }
                    clean_side <- function(side) {
                        if (is.na(side) || !nzchar(side) || side == "X") {
                            return("X")
                        }
                        segs <- (unlist(
                            (side |>
                                str_split(fixed(".")) |>
                                lapply(function(parts) {
                                    if (identical(tail(parts, 1), "")) {
                                        head(parts, -1)
                                    } else {
                                        parts
                                    }
                                }))
                        ) |>
                            str_trim())
                        segs <- segs[nzchar(segs)]
                        if (!length(segs)) {
                            return("X")
                        }
                        segs <- vapply(
                            segs,
                            function(seg) {
                                if (
                                    (seg |>
                                        str_detect(
                                            "^T[A-Z0-9]*[RBGWOLY]$"
                                        )) %in%
                                        TRUE
                                ) {
                                    paste0(
                                        "T",
                                        (seg |>
                                            str_replace(
                                                regex(
                                                    "^.*([RBGWOLY])$",
                                                    dotall = TRUE
                                                ),
                                                "\\1"
                                            ))
                                    )
                                } else {
                                    seg
                                }
                            },
                            character(1)
                        )
                        paste(segs, collapse = ".")
                    }
                    paste0(clean_side(sides[1]), "-", clean_side(sides[2]))
                },
                character(1)
            )
            res
        }
        make_mark <- function(ul, ll, ur, lr) {
            ul1 <- clean_segment(ul)
            ll1 <- clean_segment(ll)
            ur1 <- clean_segment(clean_geo(ur))
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
                if (length(left)) {
                    paste(left, collapse = ".")
                } else {
                    "X"
                },
                "-",
                if (length(right)) {
                    paste(right, collapse = ".")
                } else {
                    "X"
                }
            )
        }
        clean_clock <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            txt[is.na(v) | !nzchar(txt) | txt == "NA"] <- "99:99"
            with_sec <- (txt |> str_detect("^\\d{2}:\\d{2}:\\d{2}$")) %in% TRUE
            txt[with_sec] <- substr(txt[with_sec], 1, 5)
            txt
        }
        split_marks <- function(v) {
            txt <- clean_segment(v)
            if (!length(txt) || is.na(txt[1])) {
                return(character())
            }
            vals <- (unlist(
                (txt[1] |>
                    str_split(fixed(",")) |>
                    lapply(function(parts) {
                        if (identical(tail(parts, 1), "")) {
                            head(parts, -1)
                        } else {
                            parts
                        }
                    }))
            ) |>
                str_trim())
            vals <- vals[nzchar(vals)]
            if (!length(vals)) {
                character()
            } else {
                unique(clean_bands(vals))
            }
        }
        is_active_link <- function(
            nest_key,
            event_date,
            event_time_key,
            nests_dt,
            end_states
        ) {
            nk <- (nest_key |> as.character() |> str_trim())
            if (is.na(nk) || !nzchar(nk)) {
                return(FALSE)
            }
            if (is_no_nest(nk)) {
                return(FALSE)
            }
            if ((nk |> str_detect("^-")) %in% TRUE) {
                return(TRUE)
            }
            buf <- nests_dt[
                nest_id == nk &
                    !is.na(event_date_nest) &
                    (event_date_nest < event_date |
                        (event_date_nest == event_date &
                            time_visit_key <= event_time_key))
            ]
            if (nrow(buf) == 0) {
                return(FALSE)
            }
            setorder(buf, event_date_nest, time_visit_key)
            !((buf$nest_state[nrow(buf)] |> as.character()) %in% end_states)
        }
        now_caps <- as.data.table(db_get(
            "SELECT date, caught, nest_id, age, field_sex, UL, LL, UR, LR FROM CAPTURES"
        ))
        now_nests <- as.data.table(db_get(
            "SELECT nest_id, date, time_visit, nest_state FROM NESTS"
        ))
        nests_last <- as.data.table(db_get(
            "SELECT nest_id, nest_state, last_visit_datetime, M_mark, F_mark FROM NESTS_LATEST"
        ))
        link_end_states <- c("pP", "P", "D", "notA")
        if (nrow(now_caps) > 0) {
            now_caps[, let(
                mark,
                mapply(make_mark, UL, LL, UR, LR, USE.NAMES = FALSE)
            )]
            now_caps[, let(date, (date |> as.Date()))]
            now_caps[, let(caught_key, clean_clock(caught))]
        } else {
            now_caps <- data.table(
                date = (character() |> as.Date()),
                caught_key = character(),
                nest_id = character(),
                age = character(),
                field_sex = character(),
                mark = character()
            )
        }
        if (nrow(now_nests) > 0) {
            now_nests[, let(event_date_nest, (date |> as.Date()))]
            now_nests[, let(time_visit_key, clean_clock(time_visit))]
        } else {
            now_nests <- data.table(
                nest_id = character(),
                nest_state = character(),
                event_date_nest = (character() |> as.Date()),
                time_visit_key = character()
            )
        }
        if (nrow(nests_last) > 0) {
            empty_links <- data.table(
                nest_id = character(),
                sex_key = character(),
                mark = character()
            )
            last_links <- rbindlist(
                lapply(c("M", "F"), function(sex_key) {
                    col <- paste0(sex_key, "_mark")
                    if (!col %in% names(nests_last)) {
                        return(empty_links)
                    }
                    buf <- nests_last[, .(
                        nest_id,
                        sex_key = sex_key,
                        mark_blob = get(col)
                    )]
                    buf <- buf[
                        !is.na(mark_blob) &
                            nzchar((mark_blob |> as.character() |> str_trim()))
                    ]
                    if (nrow(buf) == 0) {
                        return(empty_links)
                    }
                    buf[, let(mark_list, lapply(mark_blob, split_marks))]
                    buf <- buf[lengths(mark_list) > 0]
                    if (nrow(buf) == 0) {
                        return(empty_links)
                    }
                    buf[, .(mark = unlist(mark_list)), by = .(nest_id, sex_key)]
                }),
                use.names = TRUE,
                fill = TRUE
            )
            last_links <- unique(last_links[!is.na(mark) & nzchar(mark)])
        } else {
            last_links <- data.table(
                nest_id = character(),
                sex_key = character(),
                mark = character()
            )
        }
        dat[, let(mark, mapply(make_mark, UL, LL, UR, LR, USE.NAMES = FALSE))]
        dat[, let(event_date, (date |> as.Date()))]
        dat[, let(event_time_key, "99:99")]
        dat[, let(age_key, (age |> as.character() |> str_trim()))]
        dat[, let(
            rclass_key,
            (rclass |> as.character() |> str_trim() |> toupper())
        )]
        dat[, let(behav_tokens, lapply(behav, parse_behav))]
        dat[, let(is_chick, !is.na(age_key) & age_key == "C")]
        parent_behav_codes <- c("IN", "NM", "BW", "BC", "FC", "AC")
        dat[, let(
            is_parent_behaviour = !is.na(age_key) &
                age_key == "A" &
                vapply(
                    behav_tokens,
                    function(tok) {
                        any(tok %in% parent_behav_codes)
                    },
                    logical(1)
                )
        )]
        if (!"ring" %in% names(dat)) {
            dat[, let(ring, NA_character_)]
        }
        gps_id_key <- (dat$gps_id |> as.character() |> str_trim())
        gps_point_key <- (dat$gps_point |> as.character() |> str_trim())
        parent_same_gps <- vapply(
            seq_len(nrow(dat)),
            function(i) {
                if (
                    isTRUE(blank(dat$gps_id[i])) ||
                        isTRUE(blank(dat$gps_point[i]))
                ) {
                    return(FALSE)
                }
                any(
                    !is.na(dat$age) &
                        (dat$age |> as.character() |> str_trim()) == "A" &
                        !blank(dat$gps_id) &
                        !blank(dat$gps_point) &
                        !blank(dat$LL) &
                        !blank(dat$LR) &
                        gps_id_key == gps_id_key[i] &
                        gps_point_key == gps_point_key[i]
                )
            },
            logical(1)
        )
        dat[, let(parent_same_gps, parent_same_gps)]
        dat[, let(ring_present, !blank(ring))]
        dat[, let(
            allow_unlinked_h_chick = blank(nest_id) &
                rclass_key == "H" &
                age_key == "C" &
                !blank(gps_id) &
                !blank(gps_point) &
                (ring_present | parent_same_gps)
        )]
        dat[, let(
            needs_nest_id,
            (is_chick & !allow_unlinked_h_chick) | is_parent_behaviour
        )]
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                rec_is_chk <- isTRUE(rec$is_chick)
                rec_is_parent_behav <- isTRUE(rec$is_parent_behaviour)
                rec_is_h <- isTRUE(rec$rclass_key == "H")
                missing_chick_nest_reason <- if (rec_is_h) {
                    "H chick needs nest_id, ring, or a same-session adult with LL/LR at the same GPS pair."
                } else {
                    "Chick resightings must record nest_id."
                }
                missing_parent_nest_reason <- if (
                    any(rec$behav_tokens[[1]] %in% c("BC", "FC", "AC"))
                ) {
                    "Adult BC/FC/AC requires nest_id; after notA, enter both GPS fields."
                } else if (any(rec$behav_tokens[[1]] %in% "BW")) {
                    "Adult BW requires nest_id."
                } else {
                    "First adult IN/NM record requires nest_id."
                }
                if (!isTRUE(rec$needs_nest_id)) {
                    return(none)
                }
                if (
                    (is.na(rec$nest_id) ||
                        !nzchar(
                            (rec$nest_id |> as.character() |> str_trim())
                        )) &&
                        rec_is_chk
                ) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "nest_id",
                        reason = missing_chick_nest_reason
                    ))
                }
                if (
                    (is.na(rec$nest_id) ||
                        !nzchar(
                            (rec$nest_id |> as.character() |> str_trim())
                        )) &&
                        rec_is_parent_behav
                ) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "nest_id",
                        reason = missing_parent_nest_reason
                    ))
                }
                rec_nest <- (rec$nest_id |> as.character() |> str_trim())
                rec_has_real_nest <- !is.na(rec_nest) &&
                    nzchar(rec_nest) &&
                    !is_no_nest(rec_nest)
                rec_is_unbanded <- is_unbanded_resight(
                    rec$UL[[1]],
                    rec$LL[[1]],
                    rec$UR[[1]],
                    rec$LR[[1]]
                )
                if (rec_has_real_nest && rec_is_unbanded) {
                    return(none)
                }
                rec_mark <- clean_segment(rec$mark)
                rec_sex <- (rec$sex |> as.character() |> str_trim())
                if (
                    (!rec_has_real_nest) &&
                        (rec_is_unbanded ||
                            is.na(rec_mark) ||
                            !nzchar(rec_mark) ||
                            rec_mark == "X-X")
                ) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "nest_id",
                        reason = missing_parent_nest_reason
                    ))
                }
                sex_key_v <- substr(rec_sex, 1, 1)
                last_opts <- if (sex_key_v %in% c("M", "F")) {
                    unique(last_links[
                        sex_key == sex_key_v & mark == rec_mark,
                        nest_id
                    ])
                } else {
                    unique(last_links[mark == rec_mark, nest_id])
                }
                last_opts <- (last_opts |> as.character() |> str_trim())
                last_opts <- last_opts[
                    !is.na(last_opts) &
                        nzchar(last_opts) &
                        !is_no_nest(last_opts)
                ]
                linked_active <- length(last_opts) > 0 &&
                    any(vapply(
                        last_opts,
                        function(nk) {
                            is_active_link(
                                nk,
                                rec$event_date,
                                rec$event_time_key,
                                now_nests,
                                link_end_states
                            )
                        },
                        logical(1)
                    ))
                errs <- list()
                if (!rec_has_real_nest && rec_is_chk) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "nest_id",
                        reason = missing_chick_nest_reason
                    ))
                }
                if (!rec_has_real_nest && rec_is_parent_behav) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "nest_id",
                        reason = missing_parent_nest_reason
                    ))
                }
                if (!rec_has_real_nest) {
                    if (!linked_active) {
                        errs[[length(errs) + 1]] <- data.table(
                            rowid = rec$rowid,
                            variable = "nest_id",
                            reason = missing_parent_nest_reason
                        )
                    }
                }
                if (length(errs) == 0) {
                    none
                } else {
                    rbindlist(errs)
                }
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val27"),

    # Check incubation links against the latest nest state.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        parse_behav <- function(v) {
            if (is.na(v) || !nzchar((v |> as.character() |> str_trim()))) {
                character()
            } else {
                (unlist(
                    (v |>
                        as.character() |>
                        str_split(fixed(",")) |>
                        lapply(function(parts) {
                            if (identical(tail(parts, 1), "")) {
                                head(parts, -1)
                            } else {
                                parts
                            }
                        }))
                ) |>
                    str_trim())
            }
        }
        is_no_nest <- function(v) {
            !is.na(v) &
                (v |> as.character() |> str_trim() |> toupper()) == "NO_NEST"
        }
        nests_dt <- as.data.table(db_get(
            "SELECT nest_id, date, time_visit, nest_state, clutch_size, brood_size, pk FROM NESTS"
        ))
        if (nrow(nests_dt) > 0) {
            nests_dt[, let(event_date_nest, (date |> as.Date()))]
            nests_dt[, let(
                time_visit_key,
                (time_visit |> as.character() |> str_trim())
            )]
            nests_dt[
                is.na(time_visit_key) | !nzchar(time_visit_key),
                let(time_visit_key, "99:99")
            ]
            nests_dt[, let(
                clutch_num = (clutch_size |> as.character() |> as.numeric()),
                brood_num = (brood_size |> as.character() |> as.numeric()),
                pk_key = (pk |> as.character() |> as.numeric())
            )]
            nests_dt[is.na(pk_key), let(pk_key, -Inf)]
        } else {
            nests_dt <- data.table(
                nest_id = character(),
                nest_state = character(),
                event_date_nest = (character() |> as.Date()),
                time_visit_key = character(),
                clutch_num = numeric(),
                brood_num = numeric(),
                pk_key = numeric()
            )
        }
        dat[, let(event_date, (date |> as.Date()))]
        dat[, let(behav_tokens, lapply(behav, parse_behav))]
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                nest_key <- (rec$nest_id |> as.character() |> str_trim())
                if (
                    !identical((rec$age[[1]] |> as.character()), "A") ||
                        is.na(nest_key) ||
                        !nzchar(nest_key) ||
                        is_no_nest(nest_key) ||
                        (nest_key |> str_detect("^-")) %in% TRUE ||
                        is.na(rec$event_date) ||
                        !any(rec$behav_tokens[[1]] %in% c("IN", "NM"))
                ) {
                    return(none)
                }
                buf <- nests_dt[
                    nest_id == nest_key &
                        !is.na(event_date_nest) &
                        event_date_nest <= rec$event_date
                ]
                if (nrow(buf) == 0) {
                    return(none)
                }
                setorder(buf, event_date_nest, time_visit_key, pk_key)
                last_v <- buf[nrow(buf)]
                last_state <- (last_v$nest_state[[1]] |> as.character())
                if (!last_state %in% c("F", "I", "H")) {
                    data.table(
                        rowid = rec$rowid,
                        variable = "nest_id",
                        reason = "Adult IN/NM requires nest_id with latest state F, I, or H."
                    )
                } else {
                    none
                }
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val28"),

    # Require linked parent and chick observations.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        clean_vec <- function(v) {
            res <- (v |> as.character() |> str_trim() |> toupper())
            res[is.na(v) | !nzchar(res) | res == "NA"] <- NA_character_
            res
        }
        parse_behav <- function(v) {
            one <- clean_vec(v)
            if (is.na(one)) {
                character()
            } else {
                (unlist(
                    (one |>
                        str_split(fixed(",")) |>
                        lapply(function(parts) {
                            if (identical(tail(parts, 1), "")) {
                                head(parts, -1)
                            } else {
                                parts
                            }
                        }))
                ) |>
                    str_trim())
            }
        }
        is_linked_nest <- function(v) {
            !is.na(v) & nzchar(v) & v != "NO_NEST"
        }
        has_gps_pair <- function(id, point) {
            !is.na(id) & !is.na(point) & nzchar(id) & nzchar(point)
        }
        same_link <- function(rec, other) {
            same_date <- !is.na(rec$date_key[[1]]) &&
                !is.na(other$date_key) &&
                (rec$date_key[[1]] |> as.character()) ==
                    (other$date_key |> as.character())
            same_nest <- is_linked_nest(rec$nest_key[[1]]) &&
                is_linked_nest(other$nest_key) &&
                rec$nest_key[[1]] == other$nest_key
            same_gps <- has_gps_pair(
                rec$gps_id_key[[1]],
                rec$gps_point_key[[1]]
            ) &&
                has_gps_pair(
                    other$gps_id_key,
                    other$gps_point_key
                ) &&
                rec$gps_id_key[[1]] == other$gps_id_key &&
                rec$gps_point_key[[1]] == other$gps_point_key
            same_date && (same_nest || same_gps)
        }
        dat[, let(
            date_key = (date |> as.character() |> as.Date()),
            age_key = clean_vec(age),
            nest_key = clean_vec(nest_id),
            gps_id_key = clean_vec(gps_id),
            gps_point_key = clean_vec(gps_point),
            behav_tokens = lapply(
                behav,
                parse_behav
            )
        )]
        dat[, let(
            parent_with_chicks = !is.na(age_key) &
                age_key == "A" &
                vapply(
                    behav_tokens,
                    function(tkns) {
                        any(tkns %in% c("BC", "FC", "AC"))
                    },
                    logical(1)
                ),
            chick_event = !is.na(age_key) & age_key == "C"
        )]
        parents <- dat[parent_with_chicks & !is.na(date_key)]
        chks <- dat[chick_event & !is.na(date_key)]
        chunks <- list()
        if (nrow(chks) > 0) {
            blank_parent <- vapply(
                seq_len(nrow(chks)),
                function(i) {
                    !any(vapply(
                        seq_len(nrow(parents)),
                        function(j) same_link(chks[i], parents[j]),
                        logical(1)
                    ))
                },
                logical(1)
            )
            if (any(blank_parent)) {
                chunks[[length(chunks) + 1]] <- data.table(
                    rowid = chks$rowid[blank_parent],
                    variable = "age",
                    reason = "Add a same-session age-A BC/FC/AC parent with matching nest_id or GPS pair."
                )
            }
        }
        if (nrow(parents) > 0) {
            blank_chk <- vapply(
                seq_len(nrow(parents)),
                function(i) {
                    !any(vapply(
                        seq_len(nrow(chks)),
                        function(j) same_link(parents[i], chks[j]),
                        logical(1)
                    ))
                },
                logical(1)
            )
            if (any(blank_chk)) {
                chunks[[length(chunks) + 1]] <- data.table(
                    rowid = parents$rowid[blank_chk],
                    variable = "behav",
                    reason = "Add one class-R row per chick with observed band and the parent’s GPS pair; ring optional."
                )
            }
        }
        if (!length(chunks)) {
            none
        } else {
            unique(rbindlist(chunks, use.names = TRUE, fill = TRUE))
        }
    } |>
        try_validator(nam = "val29"),

    # Check brood links and GPS after nest closure.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        clean_vec <- function(v) {
            res <- (v |> as.character() |> str_trim() |> toupper())
            res[is.na(v) | !nzchar(res) | res == "NA"] <- NA_character_
            res
        }
        parse_behav <- function(v) {
            one <- clean_vec(v)
            if (is.na(one)) {
                character()
            } else {
                (unlist(
                    (one |>
                        str_split(fixed(",")) |>
                        lapply(function(parts) {
                            if (identical(tail(parts, 1), "")) {
                                head(parts, -1)
                            } else {
                                parts
                            }
                        }))
                ) |>
                    str_trim())
            }
        }
        is_pos_nest <- function(v) {
            !is.na(v) &
                nzchar(v) &
                v != "NO_NEST" &
                !(v |> str_detect("^-")) %in% TRUE
        }
        has_gps_pair <- function(id, point) {
            !is.na(id) & !is.na(point) & nzchar(id) & nzchar(point)
        }
        nests_dt <- as.data.table(db_get(
            "SELECT nest_id, date, time_visit, nest_state, brood_size, pk FROM NESTS"
        ))
        if (!nrow(nests_dt)) {
            none
        } else {
            nests_dt[, let(
                nest_key = clean_vec(nest_id),
                event_date_nest = (date |> as.character() |> as.Date()),
                time_visit_key = (time_visit |> as.character() |> str_trim()),
                pk_key = (pk |> as.character() |> as.numeric()),
                state_key = clean_vec(nest_state),
                brood_num = (brood_size |> as.character() |> as.numeric())
            )]
            nests_dt[
                is.na(time_visit_key) |
                    !nzchar(time_visit_key) |
                    time_visit_key == "NA",
                let(time_visit_key, "99:99:99")
            ]
            nests_dt[is.na(pk_key), let(pk_key, -Inf)]
            dat[, let(
                date_key = (date |> as.character() |> as.Date()),
                age_key = clean_vec(age),
                nest_key = clean_vec(nest_id),
                gps_id_key = clean_vec(gps_id),
                gps_point_key = clean_vec(gps_point),
                behav_tokens = lapply(
                    behav,
                    parse_behav
                )
            )]
            last_for <- function(nest_key, event_date) {
                if (!is_pos_nest(nest_key) || is.na(event_date)) {
                    return(NULL)
                }
                key_v <- nest_key
                buf <- nests_dt[
                    nest_key == key_v &
                        !is.na(event_date_nest) &
                        event_date_nest <= event_date
                ]
                if (!nrow(buf)) {
                    return(NULL)
                }
                setorder(buf, event_date_nest, time_visit_key, pk_key)
                buf[nrow(buf)]
            }
            chunks <- list()
            for (i in seq_len(nrow(dat))) {
                rec <- dat[i]
                if (
                    is.na(rec$date_key[[1]]) || !is_pos_nest(rec$nest_key[[1]])
                ) {
                    next
                }
                last_v <- last_for(rec$nest_key[[1]], rec$date_key[[1]])
                if (is.null(last_v)) {
                    next
                }
                state_key <- last_v$state_key[[1]]
                tkns <- rec$behav_tokens[[1]]
                if (
                    isTRUE(rec$age_key[[1]] == "A") &&
                        any(tkns %in% c("BC", "FC", "AC")) &&
                        !state_key %in% c("H", "NOTA")
                ) {
                    chunks[[length(chunks) + 1]] <- data.table(
                        rowid = rec$rowid,
                        variable = "nest_id",
                        reason = "BC/FC/AC requires nest_id with latest state H or notA."
                    )
                }
                mobile_brd <- state_key == "NOTA" &&
                    !is.na(last_v$brood_num[[1]]) &&
                    last_v$brood_num[[1]] > 0
                needs_mobile_gps <- mobile_brd &&
                    (isTRUE(rec$age_key[[1]] == "C") ||
                        (isTRUE(rec$age_key[[1]] == "A") &&
                            any(tkns %in% c("BW", "BC", "FC", "AC"))))
                if (
                    needs_mobile_gps &&
                        !has_gps_pair(
                            rec$gps_id_key[[1]],
                            rec$gps_point_key[[1]]
                        )
                ) {
                    if (
                        is.na(rec$gps_id_key[[1]]) ||
                            !nzchar(rec$gps_id_key[[1]])
                    ) {
                        chunks[[length(chunks) + 1]] <- data.table(
                            rowid = rec$rowid,
                            variable = "gps_id",
                            reason = "After notA, enter both GPS fields for parent/chick links."
                        )
                    }
                    if (
                        is.na(rec$gps_point_key[[1]]) ||
                            !nzchar(rec$gps_point_key[[1]])
                    ) {
                        chunks[[length(chunks) + 1]] <- data.table(
                            rowid = rec$rowid,
                            variable = "gps_point",
                            reason = "After notA, enter both GPS fields for parent/chick links."
                        )
                    }
                }
            }
            if (!length(chunks)) {
                none
            } else {
                unique(rbindlist(chunks, use.names = TRUE, fill = TRUE))
            }
        }
    } |>
        try_validator(nam = "val30"),

    # Check observations against earlier death records.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        clean_segment <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            txt[is.na(v) | !nzchar(txt) | txt == "NA"] <- NA_character_
            txt
        }
        clean_one <- function(v) {
            res <- clean_segment(v)
            res
        }
        clean_geo <- function(v) {
            txt <- clean_one(v)
            res <- txt
            tag_like <- !is.na(txt) &
                (txt |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (txt[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
        canon_left <- function(ul, ll) {
            ul1 <- clean_one(ul)
            ll1 <- clean_one(ll)
            ifelse(
                !is.na(ul1) &
                    (ul1 |> str_detect("^[RBGWOLY]$")) %in% TRUE &
                    !is.na(ll1) &
                    (ll1 |> str_detect("^[RBGWOLY]$")) %in%
                        TRUE,
                paste0(ul1, ll1),
                ifelse(
                    (is.na(ul1) | ul1 %in% c("X", "M")) &
                        !is.na(ll1) &
                        (ll1 |> str_detect("^[RBGWOLY]{2}$")) %in% TRUE,
                    ll1,
                    ifelse(
                        (is.na(ll1) | ll1 %in% c("X", "M")) &
                            !is.na(ul1) &
                            (ul1 |> str_detect("^[RBGWOLY]{2}$")) %in% TRUE,
                        ul1,
                        NA_character_
                    )
                )
            )
        }
        canon_right <- function(ur, lr) {
            ur1 <- clean_geo(ur)
            lr1 <- clean_one(lr)
            ifelse(
                !is.na(ur1) &
                    (ur1 |> str_detect("^T[RBGWOLY]$")) %in% TRUE &
                    !is.na(lr1) &
                    (lr1 |> str_detect("^[RBGWOLY]{2}$")) %in%
                        TRUE,
                lr1,
                ifelse(
                    !is.na(ur1) &
                        (ur1 |> str_detect("^T[RBGWOLY]$")) %in% TRUE &
                        !is.na(lr1) &
                        (lr1 |> str_detect("^[RBGWOLY]$")) %in% TRUE,
                    paste0((ur1 |> str_replace("^T", "")), lr1),
                    ifelse(
                        !is.na(ur1) &
                            (ur1 |> str_detect("^[RBGWOLY]$")) %in% TRUE &
                            !is.na(lr1) &
                            (lr1 |> str_detect("^[RBGWOLY]$")) %in% TRUE,
                        paste0(ur1, lr1),
                        ifelse(
                            (is.na(ur1) | ur1 %in% c("X", "M")) &
                                !is.na(lr1) &
                                (lr1 |> str_detect("^[RBGWOLY]{2}$")) %in%
                                    TRUE,
                            lr1,
                            ifelse(
                                (is.na(lr1) | lr1 %in% c("X", "M")) &
                                    !is.na(ur1) &
                                    (ur1 |> str_detect("^[RBGWOLY]{2}$")) %in%
                                        TRUE,
                                ur1,
                                NA_character_
                            )
                        )
                    )
                )
            )
        }
        raw_combo <- function(ul, ll, ur, lr) {
            ul1 <- clean_one(ul)
            ll1 <- clean_one(ll)
            ur1 <- clean_geo(ur)
            lr1 <- clean_one(lr)
            ifelse(
                is.na(ul1) | is.na(ll1) | is.na(ur1) | is.na(lr1),
                NA_character_,
                paste0(
                    ul1,
                    ll1,
                    ur1,
                    lr1
                )
            )
        }
        bird_id <- function(ul, ll, ur, lr) {
            left_pair <- canon_left(ul, ll)
            right_pair <- canon_right(ur, lr)
            canon <- ifelse(
                !is.na(left_pair) & !is.na(right_pair),
                paste0(
                    "X",
                    left_pair,
                    "X",
                    right_pair
                ),
                NA_character_
            )
            txt <- raw_combo(ul, ll, ur, lr)
            ifelse(!is.na(canon), canon, txt)
        }
        band_id <- function(dt) {
            mapply(bird_id, dt$UL, dt$LL, dt$UR, dt$LR, USE.NAMES = FALSE)
        }
        signature_tbl <- function(
            dt,
            ul_col = "UL",
            ll_col = "LL",
            ur_col = "UR",
            lr_col = "LR"
        ) {
            buf <- copy(dt)
            ul_vals <- buf[[ul_col]]
            ll_vals <- buf[[ll_col]]
            ur_vals <- buf[[ur_col]]
            lr_vals <- buf[[lr_col]]
            flag_ul <- clean_one(ul_vals)
            flag_ul[
                is.na(flag_ul) |
                    !(flag_ul |> str_detect("^F[A-Z0-9]+$")) %in% TRUE
            ] <- NA_character_
            flag_ur <- clean_one(ur_vals)
            flag_ur[
                is.na(flag_ur) |
                    !(flag_ur |> str_detect("^F[A-Z0-9]+$")) %in% TRUE
            ] <- NA_character_
            buf[, let(
                left_pair = canon_left(ul_vals, ll_vals),
                right_pair = canon_right(
                    ur_vals,
                    lr_vals
                ),
                flag_ul = flag_ul,
                flag_ur = flag_ur
            )]
            buf[, let(
                has_signature,
                !is.na(left_pair) |
                    !is.na(right_pair) |
                    !is.na(flag_ul) |
                    !is.na(flag_ur)
            )]
            buf
        }
        fits_marks <- function(rec, hist) {
            if (!nrow(hist) || !isTRUE(rec$has_signature[[1]])) {
                return(FALSE)
            }
            keep <- rep(TRUE, nrow(hist))
            if (!is.na(rec$left_pair[[1]])) {
                keep <- keep &
                    !is.na(hist$left_pair) &
                    hist$left_pair == rec$left_pair[[1]]
            }
            if (!is.na(rec$right_pair[[1]])) {
                keep <- keep &
                    !is.na(hist$right_pair) &
                    hist$right_pair == rec$right_pair[[1]]
            }
            if (!is.na(rec$flag_ul[[1]])) {
                keep <- keep &
                    !is.na(hist$flag_ul) &
                    hist$flag_ul == rec$flag_ul[[1]]
            }
            if (!is.na(rec$flag_ur[[1]])) {
                keep <- keep &
                    !is.na(hist$flag_ur) &
                    hist$flag_ur == rec$flag_ur[[1]]
            }
            any(keep)
        }
        dead_caps <- as.data.table(db_get(
            "SELECT date, capture_status, UL_in, LL_in, UR_in, LR_in FROM CAPTURES"
        ))
        if (nrow(dead_caps) == 0) {
            none
        } else {
            dead_caps <- dead_caps[capture_status == "D"]
            if (nrow(dead_caps) == 0) {
                none
            } else {
                dead_caps[, let(death_date = (date |> as.Date()))]
                dead_caps <- signature_tbl(
                    dead_caps,
                    ul_col = "UL_in",
                    ll_col = "LL_in",
                    ur_col = "UR_in",
                    lr_col = "LR_in"
                )
                dead_caps <- dead_caps[
                    !is.na(death_date) & !is.na(has_signature) & has_signature
                ]
                if (nrow(dead_caps) == 0) {
                    none
                } else {
                    dat <- signature_tbl(dat)
                    dat[, let(event_date, (date |> as.Date()))]
                    res <- rbindlist(
                        lapply(seq_len(nrow(dat)), function(i) {
                            rec <- dat[i]
                            rowid_val <- rec$rowid[[1]]
                            evt_date_v <- rec$event_date[[1]]
                            if (
                                is.na(evt_date_v) ||
                                    !isTRUE(rec$has_signature[[1]])
                            ) {
                                return(none)
                            }
                            if (
                                fits_marks(
                                    rec,
                                    dead_caps[death_date < evt_date_v]
                                )
                            ) {
                                data.table(
                                    rowid = rowid_val,
                                    variable = "UL",
                                    reason = "This combo was already recorded dead in CAPTURES before this resighting date."
                                )
                            } else {
                                none
                            }
                        }),
                        use.names = TRUE,
                        fill = TRUE
                    )
                    if (nrow(res) == 0) {
                        none
                    } else {
                        unique(res)
                    }
                }
            }
        }
    } |>
        try_validator(nam = "val31"),

    # rclass V, P, and H require cam_id, photo_start, and photo_end.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        is_set <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & txt != "NA"
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                pic_req <- !is.na(rec$rclass) &&
                    (rec$rclass |> as.character() |> str_trim()) %in%
                        c("V", "P", "H")
                has_cam <- is_set(rec$cam_id)
                has_start <- is_set(rec$photo_start)
                has_end <- is_set(rec$photo_end)
                all_set <- has_cam && has_start && has_end
                if (pic_req && !all_set) {
                    if (!has_cam) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "cam_id",
                            reason = "rclass V, P, and H require cam_id, photo_start, and photo_end."
                        ))
                    }
                }
                none
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val32"),

    # rclass V, P, and H require cam_id, photo_start, and photo_end.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        is_set <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & txt != "NA"
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                pic_req <- !is.na(rec$rclass) &&
                    (rec$rclass |> as.character() |> str_trim()) %in%
                        c("V", "P", "H")
                has_cam <- is_set(rec$cam_id)
                has_start <- is_set(rec$photo_start)
                has_end <- is_set(rec$photo_end)
                all_set <- has_cam && has_start && has_end
                if (pic_req && !all_set) {
                    if (!has_start) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "photo_start",
                            reason = "rclass V, P, and H require cam_id, photo_start, and photo_end."
                        ))
                    }
                }
                none
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val33"),

    # rclass V, P, and H require cam_id, photo_start, and photo_end.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        is_set <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & txt != "NA"
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                pic_req <- !is.na(rec$rclass) &&
                    (rec$rclass |> as.character() |> str_trim()) %in%
                        c("V", "P", "H")
                has_cam <- is_set(rec$cam_id)
                has_start <- is_set(rec$photo_start)
                has_end <- is_set(rec$photo_end)
                all_set <- has_cam && has_start && has_end
                if (pic_req && !all_set) {
                    if (!has_end) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "photo_end",
                            reason = "rclass V, P, and H require cam_id, photo_start, and photo_end."
                        ))
                    }
                }
                none
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val34"),

    # Enter cam_id, photo_start, and photo_end together.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        is_set <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & txt != "NA"
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                pic_req <- !is.na(rec$rclass) &&
                    (rec$rclass |> as.character() |> str_trim()) %in%
                        c("V", "P", "H")
                has_cam <- is_set(rec$cam_id)
                has_start <- is_set(rec$photo_start)
                has_end <- is_set(rec$photo_end)
                any_set <- has_cam || has_start || has_end
                all_set <- has_cam && has_start && has_end
                if (!(pic_req && !all_set)) {
                    if (any_set && !all_set) {
                        if (!has_cam) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "cam_id",
                                reason = "Enter cam_id, photo_start, and photo_end together."
                            ))
                        }
                    }
                }
                none
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val35"),

    # Enter cam_id, photo_start, and photo_end together.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        is_set <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & txt != "NA"
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                pic_req <- !is.na(rec$rclass) &&
                    (rec$rclass |> as.character() |> str_trim()) %in%
                        c("V", "P", "H")
                has_cam <- is_set(rec$cam_id)
                has_start <- is_set(rec$photo_start)
                has_end <- is_set(rec$photo_end)
                any_set <- has_cam || has_start || has_end
                all_set <- has_cam && has_start && has_end
                if (!(pic_req && !all_set)) {
                    if (any_set && !all_set) {
                        if (!has_start) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "photo_start",
                                reason = "Enter cam_id, photo_start, and photo_end together."
                            ))
                        }
                    }
                }
                none
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val36"),

    # Enter cam_id, photo_start, and photo_end together.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        is_set <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & txt != "NA"
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                pic_req <- !is.na(rec$rclass) &&
                    (rec$rclass |> as.character() |> str_trim()) %in%
                        c("V", "P", "H")
                has_cam <- is_set(rec$cam_id)
                has_start <- is_set(rec$photo_start)
                has_end <- is_set(rec$photo_end)
                any_set <- has_cam || has_start || has_end
                all_set <- has_cam && has_start && has_end
                if (!(pic_req && !all_set)) {
                    if (any_set && !all_set) {
                        if (!has_end) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "photo_end",
                                reason = "Enter cam_id, photo_start, and photo_end together."
                            ))
                        }
                    }
                }
                none
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val37"),

    # End photo filenames with digits.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        pic_no <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            res <- rep(NA_integer_, length(txt))
            valid <- !is.na(txt) & nzchar(txt) & txt != "NA"
            if (!any(valid)) {
                return(res)
            }
            roll_ok <- valid &
                (txt |> str_detect("([0-9]+)-([0-9]{4})$")) %in% TRUE
            if (any(roll_ok)) {
                res[roll_ok] <- (txt[roll_ok] |>
                    str_replace("^.*?([0-9]+)-([0-9]{4})$", "\\1") |>
                    as.integer()) *
                    10000 +
                    (txt[roll_ok] |>
                        str_replace("^.*?([0-9]+)-([0-9]{4})$", "\\2") |>
                        as.integer())
            }
            suffix_ok <- valid &
                !roll_ok &
                (txt |> str_detect("\\d+$")) %in% TRUE
            if (any(suffix_ok)) {
                res[suffix_ok] <- (txt[suffix_ok] |>
                    str_replace("^.*?(\\d+)$", "\\1") |>
                    as.integer())
            }
            res
        }
        is_set <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & txt != "NA"
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                has_cam <- is_set(rec$cam_id)
                has_start <- is_set(rec$photo_start)
                has_end <- is_set(rec$photo_end)
                all_set <- has_cam && has_start && has_end
                if (all_set) {
                    start_no <- pic_no(rec$photo_start)
                    end_no <- pic_no(rec$photo_end)
                    if (is.na(start_no) || is.na(end_no)) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "photo_start",
                            reason = "End photo filenames with digits."
                        ))
                    }
                }
                none
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val38"),

    # photo_end must not precede photo_start.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        pic_no <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            res <- rep(NA_integer_, length(txt))
            valid <- !is.na(txt) & nzchar(txt) & txt != "NA"
            if (!any(valid)) {
                return(res)
            }
            roll_ok <- valid &
                (txt |> str_detect("([0-9]+)-([0-9]{4})$")) %in% TRUE
            if (any(roll_ok)) {
                res[roll_ok] <- (txt[roll_ok] |>
                    str_replace("^.*?([0-9]+)-([0-9]{4})$", "\\1") |>
                    as.integer()) *
                    10000 +
                    (txt[roll_ok] |>
                        str_replace("^.*?([0-9]+)-([0-9]{4})$", "\\2") |>
                        as.integer())
            }
            suffix_ok <- valid &
                !roll_ok &
                (txt |> str_detect("\\d+$")) %in% TRUE
            if (any(suffix_ok)) {
                res[suffix_ok] <- (txt[suffix_ok] |>
                    str_replace("^.*?(\\d+)$", "\\1") |>
                    as.integer())
            }
            res
        }
        is_set <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & txt != "NA"
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                has_cam <- is_set(rec$cam_id)
                has_start <- is_set(rec$photo_start)
                has_end <- is_set(rec$photo_end)
                all_set <- has_cam && has_start && has_end
                if (all_set) {
                    start_no <- pic_no(rec$photo_start)
                    end_no <- pic_no(rec$photo_end)
                    if (!(is.na(start_no) || is.na(end_no))) {
                        if (start_no > end_no) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "photo_end",
                                reason = "photo_end must not precede photo_start."
                            ))
                        }
                    }
                }
                none
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val39"),

    # Check photo ranges for reuse.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        clean_pic <- function(v) {
            txt <- (v |> as.character() |> str_trim() |> toupper())
            txt[is.na(v) | !nzchar(txt) | txt == "NA"] <- NA_character_
            txt
        }
        spread_pics <- function(dt, table_name, rowid_col = "rowid") {
            if (nrow(dt) == 0) {
                return(data.table(
                    table_name = character(),
                    rowid = integer(),
                    photo_no = integer(),
                    cam_key = character(),
                    date_key = character(),
                    observer_key = character(),
                    nest_key = character(),
                    gps_id_key = character(),
                    gps_point_key = character(),
                    rclass_key = character(),
                    age_key = character(),
                    pk_key = character()
                ))
            }
            pic_no <- function(v) {
                txt <- (v |>
                    as.character() |>
                    str_trim() |>
                    str_replace("\\.[A-Za-z0-9]{1,5}$", ""))
                res <- rep(NA_integer_, length(txt))
                valid <- !is.na(txt) & nzchar(txt) & txt != "NA"
                if (!any(valid)) {
                    return(res)
                }
                roll_ok <- valid &
                    (txt |> str_detect("([0-9]+)-([0-9]{4})$")) %in% TRUE
                if (any(roll_ok)) {
                    res[roll_ok] <- (txt[roll_ok] |>
                        str_replace("^.*?([0-9]+)-([0-9]{4})$", "\\1") |>
                        as.integer()) *
                        10000 +
                        (txt[roll_ok] |>
                            str_replace("^.*?([0-9]+)-([0-9]{4})$", "\\2") |>
                            as.integer())
                }
                suffix_ok <- valid &
                    !roll_ok &
                    (txt |> str_detect("\\d+$")) %in% TRUE
                if (any(suffix_ok)) {
                    res[suffix_ok] <- (txt[suffix_ok] |>
                        str_replace("^.*?(\\d+)$", "\\1") |>
                        as.integer())
                }
                res
            }
            buf <- copy(dt)
            if (!rowid_col %in% names(buf)) {
                buf[, let(rowid, .I)]
            } else if (rowid_col != "rowid") {
                buf[, let(rowid, get(rowid_col))]
            }
            for (fld in c(
                "cam_id",
                "date",
                "observer",
                "nest_id",
                "gps_id",
                "gps_point",
                "rclass",
                "age",
                "pk"
            )) {
                if (!fld %in% names(buf)) {
                    buf[, let((fld), NA_character_)]
                }
            }
            buf[, let(
                table_name = table_name,
                cam_key = clean_pic(cam_id),
                date_key = clean_pic(date),
                observer_key = clean_pic(observer),
                nest_key = clean_pic(nest_id),
                gps_id_key = clean_pic(gps_id),
                gps_point_key = clean_pic(gps_point),
                rclass_key = clean_pic(rclass),
                age_key = clean_pic(age),
                pk_key = clean_pic(pk)
            )]
            buf[, let(start_no, pic_no(photo_start))]
            buf[, let(end_no, pic_no(photo_end))]
            buf <- buf[!is.na(start_no) & !is.na(end_no) & start_no <= end_no]
            if (nrow(buf) == 0) {
                return(data.table(
                    table_name = character(),
                    rowid = integer(),
                    photo_no = integer(),
                    cam_key = character(),
                    date_key = character(),
                    observer_key = character(),
                    nest_key = character(),
                    gps_id_key = character(),
                    gps_point_key = character(),
                    rclass_key = character(),
                    age_key = character(),
                    pk_key = character()
                ))
            }
            bits <- lapply(seq_len(nrow(buf)), function(i) {
                data.table(
                    table_name = buf$table_name[i],
                    rowid = buf$rowid[i],
                    photo_no = seq.int(
                        buf$start_no[i],
                        buf$end_no[i]
                    ),
                    cam_key = buf$cam_key[i],
                    date_key = buf$date_key[i],
                    observer_key = buf$observer_key[i],
                    nest_key = buf$nest_key[i],
                    gps_id_key = buf$gps_id_key[i],
                    gps_point_key = buf$gps_point_key[i],
                    rclass_key = buf$rclass_key[i],
                    age_key = buf$age_key[i],
                    pk_key = buf$pk_key[i]
                )
            })
            rbindlist(bits, use.names = TRUE, fill = TRUE)
        }
        same_pic_event <- function(a, b) {
            if (
                !identical(a$table_name[[1]], "RESIGHTINGS") ||
                    !identical(b$table_name[[1]], "RESIGHTINGS")
            ) {
                return(FALSE)
            }
            if (
                !identical(a$rclass_key[[1]], "H") ||
                    !identical(b$rclass_key[[1]], "H") ||
                    !identical(
                        a$age_key[[1]],
                        "C"
                    ) ||
                    !identical(b$age_key[[1]], "C")
            ) {
                return(FALSE)
            }
            if (
                any(is.na(c(
                    a$cam_key[[1]],
                    b$cam_key[[1]],
                    a$date_key[[1]],
                    b$date_key[[1]]
                )))
            ) {
                return(FALSE)
            }
            if (
                !identical(a$cam_key[[1]], b$cam_key[[1]]) ||
                    !identical(a$date_key[[1]], b$date_key[[1]])
            ) {
                return(FALSE)
            }
            nest_full <- !is.na(a$nest_key[[1]]) && !is.na(b$nest_key[[1]])
            if (nest_full) {
                return(identical(a$nest_key[[1]], b$nest_key[[1]]))
            }
            gps_full <- !is.na(a$gps_id_key[[1]]) &&
                !is.na(b$gps_id_key[[1]]) &&
                !is.na(a$gps_point_key[[1]]) &&
                !is.na(b$gps_point_key[[1]])
            gps_full &&
                identical(a$gps_id_key[[1]], b$gps_id_key[[1]]) &&
                identical(
                    a$gps_point_key[[1]],
                    b$gps_point_key[[1]]
                )
        }
        pic_conflict <- function(a, b) {
            same_saved_rec <- !is.na(a$pk_key[[1]]) &&
                !is.na(b$pk_key[[1]]) &&
                identical(
                    a$table_name[[1]],
                    b$table_name[[1]]
                ) &&
                identical(a$pk_key[[1]], b$pk_key[[1]])
            if (same_saved_rec) {
                return(FALSE)
            }
            if (
                is.na(a$cam_key[[1]]) ||
                    is.na(b$cam_key[[1]]) ||
                    !identical(a$cam_key[[1]], b$cam_key[[1]]) ||
                    !identical(a$photo_no[[1]], b$photo_no[[1]])
            ) {
                return(FALSE)
            }
            !same_pic_event(a, b)
        }
        other_res <- as.data.table(db_get(
            "SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, rclass, age, photo_start, photo_end FROM RESIGHTINGS"
        ))
        other_caps <- as.data.table(db_get(
            "SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, age, photo_start, photo_end FROM CAPTURES"
        ))
        other_nests <- as.data.table(db_get(
            "SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, photo_start, photo_end FROM NESTS"
        ))
        now_wide <- spread_pics(dat, "RESIGHTINGS")
        other_res_wide <- spread_pics(
            other_res,
            "RESIGHTINGS",
            rowid_col = "missing_rowid"
        )
        other_caps_wide <- spread_pics(
            other_caps,
            "CAPTURES",
            rowid_col = "missing_rowid"
        )
        other_nests_wide <- spread_pics(
            other_nests,
            "NESTS",
            rowid_col = "missing_rowid"
        )
        batch_dups <- integer()
        if (nrow(now_wide) > 1) {
            for (i in seq_len(nrow(now_wide))) {
                hits <- which(
                    now_wide$photo_no == now_wide$photo_no[i] &
                        now_wide$rowid != now_wide$rowid[i]
                )
                if (length(hits) > 0) {
                    for (j in hits) {
                        if (pic_conflict(now_wide[i], now_wide[j])) {
                            batch_dups <- c(
                                batch_dups,
                                now_wide$rowid[i],
                                now_wide$rowid[j]
                            )
                        }
                    }
                }
            }
        }
        src <- rbindlist(
            list(other_res_wide, other_caps_wide, other_nests_wide),
            use.names = TRUE,
            fill = TRUE
        )
        stored_dups <- integer()
        if (nrow(src) > 0) {
            for (i in seq_len(nrow(now_wide))) {
                hits <- which(src$photo_no == now_wide$photo_no[i])
                if (length(hits) > 0) {
                    for (j in hits) {
                        if (pic_conflict(now_wide[i], src[j])) {
                            stored_dups <- c(stored_dups, now_wide$rowid[i])
                        }
                    }
                }
            }
        }
        flagged <- sort(unique(c(batch_dups, stored_dups)))
        if (length(flagged) == 0) {
            none
        } else {
            data.table(
                rowid = flagged,
                variable = "photo_start",
                reason = "Photo range overlaps another event; sharing allowed within one age-C H brood session."
            )
        }
    } |>
        try_validator(nam = "val40"),

    # Check observer initials.
    is.regexp_validator(
        x[, .(observer)],
        regexp = "^[A-Z0-9]{2,3}$",
        reason = "Use 2–3 uppercase letters or digits."
    ) |>
        try_validator(nam = "val41"),

    # Check gps_id is numeric.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat <- dat[
            !is.na(gps_id) & nzchar((gps_id |> as.character() |> str_trim()))
        ]
        dat[, let(
            gps_id,
            (gps_id |> as.character() |> str_trim() |> as.numeric())
        )]
        is.na_validator(
            dat[, .(rowid, gps_id)],
            reason = "GPS ID must be a positive whole number."
        )
    } |>
        try_validator(nam = "val42"),

    # Check the gps_id range.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat <- dat[
            !is.na(gps_id) & nzchar((gps_id |> as.character() |> str_trim()))
        ]
        dat[, let(
            gps_id,
            (gps_id |> as.character() |> str_trim() |> as.numeric())
        )]
        interval_validator(
            dat[, .(rowid, gps_id)],
            v = data.table(variable = "gps_id", lq = 1, uq = Inf),
            reason = "GPS ID must be a positive whole number."
        )
    } |>
        try_validator(nam = "val43"),

    # Require a whole number for gps_id.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat <- dat[
            !is.na(gps_id) & nzchar((gps_id |> as.character() |> str_trim()))
        ]
        dat[, let(
            gps_id,
            (gps_id |> as.character() |> str_trim() |> as.numeric())
        )]
        dat[
            !is.na(gps_id) & gps_id != floor(gps_id),
            .(
                rowid,
                variable = "gps_id",
                reason = "GPS ID must be a positive whole number."
            )
        ]
    } |>
        try_validator(nam = "val44"),

    # Check gps_point is numeric.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat <- dat[
            !is.na(gps_point) &
                nzchar((gps_point |> as.character() |> str_trim()))
        ]
        dat[, let(
            gps_point,
            (gps_point |> as.character() |> str_trim() |> as.numeric())
        )]
        is.na_validator(
            dat[, .(rowid, gps_point)],
            reason = "GPS point must be a positive whole number."
        )
    } |>
        try_validator(nam = "val45"),

    # Check the gps_point range.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat <- dat[
            !is.na(gps_point) &
                nzchar((gps_point |> as.character() |> str_trim()))
        ]
        dat[, let(
            gps_point,
            (gps_point |> as.character() |> str_trim() |> as.numeric())
        )]
        interval_validator(
            dat[, .(rowid, gps_point)],
            v = data.table(
                variable = "gps_point",
                lq = 1,
                uq = Inf
            ),
            reason = "GPS point must be a positive whole number."
        )
    } |>
        try_validator(nam = "val46"),

    # Require a whole number for gps_point.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat <- dat[
            !is.na(gps_point) &
                nzchar((gps_point |> as.character() |> str_trim()))
        ]
        dat[, let(
            gps_point,
            (gps_point |> as.character() |> str_trim() |> as.numeric())
        )]
        dat[
            !is.na(gps_point) & gps_point != floor(gps_point),
            .(
                rowid,
                variable = "gps_point",
                reason = "GPS point must be a positive whole number."
            )
        ]
    } |>
        try_validator(nam = "val47"),

    # Check date format.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        txt <- (dat$date |> as.character() |> str_trim())
        conv <- (txt |> as.Date(format = "%Y-%m-%d"))
        bad_idx <- which(
            !is.na(dat$date) &
                nzchar(txt) &
                (!(txt |> str_detect("^\\d{4}-\\d{2}-\\d{2}$")) %in% TRUE |
                    is.na(conv))
        )
        if (length(bad_idx) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "date",
                reason = "Use YYYY-MM-DD."
            )
        }
    } |>
        try_validator(nam = "val48"),

    # Check left tibia format.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is.regexp_validator(
            dat[, .(UL, rowid)],
            regexp = "^(X|[OYWBRGLM]{1,2}|F[OYWBRGLM][A-Z0-9]{2,3})$",
            reason = "Invalid left-tibia code."
        )
    } |>
        try_validator(nam = "val49"),

    # Check left tarsus format.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is.regexp_validator(
            dat[, .(LL, rowid)],
            regexp = "^(X|XX|[OYWBRGLM]{1,2})$",
            reason = "Invalid left-tarsus code."
        )
    } |>
        try_validator(nam = "val50"),

    # Check right tibia format.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is.regexp_validator(
            dat[, .(UR, rowid)],
            regexp = "^(X|[OYWBRGLM]{1,2}|T[A-Z0-9]{0,5}[RBGWOLY]|F[OYWBRGLM][A-Z0-9]{2,3})$",
            reason = "Invalid right-tibia code."
        )
    } |>
        try_validator(nam = "val51"),

    # Check right tarsus format.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is.regexp_validator(
            dat[, .(LR, rowid)],
            regexp = "^(X|XX|[OYWBRGLM]{1,2})$",
            reason = "Invalid right-tarsus code."
        )
    } |>
        try_validator(nam = "val52"),

    # Check behaviour tokens.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        allowed <- c(
            "IN",
            "CO",
            "PR",
            "BW",
            "BC",
            "AC",
            "NM",
            "SC",
            "FC",
            "FA",
            "FM",
            "FF",
            "RS",
            "LF",
            "AT",
            "FT",
            "OB"
        )
        txt <- (dat$behav |> as.character() |> str_trim())
        set_i <- which(!is.na(dat$behav) & nzchar(txt))
        bad_idx <- set_i[
            !vapply(
                (txt[set_i] |>
                    str_split(",") |>
                    lapply(function(parts) {
                        if (identical(tail(parts, 1), "")) {
                            head(parts, -1)
                        } else {
                            parts
                        }
                    })),
                FUN.VALUE = logical(1),
                FUN = function(tkns) {
                    tkns <- (tkns |> str_trim())
                    length(tkns) > 0 &&
                        all(nzchar(tkns)) &&
                        all(tkns %in% allowed)
                }
            )
        ]
        if (length(bad_idx) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "behav",
                reason = "Use valid comma-separated behaviour codes."
            )
        }
    } |>
        try_validator(nam = "val53"),

    # Check camera id format.
    is.regexp_validator(
        x[, .(cam_id)],
        regexp = "^[A-Za-z0-9]{2,3}$",
        reason = "Use a valid 2–3-character camera ID."
    ) |>
        try_validator(nam = "val54"),

    # Check photo filename format.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        set_v <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            !is.na(v) & nzchar(txt) & txt != "NA"
        }
        filename_ok <- function(v) {
            (v |>
                as.character() |>
                str_trim() |>
                str_detect(regex("^[A-Za-z0-9._-]+$", dotall = TRUE))) %in%
                TRUE
        }
        res <- rbindlist(
            lapply(c("photo_start", "photo_end"), function(col) {
                bad_idx <- which(set_v(dat[[col]]) & !filename_ok(dat[[col]]))
                if (length(bad_idx) == 0) {
                    return(NULL)
                }
                data.table(
                    rowid = dat$rowid[bad_idx],
                    variable = col,
                    reason = "Invalid photo filename."
                )
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (is.null(res) || nrow(res) == 0) {
            none
        } else {
            res
        }
    } |>
        try_validator(nam = "val55"),

    # Check hiding-photo chick ring format.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        if (!"rclass" %in% names(dat)) {
            dat[, let(rclass, NA_character_)]
        }
        if (!"ring" %in% names(dat)) {
            dat[, let(ring, NA_character_)]
        }
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        ring_key <- (dat$ring |> as.character() |> str_trim() |> toupper())
        blank_ring <- is.na(dat$ring) |
            is.na(ring_key) |
            !nzchar(ring_key) |
            ring_key == "NA"
        bad_idx <- which(
            !is.na(rclass_key) &
                rclass_key == "H" &
                !blank_ring &
                !(ring_key |> str_detect("^CP-?[0-9]{5}$")) %in%
                    TRUE
        )
        if (length(bad_idx) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "ring",
                reason = "H chick ring: CP plus 5 digits, optional dash."
            )
        }
    } |>
        try_validator(nam = "val56"),

    # Match hiding-photo chick rings to captures.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        if (!"rclass" %in% names(dat)) {
            dat[, let(rclass, NA_character_)]
        }
        if (!"ring" %in% names(dat)) {
            dat[, let(ring, NA_character_)]
        }
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        rclass_key <- (dat$rclass |> as.character() |> str_trim() |> toupper())
        ring_key <- (dat$ring |> as.character() |> str_trim() |> toupper())
        blank_ring <- is.na(dat$ring) |
            is.na(ring_key) |
            !nzchar(ring_key) |
            ring_key == "NA"
        ok_h <- !is.na(rclass_key) &
            rclass_key == "H" &
            !blank_ring &
            (ring_key |> str_detect("^CP-?[0-9]{5}$")) %in%
                TRUE
        if (!any(ok_h)) {
            none
        } else {
            caught_v <- tryCatch(
                as.data.table(db_get(
                    "SELECT ring, UL, LL, UR, LR FROM CAPTURES"
                )),
                error = function(e) NULL
            )
            if (is.null(caught_v) || !"ring" %in% names(caught_v)) {
                dat[
                    ok_h,
                    .(
                        rowid,
                        variable = "ring",
                        reason = "H chick ring unverified; use a CP ring recorded in CAPTURES."
                    )
                ]
            } else {
                caught_key_a <- (caught_v$ring |>
                    as.character() |>
                    str_trim() |>
                    toupper())
                caught_key_a <- (caught_key_a |> str_replace("^CP-", "CP"))
                caught_key_a <- caught_key_a[
                    !is.na(caught_key_a) &
                        nzchar(caught_key_a) &
                        caught_key_a != "NA"
                ]
                set_key <- (ring_key |> str_replace("^CP-", "CP"))
                blank_hist <- ok_h & !(set_key %in% unique(caught_key_a))
                dat[
                    blank_hist,
                    .(
                        rowid,
                        variable = "ring",
                        reason = "H chick ring missing from CAPTURES; check ring or add capture."
                    )
                ]
            }
        }
    } |>
        try_validator(nam = "val57")
)
