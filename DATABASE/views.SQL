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
      WHEN UR_tag_norm REGEXP '^T[BGROWLY]$'
       AND LR_raw REGEXP '^[BGROWLY]$'
      THEN CONCAT(SUBSTRING(UR_tag_norm, 2, 1), LR_raw)
      WHEN UR_tag_norm REGEXP '^[BGROWLY]$'
       AND LR_raw REGEXP '^[BGROWLY]$'
      THEN CONCAT(UR_tag_norm, LR_raw)
      WHEN COALESCE(UR_tag_norm, 'X') IN ('X', 'M')
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
)
SELECT
  candidate.site_code,
  FIELD_2026_BADOatNZ.format_mark('X', candidate.LL, 'X', candidate.LR) AS mark,
  candidate.LL,
  candidate.LR
FROM candidate_combos candidate
LEFT JOIN used_combos used
  ON candidate.LL = used.LL
 AND candidate.LR = used.LR
WHERE used.LL IS NULL;


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
    AND n.date <= sr.reference_date
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
    AND n.gps_id IS NOT NULL
    AND n.gps_point IS NOT NULL
    AND n.date <= sr.reference_date
),
capture_adult_marks AS (
  SELECT DISTINCT
    c.nest_id,
    LEFT(c.field_sex, 1) AS sex,
    FIELD_2026_BADOatNZ.format_mark(c.UL, c.LL, c.UR, c.LR) AS mark
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
    AND c.age <> 'C'
    AND c.field_sex IN ('M', 'MU', 'F', 'FU')
    AND c.date <= sr.reference_date
),
resighting_adult_marks AS (
  SELECT DISTINCT
    r.nest_id,
    LEFT(r.sex, 1) AS sex,
    CASE
      WHEN NULLIF(TRIM(r.UL), '') IS NULL
       AND NULLIF(TRIM(r.LL), '') IS NULL
       AND NULLIF(TRIM(r.UR), '') IS NULL
       AND NULLIF(TRIM(r.LR), '') IS NULL
      THEN NULL
      ELSE FIELD_2026_BADOatNZ.format_mark(
        NULLIF(TRIM(r.UL), ''),
        NULLIF(TRIM(r.LL), ''),
        NULLIF(TRIM(r.UR), ''),
        NULLIF(TRIM(r.LR), '')
      )
    END AS mark
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE r.nest_id IS NOT NULL
    AND TRIM(r.nest_id) <> ''
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
parent_marks AS (
  SELECT
    nest_id,
    GROUP_CONCAT(
      CASE WHEN sex = 'M' THEN mark END
      ORDER BY CASE WHEN sex = 'M' THEN mark END
      SEPARATOR ','
    ) AS M_mark,
    GROUP_CONCAT(
      CASE WHEN sex = 'F' THEN mark END
      ORDER BY CASE WHEN sex = 'F' THEN mark END
      SEPARATOR ','
    ) AS F_mark
  FROM nest_parent_marks
  WHERE mark IS NOT NULL
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
    DATEDIFF(sr.reference_date, e.date) AS days_since_float,
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
    egg_calibration_candidates.days_since_float,
    calibration_hatch_day.hatch_day - egg_calibration_candidates.max_days_since_laying AS min_days_to_hatch_at_float
  FROM egg_calibration_candidates
  CROSS JOIN calibration_hatch_day
  WHERE egg_calibration_candidates.row_num = 1
),
nest_hatch_prediction AS (
  SELECT
    nest_id,
    MIN(min_days_to_hatch_at_float - days_since_float) AS min_days_to_hatch
  FROM egg_hatch_prediction
  GROUP BY nest_id
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
  nest_coordinates.lon
FROM latest_visit n
LEFT JOIN latest_clutch
  ON n.nest_id = latest_clutch.nest_id
 AND latest_clutch.row_num = 1
LEFT JOIN latest_brood
  ON n.nest_id = latest_brood.nest_id
 AND latest_brood.row_num = 1
LEFT JOIN parent_marks
  ON n.nest_id = parent_marks.nest_id
LEFT JOIN nest_hatch_prediction
  ON n.nest_id = nest_hatch_prediction.nest_id
LEFT JOIN nest_coordinates
  ON n.nest_id = nest_coordinates.nest_id
 AND nest_coordinates.row_num = 1
WHERE n.row_num = 1;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
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
  days_to_hatch_at_float,
  days_to_hatch_at_float - days_since_float AS days_to_hatch,
  DATE_ADD(float_date, INTERVAL ROUND(days_to_hatch_at_float) DAY) AS predicted_hatch_date,
  min_days_to_hatch_at_float - days_since_float AS min_days_to_hatch,
  max_days_to_hatch_at_float - days_since_float AS max_days_to_hatch,
  n_calibration
FROM egg_prediction;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.TODO_LIST AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
latest_nests AS (
  SELECT
    n.*,
    sr.reference_date
  FROM FIELD_2026_BADOatNZ.NESTS_LATEST n
  CROSS JOIN sr
),
active_nests AS (
  SELECT
    n.*
  FROM latest_nests n
  WHERE n.nest_state IS NULL
    OR n.nest_state NOT IN ('pP', 'pD', 'P', 'D', 'notA')
),
nest_history AS (
  SELECT
    n.*
  FROM FIELD_2026_BADOatNZ.NESTS n
  CROSS JOIN sr
  WHERE n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
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
  WHERE nest_state IN ('F', 'I')
  GROUP BY nest_id
),
photo_summary AS (
  SELECT
    nest_id,
    MAX(date) AS last_photo_date,
    MAX(CAST(CONCAT(date, ' ', COALESCE(time_visit, '00:00:00')) AS DATETIME)) AS last_photo_datetime,
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
  WHERE e.date <= sr.reference_date
    AND e.float_angle IS NOT NULL
    AND e.float_location IS NOT NULL
  GROUP BY
    e.nest_id,
    e.date,
    COALESCE(e.time_visit, '00:00:00')
),
processed_visit_summary AS (
  SELECT
    n.nest_id,
    MAX(
      CAST(CONCAT(n.date, ' ', COALESCE(n.time_visit, '00:00:00')) AS DATETIME)
    ) AS last_processed_datetime
  FROM nest_history n
  JOIN first_processable_visit
    ON n.nest_id = first_processable_visit.nest_id
  JOIN float_visit_summary
    ON n.nest_id = float_visit_summary.nest_id
   AND n.date = float_visit_summary.float_date
   AND COALESCE(n.time_visit, '00:00:00') = float_visit_summary.float_time_visit
  WHERE (n.nest_photo = '1' OR n.tent_photo = '1')
    AND CAST(CONCAT(n.date, ' ', COALESCE(n.time_visit, '00:00:00')) AS DATETIME)
        >= first_processable_visit.first_processable_datetime
  GROUP BY n.nest_id
),
float_summary AS (
  SELECT
    float_visit_summary.nest_id,
    MAX(float_visit_summary.float_date) AS last_float_date,
    MAX(float_visit_summary.float_datetime) AS last_float_datetime,
    SUM(float_visit_summary.n_float_rows) AS n_float_rows
  FROM float_visit_summary
  GROUP BY float_visit_summary.nest_id
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
      MIN(CASE WHEN nest_state = 'F' THEN date END),
      MIN(CASE WHEN nest_state = 'I' THEN date END),
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
    CAST(CONCAT(n.date, ' ', COALESCE(n.time_visit, '00:00:00')) AS DATETIME) AS clutch_datetime,
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
latest_clutch_processing_status AS (
  SELECT
    latest_clutch_history.nest_id,
    latest_clutch_history.clutch_has_photo,
    CASE
      WHEN float_visit_summary.nest_id IS NOT NULL THEN 1
      ELSE 0
    END AS clutch_has_float
  FROM latest_clutch_history
  LEFT JOIN float_visit_summary
    ON latest_clutch_history.nest_id = float_visit_summary.nest_id
   AND latest_clutch_history.clutch_date = float_visit_summary.float_date
   AND latest_clutch_history.clutch_time_visit = float_visit_summary.float_time_visit
  WHERE latest_clutch_history.row_num = 1
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
  WHERE n.nest_state IN ('pP', 'pD', 'P', 'D')
     OR (
       n.nest_state = 'H'
       AND COALESCE(n.clutch_size, 0) = 0
       AND COALESCE(n.brood_size, 0) > 0
     )
),
chick_captures AS (
  SELECT
    c.nest_id,
    COUNT(*) AS n_chick_captures
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
    AND c.age = 'C'
    AND c.date <= sr.reference_date
  GROUP BY c.nest_id
),
hiding_spot_photos AS (
  SELECT
    r.nest_id,
    COUNT(*) AS n_hiding_spot_photos
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE r.nest_id IS NOT NULL
    AND TRIM(r.nest_id) <> ''
    AND r.rclass = 'H'
    AND r.date <= sr.reference_date
  GROUP BY r.nest_id
),
adult_capture_latest AS (
  SELECT
    x.nest_id,
    x.sex,
    x.mark,
    x.has_geo,
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
      FIELD_2026_BADOatNZ.format_mark(
        COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')),
        COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')),
        COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')),
        COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), ''))
      ) AS mark,
      CASE
        WHEN c.tag_type = 'GEO'
         AND c.tag_action IN ('D', 'S', 'N')
         AND NULLIF(TRIM(c.tag_id), '') IS NOT NULL
        THEN 1
        ELSE 0
      END AS has_geo,
      (
        CASE WHEN COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')) NOT IN ('X', 'M') THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')) NOT IN ('X', 'M') THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')) NOT IN ('X', 'M') THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')) NOT IN ('X', 'M') THEN 1 ELSE 0 END
      ) AS non_x_non_m_count,
      (
        CASE WHEN COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')) REGEXP '^[OYWBRGL]$' THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')) REGEXP '^[OYWBRGL]$' THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')) REGEXP '^[OYWBRGL]$' THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')) REGEXP '^[OYWBRGL]$' THEN 1 ELSE 0 END
      ) AS plain_colour_count,
      (
        CASE WHEN COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')) = 'M' THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')) = 'M' THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')) = 'M' THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')) = 'M' THEN 1 ELSE 0 END
      ) AS metal_count,
      ROW_NUMBER() OVER (
        PARTITION BY c.nest_id, LEFT(c.field_sex, 1)
        ORDER BY
          c.date DESC,
          COALESCE(c.released, c.caught, '00:00:00') DESC,
          c.pk DESC
      ) AS row_num
    FROM FIELD_2026_BADOatNZ.CAPTURES c
    CROSS JOIN sr
    WHERE c.nest_id IS NOT NULL
      AND TRIM(c.nest_id) <> ''
      AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
      AND c.age = 'A'
      AND c.field_sex IN ('M', 'MU', 'F', 'FU')
      AND c.date <= sr.reference_date
  ) x
  WHERE x.row_num = 1
),
adult_capture_status AS (
  SELECT
    nest_id,
    MAX(CASE WHEN sex = 'M' THEN mark END) AS M_mark_latest,
    MAX(CASE WHEN sex = 'F' THEN mark END) AS F_mark_latest,
    MAX(CASE WHEN sex = 'M' THEN has_geo END) AS M_has_geo,
    MAX(CASE WHEN sex = 'F' THEN has_geo END) AS F_has_geo,
    MAX(CASE WHEN sex = 'M' THEN is_single_colour_recruit END) AS M_single_colour_recruit,
    MAX(CASE WHEN sex = 'F' THEN is_single_colour_recruit END) AS F_single_colour_recruit
  FROM adult_capture_latest
  GROUP BY nest_id
),
adult_capture_timing AS (
  SELECT
    c.nest_id,
    LEFT(c.field_sex, 1) AS sex,
    MAX(
      CAST(
        CONCAT(
          c.date,
          ' ',
          COALESCE(c.released, c.caught, '00:00:00')
        ) AS DATETIME
      )
    ) AS last_capture_datetime
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
    AND c.age = 'A'
    AND c.field_sex IN ('M', 'MU', 'F', 'FU')
    AND c.date <= sr.reference_date
  GROUP BY
    c.nest_id,
    LEFT(c.field_sex, 1)
),
adult_capture_any_timing AS (
  SELECT
    c.nest_id,
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
    AND c.age = 'A'
    AND c.field_sex IN ('M', 'MU', 'F', 'FU', 'U')
    AND c.date <= sr.reference_date
  GROUP BY c.nest_id
),
adult_resighting_latest AS (
  SELECT
    x.nest_id,
    x.sex,
    x.mark,
    x.is_confirmed_xx
  FROM (
    SELECT
      y.*,
      ROW_NUMBER() OVER (
        PARTITION BY y.nest_id, y.sex
        ORDER BY
          y.has_informative_band_obs DESC,
          y.obs_date DESC,
          y.pk DESC
      ) AS row_num
    FROM (
      SELECT
        r.nest_id,
        LEFT(r.sex, 1) AS sex,
        r.date AS obs_date,
        r.pk,
        CASE
          WHEN NULLIF(TRIM(r.UL), '') IS NULL
           AND NULLIF(TRIM(r.LL), '') IS NULL
           AND NULLIF(TRIM(r.UR), '') IS NULL
           AND NULLIF(TRIM(r.LR), '') IS NULL
          THEN NULL
          ELSE FIELD_2026_BADOatNZ.format_mark(
            NULLIF(TRIM(r.UL), ''),
            NULLIF(TRIM(r.LL), ''),
            NULLIF(TRIM(r.UR), ''),
            NULLIF(TRIM(r.LR), '')
          )
        END AS mark,
        CASE
          WHEN COALESCE(NULLIF(TRIM(r.UL), ''), '') = 'X'
           AND COALESCE(NULLIF(TRIM(r.LL), ''), '') = 'X'
           AND COALESCE(NULLIF(TRIM(r.UR), ''), '') = 'X'
           AND COALESCE(NULLIF(TRIM(r.LR), ''), '') = 'X'
          THEN 1
          ELSE 0
        END AS is_confirmed_xx,
        CASE
          WHEN COALESCE(NULLIF(TRIM(r.UL), ''), '') = 'X'
           AND COALESCE(NULLIF(TRIM(r.LL), ''), '') = 'X'
           AND COALESCE(NULLIF(TRIM(r.UR), ''), '') = 'X'
           AND COALESCE(NULLIF(TRIM(r.LR), ''), '') = 'X'
          THEN 1
          WHEN NULLIF(TRIM(r.UL), '') IS NOT NULL AND TRIM(r.UL) <> 'X' THEN 1
          WHEN NULLIF(TRIM(r.LL), '') IS NOT NULL AND TRIM(r.LL) <> 'X' THEN 1
          WHEN NULLIF(TRIM(r.UR), '') IS NOT NULL AND TRIM(r.UR) <> 'X' THEN 1
          WHEN NULLIF(TRIM(r.LR), '') IS NOT NULL AND TRIM(r.LR) <> 'X' THEN 1
          ELSE 0
        END AS has_informative_band_obs
      FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
      CROSS JOIN sr
      WHERE r.nest_id IS NOT NULL
        AND TRIM(r.nest_id) <> ''
        AND r.age = 'A'
        AND r.sex IN ('M', 'MU', 'F', 'FU')
        AND r.date <= sr.reference_date
    ) y
  ) x
  WHERE x.row_num = 1
),
adult_resighting_status AS (
  SELECT
    nest_id,
    MAX(CASE WHEN sex = 'M' THEN mark END) AS M_mark_resight,
    MAX(CASE WHEN sex = 'F' THEN mark END) AS F_mark_resight,
    MAX(CASE WHEN sex = 'M' THEN is_confirmed_xx END) AS M_confirmed_xx,
    MAX(CASE WHEN sex = 'F' THEN is_confirmed_xx END) AS F_confirmed_xx
  FROM adult_resighting_latest
  GROUP BY nest_id
),
todo_parent_source AS (
  SELECT
    nest_id,
    MAX(M_mark) AS M_mark,
    MAX(F_mark) AS F_mark
  FROM (
    SELECT
      active_nests.nest_id,
      active_nests.M_mark,
      active_nests.F_mark
    FROM active_nests
    UNION ALL
    SELECT
      brood_followup_nests.nest_id,
      brood_followup_nests.M_mark,
      brood_followup_nests.F_mark
    FROM brood_followup_nests
    UNION ALL
    SELECT
      nota_followup_nests.nest_id,
      nota_followup_nests.M_mark,
      nota_followup_nests.F_mark
    FROM nota_followup_nests
  ) todo_parent_rows
  GROUP BY nest_id
),
adult_parent_status AS (
  SELECT
    todo_parent_source.nest_id,
    COALESCE(
      adult_capture_status.M_mark_latest,
      adult_resighting_status.M_mark_resight,
      todo_parent_source.M_mark
    ) AS M_parent_mark,
    COALESCE(
      adult_capture_status.F_mark_latest,
      adult_resighting_status.F_mark_resight,
      todo_parent_source.F_mark
    ) AS F_parent_mark,
    GREATEST(
      COALESCE(adult_capture_status.M_has_geo, 0),
      CASE
        WHEN SUBSTRING_INDEX(
               COALESCE(
                 adult_capture_status.M_mark_latest,
                 adult_resighting_status.M_mark_resight,
                 todo_parent_source.M_mark,
                 ''
               ),
               '-',
               -1
             ) REGEXP '(^|\\.)T[A-Z0-9]*(\\.|$)'
        THEN 1
        ELSE 0
      END
    ) AS M_has_geo,
    GREATEST(
      COALESCE(adult_capture_status.F_has_geo, 0),
      CASE
        WHEN SUBSTRING_INDEX(
               COALESCE(
                 adult_capture_status.F_mark_latest,
                 adult_resighting_status.F_mark_resight,
                 todo_parent_source.F_mark,
                 ''
               ),
               '-',
               -1
             ) REGEXP '(^|\\.)T[A-Z0-9]*(\\.|$)'
        THEN 1
        ELSE 0
      END
    ) AS F_has_geo,
    COALESCE(adult_capture_status.M_single_colour_recruit, 0) AS M_single_colour_recruit,
    COALESCE(adult_capture_status.F_single_colour_recruit, 0) AS F_single_colour_recruit,
    CASE
      WHEN adult_capture_status.M_mark_latest IS NULL
       AND COALESCE(adult_resighting_status.M_confirmed_xx, 0) = 1
      THEN 1
      ELSE 0
    END AS M_confirmed_unbanded,
    CASE
      WHEN adult_capture_status.F_mark_latest IS NULL
       AND COALESCE(adult_resighting_status.F_confirmed_xx, 0) = 1
      THEN 1
      ELSE 0
    END AS F_confirmed_unbanded,
    CASE
      WHEN adult_capture_status.M_mark_latest IS NULL
       AND COALESCE(
             adult_resighting_status.M_mark_resight,
             todo_parent_source.M_mark
           ) IS NULL
      THEN 1
      ELSE 0
    END AS M_unknown_status,
    CASE
      WHEN adult_capture_status.F_mark_latest IS NULL
       AND COALESCE(
             adult_resighting_status.F_mark_resight,
             todo_parent_source.F_mark
           ) IS NULL
      THEN 1
      ELSE 0
    END AS F_unknown_status
  FROM todo_parent_source
  LEFT JOIN adult_capture_status
    ON todo_parent_source.nest_id = adult_capture_status.nest_id
  LEFT JOIN adult_resighting_status
    ON todo_parent_source.nest_id = adult_resighting_status.nest_id
),
adult_capture_interval_status AS (
  SELECT
    todo_parent_source.nest_id,
    MAX(CASE WHEN adult_capture_timing.sex = 'M' THEN adult_capture_timing.last_capture_datetime END) AS M_last_capture_datetime,
    MAX(CASE WHEN adult_capture_timing.sex = 'F' THEN adult_capture_timing.last_capture_datetime END) AS F_last_capture_datetime,
    adult_capture_any_timing.last_any_adult_capture_datetime,
    CASE
      WHEN adult_capture_any_timing.last_any_adult_capture_datetime IS NULL THEN 1
      ELSE 0
    END AS no_parent_capture_yet,
    CASE
      WHEN MAX(CASE WHEN adult_capture_timing.sex = 'F' THEN adult_capture_timing.last_capture_datetime END)
           <= DATE_SUB(CAST(CONCAT(sr.reference_date, ' 08:00:00') AS DATETIME), INTERVAL 36 HOUR)
      THEN 1
      ELSE 0
    END AS M_target_capture_window_open,
    CASE
      WHEN MAX(CASE WHEN adult_capture_timing.sex = 'M' THEN adult_capture_timing.last_capture_datetime END)
           <= DATE_SUB(CAST(CONCAT(sr.reference_date, ' 08:00:00') AS DATETIME), INTERVAL 36 HOUR)
      THEN 1
      ELSE 0
    END AS F_target_capture_window_open
  FROM todo_parent_source
  CROSS JOIN sr
  LEFT JOIN adult_capture_timing
    ON todo_parent_source.nest_id = adult_capture_timing.nest_id
  LEFT JOIN adult_capture_any_timing
    ON todo_parent_source.nest_id = adult_capture_any_timing.nest_id
  GROUP BY
    todo_parent_source.nest_id,
    adult_capture_any_timing.last_any_adult_capture_datetime
),
todo_untrapped_parent_candidate AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Untrapped parent' AS todo,
    CASE
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_confirmed_unbanded = 1 THEN 'target any (both X-X)'
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_has_geo = 1 THEN 'target M (X-X mate of GEO bird)'
      WHEN adult_parent_status.F_confirmed_unbanded = 1
       AND adult_parent_status.M_has_geo = 1 THEN 'target F (X-X mate of GEO bird)'
      WHEN adult_parent_status.M_unknown_status = 1
       AND adult_parent_status.F_has_geo = 1 THEN 'target M (unknown mate of GEO bird)'
      WHEN adult_parent_status.F_unknown_status = 1
       AND adult_parent_status.M_has_geo = 1 THEN 'target F (unknown mate of GEO bird)'
      WHEN adult_parent_status.M_confirmed_unbanded = 1 THEN 'target M (X-X)'
      WHEN adult_parent_status.F_confirmed_unbanded = 1 THEN 'target F (X-X)'
      WHEN adult_parent_status.M_unknown_status = 1
       AND adult_parent_status.F_unknown_status = 1 THEN 'target any (status unknown)'
      WHEN adult_parent_status.M_unknown_status = 1 THEN 'target M (status unknown)'
      WHEN adult_parent_status.F_unknown_status = 1 THEN 'target F (status unknown)'
      WHEN adult_parent_status.M_has_geo = 1
       AND adult_parent_status.F_has_geo = 0 THEN 'target F (non-GEO mate)'
      WHEN adult_parent_status.F_has_geo = 1
       AND adult_parent_status.M_has_geo = 0 THEN 'target M (non-GEO mate)'
      WHEN adult_parent_status.M_single_colour_recruit = 1
       AND adult_parent_status.F_single_colour_recruit = 1 THEN 'target any recruit for full colour marks'
      WHEN adult_parent_status.M_single_colour_recruit = 1 THEN 'target M recruit for full colour marks'
      WHEN adult_parent_status.F_single_colour_recruit = 1 THEN 'target F recruit for full colour marks'
    END AS notes,
    CASE
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
      WHEN adult_parent_status.M_has_geo = 1
       AND adult_parent_status.F_has_geo = 0 THEN 'F'
      WHEN adult_parent_status.F_has_geo = 1
       AND adult_parent_status.M_has_geo = 0 THEN 'M'
      WHEN adult_parent_status.M_single_colour_recruit = 1
       AND adult_parent_status.F_single_colour_recruit = 1 THEN 'A'
      WHEN adult_parent_status.M_single_colour_recruit = 1 THEN 'M'
      WHEN adult_parent_status.F_single_colour_recruit = 1 THEN 'F'
    END AS target_parent,
    DATEDIFF(
      active_nests.reference_date,
      COALESCE(nest_discovery.first_found_date, active_nests.reference_date)
    ) AS days_overdue,
    350
      + DATEDIFF(
          active_nests.reference_date,
          COALESCE(nest_discovery.first_found_date, active_nests.reference_date)
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
    adult_capture_interval_status.no_parent_capture_yet,
    adult_capture_interval_status.M_target_capture_window_open,
    adult_capture_interval_status.F_target_capture_window_open,
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  LEFT JOIN adult_parent_status
    ON active_nests.nest_id = adult_parent_status.nest_id
  LEFT JOIN adult_capture_interval_status
    ON active_nests.nest_id = adult_capture_interval_status.nest_id
  LEFT JOIN nest_discovery
    ON active_nests.nest_id = nest_discovery.nest_id
  WHERE active_nests.nest_state IN ('F', 'I')
    AND (
      adult_parent_status.M_confirmed_unbanded = 1
      OR adult_parent_status.F_confirmed_unbanded = 1
      OR adult_parent_status.M_unknown_status = 1
      OR adult_parent_status.F_unknown_status = 1
      OR (adult_parent_status.M_has_geo = 1 AND adult_parent_status.F_has_geo = 0)
      OR (adult_parent_status.F_has_geo = 1 AND adult_parent_status.M_has_geo = 0)
      OR adult_parent_status.M_single_colour_recruit = 1
      OR adult_parent_status.F_single_colour_recruit = 1
    )
),
todo_untrapped_parent AS (
  SELECT
    nest_id,
    reference_date,
    todo,
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
  FROM todo_untrapped_parent_candidate
  WHERE (
      target_parent = 'A'
      AND COALESCE(no_parent_capture_yet, 0) = 1
    )
     OR (
      target_parent = 'M'
      AND (
        COALESCE(no_parent_capture_yet, 0) = 1
        OR COALESCE(M_target_capture_window_open, 0) = 1
      )
    )
     OR (
      target_parent = 'F'
      AND (
        COALESCE(no_parent_capture_yet, 0) = 1
        OR COALESCE(F_target_capture_window_open, 0) = 1
      )
    )
),
todo_unprocessed_nest AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Unprocessed nest' AS todo,
    CASE
      WHEN processing_summary.n_float_rows = 0
       AND processing_summary.n_photo_rows = 0 THEN 'float + photos'
      WHEN processing_summary.n_float_rows = 0 THEN 'float only'
      WHEN processing_summary.n_photo_rows = 0 THEN 'photos only'
    END AS notes,
    DATEDIFF(active_nests.reference_date, processing_summary.first_processable_date) AS days_overdue,
    200 + DATEDIFF(active_nests.reference_date, processing_summary.first_processable_date) AS priority,
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
  WHERE active_nests.nest_state IN ('F', 'I')
    AND (
      processing_summary.n_float_rows = 0
      OR processing_summary.n_photo_rows = 0
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
  WHERE active_nests.nest_state = 'S'
    AND COALESCE(photo_summary.n_photo_rows, 0) = 0
),
todo_reprocess_nest AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Re-process nest' AS todo,
    CASE
      WHEN COALESCE(latest_clutch_processing_status.clutch_has_float, 0) = 0
       AND COALESCE(latest_clutch_processing_status.clutch_has_photo, 0) = 0 THEN 'float + photos'
      WHEN COALESCE(latest_clutch_processing_status.clutch_has_float, 0) = 0 THEN 'float only'
      WHEN COALESCE(latest_clutch_processing_status.clutch_has_photo, 0) = 0 THEN 'photos only'
      ELSE 'clutch increased'
    END AS notes,
    DATEDIFF(active_nests.reference_date, latest_clutch_history.clutch_date) AS days_overdue,
    250 + DATEDIFF(active_nests.reference_date, latest_clutch_history.clutch_date) AS priority,
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
  LEFT JOIN adult_parent_status
    ON active_nests.nest_id = adult_parent_status.nest_id
  WHERE processing_summary.last_processed_datetime IS NOT NULL
    AND active_nests.nest_state IN ('F', 'I')
    AND COALESCE(active_nests.brood_size, 0) = 0
    AND latest_clutch_history.clutch_datetime > processing_summary.last_processed_datetime
    AND clutch_at_processing.clutch_size IS NOT NULL
    AND latest_clutch_history.clutch_size > clutch_at_processing.clutch_size
),
nest_check_rules AS (
  SELECT
    20 AS start_day_after_completion,
    2 AS repeat_interval_days
),
nest_check_target_nests AS (
  SELECT
    nest_id
  FROM active_nests
  WHERE nest_state = 'I'
),
nest_check_schedule AS (
  SELECT
    e.nest_id,
    MAX(
      DATE_SUB(
        e.float_date,
        INTERVAL ROUND(e.predicted_days_since_laying) DAY
      )
    ) AS estimated_clutch_completion_date
  FROM FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION e
  JOIN nest_check_target_nests
    ON e.nest_id = nest_check_target_nests.nest_id
  GROUP BY e.nest_id
),
todo_nest_check AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'nest check' AS todo,
    CASE
      WHEN active_nests.hatch_signs_present = 1 THEN 'hatch signs present'
      ELSE 'pre-hatch nest check'
    END AS notes,
    CASE
      WHEN active_nests.hatch_signs_present = 1 THEN GREATEST(0, active_nests.days_ago - 1)
      ELSE GREATEST(0, active_nests.days_ago - nest_check_rules.repeat_interval_days)
    END AS days_overdue,
    CASE
      WHEN active_nests.hatch_signs_present = 1 THEN
        500 + GREATEST(0, active_nests.days_ago - 1)
      ELSE
        300
        + GREATEST(0, active_nests.days_ago - nest_check_rules.repeat_interval_days)
        + GREATEST(
            0,
            DATEDIFF(
              active_nests.reference_date,
              nest_check_schedule.estimated_clutch_completion_date
            ) - nest_check_rules.start_day_after_completion
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
  LEFT JOIN nest_check_schedule
    ON active_nests.nest_id = nest_check_schedule.nest_id
  LEFT JOIN adult_parent_status
    ON active_nests.nest_id = adult_parent_status.nest_id
  WHERE (active_nests.clutch_size IS NULL OR active_nests.clutch_size > 0)
    AND (
      (
        active_nests.hatch_signs_present = 1
        AND active_nests.days_ago >= 1
      )
      OR (
        active_nests.nest_state = 'I'
        AND nest_check_schedule.estimated_clutch_completion_date IS NOT NULL
        AND DATEDIFF(
              active_nests.reference_date,
              nest_check_schedule.estimated_clutch_completion_date
            ) >= nest_check_rules.start_day_after_completion
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
    brood_followup_nests.min_days_to_hatch,
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
),
todo_hiding_spot_photos AS (
  SELECT
    brood_followup_nests.nest_id,
    brood_followup_nests.reference_date,
    'Hiding spot photos needed' AS todo,
    'need H resightings' AS notes,
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
    brood_followup_nests.min_days_to_hatch,
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
  LEFT JOIN adult_parent_status
    ON brood_followup_nests.nest_id = adult_parent_status.nest_id
  WHERE DATEDIFF(
          brood_followup_nests.reference_date,
          brood_followup_nests.hatch_date
        ) BETWEEN 1 AND 6
    AND COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0) = 0
),
todo_nota_nest_check AS (
  SELECT
    nota_followup_nests.nest_id,
    nota_followup_nests.reference_date,
    'notA nest-check' AS todo,
    CASE
      WHEN nota_followup_nests.nest_state IN ('pP', 'pD')
      THEN 'confirm fate + remove nest marks'
      WHEN nota_followup_nests.nest_state = 'H'
       AND COALESCE(nota_followup_nests.clutch_size, 0) = 0
       AND COALESCE(nota_followup_nests.brood_size, 0) > 0
      THEN 'brood away; remove nest marks + enter notA'
      ELSE 'remove nest marks + enter notA'
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
  CASE
    WHEN t.todo = 'Untrapped parent'
     AND t.min_days_to_hatch IS NOT NULL
     AND CEILING(t.min_days_to_hatch) <= 5
    THEN CONCAT(GREATEST(0, CEILING(t.min_days_to_hatch)), ' to H')
    WHEN t.todo = 'Untrapped parent'
    THEN CONCAT(COALESCE(t.days_overdue, 0), ' since F')
    ELSE CAST(t.days_overdue AS CHAR)
  END AS overdue_label
FROM (
  SELECT * FROM todo_untrapped_parent
  UNION ALL
  SELECT * FROM todo_unprocessed_nest
  UNION ALL
  SELECT * FROM todo_take_scrape_photos
  UNION ALL
  SELECT * FROM todo_reprocess_nest
  UNION ALL
  SELECT * FROM todo_nest_check
  UNION ALL
  SELECT * FROM todo_untrapped_brood
  UNION ALL
  SELECT * FROM todo_hiding_spot_photos
  UNION ALL
  SELECT * FROM todo_nota_nest_check
) t;


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


/*
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
