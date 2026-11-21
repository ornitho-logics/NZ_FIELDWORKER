list(
    # Check observer initials.
    is.regexp_validator(
        x[, .(observer)],
        regexp = "^[A-Z0-9]{2,3}$",
        reason = "Use 2–3 uppercase letters or digits."
    ) |>
        try_validator(nam = "val1"),

    # Check start date.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        txt <- (dat$start |> as.character() |> str_trim())
        conv <- (txt |> as.Date(format = "%Y-%m-%d"))
        bad_idx <- which(
            !is.na(dat$start) &
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
                variable = "start",
                reason = "Use YYYY-MM-DD."
            )
        }
    } |>
        try_validator(nam = "val2"),

    # Check stop date.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        txt <- (dat$stop |> as.character() |> str_trim())
        conv <- (txt |> as.Date(format = "%Y-%m-%d"))
        bad_idx <- which(
            !is.na(dat$stop) &
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
                variable = "stop",
                reason = "Use YYYY-MM-DD."
            )
        }
    } |>
        try_validator(nam = "val3"),

    # Check gps id.
    {
        dat <- copy(x)
        if (!"rowid" %in% names(dat)) {
            dat[, let(rowid, .I)]
        }
        txt <- (dat$gps_id |> as.character() |> str_trim())
        ok_gps_list <- function(v) {
            v <- (v |> as.character() |> str_trim())
            if (is.na(v) || !nzchar(v) || v == "NA") {
                return(TRUE)
            }
            parts <- (unlist(
                (v |>
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
            if (!length(parts) || any(!nzchar(parts))) {
                return(FALSE)
            }
            vals <- (parts |> as.numeric())
            all(!is.na(vals) & vals >= 1 & vals <= 255 & vals == floor(vals))
        }
        bad_idx <- which(!vapply(txt, ok_gps_list, logical(1)))
        if (length(bad_idx) == 0) {
            data.table(
                rowid = integer(),
                variable = character(),
                reason = character()
            )
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "gps_id",
                reason = "Use integers 1–255, comma-separated if multiple."
            )
        }
    } |>
        try_validator(nam = "val4"),

    # Check observer start and stop order.
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
        start_date <- (dat$start |> as.Date())
        stop_date <- (dat$stop |> as.Date())
        bad_idx <- which(
            !is.na(dat$start) &
                !is.na(dat$stop) &
                !is.na(start_date) &
                !is.na(stop_date) &
                start_date > stop_date
        )
        if (length(bad_idx) == 0) {
            none
        } else {
            data.table(
                rowid = dat$rowid[bad_idx],
                variable = "start",
                reason = "start must not follow stop."
            )
        }
    } |>
        try_validator(nam = "val5"),

    # Require a unique observer code.
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
        dup_codes <- dat[
            !is.na(observer) &
                nzchar((observer |> as.character() |> str_trim())),
            .N,
            by = observer
        ][N > 1, observer]
        if (length(dup_codes) == 0) {
            none
        } else {
            dat[
                observer %in% dup_codes,
                .(
                    rowid,
                    variable = "observer",
                    reason = "Duplicate observer code."
                )
            ]
        }
    } |>
        try_validator(nam = "val6")
)
