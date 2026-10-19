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


overview_hatching_date_scale <- function() {
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
      binwidth = 4,
      fill = "#6d7577",
      color = "white"
    ) +
    overview_date_scale() +
    overview_date_coordinates(date_limits)
}


overview_hatching_forecast_plot <- function(
  x,
  refdate,
  binwidth = 1L
) {
  refdate <- as.Date(refdate)
  x <- data.table(x)
  forecast_start <- refdate + 1L
  empty_limits <- c(refdate - 3L, forecast_start + binwidth)

  base <- overview_histogram_base("N anticipated hatching events") +
    overview_hatching_date_scale()

  reference_vline <- geom_vline(
    xintercept = refdate,
    color = "red",
    linewidth = 0.8,
    linetype = "solid"
  )
  reference_label <- annotate(
      "text",
      x = refdate - 1L,
      y = Inf,
      label = "reference date",
      angle = 90,
      hjust = 1.05,
      vjust = 0.5,
      color = "red",
      size = 4
    )

  if (!nrow(x) || !"datetime" %in% names(x)) {
    return(
      base +
        reference_vline +
        reference_label +
        overview_date_coordinates(empty_limits)
    )
  }

  x[, plot_date := as.Date(as.character(datetime))]
  x <- x[!is.na(plot_date) & plot_date >= forecast_start]

  if (!nrow(x)) {
    return(
      base +
        reference_vline +
        reference_label +
        overview_date_coordinates(empty_limits)
    )
  }

  max_date <- max(x$plot_date, na.rm = TRUE)
  plot_limits <- c(
    refdate - 3L,
    max(max_date, forecast_start + binwidth)
  )

  base +
    geom_histogram(
      data = x,
      mapping = aes(x = plot_date),
      binwidth = binwidth,
      boundary = as.numeric(forecast_start),
      fill = "#6d7577",
      color = "white"
    ) +
    reference_vline +
    reference_label +
    overview_date_coordinates(plot_limits)
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


overview_pair_tallies_current <- function(
  refdate = get_reference_date(),
  require_geolocator = TRUE
) {
  refdate <- as.Date(refdate)
  pair_condition <- if (isTRUE(require_geolocator)) {
    "m.has_geolocator = 1 AND f.has_geolocator = 1"
  } else {
    "m.has_banded_mark = 1 AND f.has_banded_mark = 1"
  }

  # Keep this query aligned with the parent identity and MM-follow-up logic
  # used by the current TODO_LIST view. TN (and other non-MM) captures are
  # confirmed directly; MM captures need either one qualifying nest-behaviour
  # resighting or three identity-matching resightings, unless X-X follow-up
  # confirms the parent under the same protocol.
  sql <- paste(
    c(
      "WITH sr AS (",
      "  SELECT CAST(? AS DATE) AS reference_date",
      "),",
      "capture_raw AS (",
      "  SELECT",
      "    NULLIF(TRIM(c.nest_id), '') AS nest_id,",
      "    LEFT(UPPER(TRIM(c.field_sex)), 1) AS sex,",
      "    UPPER(TRIM(COALESCE(c.capture_method, ''))) AS capture_method,",
      "    c.date AS event_date,",
      "    CAST(CONCAT(c.date, ' ', COALESCE(c.released, c.caught, '00:00:00')) AS DATETIME) AS event_datetime,",
      "    c.pk AS event_pk,",
      "    CASE WHEN UPPER(TRIM(COALESCE(c.capture_status, ''))) = 'D' THEN 1 ELSE 0 END AS is_dead,",
      "    CASE WHEN UPPER(TRIM(COALESCE(c.capture_status, ''))) <> 'D'",
      "      AND UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), ''))) IN ('X', 'XX')",
      "      AND UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), ''))) IN ('X', 'XX')",
      "      THEN 1 ELSE 0 END AS is_confirmed_xx,",
      "    UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), ''))) AS UL_obs,",
      "    CASE WHEN UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), ''))) IN ('X', 'XX') THEN 'X' ELSE UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), ''))) END AS LL_obs,",
      "    UPPER(COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), ''))) AS UR_obs,",
      "    CASE WHEN UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), ''))) IN ('X', 'XX') THEN 'X' ELSE UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), ''))) END AS LR_obs,",
      "    UPPER(TRIM(COALESCE(c.tag_type, ''))) AS tag_type,",
      "    UPPER(TRIM(COALESCE(c.tag_action, ''))) AS tag_action,",
      "    NULLIF(TRIM(c.tag_id), '') AS tag_id,",
      "    NULLIF(TRIM(c.ring), '') AS ring",
      "  FROM CAPTURES c",
      "  CROSS JOIN sr",
      "  WHERE NULLIF(TRIM(c.nest_id), '') IS NOT NULL",
      "    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'",
      "    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'",
      "    AND UPPER(TRIM(COALESCE(c.age, ''))) = 'A'",
      "    AND LEFT(UPPER(TRIM(c.field_sex)), 1) IN ('M', 'F')",
      "    AND c.date IS NOT NULL",
      "    AND c.date <= sr.reference_date",
      "),",
      "capture_events AS (",
      "  SELECT",
      "    r.*,",
      "    CASE",
      "      WHEN r.is_dead = 1 THEN 'dead'",
      "      WHEN r.is_confirmed_xx = 1 THEN 'X-X'",
      "      WHEN (r.UL_obs IS NOT NULL AND UPPER(r.UL_obs) NOT REGEXP '^(X+|M)$')",
      "        OR (r.LL_obs IS NOT NULL AND UPPER(r.LL_obs) NOT REGEXP '^(X+|M)$')",
      "        OR (r.UR_obs IS NOT NULL AND UPPER(r.UR_obs) NOT REGEXP '^(X+|M)$')",
      "        OR (r.LR_obs IS NOT NULL AND UPPER(r.LR_obs) NOT REGEXP '^(X+|M)$')",
      "      THEN FIELD_2026_BADOatNZ.format_mark(r.UL_obs, r.LL_obs, r.UR_obs, r.LR_obs)",
      "      ELSE NULL",
      "    END AS mark,",
      "    CASE",
      "      WHEN (r.tag_type = 'GEO' AND r.tag_action IN ('D', 'S', 'N') AND r.tag_id IS NOT NULL)",
      "        OR UPPER(COALESCE(r.UL_obs, '')) REGEXP '^T[A-Z0-9]*$'",
      "        OR UPPER(COALESCE(r.UR_obs, '')) REGEXP '^T[A-Z0-9]*$'",
      "      THEN 1 ELSE 0",
      "    END AS has_geolocator,",
      "    CASE WHEN r.LL_obs IS NOT NULL AND r.LR_obs IS NOT NULL THEN 1 ELSE 0 END AS has_complete_tarsal_pair,",
      "    CASE WHEN r.capture_method = 'TN' THEN 1 ELSE 0 END AS direct_nest_capture_rank,",
      "    1 AS source_rank",
      "  FROM capture_raw r",
      "),",
      "resighting_raw AS (",
      "  SELECT",
      "    NULLIF(TRIM(r.nest_id), '') AS nest_id,",
      "    LEFT(UPPER(TRIM(r.sex)), 1) AS sex,",
      "    r.date AS event_date,",
      "    r.pk AS event_pk,",
      "    UPPER(TRIM(COALESCE(r.behav, ''))) AS behav,",
      "    CASE WHEN UPPER(NULLIF(TRIM(r.UL), '')) IN ('X', 'XX') THEN 'X' ELSE UPPER(NULLIF(TRIM(r.UL), '')) END AS UL_obs,",
      "    CASE WHEN UPPER(NULLIF(TRIM(r.LL), '')) IN ('X', 'XX') THEN 'X' ELSE UPPER(NULLIF(TRIM(r.LL), '')) END AS LL_obs,",
      "    CASE WHEN UPPER(NULLIF(TRIM(r.UR), '')) IN ('X', 'XX') THEN 'X' ELSE UPPER(NULLIF(TRIM(r.UR), '')) END AS UR_obs,",
      "    CASE WHEN UPPER(NULLIF(TRIM(r.LR), '')) IN ('X', 'XX') THEN 'X' ELSE UPPER(NULLIF(TRIM(r.LR), '')) END AS LR_obs,",
      "    CASE WHEN UPPER(NULLIF(TRIM(r.UL), '')) REGEXP '^T[A-Z0-9]*$' OR UPPER(NULLIF(TRIM(r.UR), '')) REGEXP '^T[A-Z0-9]*$' THEN 1 ELSE 0 END AS has_geolocator",
      "  FROM RESIGHTINGS r",
      "  CROSS JOIN sr",
      "  WHERE NULLIF(TRIM(r.nest_id), '') IS NOT NULL",
      "    AND UPPER(TRIM(r.nest_id)) <> 'NO_NEST'",
      "    AND UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'",
      "    AND UPPER(TRIM(COALESCE(r.age, ''))) = 'A'",
      "    AND LEFT(UPPER(TRIM(r.sex)), 1) IN ('M', 'F')",
      "    AND r.date IS NOT NULL",
      "    AND r.date <= sr.reference_date",
      "),",
      "resighting_scored AS (",
      "  SELECT",
      "    r.*,",
      "    CASE",
      "      WHEN r.LL_obs = 'X' AND r.LR_obs = 'X' THEN 'X-X'",
      "      WHEN (r.UL_obs IS NOT NULL AND r.UL_obs NOT REGEXP '^(X+|M)$')",
      "        OR (r.LL_obs IS NOT NULL AND r.LL_obs NOT REGEXP '^(X+|M)$')",
      "        OR (r.UR_obs IS NOT NULL AND r.UR_obs NOT REGEXP '^(X+|M)$')",
      "        OR (r.LR_obs IS NOT NULL AND r.LR_obs NOT REGEXP '^(X+|M)$')",
      "      THEN FIELD_2026_BADOatNZ.format_mark(r.UL_obs, r.LL_obs, r.UR_obs, r.LR_obs)",
      "      ELSE NULL",
      "    END AS mark,",
      "    CASE WHEN r.LL_obs = 'X' AND r.LR_obs = 'X' THEN 1 ELSE 0 END AS is_confirmed_xx,",
      "    CASE WHEN r.LL_obs = 'X' AND r.LR_obs = 'X' THEN 1",
      "      WHEN (r.UL_obs IS NOT NULL AND r.UL_obs NOT REGEXP '^(X|M)$')",
      "        OR (r.LL_obs IS NOT NULL AND r.LL_obs NOT REGEXP '^(X|M)$')",
      "        OR (r.UR_obs IS NOT NULL AND r.UR_obs NOT REGEXP '^(X|M)$')",
      "        OR (r.LR_obs IS NOT NULL AND r.LR_obs NOT REGEXP '^(X|M)$') THEN 1 ELSE 0 END AS has_informative_band,",
      "    CASE WHEN r.LL_obs IS NOT NULL AND r.LR_obs IS NOT NULL THEN 1 ELSE 0 END AS has_complete_tarsal_pair,",
      "    (r.UL_obs IS NOT NULL) + (r.LL_obs IS NOT NULL) + (r.UR_obs IS NOT NULL) + (r.LR_obs IS NOT NULL) AS observed_segment_count,",
      "    CASE WHEN r.behav REGEXP '(^|[^A-Z])(BW|NM|IN|BC|FC|AC)([^A-Z]|$)' THEN 1 ELSE 0 END AS has_matching_nest_behav",
      "  FROM resighting_raw r",
      "),",
      "resighting_with_latest_values AS (",
      "  SELECT",
      "    r.*,",
      "    FIRST_VALUE(r.UL_obs) OVER (PARTITION BY r.nest_id, r.sex ORDER BY r.event_date DESC, r.event_pk DESC) AS latest_UL_obs,",
      "    FIRST_VALUE(r.LL_obs) OVER (PARTITION BY r.nest_id, r.sex ORDER BY r.event_date DESC, r.event_pk DESC) AS latest_LL_obs,",
      "    FIRST_VALUE(r.UR_obs) OVER (PARTITION BY r.nest_id, r.sex ORDER BY r.event_date DESC, r.event_pk DESC) AS latest_UR_obs,",
      "    FIRST_VALUE(r.LR_obs) OVER (PARTITION BY r.nest_id, r.sex ORDER BY r.event_date DESC, r.event_pk DESC) AS latest_LR_obs",
      "  FROM resighting_scored r",
      "),",
      "resighting_ranked AS (",
      "  SELECT",
      "    r.*,",
      "    ROW_NUMBER() OVER (",
      "      PARTITION BY r.nest_id, r.sex",
      "      ORDER BY",
      "        (CASE WHEN (r.latest_UL_obs IS NULL OR r.UL_obs IS NULL OR r.latest_UL_obs = r.UL_obs)",
      "          AND (r.latest_LL_obs IS NULL OR r.LL_obs IS NULL OR r.latest_LL_obs = r.LL_obs)",
      "          AND (r.latest_UR_obs IS NULL OR r.UR_obs IS NULL OR r.latest_UR_obs = r.UR_obs)",
      "          AND (r.latest_LR_obs IS NULL OR r.LR_obs IS NULL OR r.latest_LR_obs = r.LR_obs) THEN 1 ELSE 0 END) DESC,",
      "        r.has_informative_band DESC,",
      "        r.has_complete_tarsal_pair DESC,",
      "        r.has_geolocator DESC,",
      "        r.observed_segment_count DESC,",
      "        r.event_date DESC,",
      "        r.event_pk DESC",
      "    ) AS row_num",
      "  FROM resighting_with_latest_values r",
      "),",
      "adult_resighting_latest AS (",
      "  SELECT r.*",
      "  FROM resighting_ranked r",
      "  WHERE r.row_num = 1",
      "    AND NOT EXISTS (",
      "      SELECT 1",
      "      FROM capture_events c",
      "      WHERE c.nest_id = r.nest_id",
      "        AND c.sex <> r.sex",
      "        AND c.LL_obs IS NOT NULL",
      "        AND c.LR_obs IS NOT NULL",
      "        AND r.LL_obs = c.LL_obs",
      "        AND r.LR_obs = c.LR_obs",
      "    )",
      "),",
      "identity_events AS (",
      "  SELECT",
      "    c.nest_id, c.sex, c.event_date, c.event_datetime, c.event_pk,",
      "    c.source_rank, c.direct_nest_capture_rank, c.has_complete_tarsal_pair,",
      "    c.mark, c.is_confirmed_xx, c.has_geolocator, c.is_dead,",
      "    CASE WHEN c.has_geolocator = 1 OR UPPER(COALESCE(c.mark, '')) REGEXP '(^|[.-])T[A-Z0-9]*($|[.-])' THEN 1 ELSE 0 END AS tag_segment_rank",
      "  FROM capture_events c",
      "  WHERE c.mark IS NOT NULL",
      "  UNION ALL",
      "  SELECT",
      "    r.nest_id, r.sex, r.event_date, NULL AS event_datetime, r.event_pk,",
      "    0 AS source_rank, 0 AS direct_nest_capture_rank, r.has_complete_tarsal_pair,",
      "    r.mark, r.is_confirmed_xx, r.has_geolocator, 0 AS is_dead,",
      "    CASE WHEN r.has_geolocator = 1 OR UPPER(COALESCE(r.mark, '')) REGEXP '(^|[.-])T[A-Z0-9]*($|[.-])' THEN 1 ELSE 0 END AS tag_segment_rank",
      "  FROM adult_resighting_latest r",
      "  WHERE r.mark IS NOT NULL",
      "),",
      "identity_ranked AS (",
      "  SELECT",
      "    e.*,",
      "    ROW_NUMBER() OVER (",
      "      PARTITION BY e.nest_id, e.sex",
      "      ORDER BY e.is_dead DESC, e.tag_segment_rank DESC, e.has_complete_tarsal_pair DESC,",
      "        e.direct_nest_capture_rank DESC, e.source_rank DESC, e.event_date DESC,",
      "        e.event_datetime DESC, e.event_pk DESC",
      "    ) AS row_num",
      "  FROM identity_events e",
      "),",
      "identity AS (",
      "  SELECT * FROM identity_ranked WHERE row_num = 1",
      "),",
      "mm_capture_ranked AS (",
      "  SELECT",
      "    c.*,",
      "    ROW_NUMBER() OVER (PARTITION BY c.nest_id, c.sex ORDER BY c.event_date DESC, c.event_datetime DESC, c.event_pk DESC) AS row_num",
      "  FROM capture_events c",
      "  WHERE c.capture_method = 'MM'",
      "),",
      "mm_capture_latest AS (",
      "  SELECT",
      "    m.*,",
      "    CASE WHEN UPPER(TRIM(COALESCE(m.ring, ''))) IN ('CP19738', 'CP19739', 'CP19693', 'CP19848') THEN 1 ELSE 0 END AS requires_spacer_identity",
      "  FROM mm_capture_ranked m",
      "  WHERE m.row_num = 1",
      "),",
      "association_resighting_candidates AS (",
      "  SELECT nest_id, sex, event_date, event_pk, mark, LL_obs, LR_obs, is_confirmed_xx, has_geolocator AS has_geo,",
      "    has_matching_nest_behav, has_matching_nest_behav AS has_nest_behav",
      "  FROM resighting_scored",
      "  WHERE mark IS NOT NULL",
      "),",
      "mm_post_matches AS (",
      "  SELECT",
      "    mm.nest_id, mm.sex, mm.mark AS mm_capture_mark, mm.LL_obs AS mm_LL_norm, mm.LR_obs AS mm_LR_norm,",
      "    mm.requires_spacer_identity, a.mark, a.is_confirmed_xx, a.has_geo, a.event_date, a.event_pk,",
      "    a.has_matching_nest_behav, a.has_nest_behav,",
      "    CASE",
      "      WHEN (mm.requires_spacer_identity = 1 AND UPPER(TRIM(a.mark)) = UPPER(TRIM(mm.mark)))",
      "        OR (mm.requires_spacer_identity = 0 AND mm.LL_obs IS NOT NULL AND mm.LR_obs IS NOT NULL",
      "          AND a.LL_obs IS NOT NULL AND a.LR_obs IS NOT NULL",
      "          AND a.LL_obs = mm.LL_obs AND a.LR_obs = mm.LR_obs)",
      "      THEN 1 ELSE 0",
      "    END AS identity_match",
      "  FROM mm_capture_latest mm",
      "  INNER JOIN association_resighting_candidates a",
      "    ON a.nest_id = mm.nest_id",
      "    AND a.sex = mm.sex",
      "    AND a.event_date >= mm.event_date",
      "),",
      "mm_followup_counts AS (",
      "  SELECT",
      "    mm.nest_id, mm.sex, mm.mark AS mm_capture_mark,",
      "    COALESCE(SUM(m.identity_match), 0) AS n_matching_post_mm_resightings,",
      "    COALESCE(MAX(CASE WHEN m.identity_match = 1 AND m.has_matching_nest_behav = 1 THEN 1 ELSE 0 END), 0) AS has_matching_nest_behav,",
      "    COALESCE(MAX(CASE WHEN m.is_confirmed_xx = 1 AND m.has_nest_behav = 1 THEN 1 ELSE 0 END), 0) AS has_xx_nest_behav,",
      "    MAX(CASE WHEN m.is_confirmed_xx = 1 AND m.has_nest_behav = 1 THEN m.event_date ELSE NULL END) AS xx_nest_behav_date,",
      "    MAX(CASE WHEN m.identity_match = 1 THEN m.event_date ELSE NULL END) AS matching_post_mm_resight_date,",
      "    COALESCE(MAX(CASE WHEN m.is_confirmed_xx = 1 THEN 1 ELSE 0 END), 0) AS post_mm_xx_seen",
      "  FROM mm_capture_latest mm",
      "  LEFT JOIN mm_post_matches m",
      "    ON m.nest_id = mm.nest_id AND m.sex = mm.sex",
      "  GROUP BY mm.nest_id, mm.sex, mm.mark",
      "),",
      "mm_followup AS (",
      "  SELECT",
      "    f.*,",
      "    CASE",
      "      WHEN COALESCE(f.has_matching_nest_behav, 0) = 0",
      "       AND COALESCE(f.has_xx_nest_behav, 0) = 0",
      "       AND COALESCE(f.n_matching_post_mm_resightings, 0) < 3",
      "      THEN 1 ELSE 0",
      "    END AS mm_resight_pending,",
      "    CASE",
      "      WHEN f.has_xx_nest_behav = 1",
      "       AND NOT EXISTS (",
      "         SELECT 1 FROM capture_events later_capture",
      "         WHERE later_capture.nest_id = f.nest_id",
      "           AND later_capture.sex = f.sex",
      "           AND later_capture.mark IS NOT NULL",
      "           AND later_capture.mark <> 'X-X'",
      "           AND LOWER(TRIM(later_capture.mark)) <> 'dead'",
      "           AND later_capture.event_date >= f.xx_nest_behav_date",
      "       )",
      "       AND (f.matching_post_mm_resight_date IS NULL OR f.matching_post_mm_resight_date <= f.xx_nest_behav_date)",
      "      THEN 1 ELSE 0",
      "    END AS mm_xx_parent_confirmed",
      "  FROM mm_followup_counts f",
      "),",
      "parent_event_flags AS (",
      "  SELECT",
      "    i.*,",
      "    COALESCE(m.mm_resight_pending, 0) AS mm_resight_pending,",
      "    m.mm_capture_mark,",
      "    COALESCE(m.mm_xx_parent_confirmed, 0) AS mm_xx_parent_confirmed,",
      "    COALESCE(m.post_mm_xx_seen, 0) AS post_mm_xx_seen,",
      "    CASE",
      "      WHEN COALESCE(m.mm_xx_parent_confirmed, 0) = 1 THEN 'X-X'",
      "      WHEN COALESCE(m.mm_resight_pending, 0) = 1 AND m.mm_capture_mark IS NOT NULL",
      "        THEN CASE WHEN COALESCE(m.post_mm_xx_seen, 0) = 1 THEN CONCAT(m.mm_capture_mark, ' & X-X') ELSE m.mm_capture_mark END",
      "      ELSE i.mark",
      "    END AS selected_mark",
      "  FROM identity i",
      "  LEFT JOIN mm_followup m",
      "    ON m.nest_id = i.nest_id AND m.sex = i.sex",
      "),",
      "parent_events AS (",
      "  SELECT",
      "    nest_id, sex,",
      "    CASE WHEN mm_xx_parent_confirmed = 1 OR mm_resight_pending = 1",
      "      THEN 0 ELSE has_geolocator END AS has_geolocator,",
      "    CASE WHEN mm_resight_pending = 1 THEN 0 ELSE 1 END AS association_confirmed,",
      "    CASE WHEN selected_mark IS NOT NULL",
      "      AND LOWER(selected_mark) <> 'dead'",
      "      AND UPPER(selected_mark) <> 'X-X' THEN 1 ELSE 0 END AS has_banded_mark",
      "  FROM parent_event_flags",
      ")"
    ),
    collapse = "\n"
  )

  sql <- paste0(
    sql,
    "\n, eligible_pairs AS (",
    "\n  SELECT m.nest_id, m.association_confirmed AS m_confirmed,",
    "\n    f.association_confirmed AS f_confirmed",
    "\n  FROM parent_events m",
    "\n  INNER JOIN parent_events f ON m.nest_id = f.nest_id",
    "\n  WHERE m.sex = 'M' AND f.sex = 'F'",
    "\n    AND ", pair_condition,
    "\n)",
    "\nSELECT",
    "\n  COUNT(CASE WHEN m_confirmed = 0 OR f_confirmed = 0 THEN 1 END) AS n_unconfirmed_pairs",
    "\nFROM eligible_pairs"
  )

  x <- data.table(db_get(sql, params = list(as.character(refdate))))

  if ("error" %in% names(x)) {
    stop(
      "overview_pair_tallies_current() database query failed: ",
      as.character(x$error[1]),
      call. = FALSE
    )
  }

  required_columns <- "n_unconfirmed_pairs"
  if (!all(required_columns %in% names(x))) {
    stop(
      "overview_pair_tallies_current() returned an unexpected result.",
      call. = FALSE
    )
  }

  as_count <- function(value) {
    if (!length(value) || is.na(value[1])) {
      return(0L)
    }
    as.integer(value[1])
  }

  if (!nrow(x)) {
    return(c(unconfirmed_pairs = 0L))
  }

  c(unconfirmed_pairs = as_count(x$n_unconfirmed_pairs))
}


overview_pair_tallies <- function(
  refdate = get_reference_date(),
  require_geolocator = TRUE
) {
  overview_pair_tallies_current(
    refdate = refdate,
    require_geolocator = require_geolocator
  )
}


overview_pair_confirmation_caption <- function() {
  paste(
    "Parents are confirmed if they were either:",
    "1) caught with the nest trap;",
    "2) caught with the mist net but resighted around the nest 3 times; or",
    "3) caught with the mist net but resighted with behav class \"IN\", \"NM\", \"BW\", \"BC\", \"FC\", or \"AC\".",
    sep = "\n"
  )
}


overview_cumulative_caption <- function(caption) {
  if (is.null(caption) || !nzchar(caption)) {
    return(list())
  }

  list(
    labs(caption = caption),
    theme(
      plot.caption = element_text(
        hjust = 0.5,
        size = 10,
        lineheight = 1.05,
        margin = ggplot2::margin(t = 8)
      )
    )
  )
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
  summary_label = NULL,
  caption = NULL
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
        overview_summary_annotation(summary_label, annotation_date) +
        overview_cumulative_caption(caption)
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
        overview_cumulative_caption(caption) +
        overview_date_scale() +
        overview_date_coordinates(date_limits)
    )
  }

  x[, sex := factor(sex, levels = c("Female", "Male"))]
  ribbon_data[, sex := factor(sex, levels = c("Female", "Male"))]
  summary_lines <- if (is.null(summary_label)) {
    0L
  } else {
    length(strsplit(summary_label, "\n", fixed = TRUE)[[1]])
  }
  legend_y <- if (!summary_lines) {
    0.98
  } else {
    max(0.48, 0.98 - (0.11 * summary_lines))
  }

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
    overview_cumulative_caption(caption) +
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
        legend_y
      ),
      legend.justification = c(0, 1)
    )
}


overview_limp_status <- function(comments) {
  comments <- tolower(trimws(as.character(comments)))
  comments[is.na(comments)] <- ""
  comments <- gsub("[[:space:]]+", " ", comments)

  structured_no_limp <- grepl(
    "\\blimp\\s*[:=]?\\s*0\\b",
    comments,
    perl = TRUE
  )
  structured_slight_limp <- grepl(
    "\\blimp\\s*[:=]?\\s*1\\b",
    comments,
    perl = TRUE
  )
  structured_limping <- grepl(
    "\\blimp\\s*[:=]?\\s*2\\b",
    comments,
    perl = TRUE
  )

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
  status[structured_no_limp] <- "No limp reported"
  status[structured_slight_limp] <- "Possible/slight limp"
  status[structured_limping] <- "Limping"
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


overview_deployment_linetype <- function(capture_status) {
  capture_status <- toupper(trimws(as.character(capture_status)))
  ifelse(!is.na(capture_status) & capture_status == "C", "dashed", "solid")
}


overview_tagged_resighting_plot <- function(x, date_limits = NULL) {
  x <- data.table(x)
  caption <- paste(
    strwrap(
      paste(
        "Diamond = geolocator deployment; circles = resightings.",
        paste(
          "Dashed lines indicate deployment during a band-combination change",
          "(capture_status = C)."
        ),
        paste(
          "limp0 = no limp, limp1 = possible/slight limp, and limp2 = limping;",
          "older comments are interpreted from text, and no limp information",
          "is treated as no limp."
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

  if (!"deployment_capture_status" %in% names(x)) {
    x[, deployment_capture_status := NA_character_]
  }

  tagged_date_limits <- c(
    min(x$deployment_date) - 2L,
    if (is.null(date_limits)) {
      max(c(x$deployment_date, x$resighting_date), na.rm = TRUE)
    } else {
      as.Date(date_limits)[2]
    }
  )

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
    last_date = max(c(deployment_date, resighting_date), na.rm = TRUE),
    deployment_linetype = overview_deployment_linetype(
      deployment_capture_status[1]
    )
  ), by = bird_id]
  setorder(histories, deployment_date, sex, bird_id)
  bird_levels <- histories$bird_id
  histories[, bird_id := factor(bird_id, levels = bird_levels)]
  histories[, sex := factor(sex, levels = c("Female", "Male"))]
  facet_labels <- histories[
    , .SD[which.max(as.integer(bird_id))],
    by = sex
  ][, .(
    sex,
    bird_id,
    label_date = tagged_date_limits[1] + 0.25,
    facet_label = fifelse(sex == "Female", "Females", "Males")
  )]

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
        yend = bird_id,
        linetype = deployment_linetype
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
    geom_text(
      data = facet_labels,
      aes(
        x = label_date,
        y = bird_id,
        label = facet_label
      ),
      hjust = 0,
      vjust = 1.2,
      fontface = "bold",
      size = 5,
      inherit.aes = FALSE
    ) +
    facet_grid(
      rows = vars(sex),
      scales = "free_y",
      space = "free_y"
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
    scale_linetype_identity(guide = "none") +
    labs(x = NULL, caption = caption) +
    overview_date_scale() +
    overview_date_coordinates(tagged_date_limits) +
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
      strip.background = element_blank(),
      strip.text.y = element_blank(),
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
        UPPER(TRIM(c.capture_status)) AS deployment_capture_status,
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
        deployment_capture_status,
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
        deployment_capture_status,
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
      d.deployment_capture_status,
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


overview_band_combo_normalize_value <- function(x, remove_hyphen = FALSE) {
  x <- toupper(trimws(as.character(x)))
  x[is.na(x) | !nzchar(x) | x %in% c(
    "NA", "N/A", "NULL", "X", "XX", "X-X", "XX-XX", "M"
  )] <- NA_character_
  if (remove_hyphen) {
    x <- gsub("-", "", x, fixed = TRUE)
    x[x %in% c("X", "XX", "M")] <- NA_character_
  }
  x
}


overview_band_combo_normalize_sex <- function(x) {
  x <- toupper(trimws(as.character(x)))
  out <- rep(NA_character_, length(x))
  out[x %in% c("M", "MU")] <- "Male"
  out[x %in% c("F", "FU")] <- "Female"
  out
}


overview_band_combo_spacer_key <- function(ul, ll, ur, lr) {
  out <- rep(NA_character_, length(ul))

  for (i in seq_along(out)) {
    if (
      !is.na(ur[i]) &&
        grepl("^T[A-Z]$", ur[i]) &&
        (!is.na(ll[i]) || !is.na(lr[i]))
    ) {
      out[i] <- paste(
        c(ll[i], sub("^T", "", ur[i]), lr[i]),
        collapse = "|"
      )
    } else if (
      is.na(ur[i]) &&
        !is.na(ll[i]) &&
        !is.na(lr[i]) &&
        nchar(lr[i]) == 2L
    ) {
      # A single LR entry can encode the observed spacer colour followed by
      # the lower-right colour for the known single-LR identities.
      out[i] <- paste(
        c(ll[i], substr(lr[i], 1L, 1L), substr(lr[i], 2L, 2L)),
        collapse = "|"
      )
    }
  }

  out
}


overview_band_combo_observation_features <- function(
  x,
  source = c("captures", "resightings")
) {
  source <- match.arg(source)
  x <- data.table::as.data.table(x)

  required <- c("pk", "date", "UL", "LL", "UR", "LR")
  if (source == "captures") {
    required <- c(
      required,
      "ring",
      "UL_in",
      "LL_in",
      "UR_in",
      "LR_in",
      "field_sex"
    )
  } else {
    required <- c(required, "sex")
  }

  for (column in setdiff(required, names(x))) {
    x[, (column) := vector("character", .N)]
  }

  x[, event_id := seq_len(.N)]
  x[, event_date := as.Date(substr(trimws(as.character(date)), 1L, 10L))]

  band_value <- function(primary, fallback = NULL) {
    primary <- as.character(primary)
    if (is.null(fallback)) {
      return(primary)
    }

    fallback <- as.character(fallback)
    use_fallback <- is.na(primary) | !nzchar(trimws(primary))
    primary[use_fallback] <- fallback[use_fallback]
    primary
  }

  x[, UL_raw := overview_band_combo_normalize_value(
    band_value(UL, if (source == "captures") UL_in else NULL)
  )]
  x[, LL_raw := overview_band_combo_normalize_value(
    band_value(LL, if (source == "captures") LL_in else NULL)
  )]
  x[, UR_raw := overview_band_combo_normalize_value(
    band_value(UR, if (source == "captures") UR_in else NULL)
  )]
  x[, LR_raw := overview_band_combo_normalize_value(
    band_value(LR, if (source == "captures") LR_in else NULL)
  )]

  x[, sex := overview_band_combo_normalize_sex(
    if (source == "captures") field_sex else sex
  )]

  if (source == "captures") {
    x[, ring := overview_band_combo_normalize_value(
      ring,
      remove_hyphen = TRUE
    )]
  } else {
    x[, ring := NA_character_]
  }

  x[, has_upper := !is.na(UL_raw) | !is.na(UR_raw)]
  x[, has_informative_band := !is.na(UL_raw) |
    !is.na(LL_raw) |
    !is.na(UR_raw) |
    !is.na(LR_raw)]

  x[, full_key := ifelse(
    has_informative_band,
    paste(
      ifelse(is.na(UL_raw), "X", UL_raw),
      ifelse(is.na(LL_raw), "X", LL_raw),
      ifelse(is.na(UR_raw), "X", UR_raw),
      ifelse(is.na(LR_raw), "X", LR_raw),
      sep = "|"
    ),
    NA_character_
  )]
  x[, lower_key := ifelse(
    !is.na(LL_raw) | !is.na(LR_raw),
    paste(
      ifelse(is.na(LL_raw), "X", LL_raw),
      ifelse(is.na(LR_raw), "X", LR_raw),
      sep = "|"
    ),
    NA_character_
  )]

  x[, flag_code := mapply(
    function(ul, ur) {
      values <- c(ul, ur)
      values <- values[
        !is.na(values) &
          grepl("^F[A-Z0-9-]+$", values)
      ]
      if (!length(values)) {
        return(NA_character_)
      }
      paste(sort(unique(values)), collapse = "|")
    },
    UL_raw,
    UR_raw,
    USE.NAMES = FALSE
  )]

  x[, spacer_key := overview_band_combo_spacer_key(
    UL_raw,
    LL_raw,
    UR_raw,
    LR_raw
  )]

  x[, strong_key := fifelse(
    !is.na(flag_code),
    paste0("flag:", flag_code),
    fifelse(
      !is.na(spacer_key),
      paste0("spacer:", spacer_key),
      fifelse(
        has_upper & !is.na(full_key),
        paste0("full:", full_key),
        NA_character_
      )
    )
  )]

  x[, representation_key := fifelse(
    !is.na(strong_key),
    strong_key,
    fifelse(
      !is.na(lower_key),
      paste0("lower:", lower_key),
      NA_character_
    )
  )]

  x[]
}


overview_band_combo_capture_anchors <- function(captures) {
  captures <- data.table::as.data.table(captures)
  captures <- captures[!is.na(ring)]

  if (!nrow(captures)) {
    return(data.table::data.table(
      ring = character(),
      identity_key = character(),
      sex = character(),
      first_date = as.Date(character()),
      full_keys = list(),
      lower_keys = list(),
      flag_keys = list(),
      spacer_keys = list()
    ))
  }

  known_sex <- function(values) {
    values <- values[values %in% c("Female", "Male")]
    if (!length(values)) {
      return(NA_character_)
    }
    values[1L]
  }

  first_date <- function(values) {
    values <- values[!is.na(values)]
    if (!length(values)) {
      return(as.Date(NA))
    }
    min(values)
  }

  captures[, identity_key := paste0("ring:", ring)]

  captures[, .(
    identity_key = identity_key[1L],
    sex = known_sex(sex),
    first_date = first_date(event_date),
    full_keys = list(unique(full_key[!is.na(full_key)])),
    lower_keys = list(unique(lower_key[!is.na(lower_key)])),
    flag_keys = list(unique(flag_code[!is.na(flag_code)])),
    spacer_keys = list(unique(spacer_key[!is.na(spacer_key)]))
  ), by = ring]
}


overview_band_combo_filter_candidates <- function(
  candidates,
  anchors,
  observed_sex
) {
  if (!length(candidates) || is.na(observed_sex)) {
    return(candidates)
  }

  candidates[
    anchors$sex[match(candidates, anchors$ring)] %in%
      c(observed_sex, NA_character_)
  ]
}


overview_band_combo_match_resightings <- function(
  resightings,
  anchors
) {
  resightings <- data.table::copy(resightings)

  if (!nrow(resightings) || !nrow(anchors)) {
    resightings[, c("matched_ring", "match_method") := list(
      NA_character_,
      NA_character_
    )]
    return(resightings)
  }

  candidates_for <- function(column, key) {
    if (is.na(key)) {
      return(character())
    }

    hit <- vapply(
      anchors[[column]],
      function(values) key %in% values,
      logical(1)
    )
    anchors$ring[hit]
  }

  matched_ring <- rep(NA_character_, nrow(resightings))
  match_method <- rep(NA_character_, nrow(resightings))
  priority <- c(
    flag_keys = "flag_code",
    full_keys = "full_key",
    spacer_keys = "spacer_key",
    lower_keys = "lower_key"
  )

  for (i in seq_len(nrow(resightings))) {
    candidate_rings <- character()
    method <- NA_character_

    for (column in names(priority)) {
      key_column <- priority[[column]]
      candidates <- candidates_for(
        column,
        resightings[[key_column]][i]
      )
      candidates <- overview_band_combo_filter_candidates(
        candidates,
        anchors,
        resightings$sex[i]
      )

      if (length(candidates)) {
        candidate_rings <- unique(candidates)
        method <- switch(
          key_column,
          flag_code = "flag",
          full_key = "full",
          spacer_key = "spacer",
          lower_key = "lower",
          key_column
        )
        break
      }
    }

    if (length(candidate_rings) == 1L) {
      matched_ring[i] <- candidate_rings
      match_method[i] <- method
    } else if (length(candidate_rings) > 1L) {
      match_method[i] <- "ambiguous"
    }
  }

  resightings[, c("matched_ring", "match_method") := list(
    matched_ring,
    match_method
  )]
  resightings[]
}


overview_band_combo_reconcile_identities <- function(
  captures,
  resightings
) {
  captures <- overview_band_combo_observation_features(
    captures,
    source = "captures"
  )
  resightings <- overview_band_combo_observation_features(
    resightings,
    source = "resightings"
  )

  anchors <- overview_band_combo_capture_anchors(captures)
  resightings <- overview_band_combo_match_resightings(
    resightings,
    anchors
  )

  captures[, c("identity_key", "sex_resolved", "source") := list(
    rep(NA_character_, .N),
    rep(NA_character_, .N),
    rep(NA_character_, .N)
  )]
  resightings[, c("identity_key", "sex_resolved", "source") := list(
    rep(NA_character_, .N),
    rep(NA_character_, .N),
    rep(NA_character_, .N)
  )]

  if (nrow(captures)) {
    sex_by_ring <- stats::setNames(anchors$sex, anchors$ring)
    captures[, c("identity_key", "sex_resolved", "source") := list(
      paste0("ring:", ring),
      unname(sex_by_ring[ring]),
      "capture"
    )]
  }

  if (nrow(resightings)) {
    sex_by_ring <- stats::setNames(anchors$sex, anchors$ring)
    resightings[, c("identity_key", "sex_resolved", "source") := list(
      ifelse(
        !is.na(matched_ring),
        paste0("ring:", matched_ring),
        NA_character_
      ),
      ifelse(
        !is.na(matched_ring),
        unname(sex_by_ring[matched_ring]),
        sex
      ),
      "resighting"
    )]
  }

  unmatched <- resightings[
    is.na(identity_key) &
      !is.na(strong_key)
  ]

  strong_groups <- data.table::data.table()
  if (nrow(unmatched)) {
    strong_groups <- unmatched[, .(
      sex = {
        values <- sex[sex %in% c("Female", "Male")]
        if (length(values)) values[1L] else NA_character_
      },
      lower_keys = list(unique(lower_key[!is.na(lower_key)]))
    ), by = .(strong_key, sex)]

    strong_groups[, group_key := paste0(
      "resight:",
      strong_key,
      ":",
      fifelse(is.na(sex), "Unknown", sex)
    )]

    strong_group_key <- stats::setNames(
      strong_groups$group_key,
      paste(strong_groups$strong_key, strong_groups$sex, sep = "\r")
    )

    strong_row_key <- paste(
      unmatched$strong_key,
      unmatched$sex,
      sep = "\r"
    )
    unmatched_identity <- unname(strong_group_key[strong_row_key])

    resightings[
      match(unmatched$event_id, event_id),
      identity_key := unmatched_identity
    ]
    resightings[
      match(unmatched$event_id, event_id),
      sex_resolved := unmatched$sex
    ]
  }

  lower_only <- resightings[
    is.na(identity_key) &
      !is.na(lower_key)
  ]

  if (nrow(lower_only)) {
    for (i in seq_len(nrow(lower_only))) {
      candidates <- strong_groups[
        vapply(
          lower_keys,
          function(values) lower_only$lower_key[i] %in% values,
          logical(1)
        )
      ]

      if (!is.na(lower_only$sex[i])) {
        candidates <- candidates[
          is.na(sex) | sex == lower_only$sex[i]
        ]
      }

      if (nrow(candidates) == 1L) {
        lower_identity <- candidates$group_key[1L]
        lower_sex <- candidates$sex[1L]
      } else {
        lower_identity <- paste0(
          "resight:lower:",
          fifelse(
            is.na(lower_only$sex[i]),
            "Unknown",
            lower_only$sex[i]
          ),
          ":",
          lower_only$lower_key[i]
        )
        lower_sex <- lower_only$sex[i]
      }

      row_index <- match(lower_only$event_id[i], resightings$event_id)
      resightings[
        row_index,
        c("identity_key", "sex_resolved") := list(
          lower_identity,
          fifelse(!is.na(lower_sex), lower_sex, sex)
        )
      ]
    }
  }

  event_rows <- data.table::rbindlist(
    list(
      captures[
        !is.na(identity_key),
        .(
          identity_key,
          sex = sex_resolved,
          event_date,
          source,
          representation_key
        )
      ],
      resightings[
        !is.na(identity_key),
        .(
          identity_key,
          sex = sex_resolved,
          event_date,
          source,
          representation_key
        )
      ]
    ),
    fill = TRUE
  )

  if (!nrow(event_rows)) {
    summary <- data.table::data.table(
      identity_key = character(),
      sex = character(),
      first_date = as.Date(character()),
      has_capture = integer(),
      has_resighting = integer(),
      n_normalized_representations = integer()
    )
  } else {
    summary <- event_rows[, .(
      sex = {
        values <- sex[sex %in% c("Female", "Male")]
        if (length(values)) values[1L] else NA_character_
      },
      first_date = {
        values <- event_date[!is.na(event_date)]
        if (length(values)) min(values) else as.Date(NA)
      },
      has_capture = as.integer(any(source == "capture")),
      has_resighting = as.integer(any(source == "resighting")),
      n_normalized_representations = data.table::uniqueN(
        representation_key[!is.na(representation_key)]
      )
    ), by = identity_key]
  }

  list(
    summary = summary[],
    captures = captures[],
    resightings = resightings[],
    anchors = anchors[],
    ambiguous_resighting_events = sum(
      resightings$match_method == "ambiguous",
      na.rm = TRUE
    )
  )
}


overview_band_combo_query <- function(
  refdate,
  start_date = NULL
) {
  refdate <- as.Date(refdate)
  start_sql <- if (is.null(start_date)) {
    "CAST(NULL AS DATE)"
  } else {
    "CAST(? AS DATE)"
  }

  params <- list(as.character(refdate))
  if (!is.null(start_date)) {
    params <- c(params, list(as.character(as.Date(start_date))))
  }

  source_sql <- function(table, sex_column, include_capture_fields = FALSE) {
    capture_fields <- if (include_capture_fields) {
      ", c.ring, c.UL_in, c.LL_in, c.UR_in, c.LR_in"
    } else {
      ""
    }

    paste(
      c(
        "WITH sr AS (",
        paste0(
          "  SELECT CAST(? AS DATE) AS reference_date, ",
          start_sql,
          " AS start_date"
        ),
        ")",
        "SELECT",
        "  ", if (include_capture_fields) "c.pk" else "r.pk",
        " AS pk,",
        "  ", if (include_capture_fields) "c.date" else "r.date",
        " AS date,",
        "  ", if (include_capture_fields) "c.UL" else "r.UL",
        " AS UL,",
        "  ", if (include_capture_fields) "c.LL" else "r.LL",
        " AS LL,",
        "  ", if (include_capture_fields) "c.UR" else "r.UR",
        " AS UR,",
        "  ", if (include_capture_fields) "c.LR" else "r.LR",
        " AS LR,",
        "  ", if (include_capture_fields) "c.field_sex" else "r.sex",
        " AS ", sex_column,
        capture_fields,
        "FROM ", table, " ",
        if (include_capture_fields) "c" else "r",
        " CROSS JOIN sr",
        "WHERE UPPER(TRIM(COALESCE(",
        if (include_capture_fields) "c.age" else "r.age",
        ", ''))) = 'A'",
        "  AND UPPER(TRIM(COALESCE(",
        if (include_capture_fields) "c.site" else "r.site",
        ", ''))) = 'CR'",
        "  AND ",
        if (include_capture_fields) "c.date" else "r.date",
        " IS NOT NULL",
        "  AND ",
        if (include_capture_fields) "c.date" else "r.date",
        " <= sr.reference_date",
        "  AND (sr.start_date IS NULL OR ",
        if (include_capture_fields) "c.date" else "r.date",
        " >= sr.start_date)"
      ),
      collapse = "\n"
    )
  }

  age_sql <- paste(
    c(
      "WITH sr AS (",
      paste0(
        "  SELECT CAST(? AS DATE) AS reference_date, ",
        start_sql,
        " AS start_date"
      ),
      ")",
      "SELECT 'CAPTURES' AS source_table,",
      "  UPPER(TRIM(COALESCE(c.age, ''))) AS age_key,",
      "  COUNT(*) AS n_rows",
      "FROM CAPTURES c CROSS JOIN sr",
      "WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'",
      "  AND c.date IS NOT NULL",
      "  AND c.date <= sr.reference_date",
      "  AND (sr.start_date IS NULL OR c.date >= sr.start_date)",
      "GROUP BY age_key",
      "UNION ALL",
      "SELECT 'RESIGHTINGS' AS source_table,",
      "  UPPER(TRIM(COALESCE(r.age, ''))) AS age_key,",
      "  COUNT(*) AS n_rows",
      "FROM RESIGHTINGS r CROSS JOIN sr",
      "WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'",
      "  AND r.date IS NOT NULL",
      "  AND r.date <= sr.reference_date",
      "  AND (sr.start_date IS NULL OR r.date >= sr.start_date)",
      "GROUP BY age_key"
    ),
    collapse = "\n"
  )

  list(
    captures = list(sql = source_sql(
      "CAPTURES",
      "field_sex",
      include_capture_fields = TRUE
    ), params = params),
    resightings = list(sql = source_sql(
      "RESIGHTINGS",
      "sex",
      include_capture_fields = FALSE
    ), params = params),
    ages = list(sql = age_sql, params = params)
  )
}


overview_band_combo_data <- function(
  refdate,
  start_date = NULL,
  include_ages = FALSE
) {
  query <- overview_band_combo_query(
    refdate = refdate,
    start_date = start_date
  )

  captures <- db_get(
    query$captures$sql,
    params = query$captures$params
  )
  resightings <- db_get(
    query$resightings$sql,
    params = query$resightings$params
  )

  reconciled <- overview_band_combo_reconcile_identities(
    captures = captures,
    resightings = resightings
  )

  if (include_ages) {
    reconciled$ages <- db_get(
      query$ages$sql,
      params = query$ages$params
    )
  } else {
    reconciled$ages <- data.table::data.table()
  }

  reconciled
}


overview_band_combos_graph <- function(
  refdate = get_reference_date(),
  date_limits = NULL,
  start_date = NULL
) {
  data <- overview_band_combo_data(
    refdate = refdate,
    start_date = start_date
  )
  x <- data$summary[
    sex %in% c("Female", "Male") &
      !is.na(first_date),
    .(
      mark = identity_key,
      sex,
      datetime = as.POSIXct(first_date)
    )
  ]

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


overview_band_combo_diagnostic <- function(
  refdate = get_reference_date(),
  start_date = NULL
) {
  data <- overview_band_combo_data(
    refdate = refdate,
    start_date = start_date,
    include_ages = TRUE
  )
  summary <- data$summary
  ages <- data.table::as.data.table(data$ages)

  adult_event_rows <- sum(
    ages[
      toupper(trimws(as.character(age_key))) == "A",
      as.numeric(n_rows)
    ],
    na.rm = TRUE
  )
  non_adult_event_rows <- sum(
    ages[
      toupper(trimws(as.character(age_key))) != "A",
      as.numeric(n_rows)
    ],
    na.rm = TRUE
  )

  data.table::data.table(
    adult_event_rows = adult_event_rows,
    non_adult_event_rows = non_adult_event_rows,
    unique_adult_identities = nrow(summary),
    capture_only_identities = sum(
      summary$has_capture == 1L &
        summary$has_resighting == 0L,
      na.rm = TRUE
    ),
    resighting_only_identities = sum(
      summary$has_capture == 0L &
        summary$has_resighting == 1L,
      na.rm = TRUE
    ),
    capture_and_resighting_identities = sum(
      summary$has_capture == 1L &
        summary$has_resighting == 1L,
      na.rm = TRUE
    ),
    identities_with_multiple_normalized_marks = sum(
      summary$n_normalized_representations > 1L,
      na.rm = TRUE
    ),
    ambiguous_resighting_events = data$ambiguous_resighting_events
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


overview_hatching_forecast_graph <- function(
  refdate = get_reference_date()
) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    WITH sr AS (
      SELECT CAST(? AS DATE) AS reference_date
    ),
    future_hatches AS (
      SELECT
        TRIM(e.nest_id) AS nest_id,
        CAST(MIN(e.predicted_hatch_date) AS DATE) AS predicted_hatch_date
      FROM EGGS_HATCH_PREDICTION e
      CROSS JOIN sr
      WHERE NULLIF(TRIM(e.nest_id), '') IS NOT NULL
        AND e.predicted_hatch_date IS NOT NULL
        AND e.predicted_hatch_date > sr.reference_date
      GROUP BY TRIM(e.nest_id)
    )
    SELECT
      nest_id,
      CAST(
        CONCAT(predicted_hatch_date, ' 00:00:00') AS DATETIME
      ) AS datetime
    FROM future_hatches
    ORDER BY predicted_hatch_date, nest_id
    ",
    params = list(as.character(refdate))
  )

  overview_hatching_forecast_plot(
    x = x,
    refdate = refdate,
    binwidth = 1L
  )
}


overview_chick_growth_plot <- function(
  x,
  refdate = NULL
) {
  measure_specs <- data.table(
    measure = c("weight", "culmen", "tarsus"),
    ylab = c("weight (g)", "culmen (mm)", "tarsus (mm)")
  )
  x <- data.table(x)

  for (column in c("ring", "nest_id", "age_days")) {
    if (!column %in% names(x)) {
      x[, (column) := NA_character_]
    }
  }

  for (column in measure_specs$measure) {
    if (!column %in% names(x)) {
      x[, (column) := NA_real_]
    }
  }

  x[, `:=`(
    ring = trimws(as.character(ring)),
    nest_id = trimws(as.character(nest_id)),
    age_days = suppressWarnings(as.numeric(age_days))
  )]

  plot_data <- melt(
    x,
    id.vars = c("ring", "nest_id", "age_days"),
    measure.vars = measure_specs$measure,
    variable.name = "measure",
    value.name = "value",
    na.rm = TRUE
  )
  plot_data[, value := suppressWarnings(as.numeric(as.character(value)))]
  plot_data <- plot_data[
    is.finite(value) &
      is.finite(age_days) &
      age_days >= 0 &
      nzchar(ring) &
      nzchar(nest_id)
  ]

  plot_data[, measure := factor(
    measure,
    levels = measure_specs$measure,
    labels = measure_specs$ylab
  )]

  repeat_ids <- plot_data[
    , .N,
    by = .(measure, ring)
  ][N > 1]
  line_data <- plot_data[
    repeat_ids,
    on = .(measure, ring),
    nomatch = 0
  ]

  fit_population_trend <- function(measure_name) {
    model_data <- copy(plot_data[measure == measure_name])

    if (
      nrow(model_data) < 8L ||
        uniqueN(model_data$age_days) < 3L
    ) {
      return(NULL)
    }

    model_data[, individual_re := factor(ring)]
    model_data[, brood_re := factor(nest_id)]

    k_age <- min(6L, uniqueN(model_data$age_days))
    model_terms <- sprintf(
      "s(age_days, k = %d, bs = 'tp')",
      k_age
    )
    excluded_terms <- character()

    if (uniqueN(model_data$individual_re) > 1L) {
      model_terms <- c(model_terms, "s(individual_re, bs = 're')")
      excluded_terms <- c(excluded_terms, "s(individual_re)")
    }

    if (uniqueN(model_data$brood_re) > 1L) {
      model_terms <- c(model_terms, "s(brood_re, bs = 're')")
      excluded_terms <- c(excluded_terms, "s(brood_re)")
    }

    fit <- tryCatch(
      mgcv::gam(
        stats::as.formula(
          paste("value ~", paste(model_terms, collapse = " + "))
        ),
        data = model_data,
        method = "REML"
      ),
      error = function(e) NULL
    )

    if (is.null(fit)) {
      return(NULL)
    }

    prediction_data <- data.table(
      age_days = seq(
        min(model_data$age_days),
        max(model_data$age_days),
        length.out = 100L
      )
    )

    if ("s(individual_re)" %in% excluded_terms) {
      prediction_data[, individual_re := factor(
        levels(model_data$individual_re)[1L],
        levels = levels(model_data$individual_re)
      )]
    }

    if ("s(brood_re)" %in% excluded_terms) {
      prediction_data[, brood_re := factor(
        levels(model_data$brood_re)[1L],
        levels = levels(model_data$brood_re)
      )]
    }

    prediction <- predict(
      fit,
      newdata = prediction_data,
      type = "response",
      se.fit = TRUE,
      exclude = excluded_terms
    )

    prediction_data[, `:=`(
      measure = measure_name,
      fit = as.numeric(prediction$fit),
      lower = as.numeric(prediction$fit - 1.96 * prediction$se.fit),
      upper = as.numeric(prediction$fit + 1.96 * prediction$se.fit)
    )]
    prediction_data[]
  }

  trend_data <- rbindlist(
    lapply(levels(plot_data$measure), fit_population_trend),
    fill = TRUE
  )

  if (!"measure" %in% names(trend_data)) {
    trend_data <- data.table(
      measure = character(),
      age_days = numeric(),
      fit = numeric(),
      lower = numeric(),
      upper = numeric()
    )
  }

  age_limits <- if (nrow(plot_data)) {
    c(0, max(plot_data$age_days, na.rm = TRUE))
  } else {
    c(0, 1)
  }

  if (diff(age_limits) == 0) {
    age_limits[2] <- age_limits[1] + 1
  }

  base_theme <- theme_bw(base_size = 14) +
    theme(
      panel.grid.minor = element_blank(),
      panel.border = element_rect(
        colour = "grey40",
        linewidth = 0.5
      ),
      axis.title = element_text(size = 11),
      axis.text = element_text(size = 9)
    )

  make_panel <- function(measure_name, ylab) {
    panel_data <- plot_data[measure == measure_name]
    panel_lines <- line_data[measure == measure_name]
    panel_trend <- trend_data[measure == measure_name]

    panel <- ggplot(
      panel_data,
      aes(x = age_days, y = value)
    )

    if (nrow(panel_trend)) {
      panel <- panel +
        geom_ribbon(
          data = panel_trend,
          aes(
            x = age_days,
            ymin = lower,
            ymax = upper
          ),
          inherit.aes = FALSE,
          fill = "#4b5254",
          alpha = 0.22
        ) +
        geom_line(
          data = panel_trend,
          aes(x = age_days, y = fit),
          inherit.aes = FALSE,
          colour = "#4b5254",
          alpha = 0.55,
          linewidth = 0.8
        )
    }

    panel +
      geom_line(
        data = panel_lines,
        aes(group = ring),
        colour = "#4b5254",
        alpha = 0.55,
        linewidth = 0.45
      ) +
      geom_point(
        colour = "#2878b5",
        alpha = 0.8,
        size = 1.8
      ) +
      scale_x_continuous(
        name = "age (days)",
        limits = age_limits,
        breaks = scales::breaks_pretty(n = 8),
        expand = expansion(mult = c(0.02, 0.04))
      ) +
      scale_y_continuous(name = ylab) +
      base_theme
  }

  panels <- lapply(
    seq_len(nrow(measure_specs)),
    function(i) {
      make_panel(
        measure_name = measure_specs$ylab[i],
        ylab = measure_specs$ylab[i]
      )
    }
  )

  refdate_label <- if (length(refdate) && !is.na(refdate)) {
    glue(" Data through reference date {as.Date(refdate)}.")
  } else {
    ""
  }

  patchwork::wrap_plots(panels, nrow = 1) +
    patchwork::plot_annotation(
      caption = paste0(
        "Age-C captures from known nests with recorded hatch dates; ",
        "lines connect repeated measurements only when the same ring was ",
        "recorded. Faint curves and ribbons show marginal GAMM trends and ",
        "95% CIs.",
        refdate_label
      )
    ) &
    theme(
      plot.caption = element_text(size = 9, hjust = 0)
    )
}


overview_chick_growth_graph <- function(
  refdate = get_reference_date()
) {
  refdate <- as.Date(refdate)

  x <- db_get(
    "
    WITH sr AS (
      SELECT CAST(? AS DATE) AS reference_date
    ),
    hatch_dates AS (
      SELECT
        TRIM(n.nest_id) AS nest_id,
        MIN(n.date) AS hatch_date
      FROM NESTS n
      CROSS JOIN sr
      WHERE NULLIF(TRIM(n.nest_id), '') IS NOT NULL
        AND UPPER(TRIM(COALESCE(n.nest_state, ''))) = 'H'
        AND n.date IS NOT NULL
        AND n.date <= sr.reference_date
      GROUP BY TRIM(n.nest_id)
    )
    SELECT
      TRIM(c.ring) AS ring,
      TRIM(c.nest_id) AS nest_id,
      h.hatch_date,
      c.date AS capture_date,
      DATEDIFF(c.date, h.hatch_date) AS age_days,
      c.weight,
      c.culmen,
      c.tarsus
    FROM CAPTURES c
    INNER JOIN hatch_dates h
      ON TRIM(c.nest_id) = h.nest_id
    CROSS JOIN sr
    WHERE UPPER(TRIM(COALESCE(c.age, ''))) = 'C'
      AND NULLIF(TRIM(c.ring), '') IS NOT NULL
      AND UPPER(TRIM(c.ring)) NOT IN ('NA', 'N/A', 'NULL', 'X', 'XX', 'M')
      AND c.date IS NOT NULL
      AND c.date <= sr.reference_date
      AND DATEDIFF(c.date, h.hatch_date) >= 0
      AND (
        c.weight IS NOT NULL
        OR c.culmen IS NOT NULL
        OR c.tarsus IS NOT NULL
      )
    ORDER BY c.date, c.pk
    ",
    params = list(as.character(refdate))
  )

  overview_chick_growth_plot(x, refdate = refdate)
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
