`%||%` <- function(x, y) {
  if (is.null(x) || !length(x)) y else x
}

yr2dbnam <- function(yr, prefix = "FIELD", dbnam = "BADOatNZ") {
  glue("{prefix}_{yr}_{dbnam}")
}


colbyID <- function(x, id = "combo") {
  cc <- x[, ..id] |> unique()
  cc[, col := rainbow(.N)]

  merge(x, cc, by = id, all.x = TRUE, sort = FALSE)
}

#' c('1:3', '1-3') |> expand_numeric_string()
#' c('1,4,5,6,7') |> expand_numeric_string()
expand_numeric_string <- function(x) {
  o <- str_squish(x) |> str_remove("\\W$")
  o <- str_replace(o, "\\-", ":")
  o <- glue("c({o})")
  o <- try(parse(text = o) |> eval(), silent = TRUE)
  if (inherits(o, "try-error")) {
    o <- NA
  }
  as.numeric(o)
}


nest2species <- function(nest) {
  x <- substr(nest, 1, 2)
  fcase(
    x == "BA" , "BADO" ,
    x == "WR" , "WRYB" ,
    x == "SO" , "SNZD" ,
    x == "BL" , "BFDO" ,
    default = NA_character_
  )
}


make_combo <- function(d, UL = "UL", LL = "LL", UR = "UR", LR = "LR", short) {
  x <- copy(d)

  if (missing(short)) {
    cols <- c(UL, LL, UR, LR)
    cc <- x[, ..cols]
    setnames(cc, c("UL", "LL", "UR", "LR"))

    o <- cc[, .(COMBO = glue_data(.SD, "{UL}/{LL}|{UR}/{LR}", .na = "~"))]$COMBO
  }

  if (!missing(short)) {
    stopifnot(short %in% c("UL", "LL", "UR", "LR"))

    o <- glue("{x[, ..short][[1]]}", .na = "~")
  }

  o
}


tag_id_from_combo <- function(co) {
  x <- DBq(
    "SELECT DISTINCT tag_id, UL, LL, UR, LR FROM CAPTURES where tag_id is not NULL"
  )
  x[, combo := make_combo(.SD, short = "LR")]
  x[co == combo, tag_id]
}


hatching_prediction <- function(x, .gampath = hatch_pred_gam) {
  require(mgcv)
  fm <- readRDS(.gampath)

  pp <- predict(fm, newdata = x, se.fit = TRUE) |>
    data.frame() |>
    data.table()
  pp[, let(conf.low = fit - 1.96 * se.fit, conf.high = fit + 1.96 * se.fit)]
  setnames(pp, "fit", "predicted")

  pp <- pp[, .(predicted, conf.low, conf.high)]

  cbind(x[, .(nest, date)], pp)
}


DBq <- function(x) {
  o <- try(DataEntry::db_get(x), silent = TRUE)

  if (inherits(o, "try-error")) {
    err <- as.character(attributes(o)$condition)
    if (shiny::isRunning()) {
      showNotification(glue("⚠ {str_trunc(x, 30)}"), type = "error")
    }
    return(data.table(error = err))
  } else {
    return(data.table(o))
  }
}


DBx <- function(x, params = NULL) {
  con <- NULL
  o <- try(
    {
      con <- DataEntry::db_con()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      if (is.null(params)) {
        DBI::dbExecute(con, x)
      } else {
        DBI::dbExecute(con, x, params = params)
      }
    },
    silent = TRUE
  )

  if (inherits(o, "try-error")) {
    err <- as.character(attributes(o)$condition)
    if (shiny::isRunning()) {
      showNotification(glue("Database write failed: {str_trunc(err, 80)}"), type = "error")
    }
    return(FALSE)
  }

  TRUE
}


get_reference_date <- function() {
  x <- DBq(
    "SELECT value FROM settings WHERE variable = 'reference_date' LIMIT 1"
  )

  if ("error" %in% names(x) || nrow(x) == 0 || is.na(x$value[1])) {
    return(NA_Date_)
  }

  as.Date(x$value[1])
}


set_reference_date <- function(refdate) {
  refdate <- as.Date(refdate)

  if (is.na(refdate)) {
    return(FALSE)
  }

  DBx(
    "
    INSERT INTO settings (variable, value)
    VALUES ('reference_date', ?)
    ON DUPLICATE KEY UPDATE
      value = VALUES(value)
    ",
    params = list(as.character(refdate))
  )
}


dbtable_is_updated <- function(tab) {
  tab <- as.character(tab)
  tab <- unique(tab[!is.na(tab) & nzchar(tab)])

  if (!length(tab)) {
    return(sample.int(.Machine$integer.max, 1))
  }

  x <- DBq(glue("CHECKSUM TABLE {paste(tab, collapse = ', ')}"))

  if (!"Checksum" %in% names(x)) {
    return(sample.int(.Machine$integer.max, 1))
  }

  if (!"Table" %in% names(x)) {
    x[, Table := tab[seq_len(.N)]]
  }

  if (!nrow(x) || all(is.na(x$Checksum))) {
    return(sample.int(.Machine$integer.max, 1))
  }

  checksum <- ifelse(is.na(x$Checksum), "NA", as.character(x$Checksum))
  paste(x$`Table`, checksum, collapse = "|")
}

#' x = showTable('CAPTURES')
showTable <- function(tab, exclude = c("pk", "nov"), formatDate = TRUE) {
  cc <- DBq(glue("SHOW COLUMNS FROM {tab};"))
  cc <- cc[!Field %in% exclude]

  o <- DBq(
    glue("SELECT DISTINCT {paste(cc$Field, collapse = ', ')} FROM {tab};")
  )

  if (formatDate && "date" %in% cc$Field) {
    o[, date := format(date, "%m-%d")]
  }

  if ("comments" %in% cc$Field) {
    o[
      !is.na(comments),
      comments := glue_data(
        .SD,
        HTML(
          '<span class="custom-tooltip" 
        data-tooltip="{htmltools::htmlEscape(
          str_replace_all(comments, "(;|\\\\.)\\\\s|(;|\\\\.)$", "\\n"), 
          attribute = TRUE)}">
        {str_trunc(comments, 10, "right")}
      </span>'
        )
      ),
      by = .I
    ]
  }

  o
}


download_plot_pdf <- function(filename, plot, width = 11, height = 8.5) {
  shiny::downloadHandler(
    filename = filename,
    content = function(file) {
      grDevices::cairo_pdf(file = file, width = width, height = height)
      on.exit(grDevices::dev.off(), add = TRUE)

      p <- plot()
      if (!is.null(p)) {
        print(p)
      }
    }
  )
}

try_else <- function(primary, fallback, ...) {
  tryCatch(
    primary,
    error = function(e) fallback(...)
  )
}
