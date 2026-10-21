/*
  CAPTURES_ARCHIVE is a compatibility layer for historic BADOatNZ records.
  It is deliberately kept separate from the current-season CAPTURES logic:
  the available-combo audit uses it as released-mark history, while current
  task generation uses FIELD_2026_BADOatNZ.CAPTURES directly. The historic
  schema dependency must therefore be checked during deployment rather than
  folded into TODO_LIST.
*/

/*
  The refresh-status table is a small operational health boundary, not a
  biological data source. A new row is written when a snapshot build starts
  and marked succeeded only after publication and cleanup complete. If an
  Adminer/client connection dies mid-refresh, the last row remains running,
  allowing the app to warn that the published task rows may be stale.
*/
CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS (
  refresh_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  reference_date DATE NOT NULL,
  state VARCHAR(16) NOT NULL,
  started_at DATETIME NOT NULL,
  completed_at DATETIME NULL,
  task_row_count BIGINT NULL,
  PRIMARY KEY (refresh_id),
  INDEX idx_todo_refresh_status_date (reference_date, refresh_id)
);

CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE AS

SELECT
  c.ring,
  c.UL,
  CASE
    WHEN REPLACE(UPPER(TRIM(c.ring)), '-', '') = 'CP19817' THEN 'YO'
    ELSE c.LL
  END AS LL,
  c.UR,
  CASE
    WHEN REPLACE(UPPER(TRIM(c.ring)), '-', '') = 'CP19817' THEN 'GR'
    ELSE c.LR
  END AS LR,
  FIELD_2026_BADOatNZ.format_mark(
    c.UL,
    CASE
      WHEN REPLACE(UPPER(TRIM(c.ring)), '-', '') = 'CP19817' THEN 'YO'
      ELSE c.LL
    END,
    c.UR,
    CASE
      WHEN REPLACE(UPPER(TRIM(c.ring)), '-', '') = 'CP19817' THEN 'GR'
      ELSE c.LR
    END
  ) AS mark,
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
  GROUP BY BADOatNZ.SEX.ring
) sex_lookup
  ON TRIM(c.ring) = sex_lookup.ring;


/*
  USED_COMBOS_DETAIL is the audit layer for colour-combination availability.
  It combines historic released marks, current CAPTURES input, and current
  RESIGHTINGS input before normalising them. Source/stage provenance is kept
  so AVAILABLE_COMBOS can exclude a mark occupied in any part of the history.

  CTE roles: sr = reference-date gate; historical_used_marks = historic
  release evidence; current_used_marks_release = current release evidence;
  current_used_marks_input = current input evidence; used_marks_raw = union;
  used_marks_prepped = trim/uppercase cleanup; used_marks_normalized = the
  final normalised occupancy classification.
*/
CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
historical_used_marks AS (
  SELECT
    CONVERT('CAPTURES_ARCHIVE' USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS source_table,
    CONVERT('release' USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS source_stage,
    CONVERT(NULLIF(TRIM(ca.ring), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS ring,
    ca.date AS date_,
    CONVERT(ca.capture_status USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS capture_status,
    CONVERT(NULLIF(UPPER(TRIM(ca.UL)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS UL_raw,
    CONVERT(NULLIF(UPPER(TRIM(ca.LL)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS LL_raw,
    CONVERT(NULLIF(UPPER(TRIM(ca.UR)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS UR_raw,
    CONVERT(NULLIF(UPPER(TRIM(ca.LR)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS LR_raw
  FROM FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE ca
  CROSS JOIN sr
  WHERE ca.date <= sr.reference_date
     OR ca.date IS NULL
),
current_used_marks_release AS (
  SELECT
    CONVERT('CAPTURES' USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS source_table,
    CONVERT('release' USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS source_stage,
    CONVERT(NULLIF(TRIM(c.ring), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS ring,
    c.date AS date_,
    CONVERT(c.capture_status USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS capture_status,
    CONVERT(NULLIF(UPPER(TRIM(c.UL)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS UL_raw,
    CONVERT(NULLIF(UPPER(TRIM(c.LL)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS LL_raw,
    CONVERT(NULLIF(UPPER(TRIM(c.UR)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS UR_raw,
    CONVERT(NULLIF(UPPER(TRIM(c.LR)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS LR_raw
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.date <= sr.reference_date
     OR c.date IS NULL
),
current_used_marks_input AS (
  SELECT
    CONVERT('CAPTURES' USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS source_table,
    CONVERT('input' USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS source_stage,
    CONVERT(NULLIF(TRIM(c.ring), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS ring,
    c.date AS date_,
    CONVERT(c.capture_status USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS capture_status,
    CONVERT(NULLIF(UPPER(TRIM(c.UL_in)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS UL_raw,
    CONVERT(NULLIF(UPPER(TRIM(c.LL_in)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS LL_raw,
    CONVERT(NULLIF(UPPER(TRIM(c.UR_in)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS UR_raw,
    CONVERT(NULLIF(UPPER(TRIM(c.LR_in)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS LR_raw
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


/*
  AVAILABLE_COMBOS turns site rules into a deterministic supply list. The
  candidate combinations are generated first, then occupied combinations are
  removed, and only then are marks ranked for fieldworker/team use.

  CTE roles: sr = fail-closed reference-date guard; colours = allowed single
  colours; lr_pairs = lower-right pairs; site_rules = permitted site/left-leg
  combinations; candidate_combos = valid candidates; used_combos = occupied
  candidates; available_combos_ranked = deterministic ordering and rank used
  by the PDF Team marks table.
*/
CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.AVAILABLE_COMBOS AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
colours AS (
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
  CROSS JOIN sr
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
     AND available_combos_ranked.LL IN ('BY', 'WY', 'YY', 'YO', 'OY') THEN 'CR'
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


/*
  NESTS_LATEST is the positive-nest operational snapshot. It selects the
  latest dated CR event as the current state while retaining historical
  evidence needed for parent identity, hatch timing, and a valid coordinate.

  CTE roles: sr = reference date; latest_visit = current event; nest_state_summary
  = historical F/I/PP/PD evidence; latest_clutch/latest_brood = latest non-null
  clutch/brood values; nest_coordinates = deterministic GPS fallback;
  capture_adult_marks/resighting_adult_marks = parent identity observations;
  nest_parent_marks/parent_mark_candidates/parent_mark_ranked/parent_marks =
  one display mark per sex; calibration_hatch_day/calibration_prediction =
  hatch calibration; egg_calibration_candidates/egg_hatch_prediction = float
  conversion; latest_float_prediction/nest_hatch_prediction = latest estimate.
*/
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
    c.date AS capture_date,
    CASE
      WHEN UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')))
             IN ('X', 'XX')
      THEN 'X'
      ELSE UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')))
    END AS UL_norm,
    CASE
      WHEN UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))
             IN ('X', 'XX')
      THEN 'X'
      ELSE UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))
    END AS LL_norm,
    CASE
      WHEN UPPER(COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')))
             IN ('X', 'XX')
      THEN 'X'
      ELSE UPPER(COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')))
    END AS UR_norm,
    CASE
      WHEN UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')))
             IN ('X', 'XX')
      THEN 'X'
      ELSE UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')))
    END AS LR_norm,
    CASE
      WHEN UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))
             IN ('X', 'XX')
       AND UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')))
             IN ('X', 'XX')
      THEN 'X-X'
      WHEN UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')))
               NOT REGEXP '^(X+|M)$'
        OR UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))
               NOT REGEXP '^(X+|M)$'
        OR UPPER(COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')))
               NOT REGEXP '^(X+|M)$'
        OR UPPER(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')))
               NOT REGEXP '^(X+|M)$'
      THEN FIELD_2026_BADOatNZ.format_mark(
        COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')),
        COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')),
        COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')),
        COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), ''))
      )
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
resighting_adult_observations AS (
  SELECT
    r.nest_id,
    LEFT(r.sex, 1) AS observed_sex,
    r.date AS observation_date,
    r.pk,
    CASE
      WHEN UPPER(NULLIF(TRIM(r.UL), '')) IN ('X', 'XX') THEN 'X'
      ELSE UPPER(NULLIF(TRIM(r.UL), ''))
    END AS UL_norm,
    CASE
      WHEN UPPER(NULLIF(TRIM(r.LL), '')) IN ('X', 'XX') THEN 'X'
      ELSE UPPER(NULLIF(TRIM(r.LL), ''))
    END AS LL_norm,
    CASE
      WHEN UPPER(NULLIF(TRIM(r.UR), '')) IN ('X', 'XX') THEN 'X'
      ELSE UPPER(NULLIF(TRIM(r.UR), ''))
    END AS UR_norm,
    CASE
      WHEN UPPER(NULLIF(TRIM(r.LR), '')) IN ('X', 'XX') THEN 'X'
      ELSE UPPER(NULLIF(TRIM(r.LR), ''))
    END AS LR_norm,
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
resighting_adult_resolved_sex AS (
  SELECT
    raw.nest_id,
    CASE
      WHEN COUNT(DISTINCT captured.sex) = 1
      THEN MAX(captured.sex)
      ELSE raw.observed_sex
    END AS sex,
    raw.mark
  FROM resighting_adult_observations raw
  LEFT JOIN capture_adult_marks captured
    ON captured.nest_id = raw.nest_id
   AND captured.capture_date <= raw.observation_date
   AND captured.mark IS NOT NULL
   AND (
     (
       captured.LL_norm IS NOT NULL
       AND captured.LR_norm IS NOT NULL
       AND captured.LL_norm = raw.LL_norm
       AND captured.LR_norm = raw.LR_norm
     )
     OR CONVERT(UPPER(TRIM(captured.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci = CONVERT(UPPER(TRIM(raw.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci
   )
  WHERE raw.mark IS NOT NULL
  GROUP BY raw.nest_id, raw.observed_sex, raw.mark, raw.observation_date, raw.pk
),
resighting_adult_marks AS (
  SELECT DISTINCT nest_id, sex, mark
  FROM resighting_adult_resolved_sex
),
nest_parent_marks AS (
  SELECT nest_id, sex, CONVERT(mark USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS mark
  FROM capture_adult_marks
  UNION
  SELECT nest_id, sex, CONVERT(mark USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS mark
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
  n.reference_date,
  n.species,
  n.site,
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

  The association is conservative: a direct nest_id wins; an unlinked H row
  may use one same-GPS adult nest or one unambiguous preceding chick capture
  by ring. Multiple candidate nests remain unresolved so a photo task cannot
  be silently cleared for the wrong family.

  CTE roles: sr = reference-date gate; h_events = valid H rows and ring keys;
  same_occasion_adult_candidates/summary = same-date same-GPS adult evidence;
  ring_capture_candidates = prior age-C capture history; and
  latest_ring_capture_datetime/summary = latest capture and ambiguity status.
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

  Location and label colour are separate concepts: the latest valid age-C GPS
  event controls a brood's displayed location, while the earliest qualifying
  chick capture controls its assigned band-colour label. This preserves the
  fieldwork interpretation when chicks later move or mix.

  CTE roles: sr = reference date; positive_history/status = positive history
  and hatch evidence; positive_chick_status = age-C evidence; positive_locations
  = positive GPS fallback; negative_encounters/ranked/discovery = mobile brood
  discovery; chick_events/ranked/direct_chick_locations = age-C union and
  latest GPS choice; chick_colour_events/ranked = stable assigned colour;
  negative_parent_events/ranked/marks = mobile parent identity; and
  positive_units/negative_units = the two final operational unit types.
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
    CONVERT(CAST(NULL AS CHAR(1)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS rclass
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
    CONVERT((CASE
      WHEN UPPER(TRIM(COALESCE(c.capture_status, ''))) = 'D' THEN 'dead'
      WHEN UPPER(TRIM(c.LL)) IN ('X', 'XX')
       AND UPPER(TRIM(c.LR)) IN ('X', 'XX') THEN 'X-X'
      WHEN (NULLIF(TRIM(c.UL), '') IS NOT NULL AND UPPER(TRIM(c.UL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(c.LL), '') IS NOT NULL AND UPPER(TRIM(c.LL)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(c.UR), '') IS NOT NULL AND UPPER(TRIM(c.UR)) NOT REGEXP '^(X+|M)$')
        OR (NULLIF(TRIM(c.LR), '') IS NOT NULL AND UPPER(TRIM(c.LR)) NOT REGEXP '^(X+|M)$')
      THEN FIELD_2026_BADOatNZ.format_mark(c.UL, c.LL, c.UR, c.LR)
      ELSE NULL
    END) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS mark,
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
    CONVERT((CASE
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
    END) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS mark,
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
    CONVERT(CAST(NULL AS CHAR(20)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS latest_chick_event_source,
    CAST(NULL AS DATE) AS location_event_date,
    CAST(NULL AS DATETIME) AS location_event_datetime,
    CAST(NULL AS UNSIGNED) AS location_event_pk,
    CONVERT(CAST(NULL AS CHAR(20)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS location_source_table,
    CONVERT(CAST(NULL AS CHAR(20)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS location_source,
    loc.gps_id AS fallback_gps_id,
    loc.gps_point AS fallback_gps_point,
    loc.lat AS fallback_lat,
    loc.lon AS fallback_lon,
    COALESCE(h.hatch_evidence_date, chicks.first_chick_capture_date)
      AS hatch_evidence_date,
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
    CONVERT(CAST(NULL AS CHAR(1)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS chick_band
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
    CONVERT(CAST(NULL AS CHAR(4)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS species,
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
    CONVERT(CAST(NULL AS CHAR(10)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS nest_state,
    CONVERT(CAST(NULL AS CHAR(50)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS hatch_state,
    CAST(NULL AS UNSIGNED) AS clutch_size,
    CAST(NULL AS UNSIGNED) AS brood_size,
    DATEDIFF(d.discovery_date, sr.reference_date) AS min_days_to_hatch,
    pm.M_mark,
    pm.F_mark,
    CONVERT(CAST(NULL AS CHAR(1)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS nest_photo,
    CONVERT(CAST(NULL AS CHAR(1)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS tent_photo,
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
    nest_id, CONVERT(species USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS species, CONVERT(brood_kind USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS brood_kind, is_negative_brood, discovery_date,
    latest_encounter_date, latest_encounter_datetime,
    latest_chick_event_date, CONVERT(latest_chick_event_source USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS latest_chick_event_source,
    location_event_date, location_event_datetime, location_event_pk,
    CONVERT(location_source_table USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS location_source_table, CONVERT(location_source USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS location_source, fallback_gps_id,
    fallback_gps_point, fallback_lat, fallback_lon, hatch_evidence_date,
    has_hatch_evidence, CONVERT(nest_state USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS nest_state, CONVERT(hatch_state USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS hatch_state, clutch_size, brood_size,
    min_days_to_hatch, CONVERT(M_mark USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS M_mark, CONVERT(F_mark USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS F_mark, CONVERT(nest_photo USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS nest_photo, CONVERT(tent_photo USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS tent_photo,
    reference_date, CONVERT(chick_band USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS chick_band
  FROM positive_units
  UNION ALL
  SELECT
    nest_id, CONVERT(species USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS species, CONVERT(brood_kind USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS brood_kind, is_negative_brood, discovery_date,
    latest_encounter_date, latest_encounter_datetime,
    latest_chick_event_date, CONVERT(latest_chick_event_source USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS latest_chick_event_source,
    location_event_date, location_event_datetime, location_event_pk,
    CONVERT(location_source_table USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS location_source_table, CONVERT(location_source USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS location_source, fallback_gps_id,
    fallback_gps_point, fallback_lat, fallback_lon, hatch_evidence_date,
    has_hatch_evidence, CONVERT(nest_state USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS nest_state, CONVERT(hatch_state USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS hatch_state, clutch_size, brood_size,
    min_days_to_hatch, CONVERT(M_mark USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS M_mark, CONVERT(F_mark USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS F_mark, CONVERT(nest_photo USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS nest_photo, CONVERT(tent_photo USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS tent_photo,
    reference_date, CONVERT(chick_band USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS chick_band
  FROM negative_units
) units
LEFT JOIN direct_chick_locations dl
  ON units.nest_id = dl.nest_id
 AND dl.row_num = 1
LEFT JOIN chick_colour_ranked cb
  ON units.nest_id = cb.nest_id
 AND cb.row_num = 1;


/*
  EGGS_HATCH_PREDICTION is the hatch-date source of truth for incomplete or
  floated nests. It combines direct chronology, float calibration, explicit
  found-incomplete inference, complete-clutch chronology, discovery fallback,
  and the conservative stable-one-egg/no-increase extension. The last source
  is separate so a one-egg clutch is not declared complete until two full
  two-day laying intervals have elapsed.

  CTE roles: nest_clutch_history = chronology; found_clutch_ranked and
  final_clutch_status = found/final status; first_complete_clutch_ranked,
  latest_clutch_ranked, first_one_egg_ranked, complete_clutch_status = complete
  sequence candidates; last_incomplete_clutch_ranked and
  incomplete_clutch_status_base/status = inferred completion; stable_one_egg_status
  = conservative extension; calibration_hatch_day through egg_prediction =
  float calibration; incomplete_nest_prediction and chronology_nest_prediction
  = no-float and observed-chronology estimates.
*/
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
latest_clutch_ranked AS (
  SELECT
    nest_clutch_history.*,
    ROW_NUMBER() OVER (
      PARTITION BY nest_id
      ORDER BY date DESC, time_visit DESC, pk DESC
    ) AS row_num
  FROM nest_clutch_history
),
first_one_egg_ranked AS (
  SELECT
    nest_clutch_history.*,
    ROW_NUMBER() OVER (
      PARTITION BY nest_id
      ORDER BY date, time_visit, pk
    ) AS row_num
  FROM nest_clutch_history
  WHERE clutch_size = 1
),
complete_clutch_status AS (
  SELECT
    complete_clutch.nest_id,
    complete_clutch.first_complete_date AS inferred_clutch_completion_date
  FROM first_complete_clutch_ranked complete_clutch
  JOIN final_clutch_status
    ON complete_clutch.nest_id = final_clutch_status.nest_id
  LEFT JOIN nest_clutch_history observed_hatch
    ON complete_clutch.nest_id = observed_hatch.nest_id
   AND UPPER(TRIM(COALESCE(observed_hatch.nest_state, ''))) = 'H'
  WHERE complete_clutch.row_num = 1
    AND final_clutch_status.final_clutch_size >= 3
    AND observed_hatch.nest_id IS NULL
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
stable_one_egg_status AS (
  SELECT
    latest.nest_id,
    first_one_egg.date AS first_one_egg_date,
    latest.date AS last_one_egg_date,
    DATE_ADD(first_one_egg.date, INTERVAL 2 DAY)
      AS inferred_clutch_completion_date,
    DATE_ADD(
      DATE_ADD(first_one_egg.date, INTERVAL 2 DAY),
      INTERVAL 26 DAY
    ) AS inferred_hatch_date
  FROM latest_clutch_ranked latest
  JOIN first_one_egg_ranked first_one_egg
    ON latest.nest_id = first_one_egg.nest_id
   AND first_one_egg.row_num = 1
  JOIN final_clutch_status final_clutch
    ON latest.nest_id = final_clutch.nest_id
  CROSS JOIN sr
  LEFT JOIN nest_clutch_history observed_hatch
    ON latest.nest_id = observed_hatch.nest_id
   AND UPPER(TRIM(COALESCE(observed_hatch.nest_state, ''))) = 'H'
  WHERE latest.row_num = 1
    AND latest.clutch_size = 1
    AND final_clutch.final_clutch_size = 1
    -- Require two full two-day laying intervals before treating a one-egg
    -- clutch as stable. Use the first one-egg record so repeated checks do
    -- not continually move the inferred hatch date forward.
    AND DATEDIFF(sr.reference_date, first_one_egg.date) >= 4
    AND UPPER(TRIM(COALESCE(latest.nest_state, ''))) IN (
      'F', 'I', 'PP', 'PD'
    )
    AND observed_hatch.nest_id IS NULL
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
),
chronology_nest_prediction AS (
  SELECT
    complete_clutch.nest_id,
    sr.reference_date,
    complete_clutch.inferred_clutch_completion_date,
    DATE_ADD(
      complete_clutch.inferred_clutch_completion_date,
      INTERVAL 26 DAY
    ) AS inferred_hatch_date,
    'complete clutch chronology' AS calibration_match_type
  FROM complete_clutch_status complete_clutch
  CROSS JOIN sr
  WHERE NOT EXISTS (
    SELECT 1
    FROM egg_prediction
    WHERE egg_prediction.nest_id = complete_clutch.nest_id
  )
    AND NOT EXISTS (
      SELECT 1
      FROM incomplete_clutch_status incomplete_clutch
      WHERE incomplete_clutch.nest_id = complete_clutch.nest_id
    )

  UNION ALL

  SELECT
    stable_one_egg.nest_id,
    sr.reference_date,
    stable_one_egg.inferred_clutch_completion_date,
    stable_one_egg.inferred_hatch_date,
    'stable one-egg/no increase' AS calibration_match_type
  FROM stable_one_egg_status stable_one_egg
  CROSS JOIN sr
  WHERE NOT EXISTS (
    SELECT 1
    FROM egg_prediction
    WHERE egg_prediction.nest_id = stable_one_egg.nest_id
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
  CONVERT(CAST(NULL AS CHAR(10)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS float_location,
  CAST(NULL AS DECIMAL(5,1)) AS matched_float_angle,
  CAST(NULL AS DECIMAL(5,1)) AS matched_float_surface,
  CONVERT(CAST(NULL AS CHAR(10)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS matched_float_location,
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
FROM incomplete_nest_prediction

UNION ALL

SELECT
  nest_id,
  CAST(NULL AS UNSIGNED) AS egg_id,
  CAST(NULL AS DATE) AS float_date,
  reference_date,
  CAST(NULL AS SIGNED) AS days_since_float,
  CAST(NULL AS DECIMAL(5,1)) AS float_angle,
  CAST(NULL AS DECIMAL(5,1)) AS float_surface,
  CONVERT(CAST(NULL AS CHAR(10)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS float_location,
  CAST(NULL AS DECIMAL(5,1)) AS matched_float_angle,
  CAST(NULL AS DECIMAL(5,1)) AS matched_float_surface,
  CONVERT(CAST(NULL AS CHAR(10)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS matched_float_location,
  calibration_match_type,
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
FROM chronology_nest_prediction;


/*
  GEO_ROLLOUT_PHENOLOGY computes the planning inputs for GEO deployment notes.
  It is intentionally separate from TODO_LIST because its lay-date strata and
  quota diagnostics are useful for auditing as well as task ranking.

  CTE roles: sr/parameters = date and rollout constants; nest_history/discovery
  = bounded chronology; first_one_egg_ranked = conservative one-egg anchor;
  direct_lay_bounds/direct_lay = chronology estimates; float_lay_ranked/float_lay
  = float estimates; final_clutch/incomplete_lay/clutch_lay/discovery_lay =
  biological fallback sources; lay_candidates/lay_ranked/nest_lay = one
  deterministic lay estimate per nest; stratum_nest_counts = nests by stratum;
  stratum_deployment_counts = deployed GEOs by stratum/sex; deployment_status =
  global counts and quotas; stratum_targets/stratum_status = deficits and
  priority fields consumed by TODO_LIST.

  The operational release ceiling is 60 of 100 GEOs, retaining 40 for the
  anticipated later nest wave. Nests first known by 2026-09-24 receive the
  historic-nest pair-completion priority implemented in TODO_LIST below.
  The final sex quotas are 50 males and 50 females. Pair completion is allowed
  only while the target sex remains below its quota; non-pair deployments
  prefer the sex with the larger remaining quota and are then ranked by that
  sex's phenology-stratum deficit.
*/
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
    999999 AS release_ceiling
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


/*
  Canonical adult identity inputs for the four-gate parent association
  pipeline.  Post-handling capture fields are preferred; LL/LR are the
  ordinary matching key, while flags and the four approved single-LR spacer
  identities receive explicit aliases.
*/
CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), normalized AS (
  SELECT
    CAST(c.pk AS CHAR(64)) AS capture_pk,
    CASE
      WHEN c.nest_id IS NULL
        OR TRIM(c.nest_id) = ''
        OR UPPER(TRIM(c.nest_id)) = 'NO_NEST'
      THEN NULL
      ELSE TRIM(c.nest_id)
    END AS nest_id,
    LEFT(c.field_sex, 1) AS capture_sex,
    c.date AS capture_date,
    CAST(CONCAT(c.date, ' ', COALESCE(c.released, c.caught, '00:00:00')) AS DATETIME)
      AS capture_datetime,
    UPPER(TRIM(COALESCE(c.capture_method, ''))) AS capture_method,
    UPPER(TRIM(COALESCE(c.capture_status, ''))) AS capture_status,
    UPPER(TRIM(COALESCE(c.caught_with, ''))) AS caught_with,
    NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') AS metal_ring,
    UPPER(TRIM(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')))) AS UL_raw,
    UPPER(TRIM(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))) AS LL_raw,
    UPPER(TRIM(COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')))) AS UR_raw,
    UPPER(TRIM(COALESCE(NULLIF(TRIM(c.LR), ''), NULLIF(TRIM(c.LR_in), '')))) AS LR_raw,
    UPPER(TRIM(COALESCE(c.tag_type, ''))) AS tag_type,
    UPPER(TRIM(COALESCE(c.tag_action, ''))) AS tag_action,
    NULLIF(UPPER(TRIM(c.tag_id)), '') AS tag_id
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age = 'A'
    AND LEFT(c.field_sex, 1) IN ('M', 'F')
    AND c.date <= sr.reference_date
), historical_normalized AS (
  /*
    A current-season resighting can identify a bird captured in a previous
    season even when there is no current-season CAPTURES row before the
    resighting. CAPTURES_ARCHIVE is an identity source only: its rows do not
    become nest-specific parent events, but they can establish a ring/mark/sex
    and GEO match for ADULT_IDENTITY_MATCHES.
  */
  SELECT
    CONVERT(CONCAT('archive:', COALESCE(c.ring, ''), ':', c.date) USING utf8mb4)
      COLLATE utf8mb4_uca1400_ai_ci AS capture_pk,
    CONVERT(CONVERT(CAST(NULL AS CHAR(6)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS nest_id,
    CONVERT(COALESCE(NULLIF(LEFT(c.gen_sex, 1), ''), LEFT(c.field_sex, 1)) USING utf8mb4)
      COLLATE utf8mb4_uca1400_ai_ci AS capture_sex,
    c.date AS capture_date,
    CAST(CONCAT(c.date, ' 00:00:00') AS DATETIME) AS capture_datetime,
    CONVERT(CONVERT(CAST(NULL AS CHAR(8)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS capture_method,
    CONVERT(UPPER(TRIM(COALESCE(c.capture_status, ''))) USING utf8mb4)
      COLLATE utf8mb4_uca1400_ai_ci AS capture_status,
    CONVERT(CONVERT(CAST(NULL AS CHAR(20)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS caught_with,
    CONVERT(NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') USING utf8mb4)
      COLLATE utf8mb4_uca1400_ai_ci AS metal_ring,
    CONVERT(UPPER(TRIM(COALESCE(c.UL, ''))) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS UL_raw,
    CONVERT(UPPER(TRIM(COALESCE(c.LL, ''))) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS LL_raw,
    CONVERT(UPPER(TRIM(COALESCE(c.UR, ''))) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS UR_raw,
    CONVERT(UPPER(TRIM(COALESCE(c.LR, ''))) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS LR_raw,
    CONVERT(UPPER(TRIM(COALESCE(c.tag_type, ''))) USING utf8mb4)
      COLLATE utf8mb4_uca1400_ai_ci AS tag_type,
    CONVERT(CONVERT(CAST(NULL AS CHAR(8)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS tag_action,
    CONVERT(NULLIF(UPPER(TRIM(c.tag_id)), '') USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS tag_id
  FROM FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE c
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(c.site_code, ''))) = 'CR'
    AND UPPER(TRIM(COALESCE(c.age, ''))) = 'A'
    AND COALESCE(NULLIF(LEFT(c.gen_sex, 1), ''), LEFT(c.field_sex, 1)) IN ('M', 'F')
    AND c.date <= sr.reference_date
), normalized_all AS (
  SELECT * FROM normalized
  UNION ALL
  SELECT * FROM historical_normalized
), derived AS (
  SELECT
    normalized_all.*,
    CASE WHEN normalized_all.UL_raw IN ('X', 'XX', 'M') OR normalized_all.UL_raw IS NULL
      THEN 'X' ELSE normalized_all.UL_raw END AS UL_norm,
    CASE WHEN normalized_all.LL_raw IN ('X', 'XX', 'M') OR normalized_all.LL_raw IS NULL
      THEN 'X' ELSE normalized_all.LL_raw END AS LL_norm,
    CASE WHEN normalized_all.UR_raw IN ('X', 'XX', 'M') OR normalized_all.UR_raw IS NULL
      THEN 'X' ELSE normalized_all.UR_raw END AS UR_norm,
    CASE WHEN normalized_all.LR_raw IN ('X', 'XX', 'M') OR normalized_all.LR_raw IS NULL
      THEN 'X' ELSE normalized_all.LR_raw END AS LR_norm,
    CASE
      WHEN normalized_all.UL_raw REGEXP '^F[A-Z0-9]+$' THEN normalized_all.UL_raw
      WHEN normalized_all.UR_raw REGEXP '^F[A-Z0-9]+$' THEN normalized_all.UR_raw
      ELSE NULL
    END AS flag_code
  FROM normalized_all
), keyed AS (
  SELECT
    derived.*,
    CASE WHEN derived.LL_raw IS NOT NULL AND derived.LR_raw IS NOT NULL
       AND (
         derived.LL_norm <> 'X'
         OR derived.LR_norm <> 'X'
         OR (
           (derived.UL_raw IS NULL OR derived.UL_raw REGEXP '^(X+|M)$')
           AND (derived.UR_raw IS NULL OR derived.UR_raw REGEXP '^(X+|M)$')
         )
       )
      THEN CONCAT(derived.LL_norm, '|', derived.LR_norm) END AS lower_key,
    CONCAT_WS('|', derived.UL_norm, derived.LL_norm, derived.UR_norm, derived.LR_norm)
      AS full_key,
    CASE
      WHEN derived.UR_raw REGEXP '^T[A-Z]$'
       AND derived.LR_norm REGEXP '^[A-Z]$'
       AND derived.LL_norm IS NOT NULL
      THEN CONCAT(derived.LL_norm, '|', RIGHT(derived.UR_raw, 1), '|', derived.LR_norm)
    END AS spacer_key
  FROM derived
)
SELECT
  keyed.*,
  CASE
    WHEN keyed.metal_ring IS NOT NULL THEN CONCAT('ring:', keyed.metal_ring)
    WHEN keyed.flag_code IS NOT NULL THEN CONCAT('flag:', keyed.flag_code)
    WHEN keyed.lower_key IS NOT NULL THEN CONCAT('lower:', keyed.lower_key)
    ELSE CONCAT('capture:', keyed.capture_pk)
  END AS identity_key,
  CASE
    WHEN keyed.flag_code IS NOT NULL THEN CONCAT(keyed.flag_code, '-X')
    WHEN keyed.LL_norm = 'X' AND keyed.LR_norm = 'X'
       AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')
       AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')
      THEN 'X-X'
    WHEN keyed.UL_norm IS NOT NULL OR keyed.LL_norm IS NOT NULL
      OR keyed.UR_norm IS NOT NULL OR keyed.LR_norm IS NOT NULL
    THEN FIELD_2026_BADOatNZ.format_mark(
      keyed.UL_norm, keyed.LL_norm, keyed.UR_norm, keyed.LR_norm
    )
    ELSE NULL
  END AS display_mark,
  CASE
    WHEN keyed.LL_norm = 'X' AND keyed.LR_norm = 'X'
     AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')
     AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')
    THEN 1 ELSE 0
  END
    AS is_confirmed_xx,
  CASE
    WHEN (
      keyed.tag_type = 'GEO'
      AND keyed.tag_action IN ('D', 'S', 'N')
      AND keyed.tag_id IS NOT NULL
    ) OR keyed.UL_raw REGEXP '^T[A-Z0-9]*$'
      OR keyed.UR_raw REGEXP '^T[A-Z0-9]*$'
    THEN 1 ELSE 0
  END AS has_geo,
  CASE WHEN LEFT(keyed.UL_raw, 2) = 'FO' OR LEFT(keyed.UR_raw, 2) = 'FO'
    THEN 1 ELSE 0 END AS is_au_migrant,
  CASE WHEN keyed.capture_status = 'D' THEN 1 ELSE 0 END AS is_dead,
  CASE WHEN keyed.LL_raw REGEXP '^[OYWBRGL]$'
         AND keyed.LR_raw REGEXP '^[OYWBRGL]$'
    THEN 1 ELSE 0 END AS is_single_colour_recruit,
  CASE
    -- HA is the canonical spotlight/night-capture code. Do not infer
    -- definitive association from legacy comments or capture_method O.
    WHEN keyed.capture_method IN ('TB', 'TN', 'HA')
      OR keyed.caught_with REGEXP '(^|[,[:space:]])[0-9]*C([,[:space:]]|$)'
    THEN 1 ELSE 0
  END AS definitive_capture,
  CASE WHEN keyed.capture_method = 'MM' THEN 1 ELSE 0 END AS has_mm_capture
FROM keyed;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES AS
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL
WHERE nest_id IS NOT NULL;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES_ALL AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), normalized AS (
  SELECT
    r.pk AS resighting_pk,
    CASE
      WHEN r.nest_id IS NULL
        OR TRIM(r.nest_id) = ''
        OR UPPER(TRIM(r.nest_id)) = 'NO_NEST'
      THEN NULL
      ELSE TRIM(r.nest_id)
    END AS nest_id,
    LEFT(r.sex, 1) AS observed_sex,
    r.date AS observation_date,
    UPPER(TRIM(COALESCE(r.behav, ''))) AS behav,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.ring, ''))) IN ('', 'X', 'XX', 'NA', 'N/A')
      THEN NULL
      ELSE REPLACE(UPPER(TRIM(r.ring)), '-', '')
    END AS metal_ring,
    UPPER(TRIM(r.UL)) AS UL_raw,
    UPPER(TRIM(r.LL)) AS LL_raw,
    UPPER(TRIM(r.UR)) AS UR_raw,
    UPPER(TRIM(r.LR)) AS LR_raw
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'A'
    AND LEFT(r.sex, 1) IN ('M', 'F')
    AND r.date <= sr.reference_date
), derived AS (
  SELECT
    normalized.*,
    CASE WHEN normalized.UL_raw IN ('X', 'XX', 'M') OR normalized.UL_raw IS NULL
      THEN 'X' ELSE normalized.UL_raw END AS UL_norm,
    CASE WHEN normalized.LL_raw IN ('X', 'XX', 'M') OR normalized.LL_raw IS NULL
      THEN 'X' ELSE normalized.LL_raw END AS LL_norm,
    CASE WHEN normalized.UR_raw IN ('X', 'XX', 'M') OR normalized.UR_raw IS NULL
      THEN 'X' ELSE normalized.UR_raw END AS UR_norm,
    CASE WHEN normalized.LR_raw IN ('X', 'XX', 'M') OR normalized.LR_raw IS NULL
      THEN 'X' ELSE normalized.LR_raw END AS LR_norm,
    CASE
      WHEN normalized.UL_raw REGEXP '^F[A-Z0-9]+$' THEN normalized.UL_raw
      WHEN normalized.UR_raw REGEXP '^F[A-Z0-9]+$' THEN normalized.UR_raw
      ELSE NULL
    END AS flag_code
  FROM normalized
), keyed AS (
  SELECT
    derived.*,
    CASE WHEN derived.LL_raw IS NOT NULL AND derived.LR_raw IS NOT NULL
       AND (
         derived.LL_norm <> 'X'
         OR derived.LR_norm <> 'X'
         OR (
           (derived.UL_raw IS NULL OR derived.UL_raw REGEXP '^(X+|M)$')
           AND (derived.UR_raw IS NULL OR derived.UR_raw REGEXP '^(X+|M)$')
         )
       )
      THEN CONCAT(derived.LL_norm, '|', derived.LR_norm) END AS lower_key,
    CONCAT_WS('|', derived.UL_norm, derived.LL_norm, derived.UR_norm, derived.LR_norm)
      AS full_key,
    CASE
      WHEN derived.UR_raw REGEXP '^T[A-Z]$'
       AND derived.LR_norm REGEXP '^[A-Z]$'
       AND derived.LL_norm IS NOT NULL
      THEN CONCAT(derived.LL_norm, '|', RIGHT(derived.UR_raw, 1), '|', derived.LR_norm)
      WHEN derived.UR_raw IS NULL
       AND derived.LR_raw REGEXP '^[A-Z]{2}$'
       AND derived.LL_norm IS NOT NULL
      THEN CONCAT(
        derived.LL_norm,
        '|',
        LEFT(derived.LR_raw, 1),
        '|',
        RIGHT(derived.LR_raw, 1)
      )
    END AS spacer_key
  FROM derived
)
SELECT
  keyed.*,
  CASE
    WHEN keyed.flag_code IS NOT NULL THEN CONCAT(keyed.flag_code, '-X')
    WHEN keyed.LL_norm = 'X' AND keyed.LR_norm = 'X'
       AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')
       AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')
      THEN 'X-X'
    WHEN keyed.UL_norm IS NOT NULL OR keyed.LL_norm IS NOT NULL
      OR keyed.UR_norm IS NOT NULL OR keyed.LR_norm IS NOT NULL
    THEN FIELD_2026_BADOatNZ.format_mark(
      keyed.UL_norm, keyed.LL_norm, keyed.UR_norm, keyed.LR_norm
    )
    ELSE NULL
  END AS observed_mark,
  CASE
    WHEN keyed.metal_ring IS NOT NULL THEN CONCAT('ring:', keyed.metal_ring)
    WHEN keyed.flag_code IS NOT NULL THEN CONCAT('flag:', keyed.flag_code)
    WHEN keyed.LL_norm = 'X' AND keyed.LR_norm = 'X'
      AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')
      AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')
      THEN CONCAT('xx:', keyed.nest_id, ':', keyed.observed_sex)
    WHEN keyed.lower_key IS NOT NULL THEN CONCAT('lower:', keyed.lower_key)
    ELSE CONCAT('resighting:', keyed.resighting_pk)
  END AS raw_identity_key,
  CASE
    WHEN keyed.LL_norm = 'X' AND keyed.LR_norm = 'X'
     AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')
     AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')
    THEN 1 ELSE 0
  END
    AS is_confirmed_xx,
  CASE WHEN keyed.behav REGEXP '(^|[,[:space:]])(IN|NM|SC|BW|BC|FC|AC)([,[:space:]]|$)'
    THEN 1 ELSE 0 END AS association_confirming,
  CASE WHEN keyed.behav REGEXP '(^|[,[:space:]])(IN|NM|SC|BW|BC|FC|AC)([,[:space:]]|$)'
    THEN 0 ELSE 1 END AS association_nonconfirming
FROM keyed;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES AS
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES_ALL
WHERE nest_id IS NOT NULL;


/*
  Match adult resightings to captured identities once.  A ring or flag match
  is strongest; otherwise use the LL/LR key, with the spacer alias reserved
  for the known single-LR birds.  A short mark is never assigned to multiple
  candidates: ambiguous matches remain reviewable and do not inherit GEO.
*/
CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES AS

WITH candidates AS (
  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex AS candidate_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END AS sex_match,
    1 AS match_priority,
    'ring' AS match_class
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES c
    ON c.metal_ring = r.metal_ring
   AND (
      c.capture_date < r.observation_date
      OR (
        c.capture_date = r.observation_date
        AND r.is_confirmed_xx = 1
        AND c.capture_status = 'F'
        AND c.capture_sex = r.observed_sex
      )
   )
  WHERE r.metal_ring IS NOT NULL

  UNION ALL

  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END,
    2,
    'flag'
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES c
    ON c.flag_code = r.flag_code
   AND c.capture_date <= r.observation_date
  WHERE r.flag_code IS NOT NULL
    AND r.metal_ring IS NULL

  UNION ALL

  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END,
    3,
    'lower'
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES c
    ON c.lower_key = r.lower_key
   AND c.capture_date <= r.observation_date
  WHERE r.lower_key IS NOT NULL
    AND c.is_confirmed_xx = 0
    AND r.metal_ring IS NULL

  UNION ALL

  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END,
    2,
    'single-lr-spacer'
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES c
    ON c.spacer_key = r.spacer_key
   AND c.capture_date <= r.observation_date
  WHERE r.spacer_key IS NOT NULL
    AND c.is_confirmed_xx = 0
    AND r.metal_ring IS NULL

  UNION ALL

  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END,
    4,
    'full'
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES c
    ON c.full_key = r.full_key
   AND c.capture_date <= r.observation_date
  WHERE r.full_key IS NOT NULL
    AND c.is_confirmed_xx = 0
    AND r.metal_ring IS NULL
), best_priority AS (
  SELECT resighting_pk, MIN(match_priority) AS match_priority
  FROM candidates
  GROUP BY resighting_pk
), best_sex AS (
  SELECT
    candidates.resighting_pk,
    candidates.match_priority,
    MAX(candidates.sex_match) AS sex_match
  FROM candidates
  JOIN best_priority
    ON candidates.resighting_pk = best_priority.resighting_pk
   AND candidates.match_priority = best_priority.match_priority
  GROUP BY candidates.resighting_pk, candidates.match_priority
), best AS (
  SELECT DISTINCT
    candidates.resighting_pk,
    candidates.identity_key,
    candidates.match_class
  FROM candidates
  JOIN best_priority
   ON candidates.resighting_pk = best_priority.resighting_pk
   AND candidates.match_priority = best_priority.match_priority
  JOIN best_sex
    ON candidates.resighting_pk = best_sex.resighting_pk
   AND candidates.match_priority = best_sex.match_priority
   AND candidates.sex_match = best_sex.sex_match
), counts AS (
  SELECT
    resighting_pk,
    COUNT(DISTINCT identity_key) AS n_candidate_identities
  FROM best
  GROUP BY resighting_pk
), latest_capture AS (
  SELECT
    best.resighting_pk,
    best.identity_key,
    c.display_mark,
    c.capture_sex,
    c.has_geo,
    c.is_au_migrant,
    c.is_dead,
    c.is_single_colour_recruit,
    c.has_mm_capture,
    ROW_NUMBER() OVER (
      PARTITION BY best.resighting_pk, best.identity_key
      ORDER BY c.capture_datetime DESC, c.capture_pk DESC
    ) AS row_num
  FROM best
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES c
    ON c.identity_key = best.identity_key
), matched AS (
  SELECT
    r.nest_id,
    r.resighting_pk,
    r.observation_date,
    r.observed_sex,
    r.behav,
    r.association_confirming,
    r.association_nonconfirming,
    r.raw_identity_key,
    r.observed_mark,
    best.identity_key,
    best.match_class,
    counts.n_candidate_identities,
    latest.display_mark AS matched_mark,
    latest.capture_sex AS matched_sex,
    latest.has_geo AS matched_has_geo,
    latest.is_au_migrant AS matched_is_au_migrant,
    latest.is_dead AS matched_is_dead,
    latest.is_single_colour_recruit AS matched_single_colour_recruit,
    latest.has_mm_capture,
    CASE WHEN counts.n_candidate_identities = 1 THEN 1 ELSE 0 END AS is_unique_match
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES r
  JOIN best
    ON r.resighting_pk = best.resighting_pk
  JOIN counts
    ON r.resighting_pk = counts.resighting_pk
  LEFT JOIN latest_capture latest
    ON latest.resighting_pk = best.resighting_pk
   AND latest.identity_key = best.identity_key
   AND latest.row_num = 1
), unmatched AS (
  SELECT
    r.nest_id,
    r.resighting_pk,
    r.observation_date,
    r.observed_sex,
    r.behav,
    r.association_confirming,
    r.association_nonconfirming,
    r.raw_identity_key AS identity_key,
    r.observed_mark AS display_mark,
    0 AS has_geo,
    0 AS is_au_migrant,
    0 AS is_dead,
    0 AS is_single_colour_recruit,
    0 AS has_mm_capture,
    'unmatched' AS match_class,
    0 AS is_ambiguous_match,
    0 AS n_candidate_identities
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES r
  WHERE NOT EXISTS (
    SELECT 1 FROM best WHERE best.resighting_pk = r.resighting_pk
  )
)
SELECT
  matched.nest_id,
  matched.resighting_pk,
  matched.observation_date,
  CASE WHEN matched.is_unique_match = 1 THEN matched.matched_sex ELSE matched.observed_sex END AS sex,
  matched.observed_sex,
  CASE WHEN matched.is_unique_match = 1 THEN matched.identity_key ELSE matched.raw_identity_key END AS identity_key,
  CASE WHEN matched.is_unique_match = 1 THEN matched.matched_mark ELSE matched.observed_mark END AS display_mark,
  CASE WHEN matched.is_unique_match = 1 THEN matched.matched_has_geo ELSE 0 END AS has_geo,
  CASE WHEN matched.is_unique_match = 1 THEN matched.matched_is_au_migrant ELSE 0 END AS is_au_migrant,
  CASE WHEN matched.is_unique_match = 1 THEN matched.matched_is_dead ELSE 0 END AS is_dead,
  CASE WHEN matched.is_unique_match = 1 THEN matched.matched_single_colour_recruit ELSE 0 END AS is_single_colour_recruit,
  matched.behav,
  matched.association_confirming,
  matched.association_nonconfirming,
  matched.has_mm_capture,
  matched.match_class,
  CASE WHEN matched.is_unique_match = 1 THEN 0 ELSE 1 END AS is_ambiguous_match,
  matched.n_candidate_identities
FROM matched

UNION ALL

SELECT
  unmatched.nest_id,
  unmatched.resighting_pk,
  unmatched.observation_date,
  unmatched.observed_sex AS sex,
  unmatched.observed_sex,
  unmatched.identity_key,
  unmatched.display_mark,
  unmatched.has_geo,
  unmatched.is_au_migrant,
  unmatched.is_dead,
  unmatched.is_single_colour_recruit,
  unmatched.behav,
  unmatched.association_confirming,
  unmatched.association_nonconfirming,
  unmatched.has_mm_capture,
  unmatched.match_class,
  unmatched.is_ambiguous_match,
  unmatched.n_candidate_identities
FROM unmatched;


/*
  Link an age-A capture to a banded age-C chick through an exact GPS pair.
  This is an additional definitive parent-association gate. It is kept
  separate from ADULT_CAPTURE_IDENTITIES because the capture may have no
  nest_id when the originating nest has already been closed.

  A nest is accepted only when the GPS-linked evidence identifies one unique
  operational nest/brood. If both the capture and chick lack nest_id, a
  unique banded opposite-sex adult at the same GPS pair may supply the nest
  through that identity's established nest-linked evidence. Conflicting or
  non-unique candidates remain unresolved and do not promote a parent.
*/
CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), capture_identities AS (
  SELECT
    captured.*,
    raw.gps_id,
    raw.gps_point
  FROM FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL captured
  JOIN FIELD_2026_BADOatNZ.CAPTURES raw
    ON CAST(raw.pk AS CHAR(64)) = captured.capture_pk
  WHERE UPPER(TRIM(COALESCE(raw.site, ''))) = 'CR'
    AND raw.age = 'A'
    AND LEFT(raw.field_sex, 1) IN ('M', 'F')
    AND raw.date <= (SELECT reference_date FROM sr)
    AND raw.gps_id IS NOT NULL
    AND raw.gps_point IS NOT NULL
), chick_events AS (
  SELECT
    r.pk AS chick_resighting_pk,
    CASE
      WHEN r.nest_id IS NULL
        OR TRIM(r.nest_id) = ''
        OR UPPER(TRIM(r.nest_id)) = 'NO_NEST'
      THEN NULL
      ELSE TRIM(r.nest_id)
    END AS nest_id,
    r.date AS observation_date,
    r.gps_id,
    r.gps_point
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'C'
    AND r.date <= sr.reference_date
    AND r.gps_id IS NOT NULL
    AND r.gps_point IS NOT NULL
    AND NULLIF(TRIM(r.ring), '') IS NOT NULL
    AND UPPER(TRIM(r.ring)) NOT IN ('X', 'XX', 'X-X', 'NA', 'N/A')
), opposite_keyed AS (
  SELECT
    observed.*,
    raw.gps_id,
    raw.gps_point
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES_ALL observed
  JOIN FIELD_2026_BADOatNZ.RESIGHTINGS raw
    ON raw.pk = observed.resighting_pk
  WHERE UPPER(TRIM(COALESCE(raw.site, ''))) = 'CR'
    AND raw.age = 'A'
    AND LEFT(raw.sex, 1) IN ('M', 'F')
    AND raw.date <= (SELECT reference_date FROM sr)
    AND raw.gps_id IS NOT NULL
    AND raw.gps_point IS NOT NULL
), opposite_candidates AS (
  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END AS sex_match,
    1 AS match_priority
  FROM opposite_keyed r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
    ON c.metal_ring = r.metal_ring
   AND c.capture_date <= r.observation_date
   AND c.is_confirmed_xx = 0
  WHERE r.metal_ring IS NOT NULL

  UNION ALL

  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END,
    2
  FROM opposite_keyed r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
    ON c.flag_code = r.flag_code
   AND c.capture_date <= r.observation_date
   AND c.is_confirmed_xx = 0
  WHERE r.flag_code IS NOT NULL
    AND r.metal_ring IS NULL

  UNION ALL

  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END,
    2
  FROM opposite_keyed r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
    ON c.spacer_key = r.spacer_key
   AND c.capture_date <= r.observation_date
   AND c.is_confirmed_xx = 0
  WHERE r.spacer_key IS NOT NULL
    AND r.metal_ring IS NULL

  UNION ALL

  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END,
    3
  FROM opposite_keyed r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
    ON c.lower_key = r.lower_key
   AND c.capture_date <= r.observation_date
   AND c.is_confirmed_xx = 0
  WHERE r.lower_key IS NOT NULL
    AND r.metal_ring IS NULL

  UNION ALL

  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END,
    4
  FROM opposite_keyed r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
    ON c.full_key = r.full_key
   AND c.capture_date <= r.observation_date
   AND c.is_confirmed_xx = 0
  WHERE r.full_key IS NOT NULL
    AND r.metal_ring IS NULL
), opposite_best_priority AS (
  SELECT resighting_pk, MIN(match_priority) AS match_priority
  FROM opposite_candidates
  GROUP BY resighting_pk
), opposite_best_sex AS (
  SELECT
    candidates.resighting_pk,
    candidates.match_priority,
    MAX(candidates.sex_match) AS sex_match
  FROM opposite_candidates candidates
  JOIN opposite_best_priority priority
    ON candidates.resighting_pk = priority.resighting_pk
   AND candidates.match_priority = priority.match_priority
  GROUP BY candidates.resighting_pk, candidates.match_priority
), opposite_best AS (
  SELECT DISTINCT
    candidates.resighting_pk,
    candidates.identity_key,
    candidates.capture_sex
  FROM opposite_candidates candidates
  JOIN opposite_best_priority priority
    ON candidates.resighting_pk = priority.resighting_pk
   AND candidates.match_priority = priority.match_priority
  JOIN opposite_best_sex sex_choice
    ON candidates.resighting_pk = sex_choice.resighting_pk
   AND candidates.match_priority = sex_choice.match_priority
   AND candidates.sex_match = sex_choice.sex_match
), opposite_counts AS (
  SELECT
    resighting_pk,
    COUNT(DISTINCT identity_key) AS n_candidate_identities
  FROM opposite_best
  GROUP BY resighting_pk
), opposite_identity_events AS (
  SELECT
    r.resighting_pk,
    r.nest_id,
    best.capture_sex AS established_sex,
    r.observed_sex,
    r.gps_id,
    r.gps_point,
    best.identity_key
  FROM opposite_keyed r
  JOIN opposite_best best
    ON r.resighting_pk = best.resighting_pk
  JOIN opposite_counts counts
    ON best.resighting_pk = counts.resighting_pk
   AND counts.n_candidate_identities = 1
), known_parent_nests AS (
  SELECT
    c.identity_key,
    c.capture_sex AS sex,
    c.nest_id
  FROM FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES c
  WHERE c.nest_id IS NOT NULL
    AND c.definitive_capture = 1

  UNION

  SELECT
    r.identity_key,
    r.sex,
    r.nest_id
  FROM FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES r
  WHERE r.nest_id IS NOT NULL
    AND r.is_ambiguous_match = 0
    AND r.association_confirming = 1
), nest_candidates AS (
  SELECT
    c.capture_pk,
    c.identity_key,
    c.capture_sex,
    c.nest_id,
    'capture_or_chick_nest' AS link_source
  FROM capture_identities c
  JOIN chick_events chick
    ON c.gps_id = chick.gps_id
   AND c.gps_point = chick.gps_point
  WHERE c.nest_id IS NOT NULL
     OR chick.nest_id IS NOT NULL

  UNION ALL

  SELECT
    c.capture_pk,
    c.identity_key,
    c.capture_sex,
    opposite.nest_id,
    'opposite_parent_nest' AS link_source
  FROM capture_identities c
  JOIN chick_events chick
    ON c.gps_id = chick.gps_id
   AND c.gps_point = chick.gps_point
  JOIN opposite_identity_events opposite
    ON opposite.gps_id = c.gps_id
   AND opposite.gps_point = c.gps_point
   AND opposite.established_sex <> c.capture_sex
  WHERE c.nest_id IS NULL
    AND chick.nest_id IS NULL
    AND opposite.nest_id IS NOT NULL

  UNION ALL

  SELECT
    c.capture_pk,
    c.identity_key,
    c.capture_sex,
    known.nest_id,
    'opposite_parent_established_nest' AS link_source
  FROM capture_identities c
  JOIN chick_events chick
    ON c.gps_id = chick.gps_id
   AND c.gps_point = chick.gps_point
  JOIN opposite_identity_events opposite
    ON opposite.gps_id = c.gps_id
   AND opposite.gps_point = c.gps_point
   AND opposite.established_sex <> c.capture_sex
   AND opposite.nest_id IS NULL
  JOIN known_parent_nests known
    ON known.identity_key = opposite.identity_key
   AND known.sex = opposite.established_sex
  WHERE c.nest_id IS NULL
    AND chick.nest_id IS NULL
), unique_nests AS (
  SELECT
    candidates.capture_pk,
    candidates.identity_key,
    candidates.capture_sex,
    MIN(candidates.nest_id) AS nest_id,
    COUNT(DISTINCT candidates.nest_id) AS n_candidate_nests,
    GROUP_CONCAT(
      DISTINCT candidates.link_source
      ORDER BY candidates.link_source
      SEPARATOR ','
    ) AS link_source
  FROM nest_candidates candidates
  WHERE candidates.nest_id IS NOT NULL
  GROUP BY
    candidates.capture_pk,
    candidates.identity_key,
    candidates.capture_sex
)
SELECT
  captures.capture_pk,
  captures.identity_key,
  captures.capture_sex,
  nests.nest_id,
  captures.capture_date,
  captures.capture_datetime,
  captures.display_mark,
  captures.has_geo,
  captures.is_au_migrant,
  captures.is_dead,
  captures.is_single_colour_recruit,
  nests.link_source,
  1 AS has_chick_gps_link
FROM capture_identities captures
JOIN unique_nests nests
  ON captures.capture_pk = nests.capture_pk
 AND captures.identity_key = nests.identity_key
 AND captures.capture_sex = nests.capture_sex
WHERE nests.n_candidate_nests = 1;


/*
  Refresh-time input boundary for the GPS-linked parent gate. During a staged
  refresh this points first to the live linker, then to its completed build
  table, and finally to the published link snapshot. Keeping this boundary
  separate lets parent-status assembly consume one materialized result.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW
  FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_PARENT_NEST_ASSOCIATIONS AS

WITH xx_supersession_evidence AS (
  SELECT
    xx.nest_id,
    xx.sex,
    xx.identity_key AS xx_identity_key,
    captured.identity_key AS captured_identity_key,
    MIN(captured.capture_date) AS supersession_capture_date
  FROM FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES xx
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES captured
    ON captured.nest_id = xx.nest_id
   AND captured.capture_sex = xx.sex
   AND captured.is_confirmed_xx = 0
   AND (
     captured.capture_date > xx.observation_date
     OR (
       captured.capture_date = xx.observation_date
       AND captured.capture_status = 'F'
     )
   )
  JOIN FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES confirming
    ON confirming.nest_id = captured.nest_id
   AND confirming.sex = captured.capture_sex
   AND confirming.identity_key = captured.identity_key
   AND confirming.observation_date > captured.capture_date
   AND confirming.association_confirming = 1
  WHERE xx.identity_key LIKE 'xx:%'
    AND xx.association_confirming = 1
  GROUP BY
    xx.nest_id,
    xx.sex,
    xx.identity_key,
    captured.identity_key
), xx_supersession_candidate_counts AS (
  SELECT
    xx_supersession_evidence.nest_id,
    xx_supersession_evidence.sex,
    xx_supersession_evidence.xx_identity_key,
    COUNT(DISTINCT xx_supersession_evidence.captured_identity_key)
      AS n_captured_candidates
  FROM xx_supersession_evidence
  GROUP BY
    xx_supersession_evidence.nest_id,
    xx_supersession_evidence.sex,
    xx_supersession_evidence.xx_identity_key
), xx_superseded AS (
  /*
    An X-X observation is a placeholder for a later captured individual only
    when chronology and later confirming evidence identify one unique bird.
    This is intentionally narrower than "same nest and same sex": a second
    captured candidate, or an X-X observation after the capture, remains a
    genuine ambiguity for review.
  */
  SELECT
    evidence.nest_id,
    evidence.sex,
    evidence.xx_identity_key,
    evidence.captured_identity_key,
    evidence.supersession_capture_date
  FROM xx_supersession_evidence evidence
  JOIN xx_supersession_candidate_counts counts
    ON counts.nest_id = evidence.nest_id
   AND counts.sex = evidence.sex
   AND counts.xx_identity_key = evidence.xx_identity_key
   AND counts.n_captured_candidates = 1
), event_union AS (
  SELECT
    c.nest_id,
    c.capture_sex AS sex,
    c.identity_key,
    c.capture_pk AS event_pk,
    c.capture_datetime AS event_datetime,
    1 AS capture_source,
    c.display_mark,
    c.has_geo,
    c.is_au_migrant,
    c.is_dead,
    c.is_single_colour_recruit,
    CASE WHEN chick_link.capture_pk IS NOT NULL
      THEN 1 ELSE c.definitive_capture END AS definitive_capture,
    0 AS confirming_resighting,
    0 AS nonconfirming_resighting,
    c.has_mm_capture,
    0 AS ambiguous_match,
    CASE WHEN chick_link.capture_pk IS NOT NULL THEN 1 ELSE 0 END
      AS chick_gps_parent_link
  FROM FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES c
  LEFT JOIN FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT chick_link
    ON chick_link.capture_pk = c.capture_pk
   AND chick_link.identity_key = c.identity_key
   AND chick_link.nest_id = c.nest_id

  UNION ALL

  SELECT
    chick_link.nest_id,
    chick_link.capture_sex AS sex,
    chick_link.identity_key,
    CONCAT('chick-gps:', chick_link.capture_pk) AS event_pk,
    chick_link.capture_datetime AS event_datetime,
    1 AS capture_source,
    chick_link.display_mark,
    chick_link.has_geo,
    chick_link.is_au_migrant,
    chick_link.is_dead,
    chick_link.is_single_colour_recruit,
    1 AS definitive_capture,
    0 AS confirming_resighting,
    0 AS nonconfirming_resighting,
    0 AS has_mm_capture,
    0 AS ambiguous_match,
    1 AS chick_gps_parent_link
  FROM FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT chick_link
  WHERE NOT EXISTS (
    SELECT 1
    FROM FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES captured
    WHERE captured.capture_pk = chick_link.capture_pk
  )

  UNION ALL

  SELECT
    r.nest_id,
    r.sex,
    CASE
      WHEN superseded.xx_identity_key IS NOT NULL
       AND r.observation_date <= superseded.supersession_capture_date
      THEN superseded.captured_identity_key
      ELSE r.identity_key
    END AS identity_key,
    r.resighting_pk AS event_pk,
    CAST(CONCAT(r.observation_date, ' 00:00:00') AS DATETIME) AS event_datetime,
    0 AS capture_source,
    r.display_mark,
    r.has_geo,
    r.is_au_migrant,
    r.is_dead,
    r.is_single_colour_recruit,
    0 AS definitive_capture,
    r.association_confirming AS confirming_resighting,
    r.association_nonconfirming AS nonconfirming_resighting,
    r.has_mm_capture,
    r.is_ambiguous_match AS ambiguous_match,
    0 AS chick_gps_parent_link
  FROM FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES r
  LEFT JOIN xx_superseded superseded
    ON superseded.nest_id = r.nest_id
   AND superseded.sex = r.sex
   AND superseded.xx_identity_key = r.identity_key
), identity_summary AS (
  SELECT
    event_union.nest_id,
    event_union.sex,
    event_union.identity_key,
    COALESCE(
      SUBSTRING_INDEX(
        GROUP_CONCAT(
          CASE WHEN event_union.capture_source = 1
            THEN event_union.display_mark END
          ORDER BY event_union.event_datetime DESC, event_union.event_pk DESC
          SEPARATOR ','
        ),
        ',',
        1
      ),
      MAX(event_union.display_mark)
    ) AS observed_mark,
    MAX(event_union.has_geo) AS identity_has_geo,
    MAX(event_union.is_au_migrant) AS identity_is_au_migrant,
    MAX(event_union.is_dead) AS identity_is_dead,
    MAX(event_union.is_single_colour_recruit) AS identity_single_colour_recruit,
    MAX(event_union.definitive_capture) AS has_definitive_capture,
    MAX(event_union.chick_gps_parent_link) AS has_chick_gps_link,
    MAX(event_union.confirming_resighting) AS has_confirming_resighting,
    COUNT(DISTINCT CASE WHEN event_union.nonconfirming_resighting = 1 THEN event_union.event_pk END)
      AS n_nonconfirming_resightings,
    COUNT(DISTINCT CASE WHEN event_union.confirming_resighting = 1 THEN event_union.event_pk END)
      AS n_confirming_resightings,
    COUNT(DISTINCT CASE
      WHEN event_union.confirming_resighting = 1 OR event_union.nonconfirming_resighting = 1
      THEN event_union.event_pk END
    ) AS n_resightings,
    MAX(event_union.has_mm_capture) AS has_mm_capture,
    MAX(event_union.ambiguous_match) AS has_ambiguous_match
  FROM event_union
  WHERE event_union.nest_id IS NOT NULL
    AND event_union.sex IN ('M', 'F')
  GROUP BY event_union.nest_id, event_union.sex, event_union.identity_key
), levels AS (
  SELECT
    identity_summary.*,
    CASE
      WHEN identity_summary.has_ambiguous_match = 1 THEN 0
      WHEN identity_summary.has_definitive_capture = 1 THEN 3
      WHEN identity_summary.has_confirming_resighting = 1 THEN 2
      WHEN identity_summary.n_nonconfirming_resightings >= 3 THEN 1
      ELSE 0
    END AS association_level
  FROM identity_summary
), ranked AS (
  SELECT
    levels.*,
    MAX(levels.association_level) OVER (
      PARTITION BY levels.nest_id, levels.sex
    ) AS highest_association_level
  FROM levels
), counted AS (
  SELECT
    ranked.*,
    SUM(
      CASE
        WHEN ranked.association_level = ranked.highest_association_level THEN 1
        ELSE 0
      END
    ) OVER (
      PARTITION BY ranked.nest_id, ranked.sex
    ) AS n_highest_identities
  FROM ranked
), classified AS (
  SELECT
    counted.*,
    CASE
      WHEN counted.highest_association_level >= 1
       AND counted.n_highest_identities = 1
       AND counted.association_level = counted.highest_association_level
      THEN 1 ELSE 0
    END AS association_selected,
    CASE
      WHEN counted.highest_association_level >= 0
       AND counted.n_highest_identities > 1
       AND counted.association_level = counted.highest_association_level
      THEN 1 ELSE 0
    END AS association_ambiguous
  FROM counted
)
SELECT
  classified.nest_id,
  classified.sex,
  CASE
    WHEN classified.association_selected = 1 THEN classified.observed_mark
    ELSE classified.observed_mark
  END AS parent_mark,
  classified.observed_mark,
  classified.identity_key,
  classified.association_level,
  classified.has_chick_gps_link,
  classified.association_selected,
  classified.association_ambiguous,
  CASE
    WHEN classified.highest_association_level = 0
      OR classified.association_ambiguous = 1
    THEN 1 ELSE 0
  END AS association_pending,
  classified.identity_has_geo,
  classified.identity_is_au_migrant,
  classified.identity_is_dead,
  classified.identity_single_colour_recruit,
  classified.has_mm_capture,
  classified.n_nonconfirming_resightings,
  classified.n_confirming_resightings,
  classified.n_resightings,
  classified.has_ambiguous_match
FROM classified;


/*
  ADULT_PARENT_STATUS is the only parent-status object consumed by the task
  engine.  The compatibility columns keep existing PDF/table consumers stable,
  while the *_resight_association_* fields expose the four-gate result.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.ADULT_PARENT_STATUS AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), units AS (
  SELECT n.nest_id, n.reference_date
  FROM FIELD_2026_BADOatNZ.NESTS_LATEST n
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.reference_date = sr.reference_date
  UNION
  SELECT b.nest_id, b.reference_date
  FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
  CROSS JOIN sr
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
), by_identity AS (
  SELECT
    association.nest_id,
    association.sex,
    association.identity_key,
    MAX(association.parent_mark) AS parent_mark,
    MAX(association.association_selected) AS association_selected,
    MAX(association.association_ambiguous) AS association_ambiguous,
    MAX(association.association_pending) AS association_pending,
    MAX(association.identity_has_geo) AS has_geo,
    MAX(association.identity_is_dead) AS is_dead,
    MAX(association.identity_is_au_migrant) AS is_au_migrant,
    MAX(association.identity_single_colour_recruit) AS single_colour_recruit,
    MAX(association.has_mm_capture) AS has_mm_capture,
    MAX(association.n_nonconfirming_resightings) AS n_nonconfirming_resightings,
    MAX(association.n_resightings) AS n_resightings
  FROM FIELD_2026_BADOatNZ.ADULT_PARENT_NEST_ASSOCIATIONS association
  GROUP BY association.nest_id, association.sex, association.identity_key
), status_by_sex AS (
  SELECT
    by_identity.nest_id,
    by_identity.sex,
    MAX(CASE WHEN by_identity.association_selected = 1 THEN by_identity.parent_mark END)
      AS selected_mark,
    COUNT(DISTINCT by_identity.identity_key) AS identity_count,
    MAX(by_identity.association_pending) AS association_pending,
    MAX(by_identity.association_ambiguous) AS association_ambiguous,
    /*
      GEO and pair-completion decisions follow the authoritative four-gate
      identity, not any historical/provisional identity of the same sex.  If
      the gate result is ambiguous, there is no selected identity and this
      deliberately returns zero; competing identities remain available in
      the diagnostic association fields below.
    */
    MAX(
      CASE WHEN by_identity.association_selected = 1
        THEN by_identity.has_geo ELSE 0 END
    ) AS selected_has_geo,
    MAX(by_identity.is_dead) AS any_is_dead,
    MAX(by_identity.is_au_migrant) AS any_is_au_migrant,
    MAX(by_identity.single_colour_recruit) AS any_single_colour_recruit,
    MAX(by_identity.has_mm_capture) AS any_mm_capture,
    SUM(by_identity.n_resightings) AS resighting_count,
    SUM(
      CASE WHEN by_identity.association_pending = 1
        THEN by_identity.n_nonconfirming_resightings ELSE 0 END
    ) AS pending_resighting_count,
    GROUP_CONCAT(
      DISTINCT CASE
        WHEN by_identity.association_pending = 1
        THEN CONCAT(
          COALESCE(by_identity.parent_mark, 'unknown'),
          CASE
            WHEN by_identity.has_mm_capture = 1
            THEN CONCAT(' (MM, ', by_identity.n_nonconfirming_resightings, ')')
            ELSE CONCAT(' (', by_identity.n_nonconfirming_resightings, ')')
          END
        )
      END
      ORDER BY by_identity.parent_mark
      SEPARATOR ' & '
    ) AS association_details,
    GROUP_CONCAT(
      DISTINCT CASE WHEN by_identity.association_pending = 1 THEN by_identity.parent_mark END
      ORDER BY by_identity.parent_mark
      SEPARATOR ' & '
    ) AS association_marks,
    MAX(CASE WHEN by_identity.has_mm_capture = 1 THEN by_identity.parent_mark END)
      AS mm_capture_mark
  FROM by_identity
  GROUP BY by_identity.nest_id, by_identity.sex
), capture_timing AS (
  SELECT
    c.nest_id,
    MAX(CASE WHEN LEFT(c.field_sex, 1) = 'M'
      THEN CAST(CONCAT(c.date, ' ', COALESCE(c.released, c.caught, '00:00:00')) AS DATETIME) END)
      AS M_last_capture_datetime,
    MAX(CASE WHEN LEFT(c.field_sex, 1) = 'F'
      THEN CAST(CONCAT(c.date, ' ', COALESCE(c.released, c.caught, '00:00:00')) AS DATETIME) END)
      AS F_last_capture_datetime,
    MAX(CAST(CONCAT(c.date, ' ', COALESCE(c.released, c.caught, '00:00:00')) AS DATETIME))
      AS last_any_adult_capture_datetime
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age = 'A'
    AND LEFT(c.field_sex, 1) IN ('M', 'F')
    AND c.date <= sr.reference_date
  GROUP BY c.nest_id
), pivoted AS (
  SELECT
    units.nest_id,
    units.reference_date,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.selected_mark END) AS M_selected_mark,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.selected_mark END) AS F_selected_mark,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.association_details END) AS M_association_details,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.association_details END) AS F_association_details,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.association_marks END) AS M_association_marks,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.association_marks END) AS F_association_marks,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.association_pending ELSE 0 END) AS M_association_pending,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.association_pending ELSE 0 END) AS F_association_pending,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.association_ambiguous ELSE 0 END) AS M_association_ambiguous,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.association_ambiguous ELSE 0 END) AS F_association_ambiguous,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.identity_count ELSE 0 END) AS M_identity_count,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.identity_count ELSE 0 END) AS F_identity_count,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.resighting_count ELSE 0 END) AS M_resighting_count,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.resighting_count ELSE 0 END) AS F_resighting_count,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.pending_resighting_count ELSE 0 END) AS M_pending_resighting_count,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.pending_resighting_count ELSE 0 END) AS F_pending_resighting_count,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.selected_has_geo ELSE 0 END) AS M_has_geo,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.selected_has_geo ELSE 0 END) AS F_has_geo,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.any_is_dead ELSE 0 END) AS M_is_dead,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.any_is_dead ELSE 0 END) AS F_is_dead,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.any_is_au_migrant ELSE 0 END) AS M_is_au_migrant,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.any_is_au_migrant ELSE 0 END) AS F_is_au_migrant,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.any_single_colour_recruit ELSE 0 END) AS M_single_colour_recruit,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.any_single_colour_recruit ELSE 0 END) AS F_single_colour_recruit,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.any_mm_capture ELSE 0 END) AS M_has_mm_capture,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.any_mm_capture ELSE 0 END) AS F_has_mm_capture,
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.mm_capture_mark END) AS M_mm_capture_mark,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.mm_capture_mark END) AS F_mm_capture_mark
  FROM units
  LEFT JOIN status_by_sex
    ON units.nest_id = status_by_sex.nest_id
  GROUP BY units.nest_id, units.reference_date
)
SELECT
  pivoted.*,
  /*
    A pending association is not the same thing as an unknown band status.
    Pending marked identities such as WY-WG (MM, 1) are already known birds;
    only a sex with no selected or pending identity is status-unknown. This
    keeps known-banded parents on the resighting pathway rather than creating
    an unnecessary band/capture target.
  */
  CASE
    WHEN NULLIF(TRIM(COALESCE(pivoted.M_selected_mark, '')), '') IS NULL
     AND NULLIF(TRIM(COALESCE(pivoted.M_association_marks, '')), '') IS NULL
    THEN 1 ELSE 0
  END AS M_unknown_status,
  CASE
    WHEN NULLIF(TRIM(COALESCE(pivoted.F_selected_mark, '')), '') IS NULL
     AND NULLIF(TRIM(COALESCE(pivoted.F_association_marks, '')), '') IS NULL
    THEN 1 ELSE 0
  END AS F_unknown_status,
  CASE WHEN pivoted.M_association_pending = 0
         AND UPPER(TRIM(COALESCE(pivoted.M_selected_mark, ''))) = 'X-X'
       THEN 1 ELSE 0 END AS M_confirmed_unbanded,
  CASE WHEN pivoted.F_association_pending = 0
         AND UPPER(TRIM(COALESCE(pivoted.F_selected_mark, ''))) = 'X-X'
       THEN 1 ELSE 0 END AS F_confirmed_unbanded,
  CASE WHEN pivoted.M_association_pending = 0 THEN pivoted.M_selected_mark ELSE pivoted.M_association_marks END AS M_parent_mark,
  CASE WHEN pivoted.F_association_pending = 0 THEN pivoted.F_selected_mark ELSE pivoted.F_association_marks END AS F_parent_mark,
  pivoted.M_association_details AS M_resight_association_details,
  pivoted.F_association_details AS F_resight_association_details,
  pivoted.M_association_marks AS M_resight_association_marks,
  pivoted.F_association_marks AS F_resight_association_marks,
  pivoted.M_association_pending AS M_resight_association_pending,
  pivoted.F_association_pending AS F_resight_association_pending,
  pivoted.M_association_ambiguous AS M_resight_association_ambiguous,
  pivoted.F_association_ambiguous AS F_resight_association_ambiguous,
  pivoted.M_identity_count AS M_resighting_identity_count,
  pivoted.F_identity_count AS F_resighting_identity_count,
  pivoted.M_resighting_count AS M_resight_association_count,
  pivoted.F_resighting_count AS F_resight_association_count,
  pivoted.M_selected_mark AS M_resight_association_selected_mark,
  pivoted.F_selected_mark AS F_resight_association_selected_mark,
  pivoted.M_has_geo AS M_resight_association_selected_has_geo,
  pivoted.F_has_geo AS F_resight_association_selected_has_geo,
  pivoted.M_has_geo AS M_captured_has_geo,
  pivoted.F_has_geo AS F_captured_has_geo,
  pivoted.M_has_geo AS M_identity_has_geo,
  pivoted.F_has_geo AS F_identity_has_geo,
  pivoted.M_selected_mark AS M_identity_mark,
  pivoted.F_selected_mark AS F_identity_mark,
  pivoted.M_is_dead AS M_identity_is_dead,
  pivoted.F_is_dead AS F_identity_is_dead,
  pivoted.M_single_colour_recruit AS M_identity_single_colour_recruit,
  pivoted.F_single_colour_recruit AS F_identity_single_colour_recruit,
  0 AS M_mm_resight_pending,
  0 AS F_mm_resight_pending,
  pivoted.M_resighting_count AS M_mm_resight_count,
  pivoted.F_resighting_count AS F_mm_resight_count,
  0 AS M_mm_xx_parent_confirmed,
  0 AS F_mm_xx_parent_confirmed,
  0 AS M_alternate_parent_confirmed,
  0 AS F_alternate_parent_confirmed,
  CONVERT(CAST(NULL AS CHAR(255)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS M_alternate_parent_marks,
  CONVERT(CAST(NULL AS CHAR(255)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS F_alternate_parent_marks,
  CONVERT(CAST(NULL AS CHAR(255)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS M_alternate_parent_details,
  CONVERT(CAST(NULL AS CHAR(255)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS F_alternate_parent_details,
  0 AS M_post_mm_xx_seen,
  0 AS F_post_mm_xx_seen,
  capture_timing.M_last_capture_datetime,
  capture_timing.F_last_capture_datetime,
  capture_timing.last_any_adult_capture_datetime,
  0 AS both_parents_need_geo,
  0 AS M_has_unique_scrape_resight,
  0 AS F_has_unique_scrape_resight
FROM pivoted
LEFT JOIN capture_timing
  ON pivoted.nest_id = capture_timing.nest_id;


/*
  ADULT_SCRAPE_RESIGHTING_STATUS is the narrow legacy-compatible helper for
  scrape-photo eligibility only. Parent identity, association, GEO, capture,
  resighting, map, summary, and PDF decisions use ADULT_PARENT_STATUS.
  Keeping this branch in its own view prevents the large resighting diagnostic
  chain from being parsed as part of the main TODO_LIST CTE graph.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.ADULT_SCRAPE_RESIGHTING_STATUS AS

WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
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
    x.UL_norm,
    x.LL_norm,
    x.UR_norm,
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
        WHEN UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')))
               IN ('X', 'XX')
        THEN 'X'
        ELSE UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')))
      END AS UL_norm,
      CASE
        WHEN UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))
               IN ('X', 'XX')
        THEN 'X'
        ELSE UPPER(COALESCE(NULLIF(TRIM(c.LL), ''), NULLIF(TRIM(c.LL_in), '')))
      END AS LL_norm,
      CASE
        WHEN UPPER(COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')))
               IN ('X', 'XX')
        THEN 'X'
        ELSE UPPER(COALESCE(NULLIF(TRIM(c.UR), ''), NULLIF(TRIM(c.UR_in), '')))
      END AS UR_norm,
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
adult_resighting_observations AS (
  /*
    Normalize adult RESIGHTINGS once before any association or display logic.
    A captured individual is the strongest available sex assignment for a
    matching later resighting. Require exactly one captured sex so that a
    lower-mark collision between male and female captures remains ambiguous
    rather than being silently assigned to both or to either sex.

    Ordinary birds match by LL/LR, allowing short LL/LR resightings. The four
    approved single-LR GEO birds additionally match their spacer-inclusive
    canonical mark. Capture dates are bounded by the observation date so a
    future capture cannot rewrite an earlier reference-date observation.
  */
  SELECT
    raw.nest_id,
    CASE
      WHEN COUNT(DISTINCT captured.sex) = 1
      THEN MAX(captured.sex)
      ELSE raw.observed_sex
    END AS sex,
    raw.observed_sex,
    raw.obs_date,
    raw.pk,
    raw.UL_obs,
    raw.LL_obs,
    raw.UR_obs,
    raw.LR_obs,
    raw.observed_mark,
    raw.behav
  FROM (
    SELECT
      r.nest_id,
      LEFT(r.sex, 1) AS observed_sex,
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
      END AS LR_obs,
      CASE
        WHEN UPPER(NULLIF(TRIM(r.LL), '')) IN ('X', 'XX')
         AND UPPER(NULLIF(TRIM(r.LR), '')) IN ('X', 'XX')
        THEN 'X-X'
        WHEN (
          NULLIF(TRIM(r.UL), '') IS NOT NULL
          AND UPPER(NULLIF(TRIM(r.UL), '')) NOT REGEXP '^(X+|M)$'
        ) OR (
          NULLIF(TRIM(r.LL), '') IS NOT NULL
          AND UPPER(NULLIF(TRIM(r.LL), '')) NOT REGEXP '^(X+|M)$'
        ) OR (
          NULLIF(TRIM(r.UR), '') IS NOT NULL
          AND UPPER(NULLIF(TRIM(r.UR), '')) NOT REGEXP '^(X+|M)$'
        ) OR (
          NULLIF(TRIM(r.LR), '') IS NOT NULL
          AND UPPER(NULLIF(TRIM(r.LR), '')) NOT REGEXP '^(X+|M)$'
        )
        THEN FIELD_2026_BADOatNZ.format_mark(
          CASE
            WHEN UPPER(NULLIF(TRIM(r.UL), '')) IN ('X', 'XX') THEN 'X'
            ELSE UPPER(NULLIF(TRIM(r.UL), ''))
          END,
          CASE
            WHEN UPPER(NULLIF(TRIM(r.LL), '')) IN ('X', 'XX') THEN 'X'
            ELSE UPPER(NULLIF(TRIM(r.LL), ''))
          END,
          CASE
            WHEN UPPER(NULLIF(TRIM(r.UR), '')) IN ('X', 'XX') THEN 'X'
            ELSE UPPER(NULLIF(TRIM(r.UR), ''))
          END,
          CASE
            WHEN UPPER(NULLIF(TRIM(r.LR), '')) IN ('X', 'XX') THEN 'X'
            ELSE UPPER(NULLIF(TRIM(r.LR), ''))
          END
        )
        ELSE NULL
      END AS observed_mark,
      r.behav
    FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
    CROSS JOIN sr
    WHERE r.nest_id IS NOT NULL
      AND TRIM(r.nest_id) <> ''
      AND UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
      AND r.age = 'A'
      AND r.sex IN ('M', 'MU', 'F', 'FU')
      AND r.date <= sr.reference_date
  ) raw
  LEFT JOIN adult_capture_events captured
    ON captured.nest_id = raw.nest_id
   AND captured.capture_date <= raw.obs_date
   AND captured.mark IS NOT NULL
   AND (
     (
       captured.LL_norm IS NOT NULL
       AND captured.LR_norm IS NOT NULL
       AND captured.LL_norm = raw.LL_obs
       AND captured.LR_norm = raw.LR_obs
     )
     OR (CONVERT(UPPER(TRIM(captured.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci = CONVERT(UPPER(TRIM(raw.observed_mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci)
     OR (
       CONVERT(UPPER(TRIM(COALESCE(captured.ring, ''))) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci IN (
         'CP19738',
         'CP19739',
         'CP19693',
         'CP19848'
       )
       AND captured.LL_norm = raw.LL_obs
       AND captured.UR_norm REGEXP '^T[A-Z]$'
       AND captured.LR_norm REGEXP '^[A-Z]$'
       AND CONCAT(RIGHT(captured.UR_norm, 1), captured.LR_norm)
           = CONCAT(raw.UR_obs, raw.LR_obs)
     )
   )
  GROUP BY
    raw.nest_id,
    raw.observed_sex,
    raw.obs_date,
    raw.pk,
    raw.UL_obs,
    raw.LL_obs,
    raw.UR_obs,
    raw.LR_obs,
    raw.observed_mark,
    raw.behav
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
        FROM adult_resighting_observations raw
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
            OR CONVERT(UPPER(TRIM(mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci
               REGEXP '(^|[.-])T[A-Z0-9]*($|[.-])'
          THEN 1
          ELSE 0
        END AS tag_segment_rank,
        CONVERT(mark USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS mark,
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
            OR CONVERT(UPPER(TRIM(mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci
               REGEXP '(^|[.-])T[A-Z0-9]*($|[.-])'
          THEN 1
          ELSE 0
        END AS tag_segment_rank,
        CONVERT(mark USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS mark,
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
    ranked.UL_norm,
    ranked.LL_norm,
    ranked.UR_norm,
    ranked.LR_norm,
    CASE
      -- Spacer-aware matching is restricted to the four approved single-LR
      -- birds. All ordinary birds are matched by LL/LR, even when UL/UR are
      -- absent from a short resighting.
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
    r.sex,
    r.association_date,
    r.pk,
    r.LL_obs,
    r.LR_obs,
    aliases.canonical_mark,
    CASE
      WHEN r.LL_obs = 'X'
       AND r.LR_obs = 'X'
      THEN 'X-X'
      WHEN aliases.canonical_mark IS NOT NULL
      THEN aliases.canonical_mark
      WHEN (r.UL_obs IS NOT NULL AND r.UL_obs NOT REGEXP '^(X+|M)$')
        OR (r.LL_obs IS NOT NULL AND r.LL_obs NOT REGEXP '^(X+|M)$')
        OR (r.UR_obs IS NOT NULL AND r.UR_obs NOT REGEXP '^(X+|M)$')
        OR (r.LR_obs IS NOT NULL AND r.LR_obs NOT REGEXP '^(X+|M)$')
      THEN FIELD_2026_BADOatNZ.format_mark(
        r.UL_obs,
        r.LL_obs,
        r.UR_obs,
        r.LR_obs
      )
      ELSE NULL
    END AS mark,
    CASE
      WHEN r.LL_obs = 'X'
       AND r.LR_obs = 'X'
      THEN 1
      ELSE 0
    END AS is_confirmed_xx,
    CASE
      WHEN COALESCE(r.UL_obs, '') REGEXP '^T[A-Z0-9]*$'
        OR COALESCE(r.UR_obs, '') REGEXP '^T[A-Z0-9]*$'
      THEN 1
      ELSE 0
    END AS has_geo,
    CASE
      WHEN r.UL_obs IS NOT NULL
       AND r.LL_obs IS NOT NULL
       AND r.UR_obs IS NOT NULL
       AND r.LR_obs IS NOT NULL
      THEN 1
      ELSE 0
    END AS has_full_mark_observation,
    CASE
      WHEN aliases.canonical_mark IS NOT NULL
       AND aliases.requires_spacer_identity = 1
      THEN 1
      ELSE 0
    END AS requires_spacer_identity,
    CASE
      WHEN aliases.canonical_mark IS NOT NULL THEN 1
      ELSE 0
    END AS is_special_spacer_alias,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.behav, ''))) REGEXP
        '(^|[^A-Z])(BW|NM|IN|BC|FC|AC)([^A-Z]|$)'
      THEN 1
      ELSE 0
    END AS has_nest_behav
  FROM (
    SELECT
      raw.nest_id,
      raw.sex,
      raw.obs_date AS association_date,
      raw.pk,
      raw.UL_obs,
      raw.LL_obs,
      raw.UR_obs,
      raw.LR_obs,
      raw.behav
    FROM adult_resighting_observations raw
    WHERE (
      (
        raw.LL_obs = 'X'
        AND raw.LR_obs = 'X'
      )
      OR (raw.UL_obs IS NOT NULL AND raw.UL_obs NOT REGEXP '^(X+|M)$')
      OR (raw.LL_obs IS NOT NULL AND raw.LL_obs NOT REGEXP '^(X+|M)$')
      OR (raw.UR_obs IS NOT NULL AND raw.UR_obs NOT REGEXP '^(X+|M)$')
      OR (raw.LR_obs IS NOT NULL AND raw.LR_obs NOT REGEXP '^(X+|M)$')
    )
  ) r
  LEFT JOIN (
    /*
      Only the four approved single-LR birds need spacer-aware aliases. A
      short observation and a full observation carrying the spacer are
      aliases for one captured bird. Keep an alias only when it maps to one
      canonical captured mark; ambiguous aliases stay unresolved.
    */
    SELECT
      aliases.sex,
      aliases.LL_alias,
      aliases.LR_alias,
      MAX(aliases.canonical_mark) AS canonical_mark,
      MAX(aliases.requires_spacer_identity) AS requires_spacer_identity
    FROM (
      SELECT
        events.sex,
        events.LL_norm AS LL_alias,
        events.LR_norm AS LR_alias,
        CONVERT(UPPER(TRIM(events.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS canonical_mark,
        1 AS requires_spacer_identity
      FROM adult_capture_events events
      WHERE CONVERT(UPPER(TRIM(COALESCE(events.ring, ''))) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci IN (
        'CP19738',
        'CP19739',
        'CP19693',
        'CP19848'
      )
        AND events.LL_norm IS NOT NULL
        AND events.LR_norm IS NOT NULL
        AND events.mark IS NOT NULL
        AND CONVERT(UPPER(TRIM(events.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci NOT IN ('X-X', 'XX-XX', 'DEAD')

      UNION ALL

      SELECT
        events.sex,
        events.LL_norm AS LL_alias,
        CONCAT(RIGHT(events.UR_norm, 1), events.LR_norm) AS LR_alias,
        CONVERT(UPPER(TRIM(events.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS canonical_mark,
        1 AS requires_spacer_identity
      FROM adult_capture_events events
      WHERE CONVERT(UPPER(TRIM(COALESCE(events.ring, ''))) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci IN (
        'CP19738',
        'CP19739',
        'CP19693',
        'CP19848'
      )
        AND events.LL_norm IS NOT NULL
        AND events.UR_norm REGEXP '^T[A-Z]$'
        AND events.LR_norm REGEXP '^[A-Z]$'
        AND events.mark IS NOT NULL
        AND CONVERT(UPPER(TRIM(events.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci NOT IN ('X-X', 'XX-XX', 'DEAD')
    ) aliases
    GROUP BY
      aliases.sex,
      aliases.LL_alias,
      aliases.LR_alias
    HAVING COUNT(DISTINCT aliases.canonical_mark) = 1
  ) aliases
    ON aliases.sex = r.sex
   AND aliases.LL_alias = r.LL_obs
   AND aliases.LR_alias = r.LR_obs
),
adult_resighting_association_status AS (
  /*
    This is a narrow supporting helper for scrape-photo eligibility only. It
    is not a parent-task selector: all parent identity, association, capture,
    resighting, GEO, map, and PDF decisions come from ADULT_PARENT_STATUS.
    Keeping this helper separate prevents the scrape-photo task from adding a
    second parent-association pipeline.
  */
  SELECT
    classified.nest_id,
    MAX(
      CASE
        WHEN classified.sex = 'M' THEN classified.association_pending
        ELSE 0
      END
    ) AS M_resight_association_pending,
    MAX(
      CASE
        WHEN classified.sex = 'F' THEN classified.association_pending
        ELSE 0
      END
    ) AS F_resight_association_pending,
    MAX(
      CASE
        WHEN classified.sex = 'M'
         AND classified.association_pending = 1
         AND classified.n_association_identities > 1
        THEN 1
        ELSE 0
      END
    ) AS M_resight_association_ambiguous,
    MAX(
      CASE
        WHEN classified.sex = 'F'
         AND classified.association_pending = 1
         AND classified.n_association_identities > 1
        THEN 1
        ELSE 0
      END
    ) AS F_resight_association_ambiguous,
    SUM(
      CASE
        WHEN classified.sex = 'M'
         AND classified.association_pending = 1
        THEN classified.n_matching_resightings
        ELSE 0
      END
    ) AS M_resight_association_count,
    SUM(
      CASE
        WHEN classified.sex = 'F'
         AND classified.association_pending = 1
        THEN classified.n_matching_resightings
        ELSE 0
      END
    ) AS F_resight_association_count,
    MAX(
      CASE
        WHEN classified.sex = 'M'
        THEN classified.n_resighting_identities
        ELSE 0
      END
    ) AS M_resighting_identity_count,
    MAX(
      CASE
        WHEN classified.sex = 'F'
        THEN classified.n_resighting_identities
        ELSE 0
      END
    ) AS F_resighting_identity_count,
    GROUP_CONCAT(
      DISTINCT CASE
        WHEN classified.sex = 'M'
         AND classified.association_pending = 1
        THEN classified.association_mark
      END
      ORDER BY classified.association_mark
      SEPARATOR ' & '
    ) AS M_resight_association_marks,
    GROUP_CONCAT(
      DISTINCT CASE
        WHEN classified.sex = 'F'
         AND classified.association_pending = 1
        THEN classified.association_mark
      END
      ORDER BY classified.association_mark
      SEPARATOR ' & '
    ) AS F_resight_association_marks,
    GROUP_CONCAT(
      DISTINCT CASE
        WHEN classified.sex = 'M'
         AND classified.association_pending = 1
        THEN CONCAT(
          classified.association_mark,
          CASE
            WHEN classified.identity_resolved = 1 THEN ''
            ELSE CONCAT(
              ' (',
              CASE
                WHEN classified.identity_is_mm = 1 THEN 'MM, '
                ELSE ''
              END,
              classified.n_matching_resightings,
              ')'
            )
          END
        )
      END
      ORDER BY classified.association_mark
      SEPARATOR ' & '
    ) AS M_resight_association_details,
    GROUP_CONCAT(
      DISTINCT CASE
        WHEN classified.sex = 'F'
         AND classified.association_pending = 1
        THEN CONCAT(
          classified.association_mark,
          CASE
            WHEN classified.identity_resolved = 1 THEN ''
            ELSE CONCAT(
              ' (',
              CASE
                WHEN classified.identity_is_mm = 1 THEN 'MM, '
                ELSE ''
              END,
              classified.n_matching_resightings,
              ')'
            )
          END
        )
      END
      ORDER BY classified.association_mark
      SEPARATOR ' & '
    ) AS F_resight_association_details,
    GROUP_CONCAT(
      DISTINCT CASE
        WHEN classified.sex = 'M'
         AND classified.association_selected = 1
        THEN classified.association_mark
      END
      ORDER BY classified.association_mark
      SEPARATOR ' & '
    ) AS M_resight_association_selected_mark,
    GROUP_CONCAT(
      DISTINCT CASE
        WHEN classified.sex = 'F'
         AND classified.association_selected = 1
        THEN classified.association_mark
      END
      ORDER BY classified.association_mark
      SEPARATOR ' & '
    ) AS F_resight_association_selected_mark,
    MAX(
      CASE
        WHEN classified.sex = 'M'
         AND classified.association_selected = 1
        THEN classified.association_selected_has_geo
        ELSE 0
      END
    ) AS M_resight_association_selected_has_geo,
    MAX(
      CASE
        WHEN classified.sex = 'F'
         AND classified.association_selected = 1
        THEN classified.association_selected_has_geo
        ELSE 0
      END
    ) AS F_resight_association_selected_has_geo,
    MAX(
      CASE
        WHEN classified.sex = 'M'
         AND classified.has_unique_lower_band = 1
        THEN 1
        ELSE 0
      END
    ) AS M_has_unique_scrape_resight,
    MAX(
      CASE
        WHEN classified.sex = 'F'
         AND classified.has_unique_lower_band = 1
        THEN 1
        ELSE 0
      END
    ) AS F_has_unique_scrape_resight
  FROM (
    SELECT
      identity_counts.*,
      CASE
        /* One resolved identity displaces other same-sex provisional
           identities. Two independently resolved identities remain
           ambiguous and stay on the resighting task. */
        WHEN identity_counts.association_eligible = 0
        THEN 0
        WHEN identity_counts.identity_is_mm = 1
        THEN 0
        WHEN identity_counts.n_resolved_identities = 1
        THEN 0
        ELSE 1
      END AS association_pending,
      CASE
        WHEN identity_counts.association_eligible = 1
         AND identity_counts.identity_is_mm = 0
         AND identity_counts.n_resolved_identities = 1
         AND identity_counts.identity_resolved = 1
        THEN 1
        ELSE 0
      END AS association_selected,
      CASE
        WHEN identity_counts.association_eligible = 1
         AND identity_counts.identity_is_mm = 0
         AND identity_counts.n_resolved_identities = 1
         AND identity_counts.identity_resolved = 1
        THEN identity_counts.identity_has_geo
        ELSE 0
      END AS association_selected_has_geo
    FROM (
      SELECT
        identity_summary.*,
        CASE
          WHEN identity_summary.association_eligible = 1
           AND EXISTS (
            SELECT 1
            FROM adult_mm_capture_latest mm_identity
            WHERE mm_identity.nest_id = identity_summary.nest_id
              AND mm_identity.sex = identity_summary.sex
              AND (
                UPPER(TRIM(identity_summary.association_mark))
                  = UPPER(TRIM(mm_identity.mark))
                OR identity_summary.association_identity_key = CASE
                  WHEN mm_identity.requires_spacer_identity = 1
                  THEN CONCAT(
                    'full:',
                    UPPER(TRIM(mm_identity.mark))
                  )
                  ELSE CONCAT(
                    'lower:',
                    mm_identity.LL_norm,
                    '|',
                    mm_identity.LR_norm
                  )
                END
                OR (
                  mm_identity.requires_spacer_identity = 0
                  AND mm_identity.UL_norm IS NOT NULL
                  AND mm_identity.UL_norm NOT IN ('X', 'M')
                  AND mm_identity.LR_norm IS NOT NULL
                  AND identity_summary.association_identity_key = CONCAT(
                    'lower:',
                    mm_identity.UL_norm,
                    '|',
                    mm_identity.LR_norm
                  )
                )
              )
          )
          THEN 1
          ELSE 0
        END AS identity_is_mm,
        SUM(identity_summary.identity_resolved) OVER (
          PARTITION BY identity_summary.nest_id, identity_summary.sex
        ) AS n_resolved_identities,
        SUM(identity_summary.association_eligible) OVER (
          PARTITION BY identity_summary.nest_id, identity_summary.sex
        ) AS n_association_identities,
        /* Count observed identities independently of task eligibility. X-X,
           dead, and directly TN-associated birds remain visible to the PDF
           status layer but cannot open an association task. */
        COUNT(*) OVER (
          PARTITION BY identity_summary.nest_id, identity_summary.sex
        ) AS n_resighting_identities
      FROM (
        SELECT
        candidate.nest_id,
        candidate.sex,
        CASE
          WHEN candidate.canonical_mark IS NOT NULL
          THEN CONCAT(
            'canonical:',
            UPPER(TRIM(candidate.canonical_mark))
          )
          WHEN candidate.requires_spacer_identity = 0
          THEN CONCAT(
            'lower:',
            candidate.LL_obs,
            '|',
            candidate.LR_obs
          )
          ELSE CONCAT(
            'full:',
            UPPER(TRIM(candidate.mark))
          )
        END AS association_identity_key,
        CASE
          WHEN candidate.canonical_mark IS NOT NULL
          THEN candidate.canonical_mark
          WHEN candidate.requires_spacer_identity = 0
          THEN FIELD_2026_BADOatNZ.format_mark(
            'X',
            candidate.LL_obs,
            'X',
            candidate.LR_obs
          )
          ELSE candidate.mark
        END AS association_mark,
        MAX(candidate.association_eligible) AS association_eligible,
        SUM(candidate.association_eligible) AS n_matching_resightings,
        CASE
          WHEN MAX(candidate.association_eligible) = 1
           AND (
             MAX(
               CASE
                 WHEN candidate.association_eligible = 1
                 THEN candidate.has_nest_behav
                 ELSE 0
               END
             ) = 1
             OR SUM(candidate.association_eligible) >= 3
           )
          THEN 1
          ELSE 0
        END AS identity_resolved,
        MAX(
          CASE
            WHEN candidate.association_eligible = 1
            THEN candidate.has_geo
            ELSE 0
          END
        ) AS identity_has_geo,
        MAX(
          CASE
            WHEN candidate.association_eligible = 1
             AND (
              (
                candidate.LL_obs IS NOT NULL
                AND candidate.LL_obs NOT REGEXP '^(X+|M)$'
              )
              OR (
                candidate.LR_obs IS NOT NULL
                AND candidate.LR_obs NOT REGEXP '^(X+|M)$'
              )
            )
            THEN 1
            ELSE 0
          END
        ) AS has_unique_lower_band
      FROM (
        SELECT
          candidate.*,
          CASE
            WHEN UPPER(TRIM(candidate.mark)) NOT IN ('X-X', 'XX-XX', 'DEAD')
             AND (
               candidate.requires_spacer_identity = 0
               OR candidate.has_full_mark_observation = 1
               OR candidate.is_special_spacer_alias = 1
             )
             AND NOT EXISTS (
               /*
                 A same-sex TN capture at the same nest is direct association
                 evidence for that identity. It still counts as an observed
                 identity for PDF notes, but it must not create a second
                 resighting-only uncertainty task. MM is retained only as
                 identity metadata; the four-gate status view owns association
                 and no separate MM follow-up task is generated.
               */
               SELECT 1
               FROM adult_capture_events captured
               WHERE captured.nest_id = candidate.nest_id
                 AND captured.sex = candidate.sex
                 AND UPPER(TRIM(COALESCE(captured.capture_method, ''))) = 'TN'
                 AND captured.capture_date <= candidate.association_date
                 AND captured.mark IS NOT NULL
                 AND (
                   (
                     candidate.canonical_mark IS NOT NULL
                     AND UPPER(TRIM(captured.mark))
                         = UPPER(TRIM(candidate.canonical_mark))
                   )
                   OR (
                     candidate.requires_spacer_identity = 1
                     AND UPPER(TRIM(captured.mark))
                         = UPPER(TRIM(candidate.mark))
                   )
                   OR (
                     candidate.requires_spacer_identity = 0
                     AND captured.LL_norm = candidate.LL_obs
                     AND captured.LR_norm = candidate.LR_obs
                   )
                 )
             )
            THEN 1
            ELSE 0
          END AS association_eligible
        FROM adult_association_resighting_candidates candidate
        WHERE candidate.mark IS NOT NULL
      ) candidate
      GROUP BY
        candidate.nest_id,
        candidate.sex,
        CASE
          WHEN candidate.canonical_mark IS NOT NULL
          THEN CONCAT(
            'canonical:',
            UPPER(TRIM(candidate.canonical_mark))
          )
          WHEN candidate.requires_spacer_identity = 0
          THEN CONCAT(
            'lower:',
            candidate.LL_obs,
            '|',
            candidate.LR_obs
          )
          ELSE CONCAT(
            'full:',
            UPPER(TRIM(candidate.mark))
          )
        END,
        CASE
          WHEN candidate.canonical_mark IS NOT NULL
          THEN candidate.canonical_mark
          WHEN candidate.requires_spacer_identity = 0
          THEN FIELD_2026_BADOatNZ.format_mark(
            'X',
            candidate.LL_obs,
            'X',
            candidate.LR_obs
          )
          ELSE candidate.mark
        END
        ) identity_summary
    ) identity_counts
  ) classified
  GROUP BY classified.nest_id
)
SELECT * FROM adult_resighting_association_status;


/*
  TODO_NEST_HISTORY and TODO_NEST_CONTEXT are the shared operational-nest
  layer for TODO_LIST.  They deliberately materialize the reference-date-
  bounded NESTS history and its processing summaries once behind MariaDB
  view boundaries.  Task-specific CTEs should consume these small relations,
  not rescan NESTS/EGGS independently.

  This is a view-only optimization: the production app still reads the live
  FIELD_2026_BADOatNZ tables, while local RDS files remain test fixtures only.
  The output columns mirror the former TODO_LIST CTEs so task eligibility and
  PDF columns do not change.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_NEST_HISTORY AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
)
SELECT
  n.*,
  sr.reference_date AS todo_reference_date
FROM FIELD_2026_BADOatNZ.NESTS n
CROSS JOIN sr
WHERE n.nest_id IS NOT NULL
  AND TRIM(n.nest_id) <> ''
  AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
  AND n.date <= sr.reference_date;


CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT AS
WITH history AS (
  SELECT *
  FROM FIELD_2026_BADOatNZ.TODO_NEST_HISTORY
),
first_processable_visit AS (
  SELECT
    nest_id,
    MIN(date) AS first_processable_date,
    MIN(
      CAST(CONCAT(date, ' ', COALESCE(time_visit, '00:00:00')) AS DATETIME)
    ) AS first_processable_datetime
  FROM history
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
  FROM history
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
  FROM history n
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
    MAX(
      CAST(CONCAT(e.date, ' ', COALESCE(e.time_visit, '00:00:00')) AS DATETIME)
    ) AS float_datetime,
    COUNT(*) AS n_float_rows
  FROM FIELD_2026_BADOatNZ.EGGS e
  JOIN FIELD_2026_BADOatNZ.NESTS_LATEST latest_nests
    ON e.nest_id = latest_nests.nest_id
  WHERE e.date <= latest_nests.reference_date
    AND e.float_angle IS NOT NULL
    AND e.float_location IS NOT NULL
  GROUP BY e.nest_id, e.date
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
    first_processable_visit.first_processable_datetime,
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
  FROM history
  GROUP BY nest_id
),
latest_clutch_ranked AS (
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
  FROM history n
  WHERE n.clutch_size IS NOT NULL
),
latest_event_ranked AS (
  SELECT
    n.nest_id,
    n.clutch_size,
    n.date AS event_date,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
    ) AS row_num
  FROM history n
),
latest_clutch_processing_status AS (
  SELECT
    latest_clutch_ranked.nest_id,
    latest_clutch_ranked.clutch_has_photo,
    MAX(
      CASE
        WHEN latest_nests.hatch_signs_present = 1 THEN 1
        WHEN float_visit_summary.nest_id IS NOT NULL THEN 1
        ELSE 0
      END
    ) AS clutch_has_float
  FROM latest_clutch_ranked
  LEFT JOIN FIELD_2026_BADOatNZ.NESTS_LATEST latest_nests
    ON latest_clutch_ranked.nest_id = latest_nests.nest_id
  LEFT JOIN float_visit_summary
    ON latest_clutch_ranked.nest_id = float_visit_summary.nest_id
   AND float_visit_summary.float_datetime
       >= latest_clutch_ranked.clutch_datetime
  WHERE latest_clutch_ranked.row_num = 1
  GROUP BY
    latest_clutch_ranked.nest_id,
    latest_clutch_ranked.clutch_has_photo
),
clutch_at_processing_ranked AS (
  SELECT
    n.nest_id,
    n.clutch_size,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
    ) AS row_num
  FROM history n
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
  FROM history
  WHERE UPPER(TRIM(COALESCE(nest_state, ''))) = 'H'
  GROUP BY nest_id
),
observed_hatch_dates AS (
  SELECT
    nest_id,
    MIN(date) AS hatch_date
  FROM history
  WHERE UPPER(TRIM(COALESCE(nest_state, ''))) = 'H'
  GROUP BY nest_id
),
current_clutch AS (
  SELECT
    nest_id,
    clutch_size AS current_clutch_size,
    clutch_datetime AS current_clutch_datetime
  FROM latest_clutch_ranked
  WHERE row_num = 1
),
/* Compute the maximum clutch and its first recorded date in one history pass. */
historical_clutch_ranked AS (
  SELECT
    history.nest_id,
    history.clutch_size,
    CAST(
      CONCAT(
        history.date,
        ' ',
        COALESCE(history.time_visit, '00:00:00')
      ) AS DATETIME
    ) AS clutch_datetime,
    MAX(history.clutch_size) OVER (
      PARTITION BY history.nest_id
    ) AS historical_max_clutch_size
  FROM history
  WHERE history.clutch_size > 0
),
historical_max_clutch AS (
  SELECT
    nest_id,
    MAX(historical_max_clutch_size) AS historical_max_clutch_size,
    MIN(
      CASE
        WHEN clutch_size = historical_max_clutch_size
        THEN clutch_datetime
      END
    ) AS historical_max_clutch_start_datetime
  FROM historical_clutch_ranked
  GROUP BY nest_id
),
last_other_clutch AS (
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
  FROM current_clutch
  LEFT JOIN history
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
current_clutch_start AS (
  SELECT
    current_clutch.nest_id,
    MIN(
      CAST(
        CONCAT(
          history.date,
          ' ',
          COALESCE(history.time_visit, '00:00:00')
        ) AS DATETIME
      )
    ) AS current_clutch_start_datetime
  FROM current_clutch
  JOIN history
    ON current_clutch.nest_id = history.nest_id
   AND history.clutch_size = current_clutch.current_clutch_size
   AND CAST(
         CONCAT(
           history.date,
           ' ',
           COALESCE(history.time_visit, '00:00:00')
         ) AS DATETIME
       ) <= current_clutch.current_clutch_datetime
  LEFT JOIN last_other_clutch
    ON current_clutch.nest_id = last_other_clutch.nest_id
  WHERE last_other_clutch.last_other_clutch_datetime IS NULL
     OR CAST(
          CONCAT(
            history.date,
            ' ',
            COALESCE(history.time_visit, '00:00:00')
          ) AS DATETIME
        ) > last_other_clutch.last_other_clutch_datetime
  GROUP BY current_clutch.nest_id
),
latest_float_status AS (
  SELECT
    p.nest_id,
    MAX(p.float_date) AS latest_float_date,
    CAST(AVG(p.predicted_days_since_laying + p.days_since_float) AS DECIMAL(6,1))
      AS average_ref_date_days_since_laid,
    CAST(ROUND(AVG(p.min_days_to_hatch), 0) AS SIGNED) AS min_days_to_hatch
  FROM FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION p
  WHERE p.float_date IS NOT NULL
    AND p.calibration_match_type IN ('exact', 'nearest')
  GROUP BY p.nest_id
)
SELECT
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
  COALESCE(latest_float_status.latest_float_date, n.latest_float_date)
    AS latest_float_date,
  COALESCE(
    latest_float_status.average_ref_date_days_since_laid,
    n.average_ref_date_days_since_laid
  ) AS average_ref_date_days_since_laid,
  COALESCE(latest_float_status.min_days_to_hatch, n.min_days_to_hatch)
    AS base_min_days_to_hatch,
  n.nest_photo,
  n.tent_photo,
  n.lat,
  n.lon,
  n.reference_date,
  observed_hatch_dates.hatch_date AS observed_hatch_date,
  nest_discovery.first_found_date,
  first_processable_visit.first_processable_date,
  first_processable_visit.first_processable_datetime,
  processing_summary.last_photo_date,
  processing_summary.last_photo_datetime,
  processing_summary.last_float_date,
  processing_summary.last_float_datetime,
  processing_summary.n_photo_rows,
  processing_summary.n_float_rows,
  processing_summary.last_processed_datetime,
  latest_clutch_ranked.clutch_size AS latest_clutch_size,
  latest_clutch_ranked.clutch_date AS latest_clutch_date,
  latest_clutch_ranked.clutch_datetime AS latest_clutch_datetime,
  latest_clutch_ranked.clutch_has_photo AS latest_clutch_has_photo,
  latest_event_ranked.clutch_size AS latest_event_clutch_size,
  latest_event_ranked.event_date AS latest_event_date,
  latest_clutch_processing_status.clutch_has_float,
  clutch_at_processing_ranked.clutch_size AS clutch_at_processing_size,
  current_clutch.current_clutch_size,
  current_clutch.current_clutch_datetime,
  current_clutch_start.current_clutch_start_datetime,
  CASE
    WHEN current_clutch.current_clutch_size
         < historical_max_clutch.historical_max_clutch_size
    THEN historical_max_clutch.historical_max_clutch_size
    ELSE current_clutch.current_clutch_size
  END AS capture_gate_clutch_size,
  CASE
    WHEN current_clutch.current_clutch_size
         < historical_max_clutch.historical_max_clutch_size
    THEN historical_max_clutch.historical_max_clutch_start_datetime
    ELSE current_clutch_start.current_clutch_start_datetime
  END AS capture_gate_clutch_start_datetime,
  hatched_nests.hatch_date
FROM FIELD_2026_BADOatNZ.NESTS_LATEST n
LEFT JOIN latest_float_status
  ON n.nest_id = latest_float_status.nest_id
LEFT JOIN observed_hatch_dates
  ON n.nest_id = observed_hatch_dates.nest_id
LEFT JOIN nest_discovery
  ON n.nest_id = nest_discovery.nest_id
LEFT JOIN first_processable_visit
  ON n.nest_id = first_processable_visit.nest_id
LEFT JOIN processing_summary
  ON n.nest_id = processing_summary.nest_id
LEFT JOIN latest_clutch_ranked
  ON n.nest_id = latest_clutch_ranked.nest_id
 AND latest_clutch_ranked.row_num = 1
LEFT JOIN latest_event_ranked
  ON n.nest_id = latest_event_ranked.nest_id
 AND latest_event_ranked.row_num = 1
LEFT JOIN latest_clutch_processing_status
  ON n.nest_id = latest_clutch_processing_status.nest_id
LEFT JOIN clutch_at_processing_ranked
  ON n.nest_id = clutch_at_processing_ranked.nest_id
 AND clutch_at_processing_ranked.row_num = 1
LEFT JOIN current_clutch
  ON n.nest_id = current_clutch.nest_id
LEFT JOIN current_clutch_start
  ON n.nest_id = current_clutch_start.nest_id
LEFT JOIN historical_max_clutch
  ON n.nest_id = historical_max_clutch.nest_id
LEFT JOIN hatched_nests
  ON n.nest_id = hatched_nests.nest_id;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT;


/*
  TODO_BROOD_CONTEXT_INPUT is the task-facing projection of BROODS_LATEST.
  The task calculator needs only this compact set of fields, but several task
  branches use it. During a staged refresh the boundary is repointed to an
  indexed snapshot, so those branches do not expand BROODS_LATEST repeatedly.
  The fallback keeps a clean view installation functional before the first
  snapshot refresh.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_INPUT AS
SELECT
  nest_id,
  species,
  is_negative_brood,
  discovery_date,
  latest_encounter_date,
  latest_encounter_datetime,
  hatch_evidence_date,
  has_hatch_evidence,
  nest_state,
  hatch_state,
  clutch_size,
  brood_size,
  lat,
  lon,
  nest_photo,
  tent_photo,
  reference_date
FROM FIELD_2026_BADOatNZ.BROODS_LATEST;


/*
  TODO_CHICK_CAPTURE_CONTEXT_INPUT is the compact task-facing aggregate for
  age-C chick captures. It is deliberately separate from the task view because
  four task branches consume the same capture counts. During a staged refresh
  this boundary is repointed to an indexed snapshot, preventing each branch
  from rescanning and regrouping CAPTURES independently.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
chick_events AS (
  SELECT
    c.nest_id,
    NULLIF(
      NULLIF(UPPER(TRIM(COALESCE(c.ring, ''))), ''),
      'NA'
    ) AS ring_key,
    CASE
      WHEN UPPER(NULLIF(TRIM(c.UL), '')) REGEXP '^F[A-Z0-9]+$'
      THEN UPPER(NULLIF(TRIM(c.UL), ''))
      WHEN UPPER(NULLIF(TRIM(c.UL_in), '')) REGEXP '^F[A-Z0-9]+$'
      THEN UPPER(NULLIF(TRIM(c.UL_in), ''))
      ELSE NULL
    END AS flag_code
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age = 'C'
    AND c.date <= sr.reference_date
)
SELECT
  chick_events.nest_id,
  COUNT(*) AS n_chick_captures,
  COUNT(DISTINCT chick_events.ring_key) AS n_captured_chick_rings,
  COUNT(DISTINCT CASE
    WHEN chick_events.flag_code IS NOT NULL
    THEN chick_events.ring_key
  END) AS n_flagged_chick_rings,
  SUM(CASE
    WHEN chick_events.ring_key IS NULL THEN 1
    ELSE 0
  END) AS n_unringed_chick_captures
FROM chick_events
GROUP BY chick_events.nest_id;


/*
  TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT is the shared, reference-date-bounded
  H-photo aggregate. Both brood task unions need the same distinct-ring count;
  a staged refresh can therefore compute this evidence summary once without
  changing the association-method, GPS, or photo metadata predicates.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
)
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
GROUP BY h.resolved_nest_id;


/*
  TODO_PARENT_STATUS is the task-facing materialization boundary for the
  authoritative four-gate parent pipeline. Keeping this as a separate
  TEMPTABLE view prevents each parent-task branch from expanding
  ADULT_PARENT_STATUS independently. It is a projection boundary, not a
  second parent-association algorithm: the biological evidence ranking and
  diagnostic columns remain in ADULT_PARENT_STATUS.

  TODO_PARENT_STATUS_INPUT is the stable input boundary used by the
  refresh-time task query. During a clean view installation it reads the live
  authoritative pipeline. During a staged snapshot refresh it is temporarily
  repointed to the populated parent-status BUILD table, so task assembly does
  not calculate ADULT_PARENT_STATUS a second time. It is repointed to the
  promoted parent snapshot only after task assembly succeeds.

  The production server continues to read live tables. No RDS path or local
  snapshot file is referenced here.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_STATUS AS
SELECT DISTINCT status.*
FROM FIELD_2026_BADOatNZ.ADULT_PARENT_STATUS status;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_PARENT_STATUS;


/*
  The TODO task engine remains the authoritative source for fieldworker task
  eligibility, but its large CTE graph is executed as the staged refresh INSERT
  in DATABASE/refresh_todo_list_snapshot.SQL. The schema installer defines the
  bounded input views and biological evidence layers; it does not ask MariaDB
  to recursively validate the full task graph as one CREATE VIEW statement.
  This is an installation-boundary change only: the refresh query preserves
  the task columns, parent evidence, brood rules, priorities, and PDF output.
*/
/*
  Views installation boundary. This file defines the schema-layer views only.
  It deliberately does not build or publish TODO snapshot tables. After this
  file succeeds, run DATABASE/refresh_todo_list_snapshot.SQL as a separate,
  failure-safe refresh step. Ordinary app and PDF reads use the published
  snapshot.
*/

/* Remove the obsolete monolithic calculator if this is an upgrade in place. */
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE;

DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.VIEW_1;


/*
  OVERVIEW is a compact dashboard aggregate, not a task source. Its capture,
  nest, egg, and resighting CTEs summarise each domain independently and then
  expose section/metric rows for the app's Overview panel.
*/
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
        WHEN CONVERT(FIELD_2026_BADOatNZ.format_mark(
          r.UL,
          r.LL,
          r.UR,
          r.LR
        ) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci <> CONVERT('X-X' USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci
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
