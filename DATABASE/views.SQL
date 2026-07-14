

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
    CAST(MAX(p.days_since_laying) AS DECIMAL(5,1)) AS max_days_since_laying
  FROM FIELD_2026_BADOatNZ.predict_hatching p
  GROUP BY
    p.float_angle,
    p.float_surface,
    p.float_location
),
egg_hatch_prediction AS (
  SELECT
    e.nest_id,
    DATEDIFF(sr.reference_date, e.date) AS days_since_float,
    calibration_hatch_day.hatch_day - calibration_prediction.max_days_since_laying AS min_days_to_hatch_at_float
  FROM FIELD_2026_BADOatNZ.EGGS e
  CROSS JOIN sr
  CROSS JOIN calibration_hatch_day
  JOIN calibration_prediction
    ON e.float_angle = calibration_prediction.float_angle
   AND e.float_location = calibration_prediction.float_location
   AND e.float_surface <=> calibration_prediction.float_surface
  WHERE e.date <= sr.reference_date
    AND e.float_angle IS NOT NULL
    AND e.float_location IS NOT NULL
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
egg_prediction AS (
  SELECT
    e.nest_id,
    e.egg_id,
    e.date AS float_date,
    sr.reference_date,
    DATEDIFF(sr.reference_date, e.date) AS days_since_float,
    e.float_angle,
    e.float_surface,
    e.float_location,
    calibration_prediction.predicted_days_since_laying,
    calibration_prediction.min_days_since_laying,
    calibration_prediction.max_days_since_laying,
    calibration_hatch_day.hatch_day - calibration_prediction.predicted_days_since_laying AS days_to_hatch_at_float,
    calibration_hatch_day.hatch_day - calibration_prediction.max_days_since_laying AS min_days_to_hatch_at_float,
    calibration_hatch_day.hatch_day - calibration_prediction.min_days_since_laying AS max_days_to_hatch_at_float,
    calibration_prediction.n_calibration
  FROM FIELD_2026_BADOatNZ.EGGS e
  CROSS JOIN sr
  CROSS JOIN calibration_hatch_day
  LEFT JOIN calibration_prediction
    ON e.float_angle = calibration_prediction.float_angle
   AND e.float_location = calibration_prediction.float_location
   AND e.float_surface <=> calibration_prediction.float_surface
  WHERE e.date <= sr.reference_date
    AND e.float_angle IS NOT NULL
    AND e.float_location IS NOT NULL
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
first_nest_visit AS (
  SELECT
    nest_id,
    MIN(date) AS first_nest_date
  FROM nest_history
  GROUP BY nest_id
),
photo_summary AS (
  SELECT
    nest_id,
    MAX(date) AS last_photo_date,
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
    first_nest_visit.nest_id,
    first_nest_visit.first_nest_date,
    photo_summary.last_photo_date,
    float_summary.last_float_date,
    COALESCE(photo_summary.n_photo_rows, 0) AS n_photo_rows,
    COALESCE(float_summary.n_float_rows, 0) AS n_float_rows,
    CASE
      WHEN photo_summary.last_photo_date IS NULL THEN float_summary.last_float_date
      WHEN float_summary.last_float_date IS NULL THEN photo_summary.last_photo_date
      WHEN photo_summary.last_photo_date >= float_summary.last_float_date THEN photo_summary.last_photo_date
      ELSE float_summary.last_float_date
    END AS last_processed_date
  FROM first_nest_visit
  LEFT JOIN photo_summary
    ON first_nest_visit.nest_id = photo_summary.nest_id
  LEFT JOIN float_summary
    ON first_nest_visit.nest_id = float_summary.nest_id
),
latest_clutch_history AS (
  SELECT
    n.nest_id,
    n.clutch_size,
    n.date AS clutch_date,
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
   AND n.date <= processing_summary.last_processed_date
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
todo_untrapped_parent AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Untrapped parent' AS todo,
    CASE
      WHEN active_nests.M_mark IS NULL AND active_nests.F_mark IS NULL THEN 'catch any'
      WHEN active_nests.M_mark IS NULL THEN 'catch M'
      WHEN active_nests.F_mark IS NULL THEN 'catch F'
    END AS notes,
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
  WHERE active_nests.nest_state <> 'H'
    AND (active_nests.M_mark IS NULL OR active_nests.F_mark IS NULL)
),
todo_unprocessed_nest AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Unprocessed nest' AS todo,
    'float + photos' AS notes,
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
  WHERE active_nests.nest_state <> 'S'
    AND processing_summary.n_float_rows = 0
    AND processing_summary.n_photo_rows = 0
),
todo_reprocess_nest AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Re-process nest' AS todo,
    'clutch changed' AS notes,
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
  WHERE processing_summary.last_processed_date IS NOT NULL
    AND latest_clutch_history.clutch_date > processing_summary.last_processed_date
    AND (
      clutch_at_processing.clutch_size IS NULL
      OR latest_clutch_history.clutch_size <> clutch_at_processing.clutch_size
    )
),
todo_nest_check AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'nest check' AS todo,
    CASE
      WHEN active_nests.hatch_signs_present = 1 THEN 'hatch signs present'
      ELSE 'nest check'
    END AS notes,
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
  WHERE (
      active_nests.hatch_signs_present = 1
      AND active_nests.days_ago >= 1
    )
    OR (
      active_nests.nest_state = 'I'
      AND active_nests.min_days_to_hatch <= 10
      AND active_nests.days_ago >= 2
    )
),
todo_untrapped_brood AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Untrapped brood' AS todo,
    'no chick captures' AS notes,
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
SELECT * FROM todo_hiding_spot_photos;
