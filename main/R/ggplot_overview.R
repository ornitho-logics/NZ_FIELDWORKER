overview_histogram_base <- function(ylab) {
  ggplot() +
    labs(
      x = NULL,
      y = ylab
    ) +
    theme_bw(base_size = 22) +
    theme(
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 30, hjust = 1)
    )
}


overview_date_scale <- function() {
  scale_x_date(
    date_labels = "%d %b",
    date_breaks = "3 days"
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
      binwidth = 1,
      fill = "#6d7577",
      color = "white"
    ) +
    overview_date_scale() +
    overview_date_coordinates(date_limits)
}


overview_cumulative_base <- function(ylab) {
  ggplot() +
    labs(
      x = "Date",
      y = ylab
    ) +
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
      name = "Sex",
      values = c(Female = "#c43c39", Male = "#2878b5")
    ) +
    scale_fill_manual(
      name = "Sex",
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


overview_date_limits <- function(refdate = get_reference_date()) {
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
    ylab = "Cumulative number of found nests",
    date_limits = date_limits,
    summary_label = glue(
      "Total number of nests found = {overview_cumulative_total(plot_data)}"
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
    ylab = "Cumulative number of geolocators deployed",
    sex_split = TRUE,
    date_limits = date_limits,
    summary_label = glue(
      "Number of females with geolocators = ",
      "{overview_cumulative_total(plot_data, 'Female')}\n",
      "Number of males with geolocators = ",
      "{overview_cumulative_total(plot_data, 'Male')}"
    )
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
    ylab = "Cumulative number of unique band combinations",
    sex_split = TRUE,
    date_limits = date_limits,
    summary_label = glue(
      "Number of females = ",
      "{overview_cumulative_total(plot_data, 'Female')}\n",
      "Number of males = ",
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
    SELECT
      e.nest_id,
      CAST(
        CONCAT(
          DATE_SUB(
            MAX(float_date),
            INTERVAL ROUND(AVG(predicted_days_since_laying)) DAY
          ),
          ' 00:00:00'
        ) AS DATETIME
      ) AS datetime
    FROM EGGS_HATCH_PREDICTION e
    INNER JOIN (
      SELECT DISTINCT nest_id
      FROM NESTS
      WHERE UPPER(TRIM(COALESCE(site, ''))) = 'CR'
        AND NULLIF(TRIM(nest_id), '') IS NOT NULL
    ) cr
      ON e.nest_id = cr.nest_id
    WHERE e.float_date IS NOT NULL
      AND e.predicted_days_since_laying IS NOT NULL
      AND e.float_date <= ?
    GROUP BY e.nest_id
    ORDER BY datetime, e.nest_id
    ",
    params = list(as.character(refdate))
  )

  overview_histogram_plot(
    x = x,
    ylab = "N estimated lay dates",
    date_limits = date_limits
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
      "Eggs floated",
      "Geolocators deployed",
      "Non-geolocator captures",
      "Chicks processed"
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
