list(
    # Required fields.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        colset <- c(
            "date",
            "caught",
            "species",
            "site",
            "observer",
            "capture_status",
            "capture_method",
            "field_sex",
            "age",
            "ring"
        )
        dat[,
            let(
                (colset),
                lapply(.SD, function(item) {
                    txt <- item |> as.character() |> str_trim()
                    txt[
                        is.na(item) | !nzchar(txt) | txt == "NA"
                    ] <- NA_character_
                    txt
                })
            ),
            .SDcols = colset
        ]
        is.na_validator(
            dat[, c("rowid", colset), with = FALSE],
            reason = "Required."
        )
    } |>
        try_validator(nam = "val1"),

    # Require COMBO.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }

        status <- dat$capture_status |> as.character() |> str_trim()
        status[
            is.na(dat$capture_status) | !nzchar(status) | status == "NA"
        ] <- NA_character_
        dat <- dat[which(status != "D")]
        colset <- c("UL", "LL", "UR", "LR")
        dat[,
            let(
                (colset),
                lapply(.SD, function(item) {
                    txt <- item |> as.character() |> str_trim()
                    txt[
                        is.na(item) | !nzchar(txt) | txt == "NA"
                    ] <- NA_character_
                    txt
                })
            ),
            .SDcols = colset
        ]
        is.na_validator(
            dat[, c("rowid", colset), with = FALSE],
            reason = "Required."
        )
    } |>
        try_validator(nam = "val2"),

    # Require a nest or brood for first chick captures.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is_blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | txt == "NA"
        }
        status_txt <- (dat$capture_status |> as.character() |> str_trim())
        status_txt[
            is.na(dat$capture_status) | !nzchar(status_txt) | status_txt == "NA"
        ] <- NA_character_
        age_txt <- (dat$age |> as.character() |> str_trim())
        age_txt[
            is.na(dat$age) | !nzchar(age_txt) | age_txt == "NA"
        ] <- NA_character_
        nest_key <- (dat$nest_id |> as.character() |> str_trim())
        nest_linked <- !is_blank(dat$nest_id) &
            (nest_key |> toupper()) != "NO_NEST" &
            !(nest_key |> str_detect("^-")) %in%
                TRUE
        unknown_brood <- !is_blank(dat$nest_id) &
            (nest_key |> str_detect("^-")) %in% TRUE
        first_chick <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "F"
        has_brood_link <- nest_linked | unknown_brood
        dat[
            which(first_chick & !has_brood_link),
            .(
                rowid,
                variable = "nest_id",
                reason = "Age-C status F requires a positive or negative nest_id."
            )
        ]
    } |>
        try_validator(nam = "val3"),

    # Require gps_id for negative brood.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is_blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | txt == "NA"
        }
        status_txt <- (dat$capture_status |> as.character() |> str_trim())
        status_txt[
            is.na(dat$capture_status) | !nzchar(status_txt) | status_txt == "NA"
        ] <- NA_character_
        age_txt <- (dat$age |> as.character() |> str_trim())
        age_txt[
            is.na(dat$age) | !nzchar(age_txt) | age_txt == "NA"
        ] <- NA_character_
        caught_with_txt <- (dat$caught_with |> as.character() |> str_trim())
        caught_with_txt[
            is.na(dat$caught_with) |
                !nzchar(caught_with_txt) |
                caught_with_txt == "NA"
        ] <- NA_character_
        nest_key <- (dat$nest_id |> as.character() |> str_trim())
        nest_linked <- !is_blank(dat$nest_id) &
            (nest_key |> toupper()) != "NO_NEST" &
            !(nest_key |> str_detect("^-")) %in%
                TRUE
        unknown_brood <- !is_blank(dat$nest_id) &
            (nest_key |> str_detect("^-")) %in% TRUE
        first_chick <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "F"
        chk_recap <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "R"
        chick_reband <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "C"
        adult_with_brood <- !is.na(age_txt) &
            (age_txt |> toupper()) == "A" &
            !is.na(caught_with_txt) &
            (caught_with_txt |> str_detect("(^|,)\\s*[0-9]*C\\s*(,|$)")) %in%
                TRUE
        adult_brood_link <- nest_linked &
            adult_with_brood
        gps_req <- (!nest_linked & !first_chick) |
            chk_recap |
            chick_reband |
            unknown_brood |
            adult_brood_link
        dat[
            which(gps_req & is_blank(dat$gps_id) & unknown_brood),
            .(
                rowid,
                variable = "gps_id",
                reason = "Negative nest_id requires gps_id and gps_point."
            )
        ]
    } |>
        try_validator(nam = "val4"),

    # Require gps_id for adult with chicks.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is_blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | txt == "NA"
        }
        status_txt <- (dat$capture_status |> as.character() |> str_trim())
        status_txt[
            is.na(dat$capture_status) | !nzchar(status_txt) | status_txt == "NA"
        ] <- NA_character_
        age_txt <- (dat$age |> as.character() |> str_trim())
        age_txt[
            is.na(dat$age) | !nzchar(age_txt) | age_txt == "NA"
        ] <- NA_character_
        caught_with_txt <- (dat$caught_with |> as.character() |> str_trim())
        caught_with_txt[
            is.na(dat$caught_with) |
                !nzchar(caught_with_txt) |
                caught_with_txt == "NA"
        ] <- NA_character_
        nest_key <- (dat$nest_id |> as.character() |> str_trim())
        nest_linked <- !is_blank(dat$nest_id) &
            (nest_key |> toupper()) != "NO_NEST" &
            !(nest_key |> str_detect("^-")) %in%
                TRUE
        unknown_brood <- !is_blank(dat$nest_id) &
            (nest_key |> str_detect("^-")) %in% TRUE
        first_chick <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "F"
        chk_recap <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "R"
        chick_reband <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "C"
        adult_with_brood <- !is.na(age_txt) &
            (age_txt |> toupper()) == "A" &
            !is.na(caught_with_txt) &
            (caught_with_txt |> str_detect("(^|,)\\s*[0-9]*C\\s*(,|$)")) %in%
                TRUE
        adult_brood_link <- nest_linked &
            adult_with_brood
        gps_req <- (!nest_linked & !first_chick) |
            chk_recap |
            chick_reband |
            unknown_brood |
            adult_brood_link
        dat[
            which(
                gps_req &
                    is_blank(dat$gps_id) &
                    adult_brood_link
            ),
            .(
                rowid,
                variable = "gps_id",
                reason = "Adult with chicks requires both GPS fields."
            )
        ]
    } |>
        try_validator(nam = "val5"),

    # Require gps_id for chick recapture or remarking.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is_blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | txt == "NA"
        }
        status_txt <- (dat$capture_status |> as.character() |> str_trim())
        status_txt[
            is.na(dat$capture_status) | !nzchar(status_txt) | status_txt == "NA"
        ] <- NA_character_
        age_txt <- (dat$age |> as.character() |> str_trim())
        age_txt[
            is.na(dat$age) | !nzchar(age_txt) | age_txt == "NA"
        ] <- NA_character_
        caught_with_txt <- (dat$caught_with |> as.character() |> str_trim())
        caught_with_txt[
            is.na(dat$caught_with) |
                !nzchar(caught_with_txt) |
                caught_with_txt == "NA"
        ] <- NA_character_
        nest_key <- (dat$nest_id |> as.character() |> str_trim())
        nest_linked <- !is_blank(dat$nest_id) &
            (nest_key |> toupper()) != "NO_NEST" &
            !(nest_key |> str_detect("^-")) %in%
                TRUE
        unknown_brood <- !is_blank(dat$nest_id) &
            (nest_key |> str_detect("^-")) %in% TRUE
        first_chick <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "F"
        chk_recap <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "R"
        chick_reband <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "C"
        adult_with_brood <- !is.na(age_txt) &
            (age_txt |> toupper()) == "A" &
            !is.na(caught_with_txt) &
            (caught_with_txt |> str_detect("(^|,)\\s*[0-9]*C\\s*(,|$)")) %in%
                TRUE
        adult_brood_link <- nest_linked &
            adult_with_brood
        gps_req <- (!nest_linked & !first_chick) |
            chk_recap |
            chick_reband |
            unknown_brood |
            adult_brood_link
        dat[
            which(
                gps_req &
                    is_blank(dat$gps_id) &
                    (chk_recap | chick_reband)
            ),
            .(
                rowid,
                variable = "gps_id",
                reason = "Age-C R/C requires both GPS fields, including with nest_id."
            )
        ]
    } |>
        try_validator(nam = "val6"),

    # Require gps_id for unlinked capture.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is_blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | txt == "NA"
        }
        status_txt <- (dat$capture_status |> as.character() |> str_trim())
        status_txt[
            is.na(dat$capture_status) | !nzchar(status_txt) | status_txt == "NA"
        ] <- NA_character_
        age_txt <- (dat$age |> as.character() |> str_trim())
        age_txt[
            is.na(dat$age) | !nzchar(age_txt) | age_txt == "NA"
        ] <- NA_character_
        caught_with_txt <- (dat$caught_with |> as.character() |> str_trim())
        caught_with_txt[
            is.na(dat$caught_with) |
                !nzchar(caught_with_txt) |
                caught_with_txt == "NA"
        ] <- NA_character_
        nest_key <- (dat$nest_id |> as.character() |> str_trim())
        nest_linked <- !is_blank(dat$nest_id) &
            (nest_key |> toupper()) != "NO_NEST" &
            !(nest_key |> str_detect("^-")) %in%
                TRUE
        unknown_brood <- !is_blank(dat$nest_id) &
            (nest_key |> str_detect("^-")) %in% TRUE
        first_chick <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "F"
        chk_recap <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "R"
        chick_reband <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "C"
        adult_with_brood <- !is.na(age_txt) &
            (age_txt |> toupper()) == "A" &
            !is.na(caught_with_txt) &
            (caught_with_txt |> str_detect("(^|,)\\s*[0-9]*C\\s*(,|$)")) %in%
                TRUE
        adult_brood_link <- nest_linked &
            adult_with_brood
        gps_req <- (!nest_linked & !first_chick) |
            chk_recap |
            chick_reband |
            unknown_brood |
            adult_brood_link
        dat[
            which(
                gps_req &
                    is_blank(dat$gps_id) &
                    !(unknown_brood |
                        adult_brood_link |
                        chk_recap |
                        chick_reband)
            ),
            .(
                rowid,
                variable = "gps_id",
                reason = "Enter gps_id and gps_point without a positive nest link."
            )
        ]
    } |>
        try_validator(nam = "val7"),

    # Require gps_point for negative brood.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is_blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | txt == "NA"
        }
        status_txt <- (dat$capture_status |> as.character() |> str_trim())
        status_txt[
            is.na(dat$capture_status) | !nzchar(status_txt) | status_txt == "NA"
        ] <- NA_character_
        age_txt <- (dat$age |> as.character() |> str_trim())
        age_txt[
            is.na(dat$age) | !nzchar(age_txt) | age_txt == "NA"
        ] <- NA_character_
        caught_with_txt <- (dat$caught_with |> as.character() |> str_trim())
        caught_with_txt[
            is.na(dat$caught_with) |
                !nzchar(caught_with_txt) |
                caught_with_txt == "NA"
        ] <- NA_character_
        nest_key <- (dat$nest_id |> as.character() |> str_trim())
        nest_linked <- !is_blank(dat$nest_id) &
            (nest_key |> toupper()) != "NO_NEST" &
            !(nest_key |> str_detect("^-")) %in%
                TRUE
        unknown_brood <- !is_blank(dat$nest_id) &
            (nest_key |> str_detect("^-")) %in% TRUE
        first_chick <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "F"
        chk_recap <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "R"
        chick_reband <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "C"
        adult_with_brood <- !is.na(age_txt) &
            (age_txt |> toupper()) == "A" &
            !is.na(caught_with_txt) &
            (caught_with_txt |> str_detect("(^|,)\\s*[0-9]*C\\s*(,|$)")) %in%
                TRUE
        adult_brood_link <- nest_linked &
            adult_with_brood
        gps_req <- (!nest_linked & !first_chick) |
            chk_recap |
            chick_reband |
            unknown_brood |
            adult_brood_link
        dat[
            which(
                gps_req & is_blank(dat$gps_point) & unknown_brood
            ),
            .(
                rowid,
                variable = "gps_point",
                reason = "Negative nest_id requires gps_id and gps_point."
            )
        ]
    } |>
        try_validator(nam = "val8"),

    # Require gps_point for chick recapture or remarking.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is_blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | txt == "NA"
        }
        status_txt <- (dat$capture_status |> as.character() |> str_trim())
        status_txt[
            is.na(dat$capture_status) | !nzchar(status_txt) | status_txt == "NA"
        ] <- NA_character_
        age_txt <- (dat$age |> as.character() |> str_trim())
        age_txt[
            is.na(dat$age) | !nzchar(age_txt) | age_txt == "NA"
        ] <- NA_character_
        caught_with_txt <- (dat$caught_with |> as.character() |> str_trim())
        caught_with_txt[
            is.na(dat$caught_with) |
                !nzchar(caught_with_txt) |
                caught_with_txt == "NA"
        ] <- NA_character_
        nest_key <- (dat$nest_id |> as.character() |> str_trim())
        nest_linked <- !is_blank(dat$nest_id) &
            (nest_key |> toupper()) != "NO_NEST" &
            !(nest_key |> str_detect("^-")) %in%
                TRUE
        unknown_brood <- !is_blank(dat$nest_id) &
            (nest_key |> str_detect("^-")) %in% TRUE
        first_chick <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "F"
        chk_recap <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "R"
        chick_reband <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "C"
        adult_with_brood <- !is.na(age_txt) &
            (age_txt |> toupper()) == "A" &
            !is.na(caught_with_txt) &
            (caught_with_txt |> str_detect("(^|,)\\s*[0-9]*C\\s*(,|$)")) %in%
                TRUE
        adult_brood_link <- nest_linked &
            adult_with_brood
        gps_req <- (!nest_linked & !first_chick) |
            chk_recap |
            chick_reband |
            unknown_brood |
            adult_brood_link
        dat[
            which(
                gps_req &
                    is_blank(dat$gps_point) &
                    (chk_recap | chick_reband)
            ),
            .(
                rowid,
                variable = "gps_point",
                reason = "Age-C R/C requires both GPS fields, including with nest_id."
            )
        ]
    } |>
        try_validator(nam = "val9"),

    # Require gps_point for unlinked capture.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is_blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | txt == "NA"
        }
        status_txt <- (dat$capture_status |> as.character() |> str_trim())
        status_txt[
            is.na(dat$capture_status) | !nzchar(status_txt) | status_txt == "NA"
        ] <- NA_character_
        age_txt <- (dat$age |> as.character() |> str_trim())
        age_txt[
            is.na(dat$age) | !nzchar(age_txt) | age_txt == "NA"
        ] <- NA_character_
        caught_with_txt <- (dat$caught_with |> as.character() |> str_trim())
        caught_with_txt[
            is.na(dat$caught_with) |
                !nzchar(caught_with_txt) |
                caught_with_txt == "NA"
        ] <- NA_character_
        nest_key <- (dat$nest_id |> as.character() |> str_trim())
        nest_linked <- !is_blank(dat$nest_id) &
            (nest_key |> toupper()) != "NO_NEST" &
            !(nest_key |> str_detect("^-")) %in%
                TRUE
        unknown_brood <- !is_blank(dat$nest_id) &
            (nest_key |> str_detect("^-")) %in% TRUE
        first_chick <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "F"
        chk_recap <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "R"
        chick_reband <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "C"
        adult_with_brood <- !is.na(age_txt) &
            (age_txt |> toupper()) == "A" &
            !is.na(caught_with_txt) &
            (caught_with_txt |> str_detect("(^|,)\\s*[0-9]*C\\s*(,|$)")) %in%
                TRUE
        adult_brood_link <- nest_linked &
            adult_with_brood
        gps_req <- (!nest_linked & !first_chick) |
            chk_recap |
            chick_reband |
            unknown_brood |
            adult_brood_link
        dat[
            which(
                gps_req &
                    is_blank(dat$gps_point) &
                    !(unknown_brood |
                        adult_brood_link |
                        chk_recap |
                        chick_reband)
            ),
            .(
                rowid,
                variable = "gps_point",
                reason = "Enter gps_id and gps_point without a positive nest link."
            )
        ]
    } |>
        try_validator(nam = "val10"),

    # Use the nest location when direct gps_point is not allowed.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is_blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | txt == "NA"
        }
        status_txt <- (dat$capture_status |> as.character() |> str_trim())
        status_txt[
            is.na(dat$capture_status) | !nzchar(status_txt) | status_txt == "NA"
        ] <- NA_character_
        age_txt <- (dat$age |> as.character() |> str_trim())
        age_txt[
            is.na(dat$age) | !nzchar(age_txt) | age_txt == "NA"
        ] <- NA_character_
        caught_with_txt <- (dat$caught_with |> as.character() |> str_trim())
        caught_with_txt[
            is.na(dat$caught_with) |
                !nzchar(caught_with_txt) |
                caught_with_txt == "NA"
        ] <- NA_character_
        nest_key <- (dat$nest_id |> as.character() |> str_trim())
        nest_linked <- !is_blank(dat$nest_id) &
            (nest_key |> toupper()) != "NO_NEST" &
            !(nest_key |> str_detect("^-")) %in%
                TRUE
        first_chick <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "F"
        chk_recap <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "R"
        chick_reband <- !is.na(age_txt) &
            (age_txt |> toupper()) == "C" &
            status_txt == "C"
        adult_with_brood <- !is.na(age_txt) &
            (age_txt |> toupper()) == "A" &
            !is.na(caught_with_txt) &
            (caught_with_txt |> str_detect("(^|,)\\s*[0-9]*C\\s*(,|$)")) %in%
                TRUE
        nest_gps_ok <- nest_linked &
            (first_chick |
                chk_recap |
                chick_reband |
                adult_with_brood)
        gps_id_set <- !is_blank(dat$gps_id)
        gps_point_set <- !is_blank(dat$gps_point)
        has_any_gps <- gps_id_set | gps_point_set
        dat[
            which(
                nest_linked &
                    has_any_gps &
                    !nest_gps_ok &
                    gps_point_set
            ),
            .(
                rowid,
                variable = "gps_point",
                reason = "Positive nest: usually blank GPS; adult with chicks needs both GPS fields and caught_with."
            )
        ]
    } |>
        try_validator(nam = "val11"),

    # Check release leg-mark characters.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is.regexp_validator(
            dat[, .(rowid, UL, LL, UR, LR)],
            regexp = "^[^?,]*$",
            reason = "Invalid leg-mark characters."
        )
    } |>
        try_validator(nam = "val12"),

    # Check the metal-ring format.
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
        ring_key <- (dat$ring |> as.character() |> str_trim())
        bad_idx <- which(
            !is.na(dat$ring) &
                nzchar(ring_key) &
                !(ring_key |> str_detect("^CP-?[0-9]{5}$")) %in% TRUE
        )
        if (length(bad_idx) == 0) {
            none
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "ring",
                reason = "Use CP plus 5 digits, w dash."
            )
        }
    } |>
        try_validator(nam = "val13"),

    # Age-A captures using capture_method HA require a positive nest_id.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is_blank <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            is.na(v) | !nzchar(txt) | (txt |> toupper()) == "NA"
        }
        age_key <- (dat$age |> as.character() |> str_trim() |> toupper())
        method_key <- (dat$capture_method |>
            as.character() |>
            str_trim() |>
            toupper())
        ha_ad <- !is.na(age_key) &
            age_key == "A" &
            !is.na(method_key) &
            method_key == "HA"
        pos_nest <- !is_blank(dat$nest_id) &
            (dat$nest_id |> as.character() |> str_trim() |> toupper()) !=
                "NO_NEST" &
            !(dat$nest_id |>
                as.character() |>
                str_trim() |>
                str_detect("^-")) %in%
                TRUE
        nest_bad <- ha_ad & !pos_nest
        dat[
            nest_bad,
            .(
                rowid,
                variable = "nest_id",
                reason = "Age-A captures using capture_method HA require a positive nest_id."
            )
        ]
    } |>
        try_validator(nam = "val14"),

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
                reason = "Date not in 2026–2027 season."
            )
        }
    } |>
        try_validator(nam = "val15"),

    # Check the site code.
    {
        dat <- copy(x)
        dat[, let(rowid, .I)]
        is.element_validator(
            dat[!is.na(site), .(site, rowid)],
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
        try_validator(nam = "val16"),

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
                        reason = "GPS  missing from GPS_POINTS "
                    )]
                }
            }
        }
    } |>
        try_validator(nam = "val17"),

    # Keep the validation flag blank.
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
        if (!"nov" %in% names(dat)) {
            none
        } else {
            res <- dat[
                !is.na(nov),
                .(rowid, variable = "nov", reason = "Leave blank.")
            ]
            if (nrow(res) == 0) {
                none
            } else {
                unique(res)
            }
        }
    } |>
        try_validator(nam = "val18"),

    # Check book, form, and event uniqueness.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        res <- rbindlist(
            list(
                dat[
                    is.na(book_id) | !(book_id %in% 1:5),
                    .(rowid, variable = "book_id", reason = "Use book_id 1–5.")
                ],
                dat[
                    is.na(form_id) | form_id < 1,
                    .(
                        rowid,
                        variable = "form_id",
                        reason = "Use a positive integer."
                    )
                ]
            ),
            use.names = TRUE,
            fill = TRUE
        )
        dup <- dat[
            !is.na(book_id) & !is.na(form_id),
            .N,
            by = .(book_id, form_id)
        ][N > 1]
        if (nrow(dup) > 0) {
            res <- rbindlist(
                list(
                    res,
                    merge(dat, dup, by = c("book_id", "form_id"))[, .(
                        rowid,
                        variable = "form_id",
                        reason = "Each [book_id, form_id] pair must represent only one capture event."
                    )]
                ),
                use.names = TRUE,
                fill = TRUE
            )
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
        try_validator(nam = "val20"),

    # Released must be blank when capture_status is D.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                status_v <- one_txt(rec$capture_status)
                released_raw <- one_txt(rec$released)
                if (identical(status_v, "D")) {
                    if (!is.na(released_raw)) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "released",
                            reason = "Released must be blank when capture_status is D."
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
        try_validator(nam = "val21"),

    # Caught must be before released.
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
        to_mins <- function(v) {
            txt <- one_txt(v)
            if (is.na(txt)) {
                return(NA_real_)
            }
            txt <- substr(txt, 1, 5)
            if (!(txt |> str_detect("^\\d{2}:\\d{2}$")) %in% TRUE) {
                return(NA_real_)
            }
            hh <- (substr(txt, 1, 2) |> as.integer())
            mm <- (substr(txt, 4, 5) |> as.integer())
            if (
                is.na(hh) || is.na(mm) || hh < 0 || hh > 23 || mm < 0 || mm > 59
            ) {
                return(NA_real_)
            }
            hh * 60 + mm
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                status_v <- one_txt(rec$capture_status)
                caught_t <- to_mins(rec$caught)
                rel_t <- to_mins(rec$released)
                if (!identical(status_v, "D")) {
                    if (
                        !is.na(caught_t) && !is.na(rel_t) && caught_t >= rel_t
                    ) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "released",
                            reason = "Caught must be before released."
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
        try_validator(nam = "val22"),

    # Check capture_status.
    {
        dat <- x[, .(capture_status)]
        is.element_validator(
            dat,
            v = data.table(
                variable = "capture_status",
                set = list(c(
                    "F",
                    "R",
                    "C",
                    "D"
                ))
            ),
            reason = "Use F, R, C, or D."
        )
    } |>
        try_validator(nam = "val23"),

    # Check nest links required by capture method.
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
        is_pos_nest <- function(v) {
            !is.na(v) &&
                nzchar(v) &&
                (v |> toupper()) != "NO_NEST" &&
                !(v |> str_detect("^-")) %in%
                    TRUE
        }
        is_real_nest <- function(v) {
            !is.na(v) && nzchar(v) && (v |> toupper()) != "NO_NEST"
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                method_v <- one_txt(rec$capture_method)
                nest_v <- one_txt(rec$nest_id)
                if (is.na(method_v)) {
                    return(none)
                }
                if (identical(method_v, "TN") && !is_pos_nest(nest_v)) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "capture_method",
                        reason = "capture_method TN requires a positive nest_id."
                    ))
                }
                if (identical(method_v, "TB") && !is_real_nest(nest_v)) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "capture_method",
                        reason = "Method TB requires a positive or negative nest_id."
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
        try_validator(nam = "val24"),

    # Check the nest or brood identifier.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        cr_pos <- "^[ABC][0-9]{4}$"
        noncr_pos <- "^BA[0-9]{4}$"
        cr_neg <- "^-[ABC][0-9]{4}$"
        noncr_neg <- "^-BA[0-9]{4}$"
        nest_txt <- (dat$nest_id |> as.character() |> str_trim())
        no_nest_i <- which(
            !is.na(dat$nest_id) &
                nzchar(nest_txt) &
                (nest_txt |> toupper()) == "NO_NEST"
        )
        bad_idx <- which(
            !is.na(dat$nest_id) &
                nzchar(nest_txt) &
                (nest_txt |> toupper()) != "NO_NEST" &
                !((dat$site == "CR" &
                    (nest_txt |> str_detect(cr_pos)) %in% TRUE &
                    !(nest_txt |> str_detect("^-")) %in% TRUE) |
                    (dat$site == "CR" &
                        (nest_txt |> str_detect(cr_neg)) %in% TRUE) |
                    (dat$site != "CR" &
                        (nest_txt |> str_detect(noncr_pos)) %in%
                            TRUE &
                        !(nest_txt |> str_detect("^-")) %in% TRUE) |
                    (dat$site != "CR" &
                        (nest_txt |> str_detect(noncr_neg)) %in%
                            TRUE))
        )
        bad_i <- sort(unique(c(no_nest_i, bad_idx)))
        if (length(bad_i) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            data.table(
                rowid = dat$rowid[bad_i],
                variable = "nest_id",
                reason = ifelse(
                    bad_i %in%
                        no_nest_i,
                    "NO_NEST is invalid; use a valid nest_id or blank with both GPS fields.",
                    "nest_id must be blank or match the current site-specific positive/negative nest_id format."
                )
            )
        }
    } |>
        try_validator(nam = "val25"),

    # Check field_sex against age.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        bad_idx <- dat[
            (age %in% c("C", "J") & field_sex != "U") |
                (age == "A" &
                    !(field_sex %in%
                        c("M", "MU", "F", "FU"))),
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
                variable = "field_sex",
                reason = "field_sex must follow the age-specific coding rule."
            )
        }
    } |>
        try_validator(nam = "val26"),

    # First-marking captures must have all input band positions set to X or left blank.
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
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks_first <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = "X"
                )
                names(in_marks_first) <- c(
                    "UL_in",
                    "LL_in",
                    "UR_in",
                    "LR_in"
                )
                in_all_x <- all(in_marks_first == "X")
                status_v <- one_txt(rec$capture_status)
                if (identical(status_v, "F")) {
                    if (!in_all_x) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "UL_in",
                            reason = "First-marking captures must have all input band positions set to X or left blank."
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
        try_validator(nam = "val27"),

    # First-marking captures must not leave all release band positions as X.
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
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                rel_all_x <- all(
                    replace(rel_marks, is.na(rel_marks), "") == "X"
                )
                status_v <- one_txt(rec$capture_status)
                if (identical(status_v, "F")) {
                    if (rel_all_x) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "UL",
                            reason = "First-marking captures must not leave all release band positions as X."
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
        try_validator(nam = "val28"),

    # Statuses R and C require all input and release band positions to be entered.
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
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                status_v <- one_txt(rec$capture_status)
                if (
                    status_v %in%
                        c("R", "C") &&
                        (any(is.na(in_marks)) || any(is.na(rel_marks)))
                ) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "UL_in",
                        reason = "Statuses R and C require all input and release band positions to be entered."
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
        try_validator(nam = "val29"),

    # Check capture, release, age, and tag marks.
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
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        clean_ring <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res %in% c("", "NA")] <- NA_character_
            (res |> toupper())
        }
        old_ring_ids <- tryCatch(
            clean_ring(
                as.data.table(db_get("SELECT ring FROM CAPTURES_ARCHIVE"))$ring
            ),
            error = function(e) character()
        )
        now_ring_ids <- tryCatch(
            clean_ring(
                as.data.table(db_get("SELECT ring FROM CAPTURES"))$ring
            ),
            error = function(e) character()
        )
        recap_ring_ids <- unique(c(
            old_ring_ids[!is.na(old_ring_ids)],
            now_ring_ids[!is.na(now_ring_ids)]
        ))
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                status_v <- one_txt(rec$capture_status)
                r_mark_mismatch <- any(
                    !is.na(in_marks) &
                        (is.na(rel_marks) | in_marks != rel_marks)
                )
                if (identical(status_v, "R") && r_mark_mismatch) {
                    ring_key <- clean_ring(rec$ring)[[1]]
                    ring_has_hist <- !is.na(ring_key) &&
                        ring_key %in% recap_ring_ids
                    return(data.table(
                        rowid = rec$rowid,
                        variable = if (ring_has_hist) {
                            "capture_status"
                        } else {
                            "UL"
                        },
                        reason = if (ring_has_hist) {
                            "Bands changed; use capture_status C."
                        } else {
                            "Recaptures with status R must keep the same band positions before and after handling."
                        }
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
        try_validator(nam = "val30"),

    # Status C requires at least one non-X input mark before the release combo is changed.
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
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks_first <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = "X"
                )
                names(in_marks_first) <- c(
                    "UL_in",
                    "LL_in",
                    "UR_in",
                    "LR_in"
                )
                in_all_x <- all(in_marks_first == "X")
                status_v <- one_txt(rec$capture_status)
                if (identical(status_v, "C") && in_all_x) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "UL_in",
                        reason = "Status C requires at least one non-X input mark before the release combo is changed."
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
        try_validator(nam = "val31"),

    # Status C requires at least one change between input and release band positions.
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
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                same_combo <- identical(
                    unname(in_marks),
                    unname(rel_marks)
                )
                status_v <- one_txt(rec$capture_status)
                if (
                    identical(status_v, "C") &&
                        !any(is.na(in_marks)) &&
                        !any(is.na(rel_marks)) &&
                        same_combo
                ) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "UL",
                        reason = "Status C requires at least one change between input and release band positions."
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
        try_validator(nam = "val32"),

    # Dead-on-capture rows must record the recovered combo in all input band positions.
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
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                status_v <- one_txt(rec$capture_status)
                if (identical(status_v, "D")) {
                    if (any(is.na(in_marks))) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "UL_in",
                            reason = "Dead-on-capture rows must record the recovered combo in all input band positions."
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

    # Dead-on-capture rows must leave all release band positions blank.
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
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                status_v <- one_txt(rec$capture_status)
                if (identical(status_v, "D")) {
                    if (any(!is.na(rel_marks))) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "UL",
                            reason = "Dead-on-capture rows must leave all release band positions blank."
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

    # Only one T allowed across upper leg positions.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        tag_count <- function(left_code, right_code) {
            sum(vapply(c(left_code, right_code), has_upper_tag, logical(1)))
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                if (
                    tag_count(
                        in_marks["UL_in"],
                        in_marks["UR_in"]
                    ) >
                        1
                ) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "UL_in",
                        reason = "Only one T allowed across upper leg positions."
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
        try_validator(nam = "val35"),

    # Only one T allowed across upper leg positions.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        tag_count <- function(left_code, right_code) {
            sum(vapply(c(left_code, right_code), has_upper_tag, logical(1)))
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                if (tag_count(rel_marks["UL"], rel_marks["UR"]) > 1) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "UL",
                        reason = "Only one T allowed across upper leg positions."
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
        try_validator(nam = "val36"),

    # T codes are only allowed in upper leg positions.
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
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                errs <- list()
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                for (nm in c("LL", "LR")) {
                    if (
                        !is.na(rel_marks[nm]) &&
                            (rel_marks[nm] |> str_detect("^T")) %in% TRUE
                    ) {
                        errs[[length(errs) + 1]] <- data.table(
                            rowid = rec$rowid,
                            variable = nm,
                            reason = "T codes are only allowed in upper leg positions."
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
        try_validator(nam = "val37"),

    # Check UL for this capture or observation.
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
        chk_colors <- c("R", "B", "G", "W", "O", "L", "Y")
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        is_blank_band <- function(v) {
            is.na(v) || identical(v, "X")
        }
        is_cr_chk_scheme <- function(ul, ll, ur, lr) {
            is_blank_band(ul) &&
                ll %in% chk_colors &&
                ur == "M" &&
                is_blank_band(lr)
        }
        is_noncr_chk_scheme <- function(ul, ll, ur, lr) {
            ul == "M" &&
                is_blank_band(ll) &&
                is_blank_band(ur) &&
                lr %in% chk_colors
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                rel_marks_scheme <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = "X"
                )
                names(rel_marks_scheme) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                status_v <- one_txt(rec$capture_status)
                site_v <- one_txt(rec$site)
                if (identical(age_v, "C") && status_v %in% c("F", "R")) {
                    chk_ok <- if (identical(site_v, "CR")) {
                        is_cr_chk_scheme(
                            one_txt(rel_marks_scheme["UL"]),
                            one_txt(rel_marks_scheme["LL"]),
                            one_txt(rel_marks_scheme["UR"]),
                            one_txt(rel_marks_scheme["LR"])
                        )
                    } else {
                        is_noncr_chk_scheme(
                            one_txt(rel_marks_scheme["UL"]),
                            one_txt(rel_marks_scheme["LL"]),
                            one_txt(rel_marks_scheme["UR"]),
                            one_txt(rel_marks_scheme["LR"])
                        )
                    }
                    if (!chk_ok || !(status_v %in% c("F", "R"))) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "UL",
                            reason = if (
                                identical(
                                    site_v,
                                    "CR"
                                )
                            ) {
                                "CR chick: one LL colour, UR M, blank UL/LR, status F/R."
                            } else {
                                "Non-CR chick: UL M, one LR colour, blank LL/UR, status F/R."
                            }
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

    # Juvenile: UL flag, UR M, blank LL/LR, status F/C.
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
        juv_flag <- "^FW[A-Z0-9]{2}$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        is_blank_band <- function(v) {
            is.na(v) || identical(v, "X")
        }
        is_juv_scheme <- function(ul, ll, ur, lr) {
            !is.na(ul) &&
                (ul |> str_detect(juv_flag)) %in% TRUE &&
                is_blank_band(ll) &&
                ur == "M" &&
                is_blank_band(lr)
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                rel_marks_scheme <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = "X"
                )
                names(rel_marks_scheme) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                status_v <- one_txt(rec$capture_status)
                if (identical(age_v, "J")) {
                    juv_rel_ok <- is_juv_scheme(
                        one_txt(rel_marks_scheme["UL"]),
                        one_txt(rel_marks_scheme["LL"]),
                        one_txt(rel_marks_scheme["UR"]),
                        one_txt(rel_marks_scheme["LR"])
                    )
                    if (status_v %in% c("F", "C") && !juv_rel_ok) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "UL",
                            reason = "Juvenile: UL flag, UR M, blank LL/LR, status F/C."
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
        try_validator(nam = "val39"),

    # Juvenile F/C: UL flag, UR M, blank LL/LR. Dead D: complete _in combo.
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
        juv_flag <- "^FW[A-Z0-9]{2}$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        is_blank_band <- function(v) {
            is.na(v) || identical(v, "X")
        }
        is_juv_scheme <- function(ul, ll, ur, lr) {
            !is.na(ul) &&
                (ul |> str_detect(juv_flag)) %in% TRUE &&
                is_blank_band(ll) &&
                ur == "M" &&
                is_blank_band(lr)
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                rel_marks_scheme <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = "X"
                )
                names(rel_marks_scheme) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                status_v <- one_txt(rec$capture_status)
                if (identical(age_v, "J")) {
                    juv_rel_ok <- is_juv_scheme(
                        one_txt(rel_marks_scheme["UL"]),
                        one_txt(rel_marks_scheme["LL"]),
                        one_txt(rel_marks_scheme["UR"]),
                        one_txt(rel_marks_scheme["LR"])
                    )
                    if (!(status_v %in% c("F", "C") && !juv_rel_ok)) {
                        if (!(status_v %in% c("F", "C", "D"))) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "UL",
                                reason = "Juvenile F/C: UL flag, UR M, blank LL/LR. Dead D: complete _in combo."
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
        try_validator(nam = "val40"),

    # CR adult LL: YR/YO/YY/GY/BY/WY/OY/LY; status D may leave all marks blank.
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
        cr_ad_ll <- c("YR", "YO", "YY", "GY", "BY", "WY", "OY", "LY")
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                rel_marks_scheme <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = "X"
                )
                names(rel_marks_scheme) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                status_v <- one_txt(rec$capture_status)
                site_v <- one_txt(rec$site)
                if (identical(age_v, "A")) {
                    if (
                        !identical(status_v, "D") &&
                            identical(site_v, "CR") &&
                            !is.na(one_txt(rel_marks_scheme["LL"])) &&
                            !(one_txt(rel_marks_scheme["LL"]) %in%
                                cr_ad_ll)
                    ) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "LL",
                            reason = "CR adult LL: YR/YO/YY/GY/BY/WY/OY/LY; status D may leave all marks blank."
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
        try_validator(nam = "val41"),

    # Non-CR adult LL cannot use YR/YO/YY/GY/BY/WY/OY/LY.
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
        cr_ad_ll <- c("YR", "YO", "YY", "GY", "BY", "WY", "OY", "LY")
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                rel_marks_scheme <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = "X"
                )
                names(rel_marks_scheme) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                status_v <- one_txt(rec$capture_status)
                site_v <- one_txt(rec$site)
                if (identical(age_v, "A")) {
                    if (
                        !identical(status_v, "D") &&
                            !is.na(site_v) &&
                            site_v != "CR" &&
                            !is.na(one_txt(rel_marks_scheme["LL"])) &&
                            one_txt(rel_marks_scheme["LL"]) %in% cr_ad_ll
                    ) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "LL",
                            reason = "Non-CR adult LL cannot use YR/YO/YY/GY/BY/WY/OY/LY."
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
        try_validator(nam = "val42"),

    # Adult captures may not use the chick or juvenile release marking schemes.
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
        chk_colors <- c("R", "B", "G", "W", "O", "L", "Y")
        juv_flag <- "^FW[A-Z0-9]{2}$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        is_blank_band <- function(v) {
            is.na(v) || identical(v, "X")
        }
        is_cr_chk_scheme <- function(ul, ll, ur, lr) {
            is_blank_band(ul) &&
                ll %in% chk_colors &&
                ur == "M" &&
                is_blank_band(lr)
        }
        is_noncr_chk_scheme <- function(ul, ll, ur, lr) {
            ul == "M" &&
                is_blank_band(ll) &&
                is_blank_band(ur) &&
                lr %in% chk_colors
        }
        is_juv_scheme <- function(ul, ll, ur, lr) {
            !is.na(ul) &&
                (ul |> str_detect(juv_flag)) %in% TRUE &&
                is_blank_band(ll) &&
                ur == "M" &&
                is_blank_band(lr)
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                rel_marks_scheme <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = "X"
                )
                names(rel_marks_scheme) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                if (identical(age_v, "A")) {
                    if (
                        is_cr_chk_scheme(
                            one_txt(rel_marks_scheme["UL"]),
                            one_txt(rel_marks_scheme["LL"]),
                            one_txt(rel_marks_scheme["UR"]),
                            one_txt(rel_marks_scheme["LR"])
                        ) ||
                            is_noncr_chk_scheme(
                                one_txt(rel_marks_scheme["UL"]),
                                one_txt(rel_marks_scheme["LL"]),
                                one_txt(rel_marks_scheme["UR"]),
                                one_txt(rel_marks_scheme["LR"])
                            ) ||
                            is_juv_scheme(
                                one_txt(rel_marks_scheme["UL"]),
                                one_txt(rel_marks_scheme["LL"]),
                                one_txt(rel_marks_scheme["UR"]),
                                one_txt(rel_marks_scheme["LR"])
                            )
                    ) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "UL",
                            reason = "Adult captures may not use the chick or juvenile release marking schemes."
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
        try_validator(nam = "val43"),

    # Short UR tag codes such as TY are reserved for GEO tags.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (!identical(tag_type_v, "GEO")) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_type",
                                reason = "Short UR tag codes such as TY are reserved for GEO tags."
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
        try_validator(nam = "val44"),

    # Release GEO tag code requires tag_id.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (rel_geotag && is.na(tag_id_v)) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id",
                                reason = "Release GEO tag code requires tag_id."
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
        try_validator(nam = "val45"),

    # Input GEO tag code requires tag_id_in.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (in_geotag && is.na(tag_id_in_v)) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id_in",
                                reason = "Input GEO tag code requires tag_id_in."
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
        try_validator(nam = "val46"),

    # Release GEO tags must use a short upper-leg T code such as TY.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (
                            identical(tag_type_v, "GEO") &&
                                tag_action_v %in% c("D", "S", "N") &&
                                !rel_geotag
                        ) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "UR",
                                reason = "Release GEO tags must use a short upper-leg T code such as TY."
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
        try_validator(nam = "val47"),

    # Input GEO tags must use a short upper-leg T code such as TY.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (
                            identical(tag_type_v, "GEO") &&
                                tag_action_v %in% c("S", "N", "R") &&
                                !in_geotag
                        ) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "UR_in",
                                reason = "Input GEO tags must use a short upper-leg T code such as TY."
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
        try_validator(nam = "val48"),

    # Release GEO tag codes require tag_action D, S, or N.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (
                            rel_geotag &&
                                !(tag_action_v %in% c("D", "S", "N"))
                        ) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_action",
                                reason = "Release GEO tag codes require tag_action D, S, or N."
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
        try_validator(nam = "val49"),

    # Input GEO tag codes require tag_action S, N, or R.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (
                            in_geotag &&
                                !(tag_action_v %in% c("S", "N", "R"))
                        ) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_action",
                                reason = "Input GEO tag codes require tag_action S, N, or R."
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
        try_validator(nam = "val50"),

    # tag_action D means the bird must not already carry a tag in the input combo.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (identical(tag_action_v, "D")) {
                            if (in_geotag) {
                                return(data.table(
                                    rowid = rec$rowid,
                                    variable = "UR_in",
                                    reason = "tag_action D means the bird must not already carry a tag in the input combo."
                                ))
                            }
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
        try_validator(nam = "val51"),

    # tag_action R means the bird must not retain a tag in the release combo.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (identical(tag_action_v, "R")) {
                            if (rel_geotag) {
                                return(data.table(
                                    rowid = rec$rowid,
                                    variable = "UR",
                                    reason = "tag_action R means the bird must not retain a tag in the release combo."
                                ))
                            }
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
        try_validator(nam = "val52"),

    # tag_action O can only be used when no tag is present at capture or release.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (
                            identical(tag_action_v, "O") &&
                                (!is.na(tag_id_v) ||
                                    !is.na(tag_id_in_v) ||
                                    rel_geotag ||
                                    in_geotag)
                        ) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_action",
                                reason = "tag_action O can only be used when no tag is present at capture or release."
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
        try_validator(nam = "val53"),

    # tag_type must be blank when no tag is present.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (
                            is.na(tag_id_v) &&
                                is.na(tag_id_in_v) &&
                                !rel_geotag &&
                                !in_geotag
                        ) {
                            if (!is.na(tag_type_v)) {
                                return(data.table(
                                    rowid = rec$rowid,
                                    variable = "tag_type",
                                    reason = "tag_type must be blank when no tag is present."
                                ))
                            }
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
        try_validator(nam = "val54"),

    # tag_action must be O when no tag is present.
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
        geotag_upper <- "^T([RBGWOLY])?$"
        clean_tag <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
        has_upper_tag <- function(v) {
            !is.na(v) && (v |> str_detect(geotag_upper)) %in% TRUE
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                band_vec <- function(vals, blank_as = NA_character_) {
                    res <- (vals |> as.character() |> str_trim())
                    res[is.na(res) | res == ""] <- blank_as
                    res <- clean_tag(res)
                    res
                }
                in_marks <- band_vec(
                    unlist(rec[, .(UL_in, LL_in, UR_in, LR_in)]),
                    blank_as = NA_character_
                )
                names(in_marks) <- c("UL_in", "LL_in", "UR_in", "LR_in")
                rel_marks <- band_vec(
                    unlist(rec[, .(UL, LL, UR, LR)]),
                    blank_as = NA_character_
                )
                names(rel_marks) <- c("UL", "LL", "UR", "LR")
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_type_v <- one_txt(rec$tag_type)
                tag_action_v <- one_txt(rec$tag_action)
                rel_ul_tag <- has_upper_tag(one_txt(rel_marks["UL"]))
                rel_ur_tag <- has_upper_tag(one_txt(rel_marks["UR"]))
                in_ul_tag <- has_upper_tag(one_txt(in_marks["UL_in"]))
                in_ur_tag <- has_upper_tag(one_txt(in_marks["UR_in"]))
                rel_geotag <- rel_ul_tag || rel_ur_tag
                in_geotag <- in_ul_tag || in_ur_tag
                tag_involved <- rel_geotag ||
                    in_geotag ||
                    !is.na(tag_id_v) ||
                    !is.na(tag_id_in_v) ||
                    !is.na(tag_action_v) ||
                    !is.na(tag_type_v)
                if (!(age_v %in% c("C", "J") && tag_involved)) {
                    if (rel_geotag || in_geotag) {
                        if (
                            is.na(tag_id_v) &&
                                is.na(tag_id_in_v) &&
                                !rel_geotag &&
                                !in_geotag
                        ) {
                            if (!identical(tag_action_v, "O")) {
                                return(data.table(
                                    rowid = rec$rowid,
                                    variable = "tag_action",
                                    reason = "tag_action must be O when no tag is present."
                                ))
                            }
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
        try_validator(nam = "val55"),

    # tag_action D requires the newly deployed tag in tag_id.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_action_v <- one_txt(rec$tag_action)
                if (identical(age_v, "A")) {
                    if (identical(tag_action_v, "D")) {
                        if (is.na(tag_id_v)) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id",
                                reason = "tag_action D requires the newly deployed tag in tag_id."
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
        try_validator(nam = "val56"),

    # tag_action D requires tag_id_in to be blank.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                age_v <- one_txt(rec$age)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_action_v <- one_txt(rec$tag_action)
                if (identical(age_v, "A")) {
                    if (identical(tag_action_v, "D")) {
                        if (!is.na(tag_id_in_v)) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id_in",
                                reason = "tag_action D requires tag_id_in to be blank."
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
        try_validator(nam = "val57"),

    # tag_action R requires the retrieved tag in tag_id_in.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                age_v <- one_txt(rec$age)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_action_v <- one_txt(rec$tag_action)
                if (identical(age_v, "A")) {
                    if (identical(tag_action_v, "R")) {
                        if (is.na(tag_id_in_v)) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id_in",
                                reason = "tag_action R requires the retrieved tag in tag_id_in."
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
        try_validator(nam = "val58"),

    # tag_action R requires release tag_id to be blank.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_action_v <- one_txt(rec$tag_action)
                if (identical(age_v, "A")) {
                    if (identical(tag_action_v, "R")) {
                        if (!is.na(tag_id_v)) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id",
                                reason = "tag_action R requires release tag_id to be blank."
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
        try_validator(nam = "val59"),

    # tag_action S requires the retained tag in tag_id_in.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                age_v <- one_txt(rec$age)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_action_v <- one_txt(rec$tag_action)
                if (identical(age_v, "A")) {
                    if (identical(tag_action_v, "S")) {
                        if (is.na(tag_id_in_v)) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id_in",
                                reason = "tag_action S requires the retained tag in tag_id_in."
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
        try_validator(nam = "val60"),

    # tag_action S requires the retained tag in tag_id.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_action_v <- one_txt(rec$tag_action)
                if (identical(age_v, "A")) {
                    if (identical(tag_action_v, "S")) {
                        if (is.na(tag_id_v)) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id",
                                reason = "tag_action S requires the retained tag in tag_id."
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
        try_validator(nam = "val61"),

    # tag_action S requires the same tag_id before and after release.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_action_v <- one_txt(rec$tag_action)
                if (identical(age_v, "A")) {
                    if (identical(tag_action_v, "S")) {
                        if (
                            !is.na(tag_id_v) &&
                                !is.na(tag_id_in_v) &&
                                tag_id_v != tag_id_in_v
                        ) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id",
                                reason = "tag_action S requires the same tag_id before and after release."
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
        try_validator(nam = "val62"),

    # tag_action N requires the removed tag in tag_id_in.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                age_v <- one_txt(rec$age)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_action_v <- one_txt(rec$tag_action)
                if (identical(age_v, "A")) {
                    if (identical(tag_action_v, "N")) {
                        if (is.na(tag_id_in_v)) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id_in",
                                reason = "tag_action N requires the removed tag in tag_id_in."
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
        try_validator(nam = "val63"),

    # tag_action N requires the newly deployed tag in tag_id.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_action_v <- one_txt(rec$tag_action)
                if (identical(age_v, "A")) {
                    if (identical(tag_action_v, "N")) {
                        if (is.na(tag_id_v)) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id",
                                reason = "tag_action N requires the newly deployed tag in tag_id."
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
        try_validator(nam = "val64"),

    # tag_action N requires different input and release tag IDs.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                age_v <- one_txt(rec$age)
                tag_id_v <- one_txt(rec$tag_id)
                tag_id_in_v <- one_txt(rec$tag_id_in)
                tag_action_v <- one_txt(rec$tag_action)
                if (identical(age_v, "A")) {
                    if (identical(tag_action_v, "N")) {
                        if (
                            !is.na(tag_id_v) &&
                                !is.na(tag_id_in_v) &&
                                tag_id_v == tag_id_in_v
                        ) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "tag_id",
                                reason = "tag_action N requires different input and release tag IDs."
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
        try_validator(nam = "val65"),

    # Check tag actions against earlier deployments.
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
        clean_text <- function(v) {
            txt <- (v |> as.character() |> str_trim() |> toupper())
            txt[is.na(v) | !nzchar(txt) | txt == "NA"] <- NA_character_
            txt
        }
        read_stamp <- function(date_v, time_v) {
            date_raw <- substr((date_v |> as.character() |> str_trim()), 1, 10)
            time_raw <- (time_v |> as.character() |> str_trim())
            time_raw[
                is.na(time_v) | !nzchar(time_raw) | time_raw == "NA"
            ] <- NA_character_
            short_time <- !is.na(time_raw) & nchar(time_raw) == 5
            time_raw[short_time] <- paste0(time_raw[short_time], ":00")
            (paste(date_raw, time_raw) |>
                as.POSIXct(
                    format = "%Y-%m-%d %H:%M:%S",
                    tz = "Pacific/Auckland"
                ))
        }
        dat[, let(
            ring_key = clean_text(ring),
            tag_id_in_key = clean_text(tag_id_in),
            tag_id_key = clean_text(tag_id),
            tag_action_key = clean_text(tag_action)
        )]
        dat[, let(event_dt = read_stamp(date, caught))]
        opts <- dat[
            tag_action_key %in%
                c("D", "R", "S", "N") &
                !is.na(event_dt) &
                !is.na(ring_key) &
                ((tag_action_key == "D" &
                    !is.na(tag_id_key) &
                    is.na(tag_id_in_key)) |
                    (tag_action_key == "R" &
                        is.na(tag_id_key) &
                        !is.na(tag_id_in_key)) |
                    (tag_action_key == "S" &
                        !is.na(tag_id_key) &
                        !is.na(tag_id_in_key) &
                        tag_id_key == tag_id_in_key) |
                    (tag_action_key == "N" &
                        !is.na(tag_id_key) &
                        !is.na(tag_id_in_key) &
                        tag_id_key != tag_id_in_key))
        ]
        if (nrow(opts) == 0) {
            none
        } else {
            saved_result <- tryCatch(
                db_get(
                    "SELECT date, caught, ring, tag_id_in, tag_id, tag_action, pk FROM CAPTURES"
                ),
                error = function(e) e
            )
            if (
                inherits(saved_result, "error") ||
                    inherits(saved_result, "try-error")
            ) {
                unique(opts[, .(
                    rowid,
                    variable = "tag_action",
                    reason = "Tag history unverified: CAPTURES unavailable."
                )])
            } else {
                kept <- as.data.table(saved_result)
                needed <- c(
                    "date",
                    "caught",
                    "ring",
                    "tag_id_in",
                    "tag_id",
                    "tag_action",
                    "pk"
                )
                for (col in setdiff(needed, names(kept))) {
                    kept[, let((col), NA)]
                }
                if (nrow(kept) > 0) {
                    kept[, let(
                        ring_key = clean_text(ring),
                        tag_id_in_key = clean_text(tag_id_in),
                        tag_id_key = clean_text(tag_id),
                        tag_action_key = clean_text(tag_action),
                        event_dt = read_stamp(date, caught),
                        current_rowid = NA_integer_,
                        source_rank = 0,
                        order_id = (pk |> as.numeric())
                    )]
                    kept[is.na(order_id), let(order_id, .I)]
                } else {
                    kept <- data.table(
                        ring_key = character(),
                        tag_id_in_key = character(),
                        tag_id_key = character(),
                        tag_action_key = character(),
                        event_dt = (character() |> as.POSIXct()),
                        current_rowid = integer(),
                        source_rank = integer(),
                        order_id = numeric()
                    )
                }
                current <- dat[, .(
                    ring_key,
                    tag_id_in_key,
                    tag_id_key,
                    tag_action_key,
                    event_dt,
                    current_rowid = rowid,
                    source_rank = 1,
                    order_id = (rowid |> as.numeric())
                )]
                hist_v <- rbindlist(
                    list(
                        kept[, .(
                            ring_key,
                            tag_id_in_key,
                            tag_id_key,
                            tag_action_key,
                            event_dt,
                            current_rowid,
                            source_rank,
                            order_id
                        )],
                        current
                    ),
                    use.names = TRUE,
                    fill = TRUE
                )
                hist_v <- hist_v[!is.na(event_dt)]
                setorder(
                    hist_v,
                    event_dt,
                    source_rank,
                    order_id,
                    na.last = TRUE
                )
                hist_v[, let(event_seq, .I)]
                errs <- list()
                bad_now <- integer()
                opt_order <- opts[order(event_dt, rowid), rowid]
                for (rid in opt_order) {
                    rec <- hist_v[current_rowid == rid][1]
                    if (nrow(rec) == 0 || is.na(rec$event_seq)) {
                        next
                    }
                    prev <- hist_v[
                        event_seq < rec$event_seq &
                            !(source_rank == 1 &
                                current_rowid %in%
                                    bad_now)
                    ]
                    action <- rec$tag_action_key[[1]]
                    ring_now <- rec$ring_key[[1]]
                    tag_in <- rec$tag_id_in_key[[1]]
                    tag_res <- rec$tag_id_key[[1]]
                    tag_hist <- function(tag) {
                        if (is.na(tag)) {
                            return(prev[0])
                        }
                        prev[
                            (!is.na(tag_id_key) & tag_id_key == tag) |
                                (!is.na(tag_id_in_key) &
                                    tag_id_in_key == tag)
                        ]
                    }
                    tag_active <- function(tag) {
                        evts <- tag_hist(tag)
                        if (nrow(evts) == 0) {
                            return(FALSE)
                        }
                        last_v <- evts[.N]
                        last_action <- last_v$tag_action_key[[1]]
                        last_ring <- last_v$ring_key[[1]]
                        active <- (identical(last_action, "D") &&
                            identical(
                                last_v$tag_id_key[[1]],
                                tag
                            )) ||
                            (identical(last_action, "S") &&
                                identical(
                                    last_v$tag_id_key[[1]],
                                    tag
                                )) ||
                            (identical(last_action, "N") &&
                                identical(
                                    last_v$tag_id_key[[1]],
                                    tag
                                ))
                        isTRUE(active) && identical(last_ring, ring_now)
                    }
                    res <- list()
                    if (identical(action, "D")) {
                        prev_a <- tag_hist(tag_res)
                        prev_deploy <- prev_a[
                            tag_action_key %in%
                                c("D", "N") &
                                !is.na(tag_id_key) &
                                tag_id_key == tag_res
                        ]
                        if (nrow(prev_deploy) > 0) {
                            last_v <- prev_a[.N]
                            reusable <- identical(
                                last_v$tag_action_key[[1]],
                                "R"
                            ) &&
                                identical(
                                    last_v$tag_id_in_key[[1]],
                                    tag_res
                                )
                            if (!isTRUE(reusable)) {
                                res[[length(res) + 1]] <- data.table(
                                    rowid = rid,
                                    variable = "tag_id",
                                    reason = "Tag already deployed; redeployment requires prior R retrieval in tag_id_in."
                                )
                            }
                        }
                    }
                    if (identical(action, "S") && !tag_active(tag_in)) {
                        res[[length(res) + 1]] <- data.table(
                            rowid = rid,
                            variable = "tag_action",
                            reason = "tag_action S requires this tag to be active on the same ring from an earlier deployment."
                        )
                    }
                    if (identical(action, "R") && !tag_active(tag_in)) {
                        res[[length(res) + 1]] <- data.table(
                            rowid = rid,
                            variable = "tag_action",
                            reason = "tag_action R requires tag_id_in to be active on the same ring from an earlier deployment."
                        )
                    }
                    if (identical(action, "N")) {
                        prior_d_same_ring <- prev[
                            tag_action_key == "D" &
                                !is.na(tag_id_key) &
                                tag_id_key == tag_in &
                                !is.na(ring_key) &
                                ring_key == ring_now
                        ]
                        if (
                            nrow(prior_d_same_ring) == 0 ||
                                !tag_active(tag_in)
                        ) {
                            res[[length(res) + 1]] <- data.table(
                                rowid = rid,
                                variable = "tag_id_in",
                                reason = "Action N requires tag_id_in active from an earlier D deployment on this ring."
                            )
                        }
                        prior_new_tag <- prev[
                            tag_action_key %in%
                                c("D", "N") &
                                !is.na(tag_id_key) &
                                tag_id_key == tag_res
                        ]
                        if (nrow(prior_new_tag) > 0) {
                            res[[length(res) + 1]] <- data.table(
                                rowid = rid,
                                variable = "tag_id",
                                reason = "Action N requires an unused release tag_id."
                            )
                        }
                    }
                    if (length(res) > 0) {
                        errs[[length(errs) + 1]] <- rbindlist(
                            res,
                            use.names = TRUE,
                            fill = TRUE
                        )
                        bad_now <- c(bad_now, rid)
                    }
                }
                res <- rbindlist(errs, use.names = TRUE, fill = TRUE)
                if (nrow(res) == 0) {
                    none
                } else {
                    unique(res)
                }
            }
        }
    } |>
        try_validator(nam = "val66"),

    # Require discovery before a positive nest-linked capture.
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
        clean_clock <- function(v) {
            txt <- (v |> as.character() |> str_trim())
            txt[is.na(v) | !nzchar(txt) | txt == "NA"] <- "99:99"
            txt
        }
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
            "SELECT nest_id, date, time_visit, nest_state FROM NESTS"
        ))
        if (nrow(nests_dt) > 0) {
            nests_dt <- copy(nests_dt)
            nests_dt[, let(event_date_nest, (date |> as.Date()))]
            nests_dt[, let(time_visit_key, clean_clock(time_visit))]
            nests_dt <- nests_dt[
                nest_state == "F" &
                    !is.na(event_date_nest) &
                    !is.na(nest_id) &
                    nzchar((nest_id |> as.character() |> str_trim())),
                .(
                    nest_id = (nest_id |> as.character() |> str_trim()),
                    event_date_nest,
                    time_visit_key
                )
            ]
            if (nrow(nests_dt) > 0) {
                setorder(nests_dt, nest_id, event_date_nest, time_visit_key)
                nests_dt <- nests_dt[, .SD[1], by = nest_id]
            }
        } else {
            nests_dt <- data.table(
                nest_id = character(),
                event_date_nest = (character() |> as.Date()),
                time_visit_key = character()
            )
        }
        dat[, let(event_date, (date |> as.Date()))]
        dat[, let(caught_key, clean_clock(caught))]
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                nest_key <- one_txt(rec$nest_id)
                evt_date_v <- rec$event_date[[1]]
                caught_key_v <- rec$caught_key[[1]]
                if (!is_pos_nest(nest_key) || is.na(evt_date_v)) {
                    return(none)
                }
                first_f <- nests_dt[nest_id == nest_key]
                if (nrow(first_f) == 0) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "nest_id",
                        reason = "nest_id requires a same-day-or-earlier NESTS F event."
                    ))
                }
                first_date <- first_f$event_date_nest[[1]]
                first_time <- first_f$time_visit_key[[1]]
                if (
                    evt_date_v < first_date ||
                        (evt_date_v == first_date &&
                            caught_key_v < first_time)
                ) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "nest_id",
                        reason = "nest_id requires a same-day-or-earlier NESTS F event."
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
        try_validator(nam = "val67"),

    # Check band combinations against capture history.
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
        clean_one <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[is.na(v) | res %in% c("", "NA")] <- NA_character_
            res
        }
        clean_geo <- function(v) {
            res <- clean_one(v)
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
                    str_replace(regex("^.*([RBGWOLY])$", dotall = TRUE), "\\1"))
            )
            res
        }
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
                    (lr1 |> str_detect("^[RBGWOLY]$")) %in%
                        TRUE,
                paste0((ur1 |> str_replace("^T", "")), lr1),
                ifelse(
                    !is.na(ur1) &
                        (ur1 |> str_detect("^[RBGWOLY]$")) %in%
                            TRUE &
                        !is.na(lr1) &
                        (lr1 |> str_detect("^[RBGWOLY]$")) %in% TRUE,
                    paste0(ur1, lr1),
                    ifelse(
                        (is.na(ur1) |
                            ur1 %in% c("X", "M")) &
                            !is.na(lr1) &
                            (lr1 |> str_detect("^[RBGWOLY]{2}$")) %in% TRUE,
                        lr1,
                        ifelse(
                            (is.na(lr1) |
                                lr1 %in% c("X", "M")) &
                                !is.na(ur1) &
                                (ur1 |> str_detect("^[RBGWOLY]{2}$")) %in% TRUE,
                            ur1,
                            NA_character_
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
        band_id <- function(dt, cols) {
            mapply(
                bird_id,
                dt[[cols[1]]],
                dt[[cols[2]]],
                dt[[cols[3]]],
                dt[[cols[4]]],
                USE.NAMES = FALSE
            )
        }
        raw_band <- function(dt, cols) {
            mapply(
                raw_combo,
                dt[[cols[1]]],
                dt[[cols[2]]],
                dt[[cols[3]]],
                dt[[cols[4]]],
                USE.NAMES = FALSE
            )
        }
        old_ref <- tryCatch(
            list(
                ok = TRUE,
                data = as.data.table(db_get(
                    "SELECT date, UL, LL, UR, LR FROM CAPTURES_ARCHIVE"
                ))
            ),
            error = function(e) {
                list(
                    ok = FALSE,
                    data = data.table(
                        date = (character() |> as.Date()),
                        UL = character(),
                        LL = character(),
                        UR = character(),
                        LR = character()
                    )
                )
            }
        )
        has_archive <- isTRUE(old_ref$ok)
        old <- old_ref$data
        if (has_archive && nrow(old) > 0) {
            old[, let(combo, band_id(.SD, c("UL", "LL", "UR", "LR")))]
            old[, let(date, (date |> as.Date()))]
        } else {
            old <- data.table(
                date = (character() |> as.Date()),
                combo = character()
            )
        }
        dat[, let(date, (date |> as.Date()))]
        dat[, let(combo_release, band_id(.SD, c("UL", "LL", "UR", "LR")))]
        dat[, let(
            combo_in,
            band_id(.SD, c("UL_in", "LL_in", "UR_in", "LR_in"))
        )]
        dat[, let(
            combo_in_raw,
            raw_band(.SD, c("UL_in", "LL_in", "UR_in", "LR_in"))
        )]
        prev_now <- function(i, combo_col) {
            any(
                dat$rowid != dat$rowid[i] &
                    !is.na(dat$date) &
                    dat$date < dat$date[i] &
                    dat[[combo_col]] == dat[[combo_col]][i],
                na.rm = TRUE
            )
        }
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                status_v <- one_txt(rec$capture_status)
                if (identical(status_v, "R")) {
                    batch_before <- prev_now(i, "combo_release")
                    prior_old <- has_archive &&
                        any(
                            old$combo == rec$combo_release &
                                old$date <= rec$date,
                            na.rm = TRUE
                        )
                    prior_exists <- prior_old || batch_before
                    if (!prior_exists) {
                        if (!has_archive) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "UL",
                                reason = paste(
                                    "Combination unverified:",
                                    "CAPTURES_ARCHIVE unavailable.",
                                    "Release match unknown; retry when",
                                    "database is available."
                                )
                            ))
                        }
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "UL",
                            reason = "Status R requires a release combo already present in capture history."
                        ))
                    }
                }
                if (identical(status_v, "C")) {
                    if (identical(one_txt(rec$combo_in_raw), "XXXX")) {
                        return(none)
                    }
                    batch_before <- prev_now(i, "combo_in")
                    prior_old <- has_archive &&
                        any(
                            old$combo == rec$combo_in &
                                old$date <= rec$date,
                            na.rm = TRUE
                        )
                    prior_exists <- prior_old || batch_before
                    if (!prior_exists) {
                        if (!has_archive) {
                            return(data.table(
                                rowid = rec$rowid,
                                variable = "UL_in",
                                reason = paste(
                                    "Combination unverified:",
                                    "CAPTURES_ARCHIVE unavailable.",
                                    "Input match unknown; retry when",
                                    "database is available."
                                )
                            ))
                        }
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "UL_in",
                            reason = "Status C requires an input combo already present in capture history."
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
        try_validator(nam = "val68"),

    # Check optional measurements are numeric.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        colset <- c(
            "tarsus",
            "culmen",
            "total_head",
            "head_white",
            "head_black",
            "rufous_band",
            "wing",
            "weight"
        )
        dat[,
            let(
                (colset),
                lapply(.SD, function(item) {
                    txt <- item |> as.character() |> str_trim()
                    txt[is.na(item) | !nzchar(txt) | txt == "NA"] <- "0"
                    num <- txt |> as.numeric()
                    num[!is.finite(num)] <- NA_real_
                    num
                })
            ),
            .SDcols = colset
        ]
        is.na_validator(
            dat[, c("rowid", colset), with = FALSE],
            reason = "Enter a finite number."
        )
    } |>
        try_validator(nam = "val69"),

    # Check adult morphometric ranges .
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        age_txt <- dat$age |> as.character() |> str_trim() |> toupper()
        cap_txt <- dat$capture_status |>
            as.character() |>
            str_trim() |>
            toupper()
        grp <- ifelse(
            age_txt == "C" & cap_txt == "C",
            "C_change",
            ifelse(age_txt == "C" & cap_txt == "R", "C_recap", age_txt)
        )
        dat <- dat[which(grp == "A")]
        colset <- c(
            "tarsus",
            "culmen",
            "total_head",
            "head_white",
            "head_black",
            "rufous_band",
            "wing",
            "weight"
        )
        dat[,
            let(
                (colset),
                lapply(.SD, function(item) {
                    txt <- item |> as.character() |> str_trim()
                    txt[
                        is.na(item) | !nzchar(txt) | txt == "NA"
                    ] <- NA_character_
                    txt |> as.numeric()
                })
            ),
            .SDcols = colset
        ]
        bounds <- data.table(
            variable = colset,
            lq = c(27.84, 15.47, 42.02, 0, 0, 5.27, 118.02, 49.47),
            uq = c(33.96, 20.42, 49.34, 8.4, 6.37, 27.68, 138, 77.16)
        )
        interval_validator(
            dat[, c("rowid", colset), with = FALSE],
            v = bounds,
            reason = "Outside morphometric range."
        )
    } |>
        try_validator(nam = "val70"),

    # Check juvenile morphometric ranges .
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        age_txt <- dat$age |> as.character() |> str_trim() |> toupper()
        cap_txt <- dat$capture_status |>
            as.character() |>
            str_trim() |>
            toupper()
        grp <- ifelse(
            age_txt == "C" & cap_txt == "C",
            "C_change",
            ifelse(age_txt == "C" & cap_txt == "R", "C_recap", age_txt)
        )
        dat <- dat[which(grp == "J")]
        colset <- c("tarsus", "culmen", "total_head", "wing", "weight")
        dat[,
            let(
                (colset),
                lapply(.SD, function(item) {
                    txt <- item |> as.character() |> str_trim()
                    txt[
                        is.na(item) | !nzchar(txt) | txt == "NA"
                    ] <- NA_character_
                    txt |> as.numeric()
                })
            ),
            .SDcols = colset
        ]
        bounds <- data.table(
            variable = colset,
            lq = c(23.22, 12.46, 40.62, 49.28, 18.58),
            uq = c(30.75, 16.36, 43.58, 124.23, 43.8)
        )
        interval_validator(
            dat[, c("rowid", colset), with = FALSE],
            v = bounds,
            reason = "Outside morphometric range."
        )
    } |>
        try_validator(nam = "val71"),

    # Check chick morphometric ranges .
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        age_txt <- dat$age |> as.character() |> str_trim() |> toupper()
        cap_txt <- dat$capture_status |>
            as.character() |>
            str_trim() |>
            toupper()
        grp <- ifelse(
            age_txt == "C" & cap_txt == "C",
            "C_change",
            ifelse(age_txt == "C" & cap_txt == "R", "C_recap", age_txt)
        )
        dat <- dat[which(grp == "C")]
        colset <- c("tarsus", "culmen", "total_head", "wing", "weight")
        dat[,
            let(
                (colset),
                lapply(.SD, function(item) {
                    txt <- item |> as.character() |> str_trim()
                    txt[
                        is.na(item) | !nzchar(txt) | txt == "NA"
                    ] <- NA_character_
                    txt |> as.numeric()
                })
            ),
            .SDcols = colset
        ]
        bounds <- data.table(
            variable = colset,
            lq = c(18.43, 6.47, 37.01, 21.99, 6.73),
            uq = c(29.52, 15.63, 39.99, 93.37, 40.38)
        )
        interval_validator(
            dat[, c("rowid", colset), with = FALSE],
            v = bounds,
            reason = "Outside morphometric range."
        )
    } |>
        try_validator(nam = "val72"),

    # Check recaptured-chick morphometric ranges .
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        age_txt <- dat$age |> as.character() |> str_trim() |> toupper()
        cap_txt <- dat$capture_status |>
            as.character() |>
            str_trim() |>
            toupper()
        grp <- ifelse(
            age_txt == "C" & cap_txt == "C",
            "C_change",
            ifelse(age_txt == "C" & cap_txt == "R", "C_recap", age_txt)
        )
        dat <- dat[which(grp == "C_recap")]
        colset <- c("tarsus", "culmen", "weight")
        dat[,
            let(
                (colset),
                lapply(.SD, function(item) {
                    txt <- item |> as.character() |> str_trim()
                    txt[
                        is.na(item) | !nzchar(txt) | txt == "NA"
                    ] <- NA_character_
                    txt |> as.numeric()
                })
            ),
            .SDcols = colset
        ]
        bounds <- data.table(
            variable = colset,
            lq = c(18.43, 6.47, 6.73),
            uq = c(26.99, 13.79, 21.99)
        )
        interval_validator(
            dat[, c("rowid", colset), with = FALSE],
            v = bounds,
            reason = "Outside morphometric range."
        )
    } |>
        try_validator(nam = "val73"),

    # Check rebanded-chick morphometric ranges .
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        age_txt <- dat$age |> as.character() |> str_trim() |> toupper()
        cap_txt <- dat$capture_status |>
            as.character() |>
            str_trim() |>
            toupper()
        grp <- ifelse(
            age_txt == "C" & cap_txt == "C",
            "C_change",
            ifelse(age_txt == "C" & cap_txt == "R", "C_recap", age_txt)
        )
        dat <- dat[which(grp == "C_change")]
        colset <- c("tarsus", "culmen", "total_head", "wing", "weight")
        dat[,
            let(
                (colset),
                lapply(.SD, function(item) {
                    txt <- item |> as.character() |> str_trim()
                    txt[
                        is.na(item) | !nzchar(txt) | txt == "NA"
                    ] <- NA_character_
                    txt |> as.numeric()
                })
            ),
            .SDcols = colset
        ]
        bounds <- data.table(
            variable = colset,
            lq = c(27.7, 13.8, 38.8, 21.99, 22.8),
            uq = c(33.96, 20.42, 49.34, 138, 77.16)
        )
        interval_validator(
            dat[, c("rowid", colset), with = FALSE],
            v = bounds,
            reason = "Outside morphometric range."
        )
    } |>
        try_validator(nam = "val74"),

    # cam_id is required when any photo flag is 1.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                flag_vals <- vapply(
                    c(
                        "mugshot_photo",
                        "wing_photo",
                        "chick_tent_photo",
                        "chick_hide_photo"
                    ),
                    function(nm) one_txt(rec[[nm]]),
                    character(1)
                )
                any_flag_yes <- any(flag_vals == "1", na.rm = TRUE)
                has_cam <- !is.na(one_txt(rec$cam_id))
                if (any_flag_yes && !has_cam) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "cam_id",
                        reason = "cam_id is required when any photo flag is 1."
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
        try_validator(nam = "val75"),

    # photo_start is required when any photo flag is 1.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                flag_vals <- vapply(
                    c(
                        "mugshot_photo",
                        "wing_photo",
                        "chick_tent_photo",
                        "chick_hide_photo"
                    ),
                    function(nm) one_txt(rec[[nm]]),
                    character(1)
                )
                any_flag_yes <- any(flag_vals == "1", na.rm = TRUE)
                has_start <- !is.na(one_txt(rec$photo_start))
                if (any_flag_yes && !has_start) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "photo_start",
                        reason = "photo_start is required when any photo flag is 1."
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
        try_validator(nam = "val76"),

    # photo_end is required when any photo flag is 1.
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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                flag_vals <- vapply(
                    c(
                        "mugshot_photo",
                        "wing_photo",
                        "chick_tent_photo",
                        "chick_hide_photo"
                    ),
                    function(nm) one_txt(rec[[nm]]),
                    character(1)
                )
                any_flag_yes <- any(flag_vals == "1", na.rm = TRUE)
                has_end <- !is.na(one_txt(rec$photo_end))
                if (any_flag_yes && !has_end) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "photo_end",
                        reason = "photo_end is required when any photo flag is 1."
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
        try_validator(nam = "val77"),

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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                has_cam <- !is.na(one_txt(rec$cam_id))
                has_start <- !is.na(one_txt(rec$photo_start))
                has_end <- !is.na(one_txt(rec$photo_end))
                meta_count <- sum(c(has_cam, has_start, has_end))
                if (meta_count > 0 && meta_count < 3) {
                    if (!has_cam) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "cam_id",
                            reason = "Enter cam_id, photo_start, and photo_end together."
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
        try_validator(nam = "val78"),

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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                has_cam <- !is.na(one_txt(rec$cam_id))
                has_start <- !is.na(one_txt(rec$photo_start))
                has_end <- !is.na(one_txt(rec$photo_end))
                meta_count <- sum(c(has_cam, has_start, has_end))
                if (meta_count > 0 && meta_count < 3) {
                    if (!has_start) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "photo_start",
                            reason = "Enter cam_id, photo_start, and photo_end together."
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
        try_validator(nam = "val79"),

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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                has_cam <- !is.na(one_txt(rec$cam_id))
                has_start <- !is.na(one_txt(rec$photo_start))
                has_end <- !is.na(one_txt(rec$photo_end))
                meta_count <- sum(c(has_cam, has_start, has_end))
                if (meta_count > 0 && meta_count < 3) {
                    if (!has_end) {
                        return(data.table(
                            rowid = rec$rowid,
                            variable = "photo_end",
                            reason = "Enter cam_id, photo_start, and photo_end together."
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
        try_validator(nam = "val80"),

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
        res <- rbindlist(
            lapply(seq_len(nrow(dat)), function(i) {
                rec <- dat[i]
                start_no <- pic_no(rec$photo_start)
                end_no <- pic_no(rec$photo_end)
                if (!is.na(start_no) && !is.na(end_no) && start_no > end_no) {
                    return(data.table(
                        rowid = rec$rowid,
                        variable = "photo_end",
                        reason = "photo_end must not precede photo_start."
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
        try_validator(nam = "val81"),

    # Check photo ranges for reuse.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
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
        other_caps <- as.data.table(db_get(
            "SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, age, photo_start, photo_end FROM CAPTURES"
        ))
        other_res <- as.data.table(db_get(
            "SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, rclass, age, photo_start, photo_end FROM RESIGHTINGS"
        ))
        other_nests <- as.data.table(db_get(
            "SELECT pk, cam_id, date, observer, nest_id, gps_id, gps_point, photo_start, photo_end FROM NESTS"
        ))
        now_wide <- spread_pics(dat, "CAPTURES")
        other_caps_wide <- spread_pics(
            other_caps,
            "CAPTURES",
            rowid_col = "missing_rowid"
        )
        other_res_wide <- spread_pics(
            other_res,
            "RESIGHTINGS",
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
                        if (
                            pic_conflict(
                                now_wide[i],
                                now_wide[j]
                            )
                        ) {
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
            list(other_caps_wide, other_res_wide, other_nests_wide),
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
                            stored_dups <- c(
                                stored_dups,
                                now_wide$rowid[i]
                            )
                        }
                    }
                }
            }
        }
        flagged <- sort(unique(c(batch_dups, stored_dups)))
        if (length(flagged) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            data.table(
                rowid = flagged,
                variable = "photo_start",
                reason = "Photo range overlaps another event; sharing allowed within one age-C H nest/GPS session."
            )
        }
    } |>
        try_validator(nam = "val82"),

    # Check observer upload initials check 1.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        txt <- (dat$observer_upload |> as.character() |> str_trim())
        dat[
            is.na(observer_upload) | !nzchar(txt),
            .(
                rowid,
                variable = "observer_upload",
                reason = "Enter the uploader’s observer code."
            )
        ]
    } |>
        try_validator(nam = "val83"),

    # Check observer upload initials check 2.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        txt <- (dat$observer_upload |> as.character() |> str_trim())
        dat[
            !is.na(observer_upload) &
                nzchar(txt) &
                !(txt |> str_detect("^[A-Z0-9]{2,3}$")) %in% TRUE,
            .(
                rowid,
                variable = "observer_upload",
                reason = "Use 2–3 uppercase letters or digits."
            )
        ]
    } |>
        try_validator(nam = "val84"),

    # Check caught with format.
    is.regexp_validator(
        x[, .(caught_with)],
        regexp = "^(?:[0-9]*C|M\\?|M|S)(?:,\\s*(?:[0-9]*C|M\\?|M|S))*$",
        reason = "Use valid comma-separated caught_with codes."
    ) |>
        try_validator(nam = "val85"),

    # Check left tibia in.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is.regexp_validator(
            dat[, .(UL_in, rowid)],
            regexp = "^(X|T|T[RBGWOLY]|[OYWBRGLM]{1,2}|F[OYWBRGLM][A-Z0-9]{2})$",
            reason = "Invalid capture left-tibia code."
        )
    } |>
        try_validator(nam = "val86"),

    # Check left tarsus in.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is.regexp_validator(
            dat[, .(LL_in, rowid)],
            regexp = "^(X|[OYWBRGLM]{1,2})$",
            reason = "Invalid capture left-tarsus code."
        )
    } |>
        try_validator(nam = "val87"),

    # Check right tibia in.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is.regexp_validator(
            dat[, .(UR_in, rowid)],
            regexp = "^(X|T|T[RBGWOLY]|[OYWBRGLM]{1,2}|F[OYWBRGLM][A-Z0-9]{2})$",
            reason = "Invalid capture right-tibia code."
        )
    } |>
        try_validator(nam = "val88"),

    # Check right tarsus in.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        is.regexp_validator(
            dat[, .(LR_in, rowid)],
            regexp = "^(X|[OYWBRGLM]{1,2})$",
            reason = "Invalid capture right-tarsus code."
        )
    } |>
        try_validator(nam = "val89"),

    # Check optional moult scores.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        colset <- c("moult_left", "moult_right")
        dat[,
            let(
                (colset),
                lapply(.SD, function(item) {
                    txt <- item |> as.character() |> str_trim()
                    txt[
                        is.na(item) | !nzchar(txt) | txt == "NA"
                    ] <- NA_character_
                    txt
                })
            ),
            .SDcols = colset
        ]
        is.regexp_validator(
            dat[, c("rowid", colset), with = FALSE],
            regexp = "^([0-9]\\([0-9]{1,2}\\))( [0-9]\\([0-9]{1,2}\\))*$",
            reason = "Invalid moult score."
        )
    } |>
        try_validator(nam = "val90"),

    # Check tag type required.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        res <- dat[
            !is.na(tag_id) & is.na(tag_type),
            .(
                rowid,
                variable = "tag_type",
                reason = "Tag type is required when tag ID is entered."
            )
        ]
        if (nrow(res) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            res
        }
    } |>
        try_validator(nam = "val91"),

    # Check tag id in format.
    is.regexp_validator(
        x[, .(tag_id_in)],
        regexp = "^[A-Za-z0-9_-]+$",
        reason = "Invalid capture tag ID."
    ) |>
        try_validator(nam = "val92"),

    # Check tag id format.
    is.regexp_validator(
        x[, .(tag_id)],
        regexp = "^[A-Za-z0-9_-]+$",
        reason = "Invalid release tag ID."
    ) |>
        try_validator(nam = "val93"),

    # Check camera id format.
    is.regexp_validator(
        x[, .(cam_id)],
        regexp = "^[A-Za-z0-9]{2,3}$",
        reason = "Use a valid 2–3-character camera ID."
    ) |>
        try_validator(nam = "val94"),

    # Check photo filename format photo start.
    is.regexp_validator(
        x[, .(photo_start)],
        regexp = "^[A-Za-z0-9._-]+$",
        reason = "Invalid photo filename."
    ) |>
        try_validator(nam = "val95"),

    # Check photo filename format photo end.
    is.regexp_validator(
        x[, .(photo_end)],
        regexp = "^[A-Za-z0-9._-]+$",
        reason = "Invalid photo filename."
    ) |>
        try_validator(nam = "val96"),

    # Check whether the ring was already recorded.
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
        clean_one <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            res
        }
        x_rings <- dat[
            (capture_status |> as.character() |> str_trim()) == "F",
            .(rowid, ring_key = clean_one(ring))
        ]
        x_rings <- x_rings[!is.na(ring_key)]
        if (nrow(x_rings) == 0) {
            none
        } else {
            now_rings <- tryCatch(
                as.data.table(db_get("SELECT ring FROM CAPTURES"))[, .(
                    ring_key = clean_one(ring)
                )],
                error = function(e) data.table(ring_key = character())
            )
            old_rings <- tryCatch(
                as.data.table(db_get("SELECT ring FROM CAPTURES_ARCHIVE"))[,
                    .(ring_key = clean_one(ring))
                ],
                error = function(e) data.table(ring_key = character())
            )
            all_rings <- rbindlist(
                list(
                    x_rings[, .(ring_key)],
                    now_rings[, .(ring_key)],
                    old_rings[,
                        .(ring_key)
                    ]
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
                none
            } else {
                x_rings[
                    ring_key %in% dup_rings,
                    .(
                        rowid,
                        variable = "ring",
                        reason = "Ring already recorded; check ring and identity."
                    )
                ]
            }
        }
    } |>
        try_validator(nam = "val97"),

    # Check whether another ring uses this combination.
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
        chk_colors <- c("R", "B", "G", "W", "O", "L", "Y")
        clean_one <- function(v) {
            res <- (v |> as.character() |> str_trim())
            res[res %in% c("", "NA")] <- NA_character_
            res
        }
        clean_geo <- function(v) {
            res <- clean_one(v)
            tag_like <- !is.na(res) &
                (res |> str_detect("^T[A-Z0-9]*[RBGWOLY]$")) %in% TRUE
            res[tag_like] <- paste0(
                "T",
                (res[tag_like] |>
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
                    (lr1 |> str_detect("^[RBGWOLY]$")) %in%
                        TRUE,
                paste0((ur1 |> str_replace("^T", "")), lr1),
                ifelse(
                    !is.na(ur1) &
                        (ur1 |> str_detect("^[RBGWOLY]$")) %in%
                            TRUE &
                        !is.na(lr1) &
                        (lr1 |> str_detect("^[RBGWOLY]$")) %in% TRUE,
                    paste0(ur1, lr1),
                    ifelse(
                        (is.na(ur1) |
                            ur1 %in% c("X", "M")) &
                            !is.na(lr1) &
                            (lr1 |> str_detect("^[RBGWOLY]{2}$")) %in% TRUE,
                        lr1,
                        ifelse(
                            (is.na(lr1) |
                                lr1 %in% c("X", "M")) &
                                !is.na(ur1) &
                                (ur1 |> str_detect("^[RBGWOLY]{2}$")) %in% TRUE,
                            ur1,
                            NA_character_
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
        band_id <- function(dt, cols = c("UL", "LL", "UR", "LR")) {
            mapply(
                bird_id,
                dt[[cols[1]]],
                dt[[cols[2]]],
                dt[[cols[3]]],
                dt[[cols[4]]],
                USE.NAMES = FALSE
            )
        }
        is_cr_chk_scheme <- function(ul, ll, ur, lr) {
            !is.na(ll) &&
                ll %in% chk_colors &&
                ur == "M" &&
                (is.na(ul) || ul == "X") &&
                (is.na(lr) ||
                    lr == "X")
        }
        is_noncr_chk_scheme <- function(ul, ll, ur, lr) {
            ul == "M" &&
                (is.na(ll) || ll == "X") &&
                (is.na(ur) || ur == "X") &&
                !is.na(lr) &&
                lr %in% chk_colors
        }
        prep_pairs <- function(dt, keep_rowid = FALSE) {
            if (is.null(dt) || nrow(dt) == 0) {
                return(data.table(
                    rowid = integer(),
                    ring = character(),
                    combo = character()
                ))
            }
            buf <- copy(dt)
            if (keep_rowid && !"rowid" %in% names(buf)) {
                buf[, let(rowid, .I)]
            }
            for (nm in c("ring", "UL", "LL", "UR", "LR")) {
                buf[, let((nm), clean_one(buf[[nm]]))]
            }
            buf[, let(UR, clean_geo(UR))]
            buf <- buf[!is.na(ring)]
            if (nrow(buf) == 0) {
                return(data.table(
                    rowid = integer(),
                    ring = character(),
                    combo = character()
                ))
            }
            buf[,
                let(combo, band_id(.SD)),
                .SDcols = c("UL", "LL", "UR", "LR")
            ]
            buf[, let(
                unique_combo_ok,
                !is.na(UL) &
                    !is.na(LL) &
                    !is.na(UR) &
                    !is.na(LR) &
                    !(UL == "X" & LL == "X" & UR == "X" & LR == "X") &
                    !mapply(
                        is_cr_chk_scheme,
                        UL,
                        LL,
                        UR,
                        LR
                    ) &
                    !mapply(is_noncr_chk_scheme, UL, LL, UR, LR)
            )]
            buf <- buf[unique_combo_ok == TRUE]
            if (nrow(buf) == 0) {
                return(data.table(
                    rowid = integer(),
                    ring = character(),
                    combo = character()
                ))
            }
            if (keep_rowid) {
                buf[, .(rowid, ring, combo)]
            } else {
                buf[, .(ring, combo)]
            }
        }
        old_pairs <- tryCatch(
            prep_pairs(as.data.table(db_get(
                "SELECT ring, UL, LL, UR, LR FROM CAPTURES_ARCHIVE"
            ))),
            error = function(e) {
                data.table(ring = character(), combo = character())
            }
        )
        now_pairs <- tryCatch(
            prep_pairs(as.data.table(db_get(
                "SELECT ring, UL, LL, UR, LR FROM CAPTURES"
            ))),
            error = function(e) {
                data.table(ring = character(), combo = character())
            }
        )
        x_pairs <- prep_pairs(
            dat[, .(rowid, ring, UL, LL, UR, LR)],
            keep_rowid = TRUE
        )
        if (nrow(x_pairs) == 0) {
            none
        } else {
            all_pairs <- rbindlist(
                list(
                    x_pairs[, .(ring, combo)],
                    now_pairs[, .(ring, combo)],
                    old_pairs[, .(ring, combo)]
                ),
                use.names = TRUE,
                fill = TRUE
            )
            all_pairs[, let(ring, clean_one(ring))]
            all_pairs[, let(combo, clean_one(combo))]
            all_pairs <- all_pairs[
                !is.na(ring) & nzchar(ring) & !is.na(combo) & nzchar(combo)
            ]
            dup_combos <- all_pairs[,
                .(n_rings = length(unique((ring |> as.character())))),
                by = combo
            ][n_rings > 1, combo]
            if (length(dup_combos) == 0) {
                none
            } else {
                x_pairs[
                    combo %in% dup_combos,
                    .(
                        rowid,
                        variable = "UL",
                        reason = paste(
                            "Band combination already used",
                            "by another ring;",
                            "check the full combination",
                            "and ring."
                        )
                    )
                ][, unique(.SD)]
            }
        }
    } |>
        try_validator(nam = "val98"),

    # Review birds recorded as handled together.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        dat[, let(nest_key, (nest_id |> as.character() |> str_trim()))]
        dat[nest_key %in% c("", "NA"), let(nest_key, NA_character_)]
        grp <- dat[
            !is.na(nest_key) &
                nzchar(nest_key) &
                nest_key != "NO_NEST" &
                !(nest_key |> str_detect("^-")) %in%
                    TRUE,
            .(
                chick_n = sum(age == "C", na.rm = TRUE),
                adult_n = sum(age == "A", na.rm = TRUE)
            ),
            by = .(date, caught, nest_key)
        ]
        joined <- merge(
            dat[, .(rowid, age, caught_with, date, caught, nest_key)],
            grp,
            by = c(
                "date",
                "caught",
                "nest_key"
            )
        )
        bad_idx <- joined[
            age == "A" &
                chick_n > 0 &
                (is.na(caught_with) |
                    !(caught_with |> as.character() |> str_detect("C")) %in%
                        TRUE),
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
                variable = "caught_with",
                reason = "Check caught_with against birds handled together."
            )
        }
    } |>
        try_validator(nam = "val99")
)
