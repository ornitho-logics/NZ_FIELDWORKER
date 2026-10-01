CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE AS

SELECT
  c.ring,
  c.UL,
  c.LL,
  c.UR,
  c.LR,
  FIELD_2026_BADOatNZ.format_mark(c.UL, c.LL, c.UR, c.LR) AS mark,
  c.date,
  c.study_year,
  c.site_code,
  c.capture_status,
  c.latitude,
  c.longitude,
  c.field_sex,
  sex_lookup.gen_sex,
  c.age,
  c.tarsus,
  c.culmen,
  c.wing,
  c.weight,
  c.moult_left,
  c.tag_id,
  c.tag_type
FROM BADOatNZ.CAPTURES c
LEFT JOIN (
  SELECT
    TRIM(ring) AS ring,
    MAX(NULLIF(TRIM(gen_sex), '')) AS gen_sex
  FROM BADOatNZ.SEX
  WHERE ring IS NOT NULL
    AND TRIM(ring) <> ''
  GROUP BY ring
) sex_lookup
  ON TRIM(c.ring) = sex_lookup.ring;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
historical_used_marks AS (
  SELECT
    'CAPTURES_ARCHIVE' AS source_table,
    'release' AS source_stage,
    NULLIF(TRIM(ca.ring), '') AS ring,
    ca.date AS date_,
    ca.capture_status,
    NULLIF(UPPER(TRIM(ca.UL)), '') AS UL_raw,
    NULLIF(UPPER(TRIM(ca.LL)), '') AS LL_raw,
    NULLIF(UPPER(TRIM(ca.UR)), '') AS UR_raw,
    NULLIF(UPPER(TRIM(ca.LR)), '') AS LR_raw
  FROM FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE ca
  CROSS JOIN sr
  WHERE ca.date <= sr.reference_date
     OR ca.date IS NULL
),
current_used_marks_release AS (
  SELECT
    'CAPTURES' AS source_table,
    'release' AS source_stage,
    NULLIF(TRIM(c.ring), '') AS ring,
    c.date AS date_,
    c.capture_status,
    NULLIF(UPPER(TRIM(c.UL)), '') AS UL_raw,
    NULLIF(UPPER(TRIM(c.LL)), '') AS LL_raw,
    NULLIF(UPPER(TRIM(c.UR)), '') AS UR_raw,
    NULLIF(UPPER(TRIM(c.LR)), '') AS LR_raw
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.date <= sr.reference_date
     OR c.date IS NULL
),
current_used_marks_input AS (
  SELECT
    'CAPTURES' AS source_table,
    'input' AS source_stage,
    NULLIF(TRIM(c.ring), '') AS ring,
    c.date AS date_,
    c.capture_status,
    NULLIF(UPPER(TRIM(c.UL_in)), '') AS UL_raw,
    NULLIF(UPPER(TRIM(c.LL_in)), '') AS LL_raw,
    NULLIF(UPPER(TRIM(c.UR_in)), '') AS UR_raw,
    NULLIF(UPPER(TRIM(c.LR_in)), '') AS LR_raw
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.date <= sr.reference_date
     OR c.date IS NULL
),
used_marks_raw AS (
  SELECT * FROM historical_used_marks
  UNION ALL
  SELECT * FROM current_used_marks_release
  UNION ALL
  SELECT * FROM current_used_marks_input
),
used_marks_prepped AS (
  SELECT
    source_table,
    source_stage,
    ring,
    date_,
    capture_status,
    UL_raw,
    LL_raw,
    UR_raw,
    LR_raw,
    CASE
      WHEN UR_raw REGEXP '^T[A-Z0-9]*[BGROWLY]$'
      THEN CONCAT('T', RIGHT(UR_raw, 1))
      ELSE UR_raw
    END AS UR_tag_norm
  FROM used_marks_raw
  WHERE COALESCE(UL_raw, LL_raw, UR_raw, LR_raw) IS NOT NULL
),
used_marks_normalized AS (
  SELECT
    source_table,
    source_stage,
    ring,
    date_,
    capture_status,
    UL_raw,
    LL_raw,
    UR_raw,
    LR_raw,
    UR_tag_norm,
    CASE
      WHEN UL_raw REGEXP '^[BGROWLY]$'
       AND LL_raw REGEXP '^[BGROWLY]$'
      THEN CONCAT(UL_raw, LL_raw)
      WHEN COALESCE(UL_raw, 'X') IN ('X', 'M')
       AND LL_raw REGEXP '^[BGROWLY]{2}$'
      THEN LL_raw
      WHEN COALESCE(LL_raw, 'X') IN ('X', 'M')
       AND UL_raw REGEXP '^[BGROWLY]{2}$'
      THEN UL_raw
      ELSE NULL
    END AS LL,
    CASE
      -- A two-band LR is already the complete right-side colour pair. The
      -- geolocator spacer in UR must not be prepended in this case.
      WHEN UR_raw REGEXP '^T[A-Z0-9]*[BGROWLY]$'
       AND LR_raw REGEXP '^[BGROWLY]{2}$'
      THEN LR_raw
      -- With a one-band LR, the colour after T supplies the first band.
      WHEN UR_raw REGEXP '^T[A-Z0-9]*[BGROWLY]$'
       AND LR_raw REGEXP '^[BGROWLY]$'
      THEN CONCAT(RIGHT(UR_raw, 1), LR_raw)
      WHEN UR_tag_norm REGEXP '^[BGROWLY]$'
       AND LR_raw REGEXP '^[BGROWLY]$'
      THEN CONCAT(UR_tag_norm, LR_raw)
      WHEN COALESCE(UR_tag_norm, 'X') IN ('X', 'XX', 'M')
       AND LR_raw REGEXP '^[BGROWLY]{2}$'
      THEN LR_raw
      WHEN COALESCE(LR_raw, 'X') IN ('X', 'M')
       AND UR_tag_norm REGEXP '^[BGROWLY]{2}$'
      THEN UR_tag_norm
      ELSE NULL
    END AS LR
  FROM used_marks_prepped
)
SELECT
  source_table,
  source_stage,
  ring,
  date_,
  capture_status,
  UL_raw,
  LL_raw,
  UR_raw,
  LR_raw,
  UR_tag_norm,
  LL,
  LR,
  CASE
    WHEN LL REGEXP '^[BGROWLY]{2}$'
     AND LR REGEXP '^[BGROWLY]{2}$'
    THEN FIELD_2026_BADOatNZ.format_mark('X', LL, 'X', LR)
    ELSE NULL
  END AS mark,
  CASE
    WHEN LL REGEXP '^[BGROWLY]{2}$'
     AND LR REGEXP '^[BGROWLY]{2}$'
    THEN 1
    ELSE 0
  END AS is_normalizable
FROM used_marks_normalized;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.AVAILABLE_COMBOS AS

WITH colours AS (
  SELECT 'B' AS colour
  UNION ALL SELECT 'G'
  UNION ALL SELECT 'R'
  UNION ALL SELECT 'O'
  UNION ALL SELECT 'W'
  UNION ALL SELECT 'L'
  UNION ALL SELECT 'Y'
),
lr_pairs AS (
  SELECT
    CONCAT(c1.colour, c2.colour) AS LR,
    c1.colour AS lr_first
  FROM colours c1
  CROSS JOIN colours c2
),
site_rules AS (
  SELECT 'CR' AS site_code, 'OY' AS LL, NULL AS lr_first_rule
  UNION ALL SELECT 'CR', 'YR', NULL
  UNION ALL SELECT 'CR', 'YO', NULL
  UNION ALL SELECT 'CR', 'YY', NULL
  UNION ALL SELECT 'CR', 'LY', NULL
  UNION ALL SELECT 'CR', 'BY', NULL
  UNION ALL SELECT 'CR', 'WY', NULL
  UNION ALL SELECT 'AR', 'BW', NULL
  UNION ALL SELECT 'WN', 'WO', 'B'
  UNION ALL SELECT 'WN', 'WO', 'G'
  UNION ALL SELECT 'WN', 'WO', 'R'
  UNION ALL SELECT 'WS', 'WO', 'O'
  UNION ALL SELECT 'WS', 'WO', 'W'
  UNION ALL SELECT 'WS', 'WO', 'Y'
),
candidate_combos AS (
  SELECT DISTINCT
    CAST(r.site_code AS CHAR(2)) AS site_code,
    CAST(r.LL AS CHAR(10)) AS LL,
    CAST(p.LR AS CHAR(10)) AS LR
  FROM site_rules r
  JOIN lr_pairs p
    ON r.lr_first_rule IS NULL
    OR p.lr_first = r.lr_first_rule
),
used_combos AS (
  SELECT DISTINCT
    CAST(ucd.LL AS CHAR(10)) AS LL,
    CAST(ucd.LR AS CHAR(10)) AS LR
  FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL ucd
  WHERE ucd.is_normalizable = 1
),
available_combos_ranked AS (
  SELECT
    candidate.site_code,
    candidate.LL,
    candidate.LR,
    ROW_NUMBER() OVER (
      PARTITION BY candidate.site_code
      ORDER BY
        CASE WHEN LEFT(candidate.LL, 1) = 'Y' THEN 0 ELSE 1 END,
        CASE
          WHEN CONCAT(candidate.LL, candidate.LR) NOT REGEXP '[LR]' THEN 0
          WHEN CONCAT(candidate.LL, candidate.LR) REGEXP 'L' THEN 1
          ELSE 2
        END,
        candidate.LL,
        candidate.LR
    ) AS combo_rank
  FROM candidate_combos candidate
  LEFT JOIN used_combos used
    ON candidate.LL = used.LL
   AND candidate.LR = used.LR
  WHERE used.LL IS NULL
    AND candidate.LL <> 'YR'
    AND candidate.LR NOT IN ('OR', 'RO')
)
SELECT
  CASE
    -- Temporary compatibility gate for the deployed PDF's site_code = 'CR' query.
    WHEN available_combos_ranked.site_code = 'CR'
     AND available_combos_ranked.LL IN ('BY', 'WY', 'YY', 'YO') THEN 'CR'
    WHEN available_combos_ranked.site_code = 'CR'
     AND CONCAT(available_combos_ranked.LL, available_combos_ranked.LR) REGEXP 'L' THEN 'CX'
    WHEN available_combos_ranked.site_code = 'CR'
     AND available_combos_ranked.combo_rank > 30 THEN 'CX'
    ELSE available_combos_ranked.site_code
  END AS site_code,
  FIELD_2026_BADOatNZ.format_mark(
    'X',
    available_combos_ranked.LL,
    'X',
    available_combos_ranked.LR
  ) AS mark,
  available_combos_ranked.LL,
  available_combos_ranked.LR
FROM available_combos_ranked
ORDER BY
  available_combos_ranked.site_code,
  available_combos_ranked.combo_rank;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.NESTS_LATEST AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
latest_visit AS (
  SELECT
    n.*,
    sr.reference_date,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
    ) AS row_num
  FROM FIELD_2026_BADOatNZ.NESTS n
  CROSS JOIN sr
  WHERE n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
    AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.date <= sr.reference_date
),
nest_state_summary AS (
  SELECT
    n.nest_id,
    MAX(
      CASE
        WHEN UPPER(TRIM(COALESCE(n.nest_state, ''))) IN ('F', 'I', 'PP', 'PD') THEN 1
        ELSE 0
      END
    ) AS has_found_or_incubated_state
  FROM FIELD_2026_BADOatNZ.NESTS n
  CROSS JOIN sr
  WHERE n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
    AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.date <= sr.reference_date
  GROUP BY n.nest_id
),
latest_clutch AS (
  SELECT
    n.nest_id,
    n.clutch_size,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
    ) AS row_num
  FROM FIELD_2026_BADOatNZ.NESTS n
  CROSS JOIN sr
  WHERE n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
    AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.clutch_size IS NOT NULL
    AND n.date <= sr.reference_date
),
latest_brood AS (
  SELECT
    n.nest_id,
    n.brood_size,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
    ) AS row_num
  FROM FIELD_2026_BADOatNZ.NESTS n
  CROSS JOIN sr
  WHERE n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
    AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.brood_size IS NOT NULL
    AND n.date <= sr.reference_date
),
nest_coordinates AS (
  SELECT
    n.nest_id,
    g.lat,
    g.lon,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY
        CASE
          WHEN n.nest_state = 'S' THEN 1
          WHEN n.nest_state = 'F' THEN 2
          ELSE 3
        END,
        n.date,
        n.time_visit,
        n.pk,
        g.datetime_,
        g.pk
    ) AS row_num
  FROM FIELD_2026_BADOatNZ.NESTS n
  JOIN FIELD_2026_BADOatNZ.GPS_POINTS g
    ON n.gps_id = g.gps_id
   AND n.gps_point = g.gps_point
  CROSS JOIN sr
  WHERE n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
    AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.gps_id IS NOT NULL
    AND n.gps_point IS NOT NULL
    AND n.date <= sr.reference_date
),
capture_adult_marks AS (
  SELECT DISTINCT
    c.nest_id,
    LEFT(c.field_sex, 1) AS sex,
    CASE
      WHEN UPPER(TRIM(c.LL)) IN ('X', 'XX')
       AND UPPER(TRIM(c.LR)) IN ('X', 'XX')
      THEN 'X-X'
      WHEN (NULLIF(TRIM(c.UL), '') IS NOT NULL AND UPPER(TRIM(c.UL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(c.LL), '') IS NOT NULL AND UPPER(TRIM(c.LL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(c.UR), '') IS NOT NULL AND UPPER(TRIM(c.UR)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(c.LR), '') IS NOT NULL AND UPPER(TRIM(c.LR)) NOT REGEXP '^(X+|M)$')
      THEN FIELD_2026_BADOatNZ.format_mark(c.UL, c.LL, c.UR, c.LR)
      ELSE NULL
    END AS mark
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age <> 'C'
    AND c.field_sex IN ('M', 'MU', 'F', 'FU')
    AND c.date <= sr.reference_date
),
resighting_adult_marks AS (
  SELECT DISTINCT
    r.nest_id,
    LEFT(r.sex, 1) AS sex,
    CASE
      WHEN UPPER(TRIM(r.LL)) IN ('X', 'XX')
       AND UPPER(TRIM(r.LR)) IN ('X', 'XX')
      THEN 'X-X'
      WHEN (NULLIF(TRIM(r.UL), '') IS NOT NULL AND UPPER(TRIM(r.UL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(r.LL), '') IS NOT NULL AND UPPER(TRIM(r.LL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(r.UR), '') IS NOT NULL AND UPPER(TRIM(r.UR)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(r.LR), '') IS NOT NULL AND UPPER(TRIM(r.LR)) NOT REGEXP '^(X+|M)$')
      THEN FIELD_2026_BADOatNZ.format_mark(
        NULLIF(TRIM(r.UL), ''),
        NULLIF(TRIM(r.LL), ''),
        NULLIF(TRIM(r.UR), ''),
        NULLIF(TRIM(r.LR), '')
      )
      ELSE NULL
    END AS mark
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE r.nest_id IS NOT NULL
    AND TRIM(r.nest_id) <> ''
    AND UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age <> 'C'
    AND r.sex IN ('M', 'MU', 'F', 'FU')
    AND r.date <= sr.reference_date
),
nest_parent_marks AS (
  SELECT nest_id, sex, mark
  FROM capture_adult_marks
  UNION
  SELECT nest_id, sex, mark
  FROM resighting_adult_marks
),
parent_mark_candidates AS (
  SELECT DISTINCT
    nest_id,
    sex,
    CASE
      WHEN REPLACE(REPLACE(REPLACE(UPPER(TRIM(mark)), 'X', ''), '.', ''), '-', '') = ''
      THEN 'X-X'
      ELSE mark
    END AS mark,
    CASE
      WHEN REPLACE(REPLACE(REPLACE(UPPER(TRIM(mark)), 'X', ''), '.', ''), '-', '') = ''
      THEN 0
      ELSE 1
    END AS has_non_x_mark,
    CHAR_LENGTH(REPLACE(REPLACE(REPLACE(UPPER(TRIM(mark)), 'X', ''), '.', ''), '-', ''))
      AS non_x_character_count
  FROM nest_parent_marks
  WHERE mark IS NOT NULL
),
parent_mark_ranked AS (
  SELECT
    parent_mark_candidates.*,
    ROW_NUMBER() OVER (
      PARTITION BY nest_id, sex
      ORDER BY
        has_non_x_mark DESC,
        non_x_character_count DESC,
        mark
    ) AS row_num
  FROM parent_mark_candidates
),
parent_marks AS (
  SELECT
    nest_id,
    MAX(CASE WHEN sex = 'M' THEN mark END) AS M_mark,
    MAX(CASE WHEN sex = 'F' THEN mark END) AS F_mark
  FROM parent_mark_ranked
  WHERE row_num = 1
  GROUP BY nest_id
),
calibration_hatch_day AS (
  SELECT CAST(MAX(days_since_laying) AS DECIMAL(5,1)) AS hatch_day
  FROM FIELD_2026_BADOatNZ.predict_hatching
),
calibration_prediction AS (
  SELECT
    p.float_angle,
    p.float_surface,
    p.float_location,
    CAST(AVG(p.days_since_laying) AS DECIMAL(5,1)) AS predicted_days_since_laying,
    CAST(MIN(p.days_since_laying) AS DECIMAL(5,1)) AS min_days_since_laying,
    CAST(MAX(p.days_since_laying) AS DECIMAL(5,1)) AS max_days_since_laying,
    COUNT(*) AS n_calibration
  FROM FIELD_2026_BADOatNZ.predict_hatching p
  GROUP BY
    p.float_angle,
    p.float_surface,
    p.float_location
),
egg_calibration_candidates AS (
  SELECT
    e.pk AS egg_pk,
    e.nest_id,
    e.date AS float_date,
    DATEDIFF(sr.reference_date, e.date) AS days_since_float,
    calibration_prediction.predicted_days_since_laying,
    calibration_prediction.min_days_since_laying,
    calibration_prediction.max_days_since_laying,
    calibration_prediction.n_calibration,
    CASE
      WHEN e.float_angle = calibration_prediction.float_angle
       AND e.float_surface <=> calibration_prediction.float_surface
      THEN 'exact'
      ELSE 'nearest'
    END AS calibration_match_type,
    ABS(
      CAST(e.float_angle AS SIGNED) -
      CAST(calibration_prediction.float_angle AS SIGNED)
    ) AS angle_diff,
    CASE
      WHEN e.float_surface IS NULL AND calibration_prediction.float_surface IS NULL THEN 0
      WHEN e.float_surface IS NULL OR calibration_prediction.float_surface IS NULL THEN 9999
      ELSE ABS(
        CAST(e.float_surface AS SIGNED) -
        CAST(calibration_prediction.float_surface AS SIGNED)
      )
    END AS surface_diff,
    ROW_NUMBER() OVER (
      PARTITION BY e.pk
      ORDER BY
        CASE
          WHEN e.float_angle = calibration_prediction.float_angle
           AND e.float_surface <=> calibration_prediction.float_surface
          THEN 0
          ELSE 1
        END,
        ABS(
          CAST(e.float_angle AS SIGNED) -
          CAST(calibration_prediction.float_angle AS SIGNED)
        ),
        CASE
          WHEN e.float_surface IS NULL AND calibration_prediction.float_surface IS NULL THEN 0
          WHEN e.float_surface IS NULL OR calibration_prediction.float_surface IS NULL THEN 9999
          ELSE ABS(
            CAST(e.float_surface AS SIGNED) -
            CAST(calibration_prediction.float_surface AS SIGNED)
          )
        END,
        calibration_prediction.n_calibration DESC,
        calibration_prediction.float_angle,
        calibration_prediction.float_surface
    ) AS row_num
  FROM FIELD_2026_BADOatNZ.EGGS e
  CROSS JOIN sr
  JOIN calibration_prediction
    ON e.float_location = calibration_prediction.float_location
  WHERE e.date <= sr.reference_date
    AND e.float_angle IS NOT NULL
    AND e.float_location IS NOT NULL
),
egg_hatch_prediction AS (
  SELECT
    egg_calibration_candidates.nest_id,
    egg_calibration_candidates.float_date,
    egg_calibration_candidates.days_since_float,
    egg_calibration_candidates.predicted_days_since_laying
      + egg_calibration_candidates.days_since_float AS ref_date_days_since_laid,
    calibration_hatch_day.hatch_day - egg_calibration_candidates.predicted_days_since_laying AS days_to_hatch
  FROM egg_calibration_candidates
  CROSS JOIN calibration_hatch_day
  WHERE egg_calibration_candidates.row_num = 1
),
latest_float_prediction AS (
  SELECT
    nest_id,
    MAX(float_date) AS latest_float_date
  FROM egg_hatch_prediction
  GROUP BY nest_id
),
nest_hatch_prediction AS (
  SELECT
    e.nest_id,
    lfp.latest_float_date,
    AVG(e.ref_date_days_since_laid) AS average_ref_date_days_since_laid,
    CAST(ROUND(AVG(e.days_to_hatch - e.days_since_float), 0) AS SIGNED) AS min_days_to_hatch
  FROM egg_hatch_prediction e
  JOIN latest_float_prediction lfp
    ON e.nest_id = lfp.nest_id
   AND e.float_date = lfp.latest_float_date
  GROUP BY
    e.nest_id,
    lfp.latest_float_date
)
SELECT
  n.nest_id,
  n.species,
  CAST(CONCAT(n.date, ' ', COALESCE(n.time_visit, '00:00:00')) AS DATETIME) AS last_visit_datetime,
  DATEDIFF(n.reference_date, n.date) AS days_ago,
  n.observer AS last_observer,
  n.nest_state,
  n.hatch_state,
  CASE
    WHEN n.hatch_state REGEXP '[0-9]+(S|CC|C)' THEN 1
    ELSE 0
  END AS hatch_signs_present,
  n.bird_inc,
  latest_clutch.clutch_size,
  latest_brood.brood_size,
  nest_hatch_prediction.min_days_to_hatch,
  parent_marks.M_mark,
  parent_marks.F_mark,
  n.nest_photo,
  n.tent_photo,
  nest_coordinates.lat,
  nest_coordinates.lon,
  nest_hatch_prediction.latest_float_date,
  nest_hatch_prediction.average_ref_date_days_since_laid
FROM latest_visit n
LEFT JOIN latest_clutch
  ON n.nest_id = latest_clutch.nest_id
 AND latest_clutch.row_num = 1
LEFT JOIN latest_brood
  ON n.nest_id = latest_brood.nest_id
 AND latest_brood.row_num = 1
LEFT JOIN parent_marks
  ON n.nest_id = parent_marks.nest_id
LEFT JOIN nest_state_summary
  ON n.nest_id = nest_state_summary.nest_id
LEFT JOIN nest_hatch_prediction
  ON n.nest_id = nest_hatch_prediction.nest_id
LEFT JOIN nest_coordinates
  ON n.nest_id = nest_coordinates.nest_id
 AND nest_coordinates.row_num = 1
WHERE n.row_num = 1
  AND NOT (
    UPPER(TRIM(COALESCE(n.nest_state, ''))) = 'S'
    AND DATEDIFF(n.reference_date, n.date) > 7
  )
  AND NOT (
    UPPER(TRIM(COALESCE(n.nest_state, ''))) = 'NOTA'
    AND COALESCE(nest_state_summary.has_found_or_incubated_state, 0) = 0
    AND DATEDIFF(n.reference_date, n.date) >= 1
  );


/*
  H-class RESIGHTINGS may omit nest_id when the chick is photographed away
  from a known nest. Resolve those rows once so BROODS_LATEST and TODO_LIST
  use the same operational association without altering the raw row.
*/
CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
h_events AS (
  SELECT
    r.pk AS resighting_pk,
    r.date AS resighting_date,
    r.nest_id AS raw_nest_id,
    NULLIF(TRIM(r.nest_id), '') AS raw_nest_id_key,
    NULLIF(
      NULLIF(UPPER(TRIM(COALESCE(r.ring, ''))), ''),
      'NA'
    ) AS ring_key,
    r.gps_id,
    r.gps_point,
    sr.reference_date
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'C'
    AND r.rclass = 'H'
    AND r.date <= sr.reference_date
    AND NULLIF(
          NULLIF(UPPER(TRIM(COALESCE(r.ring, ''))), ''),
          'NA'
        ) IS NOT NULL
),
same_occasion_adult_candidates AS (
  SELECT
    h.resighting_pk,
    TRIM(a.nest_id) AS adult_nest_id
  FROM h_events h
  JOIN FIELD_2026_BADOatNZ.RESIGHTINGS a
    ON a.date = h.resighting_date
   AND UPPER(TRIM(COALESCE(a.site, ''))) = 'CR'
   AND a.age = 'A'
   AND a.nest_id IS NOT NULL
   AND TRIM(a.nest_id) <> ''
   AND UPPER(TRIM(a.nest_id)) <> 'NO_NEST'
   AND h.gps_id IS NOT NULL
   AND h.gps_point IS NOT NULL
   AND a.gps_id = h.gps_id
   AND a.gps_point = h.gps_point
  WHERE h.raw_nest_id_key IS NULL
),
same_occasion_adult_summary AS (
  SELECT
    resighting_pk,
    COUNT(DISTINCT adult_nest_id) AS n_adult_nest_ids,
    MIN(adult_nest_id) AS adult_nest_id
  FROM same_occasion_adult_candidates
  GROUP BY resighting_pk
),
ring_capture_candidates AS (
  SELECT
    h.resighting_pk,
    TRIM(c.nest_id) AS capture_nest_id,
    CAST(
      CONCAT(
        c.date,
        ' ',
        COALESCE(c.released, c.caught, '00:00:00')
      ) AS DATETIME
    ) AS capture_datetime,
    c.pk AS capture_pk
  FROM h_events h
  JOIN FIELD_2026_BADOatNZ.CAPTURES c
    ON NULLIF(
         NULLIF(UPPER(TRIM(COALESCE(c.ring, ''))), ''),
         'NA'
       ) = h.ring_key
   AND c.age = 'C'
   AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
   AND c.nest_id IS NOT NULL
   AND TRIM(c.nest_id) <> ''
   AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
   AND c.date < h.resighting_date
  WHERE h.raw_nest_id_key IS NULL
),
latest_ring_capture_datetime AS (
  SELECT
    resighting_pk,
    MAX(capture_datetime) AS latest_capture_datetime
  FROM ring_capture_candidates
  GROUP BY resighting_pk
),
latest_ring_capture_summary AS (
  SELECT
    candidates.resighting_pk,
    COUNT(DISTINCT candidates.capture_nest_id) AS n_capture_nest_ids,
    MIN(candidates.capture_nest_id) AS capture_nest_id
  FROM ring_capture_candidates candidates
  JOIN latest_ring_capture_datetime latest
    ON candidates.resighting_pk = latest.resighting_pk
   AND candidates.capture_datetime = latest.latest_capture_datetime
  GROUP BY candidates.resighting_pk
)
SELECT
  h.resighting_pk,
  h.resighting_date,
  h.reference_date,
  h.raw_nest_id,
  h.ring_key AS ring,
  h.gps_id,
  h.gps_point,
  CASE
    WHEN UPPER(TRIM(COALESCE(h.raw_nest_id_key, ''))) = 'NO_NEST'
    THEN NULL
    WHEN h.raw_nest_id_key IS NOT NULL
    THEN h.raw_nest_id_key
    WHEN COALESCE(adults.n_adult_nest_ids, 0) = 1
    THEN adults.adult_nest_id
    WHEN COALESCE(adults.n_adult_nest_ids, 0) > 1
    THEN NULL
    WHEN COALESCE(captures.n_capture_nest_ids, 0) = 1
    THEN captures.capture_nest_id
    ELSE NULL
  END AS resolved_nest_id,
  CASE
    WHEN UPPER(TRIM(COALESCE(h.raw_nest_id_key, ''))) = 'NO_NEST'
    THEN 'explicit_no_nest'
    WHEN h.raw_nest_id_key IS NOT NULL
    THEN 'direct'
    WHEN COALESCE(adults.n_adult_nest_ids, 0) > 1
    THEN 'ambiguous_same_occasion_adult'
    WHEN COALESCE(adults.n_adult_nest_ids, 0) = 1
    THEN 'same_occasion_adult'
    WHEN COALESCE(captures.n_capture_nest_ids, 0) > 1
    THEN 'ambiguous_capture_history'
    WHEN COALESCE(captures.n_capture_nest_ids, 0) = 1
    THEN 'ring_capture'
    ELSE 'unresolved'
  END AS association_method
FROM h_events h
LEFT JOIN same_occasion_adult_summary adults
  ON h.resighting_pk = adults.resighting_pk
LEFT JOIN latest_ring_capture_summary captures
  ON h.resighting_pk = captures.resighting_pk;


/*
  BROODS_LATEST is the unified operational source for the PDF map and parent
  summary. Positive IDs retain their stationary NESTS history. Negative IDs
  represent mobile broods with no NESTS or EGGS rows and are discovered from
  nest-linked CAPTURES/RESIGHTINGS only.
*/
CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.BROODS_LATEST AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
positive_history AS (
  SELECT
    n.*,
    sr.reference_date,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
    ) AS row_num
  FROM FIELD_2026_BADOatNZ.NESTS n
  CROSS JOIN sr
  WHERE n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
    AND LEFT(TRIM(n.nest_id), 1) <> '-'
    AND UPPER(TRIM(n.nest_id)) <> 'NO_NEST'
    AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.date <= sr.reference_date
),
positive_history_status AS (
  SELECT
    nest_id,
    MAX(
      CASE
        WHEN UPPER(TRIM(COALESCE(nest_state, ''))) = 'H'
          OR COALESCE(brood_size, 0) > 0
        THEN 1
        ELSE 0
      END
    ) AS has_hatch_evidence,
    MIN(
      CASE
        WHEN UPPER(TRIM(COALESCE(nest_state, ''))) = 'H'
          OR COALESCE(brood_size, 0) > 0
        THEN date
      END
    ) AS hatch_evidence_date,
    MIN(date) AS discovery_date
  FROM positive_history
  GROUP BY nest_id
),
positive_chick_status AS (
  SELECT
    c.nest_id,
    MIN(c.date) AS first_chick_capture_date
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND LEFT(TRIM(c.nest_id), 1) <> '-'
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND UPPER(TRIM(COALESCE(c.age, ''))) = 'C'
    AND c.date <= sr.reference_date
  GROUP BY c.nest_id
),
positive_locations AS (
  SELECT
    n.nest_id,
    g.gps_id,
    g.gps_point,
    g.lat,
    g.lon,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY
        CASE
          WHEN n.nest_state = 'S' THEN 1
          WHEN n.nest_state = 'F' THEN 2
          ELSE 3
        END,
        n.date,
        n.time_visit,
        n.pk,
        g.datetime_,
        g.pk
    ) AS row_num
  FROM positive_history n
  JOIN FIELD_2026_BADOatNZ.GPS_POINTS g
    ON n.gps_id = g.gps_id
   AND n.gps_point = g.gps_point
  WHERE n.gps_id IS NOT NULL
    AND n.gps_point IS NOT NULL
),
negative_encounters AS (
  SELECT
    c.nest_id,
    c.date AS event_date,
    COALESCE(c.released, c.caught, '00:00:00') AS event_time,
    CAST(CONCAT(c.date, ' ', COALESCE(c.released, c.caught, '00:00:00')) AS DATETIME)
      AS event_datetime,
    c.gps_id,
    c.gps_point,
    c.pk AS event_pk,
    'CAPTURES' AS source_table,
    2 AS source_rank,
    c.age,
    CAST(NULL AS CHAR(1)) AS rclass
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND LEFT(TRIM(c.nest_id), 1) = '-'
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.date <= sr.reference_date
  UNION ALL
  SELECT
    r.nest_id,
    r.date AS event_date,
    '00:00:00' AS event_time,
    CAST(CONCAT(r.date, ' 00:00:00') AS DATETIME) AS event_datetime,
    r.gps_id,
    r.gps_point,
    r.pk AS event_pk,
    'RESIGHTINGS' AS source_table,
    CASE WHEN r.rclass = 'H' THEN 1 ELSE 3 END AS source_rank,
    r.age,
    r.rclass
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE r.nest_id IS NOT NULL
    AND LEFT(TRIM(r.nest_id), 1) = '-'
    AND UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.date <= sr.reference_date
),
negative_encounters_ranked AS (
  SELECT
    negative_encounters.*,
    ROW_NUMBER() OVER (
      PARTITION BY nest_id
      ORDER BY event_date DESC, event_datetime DESC, source_rank, event_pk DESC
    ) AS row_num
  FROM negative_encounters
),
negative_discovery AS (
  SELECT
    nest_id,
    MIN(event_date) AS discovery_date
  FROM negative_encounters
  GROUP BY nest_id
),
chick_events AS (
  SELECT
    c.nest_id,
    c.date AS event_date,
    COALESCE(c.released, c.caught, '00:00:00') AS event_time,
    CAST(CONCAT(c.date, ' ', COALESCE(c.released, c.caught, '00:00:00')) AS DATETIME)
      AS event_datetime,
    c.gps_id,
    c.gps_point,
    c.pk AS event_pk,
    'CAPTURES' AS source_table,
    2 AS source_rank,
    c.age,
    NULL AS rclass
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age = 'C'
    AND c.date <= sr.reference_date
  UNION ALL
  SELECT
    COALESCE(h_assoc.resolved_nest_id, r.nest_id) AS nest_id,
    r.date AS event_date,
    '00:00:00' AS event_time,
    CAST(CONCAT(r.date, ' 00:00:00') AS DATETIME) AS event_datetime,
    r.gps_id,
    r.gps_point,
    r.pk AS event_pk,
    'RESIGHTINGS' AS source_table,
    CASE WHEN r.rclass = 'H' THEN 1 ELSE 3 END AS source_rank,
    r.age,
    r.rclass
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  LEFT JOIN FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h_assoc
    ON r.pk = h_assoc.resighting_pk
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'C'
    AND r.date <= sr.reference_date
    AND (
      (
        r.nest_id IS NOT NULL
        AND TRIM(r.nest_id) <> ''
        AND UPPER(TRIM(r.nest_id)) <> 'NO_NEST'
      )
      OR h_assoc.resolved_nest_id IS NOT NULL
    )
),
chick_events_ranked AS (
  SELECT
    chick_events.*,
    ROW_NUMBER() OVER (
      PARTITION BY nest_id
      ORDER BY event_date DESC, event_datetime DESC, source_rank, event_pk DESC
    ) AS row_num
  FROM chick_events
),
direct_chick_locations AS (
  SELECT
    events.nest_id,
    events.event_date,
    events.event_datetime,
    events.event_pk,
    events.source_table,
    events.source_rank,
    events.gps_id,
    events.gps_point,
    g.lat,
    g.lon,
    ROW_NUMBER() OVER (
      PARTITION BY events.nest_id
      ORDER BY
        events.event_date DESC,
        events.event_datetime DESC,
        events.source_rank,
        events.event_pk DESC
    ) AS row_num
  FROM chick_events events
  JOIN FIELD_2026_BADOatNZ.GPS_POINTS g
    ON events.gps_id = g.gps_id
   AND events.gps_point = g.gps_point
  WHERE events.gps_id IS NOT NULL
    AND events.gps_point IS NOT NULL
),
chick_colour_events AS (
  SELECT
    c.nest_id,
    c.date AS event_date,
    COALESCE(c.released, c.caught, '00:00:00') AS event_time,
    c.pk,
    CASE
      WHEN UPPER(TRIM(c.LL)) IN ('B', 'G', 'O', 'R', 'W', 'Y')
      THEN UPPER(TRIM(c.LL))
      WHEN UPPER(TRIM(c.LR)) IN ('B', 'G', 'O', 'R', 'W', 'Y')
      THEN UPPER(TRIM(c.LR))
      ELSE NULL
    END AS chick_band
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age = 'C'
    AND c.date <= sr.reference_date
),
chick_colour_ranked AS (
  SELECT
    chick_colour_events.*,
    ROW_NUMBER() OVER (
      PARTITION BY nest_id
      ORDER BY event_date, event_time, pk
    ) AS row_num
  FROM chick_colour_events
  WHERE chick_band IS NOT NULL
),
negative_parent_events AS (
  SELECT
    c.nest_id,
    LEFT(c.field_sex, 1) AS sex,
    c.date AS event_date,
    COALESCE(c.released, c.caught, '00:00:00') AS event_time,
    c.pk AS event_pk,
    1 AS source_rank,
    CASE
      WHEN UPPER(TRIM(COALESCE(c.capture_status, ''))) = 'D' THEN 'dead'
      WHEN UPPER(TRIM(c.LL)) IN ('X', 'XX')
       AND UPPER(TRIM(c.LR)) IN ('X', 'XX') THEN 'X-X'
      WHEN (NULLIF(TRIM(c.UL), '') IS NOT NULL AND UPPER(TRIM(c.UL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(c.LL), '') IS NOT NULL AND UPPER(TRIM(c.LL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(c.UR), '') IS NOT NULL AND UPPER(TRIM(c.UR)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(c.LR), '') IS NOT NULL AND UPPER(TRIM(c.LR)) NOT REGEXP '^(X+|M)$')
      THEN FIELD_2026_BADOatNZ.format_mark(c.UL, c.LL, c.UR, c.LR)
      ELSE NULL
    END AS mark,
    CASE
      WHEN UPPER(TRIM(COALESCE(c.tag_type, ''))) = 'GEO'
       AND NULLIF(TRIM(c.tag_id), '') IS NOT NULL THEN 1
      WHEN UPPER(TRIM(c.UR)) REGEXP 'T'
        OR UPPER(TRIM(c.UL)) REGEXP 'T' THEN 1
      ELSE 0
    END AS has_geo
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND LEFT(TRIM(c.nest_id), 1) = '-'
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age = 'A'
    AND LEFT(c.field_sex, 1) IN ('M', 'F')
    AND c.date <= sr.reference_date
  UNION ALL
  SELECT
    r.nest_id,
    LEFT(r.sex, 1) AS sex,
    r.date AS event_date,
    '00:00:00' AS event_time,
    r.pk AS event_pk,
    2 AS source_rank,
    CASE
      WHEN UPPER(TRIM(r.LL)) IN ('X', 'XX')
       AND UPPER(TRIM(r.LR)) IN ('X', 'XX') THEN 'X-X'
      WHEN (NULLIF(TRIM(r.UL), '') IS NOT NULL AND UPPER(TRIM(r.UL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(r.LL), '') IS NOT NULL AND UPPER(TRIM(r.LL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(r.UR), '') IS NOT NULL AND UPPER(TRIM(r.UR)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(r.LR), '') IS NOT NULL AND UPPER(TRIM(r.LR)) NOT REGEXP '^(X+|M)$')
      THEN FIELD_2026_BADOatNZ.format_mark(
        NULLIF(TRIM(r.UL), ''),
        NULLIF(TRIM(r.LL), ''),
        NULLIF(TRIM(r.UR), ''),
        NULLIF(TRIM(r.LR), '')
      )
      ELSE NULL
    END AS mark,
    CASE
      WHEN UPPER(TRIM(r.UR)) REGEXP 'T'
        OR UPPER(TRIM(r.UL)) REGEXP 'T' THEN 1
      ELSE 0
    END AS has_geo
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE r.nest_id IS NOT NULL
    AND LEFT(TRIM(r.nest_id), 1) = '-'
    AND UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'A'
    AND LEFT(r.sex, 1) IN ('M', 'F')
    AND r.date <= sr.reference_date
),
negative_parent_ranked AS (
  SELECT
    negative_parent_events.*,
    ROW_NUMBER() OVER (
      PARTITION BY nest_id, sex
      ORDER BY
        CASE WHEN mark = 'dead' THEN 1 ELSE 0 END DESC,
        has_geo DESC,
        CASE WHEN mark IS NOT NULL THEN 1 ELSE 0 END DESC,
        event_date DESC,
        event_time DESC,
        source_rank,
        event_pk DESC
    ) AS row_num
  FROM negative_parent_events
),
negative_parent_marks AS (
  SELECT
    nest_id,
    MAX(CASE WHEN sex = 'M' AND row_num = 1 THEN mark END) AS M_mark,
    MAX(CASE WHEN sex = 'F' AND row_num = 1 THEN mark END) AS F_mark
  FROM negative_parent_ranked
  GROUP BY nest_id
),
positive_units AS (
  SELECT
    p.nest_id,
    p.species,
    'positive' AS brood_kind,
    0 AS is_negative_brood,
    h.discovery_date,
    p.date AS latest_encounter_date,
    CAST(CONCAT(p.date, ' ', COALESCE(p.time_visit, '00:00:00')) AS DATETIME)
      AS latest_encounter_datetime,
    CAST(NULL AS DATE) AS latest_chick_event_date,
    CAST(NULL AS CHAR(20)) AS latest_chick_event_source,
    CAST(NULL AS DATE) AS location_event_date,
    CAST(NULL AS DATETIME) AS location_event_datetime,
    CAST(NULL AS UNSIGNED) AS location_event_pk,
    CAST(NULL AS CHAR(20)) AS location_source_table,
    CAST(NULL AS CHAR(20)) AS location_source,
    loc.gps_id AS fallback_gps_id,
    loc.gps_point AS fallback_gps_point,
    loc.lat AS fallback_lat,
    loc.lon AS fallback_lon,
    CASE
      WHEN h.hatch_evidence_date IS NULL THEN chicks.first_chick_capture_date
      WHEN chicks.first_chick_capture_date IS NULL THEN h.hatch_evidence_date
      WHEN chicks.first_chick_capture_date < h.hatch_evidence_date
      THEN chicks.first_chick_capture_date
      ELSE h.hatch_evidence_date
    END AS hatch_evidence_date,
    CASE
      WHEN h.has_hatch_evidence = 1 OR chicks.nest_id IS NOT NULL THEN 1
      ELSE 0
    END AS has_hatch_evidence,
    p.nest_state,
    p.hatch_state,
    p.clutch_size,
    p.brood_size,
    nl.min_days_to_hatch,
    nl.M_mark,
    nl.F_mark,
    nl.nest_photo,
    nl.tent_photo,
    sr.reference_date,
    CAST(NULL AS CHAR(1)) AS chick_band
  FROM positive_history p
  JOIN positive_history_status h
    ON p.nest_id = h.nest_id
  LEFT JOIN positive_chick_status chicks
    ON p.nest_id = chicks.nest_id
  LEFT JOIN positive_locations loc
    ON p.nest_id = loc.nest_id
   AND loc.row_num = 1
  LEFT JOIN FIELD_2026_BADOatNZ.NESTS_LATEST nl
    ON p.nest_id = nl.nest_id
  CROSS JOIN sr
  WHERE p.row_num = 1
    AND NOT (
      UPPER(TRIM(COALESCE(p.nest_state, ''))) IN ('NOTA', 'P', 'D')
      AND h.has_hatch_evidence = 0
      AND chicks.nest_id IS NULL
    )
    AND NOT (
      UPPER(TRIM(COALESCE(p.nest_state, ''))) = 'S'
      AND DATEDIFF(p.reference_date, p.date) > 7
    )
),
negative_units AS (
  SELECT
    e.nest_id,
    CAST(NULL AS CHAR(4)) AS species,
    'negative' AS brood_kind,
    1 AS is_negative_brood,
    d.discovery_date,
    e.event_date AS latest_encounter_date,
    e.event_datetime AS latest_encounter_datetime,
    ce.event_date AS latest_chick_event_date,
    ce.source_table AS latest_chick_event_source,
    dl.event_date AS location_event_date,
    dl.event_datetime AS location_event_datetime,
    dl.event_pk AS location_event_pk,
    dl.source_table AS location_source_table,
    CASE
      WHEN dl.nest_id IS NOT NULL THEN 'direct_chick_event'
      ELSE 'missing_direct_chick_location'
    END AS location_source,
    CAST(NULL AS UNSIGNED) AS fallback_gps_id,
    CAST(NULL AS UNSIGNED) AS fallback_gps_point,
    CAST(NULL AS DECIMAL(12,7)) AS fallback_lat,
    CAST(NULL AS DECIMAL(12,7)) AS fallback_lon,
    CAST(NULL AS DATE) AS hatch_evidence_date,
    1 AS has_hatch_evidence,
    CAST(NULL AS CHAR(10)) AS nest_state,
    CAST(NULL AS CHAR(50)) AS hatch_state,
    CAST(NULL AS UNSIGNED) AS clutch_size,
    CAST(NULL AS UNSIGNED) AS brood_size,
    CAST(NULL AS SIGNED) AS min_days_to_hatch,
    pm.M_mark,
    pm.F_mark,
    CAST(NULL AS CHAR(1)) AS nest_photo,
    CAST(NULL AS CHAR(1)) AS tent_photo,
    sr.reference_date,
    cb.chick_band
  FROM negative_encounters_ranked e
  JOIN negative_discovery d
    ON e.nest_id = d.nest_id
  LEFT JOIN chick_events_ranked ce
    ON e.nest_id = ce.nest_id
   AND ce.row_num = 1
  LEFT JOIN direct_chick_locations dl
    ON e.nest_id = dl.nest_id
   AND dl.row_num = 1
  LEFT JOIN negative_parent_marks pm
    ON e.nest_id = pm.nest_id
  LEFT JOIN chick_colour_ranked cb
    ON e.nest_id = cb.nest_id
   AND cb.row_num = 1
  CROSS JOIN sr
  WHERE e.row_num = 1
)
SELECT
  units.nest_id,
  units.species,
  units.brood_kind,
  units.is_negative_brood,
  units.discovery_date,
  units.latest_encounter_date,
  units.latest_encounter_datetime,
  units.latest_chick_event_date,
  units.latest_chick_event_source,
  COALESCE(dl.gps_id, units.fallback_gps_id) AS gps_id,
  COALESCE(dl.gps_point, units.fallback_gps_point) AS gps_point,
  COALESCE(dl.lat, units.fallback_lat) AS lat,
  COALESCE(dl.lon, units.fallback_lon) AS lon,
  CASE
    WHEN dl.nest_id IS NOT NULL THEN 'direct_chick_event'
    WHEN units.fallback_lat IS NOT NULL THEN 'positive_nest_fallback'
    ELSE units.location_source
  END AS location_source,
  COALESCE(dl.event_date, units.location_event_date) AS location_event_date,
  COALESCE(dl.event_datetime, units.location_event_datetime) AS location_event_datetime,
  COALESCE(dl.event_pk, units.location_event_pk) AS location_event_pk,
  COALESCE(dl.source_table, units.location_source_table) AS location_source_table,
  units.hatch_evidence_date,
  units.has_hatch_evidence,
  units.nest_state,
  units.hatch_state,
  units.clutch_size,
  units.brood_size,
  units.min_days_to_hatch,
  units.M_mark,
  units.F_mark,
  units.nest_photo,
  units.tent_photo,
  COALESCE(units.chick_band, cb.chick_band) AS chick_band,
  units.reference_date
FROM (
  SELECT
    nest_id, species, brood_kind, is_negative_brood, discovery_date,
    latest_encounter_date, latest_encounter_datetime,
    latest_chick_event_date, latest_chick_event_source,
    location_event_date, location_event_datetime, location_event_pk,
    location_source_table, location_source, fallback_gps_id,
    fallback_gps_point, fallback_lat, fallback_lon, hatch_evidence_date,
    has_hatch_evidence, nest_state, hatch_state, clutch_size, brood_size,
    min_days_to_hatch, M_mark, F_mark, nest_photo, tent_photo,
    reference_date, chick_band
  FROM positive_units
  UNION ALL
  SELECT
    nest_id, species, brood_kind, is_negative_brood, discovery_date,
    latest_encounter_date, latest_encounter_datetime,
    latest_chick_event_date, latest_chick_event_source,
    location_event_date, location_event_datetime, location_event_pk,
    location_source_table, location_source, fallback_gps_id,
    fallback_gps_point, fallback_lat, fallback_lon, hatch_evidence_date,
    has_hatch_evidence, nest_state, hatch_state, clutch_size, brood_size,
    min_days_to_hatch, M_mark, F_mark, nest_photo, tent_photo,
    reference_date, chick_band
  FROM negative_units
) units
LEFT JOIN direct_chick_locations dl
  ON units.nest_id = dl.nest_id
 AND dl.row_num = 1
LEFT JOIN chick_colour_ranked cb
  ON units.nest_id = cb.nest_id
 AND cb.row_num = 1;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
nest_clutch_history AS (
  SELECT
    n.nest_id,
    n.date,
    n.time_visit,
    n.pk,
    n.nest_state,
    n.clutch_size
  FROM FIELD_2026_BADOatNZ.NESTS n
  CROSS JOIN sr
  WHERE n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
    AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.clutch_size IS NOT NULL
    AND n.date <= sr.reference_date
),
found_clutch_ranked AS (
  SELECT
    nest_clutch_history.*,
    ROW_NUMBER() OVER (
      PARTITION BY nest_id
      ORDER BY date, time_visit, pk
    ) AS row_num
  FROM nest_clutch_history
  WHERE UPPER(TRIM(COALESCE(nest_state, ''))) = 'F'
),
final_clutch_status AS (
  SELECT
    nest_id,
    MAX(clutch_size) AS final_clutch_size
  FROM nest_clutch_history
  WHERE clutch_size > 0
  GROUP BY nest_id
),
first_complete_clutch_ranked AS (
  SELECT
    history.nest_id,
    history.date AS first_complete_date,
    history.time_visit AS first_complete_time,
    history.pk AS first_complete_pk,
    history.clutch_size AS final_clutch_size,
    ROW_NUMBER() OVER (
      PARTITION BY history.nest_id
      ORDER BY history.date, history.time_visit, history.pk
    ) AS row_num
  FROM nest_clutch_history history
  JOIN final_clutch_status
    ON history.nest_id = final_clutch_status.nest_id
   AND history.clutch_size = final_clutch_status.final_clutch_size
),
last_incomplete_clutch_ranked AS (
  SELECT
    history.nest_id,
    history.date AS last_incomplete_date,
    history.clutch_size AS last_incomplete_size,
    ROW_NUMBER() OVER (
      PARTITION BY history.nest_id
      ORDER BY history.date DESC, history.time_visit DESC, history.pk DESC
    ) AS row_num
  FROM nest_clutch_history history
  JOIN final_clutch_status
    ON history.nest_id = final_clutch_status.nest_id
   AND history.clutch_size < final_clutch_status.final_clutch_size
  JOIN first_complete_clutch_ranked complete_clutch
    ON history.nest_id = complete_clutch.nest_id
   AND complete_clutch.row_num = 1
  WHERE CAST(
          CONCAT(history.date, ' ', COALESCE(history.time_visit, '00:00:00'))
          AS DATETIME
        ) < CAST(
          CONCAT(
            complete_clutch.first_complete_date,
            ' ',
            COALESCE(complete_clutch.first_complete_time, '00:00:00')
          ) AS DATETIME
        )
),
incomplete_clutch_status_base AS (
  SELECT
    found.nest_id,
    found.clutch_size AS found_clutch_size,
    final_clutch_status.final_clutch_size,
    complete_clutch.first_complete_date,
    CASE
      WHEN found.clutch_size < final_clutch_status.final_clutch_size THEN 1
      ELSE 0
    END AS found_as_incomplete,
    CASE
      WHEN found.clutch_size < final_clutch_status.final_clutch_size
      THEN CASE
        WHEN last_incomplete.last_incomplete_date IS NULL
        THEN complete_clutch.first_complete_date
        WHEN DATE_ADD(
               last_incomplete.last_incomplete_date,
               INTERVAL (
                 2 * (
                   final_clutch_status.final_clutch_size
                   - last_incomplete.last_incomplete_size
                 )
               ) DAY
             ) >= complete_clutch.first_complete_date
        THEN complete_clutch.first_complete_date
        ELSE DATE_ADD(
          DATE_ADD(
            last_incomplete.last_incomplete_date,
            INTERVAL (
              2 * (
                final_clutch_status.final_clutch_size
                - last_incomplete.last_incomplete_size
              )
            ) DAY
          ),
          INTERVAL ROUND(
            DATEDIFF(
              complete_clutch.first_complete_date,
              DATE_ADD(
                last_incomplete.last_incomplete_date,
                INTERVAL (
                  2 * (
                    final_clutch_status.final_clutch_size
                    - last_incomplete.last_incomplete_size
                  )
                ) DAY
              )
            ) / 2
          ) DAY
        )
      END
      ELSE NULL
    END AS inferred_clutch_completion_date
  FROM found_clutch_ranked found
  JOIN final_clutch_status
    ON found.nest_id = final_clutch_status.nest_id
  JOIN first_complete_clutch_ranked complete_clutch
    ON found.nest_id = complete_clutch.nest_id
   AND complete_clutch.row_num = 1
  LEFT JOIN last_incomplete_clutch_ranked last_incomplete
    ON found.nest_id = last_incomplete.nest_id
   AND last_incomplete.row_num = 1
  WHERE found.row_num = 1
),
incomplete_clutch_status AS (
  SELECT
    incomplete_clutch_status_base.*,
    DATE_ADD(inferred_clutch_completion_date, INTERVAL 26 DAY)
      AS inferred_hatch_date
  FROM incomplete_clutch_status_base
  WHERE found_as_incomplete = 1
),
calibration_hatch_day AS (
  SELECT CAST(MAX(days_since_laying) AS DECIMAL(5,1)) AS hatch_day
  FROM FIELD_2026_BADOatNZ.predict_hatching
),
calibration_prediction AS (
  SELECT
    p.float_angle,
    p.float_surface,
    p.float_location,
    CAST(AVG(p.days_since_laying) AS DECIMAL(5,1)) AS predicted_days_since_laying,
    CAST(MIN(p.days_since_laying) AS DECIMAL(5,1)) AS min_days_since_laying,
    CAST(MAX(p.days_since_laying) AS DECIMAL(5,1)) AS max_days_since_laying,
    COUNT(*) AS n_calibration
  FROM FIELD_2026_BADOatNZ.predict_hatching p
  GROUP BY
    p.float_angle,
    p.float_surface,
    p.float_location
),
egg_calibration_candidates AS (
  SELECT
    e.pk AS egg_pk,
    e.nest_id,
    e.egg_id,
    e.date AS float_date,
    sr.reference_date,
    DATEDIFF(sr.reference_date, e.date) AS days_since_float,
    e.float_angle,
    e.float_surface,
    e.float_location,
    calibration_prediction.float_angle AS matched_float_angle,
    calibration_prediction.float_surface AS matched_float_surface,
    calibration_prediction.float_location AS matched_float_location,
    calibration_prediction.predicted_days_since_laying,
    calibration_prediction.min_days_since_laying,
    calibration_prediction.max_days_since_laying,
    calibration_prediction.n_calibration,
    CASE
      WHEN e.float_angle = calibration_prediction.float_angle
       AND e.float_surface <=> calibration_prediction.float_surface
      THEN 'exact'
      ELSE 'nearest'
    END AS calibration_match_type,
    ABS(
      CAST(e.float_angle AS SIGNED) -
      CAST(calibration_prediction.float_angle AS SIGNED)
    ) AS angle_diff,
    CASE
      WHEN e.float_surface IS NULL AND calibration_prediction.float_surface IS NULL THEN 0
      WHEN e.float_surface IS NULL OR calibration_prediction.float_surface IS NULL THEN 9999
      ELSE ABS(
        CAST(e.float_surface AS SIGNED) -
        CAST(calibration_prediction.float_surface AS SIGNED)
      )
    END AS surface_diff,
    ROW_NUMBER() OVER (
      PARTITION BY e.pk
      ORDER BY
        CASE
          WHEN e.float_angle = calibration_prediction.float_angle
           AND e.float_surface <=> calibration_prediction.float_surface
          THEN 0
          ELSE 1
        END,
        ABS(
          CAST(e.float_angle AS SIGNED) -
          CAST(calibration_prediction.float_angle AS SIGNED)
        ),
        CASE
          WHEN e.float_surface IS NULL AND calibration_prediction.float_surface IS NULL THEN 0
          WHEN e.float_surface IS NULL OR calibration_prediction.float_surface IS NULL THEN 9999
          ELSE ABS(
            CAST(e.float_surface AS SIGNED) -
            CAST(calibration_prediction.float_surface AS SIGNED)
          )
        END,
        calibration_prediction.n_calibration DESC,
        calibration_prediction.float_angle,
        calibration_prediction.float_surface
    ) AS row_num
  FROM FIELD_2026_BADOatNZ.EGGS e
  CROSS JOIN sr
  JOIN calibration_prediction
    ON e.float_location = calibration_prediction.float_location
  WHERE e.date <= sr.reference_date
    AND e.float_angle IS NOT NULL
    AND e.float_location IS NOT NULL
),
egg_prediction AS (
  SELECT
    egg_calibration_candidates.nest_id,
    egg_calibration_candidates.egg_id,
    egg_calibration_candidates.float_date,
    egg_calibration_candidates.reference_date,
    egg_calibration_candidates.days_since_float,
    egg_calibration_candidates.float_angle,
    egg_calibration_candidates.float_surface,
    egg_calibration_candidates.float_location,
    egg_calibration_candidates.matched_float_angle,
    egg_calibration_candidates.matched_float_surface,
    egg_calibration_candidates.matched_float_location,
    egg_calibration_candidates.calibration_match_type,
    egg_calibration_candidates.angle_diff,
    egg_calibration_candidates.surface_diff,
    egg_calibration_candidates.predicted_days_since_laying,
    egg_calibration_candidates.min_days_since_laying,
    egg_calibration_candidates.max_days_since_laying,
    calibration_hatch_day.hatch_day - egg_calibration_candidates.predicted_days_since_laying AS days_to_hatch_at_float,
    calibration_hatch_day.hatch_day - egg_calibration_candidates.max_days_since_laying AS min_days_to_hatch_at_float,
    calibration_hatch_day.hatch_day - egg_calibration_candidates.min_days_since_laying AS max_days_to_hatch_at_float,
    egg_calibration_candidates.n_calibration
  FROM egg_calibration_candidates
  CROSS JOIN calibration_hatch_day
  WHERE egg_calibration_candidates.row_num = 1
),
incomplete_nest_prediction AS (
  SELECT
    incomplete_clutch_status.nest_id,
    sr.reference_date,
    incomplete_clutch_status.inferred_clutch_completion_date,
    incomplete_clutch_status.inferred_hatch_date
  FROM incomplete_clutch_status
  CROSS JOIN sr
  WHERE NOT EXISTS (
    SELECT 1
    FROM egg_prediction
    WHERE egg_prediction.nest_id = incomplete_clutch_status.nest_id
  )
)
SELECT
  nest_id,
  egg_id,
  float_date,
  reference_date,
  days_since_float,
  float_angle,
  float_surface,
  float_location,
  matched_float_angle,
  matched_float_surface,
  matched_float_location,
  calibration_match_type,
  angle_diff,
  surface_diff,
  predicted_days_since_laying,
  predicted_days_since_laying + days_since_float AS ref_date_days_since_laid,
  days_to_hatch_at_float,
  days_to_hatch_at_float - days_since_float AS days_to_hatch,
  DATE_ADD(float_date, INTERVAL ROUND(days_to_hatch_at_float) DAY) AS predicted_hatch_date,
  min_days_to_hatch_at_float - days_since_float AS min_days_to_hatch,
  max_days_to_hatch_at_float - days_since_float AS max_days_to_hatch,
  n_calibration
FROM egg_prediction

UNION ALL

SELECT
  nest_id,
  CAST(NULL AS UNSIGNED) AS egg_id,
  CAST(NULL AS DATE) AS float_date,
  reference_date,
  CAST(NULL AS SIGNED) AS days_since_float,
  CAST(NULL AS DECIMAL(5,1)) AS float_angle,
  CAST(NULL AS DECIMAL(5,1)) AS float_surface,
  CAST(NULL AS CHAR(10)) AS float_location,
  CAST(NULL AS DECIMAL(5,1)) AS matched_float_angle,
  CAST(NULL AS DECIMAL(5,1)) AS matched_float_surface,
  CAST(NULL AS CHAR(10)) AS matched_float_location,
  'found as incomplete' AS calibration_match_type,
  CAST(NULL AS SIGNED) AS angle_diff,
  CAST(NULL AS SIGNED) AS surface_diff,
  CAST(0 AS DECIMAL(5,1)) AS predicted_days_since_laying,
  CAST(
    DATEDIFF(reference_date, inferred_clutch_completion_date)
    AS DECIMAL(5,1)
  ) AS ref_date_days_since_laid,
  CAST(NULL AS DECIMAL(5,1)) AS days_to_hatch_at_float,
  DATEDIFF(inferred_hatch_date, reference_date) AS days_to_hatch,
  inferred_hatch_date AS predicted_hatch_date,
  DATEDIFF(inferred_hatch_date, reference_date) AS min_days_to_hatch,
  DATEDIFF(inferred_hatch_date, reference_date) AS max_days_to_hatch,
  0 AS n_calibration
FROM incomplete_nest_prediction;


-- The operational release ceiling is 60 of 100 GEOs, retaining 40 for the
-- anticipated later nest wave. Nests first known by 2026-09-24 receive the
-- historic-nest pair-completion priority implemented in TODO_LIST below.
-- The final sex quotas are 50 males and 50 females. Pair completion is allowed
-- only while the target sex remains below its quota; non-pair deployments
-- prefer the sex with the larger remaining quota and are then ranked by that
-- sex's phenology-stratum deficit.
CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.GEO_ROLLOUT_PHENOLOGY AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
parameters AS (
  SELECT
    CAST('2026-08-10' AS DATE) AS phenology_anchor,
    60 AS release_ceiling
),
nest_history AS (
  SELECT n.*
  FROM FIELD_2026_BADOatNZ.NESTS n
  CROSS JOIN sr
  WHERE n.date <= sr.reference_date
    AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
),
nest_discovery AS (
  SELECT
    nest_id,
    MIN(date) AS first_found_date
  FROM nest_history
  GROUP BY nest_id
),
first_one_egg_ranked AS (
  SELECT
    n.nest_id,
    n.date AS one_egg_date,
    n.time_visit AS one_egg_time,
    n.pk,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date, n.time_visit, n.pk
    ) AS row_num
  FROM nest_history n
  WHERE n.clutch_size = 1
),
direct_lay_bounds AS (
  SELECT
    one_egg.nest_id,
    one_egg.one_egg_date,
    MAX(prior.date) AS prior_zero_date
  FROM first_one_egg_ranked one_egg
  LEFT JOIN nest_history prior
    ON one_egg.nest_id = prior.nest_id
   AND CAST(
         CONCAT(prior.date, ' ', COALESCE(prior.time_visit, '00:00:00'))
         AS DATETIME
       ) < CAST(
         CONCAT(
           one_egg.one_egg_date,
           ' ',
           COALESCE(one_egg.one_egg_time, '00:00:00')
         ) AS DATETIME
       )
   AND (
     prior.clutch_size = 0
     OR UPPER(TRIM(COALESCE(prior.nest_state, ''))) = 'S'
   )
  WHERE one_egg.row_num = 1
  GROUP BY one_egg.nest_id, one_egg.one_egg_date
),
direct_lay AS (
  SELECT
    nest_id,
    DATE_ADD(
      COALESCE(prior_zero_date, DATE_SUB(one_egg_date, INTERVAL 2 DAY)),
      INTERVAL ROUND(
        DATEDIFF(
          one_egg_date,
          COALESCE(prior_zero_date, DATE_SUB(one_egg_date, INTERVAL 2 DAY))
        ) / 2
      ) DAY
    ) AS first_egg_estimate,
    COALESCE(prior_zero_date, DATE_SUB(one_egg_date, INTERVAL 2 DAY))
      AS first_egg_lower,
    one_egg_date AS first_egg_upper,
    CASE
      WHEN prior_zero_date IS NOT NULL
       AND DATEDIFF(one_egg_date, prior_zero_date) <= 3
      THEN 'high'
      ELSE 'medium'
    END AS phenology_confidence,
    1 AS source_rank
  FROM direct_lay_bounds
),
float_lay_ranked AS (
  SELECT
    p.nest_id,
    p.float_date,
    DATE_SUB(
      p.float_date,
      INTERVAL ROUND(p.predicted_days_since_laying) DAY
    ) AS lay_point,
    DATE_SUB(
      p.float_date,
      INTERVAL CEILING(
        p.predicted_days_since_laying
        + (
          p.days_to_hatch_at_float
          - (p.min_days_to_hatch + p.days_since_float)
        )
      ) DAY
    ) AS lay_lower,
    DATE_SUB(
      p.float_date,
      INTERVAL FLOOR(
        p.predicted_days_since_laying
        - (
          (p.max_days_to_hatch + p.days_since_float)
          - p.days_to_hatch_at_float
        )
      ) DAY
    ) AS lay_upper,
    CASE WHEN p.calibration_match_type = 'exact' THEN 1 ELSE 0 END AS is_exact,
    ROW_NUMBER() OVER (
      PARTITION BY p.nest_id, p.float_date
      ORDER BY
        CASE WHEN p.egg_id = 1 THEN 0 ELSE 1 END,
        DATE_SUB(
          p.float_date,
          INTERVAL ROUND(p.predicted_days_since_laying) DAY
        ),
        p.egg_id
    ) AS row_num
  FROM FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION p
  WHERE p.float_date IS NOT NULL
    AND p.predicted_days_since_laying IS NOT NULL
    AND p.calibration_match_type IN ('exact', 'nearest')
),
float_lay AS (
  SELECT
    nest_id,
    FROM_DAYS(ROUND(AVG(TO_DAYS(lay_point)))) AS first_egg_estimate,
    MIN(lay_lower) AS first_egg_lower,
    MAX(lay_upper) AS first_egg_upper,
    CASE
      WHEN MIN(is_exact) = 1
       AND DATEDIFF(MAX(lay_upper), MIN(lay_lower)) <= 4
      THEN 'high'
      WHEN DATEDIFF(MAX(lay_upper), MIN(lay_lower)) <= 8
      THEN 'medium'
      ELSE 'low'
    END AS phenology_confidence,
    2 AS source_rank
  FROM float_lay_ranked
  WHERE row_num = 1
  GROUP BY nest_id
),
final_clutch AS (
  SELECT
    nest_id,
    GREATEST(1, COALESCE(MAX(clutch_size), 3)) AS final_clutch_size
  FROM nest_history
  GROUP BY nest_id
),
incomplete_lay AS (
  SELECT
    p.nest_id,
    DATE_SUB(
      DATE_SUB(MIN(p.predicted_hatch_date), INTERVAL 26 DAY),
      INTERVAL (2 * (MAX(final_clutch.final_clutch_size) - 1)) DAY
    ) AS first_egg_estimate,
    DATE_SUB(
      DATE_SUB(
        DATE_SUB(MIN(p.predicted_hatch_date), INTERVAL 26 DAY),
        INTERVAL (2 * (MAX(final_clutch.final_clutch_size) - 1)) DAY
      ),
      INTERVAL 2 DAY
    ) AS first_egg_lower,
    DATE_ADD(
      DATE_SUB(
        DATE_SUB(MIN(p.predicted_hatch_date), INTERVAL 26 DAY),
        INTERVAL (2 * (MAX(final_clutch.final_clutch_size) - 1)) DAY
      ),
      INTERVAL 2 DAY
    ) AS first_egg_upper,
    'medium' AS phenology_confidence,
    3 AS source_rank
  FROM FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION p
  JOIN final_clutch
    ON p.nest_id = final_clutch.nest_id
  WHERE p.calibration_match_type = 'found as incomplete'
  GROUP BY p.nest_id
),
clutch_lay AS (
  SELECT
    summary.nest_id,
    DATE_SUB(
      summary.first_complete_date,
      INTERVAL (2 * (summary.final_clutch_size - 1)) DAY
    ) AS first_egg_estimate,
    DATE_SUB(
      DATE_SUB(
        summary.first_complete_date,
        INTERVAL (2 * (summary.final_clutch_size - 1)) DAY
      ),
      INTERVAL 4 DAY
    ) AS first_egg_lower,
    DATE_SUB(
      summary.first_complete_date,
      INTERVAL (2 * (summary.final_clutch_size - 1)) DAY
    ) AS first_egg_upper,
    'low' AS phenology_confidence,
    4 AS source_rank
  FROM (
    SELECT
      history.nest_id,
      final_clutch.final_clutch_size,
      MIN(history.date) AS first_complete_date
    FROM nest_history history
    JOIN final_clutch
      ON history.nest_id = final_clutch.nest_id
     AND history.clutch_size = final_clutch.final_clutch_size
    WHERE history.clutch_size > 0
    GROUP BY history.nest_id, final_clutch.final_clutch_size
  ) summary
),
discovery_lay AS (
  SELECT
    nest_id,
    DATE_SUB(first_found_date, INTERVAL 5 DAY) AS first_egg_estimate,
    DATE_SUB(first_found_date, INTERVAL 10 DAY) AS first_egg_lower,
    first_found_date AS first_egg_upper,
    'low' AS phenology_confidence,
    5 AS source_rank
  FROM nest_discovery
),
lay_candidates AS (
  SELECT * FROM direct_lay
  UNION ALL
  SELECT * FROM float_lay
  UNION ALL
  SELECT * FROM incomplete_lay
  UNION ALL
  SELECT * FROM clutch_lay
  UNION ALL
  SELECT * FROM discovery_lay
),
lay_ranked AS (
  SELECT
    candidates.*,
    ROW_NUMBER() OVER (
      PARTITION BY candidates.nest_id
      ORDER BY candidates.source_rank
    ) AS row_num
  FROM lay_candidates candidates
),
nest_lay AS (
  SELECT
    ranked.nest_id,
    ranked.first_egg_estimate,
    ranked.first_egg_lower,
    ranked.first_egg_upper,
    ranked.phenology_confidence,
    DATE_ADD(
      parameters.phenology_anchor,
      INTERVAL (
        7 * FLOOR(
          DATEDIFF(ranked.first_egg_estimate, parameters.phenology_anchor) / 7
        )
      ) DAY
    ) AS stratum_start,
    CASE
      WHEN FLOOR(
        DATEDIFF(ranked.first_egg_lower, parameters.phenology_anchor) / 7
      ) <> FLOOR(
        DATEDIFF(ranked.first_egg_upper, parameters.phenology_anchor) / 7
      )
      THEN 1
      ELSE 0
    END AS spans_strata
  FROM lay_ranked ranked
  CROSS JOIN parameters
  WHERE ranked.row_num = 1
),
stratum_nest_counts AS (
  SELECT
    stratum_start,
    COUNT(*) AS n_nests
  FROM nest_lay
  GROUP BY stratum_start
),
stratum_deployment_counts AS (
  SELECT
    lay.stratum_start,
    COUNT(DISTINCT CASE
      WHEN LEFT(c.field_sex, 1) = 'M' THEN NULLIF(TRIM(c.tag_id), '')
    END) AS male_geo,
    COUNT(DISTINCT CASE
      WHEN LEFT(c.field_sex, 1) = 'F' THEN NULLIF(TRIM(c.tag_id), '')
    END) AS female_geo
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  JOIN nest_lay lay
    ON c.nest_id = lay.nest_id
  CROSS JOIN sr
  WHERE c.date <= sr.reference_date
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND UPPER(TRIM(COALESCE(c.tag_type, ''))) = 'GEO'
    AND UPPER(TRIM(COALESCE(c.tag_action, ''))) IN ('D', 'S', 'N')
    AND NULLIF(TRIM(c.tag_id), '') IS NOT NULL
  GROUP BY lay.stratum_start
),
deployment_status AS (
  SELECT
    COUNT(DISTINCT NULLIF(TRIM(c.tag_id), '')) AS n_geo_deployed,
    COUNT(DISTINCT CASE
      WHEN LEFT(c.field_sex, 1) = 'M' THEN NULLIF(TRIM(c.tag_id), '')
    END) AS n_male_geo_deployed,
    COUNT(DISTINCT CASE
      WHEN LEFT(c.field_sex, 1) = 'F' THEN NULLIF(TRIM(c.tag_id), '')
    END) AS n_female_geo_deployed
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.date <= sr.reference_date
    AND UPPER(TRIM(COALESCE(c.tag_type, ''))) = 'GEO'
    AND UPPER(TRIM(COALESCE(c.tag_action, ''))) IN ('D', 'S', 'N')
    AND NULLIF(TRIM(c.tag_id), '') IS NOT NULL
),
stratum_targets AS (
  SELECT
    nest_counts.stratum_start,
    nest_counts.n_nests,
    COALESCE(deployments.male_geo, 0) AS male_geo,
    COALESCE(deployments.female_geo, 0) AS female_geo,
    COALESCE(deployments.male_geo, 0)
      + COALESCE(deployments.female_geo, 0) AS current_geo_total,
    COALESCE(deployments.male_geo, 0)
      + COALESCE(deployments.female_geo, 0)
      + GREATEST(
          0,
          parameters.release_ceiling - deployment_status.n_geo_deployed
        ) * nest_counts.n_nests
          / NULLIF(SUM(nest_counts.n_nests) OVER (), 0)
      AS target_total,
    deployment_status.n_male_geo_deployed,
    deployment_status.n_female_geo_deployed
  FROM stratum_nest_counts nest_counts
  LEFT JOIN stratum_deployment_counts deployments
    ON nest_counts.stratum_start = deployments.stratum_start
  CROSS JOIN deployment_status
  CROSS JOIN parameters
),
stratum_status AS (
  SELECT
    targets.*,
    CASE
      WHEN targets.male_geo < targets.female_geo
      THEN targets.female_geo - targets.male_geo
      WHEN targets.male_geo = targets.female_geo
       AND targets.target_total > targets.current_geo_total
       AND targets.n_male_geo_deployed < targets.n_female_geo_deployed
      THEN targets.target_total - targets.current_geo_total
      ELSE 0
    END AS male_deficit,
    CASE
      WHEN targets.female_geo < targets.male_geo
      THEN targets.male_geo - targets.female_geo
      WHEN targets.male_geo = targets.female_geo
       AND targets.target_total > targets.current_geo_total
       AND targets.n_female_geo_deployed < targets.n_male_geo_deployed
      THEN targets.target_total - targets.current_geo_total
      ELSE 0
    END AS female_deficit
  FROM stratum_targets targets
)
SELECT
  lay.nest_id,
  lay.first_egg_estimate,
  lay.first_egg_lower,
  lay.first_egg_upper,
  lay.phenology_confidence,
  lay.stratum_start,
  lay.spans_strata,
  strata.n_nests AS stratum_n_nests,
  strata.male_geo AS stratum_male_geo,
  strata.female_geo AS stratum_female_geo,
  strata.target_total AS stratum_target_total,
  strata.male_deficit,
  strata.female_deficit
FROM nest_lay lay
LEFT JOIN stratum_status strata
  ON lay.stratum_start = strata.stratum_start;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.TODO_LIST AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
cr_current_nest_ids AS (
  SELECT
    latest_visit.nest_id
  FROM (
    SELECT
      n.nest_id,
      n.site,
      ROW_NUMBER() OVER (
        PARTITION BY n.nest_id
        ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
      ) AS row_num
    FROM FIELD_2026_BADOatNZ.NESTS n
    CROSS JOIN sr
    WHERE n.nest_id IS NOT NULL
      AND TRIM(n.nest_id) <> ''
      AND n.date <= sr.reference_date
  ) latest_visit
  WHERE latest_visit.row_num = 1
    AND UPPER(TRIM(COALESCE(latest_visit.site, ''))) = 'CR'
),
latest_float_dates AS (
  SELECT
    p.nest_id,
    MAX(p.float_date) AS latest_float_date
  FROM FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION p
  WHERE p.float_date IS NOT NULL
    AND p.calibration_match_type IN ('exact', 'nearest')
  GROUP BY p.nest_id
),
latest_float_status AS (
  SELECT
    p.nest_id,
    d.latest_float_date,
    CAST(
      AVG(p.predicted_days_since_laying + p.days_since_float)
      AS DECIMAL(6,1)
    ) AS average_ref_date_days_since_laid,
    CAST(
      ROUND(AVG(p.min_days_to_hatch), 0)
      AS SIGNED
    ) AS min_days_to_hatch
  FROM FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION p
  JOIN latest_float_dates d
    ON p.nest_id = d.nest_id
   AND p.float_date = d.latest_float_date
  GROUP BY
    p.nest_id,
    d.latest_float_date
),
geo_deployment_status AS (
  SELECT
    COUNT(DISTINCT NULLIF(TRIM(c.tag_id), '')) AS n_geo_deployed,
    COUNT(DISTINCT CASE
      WHEN LEFT(c.field_sex, 1) = 'M' THEN NULLIF(TRIM(c.tag_id), '')
    END) AS n_male_geo_deployed,
    COUNT(DISTINCT CASE
      WHEN LEFT(c.field_sex, 1) = 'F' THEN NULLIF(TRIM(c.tag_id), '')
    END) AS n_female_geo_deployed,
    60 AS release_ceiling,
    GREATEST(
      0,
      50 - COUNT(DISTINCT CASE
        WHEN LEFT(c.field_sex, 1) = 'M' THEN NULLIF(TRIM(c.tag_id), '')
      END)
    ) AS male_quota_remaining,
    GREATEST(
      0,
      50 - COUNT(DISTINCT CASE
        WHEN LEFT(c.field_sex, 1) = 'F' THEN NULLIF(TRIM(c.tag_id), '')
      END)
    ) AS female_quota_remaining,
    CASE
      WHEN GREATEST(
             0,
             50 - COUNT(DISTINCT CASE
               WHEN LEFT(c.field_sex, 1) = 'M'
               THEN NULLIF(TRIM(c.tag_id), '')
             END)
           )
           > GREATEST(
               0,
               50 - COUNT(DISTINCT CASE
                 WHEN LEFT(c.field_sex, 1) = 'F'
                 THEN NULLIF(TRIM(c.tag_id), '')
               END)
             )
      THEN 'M'
      WHEN GREATEST(
             0,
             50 - COUNT(DISTINCT CASE
               WHEN LEFT(c.field_sex, 1) = 'F'
               THEN NULLIF(TRIM(c.tag_id), '')
             END)
           )
           > GREATEST(
               0,
               50 - COUNT(DISTINCT CASE
                 WHEN LEFT(c.field_sex, 1) = 'M'
                 THEN NULLIF(TRIM(c.tag_id), '')
               END)
             )
      THEN 'F'
      ELSE NULL
    END AS preferred_balance_sex
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.date <= sr.reference_date
    AND UPPER(TRIM(COALESCE(c.tag_type, ''))) = 'GEO'
    AND UPPER(TRIM(COALESCE(c.tag_action, ''))) IN ('D', 'S', 'N')
    AND NULLIF(TRIM(c.tag_id), '') IS NOT NULL
),
initial_clutch_status AS (
  SELECT
    p.nest_id,
    1 AS found_as_incomplete,
    DATE_SUB(p.predicted_hatch_date, INTERVAL 26 DAY)
      AS inferred_clutch_completion_date,
    p.predicted_hatch_date AS inferred_hatch_date
  FROM FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION p
  WHERE p.calibration_match_type = 'found as incomplete'
),
latest_nests AS (
  SELECT DISTINCT
    n.nest_id,
    n.species,
    n.last_visit_datetime,
    n.days_ago,
    n.last_observer,
    n.nest_state,
    n.hatch_state,
    n.hatch_signs_present,
    n.bird_inc,
    n.clutch_size,
    n.brood_size,
    latest_float_status.latest_float_date,
    latest_float_status.average_ref_date_days_since_laid,
    CASE
      WHEN observed_hatch_dates.hatch_date IS NOT NULL
      THEN DATEDIFF(
        observed_hatch_dates.hatch_date,
        sr.reference_date
      )
      WHEN initial_clutch_status.found_as_incomplete = 1
      THEN DATEDIFF(
        initial_clutch_status.inferred_hatch_date,
        sr.reference_date
      )
      ELSE COALESCE(
        latest_float_status.min_days_to_hatch,
        n.min_days_to_hatch
      )
    END AS min_days_to_hatch,
    n.nest_photo,
    n.tent_photo,
    n.lat,
    n.lon,
    sr.reference_date
  FROM FIELD_2026_BADOatNZ.NESTS_LATEST n
  JOIN cr_current_nest_ids
    ON n.nest_id = cr_current_nest_ids.nest_id
  LEFT JOIN initial_clutch_status
    ON n.nest_id = initial_clutch_status.nest_id
  LEFT JOIN (
    SELECT
      observed_nest.nest_id,
      MIN(observed_nest.date) AS hatch_date
    FROM FIELD_2026_BADOatNZ.NESTS observed_nest
    CROSS JOIN sr
    WHERE observed_nest.nest_id IS NOT NULL
      AND TRIM(observed_nest.nest_id) <> ''
      AND UPPER(TRIM(COALESCE(observed_nest.site, ''))) = 'CR'
      AND UPPER(TRIM(COALESCE(observed_nest.nest_state, ''))) = 'H'
      AND observed_nest.date <= sr.reference_date
    GROUP BY observed_nest.nest_id
  ) observed_hatch_dates
    ON n.nest_id = observed_hatch_dates.nest_id
  LEFT JOIN latest_float_status
    ON n.nest_id = latest_float_status.nest_id
  CROSS JOIN sr
),
active_nests AS (
  SELECT DISTINCT
    n.*
  FROM latest_nests n
  -- pP and pD are uncertain and remain operationally active like I until a
  -- definitive fate or hatch state is recorded.
  WHERE n.nest_state IS NULL
    OR UPPER(TRIM(COALESCE(n.nest_state, ''))) NOT IN ('P', 'D', 'NOTA')
),
nest_history AS (
  SELECT DISTINCT
    n.*
  FROM FIELD_2026_BADOatNZ.NESTS n
  CROSS JOIN sr
  WHERE n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
    AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.date <= sr.reference_date
),
first_processable_visit AS (
  SELECT
    nest_id,
    MIN(date) AS first_processable_date,
    MIN(
      CAST(CONCAT(date, ' ', COALESCE(time_visit, '00:00:00')) AS DATETIME)
    ) AS first_processable_datetime
  FROM nest_history
  WHERE UPPER(TRIM(COALESCE(nest_state, ''))) IN ('F', 'I', 'PP', 'PD')
  GROUP BY nest_id
),
photo_summary AS (
  SELECT
    nest_id,
    MAX(date) AS last_photo_date,
    MAX(
      CAST(CONCAT(date, ' ', COALESCE(time_visit, '00:00:00')) AS DATETIME)
    ) AS last_photo_datetime,
    COUNT(*) AS n_photo_rows
  FROM nest_history
  WHERE nest_photo = '1'
     OR tent_photo = '1'
  GROUP BY nest_id
),
processing_photo_summary AS (
  SELECT
    n.nest_id,
    MAX(n.date) AS last_photo_date,
    MAX(
      CAST(CONCAT(n.date, ' ', COALESCE(n.time_visit, '00:00:00')) AS DATETIME)
    ) AS last_photo_datetime,
    COUNT(*) AS n_photo_rows
  FROM nest_history n
  JOIN first_processable_visit
    ON n.nest_id = first_processable_visit.nest_id
  WHERE (n.nest_photo = '1' OR n.tent_photo = '1')
    AND CAST(CONCAT(n.date, ' ', COALESCE(n.time_visit, '00:00:00')) AS DATETIME)
        >= first_processable_visit.first_processable_datetime
  GROUP BY n.nest_id
),
float_visit_summary AS (
  SELECT
    e.nest_id,
    e.date AS float_date,
    COALESCE(e.time_visit, '00:00:00') AS float_time_visit,
    MAX(
      CAST(CONCAT(e.date, ' ', COALESCE(e.time_visit, '00:00:00')) AS DATETIME)
    ) AS float_datetime,
    COUNT(*) AS n_float_rows
  FROM FIELD_2026_BADOatNZ.EGGS e
  CROSS JOIN sr
  JOIN latest_nests
    ON e.nest_id = latest_nests.nest_id
  WHERE e.date <= sr.reference_date
    AND e.float_angle IS NOT NULL
    AND e.float_location IS NOT NULL
  GROUP BY
    e.nest_id,
    e.date,
    COALESCE(e.time_visit, '00:00:00')
),
float_summary AS (
  SELECT
    float_visit_summary.nest_id,
    MAX(float_visit_summary.float_date) AS last_float_date,
    MAX(float_visit_summary.float_datetime) AS last_float_datetime,
    SUM(float_visit_summary.n_float_rows) AS n_float_rows
  FROM float_visit_summary
  JOIN first_processable_visit
    ON float_visit_summary.nest_id = first_processable_visit.nest_id
   AND float_visit_summary.float_datetime
       >= first_processable_visit.first_processable_datetime
  GROUP BY float_visit_summary.nest_id
),
processed_visit_summary AS (
  SELECT
    first_processable_visit.nest_id,
    CASE
      WHEN processing_photo_summary.last_photo_datetime IS NOT NULL
       AND float_summary.last_float_datetime IS NOT NULL
      THEN GREATEST(
        processing_photo_summary.last_photo_datetime,
        float_summary.last_float_datetime
      )
      ELSE NULL
    END AS last_processed_datetime
  FROM first_processable_visit
  LEFT JOIN processing_photo_summary
    ON first_processable_visit.nest_id = processing_photo_summary.nest_id
  LEFT JOIN float_summary
    ON first_processable_visit.nest_id = float_summary.nest_id
),
processing_summary AS (
  SELECT
    first_processable_visit.nest_id,
    first_processable_visit.first_processable_date,
    processing_photo_summary.last_photo_date,
    processing_photo_summary.last_photo_datetime,
    float_summary.last_float_date,
    float_summary.last_float_datetime,
    COALESCE(processing_photo_summary.n_photo_rows, 0) AS n_photo_rows,
    COALESCE(float_summary.n_float_rows, 0) AS n_float_rows,
    processed_visit_summary.last_processed_datetime
  FROM first_processable_visit
  LEFT JOIN processing_photo_summary
    ON first_processable_visit.nest_id = processing_photo_summary.nest_id
  LEFT JOIN float_summary
    ON first_processable_visit.nest_id = float_summary.nest_id
  LEFT JOIN processed_visit_summary
    ON first_processable_visit.nest_id = processed_visit_summary.nest_id
),
nest_discovery AS (
  SELECT
    nest_id,
    COALESCE(
      MIN(CASE WHEN UPPER(TRIM(COALESCE(nest_state, ''))) = 'F' THEN date END),
      MIN(CASE WHEN UPPER(TRIM(COALESCE(nest_state, ''))) IN ('I', 'PP', 'PD') THEN date END),
      MIN(date)
    ) AS first_found_date
  FROM nest_history
  GROUP BY nest_id
),
latest_clutch_history AS (
  SELECT
    n.nest_id,
    n.clutch_size,
    n.date AS clutch_date,
    COALESCE(n.time_visit, '00:00:00') AS clutch_time_visit,
    CAST(CONCAT(n.date, ' ', COALESCE(n.time_visit, '00:00:00')) AS DATETIME)
      AS clutch_datetime,
    CASE
      WHEN n.nest_photo = '1' OR n.tent_photo = '1' THEN 1
      ELSE 0
    END AS clutch_has_photo,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
    ) AS row_num
  FROM nest_history n
  WHERE n.clutch_size IS NOT NULL
),
latest_nest_event AS (
  SELECT
    n.nest_id,
    n.clutch_size,
    n.date AS event_date,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
    ) AS row_num
  FROM nest_history n
),
latest_clutch_processing_status AS (
  SELECT
    latest_clutch_history.nest_id,
    latest_clutch_history.clutch_has_photo,
    MAX(
      CASE
        WHEN latest_nests.hatch_signs_present = 1 THEN 1
        WHEN float_visit_summary.nest_id IS NOT NULL THEN 1
        ELSE 0
      END
    ) AS clutch_has_float
  FROM latest_clutch_history
  LEFT JOIN latest_nests
    ON latest_clutch_history.nest_id = latest_nests.nest_id
  LEFT JOIN float_visit_summary
    ON latest_clutch_history.nest_id = float_visit_summary.nest_id
   AND float_visit_summary.float_datetime
       >= latest_clutch_history.clutch_datetime
  WHERE latest_clutch_history.row_num = 1
  GROUP BY
    latest_clutch_history.nest_id,
    latest_clutch_history.clutch_has_photo
),
clutch_at_processing AS (
  SELECT
    n.nest_id,
    n.clutch_size,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
    ) AS row_num
  FROM nest_history n
  JOIN processing_summary
    ON n.nest_id = processing_summary.nest_id
   AND processing_summary.last_processed_datetime IS NOT NULL
   AND CAST(CONCAT(n.date, ' ', COALESCE(n.time_visit, '00:00:00')) AS DATETIME)
       <= processing_summary.last_processed_datetime
  WHERE n.clutch_size IS NOT NULL
),
hatched_nests AS (
  SELECT
    nest_id,
    MIN(date) AS hatch_date
  FROM nest_history
  WHERE nest_state = 'H'
  GROUP BY nest_id
),
brood_followup_nests AS (
  SELECT
    n.*,
    hatched_nests.hatch_date
  FROM latest_nests n
  JOIN hatched_nests
    ON n.nest_id = hatched_nests.nest_id
  WHERE n.nest_state IN ('H', 'notA')
),
nota_followup_nests AS (
  SELECT
    n.*
  FROM latest_nests n
  WHERE UPPER(TRIM(COALESCE(n.nest_state, ''))) IN ('P', 'D')
     OR (
       n.nest_state = 'H'
       AND COALESCE(n.clutch_size, 0) = 0
       AND COALESCE(n.brood_size, 0) > 0
     )
),
chick_captures AS (
  SELECT
    c.nest_id,
    COUNT(*) AS n_chick_captures,
    COUNT(DISTINCT NULLIF(
      NULLIF(UPPER(TRIM(COALESCE(c.ring, ''))), ''),
      'NA'
    )) AS n_captured_chick_rings
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age = 'C'
    AND c.date <= sr.reference_date
  GROUP BY c.nest_id
),
hiding_spot_photos AS (
  SELECT
    h.resolved_nest_id AS nest_id,
    COUNT(DISTINCT h.ring) AS n_hiding_spot_photos
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h
  JOIN FIELD_2026_BADOatNZ.RESIGHTINGS r
    ON r.pk = h.resighting_pk
  JOIN FIELD_2026_BADOatNZ.GPS_POINTS g
    ON r.gps_id = g.gps_id
   AND r.gps_point = g.gps_point
  CROSS JOIN sr
  WHERE h.resolved_nest_id IS NOT NULL
    AND h.association_method IN (
      'direct',
      'same_occasion_adult',
      'ring_capture'
    )
    AND UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'C'
    AND r.rclass = 'H'
    AND r.date <= sr.reference_date
    AND r.gps_id IS NOT NULL
    AND r.gps_point IS NOT NULL
    AND NULLIF(
          NULLIF(UPPER(TRIM(COALESCE(r.photo_start, ''))), ''),
          'NA'
        ) IS NOT NULL
    AND NULLIF(
          NULLIF(UPPER(TRIM(COALESCE(r.photo_end, ''))), ''),
          'NA'
        ) IS NOT NULL
  GROUP BY h.resolved_nest_id
),
adult_capture_events AS (
  SELECT
    x.nest_id,
    x.sex,
    x.capture_method,
    x.capture_date,
    x.capture_datetime,
    x.event_pk,
    x.mark,
    x.ring,
    x.LL_norm,
    x.LR_norm,
    x.is_confirmed_xx,
    x.has_geo,
    x.is_au_migrant,
    x.is_dead,
    x.has_complete_tarsal_pair,
    CASE
      WHEN x.non_x_non_m_count = 1
       AND x.plain_colour_count = 1
       AND x.metal_count >= 1
      THEN 1
      ELSE 0
    END AS is_single_colour_recruit
  FROM (
    SELECT
      c.nest_id,
      LEFT(c.field_sex, 1) AS sex,
      c.capture_method,
      c.date AS capture_date,
      CAST(
        CONCAT(
          c.date,
          ' ',
          COALESCE(c.released, c.caught, '00:00:00')
        ) AS DATETIME
      ) AS capture_datetime,
      c.pk AS event_pk,
      NULLIF(TRIM(c.ring), '') AS ring,
      CASE
        WHEN UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))
               IN ('X', 'XX')
        THEN 'X'
        ELSE UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))
      END AS LL_norm,
      CASE
        WHEN UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')))
               IN ('X', 'XX')
        THEN 'X'
        ELSE UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')))
      END AS LR_norm,
      CASE
        WHEN UPPER(TRIM(COALESCE(c.capture_status, ''))) = 'D'
        THEN 'dead'
        WHEN UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))
               IN ('X', 'XX')
         AND UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')))
               IN ('X', 'XX')
        THEN 'X-X'
        WHEN (
          COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')) IS NOT NULL
          AND UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')))
              NOT REGEXP '^(X+|M)$'
        ) OR (
          COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')) IS NOT NULL
          AND UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))
              NOT REGEXP '^(X+|M)$'
        ) OR (
          COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')) IS NOT NULL
          AND UPPER(COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')))
              NOT REGEXP '^(X+|M)$'
        ) OR (
          COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')) IS NOT NULL
          AND UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')))
              NOT REGEXP '^(X+|M)$'
        )
        THEN FIELD_2026_BADOatNZ.format_mark(
          COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')),
          COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')),
          COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')),
          COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), ''))
        )
        ELSE NULL
      END AS mark,
      CASE
        WHEN UPPER(TRIM(COALESCE(c.capture_status, ''))) = 'D'
        THEN 0
        WHEN UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))
               IN ('X', 'XX')
         AND UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')))
               IN ('X', 'XX')
        THEN 1
        ELSE 0
      END AS is_confirmed_xx,
      CASE
        WHEN (
          UPPER(TRIM(COALESCE(c.tag_type, ''))) = 'GEO'
          AND UPPER(TRIM(COALESCE(c.tag_action, ''))) IN ('D', 'S', 'N')
          AND NULLIF(TRIM(c.tag_id), '') IS NOT NULL
        ) OR UPPER(
          COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), ''), '')
        ) REGEXP '^T[A-Z0-9]*$'
        OR UPPER(
          COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), ''), '')
        ) REGEXP '^T[A-Z0-9]*$'
        THEN 1
        ELSE 0
      END AS has_geo,
      CASE
        WHEN LEFT(UPPER(TRIM(COALESCE(c.UL, ''))), 2) = 'FO'
          OR LEFT(UPPER(TRIM(COALESCE(c.UR, ''))), 2) = 'FO'
          OR LEFT(UPPER(TRIM(COALESCE(c.UL_in, ''))), 2) = 'FO'
          OR LEFT(UPPER(TRIM(COALESCE(c.UR_in, ''))), 2) = 'FO'
        THEN 1
        ELSE 0
      END AS is_au_migrant,
      CASE
        WHEN UPPER(TRIM(COALESCE(c.capture_status, ''))) = 'D' THEN 1
        ELSE 0
      END AS is_dead,
      CASE
        WHEN COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), ''))
               IS NOT NULL
         AND COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), ''))
               IS NOT NULL
        THEN 1
        ELSE 0
      END AS has_complete_tarsal_pair,
      (
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), ''))
               NOT IN ('X', 'M') THEN 1 ELSE 0
        END +
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), ''))
               NOT IN ('X', 'M') THEN 1 ELSE 0
        END +
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), ''))
               NOT IN ('X', 'M') THEN 1 ELSE 0
        END +
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), ''))
               NOT IN ('X', 'M') THEN 1 ELSE 0
        END
      ) AS non_x_non_m_count,
      (
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), ''))
               REGEXP '^[OYWBRGL]$' THEN 1 ELSE 0
        END +
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), ''))
               REGEXP '^[OYWBRGL]$' THEN 1 ELSE 0
        END +
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), ''))
               REGEXP '^[OYWBRGL]$' THEN 1 ELSE 0
        END +
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), ''))
               REGEXP '^[OYWBRGL]$' THEN 1 ELSE 0
        END
      ) AS plain_colour_count,
      (
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')) = 'M'
          THEN 1 ELSE 0
        END +
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')) = 'M'
          THEN 1 ELSE 0
        END +
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')) = 'M'
          THEN 1 ELSE 0
        END +
        CASE
          WHEN COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')) = 'M'
          THEN 1 ELSE 0
        END
      ) AS metal_count
    FROM FIELD_2026_BADOatNZ.CAPTURES c
    CROSS JOIN sr
    WHERE c.nest_id IS NOT NULL
      AND TRIM(c.nest_id) <> ''
      AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
      AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
      AND c.age = 'A'
      AND c.field_sex IN ('M', 'MU', 'F', 'FU')
      AND c.date <= sr.reference_date
  ) x
),
adult_capture_timing AS (
  SELECT
    c.nest_id,
    MAX(
      CASE
        WHEN LEFT(c.field_sex, 1) = 'M'
        THEN CAST(
          CONCAT(
            c.date,
            ' ',
            COALESCE(c.released, c.caught, '00:00:00')
          ) AS DATETIME
        )
      END
    ) AS M_last_capture_datetime,
    MAX(
      CASE
        WHEN LEFT(c.field_sex, 1) = 'F'
        THEN CAST(
          CONCAT(
            c.date,
            ' ',
            COALESCE(c.released, c.caught, '00:00:00')
          ) AS DATETIME
        )
      END
    ) AS F_last_capture_datetime,
    MAX(
      CAST(
        CONCAT(
          c.date,
          ' ',
          COALESCE(c.released, c.caught, '00:00:00')
        ) AS DATETIME
      )
    ) AS last_any_adult_capture_datetime
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age = 'A'
    AND c.field_sex IN ('M', 'MU', 'F', 'FU', 'U')
    AND c.date <= sr.reference_date
  GROUP BY c.nest_id
),
adult_resighting_latest AS (
  SELECT
    x.nest_id,
    x.sex,
    x.obs_date,
    x.pk AS event_pk,
    x.LL_obs,
    x.LR_obs,
    x.mark,
    x.is_confirmed_xx,
    x.has_geo,
    x.is_au_migrant,
    x.has_complete_tarsal_pair
  FROM (
    SELECT
      z.*,
      ROW_NUMBER() OVER (
        PARTITION BY z.nest_id, z.sex
        ORDER BY
          CASE
            WHEN (z.latest_UL_obs IS NULL OR z.UL_obs IS NULL
                  OR z.latest_UL_obs = z.UL_obs)
             AND (z.latest_LL_obs IS NULL OR z.LL_obs IS NULL
                  OR z.latest_LL_obs = z.LL_obs)
             AND (z.latest_UR_obs IS NULL OR z.UR_obs IS NULL
                  OR z.latest_UR_obs = z.UR_obs)
             AND (z.latest_LR_obs IS NULL OR z.LR_obs IS NULL
                  OR z.latest_LR_obs = z.LR_obs)
            THEN 1
            ELSE 0
          END DESC,
          z.has_informative_band_obs DESC,
          z.has_complete_tarsal_pair DESC,
          z.has_geo DESC,
          z.observed_segment_count DESC,
          z.obs_date DESC,
          z.pk DESC
      ) AS row_num
    FROM (
      SELECT
        y.*,
        FIRST_VALUE(y.UL_obs) OVER (
          PARTITION BY y.nest_id, y.sex
          ORDER BY y.obs_date DESC, y.pk DESC
        ) AS latest_UL_obs,
        FIRST_VALUE(y.LL_obs) OVER (
          PARTITION BY y.nest_id, y.sex
          ORDER BY y.obs_date DESC, y.pk DESC
        ) AS latest_LL_obs,
        FIRST_VALUE(y.UR_obs) OVER (
          PARTITION BY y.nest_id, y.sex
          ORDER BY y.obs_date DESC, y.pk DESC
        ) AS latest_UR_obs,
        FIRST_VALUE(y.LR_obs) OVER (
          PARTITION BY y.nest_id, y.sex
          ORDER BY y.obs_date DESC, y.pk DESC
        ) AS latest_LR_obs
      FROM (
        SELECT
          raw.nest_id,
          raw.sex,
          raw.obs_date,
          raw.pk,
          raw.UL_obs,
          raw.LL_obs,
          raw.UR_obs,
          raw.LR_obs,
        CASE
          WHEN raw.LL_obs = 'X' AND raw.LR_obs = 'X'
          THEN 'X-X'
          WHEN (raw.UL_obs IS NOT NULL AND raw.UL_obs NOT REGEXP '^(X|M)$')
            OR (raw.LL_obs IS NOT NULL AND raw.LL_obs NOT REGEXP '^(X|M)$')
            OR (raw.UR_obs IS NOT NULL AND raw.UR_obs NOT REGEXP '^(X|M)$')
            OR (raw.LR_obs IS NOT NULL AND raw.LR_obs NOT REGEXP '^(X|M)$')
          THEN FIELD_2026_BADOatNZ.format_mark(
            raw.UL_obs,
            raw.LL_obs,
            raw.UR_obs,
            raw.LR_obs
          )
          ELSE NULL
        END AS mark,
        CASE
          WHEN raw.LL_obs = 'X' AND raw.LR_obs = 'X'
          THEN 1
          ELSE 0
        END AS is_confirmed_xx,
        CASE
          WHEN raw.LL_obs = 'X' AND raw.LR_obs = 'X'
          THEN 1
          WHEN raw.UL_obs IS NOT NULL AND raw.UL_obs NOT REGEXP '^(X|M)$' THEN 1
          WHEN raw.LL_obs IS NOT NULL AND raw.LL_obs NOT REGEXP '^(X|M)$' THEN 1
          WHEN raw.UR_obs IS NOT NULL AND raw.UR_obs NOT REGEXP '^(X|M)$' THEN 1
          WHEN raw.LR_obs IS NOT NULL AND raw.LR_obs NOT REGEXP '^(X|M)$' THEN 1
          ELSE 0
        END AS has_informative_band_obs,
        CASE
          WHEN COALESCE(raw.UL_obs, '') REGEXP '^T[A-Z0-9]*$'
            OR COALESCE(raw.UR_obs, '') REGEXP '^T[A-Z0-9]*$'
          THEN 1
          ELSE 0
        END AS has_geo,
        CASE
          WHEN LEFT(COALESCE(raw.UL_obs, ''), 2) = 'FO'
            OR LEFT(COALESCE(raw.UR_obs, ''), 2) = 'FO'
          THEN 1
          ELSE 0
        END AS is_au_migrant,
        CASE
          WHEN raw.LL_obs IS NOT NULL AND raw.LR_obs IS NOT NULL THEN 1
          ELSE 0
        END AS has_complete_tarsal_pair,
        (
          CASE WHEN raw.UL_obs IS NOT NULL THEN 1 ELSE 0 END +
          CASE WHEN raw.LL_obs IS NOT NULL THEN 1 ELSE 0 END +
          CASE WHEN raw.UR_obs IS NOT NULL THEN 1 ELSE 0 END +
          CASE WHEN raw.LR_obs IS NOT NULL THEN 1 ELSE 0 END
        ) AS observed_segment_count
        FROM (
          SELECT
            r.nest_id,
            LEFT(r.sex, 1) AS sex,
            r.date AS obs_date,
            r.pk,
            CASE
              WHEN UPPER(NULLIF(TRIM(r.UL), '')) IN ('X', 'XX') THEN 'X'
              ELSE UPPER(NULLIF(TRIM(r.UL), ''))
            END AS UL_obs,
            CASE
              WHEN UPPER(NULLIF(TRIM(r.LL), '')) IN ('X', 'XX') THEN 'X'
              ELSE UPPER(NULLIF(TRIM(r.LL), ''))
            END AS LL_obs,
            CASE
              WHEN UPPER(NULLIF(TRIM(r.UR), '')) IN ('X', 'XX') THEN 'X'
              ELSE UPPER(NULLIF(TRIM(r.UR), ''))
            END AS UR_obs,
            CASE
              WHEN UPPER(NULLIF(TRIM(r.LR), '')) IN ('X', 'XX') THEN 'X'
              ELSE UPPER(NULLIF(TRIM(r.LR), ''))
            END AS LR_obs
          FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
          CROSS JOIN sr
          WHERE r.nest_id IS NOT NULL
            AND TRIM(r.nest_id) <> ''
            AND UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
            AND r.age = 'A'
            AND r.sex IN ('M', 'MU', 'F', 'FU')
            AND r.date <= sr.reference_date
        ) raw
      ) y
    ) z
  ) x
  WHERE x.row_num = 1
),
adult_parent_identity_latest AS (
  SELECT
    ranked.nest_id,
    ranked.sex,
    ranked.mark,
    ranked.is_confirmed_xx,
    ranked.has_geo,
    ranked.is_au_migrant,
    ranked.is_dead,
    ranked.is_single_colour_recruit
  FROM (
    SELECT
      events.*,
      ROW_NUMBER() OVER (
        PARTITION BY events.nest_id, events.sex
        ORDER BY
          events.is_dead DESC,
          events.tag_segment_rank DESC,
          events.complete_tarsal_rank DESC,
          events.direct_nest_capture_rank DESC,
          events.source_rank DESC,
          events.event_date DESC,
          events.event_datetime DESC,
          events.event_pk DESC
      ) AS row_num
    FROM (
      SELECT
        nest_id,
        sex,
        capture_date AS event_date,
        capture_datetime AS event_datetime,
        event_pk,
        1 AS source_rank,
        CASE
          WHEN UPPER(TRIM(COALESCE(capture_method, ''))) = 'TN' THEN 1
          ELSE 0
        END AS direct_nest_capture_rank,
        has_complete_tarsal_pair AS complete_tarsal_rank,
        CASE
          WHEN has_geo = 1
            OR UPPER(TRIM(mark))
               REGEXP '(^|[.-])T[A-Z0-9]*($|[.-])'
          THEN 1
          ELSE 0
        END AS tag_segment_rank,
        mark,
        is_confirmed_xx,
        has_geo,
        is_au_migrant,
        is_dead,
        is_single_colour_recruit
      FROM adult_capture_events
      WHERE mark IS NOT NULL

      UNION ALL

      SELECT
        nest_id,
        sex,
        obs_date AS event_date,
        CAST(CONCAT(obs_date, ' 00:00:00') AS DATETIME) AS event_datetime,
        event_pk,
        0 AS source_rank,
        0 AS direct_nest_capture_rank,
        has_complete_tarsal_pair AS complete_tarsal_rank,
        CASE
          WHEN has_geo = 1
            OR UPPER(TRIM(mark))
               REGEXP '(^|[.-])T[A-Z0-9]*($|[.-])'
          THEN 1
          ELSE 0
        END AS tag_segment_rank,
        mark,
        is_confirmed_xx,
        has_geo,
        is_au_migrant,
        0 AS is_dead,
        0 AS is_single_colour_recruit
      FROM adult_resighting_latest resighting
      WHERE resighting.mark IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM FIELD_2026_BADOatNZ.CAPTURES captured_other
          CROSS JOIN sr
          WHERE captured_other.nest_id = resighting.nest_id
            AND LEFT(captured_other.field_sex, 1) <> resighting.sex
            AND captured_other.age = 'A'
            AND UPPER(TRIM(COALESCE(captured_other.site, ''))) = 'CR'
            AND captured_other.date <= sr.reference_date
            AND resighting.LL_obs IS NOT NULL
            AND resighting.LR_obs IS NOT NULL
            AND CASE
              WHEN UPPER(COALESCE(
                NULLIF(TRIM(captured_other.LL), ''),
                NULLIF(TRIM(captured_other.LL_in), '')
              )) IN ('X', 'XX') THEN 'X'
              ELSE UPPER(COALESCE(
                NULLIF(TRIM(captured_other.LL), ''),
                NULLIF(TRIM(captured_other.LL_in), '')
              ))
            END = resighting.LL_obs
            AND CASE
              WHEN UPPER(COALESCE(
                NULLIF(TRIM(captured_other.LR), ''),
                NULLIF(TRIM(captured_other.LR_in), '')
              )) IN ('X', 'XX') THEN 'X'
              ELSE UPPER(COALESCE(
                NULLIF(TRIM(captured_other.LR), ''),
                NULLIF(TRIM(captured_other.LR_in), '')
              ))
            END = resighting.LR_obs
        )
    ) events
  ) ranked
  WHERE ranked.row_num = 1
),
adult_parent_identity_status AS (
  SELECT
    nest_id,
    MAX(CASE WHEN sex = 'M' THEN mark END) AS M_identity_mark,
    MAX(CASE WHEN sex = 'F' THEN mark END) AS F_identity_mark,
    MAX(CASE WHEN sex = 'M' THEN is_confirmed_xx END) AS M_identity_confirmed_xx,
    MAX(CASE WHEN sex = 'F' THEN is_confirmed_xx END) AS F_identity_confirmed_xx,
    MAX(CASE WHEN sex = 'M' THEN has_geo END) AS M_identity_has_geo,
    MAX(CASE WHEN sex = 'F' THEN has_geo END) AS F_identity_has_geo,
    MAX(CASE WHEN sex = 'M' THEN is_au_migrant END) AS M_identity_is_au_migrant,
    MAX(CASE WHEN sex = 'F' THEN is_au_migrant END) AS F_identity_is_au_migrant,
    MAX(CASE WHEN sex = 'M' THEN is_dead END) AS M_identity_is_dead,
    MAX(CASE WHEN sex = 'F' THEN is_dead END) AS F_identity_is_dead,
    MAX(CASE WHEN sex = 'M' THEN is_single_colour_recruit END)
      AS M_identity_single_colour_recruit,
    MAX(CASE WHEN sex = 'F' THEN is_single_colour_recruit END)
      AS F_identity_single_colour_recruit
  FROM adult_parent_identity_latest
  GROUP BY nest_id
),
adult_mm_capture_latest AS (
  SELECT
    ranked.nest_id,
    ranked.sex,
    ranked.capture_date AS mm_capture_date,
    ranked.capture_datetime AS mm_capture_datetime,
    ranked.mark,
    ranked.LL_norm,
    ranked.LR_norm,
    CASE
      -- These four legacy birds were released with one LR band, so the
      -- spacer colour remains part of their unique identifying combination.
      WHEN UPPER(TRIM(COALESCE(ranked.ring, ''))) IN (
        'CP19738',
        'CP19739',
        'CP19693',
        'CP19848'
      )
      THEN 1
      ELSE 0
    END AS requires_spacer_identity
  FROM (
    SELECT
      events.*,
      ROW_NUMBER() OVER (
        PARTITION BY events.nest_id, events.sex
        ORDER BY events.capture_date DESC, events.capture_datetime DESC,
          events.event_pk DESC
      ) AS mm_row_num
    FROM adult_capture_events events
    WHERE UPPER(TRIM(COALESCE(events.capture_method, ''))) = 'MM'
  ) ranked
  WHERE ranked.mm_row_num = 1
),
adult_association_resighting_candidates AS (
  SELECT
    r.nest_id,
    LEFT(r.sex, 1) AS sex,
    r.date AS association_date,
    r.pk,
    CASE
      WHEN UPPER(NULLIF(TRIM(r.LL), '')) IN ('X', 'XX') THEN 'X'
      ELSE UPPER(NULLIF(TRIM(r.LL), ''))
    END AS LL_obs,
    CASE
      WHEN UPPER(NULLIF(TRIM(r.LR), '')) IN ('X', 'XX') THEN 'X'
      ELSE UPPER(NULLIF(TRIM(r.LR), ''))
    END AS LR_obs,
    CASE
      WHEN UPPER(TRIM(r.LL)) IN ('X', 'XX')
       AND UPPER(TRIM(r.LR)) IN ('X', 'XX')
      THEN 'X-X'
      WHEN (NULLIF(TRIM(r.UL), '') IS NOT NULL AND UPPER(TRIM(r.UL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(r.LL), '') IS NOT NULL AND UPPER(TRIM(r.LL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(r.UR), '') IS NOT NULL AND UPPER(TRIM(r.UR)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(r.LR), '') IS NOT NULL AND UPPER(TRIM(r.LR)) NOT REGEXP '^(X+|M)$')
      THEN FIELD_2026_BADOatNZ.format_mark(
        NULLIF(TRIM(r.UL), ''),
        NULLIF(TRIM(r.LL), ''),
        NULLIF(TRIM(r.UR), ''),
        NULLIF(TRIM(r.LR), '')
      )
      ELSE NULL
    END AS mark,
    CASE
      WHEN UPPER(TRIM(r.LL)) IN ('X', 'XX')
       AND UPPER(TRIM(r.LR)) IN ('X', 'XX')
      THEN 1
      ELSE 0
    END AS is_confirmed_xx,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.UL, ''))) REGEXP '^T[A-Z0-9]*$'
        OR UPPER(TRIM(COALESCE(r.UR, ''))) REGEXP '^T[A-Z0-9]*$'
      THEN 1
      ELSE 0
    END AS has_geo,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.behav, ''))) REGEXP
        '(^|[^A-Z])(BW|NM|IN)([^A-Z]|$)'
      THEN 1
      ELSE 0
    END AS has_matching_nest_behav,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.behav, ''))) REGEXP
        '(^|[^A-Z])(BW|NM|IN)([^A-Z]|$)'
      THEN 1
      ELSE 0
    END AS has_nest_behav
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE r.nest_id IS NOT NULL
    AND TRIM(r.nest_id) <> ''
    AND UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'A'
    AND r.sex IN ('M', 'MU', 'F', 'FU')
    AND r.date <= sr.reference_date
    AND (
      (
        UPPER(TRIM(r.LL)) IN ('X', 'XX')
        AND UPPER(TRIM(r.LR)) IN ('X', 'XX')
      )
      OR (NULLIF(TRIM(r.UL), '') IS NOT NULL AND UPPER(TRIM(r.UL)) NOT REGEXP '^(X+|M)$')
      OR (NULLIF(TRIM(r.LL), '') IS NOT NULL AND UPPER(TRIM(r.LL)) NOT REGEXP '^(X+|M)$')
      OR (NULLIF(TRIM(r.UR), '') IS NOT NULL AND UPPER(TRIM(r.UR)) NOT REGEXP '^(X+|M)$')
      OR (NULLIF(TRIM(r.LR), '') IS NOT NULL AND UPPER(TRIM(r.LR)) NOT REGEXP '^(X+|M)$')
    )
),
adult_mm_post_resighting_matched AS (
  SELECT
    mm.nest_id,
    mm.sex,
    association.mark,
    association.is_confirmed_xx,
    association.has_geo,
    association.association_date,
    association.pk,
    association.has_matching_nest_behav,
    association.has_nest_behav,
    CASE
      WHEN (
        mm.requires_spacer_identity = 1
        AND UPPER(TRIM(association.mark)) = UPPER(TRIM(mm.mark))
      )
      OR (
        mm.requires_spacer_identity = 0
        AND mm.LL_norm IS NOT NULL
        AND mm.LR_norm IS NOT NULL
        AND association.LL_obs IS NOT NULL
        AND association.LR_obs IS NOT NULL
        AND association.LL_obs = mm.LL_norm
        AND association.LR_obs = mm.LR_norm
      )
      THEN 1
      ELSE 0
    END AS identity_match
  FROM adult_mm_capture_latest mm
  JOIN adult_association_resighting_candidates association
    ON mm.nest_id = association.nest_id
   AND mm.sex = association.sex
   AND association.association_date >= mm.mm_capture_date
),
adult_mm_post_resighting_ranked AS (
  SELECT
    matched.nest_id,
    matched.sex,
    matched.mark,
    matched.is_confirmed_xx,
    matched.has_geo,
    matched.association_date,
    matched.pk,
    CASE
      WHEN matched.identity_match = 1 THEN 1
      ELSE 0
    END AS identity_match,
    SUM(
      CASE
        WHEN matched.identity_match = 1 THEN 1
        ELSE 0
      END
    ) OVER (
      PARTITION BY matched.nest_id, matched.sex
    ) AS n_matching_post_mm_resightings,
    MAX(
      CASE
        WHEN matched.identity_match = 1
         AND matched.has_matching_nest_behav = 1
        THEN 1
        ELSE 0
      END
    ) OVER (
      PARTITION BY matched.nest_id, matched.sex
    ) AS has_matching_nest_behav,
    MAX(
      CASE
        WHEN matched.is_confirmed_xx = 1
         AND matched.has_nest_behav = 1
        THEN 1
        ELSE 0
      END
    ) OVER (
      PARTITION BY matched.nest_id, matched.sex
    ) AS has_xx_nest_behav,
    MAX(
      CASE
        WHEN matched.is_confirmed_xx = 1
         AND matched.has_nest_behav = 1
        THEN matched.association_date
        ELSE NULL
      END
    ) OVER (
      PARTITION BY matched.nest_id, matched.sex
    ) AS xx_nest_behav_date,
    MAX(
      CASE
        WHEN matched.identity_match = 1
        THEN matched.association_date
        ELSE NULL
      END
    ) OVER (
      PARTITION BY matched.nest_id, matched.sex
    ) AS matching_post_mm_resight_date,
    MAX(
      CASE
        WHEN matched.is_confirmed_xx = 1 THEN 1
        ELSE 0
      END
    ) OVER (
      PARTITION BY matched.nest_id, matched.sex
    ) AS post_mm_xx_seen,
    ROW_NUMBER() OVER (
      PARTITION BY matched.nest_id, matched.sex
      ORDER BY
        CASE
          WHEN matched.identity_match = 1 THEN 1
          ELSE 0
        END DESC,
        matched.association_date DESC,
        matched.pk DESC
      ) AS row_num
  FROM adult_mm_post_resighting_matched matched
),
adult_mm_followup_status AS (
  SELECT
    mm.nest_id,
    MAX(
      CASE
        WHEN mm.sex = 'M'
         AND (
           COALESCE(followup.n_matching_post_mm_resightings, 0) = 0
           AND COALESCE(followup.has_xx_nest_behav, 0) = 0
           OR (
             COALESCE(followup.has_matching_nest_behav, 0) = 0
             AND COALESCE(followup.has_xx_nest_behav, 0) = 0
             AND COALESCE(followup.n_matching_post_mm_resightings, 0) < 3
           )
         )
        THEN 1
        ELSE 0
      END
    )
      AS M_mm_resight_pending,
    MAX(
      CASE
        WHEN mm.sex = 'F'
         AND (
           COALESCE(followup.n_matching_post_mm_resightings, 0) = 0
           AND COALESCE(followup.has_xx_nest_behav, 0) = 0
           OR (
             COALESCE(followup.has_matching_nest_behav, 0) = 0
             AND COALESCE(followup.has_xx_nest_behav, 0) = 0
             AND COALESCE(followup.n_matching_post_mm_resightings, 0) < 3
           )
         )
        THEN 1
        ELSE 0
      END
    )
      AS F_mm_resight_pending,
    MAX(
      CASE
        WHEN mm.sex = 'M'
        AND COALESCE(followup.n_matching_post_mm_resightings, 0) >= 1
        AND (
          COALESCE(followup.has_matching_nest_behav, 0) = 1
          OR COALESCE(followup.n_matching_post_mm_resightings, 0) >= 3
        )
        THEN 1
        ELSE 0
      END
    )
      AS M_mm_followup_found,
    MAX(
      CASE
        WHEN mm.sex = 'F'
        AND COALESCE(followup.n_matching_post_mm_resightings, 0) >= 1
        AND (
          COALESCE(followup.has_matching_nest_behav, 0) = 1
          OR COALESCE(followup.n_matching_post_mm_resightings, 0) >= 3
        )
        THEN 1
        ELSE 0
      END
    )
      AS F_mm_followup_found,
    MAX(CASE WHEN mm.sex = 'M' THEN followup.mark END) AS M_mm_followup_mark,
    MAX(CASE WHEN mm.sex = 'F' THEN followup.mark END) AS F_mm_followup_mark,
    MAX(CASE WHEN mm.sex = 'M' THEN followup.is_confirmed_xx END)
      AS M_mm_followup_confirmed_xx,
    MAX(CASE WHEN mm.sex = 'F' THEN followup.is_confirmed_xx END)
      AS F_mm_followup_confirmed_xx,
    MAX(CASE WHEN mm.sex = 'M' THEN followup.has_geo END) AS M_mm_followup_has_geo,
    MAX(CASE WHEN mm.sex = 'F' THEN followup.has_geo END) AS F_mm_followup_has_geo,
    MAX(
      CASE
        WHEN mm.sex = 'M'
         AND followup.has_xx_nest_behav = 1
         AND NOT EXISTS (
           SELECT 1
           FROM adult_capture_events later_capture
           WHERE later_capture.nest_id = mm.nest_id
             AND later_capture.sex = mm.sex
             AND later_capture.mark IS NOT NULL
             AND later_capture.mark <> 'X-X'
             AND LOWER(TRIM(later_capture.mark)) <> 'dead'
             AND later_capture.capture_date >= followup.xx_nest_behav_date
           )
         AND (
           followup.matching_post_mm_resight_date IS NULL
           OR followup.matching_post_mm_resight_date
              <= followup.xx_nest_behav_date
          )
        THEN 1
        ELSE 0
      END
    ) AS M_mm_xx_parent_confirmed,
    MAX(
      CASE
        WHEN mm.sex = 'F'
         AND followup.has_xx_nest_behav = 1
         AND NOT EXISTS (
           SELECT 1
           FROM adult_capture_events later_capture
           WHERE later_capture.nest_id = mm.nest_id
             AND later_capture.sex = mm.sex
             AND later_capture.mark IS NOT NULL
             AND later_capture.mark <> 'X-X'
             AND LOWER(TRIM(later_capture.mark)) <> 'dead'
             AND later_capture.capture_date >= followup.xx_nest_behav_date
           )
         AND (
           followup.matching_post_mm_resight_date IS NULL
           OR followup.matching_post_mm_resight_date
              <= followup.xx_nest_behav_date
          )
        THEN 1
        ELSE 0
      END
    ) AS F_mm_xx_parent_confirmed,
    MAX(CASE WHEN mm.sex = 'M' THEN mm.mark END) AS M_mm_capture_mark,
    MAX(CASE WHEN mm.sex = 'F' THEN mm.mark END) AS F_mm_capture_mark,
    MAX(
      CASE
        WHEN mm.sex = 'M'
         AND followup.post_mm_xx_seen = 1
         AND NOT (
           followup.has_xx_nest_behav = 1
           AND followup.matching_post_mm_resight_date IS NOT NULL
           AND followup.matching_post_mm_resight_date
               > followup.xx_nest_behav_date
         )
         AND mm.mark IS NOT NULL
         AND mm.mark <> 'X-X'
         AND LOWER(TRIM(mm.mark)) <> 'dead'
        THEN 1
        ELSE 0
      END
    ) AS M_post_mm_xx_seen,
    MAX(
      CASE
        WHEN mm.sex = 'F'
         AND followup.post_mm_xx_seen = 1
         AND NOT (
           followup.has_xx_nest_behav = 1
           AND followup.matching_post_mm_resight_date IS NOT NULL
           AND followup.matching_post_mm_resight_date
               > followup.xx_nest_behav_date
         )
         AND mm.mark IS NOT NULL
         AND mm.mark <> 'X-X'
         AND LOWER(TRIM(mm.mark)) <> 'dead'
        THEN 1
        ELSE 0
      END
    ) AS F_post_mm_xx_seen
  FROM adult_mm_capture_latest mm
  LEFT JOIN adult_mm_post_resighting_ranked followup
    ON mm.nest_id = followup.nest_id
   AND mm.sex = followup.sex
   AND followup.row_num = 1
  GROUP BY mm.nest_id
),
scrape_parent_identity AS (
  SELECT
    r.nest_id,
    MAX(
      CASE
        WHEN LEFT(r.sex, 1) = 'M'
         AND (
           (
             NULLIF(TRIM(r.LL), '') IS NOT NULL
             AND UPPER(TRIM(r.LL)) NOT REGEXP '^(X+|M)$'
           )
           OR (
             NULLIF(TRIM(r.LR), '') IS NOT NULL
             AND UPPER(TRIM(r.LR)) NOT REGEXP '^(X+|M)$'
           )
         )
        THEN 1
        ELSE 0
      END
    ) AS M_has_unique_scrape_resight,
    MAX(
      CASE
        WHEN LEFT(r.sex, 1) = 'F'
         AND (
           (
             NULLIF(TRIM(r.LL), '') IS NOT NULL
             AND UPPER(TRIM(r.LL)) NOT REGEXP '^(X+|M)$'
           )
           OR (
             NULLIF(TRIM(r.LR), '') IS NOT NULL
             AND UPPER(TRIM(r.LR)) NOT REGEXP '^(X+|M)$'
           )
         )
        THEN 1
        ELSE 0
      END
    ) AS F_has_unique_scrape_resight
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE r.nest_id IS NOT NULL
    AND TRIM(r.nest_id) <> ''
    AND UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'A'
    AND r.sex IN ('M', 'MU', 'F', 'FU')
    AND r.date <= sr.reference_date
  GROUP BY r.nest_id
),
todo_parent_source AS (
  SELECT
    latest_nests.nest_id,
    CAST(NULL AS CHAR(50)) AS M_mark,
    CAST(NULL AS CHAR(50)) AS F_mark
  FROM latest_nests
  UNION ALL
  SELECT
    b.nest_id,
    CAST(NULL AS CHAR(50)) AS M_mark,
    CAST(NULL AS CHAR(50)) AS F_mark
  FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
  CROSS JOIN sr
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
),
adult_parent_status AS (
  SELECT
    todo_parent_source.nest_id,
    CASE
      WHEN COALESCE(
             adult_mm_followup_status.M_mm_xx_parent_confirmed,
             0
           ) = 1
      THEN 'X-X'
      WHEN COALESCE(adult_mm_followup_status.M_mm_resight_pending, 0) = 1
       AND adult_mm_followup_status.M_mm_capture_mark IS NOT NULL
      THEN CASE
        WHEN COALESCE(adult_mm_followup_status.M_post_mm_xx_seen, 0) = 1
        THEN CONCAT(adult_mm_followup_status.M_mm_capture_mark, ' & X-X')
        ELSE adult_mm_followup_status.M_mm_capture_mark
      END
      WHEN COALESCE(
        adult_parent_identity_status.M_identity_mark,
        todo_parent_source.M_mark
      ) IS NULL
      THEN NULL
      WHEN REPLACE(
        REPLACE(
          REPLACE(
            UPPER(
              TRIM(
                COALESCE(
                  adult_parent_identity_status.M_identity_mark,
                  todo_parent_source.M_mark,
                  ''
                )
              )
            ),
            'X',
            ''
          ),
          '.',
          ''
        ),
        '-',
        ''
      ) = ''
      THEN 'X-X'
      ELSE COALESCE(
        adult_parent_identity_status.M_identity_mark,
        todo_parent_source.M_mark
      )
    END AS M_parent_mark,
    CASE
      WHEN COALESCE(
             adult_mm_followup_status.F_mm_xx_parent_confirmed,
             0
           ) = 1
      THEN 'X-X'
      WHEN COALESCE(adult_mm_followup_status.F_mm_resight_pending, 0) = 1
       AND adult_mm_followup_status.F_mm_capture_mark IS NOT NULL
      THEN CASE
        WHEN COALESCE(adult_mm_followup_status.F_post_mm_xx_seen, 0) = 1
        THEN CONCAT(adult_mm_followup_status.F_mm_capture_mark, ' & X-X')
        ELSE adult_mm_followup_status.F_mm_capture_mark
      END
      WHEN COALESCE(
        adult_parent_identity_status.F_identity_mark,
        todo_parent_source.F_mark
      ) IS NULL
      THEN NULL
      WHEN REPLACE(
        REPLACE(
          REPLACE(
            UPPER(
              TRIM(
                COALESCE(
                  adult_parent_identity_status.F_identity_mark,
                  todo_parent_source.F_mark,
                  ''
                )
              )
            ),
            'X',
            ''
          ),
          '.',
          ''
        ),
        '-',
        ''
      ) = ''
      THEN 'X-X'
      ELSE COALESCE(
        adult_parent_identity_status.F_identity_mark,
        todo_parent_source.F_mark
      )
    END AS F_parent_mark,
    CASE
      WHEN COALESCE(adult_mm_followup_status.M_mm_xx_parent_confirmed, 0) = 1
      THEN 0
      WHEN COALESCE(adult_mm_followup_status.M_mm_resight_pending, 0) = 1
      THEN 0
      ELSE COALESCE(adult_parent_identity_status.M_identity_has_geo, 0)
    END AS M_has_geo,
    CASE
      WHEN COALESCE(adult_mm_followup_status.F_mm_xx_parent_confirmed, 0) = 1
      THEN 0
      WHEN COALESCE(adult_mm_followup_status.F_mm_resight_pending, 0) = 1
      THEN 0
      ELSE COALESCE(adult_parent_identity_status.F_identity_has_geo, 0)
    END AS F_has_geo,
    -- Preserve captured GEO evidence only while that capture remains the
    -- resolved parent identity used for pair-completion decisions.
    CASE
      WHEN COALESCE(adult_mm_followup_status.M_mm_xx_parent_confirmed, 0) = 1
      THEN 0
      ELSE COALESCE(adult_parent_identity_status.M_identity_has_geo, 0)
    END
      AS M_captured_has_geo,
    CASE
      WHEN COALESCE(adult_mm_followup_status.F_mm_xx_parent_confirmed, 0) = 1
      THEN 0
      ELSE COALESCE(adult_parent_identity_status.F_identity_has_geo, 0)
    END
      AS F_captured_has_geo,
    CASE
      WHEN COALESCE(adult_mm_followup_status.M_mm_resight_pending, 0) = 1
      THEN 0
      ELSE COALESCE(
        adult_parent_identity_status.M_identity_single_colour_recruit,
        0
      )
    END AS M_single_colour_recruit,
    CASE
      WHEN COALESCE(adult_mm_followup_status.F_mm_resight_pending, 0) = 1
      THEN 0
      ELSE COALESCE(
        adult_parent_identity_status.F_identity_single_colour_recruit,
        0
      )
    END AS F_single_colour_recruit,
    CASE
      WHEN COALESCE(
             adult_mm_followup_status.M_mm_xx_parent_confirmed,
             0
           ) = 1
      THEN 1
      WHEN COALESCE(adult_mm_followup_status.M_mm_resight_pending, 0) = 1
      THEN 0
      ELSE COALESCE(adult_parent_identity_status.M_identity_confirmed_xx, 0)
    END AS M_confirmed_unbanded,
    CASE
      WHEN COALESCE(
             adult_mm_followup_status.F_mm_xx_parent_confirmed,
             0
           ) = 1
      THEN 1
      WHEN COALESCE(adult_mm_followup_status.F_mm_resight_pending, 0) = 1
      THEN 0
      ELSE COALESCE(adult_parent_identity_status.F_identity_confirmed_xx, 0)
    END AS F_confirmed_unbanded,
    CASE
      -- MM association uncertainty is handled by the resighting task below;
      -- it must not make this sex a capture candidate.
      WHEN COALESCE(adult_mm_followup_status.M_mm_resight_pending, 0) = 1
      THEN 0
      WHEN COALESCE(
             adult_parent_identity_status.M_identity_mark,
             todo_parent_source.M_mark
           ) IS NULL
      THEN 1
      ELSE 0
    END AS M_unknown_status,
    CASE
      -- Keep MM follow-up separate from ordinary unknown-status capture work.
      WHEN COALESCE(adult_mm_followup_status.F_mm_resight_pending, 0) = 1
      THEN 0
      WHEN COALESCE(
             adult_parent_identity_status.F_identity_mark,
             todo_parent_source.F_mark
           ) IS NULL
      THEN 1
      ELSE 0
    END AS F_unknown_status,
    COALESCE(adult_parent_identity_status.M_identity_is_au_migrant, 0)
      AS M_is_au_migrant,
    COALESCE(adult_parent_identity_status.F_identity_is_au_migrant, 0)
      AS F_is_au_migrant,
    COALESCE(adult_parent_identity_status.M_identity_is_dead, 0)
      AS M_is_dead,
    COALESCE(adult_parent_identity_status.F_identity_is_dead, 0)
      AS F_is_dead,
    -- A later live X-X resighting with qualifying nest behaviour can replace
    -- the dead identity from an earlier uncertain MM capture for GEO work.
    COALESCE(adult_mm_followup_status.M_mm_xx_parent_confirmed, 0)
      AS M_mm_xx_parent_confirmed,
    COALESCE(adult_mm_followup_status.F_mm_xx_parent_confirmed, 0)
      AS F_mm_xx_parent_confirmed,
    COALESCE(adult_mm_followup_status.M_mm_resight_pending, 0) AS M_mm_resight_pending,
    COALESCE(adult_mm_followup_status.F_mm_resight_pending, 0) AS F_mm_resight_pending,
    COALESCE(adult_mm_followup_status.M_post_mm_xx_seen, 0) AS M_post_mm_xx_seen,
    COALESCE(adult_mm_followup_status.F_post_mm_xx_seen, 0) AS F_post_mm_xx_seen
  FROM todo_parent_source
  LEFT JOIN adult_parent_identity_status
    ON todo_parent_source.nest_id = adult_parent_identity_status.nest_id
  LEFT JOIN adult_mm_followup_status
    ON todo_parent_source.nest_id = adult_mm_followup_status.nest_id
),
adult_parent_geo_target_status AS (
  SELECT
    adult_parent_status.*,
    CASE
      WHEN geo_deployment_status.n_geo_deployed < 101
       AND adult_parent_status.M_parent_mark IS NOT NULL
       AND adult_parent_status.F_parent_mark IS NOT NULL
       AND COALESCE(adult_parent_status.M_confirmed_unbanded, 0) = 0
       AND COALESCE(adult_parent_status.F_confirmed_unbanded, 0) = 0
       AND COALESCE(adult_parent_status.M_unknown_status, 0) = 0
       AND COALESCE(adult_parent_status.F_unknown_status, 0) = 0
       AND COALESCE(adult_parent_status.M_has_geo, 0) = 0
       AND COALESCE(adult_parent_status.F_has_geo, 0) = 0
       AND COALESCE(adult_parent_status.M_is_au_migrant, 0) = 0
       AND COALESCE(adult_parent_status.F_is_au_migrant, 0) = 0
       AND COALESCE(adult_parent_status.M_is_dead, 0) = 0
       AND COALESCE(adult_parent_status.F_is_dead, 0) = 0
       AND COALESCE(adult_parent_status.M_single_colour_recruit, 0) = 0
       AND COALESCE(adult_parent_status.F_single_colour_recruit, 0) = 0
       AND COALESCE(adult_parent_status.M_mm_resight_pending, 0) = 0
       AND COALESCE(adult_parent_status.F_mm_resight_pending, 0) = 0
      THEN 1
      ELSE 0
    END AS both_parents_need_geo
  FROM adult_parent_status
  CROSS JOIN geo_deployment_status
),
adult_capture_interval_status AS (
  SELECT
    todo_parent_source.nest_id,
    adult_capture_timing.M_last_capture_datetime,
    adult_capture_timing.F_last_capture_datetime,
    adult_capture_timing.last_any_adult_capture_datetime,
    CASE
      WHEN adult_capture_timing.last_any_adult_capture_datetime IS NULL THEN 1
      ELSE 0
    END AS no_parent_capture_yet,
    CASE
      WHEN adult_capture_timing.last_any_adult_capture_datetime
           <= DATE_SUB(
                CAST(CONCAT(sr.reference_date, ' 08:00:00') AS DATETIME),
                INTERVAL 36 HOUR
              )
      THEN 1
      ELSE 0
    END AS any_target_capture_window_open,
    CASE
      WHEN adult_capture_timing.F_last_capture_datetime
           <= DATE_SUB(
                CAST(CONCAT(sr.reference_date, ' 08:00:00') AS DATETIME),
                INTERVAL 36 HOUR
              )
      THEN 1
      ELSE 0
    END AS M_target_capture_window_open,
    CASE
      WHEN adult_capture_timing.M_last_capture_datetime
           <= DATE_SUB(
                CAST(CONCAT(sr.reference_date, ' 08:00:00') AS DATETIME),
                INTERVAL 36 HOUR
              )
      THEN 1
      ELSE 0
    END AS F_target_capture_window_open
  FROM todo_parent_source
  CROSS JOIN sr
  LEFT JOIN adult_capture_timing
    ON todo_parent_source.nest_id = adult_capture_timing.nest_id
),
adult_capture_current_clutch AS (
  SELECT
    active_nests.nest_id,
    latest_clutch_history.clutch_size AS current_clutch_size,
    latest_clutch_history.clutch_datetime AS current_clutch_datetime
  FROM active_nests
  JOIN latest_clutch_history
    ON active_nests.nest_id = latest_clutch_history.nest_id
   AND latest_clutch_history.row_num = 1
  WHERE (
      UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) IN ('F', 'I', 'PP', 'PD')
      OR (
        active_nests.hatch_signs_present = 1
        AND active_nests.latest_float_date IS NULL
      )
    )
    AND latest_clutch_history.clutch_size IS NOT NULL
    AND latest_clutch_history.clutch_size > 0
),
adult_capture_last_other_clutch AS (
  SELECT
    current_clutch.nest_id,
    MAX(
      CAST(
        CONCAT(
          history.date,
          ' ',
          COALESCE(history.time_visit, '00:00:00')
        ) AS DATETIME
      )
    ) AS last_other_clutch_datetime
  FROM adult_capture_current_clutch current_clutch
  LEFT JOIN nest_history history
    ON current_clutch.nest_id = history.nest_id
   AND history.clutch_size IS NOT NULL
   AND history.clutch_size <> current_clutch.current_clutch_size
   AND CAST(
         CONCAT(
           history.date,
           ' ',
           COALESCE(history.time_visit, '00:00:00')
         ) AS DATETIME
       ) <= current_clutch.current_clutch_datetime
  GROUP BY current_clutch.nest_id
),
adult_capture_current_clutch_start AS (
  SELECT
    current_clutch.nest_id,
    current_clutch.current_clutch_size,
    current_clutch.current_clutch_datetime,
    MIN(
      CAST(
        CONCAT(
          history.date,
          ' ',
          COALESCE(history.time_visit, '00:00:00')
        ) AS DATETIME
      )
    ) AS current_clutch_start_datetime
  FROM adult_capture_current_clutch current_clutch
  JOIN nest_history history
    ON current_clutch.nest_id = history.nest_id
   AND history.clutch_size = current_clutch.current_clutch_size
   AND CAST(
         CONCAT(
           history.date,
           ' ',
           COALESCE(history.time_visit, '00:00:00')
         ) AS DATETIME
       ) <= current_clutch.current_clutch_datetime
  LEFT JOIN adult_capture_last_other_clutch last_other
    ON current_clutch.nest_id = last_other.nest_id
  WHERE last_other.last_other_clutch_datetime IS NULL
     OR CAST(
          CONCAT(
            history.date,
            ' ',
            COALESCE(history.time_visit, '00:00:00')
          ) AS DATETIME
        ) > last_other.last_other_clutch_datetime
  GROUP BY
    current_clutch.nest_id,
    current_clutch.current_clutch_size,
    current_clutch.current_clutch_datetime
),
adult_capture_age_status AS (
  SELECT
    x.nest_id,
    x.clutch_completion_basis_date,
    CASE
      WHEN x.clutch_completion_confirmed = 1 THEN 1
      WHEN x.current_clutch_size = 2
       AND DATEDIFF(
             sr.reference_date,
             DATE(x.current_clutch_datetime)
           ) >= 4
      THEN 1
      ELSE 0
    END AS clutch_completion_confirmed,
    CASE
      -- Hatch signs without a flotation date mean the nest is already in
      -- the hatching window, so do not block parent capture on the missing
      -- seven-day estimate. The 36-hour capture interval is applied later.
      WHEN latest_nests.hatch_signs_present = 1
       AND latest_nests.latest_float_date IS NULL
      THEN 1
      WHEN CASE
             WHEN x.uses_inferred_lay_interval = 1
             THEN DATEDIFF(
                    sr.reference_date,
                    x.clutch_completion_basis_date
                  )
             WHEN latest_nests.latest_float_date
                    >= DATE(x.current_clutch_start_datetime)
              AND latest_nests.average_ref_date_days_since_laid IS NOT NULL
             THEN latest_nests.average_ref_date_days_since_laid
             ELSE DATEDIFF(
                    sr.reference_date,
                    x.clutch_completion_basis_date
                  )
           END >= 7
      THEN 1
      ELSE 0
    END AS capture_allowed_after_completion
  FROM (
    SELECT
      clutch_start.nest_id,
      clutch_start.current_clutch_size,
      clutch_start.current_clutch_datetime,
      clutch_start.current_clutch_start_datetime,
      CASE
        WHEN initial_clutch_status.found_as_incomplete = 1
        THEN initial_clutch_status.inferred_clutch_completion_date
        WHEN clutch_start.current_clutch_size >= 3
          OR DATEDIFF(
               DATE(clutch_start.current_clutch_datetime),
               DATE(clutch_start.current_clutch_start_datetime)
             ) >= 3
        THEN DATE(clutch_start.current_clutch_start_datetime)
        ELSE DATE_ADD(
          DATE(clutch_start.current_clutch_datetime),
          INTERVAL (
            2 * GREATEST(0, 3 - clutch_start.current_clutch_size)
          ) DAY
        )
      END AS clutch_completion_basis_date,
      CASE
        WHEN initial_clutch_status.found_as_incomplete = 1 THEN 1
        ELSE 0
      END AS uses_inferred_lay_interval,
      CASE
        WHEN clutch_start.current_clutch_size >= 3 THEN 1
        WHEN DATEDIFF(
               DATE(clutch_start.current_clutch_datetime),
               DATE(clutch_start.current_clutch_start_datetime)
             ) >= 3
        THEN 1
        ELSE 0
      END AS clutch_completion_confirmed
    FROM adult_capture_current_clutch_start clutch_start
    LEFT JOIN initial_clutch_status
      ON clutch_start.nest_id = initial_clutch_status.nest_id
  ) x
  JOIN latest_nests
    ON x.nest_id = latest_nests.nest_id
  CROSS JOIN sr
  UNION ALL
  SELECT
    b.nest_id,
    CAST(NULL AS DATE) AS clutch_completion_basis_date,
    1 AS clutch_completion_confirmed,
    1 AS capture_allowed_after_completion
  FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
  CROSS JOIN sr
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
),
complete_clutch_processing_status AS (
  SELECT
    clutch_start.nest_id,
    MAX(
      CASE
        WHEN n.nest_photo = '1' OR n.tent_photo = '1' THEN 1
        ELSE 0
      END
    ) AS complete_clutch_has_photo,
    MAX(
      CASE
        WHEN latest_nests.hatch_signs_present = 1 THEN 1
        WHEN float_visit_summary.nest_id IS NOT NULL THEN 1
        ELSE 0
      END
    ) AS complete_clutch_has_float
  FROM adult_capture_current_clutch_start clutch_start
  LEFT JOIN latest_nests
    ON clutch_start.nest_id = latest_nests.nest_id
  LEFT JOIN nest_history n
    ON clutch_start.nest_id = n.nest_id
   AND n.clutch_size = clutch_start.current_clutch_size
   AND CAST(
         CONCAT(n.date, ' ', COALESCE(n.time_visit, '00:00:00'))
         AS DATETIME
       ) >= clutch_start.current_clutch_start_datetime
  LEFT JOIN float_visit_summary
    ON clutch_start.nest_id = float_visit_summary.nest_id
   AND float_visit_summary.float_datetime
       >= clutch_start.current_clutch_start_datetime
  GROUP BY clutch_start.nest_id
),
geo_parent_plan AS (
  SELECT
    ranked.nest_id,
    ranked.geo_rank,
    ranked.geo_priority_tier,
    ranked.global_sex_priority,
    ranked.geo_priority_score,
    ranked.geo_reason,
    ranked.geo_target,
    ranked.geo_is_actionable,
    ranked.n_geo_deployed,
    ranked.release_ceiling,
    GREATEST(
      0,
      ranked.release_ceiling - ranked.n_geo_deployed
    ) AS release_slots_remaining,
    ranked.n_male_geo_deployed,
    ranked.n_female_geo_deployed,
    ranked.male_quota_remaining,
    ranked.female_quota_remaining,
    ranked.preferred_balance_sex,
    -- Only identity-driven banding belongs in the non-tag target field.
    -- Sex/phenology rollout candidates remain paused unless they complete a
    -- GEO pair through pair_target.
    ranked.band_target AS geo_band_target,
    CASE
      WHEN ranked.geo_is_actionable = 1
       AND ranked.pair_target IS NOT NULL
      THEN ranked.geo_target
      ELSE NULL
    END AS geo_tag_target,
    CASE
      WHEN ranked.geo_is_actionable = 1
       AND ranked.pair_target IS NOT NULL
      THEN CONCAT(
        'tag ',
        CASE
          WHEN ranked.pair_target = 'M'
           AND ranked.M_parent_mark = 'X-X'
          THEN 'X-X M'
          WHEN ranked.pair_target = 'F'
           AND ranked.F_parent_mark = 'X-X'
          THEN 'X-X F'
          ELSE ranked.pair_target
        END,
        ' (pair completion',
        CASE
          WHEN (ranked.pair_target = 'M' AND ranked.M_parent_mark IS NULL)
            OR (ranked.pair_target = 'F' AND ranked.F_parent_mark IS NULL)
          THEN '; status ?'
          ELSE ''
        END,
        ')'
      )
      WHEN ranked.pair_target IS NULL
       AND ranked.band_target IS NOT NULL
      THEN CONCAT(
        'band ',
        CASE ranked.band_target WHEN 'A' THEN 'either' ELSE ranked.band_target END
      )
      WHEN ranked.pair_target IS NOT NULL
       AND ranked.is_candidate = 0
      THEN CONCAT(
        'resight ',
        CASE
          WHEN ranked.pair_target = 'M'
           AND ranked.M_parent_mark = 'X-X'
          THEN 'X-X M'
          WHEN ranked.pair_target = 'F'
           AND ranked.F_parent_mark = 'X-X'
          THEN 'X-X F'
          ELSE ranked.pair_target
        END,
        ' (pair completion',
        CASE
          WHEN (ranked.pair_target = 'M' AND ranked.M_parent_mark IS NULL)
            OR (ranked.pair_target = 'F' AND ranked.F_parent_mark IS NULL)
          THEN '; confirm identity/GEO'
          ELSE ''
        END,
        ')'
      )
      WHEN ranked.pair_target IS NOT NULL
       AND ranked.is_candidate = 1
      THEN CONCAT(
        'resight ',
        ranked.pair_target,
        ' (pair completion waitlist)'
      )
      WHEN ranked.geo_target IS NOT NULL
       AND ranked.band_target IS NOT NULL
      THEN CONCAT(
        'resight ',
        CASE ranked.geo_target WHEN 'A' THEN 'any' ELSE ranked.geo_target END,
        CASE
          WHEN ranked.is_candidate = 0
          THEN ' (GEO timing/waitlist)'
          ELSE ' (GEO waitlist)'
        END
      )
      WHEN ranked.balance_target IS NULL
       AND ranked.band_target IS NOT NULL
      THEN CONCAT(
        'band ',
        CASE ranked.band_target WHEN 'A' THEN 'either' ELSE ranked.band_target END,
        ' (',
        CASE
          WHEN ranked.band_target = 'M'
           AND ranked.male_quota_remaining = 0
          THEN 'male GEO quota complete'
          WHEN ranked.band_target = 'F'
           AND ranked.female_quota_remaining = 0
          THEN 'female GEO quota complete'
          WHEN ranked.band_target = 'A'
           AND ranked.male_quota_remaining = 0
           AND ranked.female_quota_remaining = 0
          THEN 'GEO sex quotas complete'
          ELSE 'GEO decision unresolved'
        END,
        ')'
      )
      ELSE NULL
    END AS geo_instruction,
    CASE
      WHEN ranked.pair_target IS NOT NULL
      THEN 1 ELSE 0
    END AS is_pair_completion,
    ranked.M_is_au_migrant,
    ranked.F_is_au_migrant
  FROM (
    SELECT
      ranked_base.*,
      CASE
        WHEN ranked_base.is_candidate = 1
         AND (
           ranked_base.pair_target IS NOT NULL
           OR ranked_base.geo_rank <= GREATEST(
             0,
             ranked_base.release_ceiling - ranked_base.n_geo_deployed
           )
         )
        THEN 1
        ELSE 0
      END AS geo_is_actionable
    FROM (
      SELECT
        scored.*,
        CASE
          WHEN scored.is_candidate = 1
          THEN SUM(scored.is_candidate) OVER (
            ORDER BY
              scored.is_candidate DESC,
              scored.geo_priority_tier,
              scored.global_sex_priority,
              scored.target_sex_deficit DESC,
              scored.geo_priority_score DESC,
              scored.first_egg_estimate,
              scored.nest_id
            ROWS UNBOUNDED PRECEDING
          )
          ELSE NULL
        END AS geo_rank
      FROM (
        SELECT
          candidates.*,
          4 * LEAST(candidates.target_sex_deficit, 3)
            + CASE WHEN candidates.pair_target IS NOT NULL THEN 2 ELSE 0 END
            + CASE
                WHEN candidates.M_reliable_identity = 1
                  OR candidates.F_reliable_identity = 1
                THEN 2 ELSE 1
              END
            + CASE candidates.phenology_confidence
                WHEN 'high' THEN 2
                WHEN 'medium' THEN 1
                ELSE 0
              END
            + candidates.target_identity_score
            AS geo_priority_score
        FROM (
          SELECT
            targets.*,
            COALESCE(targets.pair_target, targets.balance_target) AS geo_target,
            CASE WHEN targets.pair_target IS NOT NULL THEN 1 ELSE 2 END
              AS geo_priority_tier,
            CASE
              WHEN targets.pair_target IS NOT NULL THEN 1
              WHEN targets.preferred_balance_sex IS NULL THEN 1
              WHEN targets.balance_target = targets.preferred_balance_sex THEN 1
              ELSE 2
            END AS global_sex_priority,
            CASE
              WHEN targets.pair_target IS NOT NULL THEN 'pair completion'
              ELSE 'sex/phenology balance'
            END AS geo_reason,
            CASE COALESCE(targets.pair_target, targets.balance_target)
              WHEN 'M' THEN COALESCE(targets.male_deficit, 0)
              WHEN 'F' THEN COALESCE(targets.female_deficit, 0)
              ELSE GREATEST(
                COALESCE(targets.male_deficit, 0),
                COALESCE(targets.female_deficit, 0)
              )
            END AS target_sex_deficit,
            CASE COALESCE(targets.pair_target, targets.balance_target)
              WHEN 'M' THEN CASE
                WHEN targets.M_parent_mark IS NULL THEN 0 ELSE 1
              END
              WHEN 'F' THEN CASE
                WHEN targets.F_parent_mark IS NULL THEN 0 ELSE 1
              END
              ELSE CASE
                WHEN targets.M_parent_mark IS NULL
                 AND targets.F_parent_mark IS NULL THEN 0 ELSE 1
              END
            END AS target_identity_score,
            CASE
               WHEN COALESCE(targets.pair_target, targets.balance_target)
                   IS NOT NULL
               AND (
                 targets.pair_target IS NOT NULL
                 OR targets.n_geo_deployed < targets.release_ceiling
               )
               AND COALESCE(targets.capture_allowed_after_completion, 0) = 1
               AND CASE COALESCE(targets.pair_target, targets.balance_target)
                 WHEN 'M' THEN CASE
                   WHEN COALESCE(targets.no_parent_capture_yet, 0) = 1
                     OR COALESCE(targets.M_target_capture_window_open, 0) = 1
                   THEN 1 ELSE 0
                 END
                 WHEN 'F' THEN CASE
                   WHEN COALESCE(targets.no_parent_capture_yet, 0) = 1
                     OR COALESCE(targets.F_target_capture_window_open, 0) = 1
                   THEN 1 ELSE 0
                 END
                 ELSE CASE
                   WHEN COALESCE(targets.no_parent_capture_yet, 0) = 1
                     OR COALESCE(targets.any_target_capture_window_open, 0) = 1
                   THEN 1 ELSE 0
                 END
               END = 1
              THEN 1 ELSE 0
            END AS is_candidate
          FROM (
            SELECT
              base.*,
            -- Pair completion has priority and bypasses the release ceiling;
            -- the final 50-per-sex quota remains the hard limit for the
            -- target sex. Once F reaches 50, an eligible M can still be
            -- selected; the reverse applies if M reaches 50 first.
            CASE
              WHEN base.M_tag_eligible = 1
               AND base.male_quota_remaining > 0
               AND (
                 COALESCE(base.F_has_geo, 0) = 1
                 OR (
                   COALESCE(base.F_captured_has_geo, 0) = 1
                   AND (
                     COALESCE(base.F_mm_resight_pending, 0) = 0
                     OR COALESCE(base.M_confirmed_unbanded, 0) = 1
                   )
                 )
               )
              THEN 'M'
              WHEN base.F_tag_eligible = 1
               AND base.female_quota_remaining > 0
               AND (
                 COALESCE(base.M_has_geo, 0) = 1
                 OR (
                   COALESCE(base.M_captured_has_geo, 0) = 1
                   AND (
                     COALESCE(base.M_mm_resight_pending, 0) = 0
                     OR COALESCE(base.F_confirmed_unbanded, 0) = 1
                   )
                 )
               )
              THEN 'F'
              ELSE NULL
            END AS pair_target,
            -- For non-pair candidates, prefer the sex with the larger global
            -- quota remainder. The ranking below then orders that sex by its
            -- phenology-stratum deficit. Unknown/X-X identities remain
            -- capture-time identity/GEO checks, not a reason to suppress a
            -- quota-eligible target.
            CASE
              WHEN base.n_geo_deployed >= base.release_ceiling THEN NULL
              WHEN base.male_quota_remaining = 0
               AND base.female_quota_remaining = 0
              THEN NULL
              WHEN base.spans_strata = 1
               AND base.phenology_confidence = 'low'
              THEN NULL
              WHEN base.M_tag_eligible = 1
               AND base.F_tag_eligible = 1
              THEN CASE
                WHEN base.preferred_balance_sex = 'M'
                 AND base.male_quota_remaining > 0
                THEN 'M'
                WHEN base.preferred_balance_sex = 'F'
                 AND base.female_quota_remaining > 0
                THEN 'F'
                WHEN base.male_quota_remaining = 0
                 AND base.female_quota_remaining > 0
                THEN 'F'
                WHEN base.female_quota_remaining = 0
                 AND base.male_quota_remaining > 0
                THEN 'M'
                WHEN COALESCE(base.male_deficit, 0)
                     >= COALESCE(base.female_deficit, 0)
                THEN 'M'
                ELSE 'F'
              END
              WHEN base.M_tag_eligible = 1
               AND base.male_quota_remaining > 0
              THEN 'M'
              WHEN base.F_tag_eligible = 1
               AND base.female_quota_remaining > 0
              THEN 'F'
              ELSE NULL
            END AS balance_target,
            CASE
              WHEN base.M_band_needed = 1 AND base.F_band_needed = 1 THEN 'A'
              WHEN base.M_band_needed = 1 THEN 'M'
              WHEN base.F_band_needed = 1 THEN 'F'
              ELSE NULL
            END AS band_target
            FROM (
            SELECT
              active_nests.nest_id,
              nest_discovery.first_found_date,
              lay.first_egg_estimate,
              lay.phenology_confidence,
              lay.spans_strata,
              lay.male_deficit,
              lay.female_deficit,
              parent_status.M_parent_mark,
              parent_status.F_parent_mark,
              parent_status.M_confirmed_unbanded,
              parent_status.F_confirmed_unbanded,
              parent_status.M_has_geo,
              parent_status.F_has_geo,
              parent_status.M_captured_has_geo,
              parent_status.F_captured_has_geo,
              parent_status.M_mm_resight_pending,
              parent_status.F_mm_resight_pending,
              parent_status.both_parents_need_geo,
              parent_status.M_is_au_migrant,
              parent_status.F_is_au_migrant,
              deployment_status.n_geo_deployed,
              deployment_status.n_male_geo_deployed,
              deployment_status.n_female_geo_deployed,
              deployment_status.male_quota_remaining,
              deployment_status.female_quota_remaining,
              deployment_status.preferred_balance_sex,
              deployment_status.release_ceiling,
              CASE
                -- Hatched nests no longer need the clutch-completion gate;
                -- retain the 36-hour parent-capture gate below.
                WHEN UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'
                  OR active_nests.hatch_signs_present = 1
                THEN 1
                ELSE COALESCE(capture_age.capture_allowed_after_completion, 0)
              END AS capture_allowed_after_completion,
              capture_interval.no_parent_capture_yet,
              capture_interval.any_target_capture_window_open,
              capture_interval.M_target_capture_window_open,
              capture_interval.F_target_capture_window_open,
              CASE
                WHEN parent_status.M_parent_mark IS NOT NULL
                 AND parent_status.M_parent_mark <> 'X-X'
                 AND LOWER(parent_status.M_parent_mark) <> 'dead'
                THEN 1 ELSE 0
              END AS M_reliable_identity,
              CASE
                WHEN parent_status.F_parent_mark IS NOT NULL
                 AND parent_status.F_parent_mark <> 'X-X'
                 AND LOWER(parent_status.F_parent_mark) <> 'dead'
                THEN 1 ELSE 0
              END AS F_reliable_identity,
              CASE
                WHEN COALESCE(parent_status.M_confirmed_unbanded, 0) = 1
                  OR COALESCE(parent_status.M_unknown_status, 0) = 1
                  OR COALESCE(parent_status.M_single_colour_recruit, 0) = 1
                THEN 1 ELSE 0
              END AS M_band_needed,
              CASE
                WHEN COALESCE(parent_status.F_confirmed_unbanded, 0) = 1
                  OR COALESCE(parent_status.F_unknown_status, 0) = 1
                  OR COALESCE(parent_status.F_single_colour_recruit, 0) = 1
                THEN 1 ELSE 0
              END AS F_band_needed,
              CASE
                WHEN LEFT(UPPER(TRIM(active_nests.nest_id)), 1) = 'A'
                THEN 0
                WHEN COALESCE(parent_status.M_has_geo, 0) = 0
                 AND COALESCE(parent_status.M_is_au_migrant, 0) = 0
                 AND (
                   COALESCE(parent_status.M_is_dead, 0) = 0
                   OR (
                     COALESCE(parent_status.M_mm_xx_parent_confirmed, 0) = 1
                     AND COALESCE(parent_status.M_confirmed_unbanded, 0) = 1
                     AND COALESCE(parent_status.M_mm_resight_pending, 0) = 0
                   )
                 )
                 AND COALESCE(parent_status.M_mm_resight_pending, 0) = 0
                THEN 1 ELSE 0
              END AS M_tag_eligible,
              CASE
                WHEN LEFT(UPPER(TRIM(active_nests.nest_id)), 1) = 'A'
                THEN 0
                WHEN COALESCE(parent_status.F_has_geo, 0) = 0
                 AND COALESCE(parent_status.F_is_au_migrant, 0) = 0
                 AND (
                   COALESCE(parent_status.F_is_dead, 0) = 0
                   OR (
                     COALESCE(parent_status.F_mm_xx_parent_confirmed, 0) = 1
                     AND COALESCE(parent_status.F_confirmed_unbanded, 0) = 1
                     AND COALESCE(parent_status.F_mm_resight_pending, 0) = 0
                   )
                 )
                 AND COALESCE(parent_status.F_mm_resight_pending, 0) = 0
                THEN 1 ELSE 0
              END AS F_tag_eligible
            FROM active_nests
            JOIN nest_discovery
              ON active_nests.nest_id = nest_discovery.nest_id
            LEFT JOIN FIELD_2026_BADOatNZ.GEO_ROLLOUT_PHENOLOGY lay
              ON active_nests.nest_id = lay.nest_id
            LEFT JOIN adult_parent_geo_target_status parent_status
              ON active_nests.nest_id = parent_status.nest_id
            LEFT JOIN adult_capture_age_status capture_age
              ON active_nests.nest_id = capture_age.nest_id
            LEFT JOIN adult_capture_interval_status capture_interval
              ON active_nests.nest_id = capture_interval.nest_id
            CROSS JOIN geo_deployment_status deployment_status
            WHERE (
                UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) IN ('F', 'I', 'H', 'PP', 'PD')
                OR (
                  active_nests.hatch_signs_present = 1
                  AND active_nests.latest_float_date IS NULL
                )
              )
            ) base
          ) targets
      ) candidates
    ) scored
    ) ranked_base
  ) ranked
),
todo_untrapped_parent_candidate AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Untrapped parent' AS todo,
    CASE
      WHEN geo_parent_plan.geo_instruction IS NOT NULL
      THEN geo_parent_plan.geo_instruction
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_confirmed_unbanded = 1
      THEN 'any (both X-X)'
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_has_geo = 1
      THEN 'M (X-X; F w/GEO)'
      WHEN adult_parent_status.F_confirmed_unbanded = 1
       AND adult_parent_status.M_has_geo = 1
      THEN 'F (X-X; M w/GEO)'
      WHEN adult_parent_status.M_unknown_status = 1
       AND adult_parent_status.F_has_geo = 1
      THEN 'M (F w/GEO)'
      WHEN adult_parent_status.F_unknown_status = 1
       AND adult_parent_status.M_has_geo = 1
      THEN 'F (M w/GEO)'
      WHEN adult_parent_status.M_confirmed_unbanded = 1
      THEN 'M (X-X)'
      WHEN adult_parent_status.F_confirmed_unbanded = 1
      THEN 'F (X-X)'
      WHEN adult_parent_status.M_unknown_status = 1
       AND adult_parent_status.F_unknown_status = 1
      THEN 'any (status ?)'
      WHEN adult_parent_status.M_unknown_status = 1
      THEN 'M (status ?)'
      WHEN adult_parent_status.F_unknown_status = 1
      THEN 'F (status ?)'
      WHEN adult_parent_status.both_parents_need_geo = 1
      THEN 'any (GEOs)'
      WHEN adult_parent_status.M_has_geo = 1
       AND adult_parent_status.F_has_geo = 0
      THEN 'F (no GEO; M w/GEO)'
      WHEN adult_parent_status.F_has_geo = 1
       AND adult_parent_status.M_has_geo = 0
      THEN 'M (no GEO; F w/GEO)'
      WHEN adult_parent_status.M_single_colour_recruit = 1
       AND adult_parent_status.F_single_colour_recruit = 1
      THEN 'any recruit (full colours)'
      WHEN adult_parent_status.M_single_colour_recruit = 1
      THEN 'M recruit (full colours)'
      WHEN adult_parent_status.F_single_colour_recruit = 1
      THEN 'F recruit (full colours)'
    END AS notes,
    CASE
      WHEN geo_parent_plan.geo_tag_target IS NOT NULL
      THEN geo_parent_plan.geo_tag_target
      WHEN geo_parent_plan.geo_target IS NOT NULL
      THEN geo_parent_plan.geo_target
      WHEN geo_parent_plan.geo_band_target IS NOT NULL
      THEN geo_parent_plan.geo_band_target
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_confirmed_unbanded = 1 THEN 'A'
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_has_geo = 1 THEN 'M'
      WHEN adult_parent_status.F_confirmed_unbanded = 1
       AND adult_parent_status.M_has_geo = 1 THEN 'F'
      WHEN adult_parent_status.M_unknown_status = 1
       AND adult_parent_status.F_has_geo = 1 THEN 'M'
      WHEN adult_parent_status.F_unknown_status = 1
       AND adult_parent_status.M_has_geo = 1 THEN 'F'
      WHEN adult_parent_status.M_confirmed_unbanded = 1 THEN 'M'
      WHEN adult_parent_status.F_confirmed_unbanded = 1 THEN 'F'
      WHEN adult_parent_status.M_unknown_status = 1
       AND adult_parent_status.F_unknown_status = 1 THEN 'A'
      WHEN adult_parent_status.M_unknown_status = 1 THEN 'M'
      WHEN adult_parent_status.F_unknown_status = 1 THEN 'F'
      WHEN adult_parent_status.both_parents_need_geo = 1 THEN 'A'
      WHEN adult_parent_status.M_has_geo = 1
       AND adult_parent_status.F_has_geo = 0
       AND adult_parent_status.F_mm_resight_pending = 0 THEN 'F'
      WHEN adult_parent_status.F_has_geo = 1
       AND adult_parent_status.M_has_geo = 0
       AND adult_parent_status.M_mm_resight_pending = 0 THEN 'M'
      WHEN adult_parent_status.M_single_colour_recruit = 1
       AND adult_parent_status.F_single_colour_recruit = 1 THEN 'A'
      WHEN adult_parent_status.M_single_colour_recruit = 1 THEN 'M'
      WHEN adult_parent_status.F_single_colour_recruit = 1 THEN 'F'
    END AS target_parent,
    DATEDIFF(
      active_nests.reference_date,
      COALESCE(active_nests.first_found_date, active_nests.reference_date)
    ) AS days_overdue,
    350
      + DATEDIFF(
          active_nests.reference_date,
          COALESCE(active_nests.first_found_date, active_nests.reference_date)
        )
      + 3 * GREATEST(
          0,
          5 - CEILING(COALESCE(active_nests.min_days_to_hatch, 99))
        ) AS priority,
    active_nests.min_days_to_hatch,
    active_nests.days_ago AS last_visit_days_ago,
    active_nests.nest_state,
    active_nests.clutch_size,
    active_nests.brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    adult_parent_status.M_confirmed_unbanded,
    adult_parent_status.F_confirmed_unbanded,
    adult_parent_status.M_unknown_status,
    adult_parent_status.F_unknown_status,
    adult_parent_status.M_has_geo,
    adult_parent_status.F_has_geo,
    adult_parent_status.M_single_colour_recruit,
    adult_parent_status.F_single_colour_recruit,
    adult_parent_status.M_mm_resight_pending,
    adult_parent_status.F_mm_resight_pending,
    adult_parent_status.both_parents_need_geo,
    adult_capture_interval_status.no_parent_capture_yet,
    adult_capture_interval_status.any_target_capture_window_open,
    adult_capture_interval_status.M_target_capture_window_open,
    adult_capture_interval_status.F_target_capture_window_open,
    CASE
      -- Hatched nests no longer need the clutch-completion gate; retain the
      -- 36-hour parent-capture gate below.
      WHEN UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'
      THEN 1
      ELSE COALESCE(adult_capture_age_status.capture_allowed_after_completion, 0)
    END AS capture_allowed_after_completion,
    CASE
      WHEN adult_parent_status.M_unknown_status = 1
        OR adult_parent_status.F_unknown_status = 1
      THEN 1
      ELSE 0
    END AS resight_only_when_capture_blocked,
    CASE
      WHEN COALESCE(
             geo_parent_plan.geo_tag_target,
             geo_parent_plan.geo_band_target
           ) = 'A'
      THEN CASE
        WHEN COALESCE(adult_capture_interval_status.no_parent_capture_yet, 0) = 1
          OR COALESCE(
               adult_capture_interval_status.any_target_capture_window_open,
               0
             ) = 1
        THEN 1 ELSE 0
      END
      WHEN COALESCE(
             geo_parent_plan.geo_tag_target,
             geo_parent_plan.geo_band_target
           ) = 'M'
      THEN CASE
        WHEN COALESCE(adult_capture_interval_status.no_parent_capture_yet, 0) = 1
          OR COALESCE(
               adult_capture_interval_status.M_target_capture_window_open,
               0
             ) = 1
        THEN 1 ELSE 0
      END
      WHEN COALESCE(
             geo_parent_plan.geo_tag_target,
             geo_parent_plan.geo_band_target
           ) = 'F'
      THEN CASE
        WHEN COALESCE(adult_capture_interval_status.no_parent_capture_yet, 0) = 1
          OR COALESCE(
               adult_capture_interval_status.F_target_capture_window_open,
               0
             ) = 1
        THEN 1 ELSE 0
      END
      WHEN (
        (
          adult_parent_status.M_confirmed_unbanded = 1
          AND adult_parent_status.F_confirmed_unbanded = 1
        )
        OR (
          adult_parent_status.M_unknown_status = 1
          AND adult_parent_status.F_unknown_status = 1
        )
        OR (
          adult_parent_status.M_single_colour_recruit = 1
          AND adult_parent_status.F_single_colour_recruit = 1
        )
        OR adult_parent_status.both_parents_need_geo = 1
      )
      THEN CASE
        WHEN COALESCE(adult_capture_interval_status.no_parent_capture_yet, 0) = 1
          OR COALESCE(
               adult_capture_interval_status.any_target_capture_window_open,
               0
             ) = 1
        THEN 1
        ELSE 0
      END
      WHEN (
        (
          adult_parent_status.M_confirmed_unbanded = 1
          AND adult_parent_status.F_has_geo = 1
        )
        OR (
          adult_parent_status.M_unknown_status = 1
          AND adult_parent_status.F_has_geo = 1
        )
        OR adult_parent_status.M_confirmed_unbanded = 1
        OR adult_parent_status.M_unknown_status = 1
        OR (
          adult_parent_status.F_has_geo = 1
          AND adult_parent_status.M_has_geo = 0
        )
        OR adult_parent_status.M_single_colour_recruit = 1
      )
      THEN CASE
        WHEN COALESCE(adult_capture_interval_status.no_parent_capture_yet, 0) = 1
          OR COALESCE(
               adult_capture_interval_status.M_target_capture_window_open,
               0
             ) = 1
        THEN 1
        ELSE 0
      END
      WHEN (
        (
          adult_parent_status.F_confirmed_unbanded = 1
          AND adult_parent_status.M_has_geo = 1
        )
        OR (
          adult_parent_status.F_unknown_status = 1
          AND adult_parent_status.M_has_geo = 1
        )
        OR adult_parent_status.F_confirmed_unbanded = 1
        OR adult_parent_status.F_unknown_status = 1
        OR (
          adult_parent_status.M_has_geo = 1
          AND adult_parent_status.F_has_geo = 0
        )
        OR adult_parent_status.F_single_colour_recruit = 1
      )
      THEN CASE
        WHEN COALESCE(adult_capture_interval_status.no_parent_capture_yet, 0) = 1
          OR COALESCE(
               adult_capture_interval_status.F_target_capture_window_open,
               0
             ) = 1
        THEN 1
        ELSE 0
      END
      ELSE 0
    END AS capture_interval_open,
    geo_parent_plan.geo_instruction,
    geo_parent_plan.geo_tag_target,
    geo_parent_plan.geo_band_target,
    geo_parent_plan.geo_target,
    geo_parent_plan.geo_is_actionable,
    geo_parent_plan.n_geo_deployed,
    geo_parent_plan.release_ceiling,
    geo_parent_plan.geo_rank,
    geo_parent_plan.geo_priority_tier,
    geo_parent_plan.global_sex_priority,
    geo_parent_plan.geo_priority_score,
    geo_parent_plan.geo_reason,
    geo_parent_plan.is_pair_completion,
    geo_parent_plan.n_male_geo_deployed,
    geo_parent_plan.n_female_geo_deployed,
    geo_parent_plan.male_quota_remaining,
    geo_parent_plan.female_quota_remaining,
    geo_parent_plan.preferred_balance_sex,
    active_nests.lat,
    active_nests.lon
  FROM (
    SELECT
      active_nests.nest_id,
      active_nests.species,
      active_nests.last_visit_datetime,
      active_nests.days_ago,
      active_nests.last_observer,
      active_nests.nest_state,
      active_nests.hatch_state,
      active_nests.hatch_signs_present,
      active_nests.bird_inc,
      active_nests.clutch_size,
      active_nests.brood_size,
      active_nests.latest_float_date,
      active_nests.average_ref_date_days_since_laid,
      active_nests.min_days_to_hatch,
      active_nests.nest_photo,
      active_nests.tent_photo,
      active_nests.lat,
      active_nests.lon,
      active_nests.reference_date,
      nest_discovery.first_found_date,
      0 AS is_negative_brood
    FROM active_nests
    LEFT JOIN nest_discovery
      ON active_nests.nest_id = nest_discovery.nest_id
    UNION ALL
    SELECT
      b.nest_id,
      b.species,
      b.latest_encounter_datetime,
      DATEDIFF(b.reference_date, b.latest_encounter_date),
      CAST(NULL AS CHAR(10)),
      b.nest_state,
      b.hatch_state,
      1,
      CAST(NULL AS CHAR(2)),
      b.clutch_size,
      b.brood_size,
      CAST(NULL AS DATE),
      CAST(NULL AS DECIMAL(6,1)),
      b.min_days_to_hatch,
      b.nest_photo,
      b.tent_photo,
      b.lat,
      b.lon,
      b.reference_date,
      b.discovery_date,
      1
    FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
    CROSS JOIN sr
    WHERE b.is_negative_brood = 1
      AND b.reference_date = sr.reference_date
  ) active_nests
  LEFT JOIN adult_parent_geo_target_status adult_parent_status
    ON active_nests.nest_id = adult_parent_status.nest_id
  LEFT JOIN geo_parent_plan
    ON active_nests.nest_id = geo_parent_plan.nest_id
  LEFT JOIN adult_capture_interval_status
    ON active_nests.nest_id = adult_capture_interval_status.nest_id
  LEFT JOIN adult_capture_age_status
    ON active_nests.nest_id = adult_capture_age_status.nest_id
  LEFT JOIN float_summary
    ON active_nests.nest_id = float_summary.nest_id
  LEFT JOIN initial_clutch_status
    ON active_nests.nest_id = initial_clutch_status.nest_id
  WHERE (
      active_nests.is_negative_brood = 1
      OR
      UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) IN ('F', 'I', 'H', 'PP', 'PD')
      OR (
        active_nests.hatch_signs_present = 1
        AND active_nests.latest_float_date IS NULL
      )
    )
    AND (
      active_nests.is_negative_brood = 1
      OR
      UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) <> 'F'
      OR COALESCE(active_nests.clutch_size, 0) <> 3
      OR initial_clutch_status.found_as_incomplete = 1
      OR COALESCE(float_summary.n_float_rows, 0) > 0
    )
    AND (
      geo_parent_plan.geo_instruction IS NOT NULL
      OR adult_parent_status.M_confirmed_unbanded = 1
      OR adult_parent_status.F_confirmed_unbanded = 1
      OR adult_parent_status.M_unknown_status = 1
      OR adult_parent_status.F_unknown_status = 1
      OR adult_parent_status.M_single_colour_recruit = 1
      OR adult_parent_status.F_single_colour_recruit = 1
    )
),
todo_untrapped_parent AS (
  SELECT
    nest_id,
    reference_date,
    todo,
    CASE
      WHEN geo_instruction IS NOT NULL
       AND geo_tag_target IS NOT NULL
       AND COALESCE(capture_allowed_after_completion, 0) = 1
       AND COALESCE(capture_interval_open, 0) = 1
      THEN geo_instruction
      WHEN geo_instruction IS NOT NULL
       AND COALESCE(is_pair_completion, 0) = 1
      THEN CONCAT(
        geo_instruction,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; after 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; after 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; after 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(M_confirmed_unbanded, 0) = 1
       AND COALESCE(F_confirmed_unbanded, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'band X-X F; band X-X M'
          ELSE 'resight F; resight M'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(M_confirmed_unbanded, 0) = 1
       AND COALESCE(F_unknown_status, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'resight/band F; band X-X M'
          ELSE 'resight F'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(M_confirmed_unbanded, 0) = 1
       AND COALESCE(F_unknown_status, 0) = 0
       AND F_mark IS NOT NULL
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'resight/band X-X M'
          ELSE 'resight M'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN geo_instruction IS NOT NULL
       AND geo_instruction LIKE 'band %'
       AND geo_tag_target IS NULL
       AND geo_band_target IS NOT NULL
       AND COALESCE(M_confirmed_unbanded, 0) = 0
       AND COALESCE(F_confirmed_unbanded, 0) = 0
       AND COALESCE(M_unknown_status, 0) = 0
       AND COALESCE(F_unknown_status, 0) = 0
       AND COALESCE(capture_allowed_after_completion, 0) = 1
       AND COALESCE(capture_interval_open, 0) = 1
      THEN geo_instruction
      WHEN COALESCE(both_parents_need_geo, 0) = 1
      THEN 'band any'
      WHEN COALESCE(F_confirmed_unbanded, 0) = 1
       AND COALESCE(M_unknown_status, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'band X-X F; resight/band M'
          ELSE 'resight M'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(M_confirmed_unbanded, 0) = 1
       AND COALESCE(F_has_geo, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'band X-X M (F w/GEO)'
          ELSE 'resight M (F w/GEO)'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(F_confirmed_unbanded, 0) = 1
       AND COALESCE(M_has_geo, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'band X-X F (M w/GEO)'
          ELSE 'resight F (M w/GEO)'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(M_confirmed_unbanded, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'band X-X M'
          ELSE 'resight M'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(F_confirmed_unbanded, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'band X-X F'
          ELSE 'resight F'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(M_unknown_status, 0) = 1
       AND COALESCE(F_unknown_status, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'resight/band any (status ?)'
          ELSE 'resight any (status ?)'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(M_unknown_status, 0) = 1
       AND COALESCE(F_has_geo, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'resight/band M (F w/GEO)'
          ELSE 'resight M (F w/GEO)'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(F_unknown_status, 0) = 1
       AND COALESCE(M_has_geo, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'resight/band F (M w/GEO)'
          ELSE 'resight F (M w/GEO)'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(M_unknown_status, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'resight/band M (status ?)'
          ELSE 'resight M (status ?)'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(F_unknown_status, 0) = 1
      THEN CONCAT(
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1
          THEN 'resight/band F (status ?)'
          ELSE 'resight F (status ?)'
        END,
        CASE
          WHEN COALESCE(capture_allowed_after_completion, 0) = 1
           AND COALESCE(capture_interval_open, 0) = 1 THEN ''
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0
           AND COALESCE(capture_interval_open, 0) = 0 THEN '; 7d+36hr'
          WHEN COALESCE(capture_allowed_after_completion, 0) = 0 THEN '; 7d rule'
          WHEN COALESCE(capture_interval_open, 0) = 0 THEN '; 36hr rule'
          ELSE ''
        END
      )
      WHEN COALESCE(M_has_geo, 0) = 1
       AND COALESCE(F_has_geo, 0) = 0
       AND COALESCE(female_quota_remaining, 0) = 0
      THEN 'band F (no GEO; female quota complete; M w/GEO)'
      WHEN COALESCE(F_has_geo, 0) = 1
       AND COALESCE(M_has_geo, 0) = 0
       AND COALESCE(male_quota_remaining, 0) = 0
      THEN 'band M (no GEO; male quota complete; F w/GEO)'
      WHEN COALESCE(M_has_geo, 0) = 1
       AND COALESCE(F_has_geo, 0) = 0
      THEN 'band F (no GEO; M w/GEO)'
      WHEN COALESCE(F_has_geo, 0) = 1
       AND COALESCE(M_has_geo, 0) = 0
      THEN 'band M (no GEO; F w/GEO)'
      WHEN COALESCE(M_single_colour_recruit, 0) = 1
       AND COALESCE(F_single_colour_recruit, 0) = 1
      THEN 'band any recruit (full colours)'
      WHEN COALESCE(M_single_colour_recruit, 0) = 1
      THEN 'band M recruit (full colours)'
      WHEN COALESCE(F_single_colour_recruit, 0) = 1
      THEN 'band F recruit (full colours)'
      ELSE notes
    END AS notes,
    days_overdue,
    priority,
    min_days_to_hatch,
    last_visit_days_ago,
    nest_state,
    clutch_size,
    brood_size,
    M_mark,
    F_mark,
    lat,
    lon,
    -- A closed 7d/36hr gate is always a resighting task, including for
    -- pair-completion targets; capture rows must be actionable on that date.
    CASE
      WHEN geo_tag_target IS NOT NULL
       AND COALESCE(capture_allowed_after_completion, 0) = 1
       AND COALESCE(capture_interval_open, 0) = 1
      THEN 'Parent capture'
      WHEN geo_instruction LIKE 'resight %'
      THEN 'Parent resighting'
      WHEN COALESCE(capture_allowed_after_completion, 0) = 1
       AND COALESCE(capture_interval_open, 0) = 1
      THEN 'Parent capture'
      ELSE 'Parent resighting'
    END AS parent_task_class
  FROM todo_untrapped_parent_candidate
  WHERE target_parent IN ('A', 'M', 'F')
    AND (
      (
        COALESCE(capture_allowed_after_completion, 0) = 1
        AND COALESCE(capture_interval_open, 0) = 1
      )
      OR COALESCE(resight_only_when_capture_blocked, 0) = 1
      OR COALESCE(is_pair_completion, 0) = 1
    )
),
todo_parent_capture AS (
  SELECT
    nest_id,
    reference_date,
    'Parent capture' AS todo,
    notes,
    days_overdue,
    priority,
    min_days_to_hatch,
    last_visit_days_ago,
    nest_state,
    clutch_size,
    brood_size,
    M_mark,
    F_mark,
    lat,
    lon
  FROM todo_untrapped_parent
  WHERE parent_task_class = 'Parent capture'
),
todo_parent_resighting_existing AS (
  SELECT
    nest_id,
    reference_date,
    'Parent resighting' AS todo,
    notes,
    days_overdue,
    priority,
    min_days_to_hatch,
    last_visit_days_ago,
    nest_state,
    clutch_size,
    brood_size,
    M_mark,
    F_mark,
    lat,
    lon
  FROM todo_untrapped_parent
  WHERE parent_task_class = 'Parent resighting'
),
todo_mm_parent_resighting_by_sex AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Parent resighting' AS todo,
    CONCAT(
      mm.sex,
      ' had MM cap',
      CASE
        WHEN (mm.sex = 'M' AND adult_parent_status.M_post_mm_xx_seen = 1)
          OR (mm.sex = 'F' AND adult_parent_status.F_post_mm_xx_seen = 1)
        THEN '; X-X also seen'
        ELSE ''
      END
    ) AS notes,
    DATEDIFF(
      active_nests.reference_date,
      COALESCE(active_nests.first_found_date, active_nests.reference_date)
    ) AS days_overdue,
    350
      + DATEDIFF(
          active_nests.reference_date,
          COALESCE(active_nests.first_found_date, active_nests.reference_date)
        )
      + 3 * GREATEST(0, 5 - CEILING(COALESCE(active_nests.min_days_to_hatch, 99)))
      AS priority,
    active_nests.min_days_to_hatch,
    active_nests.days_ago AS last_visit_days_ago,
    active_nests.nest_state,
    active_nests.clutch_size,
    active_nests.brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    active_nests.lat,
    active_nests.lon,
    mm.sex,
    CASE
      WHEN (mm.sex = 'M' AND adult_parent_status.M_post_mm_xx_seen = 1)
        OR (mm.sex = 'F' AND adult_parent_status.F_post_mm_xx_seen = 1)
      THEN 1
      ELSE 0
    END AS post_mm_xx_seen
  FROM (
    SELECT
      active_nests.nest_id,
      active_nests.species,
      active_nests.last_visit_datetime,
      active_nests.days_ago,
      active_nests.last_observer,
      active_nests.nest_state,
      active_nests.hatch_state,
      active_nests.hatch_signs_present,
      active_nests.bird_inc,
      active_nests.clutch_size,
      active_nests.brood_size,
      active_nests.latest_float_date,
      active_nests.average_ref_date_days_since_laid,
      active_nests.min_days_to_hatch,
      active_nests.nest_photo,
      active_nests.tent_photo,
      active_nests.lat,
      active_nests.lon,
      active_nests.reference_date,
      nest_discovery.first_found_date,
      0 AS is_negative_brood
    FROM active_nests
    LEFT JOIN nest_discovery
      ON active_nests.nest_id = nest_discovery.nest_id
    UNION ALL
    SELECT
      b.nest_id,
      b.species,
      b.latest_encounter_datetime,
      DATEDIFF(b.reference_date, b.latest_encounter_date),
      CAST(NULL AS CHAR(10)),
      b.nest_state,
      b.hatch_state,
      1,
      CAST(NULL AS CHAR(2)),
      b.clutch_size,
      b.brood_size,
      CAST(NULL AS DATE),
      CAST(NULL AS DECIMAL(6,1)),
      b.min_days_to_hatch,
      b.nest_photo,
      b.tent_photo,
      b.lat,
      b.lon,
      b.reference_date,
      b.discovery_date,
      1
    FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
    CROSS JOIN sr
    WHERE b.is_negative_brood = 1
      AND b.reference_date = sr.reference_date
  ) active_nests
  JOIN adult_mm_capture_latest mm
    ON active_nests.nest_id = mm.nest_id
  LEFT JOIN adult_parent_status
    ON active_nests.nest_id = adult_parent_status.nest_id
  WHERE (
      active_nests.is_negative_brood = 1
      OR UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) IN ('F', 'I', 'H', 'PP', 'PD')
      OR (
        active_nests.hatch_signs_present = 1
        AND active_nests.latest_float_date IS NULL
      )
    )
    AND (
      (mm.sex = 'M' AND COALESCE(adult_parent_status.M_mm_resight_pending, 0) = 1)
      OR (mm.sex = 'F' AND COALESCE(adult_parent_status.F_mm_resight_pending, 0) = 1)
    )
    AND DATEDIFF(
          active_nests.reference_date,
          mm.mm_capture_date
        ) >= 2
),
todo_mm_parent_resighting AS (
  SELECT
    nest_id,
    reference_date,
    todo,
    CASE
      WHEN SUM(sex = 'M') > 0 AND SUM(sex = 'F') > 0
      THEN CONCAT(
        'M&F had MM cap',
        CASE
          WHEN MAX(CASE WHEN sex = 'M' THEN post_mm_xx_seen ELSE 0 END) = 1
           AND MAX(CASE WHEN sex = 'F' THEN post_mm_xx_seen ELSE 0 END) = 1
          THEN '; M&F X-X also seen'
          WHEN MAX(CASE WHEN sex = 'M' THEN post_mm_xx_seen ELSE 0 END) = 1
          THEN '; M X-X also seen'
          WHEN MAX(CASE WHEN sex = 'F' THEN post_mm_xx_seen ELSE 0 END) = 1
          THEN '; F X-X also seen'
          ELSE ''
        END
      )
      ELSE GROUP_CONCAT(
        notes
        ORDER BY CASE sex WHEN 'M' THEN 0 ELSE 1 END
        SEPARATOR '; '
      )
    END AS notes,
    MAX(days_overdue) AS days_overdue,
    MAX(priority) AS priority,
    MAX(min_days_to_hatch) AS min_days_to_hatch,
    MAX(last_visit_days_ago) AS last_visit_days_ago,
    MAX(nest_state) AS nest_state,
    MAX(clutch_size) AS clutch_size,
    MAX(brood_size) AS brood_size,
    MAX(M_mark) AS M_mark,
    MAX(F_mark) AS F_mark,
    MAX(lat) AS lat,
    MAX(lon) AS lon
  FROM todo_mm_parent_resighting_by_sex
  GROUP BY nest_id, reference_date, todo
),
todo_parent_resighting_source AS (
  SELECT * FROM todo_parent_resighting_existing
  UNION ALL
  SELECT * FROM todo_mm_parent_resighting
),
todo_parent_resighting AS (
  SELECT
    nest_id,
    reference_date,
    'Parent resighting' AS todo,
    GROUP_CONCAT(DISTINCT notes ORDER BY notes SEPARATOR '; ') AS notes,
    MAX(days_overdue) AS days_overdue,
    MAX(priority) AS priority,
    MAX(min_days_to_hatch) AS min_days_to_hatch,
    MAX(last_visit_days_ago) AS last_visit_days_ago,
    MAX(nest_state) AS nest_state,
    MAX(clutch_size) AS clutch_size,
    MAX(brood_size) AS brood_size,
    MAX(M_mark) AS M_mark,
    MAX(F_mark) AS F_mark,
    MAX(lat) AS lat,
    MAX(lon) AS lon
  FROM todo_parent_resighting_source
  GROUP BY nest_id, reference_date
),
todo_unprocessed_nest AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Unprocessed nest' AS todo,
    CASE
      WHEN COALESCE(initial_clutch_status.found_as_incomplete, 0) = 0
       AND COALESCE(
             complete_clutch_processing_status.complete_clutch_has_float,
             0
           ) = 0
       AND COALESCE(
             complete_clutch_processing_status.complete_clutch_has_photo,
             0
           ) = 0
      THEN 'float + photos'
      WHEN COALESCE(initial_clutch_status.found_as_incomplete, 0) = 0
       AND COALESCE(
             complete_clutch_processing_status.complete_clutch_has_float,
             0
           ) = 0
      THEN 'float only'
      WHEN COALESCE(
             complete_clutch_processing_status.complete_clutch_has_photo,
             0
           ) = 0
      THEN 'photos only'
    END AS notes,
    DATEDIFF(
      active_nests.reference_date,
      adult_capture_age_status.clutch_completion_basis_date
    ) AS days_overdue,
    200 + DATEDIFF(
      active_nests.reference_date,
      adult_capture_age_status.clutch_completion_basis_date
    ) AS priority,
    active_nests.min_days_to_hatch,
    active_nests.days_ago AS last_visit_days_ago,
    active_nests.nest_state,
    active_nests.clutch_size,
    active_nests.brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  JOIN processing_summary
    ON active_nests.nest_id = processing_summary.nest_id
  LEFT JOIN adult_parent_status
    ON active_nests.nest_id = adult_parent_status.nest_id
  LEFT JOIN adult_capture_age_status
    ON active_nests.nest_id = adult_capture_age_status.nest_id
  LEFT JOIN complete_clutch_processing_status
    ON active_nests.nest_id = complete_clutch_processing_status.nest_id
  LEFT JOIN initial_clutch_status
    ON active_nests.nest_id = initial_clutch_status.nest_id
  WHERE UPPER(TRIM(COALESCE(active_nests.species, ''))) = 'BADO'
    AND UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) IN ('F', 'I', 'PP', 'PD')
    AND COALESCE(adult_capture_age_status.clutch_completion_confirmed, 0) = 1
    AND (
      (
        COALESCE(initial_clutch_status.found_as_incomplete, 0) = 0
        AND COALESCE(
              complete_clutch_processing_status.complete_clutch_has_float,
              0
            ) = 0
      )
      OR COALESCE(
           complete_clutch_processing_status.complete_clutch_has_photo,
           0
         ) = 0
    )
),
todo_take_scrape_photos AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'take scrape photos' AS todo,
    'scrape photos needed' AS notes,
    DATEDIFF(
      active_nests.reference_date,
      nest_discovery.first_found_date
    ) AS days_overdue,
    150 + DATEDIFF(
      active_nests.reference_date,
      nest_discovery.first_found_date
    ) AS priority,
    active_nests.min_days_to_hatch,
    active_nests.days_ago AS last_visit_days_ago,
    active_nests.nest_state,
    active_nests.clutch_size,
    active_nests.brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  LEFT JOIN photo_summary
    ON active_nests.nest_id = photo_summary.nest_id
  JOIN nest_discovery
    ON active_nests.nest_id = nest_discovery.nest_id
  LEFT JOIN adult_parent_status
    ON active_nests.nest_id = adult_parent_status.nest_id
  LEFT JOIN scrape_parent_identity
    ON active_nests.nest_id = scrape_parent_identity.nest_id
  WHERE UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'S'
    AND COALESCE(photo_summary.n_photo_rows, 0) = 0
    AND (
      COALESCE(scrape_parent_identity.M_has_unique_scrape_resight, 0) = 1
      OR COALESCE(scrape_parent_identity.F_has_unique_scrape_resight, 0) = 1
    )
),
todo_reprocess_nest AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Re-process nest' AS todo,
    CASE
      WHEN COALESCE(latest_clutch_processing_status.clutch_has_float, 0) = 0
       AND COALESCE(latest_clutch_processing_status.clutch_has_photo, 0) = 0
      THEN 'float + photos'
      WHEN COALESCE(latest_clutch_processing_status.clutch_has_float, 0) = 0
      THEN 'float only'
      WHEN COALESCE(latest_clutch_processing_status.clutch_has_photo, 0) = 0
      THEN 'photos only'
      ELSE 'clutch increased'
    END AS notes,
    DATEDIFF(
      active_nests.reference_date,
      latest_clutch_history.clutch_date
    ) AS days_overdue,
    250 + DATEDIFF(
      active_nests.reference_date,
      latest_clutch_history.clutch_date
    ) AS priority,
    active_nests.min_days_to_hatch,
    active_nests.days_ago AS last_visit_days_ago,
    active_nests.nest_state,
    active_nests.clutch_size,
    active_nests.brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  JOIN processing_summary
    ON active_nests.nest_id = processing_summary.nest_id
  JOIN latest_clutch_history
    ON active_nests.nest_id = latest_clutch_history.nest_id
   AND latest_clutch_history.row_num = 1
  LEFT JOIN latest_clutch_processing_status
    ON active_nests.nest_id = latest_clutch_processing_status.nest_id
  LEFT JOIN clutch_at_processing
    ON active_nests.nest_id = clutch_at_processing.nest_id
   AND clutch_at_processing.row_num = 1
  LEFT JOIN initial_clutch_status
    ON active_nests.nest_id = initial_clutch_status.nest_id
  LEFT JOIN adult_parent_status
    ON active_nests.nest_id = adult_parent_status.nest_id
  WHERE processing_summary.last_processed_datetime IS NOT NULL
    AND UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) IN ('F', 'I', 'PP', 'PD')
    AND COALESCE(initial_clutch_status.found_as_incomplete, 0) = 0
    AND COALESCE(active_nests.brood_size, 0) = 0
    AND latest_clutch_history.clutch_datetime
        > processing_summary.last_processed_datetime
    AND clutch_at_processing.clutch_size IS NOT NULL
    AND latest_clutch_history.clutch_size > clutch_at_processing.clutch_size
),
todo_clutch_check AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Clutch check' AS todo,
    'check for additional eggs' AS notes,
    GREATEST(
      0,
      DATEDIFF(active_nests.reference_date, latest_nest_event.event_date) - 2
    ) AS days_overdue,
    275 + GREATEST(
      0,
      DATEDIFF(active_nests.reference_date, latest_nest_event.event_date) - 2
    ) AS priority,
    active_nests.min_days_to_hatch,
    active_nests.days_ago AS last_visit_days_ago,
    active_nests.nest_state,
    active_nests.clutch_size,
    active_nests.brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  JOIN latest_nest_event
    ON active_nests.nest_id = latest_nest_event.nest_id
   AND latest_nest_event.row_num = 1
  JOIN adult_capture_current_clutch_start
    ON active_nests.nest_id = adult_capture_current_clutch_start.nest_id
  LEFT JOIN adult_parent_status
    ON active_nests.nest_id = adult_parent_status.nest_id
  WHERE UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) IN ('F', 'I', 'PP', 'PD')
    AND latest_nest_event.clutch_size IN (1, 2)
    AND DATEDIFF(
          latest_nest_event.event_date,
          DATE(adult_capture_current_clutch_start.current_clutch_start_datetime)
        ) < 7
    AND DATEDIFF(
          active_nests.reference_date,
          latest_nest_event.event_date
        ) >= 2
),
nest_check_rules AS (
  SELECT
    6 AS start_days_before_hatch,
    2 AS repeat_interval_days
),
todo_nest_check AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'nest check' AS todo,
    CONCAT(
      'Last visit: ',
      COALESCE(
        NULLIF(TRIM(active_nests.hatch_state), ''),
        'not recorded'
      )
    ) AS notes,
    CASE
      WHEN active_nests.hatch_signs_present = 1
      THEN GREATEST(0, active_nests.days_ago - 1)
      ELSE GREATEST(
        0,
        nest_check_rules.start_days_before_hatch
          - CEILING(active_nests.min_days_to_hatch)
      )
    END AS days_overdue,
    CASE
      WHEN active_nests.hatch_signs_present = 1
      THEN 500 + GREATEST(0, active_nests.days_ago - 1)
      ELSE 300
        + GREATEST(
            0,
            nest_check_rules.start_days_before_hatch
              - CEILING(active_nests.min_days_to_hatch)
          )
    END AS priority,
    active_nests.min_days_to_hatch,
    active_nests.days_ago AS last_visit_days_ago,
    active_nests.nest_state,
    active_nests.clutch_size,
    active_nests.brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  CROSS JOIN nest_check_rules
  LEFT JOIN adult_parent_status
    ON active_nests.nest_id = adult_parent_status.nest_id
  WHERE active_nests.clutch_size IS NULL
     OR active_nests.clutch_size > 0
    AND (
      (
        active_nests.hatch_signs_present = 1
        AND active_nests.days_ago >= 1
      )
      OR (
        UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) IN ('I', 'PP', 'PD')
        AND active_nests.min_days_to_hatch IS NOT NULL
        AND CEILING(active_nests.min_days_to_hatch)
            <= nest_check_rules.start_days_before_hatch
        AND active_nests.days_ago >= nest_check_rules.repeat_interval_days
      )
    )
),
todo_untrapped_brood AS (
  SELECT
    brood_followup_nests.nest_id,
    brood_followup_nests.reference_date,
    'Untrapped brood' AS todo,
    'no chick captures' AS notes,
    DATEDIFF(
      brood_followup_nests.reference_date,
      brood_followup_nests.hatch_date
    ) AS days_overdue,
    450 + DATEDIFF(
      brood_followup_nests.reference_date,
      brood_followup_nests.hatch_date
    ) AS priority,
    DATEDIFF(
      brood_followup_nests.hatch_date,
      brood_followup_nests.reference_date
    ) AS min_days_to_hatch,
    brood_followup_nests.days_ago AS last_visit_days_ago,
    brood_followup_nests.nest_state,
    brood_followup_nests.clutch_size,
    brood_followup_nests.brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    brood_followup_nests.lat,
    brood_followup_nests.lon
  FROM brood_followup_nests
  LEFT JOIN chick_captures
    ON brood_followup_nests.nest_id = chick_captures.nest_id
  LEFT JOIN adult_parent_status
    ON brood_followup_nests.nest_id = adult_parent_status.nest_id
  WHERE COALESCE(chick_captures.n_chick_captures, 0) = 0
  UNION ALL
  SELECT
    b.nest_id,
    b.reference_date,
    'Untrapped brood' AS todo,
    'no chick captures' AS notes,
    DATEDIFF(b.reference_date, b.discovery_date) AS days_overdue,
    450 + DATEDIFF(b.reference_date, b.discovery_date) AS priority,
    CAST(NULL AS SIGNED) AS min_days_to_hatch,
    DATEDIFF(b.reference_date, b.latest_encounter_date) AS last_visit_days_ago,
    CAST(NULL AS CHAR(10)) AS nest_state,
    CAST(NULL AS SIGNED) AS clutch_size,
    CAST(NULL AS SIGNED) AS brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    b.lat,
    b.lon
  FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
  CROSS JOIN sr
  LEFT JOIN chick_captures
    ON b.nest_id = chick_captures.nest_id
  LEFT JOIN adult_parent_status
    ON b.nest_id = adult_parent_status.nest_id
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
    AND COALESCE(chick_captures.n_chick_captures, 0) = 0
),
todo_hiding_spot_photos AS (
  SELECT
    brood_followup_nests.nest_id,
    brood_followup_nests.reference_date,
    'Hiding spot photos needed' AS todo,
    CONCAT(
      COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0),
      '/',
      COALESCE(chick_captures.n_captured_chick_rings, 0),
      ' chicks photographed'
    ) AS notes,
    GREATEST(
      0,
      DATEDIFF(
        brood_followup_nests.reference_date,
        brood_followup_nests.hatch_date
      ) - 1
    ) AS days_overdue,
    400 + GREATEST(
      0,
      DATEDIFF(
        brood_followup_nests.reference_date,
        brood_followup_nests.hatch_date
      ) - 1
    ) AS priority,
    DATEDIFF(
      brood_followup_nests.hatch_date,
      brood_followup_nests.reference_date
    ) AS min_days_to_hatch,
    brood_followup_nests.days_ago AS last_visit_days_ago,
    brood_followup_nests.nest_state,
    brood_followup_nests.clutch_size,
    brood_followup_nests.brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    brood_followup_nests.lat,
    brood_followup_nests.lon
  FROM brood_followup_nests
  LEFT JOIN hiding_spot_photos
    ON brood_followup_nests.nest_id = hiding_spot_photos.nest_id
  LEFT JOIN chick_captures
    ON brood_followup_nests.nest_id = chick_captures.nest_id
  LEFT JOIN adult_parent_status
    ON brood_followup_nests.nest_id = adult_parent_status.nest_id
  WHERE DATEDIFF(
        brood_followup_nests.reference_date,
        brood_followup_nests.hatch_date
      ) BETWEEN 1 AND 6
    AND (
      COALESCE(chick_captures.n_captured_chick_rings, 0) = 0
      OR COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0)
           < chick_captures.n_captured_chick_rings
    )
  UNION ALL
  SELECT
    b.nest_id,
    b.reference_date,
    'Hiding spot photos needed' AS todo,
    CONCAT(
      COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0),
      '/',
      COALESCE(chick_captures.n_captured_chick_rings, 0),
      ' chicks photographed'
    ) AS notes,
    GREATEST(0, DATEDIFF(b.reference_date, b.discovery_date) - 1) AS days_overdue,
    400 + GREATEST(0, DATEDIFF(b.reference_date, b.discovery_date) - 1) AS priority,
    CAST(NULL AS SIGNED) AS min_days_to_hatch,
    DATEDIFF(b.reference_date, b.latest_encounter_date) AS last_visit_days_ago,
    CAST(NULL AS CHAR(10)) AS nest_state,
    CAST(NULL AS SIGNED) AS clutch_size,
    CAST(NULL AS SIGNED) AS brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    b.lat,
    b.lon
  FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
  CROSS JOIN sr
  LEFT JOIN hiding_spot_photos
    ON b.nest_id = hiding_spot_photos.nest_id
  LEFT JOIN chick_captures
    ON b.nest_id = chick_captures.nest_id
  LEFT JOIN adult_parent_status
    ON b.nest_id = adult_parent_status.nest_id
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
    AND DATEDIFF(b.reference_date, b.discovery_date) BETWEEN 1 AND 6
    AND (
      COALESCE(chick_captures.n_captured_chick_rings, 0) = 0
      OR COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0)
           < chick_captures.n_captured_chick_rings
    )
),
todo_nota_nest_check AS (
  SELECT
    nota_followup_nests.nest_id,
    nota_followup_nests.reference_date,
    'notA nest-check' AS todo,
    CASE
      WHEN nota_followup_nests.nest_state = 'H'
       AND COALESCE(nota_followup_nests.clutch_size, 0) = 0
       AND COALESCE(nota_followup_nests.brood_size, 0) > 0
      THEN 'hatched; remove flag + do notA'
      ELSE 'remove flag + do notA'
    END AS notes,
    nota_followup_nests.days_ago AS days_overdue,
    325 + nota_followup_nests.days_ago AS priority,
    nota_followup_nests.min_days_to_hatch,
    nota_followup_nests.days_ago AS last_visit_days_ago,
    nota_followup_nests.nest_state,
    nota_followup_nests.clutch_size,
    nota_followup_nests.brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    nota_followup_nests.lat,
    nota_followup_nests.lon
  FROM nota_followup_nests
  LEFT JOIN adult_parent_status
    ON nota_followup_nests.nest_id = adult_parent_status.nest_id
)
SELECT
  t.*,
  geo_parent_plan.geo_rank AS geo_priority_rank,
  geo_parent_plan.geo_priority_tier,
  geo_parent_plan.geo_priority_score,
  geo_parent_plan.geo_reason,
  geo_parent_plan.geo_target,
  geo_parent_plan.geo_tag_target,
  geo_parent_plan.geo_is_actionable,
  geo_parent_plan.n_geo_deployed,
  geo_parent_plan.release_ceiling,
  geo_parent_plan.release_slots_remaining,
  geo_parent_plan.n_male_geo_deployed,
  geo_parent_plan.n_female_geo_deployed,
  geo_parent_plan.male_quota_remaining,
  geo_parent_plan.female_quota_remaining,
  geo_parent_plan.preferred_balance_sex,
  geo_parent_plan.M_is_au_migrant,
  geo_parent_plan.F_is_au_migrant,
  CASE
    WHEN t.todo IN ('Untrapped parent', 'Parent capture', 'Parent resighting')
     AND t.min_days_to_hatch IS NOT NULL
     AND CEILING(t.min_days_to_hatch) <= 5
    THEN CONCAT(
      GREATEST(0, CEILING(t.min_days_to_hatch)),
      ' to H'
    )
    WHEN t.todo = 'Untrapped parent'
    THEN CONCAT(COALESCE(t.days_overdue, 0), ' since F')
    ELSE CAST(t.days_overdue AS CHAR)
  END AS overdue_label
FROM (
  SELECT * FROM todo_parent_capture
  UNION ALL
  SELECT * FROM todo_parent_resighting
  UNION ALL
  SELECT * FROM todo_unprocessed_nest
  UNION ALL
  SELECT * FROM todo_take_scrape_photos
  UNION ALL
  SELECT * FROM todo_reprocess_nest
  UNION ALL
  SELECT * FROM todo_clutch_check
  UNION ALL
  SELECT * FROM todo_nest_check
  UNION ALL
  SELECT * FROM todo_untrapped_brood
  UNION ALL
  SELECT * FROM todo_hiding_spot_photos
  UNION ALL
  SELECT * FROM todo_nota_nest_check
) t
LEFT JOIN geo_parent_plan
  ON t.nest_id = geo_parent_plan.nest_id
-- WRYB remains available to map/summary consumers, but is not a Cass
-- operational task in TODO_LIST.
WHERE NOT EXISTS (
  SELECT 1
  FROM FIELD_2026_BADOatNZ.NESTS_LATEST wryb_nest
  WHERE wryb_nest.nest_id = t.nest_id
    AND UPPER(TRIM(COALESCE(wryb_nest.species, ''))) = 'WRYB'
);


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.VIEW_1 AS

WITH reference_setting AS (
  -- Fail closed unless exactly one non-null canonical reference date exists.
  SELECT MAX(value) AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
  HAVING COUNT(*) = 1
),
latest_nest_state AS (
  SELECT
    ranked.nest_id,
    ranked.nest_state
  FROM (
    SELECT
      n.nest_id,
      n.nest_state,
      ROW_NUMBER() OVER (
        PARTITION BY n.nest_id
        ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
      ) AS row_num
    FROM FIELD_2026_BADOatNZ.NESTS n
    CROSS JOIN reference_setting reference
    WHERE n.nest_id IS NOT NULL
      AND TRIM(n.nest_id) <> ''
      AND n.date <= reference.reference_date
  ) ranked
  WHERE ranked.row_num = 1
),
geo_device_history AS (
  -- A device seen against several rings is not safe cohort evidence.
  SELECT
    UPPER(TRIM(c.ring)) AS bird_id,
    UPPER(TRIM(c.tag_id)) AS device_id
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN reference_setting reference
  WHERE c.date <= reference.reference_date
    AND UPPER(TRIM(COALESCE(c.tag_type, ''))) = 'GEO'
    AND NULLIF(TRIM(c.ring), '') IS NOT NULL
    AND NULLIF(TRIM(c.tag_id), '') IS NOT NULL

  UNION

  SELECT
    UPPER(TRIM(c.ring)) AS bird_id,
    UPPER(TRIM(c.tag_id_in)) AS device_id
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN reference_setting reference
  WHERE c.date <= reference.reference_date
    AND UPPER(TRIM(COALESCE(c.tag_type, ''))) = 'GEO'
    AND NULLIF(TRIM(c.ring), '') IS NOT NULL
    AND NULLIF(TRIM(c.tag_id_in), '') IS NOT NULL
),
geo_device_owners AS (
  SELECT
    device_id,
    COUNT(DISTINCT bird_id) AS n_birds
  FROM geo_device_history
  GROUP BY device_id
),
capture_mark_versions AS (
  -- Post-handling fields define the current identity. The *_in fields are
  -- retained as a separate historical alias and as a fallback when a
  -- post-handling field is blank.
  SELECT
    UPPER(TRIM(c.ring)) AS bird_id,
    UPPER(TRIM(c.tag_id)) AS device_id,
    c.date AS cap_date,
    c.caught AS cap_time,
    c.field_sex AS sex,
    LEFT(UPPER(TRIM(c.field_sex)), 1) AS sex_key,
    c.pk,
    'post' AS mark_source,
    UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), ''))) AS UL_norm,
    UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), ''))) AS LL_norm,
    UPPER(COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), ''))) AS UR_norm,
    UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), ''))) AS LR_norm
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN reference_setting reference
  WHERE c.date IS NOT NULL
    AND c.date <= reference.reference_date
    AND NULLIF(TRIM(c.ring), '') IS NOT NULL

  UNION ALL

  SELECT
    UPPER(TRIM(c.ring)) AS bird_id,
    UPPER(TRIM(c.tag_id)) AS device_id,
    c.date AS cap_date,
    c.caught AS cap_time,
    c.field_sex AS sex,
    LEFT(UPPER(TRIM(c.field_sex)), 1) AS sex_key,
    c.pk,
    'in' AS mark_source,
    UPPER(NULLIF(TRIM(c.UL_in), '')) AS UL_norm,
    UPPER(NULLIF(TRIM(c.LL_in), '')) AS LL_norm,
    UPPER(NULLIF(TRIM(c.UR_in), '')) AS UR_norm,
    UPPER(NULLIF(TRIM(c.LR_in), '')) AS LR_norm
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN reference_setting reference
  WHERE c.date IS NOT NULL
    AND c.date <= reference.reference_date
    AND NULLIF(TRIM(c.ring), '') IS NOT NULL
    AND (
      NULLIF(TRIM(c.UL_in), '') IS NOT NULL
      OR NULLIF(TRIM(c.LL_in), '') IS NOT NULL
      OR NULLIF(TRIM(c.UR_in), '') IS NOT NULL
      OR NULLIF(TRIM(c.LR_in), '') IS NOT NULL
    )
),
capture_mark_identity_values AS (
  SELECT
    versions.*,
    CASE
      WHEN versions.LR_norm REGEXP '^[A-Z]$'
       AND versions.UR_norm REGEXP '^T[A-Z]$'
       AND SUBSTRING(versions.UR_norm, 2) NOT IN ('X', 'M')
      THEN CONCAT(
        COALESCE(NULLIF(versions.LL_norm, ''), 'X'),
        '-',
        SUBSTRING(versions.UR_norm, 2),
        '.',
        versions.LR_norm
      )
      ELSE FIELD_2026_BADOatNZ.format_mark(
        versions.UL_norm,
        versions.LL_norm,
        versions.UR_norm,
        versions.LR_norm
      )
    END AS mark
  FROM capture_mark_versions versions
),
capture_mark_identities AS (
  SELECT
    identities.*,
    UPPER(identities.mark) AS mark_key,
    CASE
      WHEN identities.LL_norm IS NOT NULL
       AND identities.LR_norm IS NOT NULL
      THEN CONCAT(identities.LL_norm, '|', identities.LR_norm)
      ELSE NULL
    END AS partial_key
  FROM capture_mark_identity_values identities
),
outgoing_geo_events AS (
  SELECT
    c.bird_id,
    c.device_id,
    c.cap_date,
    c.cap_time,
    c.sex,
    c.sex_key,
    c.mark,
    c.mark_key,
    c.pk
  FROM capture_mark_identities c
  JOIN FIELD_2026_BADOatNZ.CAPTURES raw_capture
    ON UPPER(TRIM(raw_capture.ring)) = c.bird_id
   AND raw_capture.pk = c.pk
  WHERE c.mark_source = 'post'
    AND UPPER(TRIM(COALESCE(raw_capture.tag_type, ''))) = 'GEO'
    AND UPPER(TRIM(COALESCE(raw_capture.tag_action, ''))) IN ('D', 'N')
    AND NULLIF(TRIM(c.device_id), '') IS NOT NULL
),
deployment_ranked AS (
  SELECT
    event.*,
    ROW_NUMBER() OVER (
      PARTITION BY event.bird_id
      ORDER BY
        event.cap_date,
        COALESCE(event.cap_time, CAST('00:00:00' AS TIME)),
        event.pk
    ) AS deployment_rank
  FROM outgoing_geo_events event
  JOIN geo_device_owners owner
    ON event.device_id = owner.device_id
   AND owner.n_birds = 1
  WHERE event.mark_key <> 'X-X'
    AND event.mark_key <> 'XX-XX'
    AND SUBSTRING_INDEX(event.mark_key, '-', 1) NOT IN ('X', 'XX')
    AND SUBSTRING_INDEX(event.mark_key, '-', -1) NOT IN ('X', 'XX')
),
tagged_birds AS (
  -- One row per ring; replacements remain part of the same bird history.
  SELECT
    bird_id,
    device_id,
    cap_date,
    sex,
    sex_key,
    mark,
    mark_key
  FROM deployment_ranked
  WHERE deployment_rank = 1
),
capture_alias_values AS (
  -- Later captures provide exact pre/post-handling aliases for changed marks.
  SELECT
    bird.bird_id,
    bird.sex_key,
    aliases.mark_key,
    aliases.partial_key
  FROM tagged_birds bird
  JOIN capture_mark_identities aliases
    ON aliases.bird_id = bird.bird_id
  CROSS JOIN reference_setting reference
  WHERE aliases.cap_date >= bird.cap_date
    AND aliases.cap_date <= reference.reference_date
),
complete_bird_aliases AS (
  SELECT DISTINCT
    bird_id,
    sex_key,
    mark_key,
    partial_key
  FROM capture_alias_values
  WHERE mark_key <> 'X-X'
    AND mark_key <> 'XX-XX'
    AND SUBSTRING_INDEX(mark_key, '-', 1) NOT IN ('X', 'XX')
    AND SUBSTRING_INDEX(mark_key, '-', -1) NOT IN ('X', 'XX')
),
alias_mark_owner_counts AS (
  SELECT
    mark_key,
    COUNT(DISTINCT bird_id) AS n_birds
  FROM complete_bird_aliases
  GROUP BY mark_key
),
alias_mark_sex_owner_counts AS (
  SELECT
    mark_key,
    sex_key,
    COUNT(DISTINCT bird_id) AS n_birds
  FROM complete_bird_aliases
  GROUP BY mark_key, sex_key
),
unique_bird_aliases AS (
  -- Ambiguous marks are retained nowhere in the exact RESIGHTINGS path.
  SELECT
    alias.bird_id,
    alias.sex_key,
    alias.mark_key,
    alias.partial_key
  FROM complete_bird_aliases alias
  JOIN alias_mark_owner_counts owner
    ON alias.mark_key = owner.mark_key
  JOIN alias_mark_sex_owner_counts sex_owner
    ON alias.mark_key = sex_owner.mark_key
   AND alias.sex_key = sex_owner.sex_key
   AND sex_owner.n_birds = 1
),
alias_partial_owner_counts AS (
  SELECT
    partial_key,
    COUNT(DISTINCT bird_id) AS n_birds
  FROM complete_bird_aliases
  WHERE partial_key IS NOT NULL
  GROUP BY partial_key
),
alias_partial_sex_owner_counts AS (
  SELECT
    partial_key,
    sex_key,
    COUNT(DISTINCT bird_id) AS n_birds
  FROM complete_bird_aliases
  WHERE partial_key IS NOT NULL
  GROUP BY partial_key, sex_key
),
unique_bird_partial_aliases AS (
  SELECT DISTINCT
    alias.bird_id,
    alias.sex_key,
    alias.partial_key
  FROM complete_bird_aliases alias
  JOIN alias_partial_owner_counts owner
    ON alias.partial_key = owner.partial_key
  JOIN alias_partial_sex_owner_counts sex_owner
    ON alias.partial_key = sex_owner.partial_key
   AND alias.sex_key = sex_owner.sex_key
   AND sex_owner.n_birds = 1
  WHERE alias.partial_key IS NOT NULL
),
resighting_mark_identity_values AS (
  SELECT
    r.date AS resighting_date,
    r.pk,
    NULLIF(TRIM(r.nest_id), '') AS nest_id,
    NULLIF(TRIM(r.comments), '') AS comment_text,
    LOWER(COALESCE(NULLIF(TRIM(r.comments), ''), '')) AS comment_lower,
    LEFT(UPPER(TRIM(r.sex)), 1) AS sex_key,
    UPPER(NULLIF(TRIM(r.UL), '')) AS UL_norm,
    UPPER(NULLIF(TRIM(r.LL), '')) AS LL_norm,
    UPPER(NULLIF(TRIM(r.UR), '')) AS UR_norm,
    UPPER(NULLIF(TRIM(r.LR), '')) AS LR_norm
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN reference_setting reference
  WHERE r.date IS NOT NULL
    AND r.date <= reference.reference_date
),
resighting_mark_identities AS (
  SELECT
    identities.*,
    CASE
      WHEN identities.LR_norm REGEXP '^[A-Z]$'
       AND identities.UR_norm REGEXP '^T[A-Z]$'
       AND SUBSTRING(identities.UR_norm, 2) NOT IN ('X', 'M')
      THEN CONCAT(
        COALESCE(NULLIF(identities.LL_norm, ''), 'X'),
        '-',
        SUBSTRING(identities.UR_norm, 2),
        '.',
        identities.LR_norm
      )
      ELSE FIELD_2026_BADOatNZ.format_mark(
        identities.UL_norm,
        identities.LL_norm,
        identities.UR_norm,
        identities.LR_norm
      )
    END AS mark,
    CASE
      WHEN identities.LL_norm IS NOT NULL
       AND identities.LR_norm IS NOT NULL
      THEN CONCAT(identities.LL_norm, '|', identities.LR_norm)
      ELSE NULL
    END AS partial_key
  FROM resighting_mark_identity_values identities
),
matched_resightings AS (
  SELECT
    alias.bird_id,
    resighting.resighting_date,
    resighting.pk,
    resighting.nest_id,
    resighting.comment_text,
    resighting.comment_lower
  FROM resighting_mark_identities resighting
  JOIN unique_bird_aliases alias
    ON UPPER(resighting.mark) = alias.mark_key
  JOIN alias_mark_owner_counts owner
    ON alias.mark_key = owner.mark_key
  JOIN tagged_birds bird
    ON alias.bird_id = bird.bird_id
  WHERE resighting.UR_norm IS NOT NULL
    AND resighting.resighting_date >= bird.cap_date
    AND (
      (
        resighting.sex_key IS NOT NULL
        AND resighting.sex_key = alias.sex_key
      )
      OR (
        resighting.sex_key IS NULL
        AND owner.n_birds = 1
      )
    )

  UNION ALL

  SELECT
    alias.bird_id,
    resighting.resighting_date,
    resighting.pk,
    resighting.nest_id,
    resighting.comment_text,
    resighting.comment_lower
  FROM resighting_mark_identities resighting
  JOIN unique_bird_partial_aliases alias
    ON resighting.partial_key = alias.partial_key
  JOIN alias_partial_owner_counts owner
    ON alias.partial_key = owner.partial_key
  JOIN tagged_birds bird
    ON alias.bird_id = bird.bird_id
  WHERE resighting.UR_norm IS NULL
    AND resighting.resighting_date >= bird.cap_date
    AND (
      (
        resighting.sex_key IS NOT NULL
        AND resighting.sex_key = alias.sex_key
      )
      OR (
        resighting.sex_key IS NULL
        AND owner.n_birds = 1
      )
    )
),
nest_association_events AS (
  -- Keep only explicit nest/brood associations; NO_NEST does not clear an
  -- earlier association. A same-day resighting takes precedence over a
  -- capture, with pk providing the final deterministic tie-break.
  SELECT
    bird.bird_id,
    c.date AS association_date,
    c.caught AS association_time,
    1 AS source_rank,
    c.pk,
    NULLIF(TRIM(c.nest_id), '') AS nest_id
  FROM tagged_birds bird
  JOIN FIELD_2026_BADOatNZ.CAPTURES c
    ON UPPER(TRIM(c.ring)) = bird.bird_id
  CROSS JOIN reference_setting reference
  WHERE c.date >= bird.cap_date
    AND c.date <= reference.reference_date
    AND NULLIF(TRIM(c.nest_id), '') IS NOT NULL
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'

  UNION ALL

  SELECT
    matched.bird_id,
    matched.resighting_date AS association_date,
    CAST(NULL AS TIME) AS association_time,
    2 AS source_rank,
    matched.pk,
    matched.nest_id
  FROM matched_resightings matched
  WHERE matched.nest_id IS NOT NULL
    AND UPPER(matched.nest_id) <> 'NO_NEST'
),
nest_association_ranked AS (
  SELECT
    association.*,
    ROW_NUMBER() OVER (
      PARTITION BY association.bird_id
      ORDER BY
        association.association_date DESC,
        association.source_rank DESC,
        COALESCE(association.association_time, CAST('00:00:00' AS TIME)) DESC,
        association.pk DESC
    ) AS association_rank
  FROM nest_association_events association
),
latest_nest_association AS (
  SELECT
    bird_id,
    nest_id
  FROM nest_association_ranked
  WHERE association_rank = 1
),
resighting_comment_terms AS (
  SELECT
    matched.*,
    CASE WHEN matched.comment_lower REGEXP
      '(^|[^[:alpha:]])limp(ing|ed|s)?([^[:alpha:]]|$)'
      THEN 1 ELSE 0
    END AS has_limp_word,
    CASE WHEN matched.comment_lower REGEXP
      '(^|[^[:alpha:]])lame(ness)?([^[:alpha:]]|$)'
      THEN 1 ELSE 0
    END AS has_lame_word,
    CASE WHEN matched.comment_lower REGEXP
      '(^|[^[:alpha:]])((not|no|without)[[:space:]-]+limp(ing|ed|s)?|(no|without)[[:space:]-]+(sign(s)?|evidence)[[:space:]-]+of[[:space:]-]+limp(ing|ed|s)?|(is|was|does|did)[[:space:]-]+not[[:space:]-]+(appear[[:space:]-]+to[[:space:]-]+)?limp(ing|ed|s)?|(isn.?t|wasn.?t|doesn.?t|didn.?t)[[:space:]-]+limp(ing|ed|s)?)([^[:alpha:]]|$)'
      THEN 1 ELSE 0
    END AS has_negated_limp,
    CASE WHEN matched.comment_lower REGEXP
      '(^|[^[:alpha:]])((not|no|without)[[:space:]-]+lame(ness)?|(no|without)[[:space:]-]+(sign(s)?|evidence)[[:space:]-]+of[[:space:]-]+lame(ness)?|(is|was)[[:space:]-]+not[[:space:]-]+(appear[[:space:]-]+to[[:space:]-]+)?lame(ness)?|(isn.?t|wasn.?t)[[:space:]-]+lame(ness)?)([^[:alpha:]]|$)'
      THEN 1 ELSE 0
    END AS has_negated_lame,
    CASE WHEN matched.comment_lower REGEXP
      '(^|[^[:alpha:]])((walk(ing|ed|s)?[[:space:]-]+(fine|normal|normally|well))|((fine|normal)[[:space:]-]+(walk(ing)?|gait))|((no|without)[[:space:]-]+(difficulty|problem(s)?|trouble)[[:space:]-]+(with[[:space:]-]+)?walk(ing)?)|(not[[:space:]-]+(favour|favor)(ing|ed|s)?[[:space:]-]+(the[[:space:]-]+)?((left|right|one)[[:space:]-]+)?(leg|foot)))([^[:alpha:]]|$)'
      THEN 1 ELSE 0
    END AS has_walking_fine_phrase,
    CASE WHEN matched.comment_lower REGEXP
      '(^|[^[:alpha:]])(((favour|favor)(ing|ed|s)?[[:space:]-]+(the[[:space:]-]+)?((left|right|one)[[:space:]-]+)?(leg|foot))|((difficulty|problem(s)?|trouble)[[:space:]-]+(with[[:space:]-]+)?walk(ing)?)|((impaired|abnormal|uneven)[[:space:]-]+(walk(ing)?|gait))|(not[[:space:]-]+(weight[[:space:]-]+bearing|bearing[[:space:]-]+weight)))([^[:alpha:]]|$)'
      THEN 1 ELSE 0
    END AS has_impaired_walking_phrase
  FROM matched_resightings matched
),
resighting_classified_base AS (
  SELECT
    terms.*,
    CASE
      WHEN terms.has_limp_word = 1 AND terms.has_negated_limp = 0 THEN 1
      WHEN terms.has_lame_word = 1 AND terms.has_negated_lame = 0 THEN 1
      WHEN terms.has_impaired_walking_phrase = 1
       AND terms.has_walking_fine_phrase = 0 THEN 1
      ELSE 0
    END AS is_limp
  FROM resighting_comment_terms terms
),
resighting_classified AS (
  SELECT
    classified.*,
    CASE
      WHEN classified.is_limp = 1
        OR classified.has_negated_limp = 1
        OR classified.has_negated_lame = 1
        OR classified.has_walking_fine_phrase = 1
      THEN 1
      ELSE 0
    END AS is_walking_relevant,
    ROW_NUMBER() OVER (
      PARTITION BY classified.bird_id
      ORDER BY classified.resighting_date DESC, classified.pk DESC
    ) AS latest_rank
  FROM resighting_classified_base classified
),
resighting_days AS (
  SELECT
    bird_id,
    resighting_date,
    MAX(is_limp) AS is_limp_day
  FROM resighting_classified
  GROUP BY bird_id, resighting_date
),
resighting_summary AS (
  SELECT
    bird_id,
    MAX(resighting_date) AS last_resighting_date,
    COUNT(DISTINCT resighting_date) AS number_of_resightings,
    SUM(is_limp_day) AS limp_days,
    SUM(CASE WHEN is_limp_day = 0 THEN 1 ELSE 0 END) AS walking_fine_days
  FROM resighting_days
  GROUP BY bird_id
),
latest_resighting AS (
  SELECT
    bird_id,
    comment_text,
    is_walking_relevant
  FROM resighting_classified
  WHERE latest_rank = 1
)
SELECT
  bird.mark AS mark,
  latest_nest.nest_id AS nest_id,
  bird.sex AS sex,
  bird.cap_date AS cap_date,
  DATEDIFF(reference.reference_date, bird.cap_date) AS days_since_cap,
  DATEDIFF(
    reference.reference_date,
    summary.last_resighting_date
  ) AS days_since_last_seen,
  CASE
    WHEN summary.number_of_resightings IS NULL THEN NULL
    WHEN latest.is_walking_relevant = 1 THEN latest.comment_text
    ELSE 'walking fine'
  END AS comment_last_seen,
  COALESCE(summary.number_of_resightings, 0) AS number_of_resightings,
  CAST(summary.limp_days AS DECIMAL(20, 6))
    / NULLIF(summary.walking_fine_days, 0) AS limp_ratio
FROM tagged_birds bird
CROSS JOIN reference_setting reference
LEFT JOIN resighting_summary summary
  ON bird.bird_id = summary.bird_id
LEFT JOIN latest_resighting latest
  ON bird.bird_id = latest.bird_id
LEFT JOIN latest_nest_association latest_nest
  ON bird.bird_id = latest_nest.bird_id
LEFT JOIN latest_nest_state
  ON latest_nest.nest_id = latest_nest_state.nest_id
WHERE NOT EXISTS (
  -- A death record in CAPTURES removes the bird from the resight follow-up
  -- table once that event is on or before the active reference date.
  SELECT 1
  FROM FIELD_2026_BADOatNZ.CAPTURES dead_capture
  WHERE UPPER(TRIM(dead_capture.ring)) = bird.bird_id
    AND UPPER(TRIM(COALESCE(dead_capture.capture_status, ''))) = 'D'
    AND dead_capture.date IS NOT NULL
    AND dead_capture.date <= reference.reference_date
)
  AND (
    latest_nest.nest_id IS NULL
    OR latest_nest_state.nest_id IS NULL
    OR UPPER(TRIM(COALESCE(latest_nest_state.nest_state, ''))) <> 'NOTA'
  );


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.OVERVIEW AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
capture_summary AS (
  SELECT
    COUNT(*) AS n_capture_records,
    COUNT(CASE WHEN c.field_sex IN ('M', 'MU') THEN 1 END) AS n_males_caught,
    COUNT(CASE WHEN c.field_sex IN ('F', 'FU') THEN 1 END) AS n_females_caught,
    COUNT(CASE WHEN c.field_sex = 'U' THEN 1 END) AS n_unknown_sex_caught,
    COUNT(CASE WHEN c.age = 'C' THEN 1 END) AS n_chicks_caught,
    COUNT(DISTINCT NULLIF(TRIM(c.ring), '')) AS n_distinct_birds_caught,
    COUNT(CASE WHEN c.capture_status = 'F' THEN 1 END) AS n_first_captures,
    COUNT(CASE WHEN c.capture_status IN ('R', 'C') THEN 1 END) AS n_recaptures,
    COUNT(
      CASE WHEN NULLIF(TRIM(c.tag_id), '') IS NOT NULL THEN 1 END
    ) AS n_captures_with_tag
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.date <= sr.reference_date
),
nest_summary AS (
  SELECT
    COUNT(*) AS n_nest_visits,
    COUNT(
      DISTINCT CASE
        WHEN n.nest_id IS NOT NULL AND TRIM(n.nest_id) <> ''
        THEN TRIM(n.nest_id)
      END
    ) AS n_nests_recorded,
    COUNT(
      DISTINCT CASE
        WHEN n.nest_state = 'F'
         AND n.nest_id IS NOT NULL
         AND TRIM(n.nest_id) <> ''
        THEN TRIM(n.nest_id)
      END
    ) AS n_nests_found,
    COUNT(
      DISTINCT CASE
        WHEN n.nest_state = 'H'
         AND n.nest_id IS NOT NULL
         AND TRIM(n.nest_id) <> ''
        THEN TRIM(n.nest_id)
      END
    ) AS n_nests_hatched,
    COUNT(
      DISTINCT CASE
        WHEN n.nest_state = 'P'
         AND n.nest_id IS NOT NULL
         AND TRIM(n.nest_id) <> ''
        THEN TRIM(n.nest_id)
      END
    ) AS n_nests_predated,
    COUNT(
      DISTINCT CASE
        WHEN n.nest_state = 'D'
         AND n.nest_id IS NOT NULL
         AND TRIM(n.nest_id) <> ''
        THEN TRIM(n.nest_id)
      END
    ) AS n_nests_deserted
  FROM FIELD_2026_BADOatNZ.NESTS n
  CROSS JOIN sr
  WHERE n.date <= sr.reference_date
),
egg_summary AS (
  SELECT
    COUNT(*) AS n_egg_records,
    COUNT(
      DISTINCT CASE
        WHEN e.nest_id IS NOT NULL
         AND TRIM(e.nest_id) <> ''
         AND e.egg_id IS NOT NULL
        THEN CONCAT(TRIM(e.nest_id), '|', e.egg_id)
      END
    ) AS n_distinct_eggs,
    COUNT(
      DISTINCT CASE
        WHEN e.nest_id IS NOT NULL
         AND TRIM(e.nest_id) <> ''
         AND e.egg_id IS NOT NULL
         AND e.float_angle IS NOT NULL
         AND e.float_location IS NOT NULL
        THEN CONCAT(TRIM(e.nest_id), '|', e.egg_id)
      END
    ) AS n_eggs_floated
  FROM FIELD_2026_BADOatNZ.EGGS e
  CROSS JOIN sr
  WHERE e.date <= sr.reference_date
),
resighting_summary AS (
  SELECT
    COUNT(*) AS n_resighting_records,
    COUNT(
      DISTINCT CASE
        WHEN FIELD_2026_BADOatNZ.format_mark(
          r.UL,
          r.LL,
          r.UR,
          r.LR
        ) <> 'X-X'
        THEN FIELD_2026_BADOatNZ.format_mark(
          r.UL,
          r.LL,
          r.UR,
          r.LR
        )
      END
    ) AS n_distinct_resightings
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE r.date <= sr.reference_date
)
SELECT
  overview.section,
  overview.metric,
  overview.n
FROM (
  SELECT
    'captures' AS section,
    'n_males_caught' AS metric,
    n_males_caught AS n
  FROM capture_summary
  UNION ALL
  SELECT 'captures', 'n_females_caught', n_females_caught
  FROM capture_summary
  UNION ALL
  SELECT 'captures', 'n_unknown_sex_caught', n_unknown_sex_caught
  FROM capture_summary
  UNION ALL
  SELECT 'captures', 'n_chicks_caught', n_chicks_caught
  FROM capture_summary
  UNION ALL
  SELECT 'captures', 'n_distinct_birds_caught', n_distinct_birds_caught
  FROM capture_summary
  UNION ALL
  SELECT 'captures', 'n_capture_records', n_capture_records
  FROM capture_summary
  UNION ALL
  SELECT 'captures', 'n_first_captures', n_first_captures
  FROM capture_summary
  UNION ALL
  SELECT 'captures', 'n_recaptures', n_recaptures
  FROM capture_summary
  UNION ALL
  SELECT 'captures', 'n_captures_with_tag', n_captures_with_tag
  FROM capture_summary
  UNION ALL
  SELECT 'nests', 'n_nests_found', n_nests_found
  FROM nest_summary
  UNION ALL
  SELECT 'nests', 'n_nests_recorded', n_nests_recorded
  FROM nest_summary
  UNION ALL
  SELECT 'nests', 'n_nests_hatched', n_nests_hatched
  FROM nest_summary
  UNION ALL
  SELECT 'nests', 'n_nests_predated', n_nests_predated
  FROM nest_summary
  UNION ALL
  SELECT 'nests', 'n_nests_deserted', n_nests_deserted
  FROM nest_summary
  UNION ALL
  SELECT 'nests', 'n_nest_visits', n_nest_visits
  FROM nest_summary
  UNION ALL
  SELECT 'eggs', 'n_distinct_eggs', n_distinct_eggs
  FROM egg_summary
  UNION ALL
  SELECT 'eggs', 'n_eggs_floated', n_eggs_floated
  FROM egg_summary
  UNION ALL
  SELECT 'eggs', 'n_egg_records', n_egg_records
  FROM egg_summary
  UNION ALL
  SELECT 'resightings', 'n_distinct_resightings', n_distinct_resightings
  FROM resighting_summary
  UNION ALL
  SELECT 'resightings', 'n_resighting_records', n_resighting_records
  FROM resighting_summary
) overview;


/* test
--- TEST FAULTY VIEW
CREATE TABLE FIELD_2026_BADOatNZ._overview_fault_source (
  n INT
);

CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.OVERVIEW AS
SELECT
  'test' AS section,
  'intentional_failure' AS metric,
  n
FROM FIELD_2026_BADOatNZ._overview_fault_source;

DROP TABLE FIELD_2026_BADOatNZ._overview_fault_source;
*/
