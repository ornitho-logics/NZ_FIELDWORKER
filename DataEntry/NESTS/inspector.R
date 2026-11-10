list(
    # Required nest fields.
    is.na_validator(
        x[, .(species, site, date, time_visit, observer, nest_id, nest_state)],
        reason = "Required."
    ) |>
        try_validator(nam = "val1"),

    # Check species allowed codes.
    is.element_validator(
        x[, .(species)],
        v = data.table(
            variable = "species",
            set = list(c(
                "BADO",
                "WRYB"
            ))
        ),
        reason = "Invalid code."
    ) |>
        try_validator(nam = "val2"),

    # Check site allowed codes.
    is.element_validator(
        x[, .(site)],
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
        reason = "Invalid code."
    ) |>
        try_validator(nam = "val3"),

    # Check nest state allowed codes.
    is.element_validator(
        x[, .(nest_state)],
        v = data.table(
            variable = "nest_state",
            set = list(c(
                "S",
                "F",
                "I",
                "H",
                "pP",
                "pD",
                "P",
                "D",
                "notA",
                "O"
            ))
        ),
        reason = "Invalid code."
    ) |>
        try_validator(nam = "val4"),

    # Check bird inc allowed codes.
    is.element_validator(
        x[, .(bird_inc)],
        v = data.table(
            variable = "bird_inc",
            set = list(c(
                "M",
                "F",
                "FM",
                "MF",
                "U",
                "E"
            ))
        ),
        reason = "Invalid code."
    ) |>
        try_validator(nam = "val5"),

    # Check nest photo allowed codes.
    is.element_validator(
        x[, .(nest_photo)],
        v = data.table(
            variable = "nest_photo",
            set = list(c(
                "0",
                "1"
            ))
        ),
        reason = "Invalid code."
    ) |>
        try_validator(nam = "val6"),

    # Check tent photo allowed codes.
    is.element_validator(
        x[, .(tent_photo)],
        v = data.table(
            variable = "tent_photo",
            set = list(c(
                "0",
                "1"
            ))
        ),
        reason = "Invalid code."
    ) |>
        try_validator(nam = "val7"),

    # Check other state comment.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        dat <- copy(x)
        dat[, let(rowid, .I)]
        state_key <- (dat$nest_state |> as.character() |> str_trim())
        comment_key <- (dat$comments |> as.character() |> str_trim())
        comment_key[is.na(dat$comments) | comment_key == "NA"] <- ""
        bad_idx <- which(state_key == "O" & !nzchar(comment_key))
        if (length(bad_idx) == 0) {
            none
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "comments",
                reason = "nest_state O requires a comment describing the observation."
            )
        }
    } |>
        try_validator(nam = "val8"),

    # Check observer initials.
    is.regexp_validator(
        x[, .(observer)],
        regexp = "^[A-Z0-9]{2,3}$",
        reason = "Use 2–3 uppercase letters or digits."
    ) |>
        try_validator(nam = "val9"),

    # Check observer active.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        dat <- copy(x)
        dat[, let(rowid, .I)]
        obs <- tryCatch(
            db_get("SELECT observer, START, STOP FROM OBSERVERS"),
            error = function(e) NULL
        )
        if (is.null(obs) || nrow(obs) == 0) {
            none
        } else {
            obs <- as.data.table(obs)
            obs[, let(observer, (observer |> as.character() |> str_trim()))]
            obs[, let(START, (START |> as.Date()))]
            obs[, let(STOP, (STOP |> as.Date()))]
            zz <- dat[, .(
                rowid,
                observer = (observer |> as.character() |> str_trim()),
                date = (date |> as.Date())
            )]
            merged <- merge(
                zz,
                obs,
                by = "observer",
                all.x = TRUE,
                allow.cartesian = TRUE
            )
            res <- merged[
                !is.na(date) &
                    (is.na(observer) |
                        observer == "" |
                        is.na(START) |
                        is.na(STOP) |
                        date < START |
                        date > STOP),
                .(
                    rowid,
                    variable = "observer",
                    reason = "Observer missing or inactive on visit date."
                )
            ][,
                unique(.SD)
            ]
            if (nrow(res) == 0) {
                none
            } else {
                res
            }
        }
    } |>
        try_validator(nam = "val10"),

    # Check hatch state clutch count.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        hatch_n <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            if (is.na(v) || !nzchar(txt) || (txt |> toupper()) == "NA") {
                return(NA_integer_)
            }
            tkns <- str_extract_all(txt, "([1-4])(CC|C|S|N)")[[1]]
            if (length(tkns) == 0 || paste0(tkns, collapse = "") != txt) {
                return(NA_integer_)
            }
            sum(
                (tkns |>
                    str_replace(regex("(\\d).*", dotall = TRUE), "\\1") |>
                    as.integer())
            )
        }
        clutch_num <- (dat$clutch_size |> as.character() |> as.numeric())
        hatch_total <- vapply(dat$hatch_state, hatch_n, integer(1))
        bad_idx <- which(
            !is.na(hatch_total) &
                !is.na(clutch_num) &
                clutch_num >= 0 &
                hatch_total > clutch_num
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
                variable = "hatch_state",
                reason = paste0(
                    "hatch_state describes ",
                    hatch_total[bad_idx],
                    " egg(s), but clutch_size is ",
                    clutch_num[bad_idx],
                    ". Check counts; C = cracked egg, not chick."
                )
            )
        }
    } |>
        try_validator(nam = "val11"),

    # Check that the GPS pair has been uploaded.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
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
        try_validator(nam = "val12"),

    # Check date season.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        txt <- (dat$date |> as.character() |> str_trim())
        conv <- (txt |> as.Date(format = "%Y-%m-%d"))
        bad_idx <- which(
            !is.na(dat$date) &
                nzchar(txt) &
                (!(txt |> str_detect("^\\d{4}-\\d{2}-\\d{2}$")) %in% TRUE |
                    is.na(conv) |
                    conv < ("2026-07-01" |> as.Date()) |
                    conv > ("2027-07-31" |> as.Date()))
        )
        if (length(bad_idx) == 0) {
            none
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "date",
                reason = "Use YYYY-MM-DD within the 2026–2027 season."
            )
        }
    } |>
        try_validator(nam = "val13"),

    # Check time format.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        txt <- (dat$time_visit |> as.character() |> str_trim())
        conv <- strptime(txt, format = "%H:%M")
        bad_idx <- which(
            !is.na(dat$time_visit) &
                nzchar(txt) &
                (!(txt |> str_detect("^\\d{2}:\\d{2}$")) %in% TRUE |
                    is.na(conv))
        )
        if (length(bad_idx) == 0) {
            none
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "time_visit",
                reason = "Use hh:mm."
            )
        }
    } |>
        try_validator(nam = "val14"),

    # Check nest id pattern.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        cr_pat <- "^[ABC](0[1-9]|[1-9][0-9])(0[1-9]|[1-9][0-9])$"
        cr_wryb_pat <- "^WR(0[1-9]|[1-9][0-9])(0[1-9]|[1-9][0-9])$"
        noncr_bado_pat <- "^BA(0[1-9]|[1-9][0-9])(0[1-9]|[1-9][0-9])$"
        txt <- (dat$nest_id |> as.character() |> str_trim())
        nest_key <- (txt |> toupper())
        site_key <- (dat$site |> as.character() |> str_trim() |> toupper())
        species_key <- (dat$species |>
            as.character() |>
            str_trim() |>
            toupper())
        set_i <- !is.na(dat$nest_id) & nzchar(txt) & (txt |> toupper()) != "NA"
        neg_i <- set_i & startsWith(txt, "-")
        wr_species_bad <- set_i &
            !neg_i &
            (nest_key |> str_detect("^WR")) %in% TRUE &
            !is.na(species_key) &
            nzchar(species_key) &
            species_key != "WRYB"
        bado_species_bad <- set_i &
            !neg_i &
            (nest_key |> str_detect("^(A|B|C|BA)")) %in% TRUE &
            !is.na(species_key) &
            nzchar(species_key) &
            species_key != "BADO"
        prefix_species_bad <- wr_species_bad | bado_species_bad
        cr_ok <- ifelse(
            species_key == "WRYB",
            (txt |> str_detect(cr_wryb_pat)) %in% TRUE,
            (txt |> str_detect(cr_pat)) %in%
                TRUE
        )
        syntax_bad <- set_i &
            !neg_i &
            !prefix_species_bad &
            ((site_key == "CR" &
                !cr_ok) |
                (site_key != "CR" &
                    species_key == "BADO" &
                    !(txt |> str_detect(noncr_bado_pat)) %in%
                        TRUE))
        bad_idx <- which(set_i & (neg_i | prefix_species_bad | syntax_bad))
        if (length(bad_idx) == 0) {
            none
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = ifelse(
                    wr_species_bad[bad_idx] | bado_species_bad[bad_idx],
                    "species",
                    "nest_id"
                ),
                reason = ifelse(
                    neg_i[bad_idx],
                    "Negative nest_id is invalid in NESTS; use CAPTURES or RESIGHTINGS.",
                    ifelse(
                        wr_species_bad[bad_idx],
                        "nest_id values beginning with WR are WRYB nest_id values. Set species to WRYB.",
                        ifelse(
                            bado_species_bad[bad_idx],
                            "nest_id values beginning with A, B, C, or BA are BADO nest_id values. Set species to BADO.",
                            ifelse(
                                site_key[bad_idx] == "CR" &
                                    species_key[bad_idx] == "WRYB",
                                "Cass River WRYB nest_id must use WR + gps_id + sequence, e.g. WR0201.",
                                ifelse(
                                    site_key[bad_idx] == "CR",
                                    "Cass River BADO nest_id must use plot + gps_id + sequence, e.g. B0112.",
                                    "Non-CR BADO nest_id must use BA + gps_id + sequence, e.g. BA0804."
                                )
                            )
                        )
                    )
                )
            )
        }
    } |>
        try_validator(nam = "val15"),

    # Check hatch state format.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        hatch_parts <- function(v) {
            s <- (v |> as.character() |> str_trim())
            if (is.na(s) || !nzchar(s)) {
                return(NULL)
            }
            toks <- str_extract_all(s, "([1-4])(CC|C|S|N)")[[1]]
            if (length(toks) == 0 || paste0(toks, collapse = "") != s) {
                return(list(valid = FALSE))
            }
            states <- (toks |> str_replace("^[1-4]", ""))
            states_norm <- ifelse(states == "CC", "C", states)
            counts <- (toks |>
                str_replace(regex("(\\d).*", dotall = TRUE), "\\1") |>
                as.integer())
            list(
                valid = TRUE,
                C = sum(counts[states_norm == "C"]),
                S = sum(counts[states_norm == "S"]),
                N = sum(counts[states_norm == "N"]),
                total = sum(counts),
                max_stage = if (any(states_norm == "C")) {
                    3
                } else if (any(states_norm == "S")) {
                    2
                } else {
                    1
                }
            )
        }
        res <- dat[,
            {
                p <- hatch_parts(hatch_state)
                if (is.null(p) || isTRUE(p$valid)) {
                    NULL
                } else {
                    data.table(
                        rowid = rowid,
                        variable = "hatch_state",
                        reason = "Use positive counts followed by C, S, N, or CC, in any order."
                    )
                }
            },
            by = rowid
        ]
        if (is.null(res) || nrow(res) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            res
        }
    } |>
        try_validator(nam = "val16"),

    # Check gps_id is numeric.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
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
        try_validator(nam = "val17"),

    # Check the gps_id range.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
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
        try_validator(nam = "val18"),

    # Require a whole number for gps_id.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
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
        try_validator(nam = "val19"),

    # Check gps_point is numeric.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
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
        try_validator(nam = "val20"),

    # Check the gps_point range.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
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
        try_validator(nam = "val21"),

    # Require a whole number for gps_point.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
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
        try_validator(nam = "val22"),

    # Check clutch_size is numeric.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat <- dat[
            !is.na(clutch_size) &
                nzchar((clutch_size |> as.character() |> str_trim()))
        ]
        dat[, let(
            clutch_size,
            (clutch_size |> as.character() |> str_trim() |> as.numeric())
        )]
        is.na_validator(
            dat[, .(rowid, clutch_size)],
            reason = "Use a non-negative integer."
        )
    } |>
        try_validator(nam = "val23"),

    # Check the clutch_size range.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat <- dat[
            !is.na(clutch_size) &
                nzchar((clutch_size |> as.character() |> str_trim()))
        ]
        dat[, let(
            clutch_size,
            (clutch_size |> as.character() |> str_trim() |> as.numeric())
        )]
        interval_validator(
            dat[, .(rowid, clutch_size)],
            v = data.table(
                variable = "clutch_size",
                lq = 0,
                uq = Inf
            ),
            reason = "Use a non-negative integer."
        )
    } |>
        try_validator(nam = "val24"),

    # Require a whole number for clutch_size.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat <- dat[
            !is.na(clutch_size) &
                nzchar((clutch_size |> as.character() |> str_trim()))
        ]
        dat[, let(
            clutch_size,
            (clutch_size |> as.character() |> str_trim() |> as.numeric())
        )]
        dat[
            !is.na(clutch_size) & clutch_size != floor(clutch_size),
            .(
                rowid,
                variable = "clutch_size",
                reason = "Use a non-negative integer."
            )
        ]
    } |>
        try_validator(nam = "val25"),

    # Check brood_size is numeric.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat <- dat[
            !is.na(brood_size) &
                nzchar((brood_size |> as.character() |> str_trim()))
        ]
        dat[, let(
            brood_size,
            (brood_size |> as.character() |> str_trim() |> as.numeric())
        )]
        is.na_validator(
            dat[, .(rowid, brood_size)],
            reason = "Use a non-negative integer."
        )
    } |>
        try_validator(nam = "val26"),

    # Check the brood_size range.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat <- dat[
            !is.na(brood_size) &
                nzchar((brood_size |> as.character() |> str_trim()))
        ]
        dat[, let(
            brood_size,
            (brood_size |> as.character() |> str_trim() |> as.numeric())
        )]
        interval_validator(
            dat[, .(rowid, brood_size)],
            v = data.table(
                variable = "brood_size",
                lq = 0,
                uq = Inf
            ),
            reason = "Use a non-negative integer."
        )
    } |>
        try_validator(nam = "val27"),

    # Require a whole number for brood_size.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat <- dat[
            !is.na(brood_size) &
                nzchar((brood_size |> as.character() |> str_trim()))
        ]
        dat[, let(
            brood_size,
            (brood_size |> as.character() |> str_trim() |> as.numeric())
        )]
        dat[
            !is.na(brood_size) & brood_size != floor(brood_size),
            .(
                rowid,
                variable = "brood_size",
                reason = "Use a non-negative integer."
            )
        ]
    } |>
        try_validator(nam = "val28"),

    # Check brood requires clutch.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) == "NA"
        }
        brd_set <- !blank(dat$brood_size)
        clutch_blank <- blank(dat$clutch_size)
        bad_idx <- which(brd_set & clutch_blank)
        if (length(bad_idx) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "clutch_size",
                reason = "brood_size requires clutch_size; use 0 if no eggs remain."
            )
        }
    } |>
        try_validator(nam = "val29"),

    # Check hatch state for brood.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        clutch_num <- (dat$clutch_size |> as.character() |> as.numeric())
        brood_num <- (dat$brood_size |> as.character() |> as.numeric())
        state_key <- (dat$nest_state |> as.character() |> str_trim())
        bad_idx <- which(
            !is.na(clutch_num) &
                clutch_num == 0 &
                !is.na(brood_num) &
                brood_num > 0 &
                state_key == "I"
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
                variable = "nest_state",
                reason = "No eggs with chicks present requires nest_state H."
            )
        }
    } |>
        try_validator(nam = "val30"),

    # Check camera id.
    is.regexp_validator(
        x[, .(cam_id)],
        regexp = "^[A-Za-z0-9]{2,3}$",
        reason = "Use a valid 2–3-character camera ID."
    ) |>
        try_validator(nam = "val31"),

    # Check photo filename photo start.
    is.regexp_validator(
        x[, .(photo_start)],
        regexp = "^[A-Za-z0-9._-]+$",
        reason = "Invalid photo filename."
    ) |>
        try_validator(nam = "val32"),

    # Check photo filename photo end.
    is.regexp_validator(
        x[, .(photo_end)],
        regexp = "^[A-Za-z0-9._-]+$",
        reason = "Invalid photo filename."
    ) |>
        try_validator(nam = "val33"),

    # cam_id is required when nest_photo or tent_photo is 1.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        one_txt <- function(v) {
            txt <- (v[[1]] |> as.character() |> str_trim())
            if (
                length(txt) == 0 || is.na(v[[1]]) || !nzchar(txt) || txt == "NA"
            ) {
                NA_character_
            } else {
                txt
            }
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                errs <- list()
                nest_pic_yes <- identical(one_txt(rec$nest_photo), "1")
                tent_pic_yes <- identical(one_txt(rec$tent_photo), "1")
                any_yes <- nest_pic_yes || tent_pic_yes
                has_cam <- !is.na(one_txt(rec$cam_id))
                if (any_yes) {
                    if (!has_cam) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "cam_id",
                            reason = "cam_id is required when nest_photo or tent_photo is 1."
                        ))
                    }
                }
                if (!length(errs) == 0) {
                    rbindlist(errs, use.names = TRUE, fill = TRUE)
                }
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (is.null(res) || nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val34"),

    # photo_start is required when nest_photo or tent_photo is 1.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        one_txt <- function(v) {
            txt <- (v[[1]] |> as.character() |> str_trim())
            if (
                length(txt) == 0 || is.na(v[[1]]) || !nzchar(txt) || txt == "NA"
            ) {
                NA_character_
            } else {
                txt
            }
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                errs <- list()
                nest_pic_yes <- identical(one_txt(rec$nest_photo), "1")
                tent_pic_yes <- identical(one_txt(rec$tent_photo), "1")
                any_yes <- nest_pic_yes || tent_pic_yes
                has_start <- !is.na(one_txt(rec$photo_start))
                if (any_yes) {
                    if (!has_start) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "photo_start",
                            reason = "photo_start is required when nest_photo or tent_photo is 1."
                        ))
                    }
                }
                if (!length(errs) == 0) {
                    rbindlist(errs, use.names = TRUE, fill = TRUE)
                }
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (is.null(res) || nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val35"),

    # photo_end is required when nest_photo or tent_photo is 1.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        one_txt <- function(v) {
            txt <- (v[[1]] |> as.character() |> str_trim())
            if (
                length(txt) == 0 || is.na(v[[1]]) || !nzchar(txt) || txt == "NA"
            ) {
                NA_character_
            } else {
                txt
            }
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                errs <- list()
                nest_pic_yes <- identical(one_txt(rec$nest_photo), "1")
                tent_pic_yes <- identical(one_txt(rec$tent_photo), "1")
                any_yes <- nest_pic_yes || tent_pic_yes
                has_end <- !is.na(one_txt(rec$photo_end))
                if (any_yes) {
                    if (!has_end) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "photo_end",
                            reason = "photo_end is required when nest_photo or tent_photo is 1."
                        ))
                    }
                }
                if (!length(errs) == 0) {
                    rbindlist(errs, use.names = TRUE, fill = TRUE)
                }
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (is.null(res) || nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val36"),

    # Enter cam_id, photo_start, and photo_end together.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        one_txt <- function(v) {
            txt <- (v[[1]] |> as.character() |> str_trim())
            if (
                length(txt) == 0 || is.na(v[[1]]) || !nzchar(txt) || txt == "NA"
            ) {
                NA_character_
            } else {
                txt
            }
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                errs <- list()
                nest_pic_yes <- identical(one_txt(rec$nest_photo), "1")
                tent_pic_yes <- identical(one_txt(rec$tent_photo), "1")
                any_yes <- nest_pic_yes || tent_pic_yes
                has_cam <- !is.na(one_txt(rec$cam_id))
                has_start <- !is.na(one_txt(rec$photo_start))
                has_end <- !is.na(one_txt(rec$photo_end))
                set_n <- sum(c(has_cam, has_start, has_end))
                if (!any_yes) {
                    if (set_n > 0 && set_n < 3) {
                        if (!has_cam) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "cam_id",
                                reason = "Enter cam_id, photo_start, and photo_end together."
                            ))
                        }
                    }
                }
                if (!length(errs) == 0) {
                    rbindlist(errs, use.names = TRUE, fill = TRUE)
                }
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (is.null(res) || nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val37"),

    # Enter cam_id, photo_start, and photo_end together.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        one_txt <- function(v) {
            txt <- (v[[1]] |> as.character() |> str_trim())
            if (
                length(txt) == 0 || is.na(v[[1]]) || !nzchar(txt) || txt == "NA"
            ) {
                NA_character_
            } else {
                txt
            }
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                errs <- list()
                nest_pic_yes <- identical(one_txt(rec$nest_photo), "1")
                tent_pic_yes <- identical(one_txt(rec$tent_photo), "1")
                any_yes <- nest_pic_yes || tent_pic_yes
                has_cam <- !is.na(one_txt(rec$cam_id))
                has_start <- !is.na(one_txt(rec$photo_start))
                has_end <- !is.na(one_txt(rec$photo_end))
                set_n <- sum(c(has_cam, has_start, has_end))
                if (!any_yes) {
                    if (set_n > 0 && set_n < 3) {
                        if (!has_start) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "photo_start",
                                reason = "Enter cam_id, photo_start, and photo_end together."
                            ))
                        }
                    }
                }
                if (!length(errs) == 0) {
                    rbindlist(errs, use.names = TRUE, fill = TRUE)
                }
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (is.null(res) || nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val38"),

    # Enter cam_id, photo_start, and photo_end together.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        one_txt <- function(v) {
            txt <- (v[[1]] |> as.character() |> str_trim())
            if (
                length(txt) == 0 || is.na(v[[1]]) || !nzchar(txt) || txt == "NA"
            ) {
                NA_character_
            } else {
                txt
            }
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                errs <- list()
                nest_pic_yes <- identical(one_txt(rec$nest_photo), "1")
                tent_pic_yes <- identical(one_txt(rec$tent_photo), "1")
                any_yes <- nest_pic_yes || tent_pic_yes
                has_cam <- !is.na(one_txt(rec$cam_id))
                has_start <- !is.na(one_txt(rec$photo_start))
                has_end <- !is.na(one_txt(rec$photo_end))
                set_n <- sum(c(has_cam, has_start, has_end))
                if (!any_yes) {
                    if (set_n > 0 && set_n < 3) {
                        if (!has_end) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "photo_end",
                                reason = "Enter cam_id, photo_start, and photo_end together."
                            ))
                        }
                    }
                }
                if (!length(errs) == 0) {
                    rbindlist(errs, use.names = TRUE, fill = TRUE)
                }
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (is.null(res) || nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val39"),

    # photo_end must not precede photo_start.
    {
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
        dat <- copy(x)
        dat[, let(rowid, .I)]
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                errs <- list()
                start_no <- pic_no(rec$photo_start)
                end_no <- pic_no(rec$photo_end)
                if (!is.na(start_no) && !is.na(end_no) && start_no > end_no) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "photo_end",
                        reason = "photo_end must not precede photo_start."
                    ))
                }
                if (!length(errs) == 0) {
                    rbindlist(errs, use.names = TRUE, fill = TRUE)
                }
            }),
            use.names = TRUE,
            fill = TRUE
        )
        if (is.null(res) || nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val40"),

    # The first chronological nest event must use nest_state S or F.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        norm_txt <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res == "NA"] <- NA_character_
            res
        }
        clock_txt <- function(v) {
            res <- norm_txt(v)
            res[!is.na(res) & nzchar(res)] <- substr(
                res[!is.na(res) & nzchar(res)],
                1,
                5
            )
            res
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat[, let(source, "current")]
        ids <- unique((dat$nest_id |> as.character() |> str_trim()))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table(
            nest_id = character(),
            date = character(),
            time_visit = character(),
            nest_state = character(),
            clutch_size = numeric(),
            gps_id = character(),
            gps_point = character(),
            rowid = integer(),
            source = character()
        )
        if (length(ids) > 0) {
            quoted <- paste(
                sprintf("'%s'", (ids |> str_replace_all("'", "''"))),
                collapse = ", "
            )
            hist0 <- tryCatch(
                db_get(sprintf(
                    paste(
                        "SELECT nest_id, date, time_visit, nest_state, clutch_size, gps_id, gps_point",
                        "FROM NESTS WHERE nest_id IN (%s)"
                    ),
                    quoted
                )),
                error = function(e) {}
            )
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- as.data.table(hist0)
                hist[, let(nest_id, norm_txt(nest_id))]
                hist[, let(date, norm_txt(date))]
                hist[, let(time_visit, clock_txt(time_visit))]
                hist[, let(nest_state, norm_txt(nest_state))]
                hist[, let(
                    clutch_size,
                    (clutch_size |> as.character() |> as.numeric())
                )]
                hist[, let(gps_id, norm_txt(gps_id))]
                hist[, let(gps_point, norm_txt(gps_point))]
                hist[, let(rowid, NA_integer_)]
                hist[, let(source, "db")]
            }
        }
        now_hist <- dat[, .(
            nest_id = norm_txt(nest_id),
            date = norm_txt(date),
            time_visit = clock_txt(time_visit),
            nest_state = norm_txt(nest_state),
            clutch_size = (clutch_size |> as.character() |> as.numeric()),
            gps_id = norm_txt(gps_id),
            gps_point = norm_txt(gps_point),
            rowid,
            source
        )]
        all_nests <- rbindlist(
            list(hist, now_hist),
            use.names = TRUE,
            fill = TRUE
        )
        all_nests[, let(date_ord, (date |> as.Date()))]
        all_nests[, let(
            time_ord,
            (strptime(time_visit, format = "%H:%M") |> as.POSIXct())
        )]
        all_nests[, let(source_ord, ifelse(source == "db", 0, 1))]
        all_nests <- all_nests[
            !is.na(nest_id) &
                nzchar(nest_id) &
                !is.na(nest_state) &
                nzchar(nest_state) &
                !is.na(date_ord) &
                !is.na(time_ord)
        ]
        setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        chunks <- lapply(
            split(all_nests, by = "nest_id", keep.by = TRUE),
            function(dt) {
                if (nrow(dt) == 0) {
                    return(NULL)
                }
                if (!is.na(dt$rowid[1])) {
                    if (
                        is.na(dt$nest_state[1]) ||
                            !dt$nest_state[1] %in% c("F", "S")
                    ) {
                        return(data.table(
                            rowid = dt$rowid[1],
                            variable = "nest_state",
                            reason = "The first chronological nest event must use nest_state S or F."
                        ))
                    }
                }
                later_now <- which(seq_len(nrow(dt)) > 1 & !is.na(dt$rowid))
                if (length(later_now) > 0) {
                    later_gps_point <- later_now[
                        !is.na(dt$gps_point[later_now]) &
                            nzchar(dt$gps_point[later_now])
                    ]
                }
            }
        )
        chunks <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, chunks)
        res <- if (length(chunks) == 0) {
            none
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        res <- res[!is.na(rowid)]
        if (nrow(res) == 0) {
            none
        } else {
            res[, .(rowid, variable, reason)]
        }
    } |>
        try_validator(nam = "val41"),

    # A first nest event with clutch_size 0 must use nest_state S.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        norm_txt <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res == "NA"] <- NA_character_
            res
        }
        clock_txt <- function(v) {
            res <- norm_txt(v)
            res[!is.na(res) & nzchar(res)] <- substr(
                res[!is.na(res) & nzchar(res)],
                1,
                5
            )
            res
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat[, let(source, "current")]
        ids <- unique((dat$nest_id |> as.character() |> str_trim()))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table(
            nest_id = character(),
            date = character(),
            time_visit = character(),
            nest_state = character(),
            clutch_size = numeric(),
            gps_id = character(),
            gps_point = character(),
            rowid = integer(),
            source = character()
        )
        if (length(ids) > 0) {
            quoted <- paste(
                sprintf("'%s'", (ids |> str_replace_all("'", "''"))),
                collapse = ", "
            )
            hist0 <- tryCatch(
                db_get(sprintf(
                    paste(
                        "SELECT nest_id, date, time_visit, nest_state, clutch_size, gps_id, gps_point",
                        "FROM NESTS WHERE nest_id IN (%s)"
                    ),
                    quoted
                )),
                error = function(e) {}
            )
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- as.data.table(hist0)
                hist[, let(nest_id, norm_txt(nest_id))]
                hist[, let(date, norm_txt(date))]
                hist[, let(time_visit, clock_txt(time_visit))]
                hist[, let(nest_state, norm_txt(nest_state))]
                hist[, let(
                    clutch_size,
                    (clutch_size |> as.character() |> as.numeric())
                )]
                hist[, let(gps_id, norm_txt(gps_id))]
                hist[, let(gps_point, norm_txt(gps_point))]
                hist[, let(rowid, NA_integer_)]
                hist[, let(source, "db")]
            }
        }
        now_hist <- dat[, .(
            nest_id = norm_txt(nest_id),
            date = norm_txt(date),
            time_visit = clock_txt(time_visit),
            nest_state = norm_txt(nest_state),
            clutch_size = (clutch_size |> as.character() |> as.numeric()),
            gps_id = norm_txt(gps_id),
            gps_point = norm_txt(gps_point),
            rowid,
            source
        )]
        all_nests <- rbindlist(
            list(hist, now_hist),
            use.names = TRUE,
            fill = TRUE
        )
        all_nests[, let(date_ord, (date |> as.Date()))]
        all_nests[, let(
            time_ord,
            (strptime(time_visit, format = "%H:%M") |> as.POSIXct())
        )]
        all_nests[, let(source_ord, ifelse(source == "db", 0, 1))]
        all_nests <- all_nests[
            !is.na(nest_id) &
                nzchar(nest_id) &
                !is.na(nest_state) &
                nzchar(nest_state) &
                !is.na(date_ord) &
                !is.na(time_ord)
        ]
        setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        chunks <- lapply(
            split(all_nests, by = "nest_id", keep.by = TRUE),
            function(dt) {
                if (nrow(dt) == 0) {
                    return(NULL)
                }
                if (!is.na(dt$rowid[1])) {
                    if (
                        identical(dt$nest_state[1], "F") &&
                            !is.na(dt$clutch_size[1]) &&
                            dt$clutch_size[1] == 0
                    ) {
                        return(data.table(
                            rowid = dt$rowid[1],
                            variable = "clutch_size",
                            reason = "A first nest event with clutch_size 0 must use nest_state S."
                        ))
                    }
                }
                later_now <- which(seq_len(nrow(dt)) > 1 & !is.na(dt$rowid))
                if (length(later_now) > 0) {
                    later_gps_point <- later_now[
                        !is.na(dt$gps_point[later_now]) &
                            nzchar(dt$gps_point[later_now])
                    ]
                }
            }
        )
        chunks <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, chunks)
        res <- if (length(chunks) == 0) {
            none
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        res <- res[!is.na(rowid)]
        if (nrow(res) == 0) {
            none
        } else {
            res[, .(rowid, variable, reason)]
        }
    } |>
        try_validator(nam = "val42"),

    # The first nest event for a nest_id must record gps_id.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        norm_txt <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res == "NA"] <- NA_character_
            res
        }
        clock_txt <- function(v) {
            res <- norm_txt(v)
            res[!is.na(res) & nzchar(res)] <- substr(
                res[!is.na(res) & nzchar(res)],
                1,
                5
            )
            res
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat[, let(source, "current")]
        ids <- unique((dat$nest_id |> as.character() |> str_trim()))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table(
            nest_id = character(),
            date = character(),
            time_visit = character(),
            nest_state = character(),
            clutch_size = numeric(),
            gps_id = character(),
            gps_point = character(),
            rowid = integer(),
            source = character()
        )
        if (length(ids) > 0) {
            quoted <- paste(
                sprintf("'%s'", (ids |> str_replace_all("'", "''"))),
                collapse = ", "
            )
            hist0 <- tryCatch(
                db_get(sprintf(
                    paste(
                        "SELECT nest_id, date, time_visit, nest_state, clutch_size, gps_id, gps_point",
                        "FROM NESTS WHERE nest_id IN (%s)"
                    ),
                    quoted
                )),
                error = function(e) {}
            )
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- as.data.table(hist0)
                hist[, let(nest_id, norm_txt(nest_id))]
                hist[, let(date, norm_txt(date))]
                hist[, let(time_visit, clock_txt(time_visit))]
                hist[, let(nest_state, norm_txt(nest_state))]
                hist[, let(
                    clutch_size,
                    (clutch_size |> as.character() |> as.numeric())
                )]
                hist[, let(gps_id, norm_txt(gps_id))]
                hist[, let(gps_point, norm_txt(gps_point))]
                hist[, let(rowid, NA_integer_)]
                hist[, let(source, "db")]
            }
        }
        now_hist <- dat[, .(
            nest_id = norm_txt(nest_id),
            date = norm_txt(date),
            time_visit = clock_txt(time_visit),
            nest_state = norm_txt(nest_state),
            clutch_size = (clutch_size |> as.character() |> as.numeric()),
            gps_id = norm_txt(gps_id),
            gps_point = norm_txt(gps_point),
            rowid,
            source
        )]
        all_nests <- rbindlist(
            list(hist, now_hist),
            use.names = TRUE,
            fill = TRUE
        )
        all_nests[, let(date_ord, (date |> as.Date()))]
        all_nests[, let(
            time_ord,
            (strptime(time_visit, format = "%H:%M") |> as.POSIXct())
        )]
        all_nests[, let(source_ord, ifelse(source == "db", 0, 1))]
        all_nests <- all_nests[
            !is.na(nest_id) &
                nzchar(nest_id) &
                !is.na(nest_state) &
                nzchar(nest_state) &
                !is.na(date_ord) &
                !is.na(time_ord)
        ]
        setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        chunks <- lapply(
            split(all_nests, by = "nest_id", keep.by = TRUE),
            function(dt) {
                if (nrow(dt) == 0) {
                    return(NULL)
                }
                if (!is.na(dt$rowid[1])) {
                    if (is.na(dt$gps_id[1]) || !nzchar(dt$gps_id[1])) {
                        return(data.table(
                            rowid = dt$rowid[1],
                            variable = "gps_id",
                            reason = "The first nest event for a nest_id must record gps_id."
                        ))
                    }
                }
                later_now <- which(seq_len(nrow(dt)) > 1 & !is.na(dt$rowid))
                if (length(later_now) > 0) {
                    later_gps_point <- later_now[
                        !is.na(dt$gps_point[later_now]) &
                            nzchar(dt$gps_point[later_now])
                    ]
                }
            }
        )
        chunks <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, chunks)
        res <- if (length(chunks) == 0) {
            none
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        res <- res[!is.na(rowid)]
        if (nrow(res) == 0) {
            none
        } else {
            res[, .(rowid, variable, reason)]
        }
    } |>
        try_validator(nam = "val43"),

    # The first nest event for a nest_id must record gps_point.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        norm_txt <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res == "NA"] <- NA_character_
            res
        }
        clock_txt <- function(v) {
            res <- norm_txt(v)
            res[!is.na(res) & nzchar(res)] <- substr(
                res[!is.na(res) & nzchar(res)],
                1,
                5
            )
            res
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat[, let(source, "current")]
        ids <- unique((dat$nest_id |> as.character() |> str_trim()))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table(
            nest_id = character(),
            date = character(),
            time_visit = character(),
            nest_state = character(),
            clutch_size = numeric(),
            gps_id = character(),
            gps_point = character(),
            rowid = integer(),
            source = character()
        )
        if (length(ids) > 0) {
            quoted <- paste(
                sprintf("'%s'", (ids |> str_replace_all("'", "''"))),
                collapse = ", "
            )
            hist0 <- tryCatch(
                db_get(sprintf(
                    paste(
                        "SELECT nest_id, date, time_visit, nest_state, clutch_size, gps_id, gps_point",
                        "FROM NESTS WHERE nest_id IN (%s)"
                    ),
                    quoted
                )),
                error = function(e) {}
            )
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- as.data.table(hist0)
                hist[, let(nest_id, norm_txt(nest_id))]
                hist[, let(date, norm_txt(date))]
                hist[, let(time_visit, clock_txt(time_visit))]
                hist[, let(nest_state, norm_txt(nest_state))]
                hist[, let(
                    clutch_size,
                    (clutch_size |> as.character() |> as.numeric())
                )]
                hist[, let(gps_id, norm_txt(gps_id))]
                hist[, let(gps_point, norm_txt(gps_point))]
                hist[, let(rowid, NA_integer_)]
                hist[, let(source, "db")]
            }
        }
        now_hist <- dat[, .(
            nest_id = norm_txt(nest_id),
            date = norm_txt(date),
            time_visit = clock_txt(time_visit),
            nest_state = norm_txt(nest_state),
            clutch_size = (clutch_size |> as.character() |> as.numeric()),
            gps_id = norm_txt(gps_id),
            gps_point = norm_txt(gps_point),
            rowid,
            source
        )]
        all_nests <- rbindlist(
            list(hist, now_hist),
            use.names = TRUE,
            fill = TRUE
        )
        all_nests[, let(date_ord, (date |> as.Date()))]
        all_nests[, let(
            time_ord,
            (strptime(time_visit, format = "%H:%M") |> as.POSIXct())
        )]
        all_nests[, let(source_ord, ifelse(source == "db", 0, 1))]
        all_nests <- all_nests[
            !is.na(nest_id) &
                nzchar(nest_id) &
                !is.na(nest_state) &
                nzchar(nest_state) &
                !is.na(date_ord) &
                !is.na(time_ord)
        ]
        setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        chunks <- lapply(
            split(all_nests, by = "nest_id", keep.by = TRUE),
            function(dt) {
                if (nrow(dt) == 0) {
                    return(NULL)
                }
                if (!is.na(dt$rowid[1])) {
                    if (is.na(dt$gps_point[1]) || !nzchar(dt$gps_point[1])) {
                        return(data.table(
                            rowid = dt$rowid[1],
                            variable = "gps_point",
                            reason = "The first nest event for a nest_id must record gps_point."
                        ))
                    }
                }
                later_now <- which(seq_len(nrow(dt)) > 1 & !is.na(dt$rowid))
                if (length(later_now) > 0) {
                    later_gps_point <- later_now[
                        !is.na(dt$gps_point[later_now]) &
                            nzchar(dt$gps_point[later_now])
                    ]
                }
            }
        )
        chunks <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, chunks)
        res <- if (length(chunks) == 0) {
            none
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        res <- res[!is.na(rowid)]
        if (nrow(res) == 0) {
            none
        } else {
            res[, .(rowid, variable, reason)]
        }
    } |>
        try_validator(nam = "val44"),

    # Each nest_id may contain only one nest_state F event.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        norm_txt <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res == "NA"] <- NA_character_
            res
        }
        clock_txt <- function(v) {
            res <- norm_txt(v)
            res[!is.na(res) & nzchar(res)] <- substr(
                res[!is.na(res) & nzchar(res)],
                1,
                5
            )
            res
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat[, let(source, "current")]
        ids <- unique((dat$nest_id |> as.character() |> str_trim()))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table(
            nest_id = character(),
            date = character(),
            time_visit = character(),
            nest_state = character(),
            clutch_size = numeric(),
            gps_id = character(),
            gps_point = character(),
            rowid = integer(),
            source = character()
        )
        if (length(ids) > 0) {
            quoted <- paste(
                sprintf("'%s'", (ids |> str_replace_all("'", "''"))),
                collapse = ", "
            )
            hist0 <- tryCatch(
                db_get(sprintf(
                    paste(
                        "SELECT nest_id, date, time_visit, nest_state, clutch_size, gps_id, gps_point",
                        "FROM NESTS WHERE nest_id IN (%s)"
                    ),
                    quoted
                )),
                error = function(e) {}
            )
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- as.data.table(hist0)
                hist[, let(nest_id, norm_txt(nest_id))]
                hist[, let(date, norm_txt(date))]
                hist[, let(time_visit, clock_txt(time_visit))]
                hist[, let(nest_state, norm_txt(nest_state))]
                hist[, let(
                    clutch_size,
                    (clutch_size |> as.character() |> as.numeric())
                )]
                hist[, let(gps_id, norm_txt(gps_id))]
                hist[, let(gps_point, norm_txt(gps_point))]
                hist[, let(rowid, NA_integer_)]
                hist[, let(source, "db")]
            }
        }
        now_hist <- dat[, .(
            nest_id = norm_txt(nest_id),
            date = norm_txt(date),
            time_visit = clock_txt(time_visit),
            nest_state = norm_txt(nest_state),
            clutch_size = (clutch_size |> as.character() |> as.numeric()),
            gps_id = norm_txt(gps_id),
            gps_point = norm_txt(gps_point),
            rowid,
            source
        )]
        all_nests <- rbindlist(
            list(hist, now_hist),
            use.names = TRUE,
            fill = TRUE
        )
        all_nests[, let(date_ord, (date |> as.Date()))]
        all_nests[, let(
            time_ord,
            (strptime(time_visit, format = "%H:%M") |> as.POSIXct())
        )]
        all_nests[, let(source_ord, ifelse(source == "db", 0, 1))]
        all_nests <- all_nests[
            !is.na(nest_id) &
                nzchar(nest_id) &
                !is.na(nest_state) &
                nzchar(nest_state) &
                !is.na(date_ord) &
                !is.na(time_ord)
        ]
        setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        chunks <- lapply(
            split(all_nests, by = "nest_id", keep.by = TRUE),
            function(dt) {
                if (nrow(dt) == 0) {
                    return(NULL)
                }
                now_f <- which(dt$source == "current" & dt$nest_state == "F")
                saved_f_exists <- any(dt$source == "db" & dt$nest_state == "F")
                duplicate_f <- if (saved_f_exists) {
                    now_f
                } else if (length(now_f) > 1) {
                    now_f[-1]
                } else {
                    integer()
                }
                if (length(duplicate_f) > 0) {
                    return(data.table(
                        rowid = dt$rowid[duplicate_f],
                        variable = "nest_state",
                        reason = "Each nest_id may contain only one nest_state F event."
                    ))
                }
                later_now <- which(seq_len(nrow(dt)) > 1 & !is.na(dt$rowid))
                if (length(later_now) > 0) {
                    later_gps_point <- later_now[
                        !is.na(dt$gps_point[later_now]) &
                            nzchar(dt$gps_point[later_now])
                    ]
                }
            }
        )
        chunks <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, chunks)
        res <- if (length(chunks) == 0) {
            none
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        res <- res[!is.na(rowid)]
        if (nrow(res) == 0) {
            none
        } else {
            res[, .(rowid, variable, reason)]
        }
    } |>
        try_validator(nam = "val45"),

    # Only the first chronological event for a nest_id may record gps_id.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        norm_txt <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res == "NA"] <- NA_character_
            res
        }
        clock_txt <- function(v) {
            res <- norm_txt(v)
            res[!is.na(res) & nzchar(res)] <- substr(
                res[!is.na(res) & nzchar(res)],
                1,
                5
            )
            res
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat[, let(source, "current")]
        ids <- unique((dat$nest_id |> as.character() |> str_trim()))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table(
            nest_id = character(),
            date = character(),
            time_visit = character(),
            nest_state = character(),
            clutch_size = numeric(),
            gps_id = character(),
            gps_point = character(),
            rowid = integer(),
            source = character()
        )
        if (length(ids) > 0) {
            quoted <- paste(
                sprintf("'%s'", (ids |> str_replace_all("'", "''"))),
                collapse = ", "
            )
            hist0 <- tryCatch(
                db_get(sprintf(
                    paste(
                        "SELECT nest_id, date, time_visit, nest_state, clutch_size, gps_id, gps_point",
                        "FROM NESTS WHERE nest_id IN (%s)"
                    ),
                    quoted
                )),
                error = function(e) {}
            )
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- as.data.table(hist0)
                hist[, let(nest_id, norm_txt(nest_id))]
                hist[, let(date, norm_txt(date))]
                hist[, let(time_visit, clock_txt(time_visit))]
                hist[, let(nest_state, norm_txt(nest_state))]
                hist[, let(
                    clutch_size,
                    (clutch_size |> as.character() |> as.numeric())
                )]
                hist[, let(gps_id, norm_txt(gps_id))]
                hist[, let(gps_point, norm_txt(gps_point))]
                hist[, let(rowid, NA_integer_)]
                hist[, let(source, "db")]
            }
        }
        now_hist <- dat[, .(
            nest_id = norm_txt(nest_id),
            date = norm_txt(date),
            time_visit = clock_txt(time_visit),
            nest_state = norm_txt(nest_state),
            clutch_size = (clutch_size |> as.character() |> as.numeric()),
            gps_id = norm_txt(gps_id),
            gps_point = norm_txt(gps_point),
            rowid,
            source
        )]
        all_nests <- rbindlist(
            list(hist, now_hist),
            use.names = TRUE,
            fill = TRUE
        )
        all_nests[, let(date_ord, (date |> as.Date()))]
        all_nests[, let(
            time_ord,
            (strptime(time_visit, format = "%H:%M") |> as.POSIXct())
        )]
        all_nests[, let(source_ord, ifelse(source == "db", 0, 1))]
        all_nests <- all_nests[
            !is.na(nest_id) &
                nzchar(nest_id) &
                !is.na(nest_state) &
                nzchar(nest_state) &
                !is.na(date_ord) &
                !is.na(time_ord)
        ]
        setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        chunks <- lapply(
            split(all_nests, by = "nest_id", keep.by = TRUE),
            function(dt) {
                if (nrow(dt) == 0) {
                    return(NULL)
                }
                later_now <- which(seq_len(nrow(dt)) > 1 & !is.na(dt$rowid))
                if (length(later_now) > 0) {
                    later_gps_id <- later_now[
                        !is.na(dt$gps_id[later_now]) &
                            nzchar(dt$gps_id[later_now])
                    ]
                    if (length(later_gps_id) > 0) {
                        return(data.table(
                            rowid = dt$rowid[later_gps_id],
                            variable = "gps_id",
                            reason = "Only the first chronological event for a nest_id may record gps_id."
                        ))
                    }
                    later_gps_point <- later_now[
                        !is.na(dt$gps_point[later_now]) &
                            nzchar(dt$gps_point[later_now])
                    ]
                }
            }
        )
        chunks <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, chunks)
        res <- if (length(chunks) == 0) {
            none
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        res <- res[!is.na(rowid)]
        if (nrow(res) == 0) {
            none
        } else {
            res[, .(rowid, variable, reason)]
        }
    } |>
        try_validator(nam = "val46"),

    # Only the first chronological event for a nest_id may record gps_point.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        norm_txt <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res == "NA"] <- NA_character_
            res
        }
        clock_txt <- function(v) {
            res <- norm_txt(v)
            res[!is.na(res) & nzchar(res)] <- substr(
                res[!is.na(res) & nzchar(res)],
                1,
                5
            )
            res
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat[, let(source, "current")]
        ids <- unique((dat$nest_id |> as.character() |> str_trim()))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table(
            nest_id = character(),
            date = character(),
            time_visit = character(),
            nest_state = character(),
            clutch_size = numeric(),
            gps_id = character(),
            gps_point = character(),
            rowid = integer(),
            source = character()
        )
        if (length(ids) > 0) {
            quoted <- paste(
                sprintf("'%s'", (ids |> str_replace_all("'", "''"))),
                collapse = ", "
            )
            hist0 <- tryCatch(
                db_get(sprintf(
                    paste(
                        "SELECT nest_id, date, time_visit, nest_state, clutch_size, gps_id, gps_point",
                        "FROM NESTS WHERE nest_id IN (%s)"
                    ),
                    quoted
                )),
                error = function(e) {}
            )
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- as.data.table(hist0)
                hist[, let(nest_id, norm_txt(nest_id))]
                hist[, let(date, norm_txt(date))]
                hist[, let(time_visit, clock_txt(time_visit))]
                hist[, let(nest_state, norm_txt(nest_state))]
                hist[, let(
                    clutch_size,
                    (clutch_size |> as.character() |> as.numeric())
                )]
                hist[, let(gps_id, norm_txt(gps_id))]
                hist[, let(gps_point, norm_txt(gps_point))]
                hist[, let(rowid, NA_integer_)]
                hist[, let(source, "db")]
            }
        }
        now_hist <- dat[, .(
            nest_id = norm_txt(nest_id),
            date = norm_txt(date),
            time_visit = clock_txt(time_visit),
            nest_state = norm_txt(nest_state),
            clutch_size = (clutch_size |> as.character() |> as.numeric()),
            gps_id = norm_txt(gps_id),
            gps_point = norm_txt(gps_point),
            rowid,
            source
        )]
        all_nests <- rbindlist(
            list(hist, now_hist),
            use.names = TRUE,
            fill = TRUE
        )
        all_nests[, let(date_ord, (date |> as.Date()))]
        all_nests[, let(
            time_ord,
            (strptime(time_visit, format = "%H:%M") |> as.POSIXct())
        )]
        all_nests[, let(source_ord, ifelse(source == "db", 0, 1))]
        all_nests <- all_nests[
            !is.na(nest_id) &
                nzchar(nest_id) &
                !is.na(nest_state) &
                nzchar(nest_state) &
                !is.na(date_ord) &
                !is.na(time_ord)
        ]
        setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        chunks <- lapply(
            split(all_nests, by = "nest_id", keep.by = TRUE),
            function(dt) {
                if (nrow(dt) == 0) {
                    return(NULL)
                }
                later_now <- which(seq_len(nrow(dt)) > 1 & !is.na(dt$rowid))
                if (length(later_now) > 0) {
                    later_gps_point <- later_now[
                        !is.na(dt$gps_point[later_now]) &
                            nzchar(dt$gps_point[later_now])
                    ]
                    if (length(later_gps_point) > 0) {
                        return(data.table(
                            rowid = dt$rowid[later_gps_point],
                            variable = "gps_point",
                            reason = "Only the first chronological event for a nest_id may record gps_point."
                        ))
                    }
                }
            }
        )
        chunks <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, chunks)
        res <- if (length(chunks) == 0) {
            none
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        res <- res[!is.na(rowid)]
        if (nrow(res) == 0) {
            none
        } else {
            res[, .(rowid, variable, reason)]
        }
    } |>
        try_validator(nam = "val47"),

    # Check start state sequence.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        norm_txt <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res == "NA"] <- NA_character_
            res
        }
        clock_txt <- function(v) {
            res <- norm_txt(v)
            res[!is.na(res) & nzchar(res)] <- substr(
                res[!is.na(res) & nzchar(res)],
                1,
                5
            )
            res
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat[, let(source, "current")]
        ids <- unique((dat$nest_id |> as.character() |> str_trim()))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table(
            nest_id = character(),
            date = character(),
            time_visit = character(),
            nest_state = character(),
            clutch_size = character(),
            brood_size = character(),
            rowid = integer(),
            source = character()
        )
        if (length(ids) > 0) {
            quoted <- paste(
                sprintf("'%s'", (ids |> str_replace_all("'", "''"))),
                collapse = ", "
            )
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
                hist <- as.data.table(hist0)
                hist[, let(nest_id, norm_txt(nest_id))]
                hist[, let(date, norm_txt(date))]
                hist[, let(time_visit, clock_txt(time_visit))]
                hist[, let(nest_state, norm_txt(nest_state))]
                hist[, let(rowid, NA_integer_)]
                hist[, let(source, "db")]
            }
        }
        now_hist <- dat[, .(
            nest_id = norm_txt(nest_id),
            date = norm_txt(date),
            time_visit = clock_txt(time_visit),
            nest_state = norm_txt(nest_state),
            clutch_size,
            brood_size,
            rowid,
            source
        )]
        all_nests <- rbindlist(
            list(hist, now_hist),
            use.names = TRUE,
            fill = TRUE
        )
        all_nests[, let(date_ord, (date |> as.Date()))]
        all_nests[, let(
            time_ord,
            (strptime(time_visit, format = "%H:%M") |> as.POSIXct())
        )]
        all_nests[, let(
            clutch_num = (clutch_size |> as.character() |> as.numeric()),
            brood_num = (brood_size |> as.character() |> as.numeric())
        )]
        all_nests[, let(source_ord, ifelse(source == "db", 0, 1))]
        all_nests[, let(state_ord, ifelse(nest_state == "notA", 1, 0))]
        all_nests <- all_nests[
            !is.na(nest_id) &
                nzchar(nest_id) &
                !is.na(nest_state) &
                nzchar(nest_state) &
                !is.na(date_ord) &
                !is.na(time_ord)
        ]
        setorder(
            all_nests,
            nest_id,
            date_ord,
            time_ord,
            source_ord,
            state_ord,
            rowid
        )
        all_nests <- all_nests[,
            .SD[1],
            by = .(nest_id, date, time_visit, nest_state)
        ]
        setorder(
            all_nests,
            nest_id,
            date_ord,
            time_ord,
            source_ord,
            state_ord,
            rowid
        )
        chunks <- lapply(
            split(all_nests, by = "nest_id", keep.by = TRUE),
            function(dt) {
                probs <- list()
                st <- (dt$nest_state |> as.character())
                if (nrow(dt) < 2) {
                    return(NULL)
                }
                last_live <- st[1]
                for (i in 2:nrow(dt)) {
                    now_state <- st[i]
                    repeated_f <- now_state == "F" &&
                        any(st[seq_len(i - 1)] == "F")
                    allowed <- switch(
                        last_live,
                        S = c("S", "F", "notA"),
                        F = c(
                            "I",
                            "H",
                            "pP",
                            "P",
                            "pD",
                            "D",
                            "notA",
                            "O"
                        ),
                        I = c(
                            "I",
                            "H",
                            "pP",
                            "P",
                            "pD",
                            "D",
                            "notA",
                            "O"
                        ),
                        pD = c("I", "H", "pP", "P", "pD", "D", "notA", "O"),
                        character()
                    )
                    if (
                        !repeated_f &&
                            length(allowed) > 0 &&
                            !now_state %in% allowed
                    ) {
                        probs[[length(probs) + 1]] <- data.table(
                            rowid = dt$rowid[i],
                            variable = "nest_state",
                            reason = if (last_live == "F") {
                                "After nest_state F, subsequent visits may use only I, H, pP, P, pD, D, notA, or O."
                            } else if (last_live == "S") {
                                "After nest_state S, subsequent visits may use only S, F, or a final notA."
                            } else {
                                "This nest_state is not allowed after the latest active nest state."
                            }
                        )
                    }
                    if (now_state != "O") {
                        last_live <- now_state
                    }
                }
                probs <- Filter(function(x) !is.null(x) && nrow(x) > 0, probs)
                if (length(probs) == 0) {
                    return(NULL)
                }
                unique(rbindlist(probs, use.names = TRUE, fill = TRUE))
            }
        )
        chunks <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, chunks)
        res <- if (length(chunks) == 0) {
            none
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        res <- res[!is.na(rowid)]
        if (nrow(res) == 0) {
            none
        } else {
            res[, .(rowid, variable, reason)]
        }
    } |>
        try_validator(nam = "val48"),

    # Check terminal notA.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        norm_txt <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res == "NA"] <- NA_character_
            res
        }
        clock_txt <- function(v) {
            if (inherits(v, "difftime")) {
                secs <- (v |> as.numeric(units = "secs"))
                res <- rep(NA_character_, length(secs))
                ok <- !is.na(secs)
                secs <- secs %% (24 * 60 * 60)
                res[ok] <- sprintf(
                    "%02d:%02d:%02d",
                    floor(secs[ok] / 3600),
                    floor((secs[ok] %% 3600) / 60),
                    floor(secs[ok] %% 60)
                )
                return(res)
            }
            res <- norm_txt(v)
            res[!is.na(res) & nzchar(res)] <- substr(
                res[!is.na(res) & nzchar(res)],
                1,
                5
            )
            res
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat[, let(source, "current")]
        clutch_num <- (dat$clutch_size |> as.character() |> as.numeric())
        brood_num <- (dat$brood_size |> as.character() |> as.numeric())
        ids <- unique((dat$nest_id |> as.character() |> str_trim()))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table(
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
            quoted <- paste(
                sprintf("'%s'", (ids |> str_replace_all("'", "''"))),
                collapse = ", "
            )
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
                hist <- as.data.table(hist0)
                hist[, let(nest_id, norm_txt(nest_id))]
                hist[, let(date, norm_txt(date))]
                hist[, let(time_visit, clock_txt(time_visit))]
                hist[, let(nest_state, norm_txt(nest_state))]
                hist[, let(
                    clutch_num,
                    (clutch_size |> as.character() |> as.numeric())
                )]
                hist[, let(
                    brood_num,
                    (brood_size |> as.character() |> as.numeric())
                )]
                hist[, let(rowid, NA_integer_)]
                hist[, let(source, "db")]
            }
        }
        now_hist <- dat[, .(
            nest_id = norm_txt(nest_id),
            date = norm_txt(date),
            time_visit = clock_txt(time_visit),
            nest_state = norm_txt(nest_state),
            clutch_num,
            brood_num,
            rowid,
            source
        )]
        all_nests <- rbindlist(
            list(hist, now_hist),
            use.names = TRUE,
            fill = TRUE
        )
        all_nests[, let(date_ord, (date |> as.Date()))]
        all_nests[, let(
            time_ord,
            (strptime(time_visit, format = "%H:%M") |> as.POSIXct())
        )]
        all_nests[, let(source_ord, ifelse(source == "db", 0, 1))]
        all_nests[, let(state_ord, ifelse(nest_state == "notA", 1, 0))]
        all_nests <- all_nests[
            !is.na(nest_id) &
                nzchar(nest_id) &
                !is.na(nest_state) &
                nzchar(nest_state) &
                !is.na(date_ord) &
                !is.na(time_ord)
        ]
        setorder(
            all_nests,
            nest_id,
            date_ord,
            time_ord,
            source_ord,
            state_ord,
            rowid
        )
        all_nests <- all_nests[,
            .SD[1],
            by = .(
                nest_id,
                date,
                time_visit,
                nest_state,
                clutch_num,
                brood_num
            )
        ]
        setorder(
            all_nests,
            nest_id,
            date_ord,
            time_ord,
            source_ord,
            state_ord,
            rowid
        )
        chunks <- lapply(
            split(all_nests, by = "nest_id", keep.by = TRUE),
            function(dt) {
                probs <- list()
                st <- (dt$nest_state |> as.character())
                end_h <- st == "H" &
                    !is.na(dt$clutch_num) &
                    dt$clutch_num == 0 &
                    !is.na(dt$brood_num) &
                    dt$brood_num > 0
                end_i <- which(end_h)
                nota_i <- which(st == "notA")
                if (length(nota_i) > 0) {
                    bad_nota <- nota_i[
                        nota_i != nrow(dt) |
                            nota_i == 1 |
                            !st[pmax(
                                nota_i -
                                    1,
                                1
                            )] %in%
                                c("S", "F", "H", "pD", "pP", "P", "D")
                    ]
                    if (length(bad_nota) > 0) {
                        probs[[length(probs) + 1]] <- data.table(
                            rowid = dt$rowid[bad_nota],
                            variable = "nest_state",
                            reason = paste(
                                "notA must be the final visit and can only follow S, F, H, pD, pP, P, or D.",
                                "When paired with D, notA may use the same timestamp but must not occur before D."
                            )
                        )
                    }
                }
                if (length(end_i) > 0) {
                    first_term <- end_i[1]
                    after_i <- if (first_term < nrow(dt)) {
                        seq.int(first_term + 1, nrow(dt))
                    } else {
                        integer()
                    }
                    allowed_after <- if (
                        length(after_i) == 1 && st[after_i] == "notA"
                    ) {
                        integer()
                    } else {
                        after_i
                    }
                    if (length(allowed_after) > 0) {
                        probs[[length(probs) + 1]] <- data.table(
                            rowid = dt$rowid[allowed_after],
                            variable = "nest_state",
                            reason = "Terminal H permits only final notA; pre-closure checks allow pP/P/D/pD."
                        )
                    }
                }
                h_to_i <- which(head(st, -1) == "H" & tail(st, -1) == "I") + 1
                if (length(h_to_i) > 0) {
                    probs[[length(probs) + 1]] <- data.table(
                        rowid = dt$rowid[h_to_i],
                        variable = "nest_state",
                        reason = "H cannot be followed by I in the same nest history."
                    )
                }
                probs <- Filter(function(x) !is.null(x) && nrow(x) > 0, probs)
                if (length(probs) == 0) {
                    NULL
                } else {
                    unique(rbindlist(probs, use.names = TRUE, fill = TRUE))
                }
            }
        )
        chunks <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, chunks)
        res <- if (length(chunks) == 0) {
            none
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        res <- res[!is.na(rowid)]
        if (nrow(res) == 0) {
            none
        } else {
            res[, .(rowid, variable, reason)]
        }
    } |>
        try_validator(nam = "val49"),

    # Check notA inactive row.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        dat <- copy(x)
        dat[, let(rowid, .I)]
        hatch_raw <- (dat$hatch_state |> as.character() |> str_trim())
        hatch_set <- !is.na(dat$hatch_state) & nzchar(hatch_raw)
        clutch_num <- (dat$clutch_size |> as.character() |> as.numeric())
        brd_raw <- (dat$brood_size |> as.character() |> str_trim())
        brd_raw[is.na(dat$brood_size) | brd_raw == "NA"] <- ""
        brood_num <- (dat$brood_size |> as.character() |> as.numeric())
        dat[, let(
            nest_key = (nest_id |> as.character() |> str_trim()),
            event_date = (date |>
                as.character() |>
                as.Date(format = "%Y-%m-%d")),
            event_time = (time_visit |> as.character() |> str_trim()),
            state_ord = ifelse((nest_state |> as.character()) == "notA", 1, 0),
            clutch_num = clutch_num
        )]
        dat[is.na(event_time), let(event_time, "")]
        dat[,
            let(
                previous_current_state = {
                    ord <- order(
                        event_date,
                        event_time,
                        state_ord,
                        rowid,
                        na.last = TRUE
                    )
                    ans <- rep(NA_character_, .N)
                    ans[ord] <- shift((nest_state |> as.character())[ord])
                    ans
                },
                previous_current_clutch = {
                    ord <- order(
                        event_date,
                        event_time,
                        state_ord,
                        rowid,
                        na.last = TRUE
                    )
                    ans <- rep(NA_real_, .N)
                    ans[ord] <- shift(clutch_num[ord])
                    ans
                }
            ),
            by = nest_key
        ]
        carries_d_clutch <- dat$nest_state == "notA" &
            dat$previous_current_state == "D" &
            !is.na(clutch_num) &
            !is.na(dat$previous_current_clutch) &
            clutch_num == dat$previous_current_clutch
        carries_d_clutch[is.na(carries_d_clutch)] <- FALSE
        clutch_bad <- dat$nest_state == "notA" &
            (is.na(clutch_num) | clutch_num != 0) &
            !carries_d_clutch
        scrape_clutch_bad <- dat$nest_state == "S" &
            (is.na(clutch_num) | clutch_num != 0)
        scrape_brd_bad <- dat$nest_state == "S" &
            nzchar(brd_raw) &
            (is.na(brood_num) | brood_num != 0)
        chunks <- list(
            dat[
                dat$nest_state == "notA" & hatch_set,
                .(
                    rowid,
                    variable = "hatch_state",
                    reason = "notA rows must leave hatch_state blank."
                )
            ],
            dat[
                clutch_bad,
                .(
                    rowid,
                    variable = "clutch_size",
                    reason = paste(
                        "notA rows must set clutch_size to 0 unless they immediately follow a D row",
                        "in the same submission and retain that D row's clutch_size."
                    )
                )
            ],
            dat[
                scrape_clutch_bad,
                .(
                    rowid,
                    variable = "clutch_size",
                    reason = "S rows must set clutch_size to 0."
                )
            ],
            dat[
                scrape_brd_bad,
                .(
                    rowid,
                    variable = "brood_size",
                    reason = "S rows must leave brood_size blank or set it to 0."
                )
            ]
        )
        chunks <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, chunks)
        res <- if (length(chunks) == 0) {
            none
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        if (nrow(res) == 0) {
            none
        } else {
            unique(res)
        }
    } |>
        try_validator(nam = "val50"),

    # Check hatch progression.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        norm_txt <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res == "NA"] <- NA_character_
            res
        }
        clock_txt <- function(v) {
            res <- norm_txt(v)
            res[!is.na(res) & nzchar(res)] <- substr(
                res[!is.na(res) & nzchar(res)],
                1,
                5
            )
            res
        }
        hatch_parts <- function(v) {
            s <- (v |> as.character() |> str_trim())
            if (is.na(s) || !nzchar(s)) {
                return(NULL)
            }
            toks <- str_extract_all(s, "([1-4])(CC|C|S|N)")[[1]]
            if (length(toks) == 0 || paste0(toks, collapse = "") != s) {
                return(NULL)
            }
            states <- (toks |> str_replace("^[1-4]", ""))
            states_norm <- ifelse(states == "CC", "C", states)
            counts <- (toks |>
                str_replace(regex("(\\d).*", dotall = TRUE), "\\1") |>
                as.integer())
            list(
                C = sum(counts[states_norm == "C"]),
                S = sum(counts[states_norm == "S"]),
                N = sum(counts[states_norm == "N"]),
                total = sum(counts),
                max_stage = if (any(states_norm == "C")) {
                    3
                } else if (any(states_norm == "S")) {
                    2
                } else {
                    1
                }
            )
        }
        is_backward_transition <- function(prev_v, current) {
            if (is.null(prev_v) || is.null(current)) {
                return(FALSE)
            }
            new_slots <- 0
            if (!is.na(prev_v$clutch_num) && !is.na(current$clutch_num)) {
                new_slots <- max(0, current$clutch_num - prev_v$clutch_num)
            }
            left_n <- prev_v$N
            unfit_n <- max(0, current$N - left_n)
            left_n <- max(0, left_n - current$N)
            unfit_s <- max(0, current$S - prev_v$S)
            left_s <- max(0, prev_v$S - current$S)
            from_n <- min(left_n, unfit_s)
            unfit_s <- unfit_s - from_n
            left_n <- left_n - from_n
            unfit_c <- max(0, current$C - prev_v$C)
            from_s <- min(left_s, unfit_c)
            unfit_c <- unfit_c - from_s
            left_s <- left_s - from_s
            from_n <- min(left_n, unfit_c)
            unfit_c <- unfit_c - from_n
            unfit_n + unfit_s + unfit_c > new_slots
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        dat[, let(source, "current")]
        ids <- unique((dat$nest_id |> as.character() |> str_trim()))
        ids <- ids[nzchar(ids) & !is.na(ids)]
        hist <- data.table(
            nest_id = character(),
            date = character(),
            time_visit = character(),
            hatch_state = character(),
            clutch_num = numeric(),
            rowid = integer(),
            source = character()
        )
        if (length(ids) > 0) {
            quoted <- paste(
                sprintf("'%s'", (ids |> str_replace_all("'", "''"))),
                collapse = ", "
            )
            hist0 <- tryCatch(
                db_get(sprintf(
                    paste(
                        "SELECT nest_id, date, time_visit, hatch_state, clutch_size",
                        "FROM NESTS WHERE nest_id IN (%s)"
                    ),
                    quoted
                )),
                error = function(e) NULL
            )
            if (!is.null(hist0) && nrow(hist0) > 0) {
                hist <- as.data.table(hist0)
                hist[, let(nest_id, norm_txt(nest_id))]
                hist[, let(date, norm_txt(date))]
                hist[, let(time_visit, clock_txt(time_visit))]
                hist[, let(hatch_state, norm_txt(hatch_state))]
                hist[, let(
                    clutch_num,
                    (clutch_size |> as.character() |> as.numeric())
                )]
                hist[, let(rowid, NA_integer_)]
                hist[, let(source, "db")]
            }
        }
        now_hist <- dat[, .(
            nest_id = norm_txt(nest_id),
            date = norm_txt(date),
            time_visit = clock_txt(time_visit),
            hatch_state = norm_txt(hatch_state),
            clutch_num = (clutch_size |> as.character() |> as.numeric()),
            rowid,
            source
        )]
        all_nests <- rbindlist(
            list(hist, now_hist),
            use.names = TRUE,
            fill = TRUE
        )
        all_nests[, let(date_ord, (date |> as.Date()))]
        all_nests[, let(
            time_ord,
            (strptime(time_visit, format = "%H:%M") |> as.POSIXct())
        )]
        all_nests[, let(source_ord, ifelse(source == "db", 0, 1))]
        setorder(all_nests, nest_id, date_ord, time_ord, source_ord, rowid)
        chunks <- lapply(
            split(all_nests, by = "nest_id", keep.by = TRUE),
            function(dt) {
                prev_hatch <- NULL
                probs <- list()
                for (i in seq_len(nrow(dt))) {
                    p <- hatch_parts(dt$hatch_state[i])
                    if (is.null(p)) {
                        next
                    }
                    p$clutch_num <- dt$clutch_num[i]
                    if (is_backward_transition(prev_hatch, p)) {
                        probs[[length(probs) + 1]] <- data.table(
                            rowid = dt$rowid[i],
                            variable = "hatch_state",
                            reason = "Hatch-state progression cannot move backward."
                        )
                    }
                    prev_hatch <- p
                }
                probs <- Filter(function(x) !is.null(x) && nrow(x) > 0, probs)
                if (length(probs) == 0) {
                    NULL
                } else {
                    rbindlist(probs, use.names = TRUE, fill = TRUE)
                }
            }
        )
        chunks <- Filter(function(dt) !is.null(dt) && nrow(dt) > 0, chunks)
        res <- if (length(chunks) == 0) {
            none
        } else {
            rbindlist(chunks, use.names = TRUE, fill = TRUE)
        }
        res <- res[!is.na(rowid)]
        if (nrow(res) == 0) {
            none
        } else {
            res[, .(rowid, variable, reason)]
        }
    } |>
        try_validator(nam = "val51"),

    # Check photo numbers unique.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
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
        expand_range <- function(start_v, end_v) {
            s <- pic_no(start_v)
            e <- pic_no(end_v)
            if (is.na(s) || is.na(e) || s > e) {
                integer()
            } else {
                seq.int(s, e)
            }
        }
        clean_pic <- function(v) {
            txt <- (v |> as.character() |> str_trim() |> toupper())
            txt[is.na(v) | !nzchar(txt) | txt == "NA"] <- NA_character_
            txt
        }
        expand_recs <- function(dt, table_name, rowid_col = NULL) {
            dt <- copy(dt)
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
                if (!fld %in% names(dt)) {
                    dt[, let((fld), NA_character_)]
                }
            }
            dt[, let(
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
            bits <- lapply(seq_len(nrow(dt)), function(i) {
                nums <- expand_range(dt$photo_start[i], dt$photo_end[i])
                if (!length(nums)) {
                    return(NULL)
                }
                data.table(
                    table_name = dt$table_name[i],
                    rowid = if (is.null(rowid_col)) {
                        NA_integer_
                    } else {
                        dt[[rowid_col]][i]
                    },
                    img_num = nums,
                    cam_key = dt$cam_key[i],
                    date_key = dt$date_key[i],
                    observer_key = dt$observer_key[i],
                    nest_key = dt$nest_key[i],
                    gps_id_key = dt$gps_id_key[i],
                    gps_point_key = dt$gps_point_key[i],
                    rclass_key = dt$rclass_key[i],
                    age_key = dt$age_key[i],
                    pk_key = dt$pk_key[i]
                )
            })
            bits <- Filter(Negate(is.null), bits)
            if (length(bits) == 0) {
                data.table(
                    table_name = character(),
                    rowid = integer(),
                    img_num = integer(),
                    cam_key = character(),
                    date_key = character(),
                    observer_key = character(),
                    nest_key = character(),
                    gps_id_key = character(),
                    gps_point_key = character(),
                    rclass_key = character(),
                    age_key = character(),
                    pk_key = character()
                )
            } else {
                rbindlist(bits, use.names = TRUE, fill = TRUE)
            }
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
                    !identical(a$img_num[[1]], b$img_num[[1]])
            ) {
                return(FALSE)
            }
            !same_pic_event(a, b)
        }
        dat <- copy(x)
        dat[, let(rowid, .I)]
        now_seq <- expand_recs(dat, table_name = "NESTS", rowid_col = "rowid")
        if (nrow(now_seq) == 0) {
            none
        } else {
            ref_bits <- list()
            ref_nests <- tryCatch(
                db_get(
                    "SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, photo_start, photo_end FROM NESTS"
                ),
                error = function(e) NULL
            )
            if (!is.null(ref_nests) && nrow(ref_nests) > 0) {
                ref_bits[[length(ref_bits) + 1]] <- expand_recs(
                    as.data.table(ref_nests),
                    table_name = "NESTS"
                )
            }
            ref_caps <- tryCatch(
                db_get(
                    "SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, age, photo_start, photo_end FROM CAPTURES"
                ),
                error = function(e) NULL
            )
            if (!is.null(ref_caps) && nrow(ref_caps) > 0) {
                ref_bits[[length(ref_bits) + 1]] <- expand_recs(
                    as.data.table(ref_caps),
                    table_name = "CAPTURES"
                )
            }
            ref_res <- tryCatch(
                db_get(
                    "SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, rclass, age, photo_start, photo_end FROM RESIGHTINGS"
                ),
                error = function(e) NULL
            )
            if (!is.null(ref_res) && nrow(ref_res) > 0) {
                ref_bits[[length(ref_bits) + 1]] <- expand_recs(
                    as.data.table(ref_res),
                    table_name = "RESIGHTINGS"
                )
            }
            src <- if (length(ref_bits) == 0) {
                data.table(
                    table_name = character(),
                    rowid = integer(),
                    img_num = integer(),
                    cam_key = character(),
                    date_key = character(),
                    observer_key = character(),
                    nest_key = character(),
                    gps_id_key = character(),
                    gps_point_key = character(),
                    rclass_key = character(),
                    age_key = character(),
                    pk_key = character()
                )
            } else {
                rbindlist(ref_bits, use.names = TRUE, fill = TRUE)
            }
            batch_dups <- integer()
            if (nrow(now_seq) > 1) {
                for (i in seq_len(nrow(now_seq))) {
                    hits <- which(
                        now_seq$img_num == now_seq$img_num[i] &
                            now_seq$rowid != now_seq$rowid[i]
                    )
                    if (length(hits) > 0) {
                        for (j in hits) {
                            if (pic_conflict(now_seq[i], now_seq[j])) {
                                batch_dups <- c(
                                    batch_dups,
                                    now_seq$rowid[i],
                                    now_seq$rowid[j]
                                )
                            }
                        }
                    }
                }
            }
            stored_dups <- integer()
            if (nrow(src) > 0) {
                for (i in seq_len(nrow(now_seq))) {
                    hits <- which(src$img_num == now_seq$img_num[i])
                    if (length(hits) > 0) {
                        for (j in hits) {
                            if (pic_conflict(now_seq[i], src[j])) {
                                stored_dups <- c(stored_dups, now_seq$rowid[i])
                            }
                        }
                    }
                }
            }
            flagged_rows <- sort(unique(c(batch_dups, stored_dups)))
            if (!length(flagged_rows)) {
                none
            } else {
                data.table(
                    rowid = flagged_rows,
                    variable = "photo_start",
                    reason = "Photo range overlaps another event; sharing allowed within one age-C H brood session."
                )
            }
        }
    } |>
        try_validator(nam = "val52"),

    # Check NEST in use.
    {
        none <- data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        )
        dat <- copy(x)
        dat[, let(rowid, .I)]
        state_key <- (dat$nest_state |> as.character() |> str_trim())
        discovery_i <- which(!is.na(state_key) & state_key %in% c("S", "F"))
        if (length(discovery_i) == 0) {
            none
        } else {
            dat <- dat[discovery_i]
            dat[, let(
                nest_key = (nest_id |> as.character() |> str_trim()),
                event_date = (date |> as.Date()),
                event_time = (time_visit |> as.character() |> str_trim())
            )]
            id_pat <- "^([ABC]|BA)([0-9]{2})([0-9]{2})$"
            ok_now <- !is.na(dat$nest_key) &
                (dat$nest_key |> str_detect(id_pat)) %in% TRUE
            current <- dat[
                which(ok_now),
                .(rowid, nest_key, event_date, event_time)
            ]
            if (nrow(current) == 0) {
                none
            } else {
                current[, let(
                    prefix = (nest_key |> str_replace(id_pat, "\\1")),
                    gps_code = (nest_key |> str_replace(id_pat, "\\2")),
                    tally = (nest_key |>
                        str_replace(id_pat, "\\3") |>
                        as.integer())
                )]
                current[
                    is.na(event_time) | event_time == "",
                    let(event_time, "99:99")
                ]
                setorderv(
                    current,
                    c("event_date", "event_time", "rowid"),
                    na.last = TRUE
                )
                opts <- current[, .SD[1], by = nest_key]
                existing0 <- tryCatch(
                    db_get("SELECT nest_id, nest_state FROM NESTS"),
                    error = function(e) NULL
                )
                existing <- data.table(
                    gps_code = character(),
                    tally = integer()
                )
                existing_exact <- character()
                if (!is.null(existing0) && nrow(existing0) > 0) {
                    existing_raw <- as.data.table(existing0)
                    existing_raw[, let(
                        nest_key,
                        (nest_id |> as.character() |> str_trim())
                    )]
                    existing_exact <- unique(existing_raw[
                        !is.na(nest_key) & nzchar(nest_key),
                        nest_key
                    ])
                    ok_existing <- !is.na(existing_raw$nest_key) &
                        (existing_raw$nest_key |> str_detect(id_pat)) %in%
                            TRUE
                    existing_raw <- existing_raw[which(
                        ok_existing &
                            (nest_state |> as.character() |> str_trim()) %in%
                                c("S", "F")
                    )]
                    if (nrow(existing_raw) > 0) {
                        existing <- unique(existing_raw[, .(
                            gps_code = (nest_key |> str_replace(id_pat, "\\2")),
                            tally = (nest_key |>
                                str_replace(id_pat, "\\3") |>
                                as.integer())
                        )])
                    }
                }
                opts <- opts[!nest_key %in% existing_exact]
                if (nrow(opts) == 0) {
                    none
                } else {
                    seen <- copy(existing)
                    errs <- vector("list", nrow(opts))
                    for (i in seq_len(nrow(opts))) {
                        option <- opts[i]
                        same_tally <- seen[
                            gps_code == option$gps_code & tally == option$tally
                        ]
                        if (nrow(same_tally) > 0) {
                            used_tallies <- seen[
                                gps_code == option$gps_code,
                                tally
                            ]
                            next_tally <- if (length(used_tallies) == 0) {
                                1
                            } else {
                                max(used_tallies) + 1
                            }
                            next_id <- if (next_tally <= 99) {
                                paste0(
                                    option$prefix,
                                    option$gps_code,
                                    sprintf("%02d", next_tally)
                                )
                            } else {
                                NA_character_
                            }
                            errs[[i]] <- data.table(
                                nest_key = option$nest_key,
                                reason = if (is.na(next_id)) {
                                    paste0(
                                        "nest_id tally ",
                                        option$gps_code,
                                        sprintf("%02d", option$tally),
                                        " already used; no free two-digit tally for this GPS."
                                    )
                                } else {
                                    paste0(
                                        "nest_id tally ",
                                        option$gps_code,
                                        sprintf("%02d", option$tally),
                                        " already used; suggested tally: ",
                                        next_id,
                                        "."
                                    )
                                }
                            )
                        }
                        seen <- unique(rbindlist(list(
                            seen,
                            option[, .(gps_code, tally)]
                        )))
                    }
                    errs <- Filter(Negate(is.null), errs)
                    if (length(errs) == 0) {
                        none
                    } else {
                        conflicts <- rbindlist(errs, use.names = TRUE)
                        merge(
                            dat[, .(rowid, nest_key)],
                            conflicts,
                            by = "nest_key",
                            all = FALSE,
                            sort = FALSE
                        )[,
                            .(rowid, variable = "nest_id", reason)
                        ]
                    }
                }
            }
        }
    } |>
        try_validator(nam = "val53")
)
