overview_integer_breaks <- function(limits, n = 6L) {
  limits <- as.numeric(limits)
  limits <- limits[is.finite(limits)]

  if (!length(limits)) {
    return(numeric())
  }

  lower <- max(0, ceiling(min(limits)))
  upper <- floor(max(limits))

  if (upper < lower) {
    return(numeric())
  }

  if (upper == lower) {
    return(lower)
  }

  raw_step <- (upper - lower) / max(n - 1L, 1L)
  magnitude <- 10^floor(log10(raw_step))
  normalized_step <- raw_step / magnitude
  step <- c(1, 2, 5, 10)[which(c(1, 2, 5, 10) >= normalized_step)[1]] *
    magnitude
  step <- max(1, step)

  seq(
    from = ceiling(lower / step) * step,
    to = floor(upper / step) * step,
    by = step
  )
}


overview_integer_y_scale <- function() {
  scale_y_continuous(breaks = overview_integer_breaks)
}


overview_histogram_base <- function(ylab) {
  ggplot() +
    labs(
      x = NULL,
      y = ylab
    ) +
    overview_integer_y_scale() +
    theme_bw(base_size = 22) +
    theme(
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 30, hjust = 1)
    )
}


overview_date_scale <- function() {
  scale_x_date(
    date_labels = "%d %b",
    date_breaks = "7 days"
  )
}


overview_date_coordinates <- function(date_limits = NULL) {
  coord_cartesian(
    xlim = if (is.null(date_limits)) NULL else as.Date(date_limits)
  )
}


overview_histogram_plot <- function(x, ylab, date_limits = NULL) {
  x <- data.table(x)

  if (!nrow(x)) {
    return(
      overview_histogram_base(ylab) +
        overview_date_scale() +
        overview_date_coordinates(date_limits)
    )
  }

  x[, plot_date := as.Date(as.character(datetime))]
  x <- x[!is.na(plot_date)]

  if (!nrow(x)) {
    return(
      overview_histogram_base(ylab) +
        overview_date_scale() +
        overview_date_coordinates(date_limits)
    )
  }

  setorder(x, plot_date)

  overview_histogram_base(ylab) +
    geom_histogram(
      data = x,
      mapping = aes(x = plot_date),
      binwidth = 4,
      fill = "#6d7577",
      color = "white"
    ) +
    overview_date_scale() +
    overview_date_coordinates(date_limits)
}


overview_lay_date_bins <- function(x, binwidth = 4L) {
  x <- data.table(x)

  if (
    !nrow(x) ||
      !all(c("nest_id", "datetime") %in% names(x))
  ) {
    return(data.table())
  }

  if (!"tag_id" %in% names(x)) {
    x[, tag_id := NA_character_]
  }

  x[, `:=`(
    nest_id = trimws(as.character(nest_id)),
    tag_id = trimws(as.character(tag_id)),
    plot_date = as.Date(as.character(datetime))
  )]
  x <- x[!is.na(plot_date) & nzchar(nest_id)]

  if (!nrow(x)) {
    return(data.table())
  }

  x[, bin_start := as.Date(
    floor(as.numeric(plot_date) / binwidth) * binwidth,
    origin = "1970-01-01"
  )]

  nest_bins <- unique(x[, .(nest_id, bin_start)])
  bins <- nest_bins[, .(n_nests = .N), by = bin_start]

  geolocators <- unique(
    x[!is.na(tag_id) & nzchar(tag_id), .(bin_start, tag_id)]
  )
  geolocator_bins <- geolocators[, .(
    n_geolocators = uniqueN(tag_id)
  ), by = bin_start]

  bins <- merge(
    bins,
    geolocator_bins,
    by = "bin_start",
    all.x = TRUE,
    sort = TRUE
  )
  bins[is.na(n_geolocators), n_geolocators := 0L]
  bins[, plot_date := bin_start + (binwidth / 2)]
  bins[]
}


overview_lay_date_plot <- function(
  x,
  ylab,
  date_limits = NULL,
  binwidth = 4L
) {
  bins <- overview_lay_date_bins(x, binwidth = binwidth)
  base <- ggplot() +
    labs(x = NULL, y = ylab) +
    scale_y_continuous(
      breaks = overview_integer_breaks,
      expand = expansion(mult = c(0.05, 0.18))
    ) +
    theme_bw(base_size = 22) +
    theme(
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 30, hjust = 1)
    ) +
    overview_date_scale() +
    overview_date_coordinates(date_limits)

  if (!nrow(bins)) {
    return(base)
  }

  annotation_x <- if (is.null(date_limits)) {
    min(bins$bin_start)
  } else {
    as.Date(date_limits)[1]
  }

  base +
    geom_col(
      data = bins,
      mapping = aes(x = plot_date, y = n_nests),
      width = binwidth,
      fill = "#6d7577",
      color = "white"
    ) +
    geom_text(
      data = bins,
      mapping = aes(
        x = plot_date,
        y = n_nests,
        label = n_geolocators
      ),
      vjust = -0.45,
      fontface = "bold",
      size = 5
    ) +
    annotate(
      "label",
      x = annotation_x,
      y = Inf,
      label = paste(
        "Numbers above bars = geolocators deployed on parents",
        "associated with nests in that four-day lay-date bin"
      ),
      hjust = 0,
      vjust = 1.2,
      size = 4.2,
      linewidth = 0.25,
      fill = "white"
    )
}


overview_cumulative_base <- function(ylab) {
  ggplot() +
    labs(
      x = NULL,
      y = ylab
    ) +
    overview_integer_y_scale() +
    theme_bw(base_size = 22) +
    theme(
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 30, hjust = 1)
    )
}


overview_cumulative_counts <- function(
  x,
  date_col = "datetime",
  group_col = NULL
) {
  x <- data.table(x)

  if (!nrow(x) || !date_col %in% names(x)) {
    return(data.table())
  }

  x[, plot_date := as.Date(as.character(get(date_col)))]
  x <- x[!is.na(plot_date)]

  if (!nrow(x)) {
    return(data.table())
  }

  if (is.null(group_col)) {
    x <- x[, .(n = .N), by = plot_date]
    setorder(x, plot_date)
    x[, cumulative_n := cumsum(n)]
    return(x)
  }

  x <- x[, .(n = .N), by = c("plot_date", group_col)]
  setorderv(x, c(group_col, "plot_date"))
  x[, cumulative_n := cumsum(n), by = group_col]
  x
}


overview_step_ribbon_data <- function(x, group_col = NULL) {
  x <- data.table(x)

  if (!nrow(x)) {
    return(data.table())
  }

  end_date <- max(x$plot_date)

  expand_one_group <- function(group_data) {
    setorder(group_data, plot_date)

    step_data <- data.table(
      plot_date = c(
        group_data$plot_date[1],
        group_data$plot_date[1],
        rep(group_data$plot_date[-1], each = 2)
      ),
      cumulative_n = c(
        0,
        group_data$cumulative_n[1],
        as.vector(rbind(
          head(group_data$cumulative_n, -1),
          tail(group_data$cumulative_n, -1)
        ))
      )
    )

    if (tail(step_data$plot_date, 1) < end_date) {
      step_data <- rbindlist(list(
        step_data,
        data.table(
          plot_date = end_date,
          cumulative_n = tail(step_data$cumulative_n, 1)
        )
      ))
    }

    step_data
  }

  if (is.null(group_col)) {
    return(expand_one_group(x))
  }

  rbindlist(
    lapply(unique(x[[group_col]]), function(group_value) {
      step_data <- expand_one_group(
        x[get(group_col) == group_value]
      )
      step_data[, (group_col) := group_value]
      step_data
    }),
    use.names = TRUE
  )
}


overview_cumulative_total <- function(
  x,
  group_value = NULL,
  group_col = "sex"
) {
  x <- data.table(x)

  if (!nrow(x)) {
    return(0L)
  }

  if (!is.null(group_value)) {
    x <- x[as.character(get(group_col)) == group_value]
  }

  if (!nrow(x)) {
    return(0L)
  }

  as.integer(max(x$cumulative_n, na.rm = TRUE))
}


overview_summary_annotation <- function(label = NULL, annotation_date = NULL) {
  if (is.null(label) || !nzchar(label)) {
    return(NULL)
  }

  if (is.null(annotation_date) || is.na(annotation_date)) {
    annotation_date <- Sys.Date()
  }

  annotate(
    "text",
    x = as.Date(annotation_date),
    y = Inf,
    label = label,
    hjust = -0.02,
    vjust = 1.3,
    size = 5.2,
    fontface = "bold",
    lineheight = 1.05
  )
}


overview_cumulative_plot <- function(
  x,
  ylab,
  sex_split = FALSE,
  date_limits = NULL,
  summary_label = NULL
) {
  x <- data.table(x)
  annotation_date <- if (!is.null(date_limits)) {
    as.Date(date_limits)[1]
  } else if (nrow(x)) {
    min(x$plot_date)
  } else {
    Sys.Date()
  }

  if (!nrow(x)) {
    return(
      overview_cumulative_base(ylab) +
        overview_date_scale() +
        overview_date_coordinates(date_limits) +
        overview_summary_annotation(summary_label, annotation_date)
    )
  }

  ribbon_data <- overview_step_ribbon_data(
    x,
    group_col = if (sex_split) "sex" else NULL
  )

  if (!sex_split) {
    return(
      overview_cumulative_base(ylab) +
        geom_ribbon(
          data = ribbon_data,
          mapping = aes(
            x = plot_date,
            ymin = 0,
            ymax = cumulative_n
          ),
          fill = "#6d7577",
          alpha = 0.45
        ) +
        geom_step(
          data = x,
          mapping = aes(x = plot_date, y = cumulative_n),
          direction = "hv",
          color = "#4b5254",
          linewidth = 0.9
        ) +
        overview_summary_annotation(summary_label, annotation_date) +
        overview_date_scale() +
        overview_date_coordinates(date_limits)
    )
  }

  x[, sex := factor(sex, levels = c("Female", "Male"))]
  ribbon_data[, sex := factor(sex, levels = c("Female", "Male"))]

  overview_cumulative_base(ylab) +
    geom_ribbon(
      data = ribbon_data,
      mapping = aes(
        x = plot_date,
        ymin = 0,
        ymax = cumulative_n,
        fill = sex,
        group = sex
      ),
      alpha = 0.38
    ) +
    geom_step(
      data = x,
      mapping = aes(
        x = plot_date,
        y = cumulative_n,
        color = sex,
        group = sex
      ),
      direction = "hv",
      linewidth = 0.9
    ) +
    overview_summary_annotation(summary_label, annotation_date) +
    scale_color_manual(
      name = NULL,
      values = c(Female = "#c43c39", Male = "#2878b5")
    ) +
    scale_fill_manual(
      name = NULL,
      values = c(Female = "#c43c39", Male = "#2878b5")
    ) +
    overview_date_scale() +
    overview_date_coordinates(date_limits) +
    theme(
      legend.position = "inside",
      legend.position.inside = c(
        0.02,
        if (is.null(summary_label)) 0.98 else 0.76
      ),
      legend.justification = c(0, 1)
    )
}


overview_limp_status <- function(comments) {
  comments <- tolower(trimws(as.character(comments)))
  comments[is.na(comments)] <- ""
  comments <- gsub("[[:space:]]+", " ", comments)

  normal_movement <- grepl(
    paste0(
      "\\b(walk(?:s|ed|ing)?|run(?:s|ning)?)\\b.{0,40}",
      "\\b(well|fine|normal(?:ly)?|great|ok(?:ay)?)\\b|",
      "\\b(well|fine|normal(?:ly)?)\\b.{0,40}",
      "\\bwalk(?:s|ed|ing)?\\b"
    ),
    comments,
    perl = TRUE
  )
  limping <- grepl(
    paste0(
      "\\b(limp(?:ing|s|ed)?|limbing|lame(?:ness)?|",
      "hopp(?:ing|s|ed)?)\\b|\\bmoderate\\s+limb\\b"
    ),
    comments,
    perl = TRUE
  )
  possible_limp <- grepl(
    paste0(
      "\\b(slight(?:ly)?|mild(?:ly)?|hesitat(?:e|es|ed|ing|ion)?|",
      "occasional(?:ly)?)\\b|",
      "\\blimp(?:ing|s|ed)?\\??\\s+(?:a\\s+)?bit\\b|",
      "\\b(?:maybe|possibly)\\b.{0,30}\\blimp|",
      "\\bstanding\\b.{0,30}\\bone leg\\b|",
      "\\brelaxing\\b.{0,30}\\bleg\\b.{0,30}\\btag"
    ),
    comments,
    perl = TRUE
  )
  explicit_no_limp <- grepl(
    paste0(
      "\\bno\\s+(?:signs?\\s+of\\s+)?(?:a\\s+)?limp(?:ing)?\\b|",
      "\\bwithout\\s+(?:a\\s+)?limp(?:ing)?\\b|",
      "\\bnot\\s+limp(?:ing)?\\b(?!\\s+(?:as\\s+much|much|less))|",
      "\\bdoes(?:\\s+not|n't)\\s+limp\\b"
    ),
    comments,
    perl = TRUE
  )

  status <- rep("No limp reported", length(comments))
  status[normal_movement] <- "No limp reported"
  status[limping] <- "Limping"
  status[possible_limp] <- "Possible/slight limp"
  status[explicit_no_limp] <- "No limp reported"
  status
}


overview_tagged_mark_label <- function(x) {
  mark <- sub("_[FM]$", "", x)
  gsub("_", "-", mark, fixed = TRUE)
}


overview_tagged_display_mark <- function(
  tarsus_mark,
  right_upper,
  right_tarsus
) {
  display_mark <- as.character(tarsus_mark)
  right_upper <- toupper(trimws(as.character(right_upper)))
  right_tarsus <- toupper(trimws(as.character(right_tarsus)))
  upper_color <- sub("^T", "", right_upper)
  use_upper_color <- !is.na(right_tarsus) &
    nchar(right_tarsus) == 1L &
    !is.na(upper_color) &
    nzchar(upper_color) &
    !upper_color %in% c("X", "M")

  left_tarsus <- sub("_[^_]+$", "", display_mark)
  display_mark[use_upper_color] <- paste0(
    left_tarsus[use_upper_color],
    "_",
    upper_color[use_upper_color],
    ".",
    right_tarsus[use_upper_color]
  )
  display_mark
}


overview_tagged_resighting_plot <- function(x, date_limits = NULL) {
  x <- data.table(x)
  caption <- paste(
    strwrap(
      paste(
        "Diamond = geolocator deployment; circles = resightings.",
        paste(
          "Limp status is inferred from comments; comments without limp or",
          "walking information are treated as no limp."
        )
      ),
      width = 54L
    ),
    collapse = "\n"
  )

  if (!nrow(x)) {
    plot_limits <- if (is.null(date_limits)) {
      c(Sys.Date() - 30, Sys.Date())
    } else {
      as.Date(date_limits)
    }
    annotation_date <- as.Date(
      mean(as.numeric(plot_limits)),
      origin = "1970-01-01"
    )

    return(
      ggplot() +
        annotate(
          "text",
          x = annotation_date,
          y = 0,
          label = "No qualifying tagged-bird histories"
        ) +
        labs(x = NULL, y = NULL, caption = caption) +
        overview_date_scale() +
        overview_date_coordinates(plot_limits) +
        scale_y_continuous(breaks = NULL) +
        theme_bw(base_size = 18) +
        theme(
          panel.grid = element_blank(),
          plot.caption = element_text(hjust = 0.5),
          plot.caption.position = "plot"
        )
    )
  }

  x[, deployment_date := as.Date(as.character(deployment_date))]
  x[, resighting_date := as.Date(as.character(resighting_date))]
  x <- x[!is.na(deployment_date)]

  if (!nrow(x)) {
    return(overview_tagged_resighting_plot(data.table(), date_limits))
  }

  x[, display_mark := overview_tagged_display_mark(
    tarsus_mark,
    right_upper,
    right_tarsus
  )]
  x[, bird_id := paste0(
    display_mark,
    "_",
    fifelse(sex == "Female", "F", "M")
  )]

  histories <- x[, .(
    sex = sex[1],
    deployment_date = min(deployment_date),
    last_date = max(c(deployment_date, resighting_date), na.rm = TRUE)
  ), by = bird_id]
  setorder(histories, deployment_date, sex, bird_id)
  bird_levels <- histories$bird_id
  histories[, bird_id := factor(bird_id, levels = bird_levels)]
  histories[, sex := factor(sex, levels = c("Female", "Male"))]

  events <- x[!is.na(resighting_date)]
  events[, limp_status := overview_limp_status(comments)]
  events[, status_rank := match(
    limp_status,
    c(
      "No limp reported",
      "Possible/slight limp",
      "Limping"
    )
  )]
  setorder(
    events,
    bird_id,
    resighting_date,
    status_rank,
    resighting_pk
  )
  events <- events[, .SD[.N], by = .(bird_id, resighting_date)]
  events[, bird_id := factor(bird_id, levels = bird_levels)]
  events[, sex := factor(sex, levels = c("Female", "Male"))]
  events[, limp_status := factor(
    limp_status,
    levels = c(
      "No limp reported",
      "Possible/slight limp",
      "Limping"
    )
  )]

  ggplot(histories, aes(y = bird_id)) +
    geom_segment(
      aes(
        x = deployment_date,
        xend = last_date,
        yend = bird_id
      ),
      color = "#343a40",
      linewidth = 0.7
    ) +
    geom_point(
      aes(x = deployment_date),
      shape = 23,
      size = 3.2,
      stroke = 0.8,
      fill = "white"
    ) +
    geom_point(
      data = events,
      aes(
        x = resighting_date,
        y = bird_id,
        fill = limp_status
      ),
      shape = 21,
      size = 3.2,
      stroke = 0.7,
      inherit.aes = FALSE
    ) +
    facet_wrap(
      vars(sex),
      ncol = 1,
      scales = "free_y",
      labeller = as_labeller(c(Female = "Females", Male = "Males"))
    ) +
    scale_y_discrete(
      name = NULL,
      position = "right",
      labels = overview_tagged_mark_label
    ) +
    scale_fill_manual(
      name = "Comment-derived limp status",
      values = c(
        "No limp reported" = "#2a9d8f",
        "Possible/slight limp" = "#e9c46a",
        "Limping" = "#d1495b"
      ),
      drop = FALSE
    ) +
    labs(x = NULL, caption = caption) +
    overview_date_scale() +
    overview_date_coordinates(date_limits) +
    guides(fill = guide_legend(ncol = 1, byrow = TRUE)) +
    theme_bw(base_size = 18) +
    theme(
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 30, hjust = 1),
      legend.position = "bottom",
      legend.direction = "vertical",
      legend.title.position = "top",
      legend.justification = "left",
      legend.box.just = "left",
      legend.title = element_text(face = "bold"),
      strip.background = element_rect(fill = "white", color = NA),
      strip.text = element_text(face = "bold"),
      plot.caption = element_text(hjust = 0, lineheight = 1.1),
      plot.caption.position = "plot"
    )
}


overview_date_limits <- function(refdate = get_reference_date()) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    WITH sr AS (
      SELECT CAST(? AS DATE) AS reference_date
    ),
    cr_nests AS (
      SELECT DISTINCT TRIM(nest_id) AS nest_id
      FROM NESTS
      WHERE UPPER(TRIM(COALESCE(site, ''))) = 'CR'
        AND NULLIF(TRIM(nest_id), '') IS NOT NULL
    ),
    lay_dates AS (
      SELECT
        DATE_SUB(
          MAX(e.float_date),
          INTERVAL ROUND(AVG(e.predicted_days_since_laying)) DAY
        ) AS date_
      FROM EGGS_HATCH_PREDICTION e
      INNER JOIN cr_nests cr
        ON e.nest_id = cr.nest_id
      CROSS JOIN sr
      WHERE e.float_date IS NOT NULL
        AND e.predicted_days_since_laying IS NOT NULL
        AND e.float_date <= sr.reference_date
      GROUP BY e.nest_id
    ),
    dated_events AS (
      SELECT n.date AS date_
      FROM NESTS n
      CROSS JOIN sr
      WHERE UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
        AND n.nest_state = 'F'
        AND n.date IS NOT NULL
        AND n.date <= sr.reference_date

      UNION ALL

      SELECT c.date AS date_
      FROM CAPTURES c
      CROSS JOIN sr
      WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
        AND c.date IS NOT NULL
        AND c.date <= sr.reference_date

      UNION ALL

      SELECT r.date AS date_
      FROM RESIGHTINGS r
      CROSS JOIN sr
      WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
        AND r.date IS NOT NULL
        AND r.date <= sr.reference_date

      UNION ALL

      SELECT date_
      FROM lay_dates
      WHERE date_ IS NOT NULL
    )
    SELECT MIN(date_) AS start_date
    FROM dated_events
    ",
    params = list(as.character(refdate))
  )

  start_date <- if (nrow(x) && "start_date" %in% names(x)) {
    as.Date(x$start_date[1])
  } else {
    as.Date(NA)
  }

  if (is.na(start_date)) {
    start_date <- refdate - 30
  }

  c(start_date, refdate)
}


overview_nests_graph <- function(
  refdate = get_reference_date(),
  date_limits = NULL
) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    SELECT
      pk,
      nest_id,
      CAST(CONCAT(date, ' ', COALESCE(time_visit, '00:00:00')) AS DATETIME) AS datetime
    FROM NESTS
    WHERE nest_state = 'F'
      AND UPPER(TRIM(COALESCE(site, ''))) = 'CR'
      AND date IS NOT NULL
      AND date <= ?
    ORDER BY date, time_visit, pk
    ",
    params = list(as.character(refdate))
  )

  x <- data.table(x)

  if (nrow(x)) {
    setorder(x, datetime, pk)
    x <- x[, .SD[1], by = nest_id]
  }

  plot_data <- overview_cumulative_counts(x)

  overview_cumulative_plot(
    x = plot_data,
    ylab = "Cumulative number of\nfound nests",
    date_limits = date_limits,
    summary_label = glue(
      "Total nests found = {overview_cumulative_total(plot_data)}"
    )
  )
}


overview_geolocator_graph <- function(
  refdate = get_reference_date(),
  date_limits = NULL
) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    SELECT
      pk,
      tag_id,
      CASE
        WHEN UPPER(TRIM(field_sex)) IN ('M', 'MU') THEN 'Male'
        WHEN UPPER(TRIM(field_sex)) IN ('F', 'FU') THEN 'Female'
      END AS sex,
      CAST(CONCAT(date, ' 00:00:00') AS DATETIME) AS datetime
    FROM CAPTURES
    WHERE UPPER(TRIM(COALESCE(site, ''))) = 'CR'
      AND tag_type = 'GEO'
      AND tag_action = 'D'
      AND date IS NOT NULL
      AND date <= ?
      AND NULLIF(TRIM(tag_id), '') IS NOT NULL
    ORDER BY date, pk
    ",
    params = list(as.character(refdate))
  )

  x <- data.table(x)

  if (nrow(x)) {
    setorder(x, datetime, pk)
    x <- x[, {
      known_sex <- unique(sex[!is.na(sex)])
      .(
        datetime = datetime[1],
        sex = if (length(known_sex) == 1) known_sex else NA_character_
      )
    }, by = tag_id]
    x <- x[!is.na(sex)]
  }

  plot_data <- overview_cumulative_counts(x, group_col = "sex")

  overview_cumulative_plot(
    x = plot_data,
    ylab = "Cumulative number of\ngeolocators deployed",
    sex_split = TRUE,
    date_limits = date_limits,
    summary_label = glue(
      "N females = ",
      "{overview_cumulative_total(plot_data, 'Female')}\n",
      "N males = ",
      "{overview_cumulative_total(plot_data, 'Male')}"
    )
  )
}


overview_tagged_resightings_graph <- function(
  refdate = get_reference_date(),
  date_limits = NULL
) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    WITH sr AS (
      SELECT CAST(? AS DATE) AS reference_date
    ),
    deployment_rows AS (
      SELECT
        c.pk,
        CONCAT(
          COALESCE(
            NULLIF(TRIM(c.LL), ''),
            NULLIF(TRIM(c.LL_in), ''),
            'X'
          ),
          '_',
          COALESCE(
            NULLIF(TRIM(c.LR), ''),
            NULLIF(TRIM(c.LR_in), ''),
            'X'
          )
        ) AS tarsus_mark,
        COALESCE(
          NULLIF(TRIM(c.UR), ''),
          NULLIF(TRIM(c.UR_in), ''),
          'X'
        ) AS right_upper,
        COALESCE(
          NULLIF(TRIM(c.LR), ''),
          NULLIF(TRIM(c.LR_in), ''),
          'X'
        ) AS right_tarsus,
        CASE
          WHEN UPPER(TRIM(c.field_sex)) IN ('M', 'MU') THEN 'Male'
          WHEN UPPER(TRIM(c.field_sex)) IN ('F', 'FU') THEN 'Female'
        END AS capture_sex,
        c.date AS deployment_date
      FROM CAPTURES c
      CROSS JOIN sr
      WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
        AND UPPER(TRIM(COALESCE(c.tag_type, ''))) = 'GEO'
        AND UPPER(TRIM(COALESCE(c.tag_action, ''))) = 'D'
        AND c.date IS NOT NULL
        AND c.date <= sr.reference_date
        AND NULLIF(TRIM(c.tag_id), '') IS NOT NULL
    ),
    ranked_deployments AS (
      SELECT
        tarsus_mark,
        right_upper,
        right_tarsus,
        capture_sex,
        deployment_date,
        ROW_NUMBER() OVER (
          PARTITION BY tarsus_mark, capture_sex
          ORDER BY deployment_date, pk
        ) AS deployment_rank
      FROM deployment_rows
      WHERE capture_sex IN ('Female', 'Male')
        AND BINARY tarsus_mark <> 'X_X'
    ),
    deployments AS (
      SELECT
        tarsus_mark,
        right_upper,
        right_tarsus,
        capture_sex,
        deployment_date
      FROM ranked_deployments
      WHERE deployment_rank = 1
    ),
    resighting_rows AS (
      SELECT
        r.pk AS resighting_pk,
        CONCAT(
          COALESCE(NULLIF(TRIM(r.LL), ''), 'X'),
          '_',
          COALESCE(NULLIF(TRIM(r.LR), ''), 'X')
        ) AS tarsus_mark,
        CASE
          WHEN UPPER(TRIM(r.sex)) IN ('M', 'MU') THEN 'Male'
          WHEN UPPER(TRIM(r.sex)) IN ('F', 'FU') THEN 'Female'
        END AS resighting_sex,
        r.date AS resighting_date,
        r.comments
      FROM RESIGHTINGS r
      CROSS JOIN sr
      WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
        AND r.date IS NOT NULL
        AND r.date <= sr.reference_date
    )
    SELECT
      d.tarsus_mark,
      d.right_upper,
      d.right_tarsus,
      d.capture_sex AS sex,
      d.deployment_date,
      r.resighting_pk,
      r.resighting_date,
      r.comments
    FROM deployments d
    LEFT JOIN resighting_rows r
      ON r.tarsus_mark = d.tarsus_mark
      AND r.resighting_sex = d.capture_sex
      AND r.resighting_date >= d.deployment_date
    ORDER BY d.capture_sex, d.deployment_date, d.tarsus_mark,
      r.resighting_date, r.resighting_pk
    ",
    params = list(as.character(refdate))
  )

  overview_tagged_resighting_plot(
    x = x,
    date_limits = date_limits
  )
}


overview_band_combos_graph <- function(
  refdate = get_reference_date(),
  date_limits = NULL
) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    WITH sr AS (
      SELECT CAST(? AS DATE) AS reference_date
    ),
    encountered AS (
      SELECT
        FIELD_2026_BADOatNZ.format_mark(c.UL, c.LL, c.UR, c.LR) AS mark,
        c.date,
        CASE
          WHEN UPPER(TRIM(c.field_sex)) IN ('M', 'MU') THEN 'Male'
          WHEN UPPER(TRIM(c.field_sex)) IN ('F', 'FU') THEN 'Female'
        END AS observed_sex
      FROM CAPTURES c
      CROSS JOIN sr
      WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
        AND c.date IS NOT NULL
        AND c.date <= sr.reference_date

      UNION ALL

      SELECT
        FIELD_2026_BADOatNZ.format_mark(r.UL, r.LL, r.UR, r.LR) AS mark,
        r.date,
        CASE
          WHEN UPPER(TRIM(r.sex)) IN ('M', 'MU') THEN 'Male'
          WHEN UPPER(TRIM(r.sex)) IN ('F', 'FU') THEN 'Female'
        END AS observed_sex
      FROM RESIGHTINGS r
      CROSS JOIN sr
      WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
        AND r.date IS NOT NULL
        AND r.date <= sr.reference_date
    ),
    archive_sex AS (
      SELECT
        ca.mark,
        CASE
          WHEN COUNT(DISTINCT CASE
            WHEN LEFT(UPPER(TRIM(ca.gen_sex)), 1) IN ('M', 'F')
            THEN LEFT(UPPER(TRIM(ca.gen_sex)), 1)
          END) = 1
          THEN MAX(CASE
            WHEN LEFT(UPPER(TRIM(ca.gen_sex)), 1) = 'M' THEN 'Male'
            WHEN LEFT(UPPER(TRIM(ca.gen_sex)), 1) = 'F' THEN 'Female'
          END)
        END AS genetic_sex
      FROM CAPTURES_ARCHIVE ca
      INNER JOIN (
        SELECT DISTINCT mark
        FROM encountered
      ) encountered_mark_list
        ON ca.mark = encountered_mark_list.mark
      GROUP BY ca.mark
    ),
    encountered_marks AS (
      SELECT
        e.mark,
        MIN(e.date) AS first_date,
        CASE
          WHEN a.genetic_sex IS NOT NULL THEN a.genetic_sex
          WHEN COUNT(DISTINCT e.observed_sex) = 1
          THEN MAX(e.observed_sex)
        END AS sex
      FROM encountered e
      LEFT JOIN archive_sex a
        ON e.mark = a.mark
      WHERE BINARY e.mark NOT IN ('X-X', 'XX-XX')
      GROUP BY e.mark, a.genetic_sex
    )
    SELECT
      mark,
      sex,
      CAST(CONCAT(first_date, ' 00:00:00') AS DATETIME) AS datetime
    FROM encountered_marks
    WHERE sex IN ('Female', 'Male')
    ORDER BY datetime, mark
    ",
    params = list(as.character(refdate))
  )

  plot_data <- overview_cumulative_counts(x, group_col = "sex")

  overview_cumulative_plot(
    x = plot_data,
    ylab = "Cumulative number of\nunique band combinations",
    sex_split = TRUE,
    date_limits = date_limits,
    summary_label = glue(
      "N females = ",
      "{overview_cumulative_total(plot_data, 'Female')}\n",
      "N males = ",
      "{overview_cumulative_total(plot_data, 'Male')}"
    )
  )
}


overview_lay_date_graph <- function(
  refdate = get_reference_date(),
  date_limits = NULL
) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    WITH sr AS (
      SELECT CAST(? AS DATE) AS reference_date
    ),
    cr_nests AS (
      SELECT DISTINCT nest_id
      FROM NESTS
      WHERE UPPER(TRIM(COALESCE(site, ''))) = 'CR'
        AND NULLIF(TRIM(nest_id), '') IS NOT NULL
    ),
    lay_dates AS (
      SELECT
        TRIM(e.nest_id) AS nest_id,
        DATE_SUB(
          MAX(e.float_date),
          INTERVAL ROUND(AVG(e.predicted_days_since_laying)) DAY
        ) AS estimated_lay_date
      FROM EGGS_HATCH_PREDICTION e
      INNER JOIN cr_nests cr
        ON TRIM(e.nest_id) = cr.nest_id
      CROSS JOIN sr
      WHERE e.float_date IS NOT NULL
        AND e.predicted_days_since_laying IS NOT NULL
        AND e.float_date <= sr.reference_date
      GROUP BY TRIM(e.nest_id)
    ),
    geolocator_deployments AS (
      SELECT DISTINCT
        TRIM(c.nest_id) AS nest_id,
        TRIM(c.tag_id) AS tag_id
      FROM CAPTURES c
      CROSS JOIN sr
      WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
        AND UPPER(TRIM(COALESCE(c.age, ''))) = 'A'
        AND UPPER(TRIM(COALESCE(c.tag_type, ''))) = 'GEO'
        AND UPPER(TRIM(COALESCE(c.tag_action, ''))) = 'D'
        AND NULLIF(TRIM(c.nest_id), '') IS NOT NULL
        AND NULLIF(TRIM(c.tag_id), '') IS NOT NULL
        AND c.date IS NOT NULL
        AND c.date <= sr.reference_date
    )
    SELECT
      l.nest_id,
      CAST(
        CONCAT(
          l.estimated_lay_date,
          ' 00:00:00'
        ) AS DATETIME
      ) AS datetime,
      g.tag_id
    FROM lay_dates l
    LEFT JOIN geolocator_deployments g
      ON l.nest_id = g.nest_id
    WHERE l.estimated_lay_date IS NOT NULL
    ORDER BY datetime, l.nest_id, g.tag_id
    ",
    params = list(as.character(refdate))
  )

  overview_lay_date_plot(
    x = x,
    ylab = "N estimated lay dates",
    date_limits = date_limits,
    binwidth = 4L
  )
}


overview_quota_pie_plot <- function(title, value, quota, fill = "#6d7577") {
  value <- as.integer(value %||% 0)
  quota <- as.integer(quota)

  shown_value <- max(value, 0)
  filled_value <- min(shown_value, quota)

  x <- data.table(
    segment = factor(
      c("filled", "remaining"),
      levels = c("filled", "remaining")
    ),
    n = c(filled_value, quota - filled_value)
  )

  ggplot(
    x,
    aes(x = "", y = n, fill = segment)
  ) +
    geom_col(
      width = 1,
      color = "#8b9395",
      linewidth = 0.35
    ) +
    coord_polar(theta = "y") +
    scale_fill_manual(
      values = c(
        filled = fill,
        remaining = "white"
      )
    ) +
    guides(fill = "none") +
    labs(
      title = title,
      subtitle = glue("{shown_value} / {quota}")
    ) +
    theme_void(base_size = 16) +
    theme(
      plot.title = element_text(
        hjust = 0.5,
        face = "bold",
        size = 16
      ),
      plot.subtitle = element_text(
        hjust = 0.5,
        face = "bold",
        size = 13
      )
    )
}


overview_quota_graph <- function(refdate = get_reference_date()) {
  refdate <- as.Date(refdate)

  geolocators <- db_get(
    "
    SELECT COUNT(DISTINCT NULLIF(TRIM(tag_id), '')) AS n
    FROM CAPTURES
    WHERE tag_type = 'GEO'
      AND tag_action = 'D'
      AND date IS NOT NULL
      AND date <= ?
    ",
    params = list(as.character(refdate))
  )

  non_geolocators <- db_get(
    "
    SELECT COUNT(DISTINCT pk) AS n
    FROM CAPTURES
    WHERE age = 'A'
      AND date IS NOT NULL
      AND date <= ?
      AND (
        NULLIF(TRIM(blood_samp), '') IS NOT NULL
        OR breast_samp = '1'
        OR primary_samp = '1'
      )
      AND (
        NULLIF(TRIM(tag_id), '') IS NULL
        OR tag_action = 'O'
      )
    ",
    params = list(as.character(refdate))
  )

  chicks <- db_get(
    "
    SELECT COUNT(DISTINCT pk) AS n
    FROM CAPTURES
    WHERE age = 'C'
      AND date IS NOT NULL
      AND date <= ?
      AND NULLIF(TRIM(blood_samp), '') IS NOT NULL
    ",
    params = list(as.character(refdate))
  )

  eggs <- db_get(
    "
    SELECT COUNT(
      DISTINCT CONCAT(TRIM(nest_id), '|', egg_id)
    ) AS n
    FROM EGGS
    WHERE date IS NOT NULL
      AND date <= ?
      AND NULLIF(TRIM(nest_id), '') IS NOT NULL
      AND egg_id IS NOT NULL
    ",
    params = list(as.character(refdate))
  )

  quota_counts <- data.table(
    title = c(
      "Eggs\nfloated",
      "Geos\ndeployed",
      "Non-geo\ncaptures",
      "Chicks\nprocessed"
    ),
    value = c(
      eggs$n[1] %||% 0,
      geolocators$n[1] %||% 0,
      non_geolocators$n[1] %||% 0,
      chicks$n[1] %||% 0
    ),
    quota = c(450, 100, 200, 500)
  )

  plots <- lapply(
    seq_len(nrow(quota_counts)),
    function(i) {
      overview_quota_pie_plot(
        title = quota_counts$title[i],
        value = quota_counts$value[i],
        quota = quota_counts$quota[i]
      )
    }
  )

  grid::grid.newpage()
  grid::pushViewport(
    grid::viewport(
      layout = grid::grid.layout(
        nrow = 1,
        ncol = length(plots)
      )
    )
  )

  for (i in seq_along(plots)) {
    print(
      plots[[i]],
      vp = grid::viewport(
        layout.pos.row = 1,
        layout.pos.col = i
      )
    )
  }

  invisible(plots)
}
