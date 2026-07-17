CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE AS

SELECT
ring,
UL,
  LL,
  UR,
  LR,
  FIELD_2026_BADOatNZ.format_mark(UL, LL, UR, LR) AS mark,
date,
study_year,
site_code,
capture_status,
latitude,
longitude,
field_sex,
age,
tarsus,
culmen,
wing,
weight,
moult_left,
tag_id,
tag_type
FROM BADOatNZ.CAPTURES;


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
    AND c.age <> 'C'
    AND c.field_sex IN ('M', 'MU', 'F', 'FU')
    AND c.date <= sr.reference_date
),
capture_marks AS (
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
  FROM capture_adult_marks
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
    ABS(e.float_angle - calibration_prediction.float_angle) AS angle_diff,
    CASE
      WHEN e.float_surface IS NULL AND calibration_prediction.float_surface IS NULL THEN 0
      WHEN e.float_surface IS NULL OR calibration_prediction.float_surface IS NULL THEN 9999
      ELSE ABS(e.float_surface - calibration_prediction.float_surface)
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
        ABS(e.float_angle - calibration_prediction.float_angle),
        CASE
          WHEN e.float_surface IS NULL AND calibration_prediction.float_surface IS NULL THEN 0
          WHEN e.float_surface IS NULL OR calibration_prediction.float_surface IS NULL THEN 9999
          ELSE ABS(e.float_surface - calibration_prediction.float_surface)
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
  capture_marks.M_mark,
  capture_marks.F_mark,
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
LEFT JOIN capture_marks
  ON n.nest_id = capture_marks.nest_id
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
    ABS(e.float_angle - calibration_prediction.float_angle) AS angle_diff,
    CASE
      WHEN e.float_surface IS NULL AND calibration_prediction.float_surface IS NULL THEN 0
      WHEN e.float_surface IS NULL OR calibration_prediction.float_surface IS NULL THEN 9999
      ELSE ABS(e.float_surface - calibration_prediction.float_surface)
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
        ABS(e.float_angle - calibration_prediction.float_angle),
        CASE
          WHEN e.float_surface IS NULL AND calibration_prediction.float_surface IS NULL THEN 0
          WHEN e.float_surface IS NULL OR calibration_prediction.float_surface IS NULL THEN 9999
          ELSE ABS(e.float_surface - calibration_prediction.float_surface)
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
active_nests AS (
  SELECT
    n.*,
    sr.reference_date
  FROM FIELD_2026_BADOatNZ.NESTS_LATEST n
  CROSS JOIN sr
  WHERE n.nest_state IS NULL
    OR n.nest_state NOT IN ('P', 'D', 'notA')
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
    MIN(date) AS first_processable_date
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
float_summary AS (
  SELECT
    e.nest_id,
    MAX(e.date) AS last_float_date,
    MAX(CAST(CONCAT(e.date, ' ', COALESCE(e.time_visit, '00:00:00')) AS DATETIME)) AS last_float_datetime,
    COUNT(*) AS n_float_rows
  FROM FIELD_2026_BADOatNZ.EGGS e
  CROSS JOIN sr
  WHERE e.date <= sr.reference_date
    AND e.float_angle IS NOT NULL
    AND e.float_location IS NOT NULL
  GROUP BY e.nest_id
),
processing_summary AS (
  SELECT
    first_processable_visit.nest_id,
    first_processable_visit.first_processable_date,
    photo_summary.last_photo_date,
    photo_summary.last_photo_datetime,
    float_summary.last_float_date,
    float_summary.last_float_datetime,
    COALESCE(photo_summary.n_photo_rows, 0) AS n_photo_rows,
    COALESCE(float_summary.n_float_rows, 0) AS n_float_rows,
    CASE
      WHEN COALESCE(photo_summary.n_photo_rows, 0) > 0
       AND COALESCE(float_summary.n_float_rows, 0) > 0
      THEN GREATEST(photo_summary.last_photo_datetime, float_summary.last_float_datetime)
      ELSE NULL
    END AS last_processed_datetime
  FROM first_processable_visit
  LEFT JOIN photo_summary
    ON first_processable_visit.nest_id = photo_summary.nest_id
  LEFT JOIN float_summary
    ON first_processable_visit.nest_id = float_summary.nest_id
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
    CAST(CONCAT(n.date, ' ', COALESCE(n.time_visit, '00:00:00')) AS DATETIME) AS clutch_datetime,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
    ) AS row_num
  FROM nest_history n
  WHERE n.clutch_size IS NOT NULL
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
chick_captures AS (
  SELECT
    c.nest_id,
    COUNT(*) AS n_chick_captures
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
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
          COALESCE(c.released, c.caught, c.cap_start, '00:00:00') DESC,
          c.pk DESC
      ) AS row_num
    FROM FIELD_2026_BADOatNZ.CAPTURES c
    CROSS JOIN sr
    WHERE c.nest_id IS NOT NULL
      AND TRIM(c.nest_id) <> ''
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
adult_parent_status AS (
  SELECT
    active_nests.nest_id,
    COALESCE(
      adult_capture_status.M_mark_latest,
      adult_resighting_status.M_mark_resight,
      active_nests.M_mark
    ) AS M_parent_mark,
    COALESCE(
      adult_capture_status.F_mark_latest,
      adult_resighting_status.F_mark_resight,
      active_nests.F_mark
    ) AS F_parent_mark,
    COALESCE(adult_capture_status.M_has_geo, 0) AS M_has_geo,
    COALESCE(adult_capture_status.F_has_geo, 0) AS F_has_geo,
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
       AND COALESCE(adult_resighting_status.M_mark_resight, active_nests.M_mark) IS NULL
      THEN 1
      ELSE 0
    END AS M_unknown_status,
    CASE
      WHEN adult_capture_status.F_mark_latest IS NULL
       AND COALESCE(adult_resighting_status.F_mark_resight, active_nests.F_mark) IS NULL
      THEN 1
      ELSE 0
    END AS F_unknown_status
  FROM active_nests
  LEFT JOIN adult_capture_status
    ON active_nests.nest_id = adult_capture_status.nest_id
  LEFT JOIN adult_resighting_status
    ON active_nests.nest_id = adult_resighting_status.nest_id
),
todo_untrapped_parent AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Untrapped parent' AS todo,
    CASE
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_confirmed_unbanded = 1 THEN 'catch any (both X-X)'
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_has_geo = 1 THEN 'catch M (X-X mate of GEO bird)'
      WHEN adult_parent_status.F_confirmed_unbanded = 1
       AND adult_parent_status.M_has_geo = 1 THEN 'catch F (X-X mate of GEO bird)'
      WHEN adult_parent_status.M_unknown_status = 1
       AND adult_parent_status.F_has_geo = 1 THEN 'catch M (unknown mate of GEO bird)'
      WHEN adult_parent_status.F_unknown_status = 1
       AND adult_parent_status.M_has_geo = 1 THEN 'catch F (unknown mate of GEO bird)'
      WHEN adult_parent_status.M_confirmed_unbanded = 1 THEN 'catch M (X-X)'
      WHEN adult_parent_status.F_confirmed_unbanded = 1 THEN 'catch F (X-X)'
      WHEN adult_parent_status.M_unknown_status = 1
       AND adult_parent_status.F_unknown_status = 1 THEN 'catch any (status unknown)'
      WHEN adult_parent_status.M_unknown_status = 1 THEN 'catch M (status unknown)'
      WHEN adult_parent_status.F_unknown_status = 1 THEN 'catch F (status unknown)'
      WHEN adult_parent_status.M_has_geo = 1
       AND adult_parent_status.F_has_geo = 0 THEN 'catch F (non-GEO mate)'
      WHEN adult_parent_status.F_has_geo = 1
       AND adult_parent_status.M_has_geo = 0 THEN 'catch M (non-GEO mate)'
      WHEN adult_parent_status.M_single_colour_recruit = 1
       AND adult_parent_status.F_single_colour_recruit = 1 THEN 'catch any recruit for full colour marks'
      WHEN adult_parent_status.M_single_colour_recruit = 1 THEN 'catch M recruit for full colour marks'
      WHEN adult_parent_status.F_single_colour_recruit = 1 THEN 'catch F recruit for full colour marks'
    END AS notes,
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
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  LEFT JOIN adult_parent_status
    ON active_nests.nest_id = adult_parent_status.nest_id
  LEFT JOIN nest_discovery
    ON active_nests.nest_id = nest_discovery.nest_id
  WHERE active_nests.nest_state <> 'H'
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
    active_nests.M_mark,
    active_nests.F_mark,
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  JOIN processing_summary
    ON active_nests.nest_id = processing_summary.nest_id
  WHERE active_nests.nest_state IN ('F', 'I')
    AND (
      processing_summary.n_float_rows = 0
      OR processing_summary.n_photo_rows = 0
    )
),
todo_reprocess_nest AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Re-process nest' AS todo,
    'clutch increased' AS notes,
    DATEDIFF(active_nests.reference_date, latest_clutch_history.clutch_date) AS days_overdue,
    250 + DATEDIFF(active_nests.reference_date, latest_clutch_history.clutch_date) AS priority,
    active_nests.min_days_to_hatch,
    active_nests.days_ago AS last_visit_days_ago,
    active_nests.nest_state,
    active_nests.clutch_size,
    active_nests.brood_size,
    active_nests.M_mark,
    active_nests.F_mark,
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  JOIN processing_summary
    ON active_nests.nest_id = processing_summary.nest_id
  JOIN latest_clutch_history
    ON active_nests.nest_id = latest_clutch_history.nest_id
   AND latest_clutch_history.row_num = 1
  LEFT JOIN clutch_at_processing
    ON active_nests.nest_id = clutch_at_processing.nest_id
   AND clutch_at_processing.row_num = 1
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
    active_nests.M_mark,
    active_nests.F_mark,
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  CROSS JOIN nest_check_rules
  LEFT JOIN nest_check_schedule
    ON active_nests.nest_id = nest_check_schedule.nest_id
  WHERE (
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
),
todo_untrapped_brood AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Untrapped brood' AS todo,
    'no chick captures' AS notes,
    DATEDIFF(active_nests.reference_date, hatched_nests.hatch_date) AS days_overdue,
    450 + DATEDIFF(active_nests.reference_date, hatched_nests.hatch_date) AS priority,
    active_nests.min_days_to_hatch,
    active_nests.days_ago AS last_visit_days_ago,
    active_nests.nest_state,
    active_nests.clutch_size,
    active_nests.brood_size,
    active_nests.M_mark,
    active_nests.F_mark,
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  JOIN hatched_nests
    ON active_nests.nest_id = hatched_nests.nest_id
  LEFT JOIN chick_captures
    ON active_nests.nest_id = chick_captures.nest_id
  WHERE active_nests.nest_state = 'H'
    AND COALESCE(chick_captures.n_chick_captures, 0) = 0
),
todo_hiding_spot_photos AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Hiding spot photos needed' AS todo,
    'need H observations' AS notes,
    GREATEST(0, DATEDIFF(active_nests.reference_date, hatched_nests.hatch_date) - 1) AS days_overdue,
    400 + GREATEST(0, DATEDIFF(active_nests.reference_date, hatched_nests.hatch_date) - 1) AS priority,
    active_nests.min_days_to_hatch,
    active_nests.days_ago AS last_visit_days_ago,
    active_nests.nest_state,
    active_nests.clutch_size,
    active_nests.brood_size,
    active_nests.M_mark,
    active_nests.F_mark,
    active_nests.lat,
    active_nests.lon
  FROM active_nests
  JOIN hatched_nests
    ON active_nests.nest_id = hatched_nests.nest_id
  LEFT JOIN hiding_spot_photos
    ON active_nests.nest_id = hiding_spot_photos.nest_id
  WHERE DATEDIFF(active_nests.reference_date, hatched_nests.hatch_date) BETWEEN 1 AND 6
    AND COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0) = 0
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
  SELECT * FROM todo_reprocess_nest
  UNION ALL
  SELECT * FROM todo_nest_check
  UNION ALL
  SELECT * FROM todo_untrapped_brood
  UNION ALL
  SELECT * FROM todo_hiding_spot_photos
) t;
