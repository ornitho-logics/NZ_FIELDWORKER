/* Bound metadata-lock waits before the first DDL in this installation. */
SET SESSION lock_wait_timeout = 30;

/*
  Serialize cooperating views installations and TODO refreshes for this
  schema. The prepared SIGNAL guard was verified on MariaDB 11.8.9; if the
  target does not support it, PREPARE fails before any DDL is attempted.
  A same-connection retry reuses an existing lock instead of acquiring it
  recursively. The lock is cooperative and is released at normal completion
  or automatically when the connection terminates.
*/
SET @todo_schema_lock_name :=
  'FIELD_2026_BADOatNZ.todo_schema_refresh';
SET @todo_schema_lock_owned_on_entry := COALESCE(
  IS_USED_LOCK(@todo_schema_lock_name) = CONNECTION_ID(),
  0
);
SET @todo_schema_lock_result := CASE
  WHEN @todo_schema_lock_owned_on_entry = 1 THEN 1
  ELSE GET_LOCK(@todo_schema_lock_name, 0)
END;
SET @todo_schema_lock_guard_sql := IF(
  COALESCE(@todo_schema_lock_result, 0) = 1,
  'DO 0',
  'SIGNAL SQLSTATE ''45000'' SET MYSQL_ERRNO = 30001, MESSAGE_TEXT = ''Could not acquire FIELD_2026_BADOatNZ schema-refresh advisory lock; another views install or TODO refresh is running.'''
);
PREPARE todo_schema_lock_guard_stmt FROM @todo_schema_lock_guard_sql;
EXECUTE todo_schema_lock_guard_stmt;
DEALLOCATE PREPARE todo_schema_lock_guard_stmt;

/*
  Raw encounter-level nest-ID consensus used only as a conflict gate for
  inferred same-occasion family links. This deliberately scans all BADO/CR
  age-A and age-C rows with an exact GPS pair, independently of identity or
  mark-quality eligibility. It supplies no association by itself.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW
  FIELD_2026_BADOatNZ.TODO_RAW_ENCOUNTER_NEST_CONSENSUS AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), raw_encounters AS (
  SELECT
    c.date AS event_date,
    c.gps_id,
    c.gps_point,
    CASE
      WHEN UPPER(TRIM(COALESCE(c.nest_id, ''))) IN ('', 'NO_NEST')
      THEN NULL
      ELSE UPPER(TRIM(c.nest_id))
    END AS nest_id
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(c.species, ''))) = 'BADO'
    AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age IN ('A', 'C')
    AND c.date <= sr.reference_date
    AND c.gps_id IS NOT NULL
    AND c.gps_point IS NOT NULL

  UNION ALL

  SELECT
    r.date AS event_date,
    r.gps_id,
    r.gps_point,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.nest_id, ''))) IN ('', 'NO_NEST')
      THEN NULL
      ELSE UPPER(TRIM(r.nest_id))
    END AS nest_id
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.species, ''))) = 'BADO'
    AND UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age IN ('A', 'C')
    AND r.date <= sr.reference_date
    AND r.gps_id IS NOT NULL
    AND r.gps_point IS NOT NULL
)
SELECT
  raw_encounters.event_date,
  raw_encounters.gps_id,
  raw_encounters.gps_point,
  COUNT(DISTINCT raw_encounters.nest_id) AS n_explicit_nest_ids,
  MIN(raw_encounters.nest_id) AS explicit_nest_id
FROM raw_encounters
WHERE raw_encounters.nest_id IS NOT NULL
GROUP BY
  raw_encounters.event_date,
  raw_encounters.gps_id,
  raw_encounters.gps_point;


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

/*
  CREATE TABLE IF NOT EXISTS does not upgrade a legacy status table already
  present in the database.  Preserve its history, assign deterministic IDs to
  legacy rows that predate the primary key, then add the key and lookup index
  only when they are absent.  The prepared statements make this block safe to
  re-run after a successful installation.
*/
SET @todo_status_next_id := (
  SELECT COALESCE(MAX(refresh_id), 0)
  FROM FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS
);

UPDATE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS
SET refresh_id = (@todo_status_next_id := @todo_status_next_id + 1)
WHERE refresh_id IS NULL
ORDER BY started_at, completed_at, reference_date;

SET @todo_status_refresh_id_is_canonical := (
  SELECT COUNT(*) = 1
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
    AND TABLE_NAME = 'TODO_REFRESH_STATUS'
    AND COLUMN_NAME = 'refresh_id'
    AND LOWER(DATA_TYPE) = 'bigint'
    AND INSTR(LOWER(COLUMN_TYPE), 'unsigned') > 0
    AND IS_NULLABLE = 'NO'
    AND INSTR(LOWER(COALESCE(EXTRA, '')), 'auto_increment') > 0
);

SET @todo_status_refresh_id_type_sql := IF(
  @todo_status_refresh_id_is_canonical = 1,
  'SELECT 1',
  'ALTER TABLE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS MODIFY refresh_id BIGINT UNSIGNED NOT NULL'
);
PREPARE todo_status_refresh_id_type_stmt
  FROM @todo_status_refresh_id_type_sql;
EXECUTE todo_status_refresh_id_type_stmt;
DEALLOCATE PREPARE todo_status_refresh_id_type_stmt;

SET @todo_status_primary_key_exists := (
  SELECT COUNT(*)
  FROM information_schema.table_constraints
  WHERE constraint_schema = 'FIELD_2026_BADOatNZ'
    AND table_name = 'TODO_REFRESH_STATUS'
    AND constraint_type = 'PRIMARY KEY'
);
SET @todo_status_primary_key_sql := IF(
  @todo_status_primary_key_exists = 0,
  'ALTER TABLE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS ADD PRIMARY KEY (refresh_id)',
  'SELECT 1'
);
PREPARE todo_status_primary_key_stmt FROM @todo_status_primary_key_sql;
EXECUTE todo_status_primary_key_stmt;
DEALLOCATE PREPARE todo_status_primary_key_stmt;

SET @todo_status_refresh_id_auto_sql := IF(
  @todo_status_refresh_id_is_canonical = 1,
  'SELECT 1',
  'ALTER TABLE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS MODIFY refresh_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT'
);
PREPARE todo_status_refresh_id_auto_stmt
  FROM @todo_status_refresh_id_auto_sql;
EXECUTE todo_status_refresh_id_auto_stmt;
DEALLOCATE PREPARE todo_status_refresh_id_auto_stmt;

SET @todo_status_index_exists := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = 'FIELD_2026_BADOatNZ'
    AND table_name = 'TODO_REFRESH_STATUS'
    AND index_name = 'idx_todo_refresh_status_date'
);
SET @todo_status_index_sql := IF(
  @todo_status_index_exists = 0,
  'ALTER TABLE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS ADD INDEX idx_todo_refresh_status_date (reference_date, refresh_id)',
  'SELECT 1'
);
PREPARE todo_status_index_stmt FROM @todo_status_index_sql;
EXECUTE todo_status_index_stmt;
DEALLOCATE PREPARE todo_status_index_stmt;

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
  UNION ALL SELECT 'CR', 'GY', NULL
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
     AND available_combos_ranked.LL IN ('BY', 'WY', 'YY', 'YO', 'OY', 'GY') THEN 'CR'
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
  CASE
    WHEN UPPER(TRIM(available_combos_ranked.LL)) = 'GY' THEN 1
    ELSE 0
  END,
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
    CASE
      WHEN NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') IS NOT NULL
       AND NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') NOT IN (
         'X', 'XX', 'X-X', 'NA', 'N/A'
       )
      THEN REPLACE(UPPER(TRIM(c.ring)), '-', '')
      ELSE NULL
    END AS ring_key,
    CASE
      WHEN UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')))
             REGEXP '^F[A-Z0-9]+$'
      THEN UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')))
      ELSE NULL
    END AS flag_key,
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
    AND (
      NOT (
        COALESCE(c.UL, '') LIKE '%?%'
        OR COALESCE(c.LL, '') LIKE '%?%'
        OR COALESCE(c.UR, '') LIKE '%?%'
        OR COALESCE(c.LR, '') LIKE '%?%'
      )
      OR (
        NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') IS NOT NULL
        AND NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') NOT IN (
          'X', 'XX', 'X-X', 'NA', 'N/A'
        )
      )
    )
),
resighting_adult_observations AS (
  SELECT
    r.nest_id,
    LEFT(r.sex, 1) AS observed_sex,
    CASE
      WHEN NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') IS NOT NULL
       AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
         'X', 'XX', 'X-X', 'NA', 'N/A'
       )
      THEN REPLACE(UPPER(TRIM(r.ring)), '-', '')
      ELSE NULL
    END AS ring_key,
    CASE
      WHEN UPPER(TRIM(r.UL)) REGEXP '^F[A-Z0-9]+$'
      THEN UPPER(TRIM(r.UL))
      WHEN UPPER(TRIM(r.UR)) REGEXP '^F[A-Z0-9]+$'
      THEN UPPER(TRIM(r.UR))
      ELSE NULL
    END AS flag_key,
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
    AND UPPER(TRIM(r.nest_id)) <> 'NO_NEST'
    AND UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age <> 'C'
    AND r.sex IN ('M', 'MU', 'F', 'FU')
    AND r.date <= sr.reference_date
    AND (
      NOT (
        COALESCE(r.UL, '') LIKE '%?%'
        OR COALESCE(r.LL, '') LIKE '%?%'
        OR COALESCE(r.UR, '') LIKE '%?%'
        OR COALESCE(r.LR, '') LIKE '%?%'
      )
      OR EXISTS (
        SELECT 1
        FROM FIELD_2026_BADOatNZ.CAPTURES captured_ring
        WHERE NULLIF(REPLACE(UPPER(TRIM(captured_ring.ring)), '-', ''), '') =
              NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
          AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
            'X', 'XX', 'X-X', 'NA', 'N/A'
          )
          AND captured_ring.date <= r.date
      )
        OR EXISTS (
          SELECT 1
          FROM FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE archive_ring
          WHERE NULLIF(REPLACE(UPPER(TRIM(archive_ring.ring)), '-', ''), '') =
                NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
            AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
              'X', 'XX', 'X-X', 'NA', 'N/A'
            )
            AND archive_ring.date <= r.date
        )
    )
),
resighting_adult_resolved_sex AS (
  /*
    A ring or engraved flag is the only historical identity evidence allowed
    to resolve a sex conflict. Lower-band and full-mark matches may preserve
    an ordinary same-sex observation, but an opposite-sex weak match is kept
    as raw observation only and its mark is suppressed from parent evidence.
  */
  SELECT
    raw.nest_id,
    CASE
      WHEN COUNT(DISTINCT CASE
        WHEN (
          (raw.ring_key IS NOT NULL AND captured.ring_key = raw.ring_key)
          OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
        )
        THEN captured.sex
      END) = 1
      THEN MAX(CASE
        WHEN (
          (raw.ring_key IS NOT NULL AND captured.ring_key = raw.ring_key)
          OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
        )
        THEN captured.sex
      END)
      ELSE raw.observed_sex
    END AS sex,
    CASE
      WHEN COUNT(DISTINCT CASE
        WHEN (
          (raw.ring_key IS NOT NULL AND captured.ring_key = raw.ring_key)
          OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
        )
        THEN captured.sex
      END) = 1
      THEN raw.mark
      WHEN COUNT(DISTINCT CASE
        WHEN NOT (
          (raw.ring_key IS NOT NULL AND captured.ring_key = raw.ring_key)
          OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
        )
         AND captured.nest_id = raw.nest_id
         AND (
           (
             captured.LL_norm IS NOT NULL
             AND captured.LR_norm IS NOT NULL
             AND captured.LL_norm = raw.LL_norm
             AND captured.LR_norm = raw.LR_norm
           )
           OR CONVERT(UPPER(TRIM(captured.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci = CONVERT(UPPER(TRIM(raw.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci
         )
        THEN captured.sex
      END) = 0
      THEN raw.mark
      WHEN COUNT(DISTINCT CASE
        WHEN NOT (
          (raw.ring_key IS NOT NULL AND captured.ring_key = raw.ring_key)
          OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
        )
         AND captured.nest_id = raw.nest_id
         AND (
           (
             captured.LL_norm IS NOT NULL
             AND captured.LR_norm IS NOT NULL
             AND captured.LL_norm = raw.LL_norm
             AND captured.LR_norm = raw.LR_norm
           )
           OR CONVERT(UPPER(TRIM(captured.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci = CONVERT(UPPER(TRIM(raw.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci
         )
        THEN captured.sex
      END) = 1
       AND MAX(CASE
         WHEN NOT (
           (raw.ring_key IS NOT NULL AND captured.ring_key = raw.ring_key)
           OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
         )
          AND captured.nest_id = raw.nest_id
          AND (
            (
              captured.LL_norm IS NOT NULL
              AND captured.LR_norm IS NOT NULL
              AND captured.LL_norm = raw.LL_norm
              AND captured.LR_norm = raw.LR_norm
            )
            OR CONVERT(UPPER(TRIM(captured.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci = CONVERT(UPPER(TRIM(raw.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci
          )
         THEN captured.sex
       END) = raw.observed_sex
      THEN raw.mark
      ELSE NULL
    END AS mark
  FROM resighting_adult_observations raw
  LEFT JOIN capture_adult_marks captured
    ON captured.capture_date <= raw.observation_date
   AND (
     (
       raw.ring_key IS NOT NULL
       AND captured.ring_key = raw.ring_key
     )
     OR (
       raw.flag_key IS NOT NULL
       AND captured.flag_key = raw.flag_key
     )
     OR (
       captured.mark IS NOT NULL
       AND captured.nest_id = raw.nest_id
       AND (
         (
           captured.LL_norm IS NOT NULL
           AND captured.LR_norm IS NOT NULL
           AND captured.LL_norm = raw.LL_norm
           AND captured.LR_norm = raw.LR_norm
         )
         OR CONVERT(UPPER(TRIM(captured.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci = CONVERT(UPPER(TRIM(raw.mark)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci
       )
     )
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
  may use one same-date same-GPS adult nest evidence from a RESIGHTINGS or
  CAPTURES row, or one unambiguous preceding chick capture by ring. Multiple
  candidate nests remain unresolved so a photo task cannot be silently cleared
  for the wrong family.

  CTE roles: sr = reference-date gate; h_events = valid H rows and ring keys;
  same_occasion_adult_candidates/summary = same-date same-GPS adult evidence
  from RESIGHTINGS and CAPTURES;
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
    /* Canonical chick identity: CP-12345 and CP12345 are one ring. */
    CASE
      WHEN UPPER(TRIM(COALESCE(r.ring, ''))) IN (
        '', 'X', 'XX', 'X-X', 'NA', 'N/A'
      )
      THEN NULL
      ELSE REPLACE(UPPER(TRIM(r.ring)), '-', '')
    END AS ring_key,
    r.gps_id,
    r.gps_point,
    sr.reference_date
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'C'
    AND r.rclass = 'H'
    AND r.date <= sr.reference_date
    AND UPPER(TRIM(COALESCE(r.nest_id, ''))) <> 'NO_NEST'
    AND UPPER(TRIM(COALESCE(r.ring, ''))) NOT IN (
      '', 'X', 'XX', 'X-X', 'NA', 'N/A'
    )
),
same_occasion_adult_candidates AS (
  SELECT
    h.resighting_pk,
    adult.adult_nest_id
  FROM h_events h
  JOIN (
    SELECT
      r.date AS event_date,
      r.gps_id,
      r.gps_point,
      TRIM(r.nest_id) AS adult_nest_id
    FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
    CROSS JOIN sr
    WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
      AND r.age = 'A'
      AND r.nest_id IS NOT NULL
      AND TRIM(r.nest_id) <> ''
      AND UPPER(TRIM(r.nest_id)) <> 'NO_NEST'
      AND r.date <= sr.reference_date
      AND (
        NOT (
          COALESCE(r.UL, '') LIKE '%?%'
          OR COALESCE(r.LL, '') LIKE '%?%'
          OR COALESCE(r.UR, '') LIKE '%?%'
          OR COALESCE(r.LR, '') LIKE '%?%'
        )
        OR EXISTS (
          SELECT 1
          FROM FIELD_2026_BADOatNZ.CAPTURES captured_ring
          WHERE NULLIF(REPLACE(UPPER(TRIM(captured_ring.ring)), '-', ''), '') =
                NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
            AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
              'X', 'XX', 'X-X', 'NA', 'N/A'
            )
            AND captured_ring.date <= r.date
        )
        OR EXISTS (
          SELECT 1
          FROM FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE archive_ring
          WHERE NULLIF(REPLACE(UPPER(TRIM(archive_ring.ring)), '-', ''), '') =
                NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
            AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
              'X', 'XX', 'X-X', 'NA', 'N/A'
            )
            AND archive_ring.date <= r.date
        )
      )
    UNION ALL
    SELECT
      c.date AS event_date,
      c.gps_id,
      c.gps_point,
      TRIM(c.nest_id) AS adult_nest_id
    FROM FIELD_2026_BADOatNZ.CAPTURES c
    CROSS JOIN sr
    WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
      AND c.age = 'A'
      AND c.nest_id IS NOT NULL
      AND TRIM(c.nest_id) <> ''
      AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
      AND c.date <= sr.reference_date
      AND (
        NOT (
          COALESCE(c.UL, '') LIKE '%?%'
          OR COALESCE(c.LL, '') LIKE '%?%'
          OR COALESCE(c.UR, '') LIKE '%?%'
          OR COALESCE(c.LR, '') LIKE '%?%'
        )
        OR (
          NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') IS NOT NULL
          AND NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') NOT IN (
            'X', 'XX', 'X-X', 'NA', 'N/A'
          )
        )
      )
  ) adult
    ON adult.event_date = h.resighting_date
   AND h.gps_id IS NOT NULL
   AND h.gps_point IS NOT NULL
   AND adult.gps_id = h.gps_id
   AND adult.gps_point = h.gps_point
  JOIN FIELD_2026_BADOatNZ.TODO_RAW_ENCOUNTER_NEST_CONSENSUS encounter
    ON encounter.event_date = h.resighting_date
   AND encounter.gps_id = h.gps_id
   AND encounter.gps_point = h.gps_point
   AND encounter.n_explicit_nest_ids = 1
   AND encounter.explicit_nest_id = UPPER(TRIM(adult.adult_nest_id))
  WHERE h.raw_nest_id_key IS NULL
    AND NOT EXISTS (
      SELECT 1
      FROM FIELD_2026_BADOatNZ.CAPTURES conflicting_capture
      WHERE UPPER(TRIM(COALESCE(conflicting_capture.site, ''))) = 'CR'
        AND conflicting_capture.age = 'C'
        AND conflicting_capture.date = h.resighting_date
        AND conflicting_capture.gps_id = h.gps_id
        AND conflicting_capture.gps_point = h.gps_point
        AND conflicting_capture.nest_id IS NOT NULL
        AND TRIM(conflicting_capture.nest_id) <> ''
        AND UPPER(TRIM(conflicting_capture.nest_id)) <> 'NO_NEST'
        AND UPPER(TRIM(conflicting_capture.nest_id)) <>
            UPPER(TRIM(adult.adult_nest_id))
    )
    AND NOT EXISTS (
      SELECT 1
      FROM FIELD_2026_BADOatNZ.RESIGHTINGS conflicting_resighting
      WHERE UPPER(TRIM(COALESCE(conflicting_resighting.site, ''))) = 'CR'
        AND conflicting_resighting.age = 'C'
        AND conflicting_resighting.date = h.resighting_date
        AND conflicting_resighting.gps_id = h.gps_id
        AND conflicting_resighting.gps_point = h.gps_point
        AND conflicting_resighting.nest_id IS NOT NULL
        AND TRIM(conflicting_resighting.nest_id) <> ''
        AND UPPER(TRIM(conflicting_resighting.nest_id)) <> 'NO_NEST'
        AND UPPER(TRIM(conflicting_resighting.nest_id)) <>
            UPPER(TRIM(adult.adult_nest_id))
    )
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
    ON CASE
         WHEN UPPER(TRIM(COALESCE(c.ring, ''))) IN (
           '', 'X', 'XX', 'X-X', 'NA', 'N/A'
         )
         THEN NULL
         ELSE REPLACE(UPPER(TRIM(c.ring)), '-', '')
       END = h.ring_key
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
    WHEN h.raw_nest_id_key IS NOT NULL
    THEN h.raw_nest_id_key
    WHEN COALESCE(encounter.n_explicit_nest_ids, 0) > 1
    THEN NULL
    WHEN COALESCE(adults.n_adult_nest_ids, 0) = 1
    THEN adults.adult_nest_id
    WHEN COALESCE(adults.n_adult_nest_ids, 0) > 1
    THEN NULL
    WHEN COALESCE(captures.n_capture_nest_ids, 0) = 1
     AND (
       COALESCE(encounter.n_explicit_nest_ids, 0) = 0
       OR (
         encounter.n_explicit_nest_ids = 1
         AND encounter.explicit_nest_id = UPPER(TRIM(captures.capture_nest_id))
       )
     )
    THEN captures.capture_nest_id
    ELSE NULL
  END AS resolved_nest_id,
  CASE
    WHEN h.raw_nest_id_key IS NOT NULL
    THEN 'direct'
    WHEN COALESCE(encounter.n_explicit_nest_ids, 0) > 1
    THEN 'unresolved_encounter_conflict'
    WHEN COALESCE(adults.n_adult_nest_ids, 0) > 1
    THEN 'ambiguous_same_occasion_adult'
    WHEN COALESCE(adults.n_adult_nest_ids, 0) = 1
    THEN 'same_occasion_adult'
    WHEN COALESCE(captures.n_capture_nest_ids, 0) > 1
    THEN 'ambiguous_capture_history'
    WHEN COALESCE(captures.n_capture_nest_ids, 0) = 1
     AND (
       COALESCE(encounter.n_explicit_nest_ids, 0) = 0
       OR (
         encounter.n_explicit_nest_ids = 1
         AND encounter.explicit_nest_id = UPPER(TRIM(captures.capture_nest_id))
       )
     )
    THEN 'ring_capture'
    WHEN COALESCE(captures.n_capture_nest_ids, 0) = 1
    THEN 'unresolved_encounter_conflict'
    ELSE 'unresolved'
  END AS association_method
FROM h_events h
LEFT JOIN same_occasion_adult_summary adults
  ON h.resighting_pk = adults.resighting_pk
LEFT JOIN latest_ring_capture_summary captures
  ON h.resighting_pk = captures.resighting_pk
LEFT JOIN FIELD_2026_BADOatNZ.TODO_RAW_ENCOUNTER_NEST_CONSENSUS encounter
  ON encounter.event_date = h.resighting_date
 AND encounter.gps_id = h.gps_id
 AND encounter.gps_point = h.gps_point;


/*
  BROODS_LATEST is the unified operational source for the PDF map and parent
  summary. Positive IDs retain their stationary NESTS history. Negative IDs
  represent mobile broods with no NESTS or EGGS rows and are discovered from
  nest-linked CAPTURES/RESIGHTINGS only.

  Location, last-visit timing, and label colour are separate concepts: the
  latest valid age-C GPS event controls a brood's displayed location; the
  latest qualifying age-C CAPTURES/RESIGHTINGS event contributes to
  latest_encounter_date; and the earliest qualifying chick capture controls
  its assigned band-colour label. This preserves the fieldwork interpretation
  when chicks later move or mix while keeping task Last Visit current.

  CTE roles: sr = reference date; positive_history/status = positive history
  and hatch evidence; positive_chick_status = first age-C capture evidence;
  positive_locations = positive GPS fallback; same_occasion_chick_gps_* =
  conservative adult-linked GPS association; negative_encounters/ranked/
  discovery = mobile brood discovery; chick_events/ranked/
  direct_chick_locations = age-C union, latest encounter, and latest GPS
  choice; chick_colour_events/ranked = stable assigned colour;
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
/*
  A non-H age-C RESIGHTINGS row may carry only the GPS pair. If exactly one
  CR adult nest_id is present at the same date and GPS pair, use that brood
  association for encounter timing and mobile-brood discovery. Multiple adult
  nest_ids remain unresolved and cannot change a brood's Last Visit value.

  Adult evidence is deliberately sourced from both RESIGHTINGS and CAPTURES.
  H rows continue through RESIGHTINGS_H_BROOD_ASSOCIATIONS so their ring-based
  hiding-photo rules remain separate and auditable.
*/
same_occasion_chick_gps_candidates AS (
  SELECT
    chick.pk AS resighting_pk,
    TRIM(adult.nest_id) AS adult_nest_id
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS chick
  JOIN (
    SELECT
      r.date AS event_date,
      r.gps_id,
      r.gps_point,
      TRIM(r.nest_id) AS nest_id
    FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
    CROSS JOIN sr
    WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
      AND r.age = 'A'
      AND r.nest_id IS NOT NULL
      AND TRIM(r.nest_id) <> ''
      AND UPPER(TRIM(r.nest_id)) <> 'NO_NEST'
      AND r.date <= sr.reference_date
      AND (
        NOT (
          COALESCE(r.UL, '') LIKE '%?%'
          OR COALESCE(r.LL, '') LIKE '%?%'
          OR COALESCE(r.UR, '') LIKE '%?%'
          OR COALESCE(r.LR, '') LIKE '%?%'
        )
        OR EXISTS (
          SELECT 1
          FROM FIELD_2026_BADOatNZ.CAPTURES captured_ring
          WHERE NULLIF(REPLACE(UPPER(TRIM(captured_ring.ring)), '-', ''), '') =
                NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
            AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
              'X', 'XX', 'X-X', 'NA', 'N/A'
            )
            AND captured_ring.date <= r.date
        )
        OR EXISTS (
          SELECT 1
          FROM FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE archive_ring
          WHERE NULLIF(REPLACE(UPPER(TRIM(archive_ring.ring)), '-', ''), '') =
                NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
            AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
              'X', 'XX', 'X-X', 'NA', 'N/A'
            )
            AND archive_ring.date <= r.date
        )
      )
    UNION ALL
    SELECT
      c.date AS event_date,
      c.gps_id,
      c.gps_point,
      TRIM(c.nest_id) AS nest_id
    FROM FIELD_2026_BADOatNZ.CAPTURES c
    CROSS JOIN sr
    WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
      AND c.age = 'A'
      AND c.nest_id IS NOT NULL
      AND TRIM(c.nest_id) <> ''
      AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
      AND c.date <= sr.reference_date
      AND (
        NOT (
          COALESCE(c.UL, '') LIKE '%?%'
          OR COALESCE(c.LL, '') LIKE '%?%'
          OR COALESCE(c.UR, '') LIKE '%?%'
          OR COALESCE(c.LR, '') LIKE '%?%'
        )
        OR (
          NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') IS NOT NULL
          AND NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') NOT IN (
            'X', 'XX', 'X-X', 'NA', 'N/A'
          )
        )
      )
  ) adult
    ON adult.event_date = chick.date
   AND chick.gps_id = adult.gps_id
   AND chick.gps_point = adult.gps_point
  JOIN FIELD_2026_BADOatNZ.TODO_RAW_ENCOUNTER_NEST_CONSENSUS encounter
    ON encounter.event_date = chick.date
   AND encounter.gps_id = chick.gps_id
   AND encounter.gps_point = chick.gps_point
   AND encounter.n_explicit_nest_ids = 1
   AND encounter.explicit_nest_id = UPPER(TRIM(adult.nest_id))
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(chick.site, ''))) = 'CR'
    AND chick.age = 'C'
    AND UPPER(TRIM(COALESCE(chick.rclass, ''))) <> 'H'
    AND chick.date <= sr.reference_date
    AND chick.gps_id IS NOT NULL
    AND chick.gps_point IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM FIELD_2026_BADOatNZ.CAPTURES conflicting_capture
      WHERE UPPER(TRIM(COALESCE(conflicting_capture.site, ''))) = 'CR'
        AND conflicting_capture.age = 'C'
        AND conflicting_capture.date = chick.date
        AND conflicting_capture.gps_id = chick.gps_id
        AND conflicting_capture.gps_point = chick.gps_point
        AND conflicting_capture.nest_id IS NOT NULL
        AND TRIM(conflicting_capture.nest_id) <> ''
        AND UPPER(TRIM(conflicting_capture.nest_id)) <> 'NO_NEST'
        AND UPPER(TRIM(conflicting_capture.nest_id)) <>
            UPPER(TRIM(adult.nest_id))
    )
    AND NOT EXISTS (
      SELECT 1
      FROM FIELD_2026_BADOatNZ.RESIGHTINGS conflicting_resighting
      WHERE UPPER(TRIM(COALESCE(conflicting_resighting.site, ''))) = 'CR'
        AND conflicting_resighting.age = 'C'
        AND conflicting_resighting.date = chick.date
        AND conflicting_resighting.gps_id = chick.gps_id
        AND conflicting_resighting.gps_point = chick.gps_point
        AND conflicting_resighting.nest_id IS NOT NULL
        AND TRIM(conflicting_resighting.nest_id) <> ''
        AND UPPER(TRIM(conflicting_resighting.nest_id)) <> 'NO_NEST'
        AND UPPER(TRIM(conflicting_resighting.nest_id)) <>
            UPPER(TRIM(adult.nest_id))
    )
    AND (
      chick.nest_id IS NULL
      OR TRIM(chick.nest_id) = ''
    )
),
same_occasion_chick_gps_summary AS (
  SELECT
    resighting_pk,
    CASE
      WHEN COUNT(DISTINCT adult_nest_id) = 1
      THEN MIN(adult_nest_id)
      ELSE NULL
    END AS resolved_nest_id,
    COUNT(DISTINCT adult_nest_id) AS n_adult_nest_ids
  FROM same_occasion_chick_gps_candidates
  GROUP BY resighting_pk
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
    COALESCE(
      h_assoc.resolved_nest_id,
      gps_assoc.resolved_nest_id,
      r.nest_id
    ) AS nest_id,
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
  LEFT JOIN same_occasion_chick_gps_summary gps_assoc
    ON r.pk = gps_assoc.resighting_pk
  CROSS JOIN sr
  WHERE (
      (
        r.nest_id IS NOT NULL
        AND LEFT(TRIM(r.nest_id), 1) = '-'
      )
      OR LEFT(TRIM(h_assoc.resolved_nest_id), 1) = '-'
      OR LEFT(TRIM(gps_assoc.resolved_nest_id), 1) = '-'
    )
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
    COALESCE(
      h_assoc.resolved_nest_id,
      gps_assoc.resolved_nest_id,
      r.nest_id
    ) AS nest_id,
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
  LEFT JOIN same_occasion_chick_gps_summary gps_assoc
    ON r.pk = gps_assoc.resighting_pk
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
      OR gps_assoc.resolved_nest_id IS NOT NULL
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
    AND (
      NOT (
        COALESCE(c.UL, '') LIKE '%?%'
        OR COALESCE(c.LL, '') LIKE '%?%'
        OR COALESCE(c.UR, '') LIKE '%?%'
        OR COALESCE(c.LR, '') LIKE '%?%'
      )
      OR (
        NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') IS NOT NULL
        AND NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') NOT IN (
          'X', 'XX', 'X-X', 'NA', 'N/A'
        )
      )
    )
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
    AND (
      NOT (
        COALESCE(r.UL, '') LIKE '%?%'
        OR COALESCE(r.LL, '') LIKE '%?%'
        OR COALESCE(r.UR, '') LIKE '%?%'
        OR COALESCE(r.LR, '') LIKE '%?%'
      )
      OR EXISTS (
        SELECT 1
        FROM FIELD_2026_BADOatNZ.CAPTURES captured_ring
        WHERE NULLIF(REPLACE(UPPER(TRIM(captured_ring.ring)), '-', ''), '') =
              NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
          AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
            'X', 'XX', 'X-X', 'NA', 'N/A'
          )
          AND captured_ring.date <= r.date
      )
        OR EXISTS (
          SELECT 1
          FROM FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE archive_ring
          WHERE NULLIF(REPLACE(UPPER(TRIM(archive_ring.ring)), '-', ''), '') =
                NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
            AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
              'X', 'XX', 'X-X', 'NA', 'N/A'
            )
            AND archive_ring.date <= r.date
        )
    )
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
    CASE
      WHEN chick_latest.event_datetime >
        CAST(CONCAT(p.date, ' ', COALESCE(p.time_visit, '00:00:00')) AS DATETIME)
      THEN chick_latest.event_date
      ELSE p.date
    END AS latest_encounter_date,
    CASE
      WHEN chick_latest.event_datetime >
        CAST(CONCAT(p.date, ' ', COALESCE(p.time_visit, '00:00:00')) AS DATETIME)
      THEN chick_latest.event_datetime
      ELSE CAST(CONCAT(p.date, ' ', COALESCE(p.time_visit, '00:00:00')) AS DATETIME)
    END AS latest_encounter_datetime,
    chick_latest.event_date AS latest_chick_event_date,
    chick_latest.source_table AS latest_chick_event_source,
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
  LEFT JOIN chick_events_ranked chick_latest
    ON p.nest_id = chick_latest.nest_id
   AND chick_latest.row_num = 1
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
  GEO_ROLLOUT_PHENOLOGY was retired.  Historical GEO deployment counts,
  cumulative deployment plots, quota/reporting panels, and tagged-bird
  resighting summaries remain available through their direct CAPTURES-based
  consumers.  New deployment eligibility is calculated only by the bounded
  tag_deployment_plan in refresh_todo_list_snapshot.SQL.
*/
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.GEO_ROLLOUT_PHENOLOGY;


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
    CASE
      WHEN UPPER(TRIM(COALESCE(c.ring, ''))) IN (
        '', 'X', 'XX', 'X-X', 'NA', 'N/A'
      )
      THEN NULL
      ELSE REPLACE(UPPER(TRIM(c.ring)), '-', '')
    END AS metal_ring,
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
    CONVERT(
      CASE
        WHEN UPPER(TRIM(COALESCE(c.ring, ''))) IN (
          '', 'X', 'XX', 'X-X', 'NA', 'N/A'
        )
        THEN NULL
        ELSE REPLACE(UPPER(TRIM(c.ring)), '-', '')
      END USING utf8mb4
    ) COLLATE utf8mb4_uca1400_ai_ci AS metal_ring,
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
    CASE
      WHEN normalized_all.UL_raw LIKE '%?%'
        OR normalized_all.LL_raw LIKE '%?%'
        OR normalized_all.UR_raw LIKE '%?%'
        OR normalized_all.LR_raw LIKE '%?%'
      THEN 1
      ELSE 0
    END AS has_uncertain_mark,
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
    WHEN keyed.LL_raw IN ('X', 'XX') AND keyed.LR_raw IN ('X', 'XX')
       AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')
       AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')
      THEN 'X-X'
    WHEN keyed.UL_raw IS NOT NULL
       AND keyed.UL_raw NOT REGEXP '^(X+|M)$'
      OR keyed.LL_raw IS NOT NULL
       AND keyed.LL_raw NOT REGEXP '^(X+|M)$'
      OR keyed.UR_raw IS NOT NULL
       AND keyed.UR_raw NOT REGEXP '^(X+|M)$'
      OR keyed.LR_raw IS NOT NULL
       AND keyed.LR_raw NOT REGEXP '^(X+|M)$'
    THEN FIELD_2026_BADOatNZ.format_mark(
      keyed.UL_norm, keyed.LL_norm, keyed.UR_norm, keyed.LR_norm
    )
    ELSE NULL
  END AS display_mark,
  CASE
    WHEN keyed.LL_raw IN ('X', 'XX') AND keyed.LR_raw IN ('X', 'XX')
     AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')
     AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')
    THEN 1 ELSE 0
  END
    AS is_confirmed_xx,
  CASE
    WHEN keyed.has_uncertain_mark = 1 AND keyed.metal_ring IS NULL
    THEN 0
    ELSE 1
  END AS association_evidence_eligible,
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
), ring_status AS (
  SELECT
    normalized.*,
    CASE
      WHEN normalized.UL_raw LIKE '%?%'
        OR normalized.LL_raw LIKE '%?%'
        OR normalized.UR_raw LIKE '%?%'
        OR normalized.LR_raw LIKE '%?%'
      THEN 1
      ELSE 0
    END AS has_uncertain_mark,
    CASE
      WHEN normalized.metal_ring IS NOT NULL
       AND EXISTS (
         SELECT 1
         FROM FIELD_2026_BADOatNZ.CAPTURES captured
         WHERE CASE
             WHEN UPPER(TRIM(COALESCE(captured.ring, ''))) IN (
               '', 'X', 'XX', 'X-X', 'NA', 'N/A'
             )
             THEN NULL
             ELSE REPLACE(UPPER(TRIM(captured.ring)), '-', '')
           END = normalized.metal_ring
           AND captured.date <= normalized.observation_date
       )
       OR normalized.metal_ring IS NOT NULL
       AND EXISTS (
         SELECT 1
         FROM FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE archive_ring
         WHERE CASE
             WHEN UPPER(TRIM(COALESCE(archive_ring.ring, ''))) IN (
               '', 'X', 'XX', 'X-X', 'NA', 'N/A'
             )
             THEN NULL
             ELSE REPLACE(UPPER(TRIM(archive_ring.ring)), '-', '')
           END = normalized.metal_ring
           AND archive_ring.date <= normalized.observation_date
       )
      THEN 1
      ELSE 0
    END AS ring_traced_to_capture
  FROM normalized
), derived AS (
  SELECT
    ring_status.*,
    CASE WHEN ring_status.UL_raw IN ('X', 'XX', 'M') OR ring_status.UL_raw IS NULL
      THEN 'X' ELSE ring_status.UL_raw END AS UL_norm,
    CASE WHEN ring_status.LL_raw IN ('X', 'XX', 'M') OR ring_status.LL_raw IS NULL
      THEN 'X' ELSE ring_status.LL_raw END AS LL_norm,
    CASE WHEN ring_status.UR_raw IN ('X', 'XX', 'M') OR ring_status.UR_raw IS NULL
      THEN 'X' ELSE ring_status.UR_raw END AS UR_norm,
    CASE WHEN ring_status.LR_raw IN ('X', 'XX', 'M') OR ring_status.LR_raw IS NULL
      THEN 'X' ELSE ring_status.LR_raw END AS LR_norm,
    CASE
      WHEN ring_status.UL_raw REGEXP '^F[A-Z0-9]+$' THEN ring_status.UL_raw
      WHEN ring_status.UR_raw REGEXP '^F[A-Z0-9]+$' THEN ring_status.UR_raw
      ELSE NULL
    END AS flag_code
  FROM ring_status
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
    WHEN keyed.LL_raw IN ('X', 'XX') AND keyed.LR_raw IN ('X', 'XX')
       AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')
       AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')
      THEN 'X-X'
    WHEN keyed.UL_raw IS NOT NULL
       AND keyed.UL_raw NOT REGEXP '^(X+|M)$'
      OR keyed.LL_raw IS NOT NULL
       AND keyed.LL_raw NOT REGEXP '^(X+|M)$'
      OR keyed.UR_raw IS NOT NULL
       AND keyed.UR_raw NOT REGEXP '^(X+|M)$'
      OR keyed.LR_raw IS NOT NULL
       AND keyed.LR_raw NOT REGEXP '^(X+|M)$'
    THEN FIELD_2026_BADOatNZ.format_mark(
      keyed.UL_norm, keyed.LL_norm, keyed.UR_norm, keyed.LR_norm
    )
    ELSE NULL
  END AS observed_mark,
  CASE
    WHEN keyed.metal_ring IS NOT NULL THEN CONCAT('ring:', keyed.metal_ring)
    WHEN keyed.flag_code IS NOT NULL THEN CONCAT('flag:', keyed.flag_code)
    WHEN keyed.LL_raw IN ('X', 'XX') AND keyed.LR_raw IN ('X', 'XX')
      AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')
      AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')
      THEN CONCAT('xx:', keyed.nest_id, ':', keyed.observed_sex)
    WHEN keyed.lower_key IS NOT NULL THEN CONCAT('lower:', keyed.lower_key)
    ELSE CONCAT('resighting:', keyed.resighting_pk)
  END AS raw_identity_key,
  CASE
    WHEN keyed.LL_raw IN ('X', 'XX') AND keyed.LR_raw IN ('X', 'XX')
     AND (keyed.UL_raw IS NULL OR keyed.UL_raw REGEXP '^(X+|M)$')
     AND (keyed.UR_raw IS NULL OR keyed.UR_raw REGEXP '^(X+|M)$')
    THEN 1 ELSE 0
  END
    AS is_confirmed_xx,
  CASE
    WHEN keyed.has_uncertain_mark = 1
     AND keyed.ring_traced_to_capture = 0
    THEN 0
    ELSE 1
  END AS association_evidence_eligible,
  CASE
    /*
      Independent confirming evidence requires a valid Cass nest/brood ID
      and both observed lower fields. Negative IDs are valid without a NESTS
      row; positive IDs must already have a dated NESTS row. Blank-ID family
      linkage is handled separately and is never promoted here.
    */
    WHEN keyed.behav REGEXP '(^|[,[:space:]])(IN|NM|SC|BW|BC|FC|AC)([,[:space:]]|$)'
     AND keyed.nest_id IS NOT NULL
     AND NULLIF(keyed.LL_raw, '') IS NOT NULL
     AND NULLIF(keyed.LR_raw, '') IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM FIELD_2026_BADOatNZ.RESIGHTINGS raw_resighting
       WHERE raw_resighting.pk = keyed.resighting_pk
         AND UPPER(TRIM(COALESCE(raw_resighting.site, ''))) = 'CR'
         AND TRIM(raw_resighting.nest_id) REGEXP '^-?[ABC][0-9]{4}$'
         AND (
           LEFT(TRIM(raw_resighting.nest_id), 1) = '-'
           OR EXISTS (
             SELECT 1
             FROM FIELD_2026_BADOatNZ.NESTS known_nest
             WHERE UPPER(TRIM(known_nest.site)) = 'CR'
               AND UPPER(TRIM(known_nest.nest_id)) =
                   UPPER(TRIM(raw_resighting.nest_id))
               AND known_nest.date <= raw_resighting.date
           )
         )
     )
      THEN 1
    ELSE 0
  END AS association_confirming,
  CASE
    WHEN keyed.behav REGEXP '(^|[,[:space:]])(IN|NM|SC|BW|BC|FC|AC)([,[:space:]]|$)'
     AND keyed.nest_id IS NOT NULL
     AND NULLIF(keyed.LL_raw, '') IS NOT NULL
     AND NULLIF(keyed.LR_raw, '') IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM FIELD_2026_BADOatNZ.RESIGHTINGS raw_resighting
       WHERE raw_resighting.pk = keyed.resighting_pk
         AND UPPER(TRIM(COALESCE(raw_resighting.site, ''))) = 'CR'
         AND TRIM(raw_resighting.nest_id) REGEXP '^-?[ABC][0-9]{4}$'
         AND (
           LEFT(TRIM(raw_resighting.nest_id), 1) = '-'
           OR EXISTS (
             SELECT 1
             FROM FIELD_2026_BADOatNZ.NESTS known_nest
             WHERE UPPER(TRIM(known_nest.site)) = 'CR'
               AND UPPER(TRIM(known_nest.nest_id)) =
                   UPPER(TRIM(raw_resighting.nest_id))
               AND known_nest.date <= raw_resighting.date
           )
         )
     )
      THEN 0
    ELSE 1
  END AS association_nonconfirming
FROM keyed;


CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES AS
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES_ALL
WHERE nest_id IS NOT NULL;


/*
  Match adult resightings to captured identities once.  A ring or flag match
  is strongest; otherwise use the LL/LR key, with the spacer alias reserved
  for the known single-LR birds.  Explicit X-X observations remain raw
  unbanded evidence and cannot attach to an unrelated unmarked capture via a
  colour-only key; a verified metal-ring match remains allowed.  A short mark
  is never assigned to multiple candidates: ambiguous matches remain
  reviewable and do not inherit GEO.
*/
CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES AS

WITH candidates AS (
  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex AS candidate_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END AS sex_match,
    1 AS match_priority,
    'ring' AS match_class,
    1 AS match_strength
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES_ALL r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
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
    'flag',
    2
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES_ALL r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
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
    'lower',
    4
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES_ALL r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
    ON c.lower_key = r.lower_key
   AND c.capture_date <= r.observation_date
  WHERE r.lower_key IS NOT NULL
    AND r.is_confirmed_xx = 0
    AND c.is_confirmed_xx = 0
    AND r.metal_ring IS NULL

  UNION ALL

  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END,
    2,
    'single-lr-spacer',
    3
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES_ALL r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
    ON c.spacer_key = r.spacer_key
   AND c.capture_date <= r.observation_date
  WHERE r.spacer_key IS NOT NULL
    AND r.is_confirmed_xx = 0
    AND c.is_confirmed_xx = 0
    AND r.metal_ring IS NULL

  UNION ALL

  SELECT
    r.resighting_pk,
    c.identity_key,
    c.capture_sex,
    CASE WHEN c.capture_sex = r.observed_sex THEN 1 ELSE 0 END,
    4,
    'full',
    5
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES_ALL r
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
    ON c.full_key = r.full_key
   AND c.capture_date <= r.observation_date
  WHERE r.full_key IS NOT NULL
    AND r.is_confirmed_xx = 0
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
), best_history AS (
  /*
    Count all candidate sexes at the strongest match priority before the
    observer-sex preference is applied. This prevents a reused ring/flag
    history from appearing uniquely verified merely because one candidate
    matches the entered sex.
  */
  SELECT
    candidates.resighting_pk,
    COUNT(DISTINCT candidates.candidate_sex) AS n_candidate_sexes
  FROM candidates
  JOIN best_priority
    ON candidates.resighting_pk = best_priority.resighting_pk
   AND candidates.match_priority = best_priority.match_priority
  GROUP BY candidates.resighting_pk
), best AS (
  SELECT DISTINCT
    candidates.resighting_pk,
    candidates.identity_key,
    candidates.candidate_sex,
    candidates.match_class,
    candidates.match_strength,
    best_history.n_candidate_sexes
  FROM candidates
  JOIN best_priority
   ON candidates.resighting_pk = best_priority.resighting_pk
   AND candidates.match_priority = best_priority.match_priority
  JOIN best_sex
    ON candidates.resighting_pk = best_sex.resighting_pk
   AND candidates.match_priority = best_sex.match_priority
   AND candidates.sex_match = best_sex.sex_match
  JOIN best_history
    ON candidates.resighting_pk = best_history.resighting_pk
), best_identity AS (
  SELECT
    best.resighting_pk,
    best.identity_key,
    MIN(best.match_strength) AS match_strength,
    CASE MIN(best.match_strength)
      WHEN 1 THEN 'ring'
      WHEN 2 THEN 'flag'
      WHEN 3 THEN 'single-lr-spacer'
      WHEN 4 THEN 'lower'
      WHEN 5 THEN 'full'
    END AS match_class,
    MAX(best.candidate_sex) AS candidate_sex,
    MAX(best.n_candidate_sexes) AS n_candidate_sexes
  FROM best
  GROUP BY best.resighting_pk, best.identity_key
), counts AS (
  SELECT
    resighting_pk,
    COUNT(DISTINCT identity_key) AS n_candidate_identities
  FROM best_identity
  GROUP BY resighting_pk
), latest_capture AS (
  SELECT
    best_identity.resighting_pk,
    best_identity.identity_key,
    c.display_mark,
    c.capture_sex,
    c.has_geo,
    c.is_au_migrant,
    c.is_dead,
    c.is_single_colour_recruit,
    c.has_mm_capture,
    ROW_NUMBER() OVER (
      PARTITION BY best_identity.resighting_pk, best_identity.identity_key
      ORDER BY c.capture_datetime DESC, c.capture_pk DESC
    ) AS row_num
  FROM best_identity
  JOIN FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
    ON c.identity_key = best_identity.identity_key
), matched AS (
  SELECT
    r.nest_id,
    r.resighting_pk,
    r.observation_date,
    r.observed_sex,
    r.behav,
    r.association_confirming,
    r.association_nonconfirming,
    r.association_evidence_eligible,
    r.raw_identity_key,
    r.observed_mark,
    best_identity.identity_key,
    best_identity.match_class,
    best_identity.match_strength,
    counts.n_candidate_identities,
    best_identity.n_candidate_sexes,
    latest.display_mark AS matched_mark,
    best_identity.candidate_sex AS matched_sex,
    latest.has_geo AS matched_has_geo,
    latest.is_au_migrant AS matched_is_au_migrant,
    latest.is_dead AS matched_is_dead,
    latest.is_single_colour_recruit AS matched_single_colour_recruit,
    latest.has_mm_capture,
    CASE
      WHEN counts.n_candidate_identities = 1
       AND (
         (
           best_identity.match_strength IN (1, 2)
           AND best_identity.n_candidate_sexes = 1
         )
         OR (
           best_identity.match_strength NOT IN (1, 2)
           AND best_identity.candidate_sex = r.observed_sex
         )
       )
      THEN 1 ELSE 0
    END AS is_unique_match
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES_ALL r
  JOIN best_identity
    ON r.resighting_pk = best_identity.resighting_pk
  JOIN counts
    ON r.resighting_pk = counts.resighting_pk
  LEFT JOIN latest_capture latest
    ON latest.resighting_pk = best_identity.resighting_pk
   AND latest.identity_key = best_identity.identity_key
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
    r.association_evidence_eligible,
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
  FROM FIELD_2026_BADOatNZ.ADULT_RESIGHTING_IDENTITIES_ALL r
  WHERE NOT EXISTS (
    SELECT 1 FROM best WHERE best.resighting_pk = r.resighting_pk
  )
)
SELECT
  matched.nest_id,
  matched.resighting_pk,
  matched.observation_date,
  CASE
    WHEN matched.is_unique_match = 1
     AND matched.match_class IN ('ring', 'flag')
    THEN matched.matched_sex
    ELSE matched.observed_sex
  END AS sex,
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
  matched.association_evidence_eligible,
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
  unmatched.association_evidence_eligible,
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
  operational nest/brood on the same date, site, and exact GPS pair. If both
  the capture and chick lack nest_id, a unique banded opposite-sex adult at
  the same dated event may supply the nest through that identity's established
  nest-linked evidence. Conflicting, future, or non-unique candidates remain
  unresolved and do not promote a parent.
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
    AND captured.association_evidence_eligible = 1
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
    AND UPPER(TRIM(COALESCE(r.ring, ''))) NOT IN (
      '', 'X', 'XX', 'X-X', 'NA', 'N/A'
    )
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
    AND observed.association_evidence_eligible = 1
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
   AND c.association_evidence_eligible = 1
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
   AND c.association_evidence_eligible = 1
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
   AND c.association_evidence_eligible = 1
  WHERE r.spacer_key IS NOT NULL
    AND r.is_confirmed_xx = 0
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
   AND c.association_evidence_eligible = 1
  WHERE r.lower_key IS NOT NULL
    AND r.is_confirmed_xx = 0
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
   AND c.association_evidence_eligible = 1
  WHERE r.full_key IS NOT NULL
    AND r.is_confirmed_xx = 0
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
    r.observation_date,
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
    c.nest_id,
    c.capture_date AS evidence_date
  FROM FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES c
  WHERE c.nest_id IS NOT NULL
    AND c.definitive_capture = 1
    AND c.association_evidence_eligible = 1

  UNION

  SELECT
    r.identity_key,
    r.sex,
    r.nest_id,
    r.observation_date AS evidence_date
  FROM FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES r
  WHERE r.nest_id IS NOT NULL
    AND r.is_ambiguous_match = 0
    AND r.association_evidence_eligible = 1
    AND r.association_confirming = 1
), nest_candidates AS (
  SELECT
    c.capture_pk,
    c.identity_key,
    c.capture_sex,
    COALESCE(c.nest_id, chick.nest_id) AS nest_id,
    'capture_or_chick_nest' AS link_source
  FROM capture_identities c
  JOIN chick_events chick
    ON c.gps_id = chick.gps_id
   AND c.gps_point = chick.gps_point
   AND c.capture_date = chick.observation_date
  LEFT JOIN FIELD_2026_BADOatNZ.TODO_RAW_ENCOUNTER_NEST_CONSENSUS encounter
    ON encounter.gps_id = c.gps_id
   AND encounter.gps_point = c.gps_point
   AND encounter.event_date = c.capture_date
  WHERE (c.nest_id IS NOT NULL OR chick.nest_id IS NOT NULL)
    AND encounter.n_explicit_nest_ids = 1
    AND encounter.explicit_nest_id = UPPER(TRIM(COALESCE(c.nest_id, chick.nest_id)))

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
   AND c.capture_date = chick.observation_date
  LEFT JOIN FIELD_2026_BADOatNZ.TODO_RAW_ENCOUNTER_NEST_CONSENSUS encounter
    ON encounter.gps_id = c.gps_id
   AND encounter.gps_point = c.gps_point
   AND encounter.event_date = c.capture_date
  JOIN opposite_identity_events opposite
    ON opposite.gps_id = c.gps_id
   AND opposite.gps_point = c.gps_point
   AND opposite.observation_date = chick.observation_date
   AND opposite.established_sex <> c.capture_sex
  WHERE c.nest_id IS NULL
    AND chick.nest_id IS NULL
    AND opposite.nest_id IS NOT NULL
    AND (
      COALESCE(encounter.n_explicit_nest_ids, 0) = 0
      OR (
        encounter.n_explicit_nest_ids = 1
        AND encounter.explicit_nest_id = UPPER(TRIM(opposite.nest_id))
      )
    )

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
   AND c.capture_date = chick.observation_date
  LEFT JOIN FIELD_2026_BADOatNZ.TODO_RAW_ENCOUNTER_NEST_CONSENSUS encounter
    ON encounter.gps_id = c.gps_id
   AND encounter.gps_point = c.gps_point
   AND encounter.event_date = c.capture_date
  JOIN opposite_identity_events opposite
    ON opposite.gps_id = c.gps_id
   AND opposite.gps_point = c.gps_point
   AND opposite.observation_date = chick.observation_date
   AND opposite.established_sex <> c.capture_sex
   AND opposite.nest_id IS NULL
  JOIN known_parent_nests known
    ON known.identity_key = opposite.identity_key
   AND known.sex = opposite.established_sex
   AND known.evidence_date <= opposite.observation_date
  WHERE c.nest_id IS NULL
    AND chick.nest_id IS NULL
    AND (
      COALESCE(encounter.n_explicit_nest_ids, 0) = 0
      OR (
        encounter.n_explicit_nest_ids = 1
        AND encounter.explicit_nest_id = UPPER(TRIM(known.nest_id))
      )
    )
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
   AND captured.association_evidence_eligible = 1
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
   AND confirming.association_evidence_eligible = 1
   AND confirming.association_confirming = 1
  WHERE xx.identity_key LIKE 'xx:%'
    AND xx.association_confirming = 1
    AND xx.association_evidence_eligible = 1
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
), mm_capture_identities AS (
  /*
    MM is a nest-specific association annotation.  A bird that was caught
    with a mobile mist net at one nest must not carry the MM label into a
    later nest where it was only resighted.  Keep the identity key here so
    the resighting branch below can test the capture at the same nest.
  */
  SELECT DISTINCT
    captured.nest_id,
    captured.capture_sex AS sex,
    captured.identity_key
  FROM FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES captured
  WHERE captured.has_mm_capture = 1
    AND captured.association_evidence_eligible = 1
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
  WHERE c.association_evidence_eligible = 1

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
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM mm_capture_identities mm
        WHERE mm.nest_id = r.nest_id
          AND mm.sex = r.sex
          AND mm.identity_key = COALESCE(
            superseded.captured_identity_key,
            r.identity_key
          )
      )
      THEN 1
      ELSE 0
    END AS has_mm_capture,
    r.is_ambiguous_match AS ambiguous_match,
    0 AS chick_gps_parent_link
  FROM FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES r
  LEFT JOIN xx_superseded superseded
    ON superseded.nest_id = r.nest_id
   AND superseded.sex = r.sex
   AND superseded.xx_identity_key = r.identity_key
  WHERE r.association_evidence_eligible = 1
), event_identity_counts AS (
  SELECT
    event_union.nest_id,
    event_union.sex,
    event_union.capture_source,
    event_union.event_pk,
    COUNT(DISTINCT event_union.identity_key) AS n_identity_keys
  FROM event_union
  WHERE (
    event_union.confirming_resighting = 1
    OR event_union.nonconfirming_resighting = 1
  )
    AND event_union.ambiguous_match = 0
  GROUP BY
    event_union.nest_id,
    event_union.sex,
    event_union.capture_source,
    event_union.event_pk
), nonconfirming_ranked AS (
  SELECT
    event_union.*,
    ROW_NUMBER() OVER (
      PARTITION BY
        event_union.nest_id,
        event_union.sex,
        event_union.identity_key
      ORDER BY event_union.event_datetime, event_union.event_pk
    ) AS nonconfirming_rank
  FROM event_union
  JOIN event_identity_counts event_counts
    ON event_counts.nest_id = event_union.nest_id
   AND event_counts.sex = event_union.sex
   AND event_counts.capture_source = event_union.capture_source
   AND event_counts.event_pk = event_union.event_pk
   AND event_counts.n_identity_keys = 1
  WHERE event_union.nonconfirming_resighting = 1
), identity_summary AS (
  SELECT
    event_union.nest_id,
    event_union.sex,
    event_union.identity_key,
    CASE
      WHEN MAX(event_union.definitive_capture) = 1
      THEN MIN(CASE
        WHEN event_union.definitive_capture = 1
        THEN event_union.event_datetime
      END)
      WHEN MAX(event_union.confirming_resighting) = 1
      THEN MIN(CASE
        WHEN event_union.confirming_resighting = 1
        THEN event_union.event_datetime
      END)
      WHEN COUNT(DISTINCT CASE
        WHEN event_union.nonconfirming_resighting = 1
         AND event_counts.n_identity_keys = 1
        THEN CONCAT(event_union.capture_source, ':', event_union.event_pk)
      END) >= 3
      THEN MIN(CASE
        WHEN nonconfirming.nonconfirming_rank = 3
        THEN nonconfirming.event_datetime
      END)
      ELSE NULL
    END AS association_evidence_datetime,
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
    COUNT(DISTINCT CASE
      WHEN event_union.nonconfirming_resighting = 1
       AND event_counts.n_identity_keys = 1
      THEN CONCAT(event_union.capture_source, ':', event_union.event_pk)
    END) AS n_nonconfirming_resightings,
    COUNT(DISTINCT CASE
      WHEN event_union.confirming_resighting = 1
       AND event_counts.n_identity_keys = 1
      THEN CONCAT(event_union.capture_source, ':', event_union.event_pk)
    END) AS n_confirming_resightings,
    COUNT(DISTINCT CASE
      WHEN (event_union.confirming_resighting = 1
         OR event_union.nonconfirming_resighting = 1)
       AND event_counts.n_identity_keys = 1
      THEN CONCAT(event_union.capture_source, ':', event_union.event_pk)
    END) AS n_resightings,
    MAX(event_union.has_mm_capture) AS has_mm_capture,
    MAX(event_union.ambiguous_match) AS has_ambiguous_match
  FROM event_union
  LEFT JOIN nonconfirming_ranked nonconfirming
    ON nonconfirming.nest_id = event_union.nest_id
   AND nonconfirming.sex = event_union.sex
   AND nonconfirming.identity_key = event_union.identity_key
   AND nonconfirming.event_pk = event_union.event_pk
   AND nonconfirming.capture_source = event_union.capture_source
  LEFT JOIN event_identity_counts event_counts
    ON event_counts.nest_id = event_union.nest_id
   AND event_counts.sex = event_union.sex
   AND event_counts.capture_source = event_union.capture_source
   AND event_counts.event_pk = event_union.event_pk
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
  classified.association_evidence_datetime,
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
    MAX(CASE WHEN by_identity.association_selected = 1 THEN by_identity.identity_key END)
      AS selected_identity_key,
    MAX(
      CASE WHEN by_identity.association_selected = 1
        THEN by_identity.is_dead END
    ) AS selected_is_dead,
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
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.selected_identity_key END)
      AS M_selected_identity_key,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.selected_identity_key END)
      AS F_selected_identity_key,
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
    MAX(CASE WHEN status_by_sex.sex = 'M' THEN status_by_sex.selected_is_dead END) AS M_selected_is_dead,
    MAX(CASE WHEN status_by_sex.sex = 'F' THEN status_by_sex.selected_is_dead END) AS F_selected_is_dead,
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
  pivoted.nest_id,
  pivoted.reference_date,
  pivoted.M_selected_mark,
  pivoted.F_selected_mark,
  pivoted.M_selected_identity_key,
  pivoted.F_selected_identity_key,
  pivoted.M_association_details,
  pivoted.F_association_details,
  pivoted.M_association_marks,
  pivoted.F_association_marks,
  pivoted.M_association_pending,
  pivoted.F_association_pending,
  pivoted.M_association_ambiguous,
  pivoted.F_association_ambiguous,
  pivoted.M_identity_count,
  pivoted.F_identity_count,
  pivoted.M_resighting_count,
  pivoted.F_resighting_count,
  pivoted.M_pending_resighting_count,
  pivoted.F_pending_resighting_count,
  pivoted.M_has_geo,
  pivoted.F_has_geo,
  pivoted.M_is_dead,
  pivoted.F_is_dead,
  pivoted.M_is_au_migrant,
  pivoted.F_is_au_migrant,
  pivoted.M_single_colour_recruit,
  pivoted.F_single_colour_recruit,
  pivoted.M_has_mm_capture,
  pivoted.F_has_mm_capture,
  pivoted.M_mm_capture_mark,
  pivoted.F_mm_capture_mark,
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
  pivoted.M_selected_is_dead AS M_identity_is_dead,
  pivoted.F_selected_is_dead AS F_identity_is_dead,
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
    x.flag_key,
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
      CASE
        WHEN NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') IS NOT NULL
         AND NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') NOT IN (
           'X', 'XX', 'X-X', 'NA', 'N/A'
         )
        THEN REPLACE(UPPER(TRIM(c.ring)), '-', '')
        ELSE NULL
      END AS ring,
      CASE
        WHEN UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')))
               REGEXP '^F[A-Z0-9]+$'
        THEN UPPER(COALESCE(NULLIF(TRIM(c.UL), ''), NULLIF(TRIM(c.UL_in), '')))
        ELSE NULL
      END AS flag_key,
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
      AND (
        NOT (
          COALESCE(c.UL, '') LIKE '%?%'
          OR COALESCE(c.LL, '') LIKE '%?%'
          OR COALESCE(c.UR, '') LIKE '%?%'
          OR COALESCE(c.LR, '') LIKE '%?%'
        )
        OR (
          NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') IS NOT NULL
          AND NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') NOT IN (
            'X', 'XX', 'X-X', 'NA', 'N/A'
          )
        )
      )
  ) x
),
adult_resighting_observations AS (
  /*
    Normalize adult RESIGHTINGS once before any association or display logic.
    A unique ring or engraved flag is the only historical identity evidence
    allowed to resolve a sex conflict. Lower-band and full-mark matches may
    preserve an ordinary same-sex observation, but an opposite-sex weak match
    is kept as raw observation only and its mark is suppressed from parent
    evidence.

    Ordinary birds match by LL/LR, allowing short LL/LR resightings. The four
    approved single-LR GEO birds additionally match their spacer-inclusive
    canonical mark. Capture dates are bounded by the observation date so a
    future capture cannot rewrite an earlier reference-date observation.
  */
  SELECT
    raw.nest_id,
    CASE
      WHEN COUNT(DISTINCT CASE
        WHEN (
          (raw.ring_key IS NOT NULL AND captured.ring = raw.ring_key)
          OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
        )
        THEN captured.sex
      END) = 1
      THEN MAX(CASE
        WHEN (
          (raw.ring_key IS NOT NULL AND captured.ring = raw.ring_key)
          OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
        )
        THEN captured.sex
      END)
      ELSE raw.observed_sex
    END AS sex,
    raw.observed_sex,
    raw.obs_date,
    raw.pk,
    raw.UL_obs,
    raw.LL_obs,
    raw.UR_obs,
    raw.LR_obs,
    CASE
      WHEN COUNT(DISTINCT CASE
        WHEN (
          (raw.ring_key IS NOT NULL AND captured.ring = raw.ring_key)
          OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
        )
        THEN captured.sex
      END) = 1
      THEN raw.observed_mark
      WHEN COUNT(DISTINCT CASE
        WHEN NOT (
          (raw.ring_key IS NOT NULL AND captured.ring = raw.ring_key)
          OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
        )
         AND captured.nest_id = raw.nest_id
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
        THEN captured.sex
      END) = 0
      THEN raw.observed_mark
      WHEN COUNT(DISTINCT CASE
        WHEN NOT (
          (raw.ring_key IS NOT NULL AND captured.ring = raw.ring_key)
          OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
        )
         AND captured.nest_id = raw.nest_id
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
        THEN captured.sex
      END) = 1
       AND MAX(CASE
         WHEN NOT (
           (raw.ring_key IS NOT NULL AND captured.ring = raw.ring_key)
           OR (raw.flag_key IS NOT NULL AND captured.flag_key = raw.flag_key)
         )
          AND captured.nest_id = raw.nest_id
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
         THEN captured.sex
       END) = raw.observed_sex
      THEN raw.observed_mark
      ELSE NULL
    END AS observed_mark,
    raw.behav
  FROM (
    SELECT
      r.nest_id,
      LEFT(r.sex, 1) AS observed_sex,
      CASE
        WHEN NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') IS NOT NULL
         AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
           'X', 'XX', 'X-X', 'NA', 'N/A'
         )
        THEN REPLACE(UPPER(TRIM(r.ring)), '-', '')
        ELSE NULL
      END AS ring_key,
      CASE
        WHEN UPPER(TRIM(r.UL)) REGEXP '^F[A-Z0-9]+$'
        THEN UPPER(TRIM(r.UL))
        WHEN UPPER(TRIM(r.UR)) REGEXP '^F[A-Z0-9]+$'
        THEN UPPER(TRIM(r.UR))
        ELSE NULL
      END AS flag_key,
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
      AND (
        NOT (
          COALESCE(r.UL, '') LIKE '%?%'
          OR COALESCE(r.LL, '') LIKE '%?%'
          OR COALESCE(r.UR, '') LIKE '%?%'
          OR COALESCE(r.LR, '') LIKE '%?%'
        )
        OR EXISTS (
          SELECT 1
          FROM FIELD_2026_BADOatNZ.CAPTURES captured_ring
          WHERE NULLIF(REPLACE(UPPER(TRIM(captured_ring.ring)), '-', ''), '') =
                NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
            AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
              'X', 'XX', 'X-X', 'NA', 'N/A'
            )
            AND captured_ring.date <= r.date
        )
        OR EXISTS (
          SELECT 1
          FROM FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE archive_ring
          WHERE NULLIF(REPLACE(UPPER(TRIM(archive_ring.ring)), '-', ''), '') =
                NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
            AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
              'X', 'XX', 'X-X', 'NA', 'N/A'
            )
            AND archive_ring.date <= r.date
        )
      )
  ) raw
  LEFT JOIN adult_capture_events captured
    ON captured.capture_date <= raw.obs_date
   AND (
     (
       raw.ring_key IS NOT NULL
       AND captured.ring = raw.ring_key
     )
     OR (
       raw.flag_key IS NOT NULL
       AND captured.flag_key = raw.flag_key
     )
     OR (
       captured.mark IS NOT NULL
       AND captured.nest_id = raw.nest_id
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
     )
   )
  GROUP BY
    raw.nest_id,
    raw.observed_sex,
    raw.ring_key,
    raw.flag_key,
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
        raw.observed_mark AS mark,
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
        '(^|[^A-Z])(BW|NM|IN|SC|BC|FC|AC)([^A-Z]|$)'
       AND r.nest_id REGEXP '^-?[ABC][0-9]{4}$'
       AND r.LL_obs IS NOT NULL
       AND r.LR_obs IS NOT NULL
       AND (
         LEFT(TRIM(r.nest_id), 1) = '-'
         OR EXISTS (
           SELECT 1
           FROM FIELD_2026_BADOatNZ.NESTS known_nest
           WHERE UPPER(TRIM(known_nest.site)) = 'CR'
             AND UPPER(TRIM(known_nest.nest_id)) = UPPER(TRIM(r.nest_id))
             AND known_nest.date <= r.association_date
         )
       )
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
  TODO_CHICK_CAPTURE_CONTEXT_BASE_INPUT is the compact task-facing aggregate for
  age-C chick captures. It is deliberately separate from the task view because
  four task branches consume the same capture counts. Ring/flag-linked R/C
  rows with a missing nest_id inherit the latest unambiguous prior identity
  link; explicit nest changes are retained so post-hatch brood mixing remains
  possible. Age-J rows are also retained at event level for the derived
  whole-brood success rule, while the context aggregate below remains age-C
  only. During a staged refresh this boundary is repointed to an indexed
  snapshot, preventing each branch from rescanning and regrouping CAPTURES
  independently.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENTS_INPUT AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
raw_chick_events AS (
  SELECT
    c.pk AS capture_pk,
    c.date AS event_date,
    CAST(CONCAT(
      c.date,
      ' ',
      COALESCE(c.released, c.caught, '00:00:00')
    ) AS DATETIME) AS event_datetime,
    CASE
      WHEN c.released IS NOT NULL OR c.caught IS NOT NULL THEN 1
      ELSE 0
    END AS event_time_is_observed,
    c.age,
    c.capture_status,
    c.site,
    c.gps_id,
    c.gps_point,
    CASE
      WHEN UPPER(TRIM(COALESCE(c.nest_id, ''))) IN ('', 'NO_NEST')
      THEN NULL
      ELSE UPPER(TRIM(c.nest_id))
    END AS recorded_nest_id,
    /* Keep the install path identical to the staged refresh path. */
    CASE
      WHEN UPPER(TRIM(COALESCE(c.ring, ''))) IN (
        '', 'X', 'XX', 'X-X', 'NA', 'N/A'
      )
      THEN NULL
      ELSE REPLACE(UPPER(TRIM(c.ring)), '-', '')
    END AS ring_key,
    CASE
      WHEN UPPER(NULLIF(TRIM(c.UL), '')) REGEXP '^F[A-Z0-9]+$'
      THEN UPPER(NULLIF(TRIM(c.UL), ''))
      WHEN UPPER(NULLIF(TRIM(c.UL_in), '')) REGEXP '^F[A-Z0-9]+$'
      THEN UPPER(NULLIF(TRIM(c.UL_in), ''))
      ELSE NULL
    END AS flag_code
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age IN ('C', 'J')
    AND c.date <= sr.reference_date
),
keyed_chick_events AS (
  SELECT
    raw.*,
    CASE
      WHEN raw.ring_key IS NOT NULL
      THEN CONCAT('ring:', raw.ring_key)
      WHEN raw.flag_code IS NOT NULL
      THEN CONCAT('flag:', raw.flag_code)
      ELSE NULL
    END AS origin_key
  FROM raw_chick_events raw
),
known_ring_nest_history AS (
  SELECT
    capture_pk,
    event_date,
    origin_key,
    recorded_nest_id AS nest_id
  FROM keyed_chick_events
  WHERE origin_key IS NOT NULL
    AND recorded_nest_id IS NOT NULL
    AND UPPER(TRIM(COALESCE(capture_status, ''))) IN ('F', 'R', 'C')
),
latest_prior_ring_date AS (
  SELECT
    e.capture_pk,
    MAX(h.event_date) AS latest_prior_event_date
  FROM keyed_chick_events e
  JOIN known_ring_nest_history h
    ON h.origin_key = e.origin_key
   AND h.event_date <= e.event_date
  WHERE e.origin_key IS NOT NULL
    AND e.recorded_nest_id IS NULL
  GROUP BY e.capture_pk
),
latest_prior_ring_nests AS (
  SELECT DISTINCT
    e.capture_pk,
    h.nest_id
  FROM keyed_chick_events e
  JOIN latest_prior_ring_date d
    ON d.capture_pk = e.capture_pk
  JOIN known_ring_nest_history h
    ON h.origin_key = e.origin_key
   AND h.event_date = d.latest_prior_event_date
),
resolved_prior_ring_nests AS (
  SELECT
    capture_pk,
    MAX(nest_id) AS inferred_nest_id
  FROM latest_prior_ring_nests
  GROUP BY capture_pk
  HAVING COUNT(*) = 1
),
chick_events AS (
  SELECT
    e.capture_pk,
    e.event_date,
    e.event_datetime,
    e.event_time_is_observed,
    e.age,
    e.site,
    e.gps_id,
    e.gps_point,
    COALESCE(e.recorded_nest_id, inferred.inferred_nest_id) AS nest_id,
    CASE
      WHEN e.recorded_nest_id IS NOT NULL THEN 'recorded'
      WHEN inferred.inferred_nest_id IS NOT NULL THEN 'prior_ring'
      ELSE 'unresolved'
    END AS nest_id_source,
    e.origin_key,
    e.ring_key,
    e.flag_code,
    e.capture_status
  FROM keyed_chick_events e
  LEFT JOIN resolved_prior_ring_nests inferred
    ON inferred.capture_pk = e.capture_pk
  WHERE e.age = 'J'
     OR COALESCE(e.recorded_nest_id, inferred.inferred_nest_id) IS NOT NULL
)
SELECT
  chick_events.capture_pk,
  chick_events.event_date,
  chick_events.event_datetime,
  chick_events.event_time_is_observed,
  chick_events.age,
  chick_events.site,
  chick_events.gps_id,
  chick_events.gps_point,
  chick_events.nest_id,
  chick_events.nest_id_source,
  chick_events.origin_key,
  chick_events.ring_key,
  chick_events.flag_code,
  chick_events.capture_status
FROM chick_events;

/*
  TODO_CHICK_CAPTURE_EVENT_STATUS_INPUT is the reusable event-level bridge
  classification shared by target and aggregate views. The raw event input
  intentionally contains only source-derived fields; this view adds the
  derived flag-to-ring status without changing those raw rows.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENT_STATUS_INPUT AS
WITH chick_events AS (
  SELECT
    events.*
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENTS_INPUT events
  WHERE events.age = 'C'
), flag_ring_counts AS (
  SELECT
    dead.capture_pk AS dead_capture_pk,
    COUNT(DISTINCT bridge.ring_key) AS n_bridge_ring_keys,
    MIN(bridge.ring_key) AS bridge_ring_key
  FROM chick_events dead
  JOIN chick_events bridge
    ON bridge.flag_code = dead.flag_code
   AND bridge.ring_key IS NOT NULL
  WHERE UPPER(TRIM(COALESCE(dead.capture_status, ''))) = 'D'
    AND dead.flag_code IS NOT NULL
    AND dead.ring_key IS NULL
  GROUP BY dead.capture_pk
)
SELECT
  events.*,
  CASE
    WHEN UPPER(TRIM(COALESCE(events.capture_status, ''))) = 'D'
     AND events.ring_key IS NULL
     AND bridge.n_bridge_ring_keys = 1
    THEN 1
    ELSE 0
  END AS is_resolved_dead_bridge,
  CASE
    WHEN bridge.n_bridge_ring_keys = 1
    THEN bridge.bridge_ring_key
    ELSE NULL
  END AS resolved_dead_ring_key
FROM chick_events events
LEFT JOIN flag_ring_counts bridge
  ON bridge.dead_capture_pk = events.capture_pk;

/*
  Keep the historical capture counts for provenance, but expose separate
  operational counts for target generation. A D capture removes only the
  individually identified chick when its normalized ring is present, or when
  a missing-ring D row has one and only one global flag-to-ring bridge. Metal
  rings are project-global: a verified ring death in one brood suppresses the
  same ring target in every brood context where that ring was recorded, while
  raw brood assignments remain unchanged. A flag bridge is accepted only when
  the flag maps to one ring across all reference-date-bounded chick history.

  A death is active only when it is the latest qualifying identity event
  through reference_date. A later F/R/C event for the same global ring
  therefore prevents an inconsistent earlier D row from suppressing a live
  target. Unringed and ambiguous D rows remain unresolved and never erase an
  arbitrary sibling.

  n_active_chick_rings is the denominator for H-photo targets. For flagging,
  n_operational_brood_size subtracts only confirmed deaths that occurred after
  the latest reference-date-bounded brood count; counts with no established
  chronology retain their value and all known active rings. Downstream
  task/snapshot consumers must use these operational columns and must not
  subtract n_dead_chick_rings a second time.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_TARGETS_INPUT AS
WITH chick_events AS (
  SELECT
    events.*
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENT_STATUS_INPUT events
), death_candidates AS (
  SELECT
    dead.nest_id,
    dead.capture_pk AS dead_capture_pk,
    dead.event_date AS dead_event_date,
    dead.event_datetime AS dead_event_datetime,
    dead.event_time_is_observed AS dead_event_time_is_observed,
    dead.ring_key
  FROM chick_events dead
  WHERE UPPER(TRIM(COALESCE(dead.capture_status, ''))) = 'D'
    AND dead.ring_key IS NOT NULL

  UNION ALL

  SELECT
    dead.nest_id,
    dead.capture_pk AS dead_capture_pk,
    dead.event_date AS dead_event_date,
    dead.event_datetime AS dead_event_datetime,
    dead.event_time_is_observed AS dead_event_time_is_observed,
    dead.resolved_dead_ring_key AS ring_key
  FROM chick_events dead
  WHERE dead.is_resolved_dead_bridge = 1
), confirmed_dead_identity_keys AS (
  SELECT
    candidate.ring_key,
    MAX(candidate.dead_event_datetime) AS dead_event_datetime
  FROM death_candidates candidate
  WHERE NOT EXISTS (
    SELECT 1
    FROM chick_events later
    WHERE later.ring_key = candidate.ring_key
      AND UPPER(TRIM(COALESCE(later.capture_status, ''))) IN ('F', 'R', 'C')
      AND (
        later.event_date > candidate.dead_event_date
        OR (
          later.event_date = candidate.dead_event_date
          AND later.event_time_is_observed = 1
          AND candidate.dead_event_time_is_observed = 1
          AND (
            later.event_datetime > candidate.dead_event_datetime
            OR (
              later.event_datetime = candidate.dead_event_datetime
              AND later.capture_pk > candidate.dead_capture_pk
            )
          )
        )
      )
  )
  GROUP BY candidate.ring_key
), event_status AS (
  SELECT
    events.*,
    CASE
      WHEN dead.ring_key IS NOT NULL THEN 1
      ELSE 0
    END AS is_confirmed_dead
  FROM chick_events events
  LEFT JOIN confirmed_dead_identity_keys dead
    ON dead.ring_key = events.ring_key
)
/* The canonical key is exactly one row per nest_id/ring_key. */
SELECT
  events.nest_id,
  events.ring_key,
  CASE
    WHEN MAX(events.is_confirmed_dead) = 1 THEN 1
    ELSE 0
  END AS is_confirmed_dead,
  CASE
    WHEN MAX(events.is_confirmed_dead) = 0 THEN 1
    ELSE 0
  END AS is_active_target,
  MAX(dead.dead_event_datetime) AS dead_event_datetime,
  MAX(CASE
    WHEN NULLIF(TRIM(events.flag_code), '') IS NOT NULL THEN 1
    ELSE 0
  END) AS has_flagged_capture
FROM event_status events
LEFT JOIN confirmed_dead_identity_keys dead
  ON dead.ring_key = events.ring_key
WHERE events.ring_key IS NOT NULL
GROUP BY events.nest_id, events.ring_key;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_BASE_INPUT AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), event_counts AS (
  SELECT
    events.nest_id,
    COUNT(*) AS n_chick_captures,
    SUM(CASE
      WHEN events.ring_key IS NULL
       AND events.is_resolved_dead_bridge = 0
      THEN 1
      ELSE 0
    END) AS n_unringed_chick_captures,
    SUM(CASE
      WHEN events.ring_key IS NULL
       AND UPPER(TRIM(COALESCE(events.capture_status, ''))) = 'D'
       AND events.is_resolved_dead_bridge = 0
      THEN 1
      ELSE 0
    END) AS n_unresolved_dead_chick_events,
    SUM(CASE
      WHEN (
        events.ring_key IS NULL
        AND events.is_resolved_dead_bridge = 0
      )
        OR targets.is_active_target = 1
      THEN 1
      ELSE 0
    END) AS n_active_chick_captures
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENT_STATUS_INPUT events
  LEFT JOIN FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_TARGETS_INPUT targets
    ON targets.nest_id = events.nest_id
   AND targets.ring_key = events.ring_key
  WHERE events.age = 'C'
  GROUP BY events.nest_id
), ring_counts AS (
  SELECT
    targets.nest_id,
    COUNT(*) AS n_captured_chick_rings,
    SUM(targets.is_confirmed_dead) AS n_dead_chick_rings,
    SUM(targets.is_active_target) AS n_active_chick_rings,
    SUM(targets.has_flagged_capture) AS n_flagged_chick_rings,
    SUM(CASE
      WHEN targets.is_active_target = 1
       AND targets.has_flagged_capture = 1
      THEN 1
      ELSE 0
    END) AS n_active_flagged_chick_rings
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_TARGETS_INPUT targets
  GROUP BY targets.nest_id
), latest_brood_counts AS (
  SELECT
    n.nest_id,
    n.brood_size,
    n.date AS brood_count_date,
    CAST(CONCAT(n.date, ' ', COALESCE(n.time_visit, '00:00:00')) AS DATETIME)
      AS brood_count_datetime,
    ROW_NUMBER() OVER (
      PARTITION BY n.nest_id
      ORDER BY n.date DESC, n.time_visit DESC, n.pk DESC
    ) AS row_num
  FROM FIELD_2026_BADOatNZ.NESTS n
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
    AND LEFT(TRIM(n.nest_id), 1) <> '-'
    AND UPPER(TRIM(n.nest_id)) <> 'NO_NEST'
    AND n.brood_size IS NOT NULL
    AND n.date <= sr.reference_date
), death_count_after_latest_brood_count AS (
  SELECT
    targets.nest_id,
    COUNT(DISTINCT CASE
      WHEN brood.brood_count_datetime IS NOT NULL
       AND targets.dead_event_datetime > brood.brood_count_datetime
      THEN targets.ring_key
    END) AS n_deaths_after_latest_brood_count
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_TARGETS_INPUT targets
  LEFT JOIN latest_brood_counts brood
    ON brood.nest_id = targets.nest_id
   AND brood.row_num = 1
  WHERE targets.is_confirmed_dead = 1
  GROUP BY targets.nest_id
)
SELECT
  events.nest_id,
  events.n_chick_captures,
  COALESCE(rings.n_captured_chick_rings, 0) AS n_captured_chick_rings,
  COALESCE(rings.n_flagged_chick_rings, 0) AS n_flagged_chick_rings,
  events.n_unringed_chick_captures,
  COALESCE(rings.n_dead_chick_rings, 0) AS n_dead_chick_rings,
  COALESCE(rings.n_active_chick_rings, 0) AS n_active_chick_rings,
  COALESCE(rings.n_active_flagged_chick_rings, 0)
    AS n_active_flagged_chick_rings,
  events.n_active_chick_captures,
  events.n_unresolved_dead_chick_events,
  brood.brood_size AS observed_brood_size,
  brood.brood_count_date AS latest_brood_count_date,
  COALESCE(deaths.n_deaths_after_latest_brood_count, 0)
    AS n_deaths_after_latest_brood_count,
  CASE
    WHEN brood.brood_size IS NULL
    THEN COALESCE(rings.n_active_chick_rings, 0)
    WHEN COALESCE(deaths.n_deaths_after_latest_brood_count, 0) = 0
    THEN GREATEST(
      brood.brood_size,
      COALESCE(rings.n_active_chick_rings, 0)
    )
    ELSE GREATEST(
      brood.brood_size - deaths.n_deaths_after_latest_brood_count,
      COALESCE(rings.n_active_chick_rings, 0)
    )
  END AS n_operational_brood_size,
  CASE
    WHEN brood.brood_size IS NULL
    THEN 'captured_live_rings'
    WHEN COALESCE(deaths.n_deaths_after_latest_brood_count, 0) = 0
    THEN 'latest_brood_size'
    ELSE 'latest_brood_size_minus_deaths_after_count'
  END AS operational_brood_size_source
FROM event_counts events
LEFT JOIN ring_counts rings
  ON rings.nest_id = events.nest_id
LEFT JOIN latest_brood_counts brood
  ON brood.nest_id = events.nest_id
 AND brood.row_num = 1
LEFT JOIN death_count_after_latest_brood_count deaths
  ON deaths.nest_id = events.nest_id;

/*
  A qualifying age-J event resolves the whole brood for task purposes. The
  origin is anchored to the earliest unambiguous age-C capture with an
  explicit live nest_id, preferring first-marking captures and falling back to
  another explicit age-C origin when no first-marking row exists. Later social
  nest assignments do not replace that origin. Live F/R/C evidence supports
  the existing resolution/reactivation rules; an origin-linked age-J D row is
  developmental resolution only and does not prove survival. An explicit J
  nest_id that conflicts with a stable origin is therefore attributed to the
  origin for task purposes, without rewriting the raw row; ambiguous origins
  remain unresolved.

  Capture-origin matching uses event datetimes. RESIGHTINGS have no time field,
  so an origin-derived resighting must be strictly earlier by date; a same-day
  capture cannot be treated as proven prior evidence for an untimed sighting.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_JUVENILE_ORIGIN_EVENTS_INPUT AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), age_c_origin_evidence AS (
  SELECT
    events.origin_key AS origin_lookup_key,
    events.nest_id,
    events.event_date,
    events.event_datetime,
    CASE
      WHEN UPPER(TRIM(COALESCE(events.capture_status, ''))) = 'F'
      THEN 1 ELSE 2
    END AS origin_priority
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENTS_INPUT events
  WHERE events.age = 'C'
    AND events.nest_id_source = 'recorded'
    AND events.origin_key IS NOT NULL
    AND UPPER(TRIM(COALESCE(events.capture_status, ''))) IN ('F', 'R', 'C')
), flag_ring_links AS (
  SELECT
    events.capture_pk AS link_capture_pk,
    events.flag_code,
    events.ring_key,
    events.event_date AS link_event_date,
    events.event_datetime AS link_event_datetime
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENTS_INPUT events
  WHERE events.age = 'C'
    AND events.nest_id_source IN ('recorded', 'prior_ring')
    AND events.nest_id IS NOT NULL
    AND events.ring_key IS NOT NULL
    AND events.flag_code IS NOT NULL
    AND UPPER(TRIM(COALESCE(events.capture_status, ''))) IN ('F', 'R', 'C')
), age_c_origin_priority AS (
  SELECT
    origin_lookup_key,
    MIN(origin_priority) AS origin_priority
  FROM age_c_origin_evidence
  GROUP BY origin_lookup_key
), age_c_origin_dates AS (
  SELECT
    evidence.origin_lookup_key,
    evidence.origin_priority,
    MIN(evidence.event_date) AS first_origin_date
  FROM age_c_origin_evidence evidence
  JOIN age_c_origin_priority priority
    ON priority.origin_lookup_key = evidence.origin_lookup_key
   AND priority.origin_priority = evidence.origin_priority
  GROUP BY evidence.origin_lookup_key, evidence.origin_priority
), age_c_origin_summary AS (
  SELECT
    evidence.origin_lookup_key,
    dates.first_origin_date,
    COUNT(DISTINCT evidence.nest_id) AS n_origin_nests,
    MIN(evidence.nest_id) AS origin_nest_id,
    MIN(evidence.event_datetime) AS origin_event_datetime
  FROM age_c_origin_evidence evidence
  JOIN age_c_origin_dates dates
    ON dates.origin_lookup_key = evidence.origin_lookup_key
   AND dates.origin_priority = evidence.origin_priority
   AND dates.first_origin_date = evidence.event_date
  GROUP BY evidence.origin_lookup_key, dates.first_origin_date
), raw_resighting_events AS (
  SELECT
    r.pk AS resighting_pk,
    r.date AS event_date,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.nest_id, ''))) IN ('', 'NO_NEST')
      THEN NULL
      ELSE UPPER(TRIM(r.nest_id))
    END AS recorded_nest_id,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.ring, ''))) IN (
        '', 'X', 'XX', 'X-X', 'NA', 'N/A'
      )
      THEN NULL
      ELSE CONCAT(
        'ring:',
        REPLACE(UPPER(TRIM(r.ring)), '-', '')
      )
    END AS ring_origin_key,
    CASE
      WHEN UPPER(NULLIF(TRIM(r.UL), '')) REGEXP '^F[A-Z0-9]+$'
      THEN CONCAT('flag:', UPPER(NULLIF(TRIM(r.UL), '')))
      WHEN UPPER(NULLIF(TRIM(r.UR), '')) REGEXP '^F[A-Z0-9]+$'
      THEN CONCAT('flag:', UPPER(NULLIF(TRIM(r.UR), '')))
      ELSE NULL
    END AS flag_origin_key
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'J'
    AND r.date <= sr.reference_date
), keyed_resighting_events AS (
  SELECT
    raw.*,
    COALESCE(raw.ring_origin_key, raw.flag_origin_key) AS origin_key
  FROM raw_resighting_events raw
), resighting_flag_ring_candidates AS (
  SELECT
    current_event.resighting_pk,
    links.ring_key
  FROM keyed_resighting_events current_event
  JOIN flag_ring_links links
    ON current_event.flag_origin_key = CONCAT('flag:', links.flag_code)
   AND links.link_event_date < current_event.event_date
), resighting_flag_ring_summary AS (
  SELECT
    resighting_pk,
    COUNT(DISTINCT ring_key) AS n_ring_keys,
    MIN(ring_key) AS ring_key
  FROM resighting_flag_ring_candidates
  GROUP BY resighting_pk
), capture_flag_ring_candidates AS (
  SELECT
    captures.capture_pk,
    links.ring_key
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENTS_INPUT captures
  JOIN flag_ring_links links
    ON captures.flag_code = links.flag_code
   AND (
     links.link_event_datetime < captures.event_datetime
     OR (
       links.link_event_datetime = captures.event_datetime
       AND links.link_capture_pk < captures.capture_pk
     )
   )
  WHERE captures.age = 'J'
), capture_flag_ring_summary AS (
  SELECT
    capture_pk,
    COUNT(DISTINCT ring_key) AS n_ring_keys,
    MIN(ring_key) AS ring_key
  FROM capture_flag_ring_candidates
  GROUP BY capture_pk
), resighting_identity_conflicts AS (
  SELECT
    current_event.resighting_pk
  FROM keyed_resighting_events current_event
  JOIN resighting_flag_ring_summary flag_bridge
    ON flag_bridge.resighting_pk = current_event.resighting_pk
  WHERE current_event.flag_origin_key IS NOT NULL
    AND (
      flag_bridge.n_ring_keys <> 1
      OR (
        current_event.ring_origin_key IS NOT NULL
        AND CONCAT('ring:', flag_bridge.ring_key) <> current_event.ring_origin_key
      )
    )
), capture_identity_conflicts AS (
  SELECT
    captures.capture_pk
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENTS_INPUT captures
  JOIN capture_flag_ring_summary flag_bridge
    ON flag_bridge.capture_pk = captures.capture_pk
  WHERE captures.age = 'J'
    AND captures.flag_code IS NOT NULL
    AND (
      flag_bridge.n_ring_keys <> 1
      OR (
        captures.ring_key IS NOT NULL
        AND flag_bridge.ring_key <> captures.ring_key
      )
    )
), resighting_origin_candidates AS (
  SELECT
    current_event.resighting_pk,
    origin.origin_lookup_key,
    origin.n_origin_nests,
    origin.origin_nest_id,
    CASE
      WHEN current_event.ring_origin_key IS NOT NULL
       AND origin.origin_lookup_key = current_event.ring_origin_key
      THEN 1
      ELSE 2
    END AS match_priority
  FROM keyed_resighting_events current_event
  JOIN age_c_origin_summary origin
    ON origin.origin_lookup_key = current_event.ring_origin_key
   AND origin.first_origin_date < current_event.event_date
  LEFT JOIN resighting_flag_ring_summary flag_bridge
    ON flag_bridge.resighting_pk = current_event.resighting_pk
  WHERE current_event.ring_origin_key IS NOT NULL
    AND (
      current_event.flag_origin_key IS NULL
      OR flag_bridge.resighting_pk IS NULL
      OR (
        flag_bridge.n_ring_keys = 1
        AND CONCAT('ring:', flag_bridge.ring_key) = current_event.ring_origin_key
      )
    )
  UNION ALL
  SELECT
    current_event.resighting_pk,
    origin.origin_lookup_key,
    origin.n_origin_nests,
    origin.origin_nest_id,
    2 AS match_priority
  FROM keyed_resighting_events current_event
  JOIN resighting_flag_ring_summary bridge
    ON bridge.resighting_pk = current_event.resighting_pk
   AND bridge.n_ring_keys = 1
  JOIN age_c_origin_summary origin
    ON origin.origin_lookup_key = CONCAT('ring:', bridge.ring_key)
   AND origin.first_origin_date < current_event.event_date
  WHERE current_event.ring_origin_key IS NULL
), resighting_origin_best_priority AS (
  SELECT
    resighting_pk,
    MIN(match_priority) AS match_priority
  FROM resighting_origin_candidates
  GROUP BY resighting_pk
), resighting_origin_summary AS (
  SELECT
    candidates.resighting_pk,
    CASE
      WHEN MAX(candidates.n_origin_nests) > 1
      THEN MAX(candidates.n_origin_nests)
      ELSE COUNT(DISTINCT candidates.origin_nest_id)
    END AS n_origin_nests,
    MIN(candidates.origin_nest_id) AS origin_nest_id
  FROM resighting_origin_candidates candidates
  JOIN resighting_origin_best_priority best
    ON best.resighting_pk = candidates.resighting_pk
   AND best.match_priority = candidates.match_priority
  GROUP BY candidates.resighting_pk
), capture_origin_candidates AS (
  SELECT
    captures.capture_pk,
    origin.n_origin_nests,
    origin.origin_nest_id
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENTS_INPUT captures
  JOIN age_c_origin_summary origin
    ON origin.origin_lookup_key = captures.origin_key
   AND origin.origin_event_datetime <= captures.event_datetime
  LEFT JOIN capture_flag_ring_summary flag_bridge
    ON flag_bridge.capture_pk = captures.capture_pk
  WHERE captures.age = 'J'
    AND captures.ring_key IS NOT NULL
    AND (
      captures.flag_code IS NULL
      OR flag_bridge.capture_pk IS NULL
      OR (
        flag_bridge.n_ring_keys = 1
        AND flag_bridge.ring_key = captures.ring_key
      )
    )
  UNION ALL
  SELECT
    captures.capture_pk,
    origin.n_origin_nests,
    origin.origin_nest_id
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENTS_INPUT captures
  JOIN capture_flag_ring_summary bridge
    ON bridge.capture_pk = captures.capture_pk
   AND bridge.n_ring_keys = 1
  JOIN age_c_origin_summary origin
    ON origin.origin_lookup_key = CONCAT('ring:', bridge.ring_key)
   AND origin.origin_event_datetime <= captures.event_datetime
  WHERE captures.age = 'J'
    AND captures.ring_key IS NULL
), capture_origin_summary AS (
  SELECT
    captures.capture_pk,
    CASE
      WHEN MAX(captures.n_origin_nests) > 1
      THEN MAX(captures.n_origin_nests)
      ELSE COUNT(DISTINCT captures.origin_nest_id)
    END AS n_origin_nests,
    MIN(captures.origin_nest_id) AS origin_nest_id
  FROM capture_origin_candidates captures
  GROUP BY captures.capture_pk
), resolved_capture_events AS (
  SELECT
    captures.capture_pk,
    captures.event_date,
    CASE
      WHEN capture_conflict.capture_pk IS NOT NULL
      THEN NULL
      WHEN COALESCE(origin.n_origin_nests, 0) = 1
      THEN origin.origin_nest_id
      WHEN COALESCE(origin.n_origin_nests, 0) > 1
      THEN NULL
      WHEN captures.nest_id_source = 'recorded'
      THEN captures.nest_id
      ELSE NULL
    END AS brood_id,
    CASE
      WHEN capture_conflict.capture_pk IS NOT NULL
      THEN 'unresolved_identity_conflict'
      WHEN COALESCE(origin.n_origin_nests, 0) = 1
       AND UPPER(TRIM(COALESCE(captures.capture_status, ''))) = 'D'
      THEN 'developmental_age_j'
      WHEN COALESCE(origin.n_origin_nests, 0) = 1
      THEN 'origin_age_c'
      WHEN COALESCE(origin.n_origin_nests, 0) > 1
      THEN 'unresolved_origin_conflict'
      ELSE 'direct'
    END AS association_method,
    captures.capture_status
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_EVENTS_INPUT captures
  LEFT JOIN capture_origin_summary origin
    ON origin.capture_pk = captures.capture_pk
  LEFT JOIN capture_identity_conflicts capture_conflict
    ON capture_conflict.capture_pk = captures.capture_pk
  WHERE captures.age = 'J'
), resolved_resighting_events AS (
  SELECT
    current_event.resighting_pk,
    current_event.event_date,
    CASE
      WHEN resighting_conflict.resighting_pk IS NOT NULL
      THEN NULL
      WHEN COALESCE(origin.n_origin_nests, 0) = 1
      THEN origin.origin_nest_id
      WHEN COALESCE(origin.n_origin_nests, 0) > 1
      THEN NULL
      ELSE current_event.recorded_nest_id
    END AS brood_id,
    CASE
      WHEN resighting_conflict.resighting_pk IS NOT NULL
      THEN 'unresolved_identity_conflict'
      WHEN COALESCE(origin.n_origin_nests, 0) = 1
      THEN 'origin_age_c'
      WHEN COALESCE(origin.n_origin_nests, 0) > 1
      THEN 'unresolved_origin_conflict'
      ELSE 'direct'
    END AS association_method
  FROM keyed_resighting_events current_event
  LEFT JOIN resighting_origin_summary origin
    ON origin.resighting_pk = current_event.resighting_pk
  LEFT JOIN resighting_identity_conflicts resighting_conflict
    ON resighting_conflict.resighting_pk = current_event.resighting_pk
)
SELECT
  captures.brood_id,
  captures.event_date,
  'CAPTURES' AS source_table,
  captures.capture_pk AS source_pk,
  captures.association_method
FROM resolved_capture_events captures
WHERE captures.brood_id IS NOT NULL
  AND (
    UPPER(TRIM(COALESCE(captures.capture_status, ''))) IN ('F', 'R', 'C')
    OR captures.association_method = 'developmental_age_j'
  )
UNION ALL
SELECT
  resightings.brood_id,
  resightings.event_date,
  'RESIGHTINGS' AS source_table,
  resightings.resighting_pk AS source_pk,
  resightings.association_method
FROM resolved_resighting_events resightings
WHERE resightings.brood_id IS NOT NULL;


/*
  S10 is a task-resolution extension of the authoritative parent layer, not a
  second parent-history algorithm. It handles the narrow case where a negative
  brood already has exactly one selected M and F in
  ADULT_PARENT_NEST_ASSOCIATIONS, an unlinked current adult resighting is
  uniquely matched to one of those selected identities, and an unlinked chick
  resighting shares that adult event's exact date and GPS pair. The raw rows
  remain unchanged; ambiguous candidate broods are deliberately excluded.
*/
/*
  Stable input boundary for parent results. The refresh worker repoints this
  object to its staged parent-status build before task assembly.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW
  FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_PARENT_STATUS;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW
  FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_RESIGHTING_ASSOCIATIONS AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), selected_parent_status AS (
  SELECT
    nest_id,
    M_selected_identity_key,
    F_selected_identity_key
  FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT
), parent_sexes AS (
  SELECT 'M' AS sex
  UNION ALL
  SELECT 'F'
), selected_parent_identities AS (
  SELECT
    status.nest_id,
    sexes.sex,
    CASE sexes.sex
      WHEN 'M' THEN status.M_selected_identity_key
      ELSE status.F_selected_identity_key
    END AS identity_key
  FROM selected_parent_status status
  CROSS JOIN parent_sexes sexes
  WHERE LEFT(TRIM(status.nest_id), 1) = '-'
    AND CASE sexes.sex
      WHEN 'M' THEN status.M_selected_identity_key
      ELSE status.F_selected_identity_key
    END IS NOT NULL
), selected_parent_proof AS (
  SELECT
    selected.nest_id,
    selected.sex,
    selected.identity_key,
    MIN(DATE(association.association_evidence_datetime))
      AS association_proof_date
  FROM selected_parent_identities selected
  JOIN FIELD_2026_BADOatNZ.ADULT_PARENT_NEST_ASSOCIATIONS association
    ON association.nest_id = selected.nest_id
   AND association.sex = selected.sex
   AND association.identity_key = selected.identity_key
   AND association.association_selected = 1
   AND association.association_ambiguous = 0
   AND association.association_evidence_datetime IS NOT NULL
  GROUP BY selected.nest_id, selected.sex, selected.identity_key
), selected_parent_proof_with_summary AS (
  SELECT
    proof.nest_id,
    proof.sex,
    proof.identity_key,
    proof.association_proof_date,
    MAX(proof.association_proof_date)
      OVER (PARTITION BY proof.nest_id) AS all_parent_proof_date,
    MAX(CASE WHEN proof.sex = 'M' THEN 1 ELSE 0 END)
      OVER (PARTITION BY proof.nest_id) AS has_M_proof,
    MAX(CASE WHEN proof.sex = 'F' THEN 1 ELSE 0 END)
      OVER (PARTITION BY proof.nest_id) AS has_F_proof
  FROM selected_parent_proof proof
), unlinked_parent_resightings AS (
  SELECT
    r.pk AS parent_resighting_pk,
    r.date AS event_date,
    r.gps_id,
    r.gps_point,
    proof.nest_id,
    matched.identity_key,
    matched.sex
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  JOIN FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES matched
    ON matched.resighting_pk = r.pk
  JOIN selected_parent_proof_with_summary proof
    ON proof.identity_key = matched.identity_key
   AND proof.sex = matched.sex
   AND proof.association_proof_date <= r.date
   AND proof.all_parent_proof_date <= r.date
   AND proof.has_M_proof = 1
   AND proof.has_F_proof = 1
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'A'
    AND LEFT(r.sex, 1) IN ('M', 'F')
    AND (r.nest_id IS NULL OR TRIM(r.nest_id) = '')
    AND r.date <= sr.reference_date
    AND r.gps_id IS NOT NULL
    AND r.gps_point IS NOT NULL
    AND UPPER(TRIM(COALESCE(r.behav, ''))) REGEXP
      '(^|[,[:space:]])(BC|FC|AC)([,[:space:]]|$)'
    AND matched.match_class <> 'unmatched'
    AND matched.is_ambiguous_match = 0
    AND COALESCE(matched.n_candidate_identities, 0) = 1
    AND matched.association_evidence_eligible = 1
), unlinked_chick_resightings AS (
  SELECT
    r.pk AS chick_resighting_pk,
    r.date AS event_date,
    r.rclass,
    r.gps_id,
    r.gps_point,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.ring, ''))) IN (
        '', 'X', 'XX', 'X-X', 'NA', 'N/A'
      )
      THEN NULL
      ELSE REPLACE(UPPER(TRIM(r.ring)), '-', '')
    END AS ring_key
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'C'
    AND (r.nest_id IS NULL OR TRIM(r.nest_id) = '')
    AND r.date <= sr.reference_date
    AND r.gps_id IS NOT NULL
    AND r.gps_point IS NOT NULL
), candidate_links AS (
  SELECT
    chick.chick_resighting_pk,
    parent.nest_id,
    chick.ring_key
  FROM unlinked_chick_resightings chick
  JOIN unlinked_parent_resightings parent
    ON parent.event_date = chick.event_date
   AND parent.gps_id = chick.gps_id
   AND parent.gps_point = chick.gps_point
  LEFT JOIN FIELD_2026_BADOatNZ.TODO_RAW_ENCOUNTER_NEST_CONSENSUS encounter
    ON encounter.event_date = chick.event_date
   AND encounter.gps_id = chick.gps_id
   AND encounter.gps_point = chick.gps_point
  WHERE (
      UPPER(TRIM(COALESCE(chick.rclass, ''))) <> 'H'
      OR chick.ring_key IS NOT NULL
    )
    AND (
      COALESCE(encounter.n_explicit_nest_ids, 0) = 0
      OR (
        encounter.n_explicit_nest_ids = 1
        AND encounter.explicit_nest_id = UPPER(TRIM(parent.nest_id))
      )
    )
    AND NOT EXISTS (
      SELECT 1
      FROM FIELD_2026_BADOatNZ.CAPTURES conflicting_capture
      WHERE UPPER(TRIM(COALESCE(conflicting_capture.site, ''))) = 'CR'
        AND conflicting_capture.age = 'C'
        AND conflicting_capture.date = chick.event_date
        AND conflicting_capture.gps_id = chick.gps_id
        AND conflicting_capture.gps_point = chick.gps_point
        AND conflicting_capture.nest_id IS NOT NULL
        AND TRIM(conflicting_capture.nest_id) <> ''
        AND UPPER(TRIM(conflicting_capture.nest_id)) <> 'NO_NEST'
        AND UPPER(TRIM(conflicting_capture.nest_id)) <>
            UPPER(TRIM(parent.nest_id))
    )
    AND NOT EXISTS (
      SELECT 1
      FROM FIELD_2026_BADOatNZ.RESIGHTINGS conflicting_resighting
      WHERE UPPER(TRIM(COALESCE(conflicting_resighting.site, ''))) = 'CR'
        AND conflicting_resighting.age = 'C'
        AND conflicting_resighting.date = chick.event_date
        AND conflicting_resighting.gps_id = chick.gps_id
        AND conflicting_resighting.gps_point = chick.gps_point
        AND conflicting_resighting.nest_id IS NOT NULL
        AND TRIM(conflicting_resighting.nest_id) <> ''
        AND UPPER(TRIM(conflicting_resighting.nest_id)) <> 'NO_NEST'
        AND UPPER(TRIM(conflicting_resighting.nest_id)) <>
            UPPER(TRIM(parent.nest_id))
    )
), unique_links AS (
  SELECT
    chick_resighting_pk,
    MIN(nest_id) AS nest_id,
    MAX(ring_key) AS ring_key
  FROM candidate_links
  GROUP BY chick_resighting_pk
  HAVING COUNT(DISTINCT nest_id) = 1
)
SELECT
  chick_resighting_pk AS resighting_pk,
  nest_id,
  ring_key AS ring
FROM unique_links;


/*
  Ordinary positive-brood family evidence is kept event-level so closure
  reactivation does not depend on BROODS_LATEST's aggregate latest-event
  shortcut. This mirrors its same-date, exact-GPS adult association, retains
  the adult source/status fields, and rejects an encounter containing a
  conflicting explicit chick nest_id. H rows remain in the dedicated H-photo
  resolver and negative broods remain in the S10 resolver.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW
  FIELD_2026_BADOatNZ.TODO_ORDINARY_FAMILY_RESIGHTING_ASSOCIATIONS AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), adult_events AS (
  SELECT
    r.date AS event_date,
    r.gps_id,
    r.gps_point,
    TRIM(r.nest_id) AS adult_nest_id,
    'RESIGHTINGS' AS adult_source_table,
    r.pk AS adult_source_pk,
    CAST(NULL AS CHAR(1)) AS adult_capture_status,
    2 AS adult_source_rank
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'A'
    AND r.nest_id IS NOT NULL
    AND TRIM(r.nest_id) <> ''
    AND UPPER(TRIM(r.nest_id)) <> 'NO_NEST'
    AND LEFT(TRIM(r.nest_id), 1) <> '-'
    AND r.date <= sr.reference_date
    AND (
      NOT (
        COALESCE(r.UL, '') LIKE '%?%'
        OR COALESCE(r.LL, '') LIKE '%?%'
        OR COALESCE(r.UR, '') LIKE '%?%'
        OR COALESCE(r.LR, '') LIKE '%?%'
      )
      OR EXISTS (
        SELECT 1
        FROM FIELD_2026_BADOatNZ.CAPTURES captured_ring
        WHERE NULLIF(REPLACE(UPPER(TRIM(captured_ring.ring)), '-', ''), '') =
              NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
          AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
            'X', 'XX', 'X-X', 'NA', 'N/A'
          )
          AND captured_ring.date <= r.date
      )
      OR EXISTS (
        SELECT 1
        FROM FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE archive_ring
        WHERE NULLIF(REPLACE(UPPER(TRIM(archive_ring.ring)), '-', ''), '') =
              NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '')
          AND NULLIF(REPLACE(UPPER(TRIM(r.ring)), '-', ''), '') NOT IN (
            'X', 'XX', 'X-X', 'NA', 'N/A'
          )
          AND archive_ring.date <= r.date
      )
    )
  UNION ALL
  SELECT
    c.date AS event_date,
    c.gps_id,
    c.gps_point,
    TRIM(c.nest_id) AS adult_nest_id,
    'CAPTURES' AS adult_source_table,
    c.pk AS adult_source_pk,
    c.capture_status AS adult_capture_status,
    1 AS adult_source_rank
  FROM FIELD_2026_BADOatNZ.CAPTURES c
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
    AND c.age = 'A'
    AND c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
    AND LEFT(TRIM(c.nest_id), 1) <> '-'
    AND c.date <= sr.reference_date
    AND (
      NOT (
        COALESCE(c.UL, '') LIKE '%?%'
        OR COALESCE(c.LL, '') LIKE '%?%'
        OR COALESCE(c.UR, '') LIKE '%?%'
        OR COALESCE(c.LR, '') LIKE '%?%'
      )
      OR (
        NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') IS NOT NULL
        AND NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') NOT IN (
          'X', 'XX', 'X-X', 'NA', 'N/A'
        )
      )
    )
), unlinked_chick_events AS (
  SELECT
    r.pk AS resighting_pk,
    r.date AS event_date,
    r.gps_id,
    r.gps_point,
    r.rclass,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.ring, ''))) IN (
        '', 'X', 'XX', 'X-X', 'NA', 'N/A'
      )
      THEN NULL
      ELSE REPLACE(UPPER(TRIM(r.ring)), '-', '')
    END AS ring_key
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'C'
    AND UPPER(TRIM(COALESCE(r.rclass, ''))) <> 'H'
    AND (r.nest_id IS NULL OR TRIM(r.nest_id) = '')
    AND r.date <= sr.reference_date
    AND r.gps_id IS NOT NULL
    AND r.gps_point IS NOT NULL
), candidate_links AS (
  SELECT
    chick.resighting_pk,
    chick.event_date,
    chick.rclass,
    chick.ring_key,
    adult.adult_nest_id,
    adult.adult_source_table,
    adult.adult_source_pk,
    adult.adult_capture_status,
    adult.adult_source_rank
  FROM unlinked_chick_events chick
  JOIN adult_events adult
    ON adult.event_date = chick.event_date
   AND adult.gps_id = chick.gps_id
   AND adult.gps_point = chick.gps_point
  JOIN FIELD_2026_BADOatNZ.TODO_RAW_ENCOUNTER_NEST_CONSENSUS encounter
    ON encounter.event_date = chick.event_date
   AND encounter.gps_id = chick.gps_id
   AND encounter.gps_point = chick.gps_point
   AND encounter.n_explicit_nest_ids = 1
   AND encounter.explicit_nest_id = UPPER(TRIM(adult.adult_nest_id))
  WHERE NOT EXISTS (
    SELECT 1
    FROM FIELD_2026_BADOatNZ.CAPTURES conflicting_capture
    WHERE UPPER(TRIM(COALESCE(conflicting_capture.site, ''))) = 'CR'
      AND conflicting_capture.age = 'C'
      AND conflicting_capture.date = chick.event_date
      AND conflicting_capture.gps_id = chick.gps_id
      AND conflicting_capture.gps_point = chick.gps_point
      AND conflicting_capture.nest_id IS NOT NULL
      AND TRIM(conflicting_capture.nest_id) <> ''
      AND UPPER(TRIM(conflicting_capture.nest_id)) <> 'NO_NEST'
      AND UPPER(TRIM(conflicting_capture.nest_id)) <>
          UPPER(TRIM(adult.adult_nest_id))
  )
  AND NOT EXISTS (
    SELECT 1
    FROM FIELD_2026_BADOatNZ.RESIGHTINGS conflicting_resighting
    WHERE UPPER(TRIM(COALESCE(conflicting_resighting.site, ''))) = 'CR'
      AND conflicting_resighting.age = 'C'
      AND conflicting_resighting.date = chick.event_date
      AND conflicting_resighting.gps_id = chick.gps_id
      AND conflicting_resighting.gps_point = chick.gps_point
      AND conflicting_resighting.nest_id IS NOT NULL
      AND TRIM(conflicting_resighting.nest_id) <> ''
      AND UPPER(TRIM(conflicting_resighting.nest_id)) <> 'NO_NEST'
      AND UPPER(TRIM(conflicting_resighting.nest_id)) <>
          UPPER(TRIM(adult.adult_nest_id))
  )
), candidate_summary AS (
  SELECT
    resighting_pk,
    COUNT(DISTINCT adult_nest_id) AS n_adult_nest_ids
  FROM candidate_links
  GROUP BY resighting_pk
), ranked_candidates AS (
  SELECT
    candidate_links.*,
    ROW_NUMBER() OVER (
      PARTITION BY candidate_links.resighting_pk
      ORDER BY
        candidate_links.adult_source_rank,
        candidate_links.adult_source_pk
    ) AS row_num
  FROM candidate_links
)
SELECT
  ranked.resighting_pk,
  ranked.event_date,
  ranked.rclass,
  ranked.ring_key AS ring,
  ranked.adult_nest_id AS nest_id,
  ranked.adult_source_table,
  ranked.adult_source_pk,
  ranked.adult_capture_status,
  'same_occasion_adult' AS association_method
FROM ranked_candidates ranked
JOIN candidate_summary summary
  ON summary.resighting_pk = ranked.resighting_pk
WHERE summary.n_adult_nest_ids = 1
  AND ranked.row_num = 1;


/*
  Install-layer boundary for the canonical age-C encounter calculation.

  The full CAPTURES/RESIGHTINGS resolver, including H, ordinary-family, S10,
  GPS, ring, conflict, and death routes, is executed once by the staged
  refresh after the parent-status boundary and connection-local caches exist.
  Keeping this boundary typed and unavailable prevents CREATE VIEW from
  expanding that graph during installation. The refresh publishes the
  reference-date-specific latest encounter fields through the existing
  extended chick-context snapshot.

  This object is retained for column-contract compatibility. It is not a
  biological result before a successful refresh.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW
  FIELD_2026_BADOatNZ.TODO_CHICK_ENCOUNTERS_INPUT AS
SELECT
  CAST(NULL AS SIGNED) AS event_pk,
  CAST(NULL AS DATE) AS event_date,
  CAST(NULL AS DATETIME) AS event_datetime,
  CAST(NULL AS CHAR(16)) AS source_table,
  CAST(NULL AS CHAR(32)) AS nest_id,
  CAST(NULL AS SIGNED) AS gps_id,
  CAST(NULL AS SIGNED) AS gps_point,
  CAST(NULL AS CHAR(50)) AS ring_key,
  CAST(NULL AS CHAR(50)) AS flag_code,
  CAST(NULL AS CHAR(1)) AS capture_status,
  CAST(NULL AS CHAR(16)) AS nest_id_source,
  CAST(NULL AS SIGNED) AS source_rank,
  CAST(NULL AS CHAR(80)) AS event_identity_key,
  CAST(NULL AS SIGNED) AS is_unresolved_identity,
  CAST(NULL AS SIGNED) AS is_known_dead,
  CAST(NULL AS SIGNED) AS has_flagged_capture
WHERE 1 = 0;


/*
  Typed unavailable boundary for the latest encounter aggregate. The
  reference-date-specific result is published by the refresh workflow into
  TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT and exposed through the final context
  boundary below.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW
  FIELD_2026_BADOatNZ.TODO_CHICK_LATEST_ENCOUNTER_CONTEXT_INPUT AS
SELECT
  CAST(NULL AS CHAR(32)) AS nest_id,
  CAST(NULL AS DATE) AS latest_encounter_date,
  CAST(NULL AS DATETIME) AS latest_encounter_datetime,
  CAST(NULL AS SIGNED) AS latest_encounter_count,
  CAST(NULL AS SIGNED) AS latest_encounter_flagged_count,
  CAST(NULL AS SIGNED) AS latest_encounter_unflagged_count,
  CAST(NULL AS SIGNED) AS latest_encounter_unresolved_count,
  CAST(NULL AS SIGNED) AS latest_encounter_known_dead_count,
  CAST(NULL AS SIGNED) AS latest_encounter_is_conservative,
  CAST(NULL AS SIGNED) AS latest_encounter_is_fallback,
  CAST(NULL AS CHAR(16)) AS latest_encounter_availability,
  CAST(NULL AS CHAR(255)) AS latest_encounter_ring_list,
  CAST(NULL AS CHAR(64)) AS latest_encounter_source,
  CAST(NULL AS CHAR(128)) AS latest_encounter_provenance,
  CAST(NULL AS DATE) AS reference_date
WHERE 1 = 0;


/*
  Clean-install context boundary. The base capture aggregate remains
  available for structural compatibility, while latest encounter fields stay
  NULL until the staged refresh publishes the extended chick snapshot.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW
  FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT AS
SELECT
  base.nest_id,
  base.n_chick_captures,
  base.n_captured_chick_rings,
  base.n_flagged_chick_rings,
  base.n_unringed_chick_captures,
  base.n_dead_chick_rings,
  base.n_active_chick_rings,
  base.n_active_flagged_chick_rings,
  base.n_active_chick_captures,
  base.n_unresolved_dead_chick_events,
  base.observed_brood_size,
  base.latest_brood_count_date,
  base.n_deaths_after_latest_brood_count,
  base.n_operational_brood_size,
  base.operational_brood_size_source,
  latest.latest_encounter_date,
  latest.latest_encounter_datetime,
  latest.latest_encounter_count,
  latest.latest_encounter_flagged_count,
  latest.latest_encounter_unflagged_count,
  latest.latest_encounter_unresolved_count,
  latest.latest_encounter_known_dead_count,
  latest.latest_encounter_is_conservative,
  latest.latest_encounter_is_fallback,
  latest.latest_encounter_availability,
  latest.latest_encounter_ring_list,
  latest.latest_encounter_source,
  latest.latest_encounter_provenance
FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_BASE_INPUT base
LEFT JOIN FIELD_2026_BADOatNZ.TODO_CHICK_LATEST_ENCOUNTER_CONTEXT_INPUT latest
  ON latest.nest_id = base.nest_id;


/*
  TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT is the explicit two-column
  refresh boundary for the shared H-photo aggregate. The table is created
  here only when it is absent; existing rows are preserved during view
  installation. DATABASE/refresh_todo_list_snapshot.SQL computes the
  reference-date-bounded biological result and publishes it atomically.

  Keeping the installer-side input as a pointer avoids recursively validating
  the full H-photo association graph during CREATE VIEW. Before the first
  successful refresh the table may be empty or contain the last published
  result; the app must use the refresh-health boundary before relying on
  task output.
*/
CREATE TABLE IF NOT EXISTS
  FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT (
    nest_id VARCHAR(6)
      CHARACTER SET utf8mb4
      COLLATE utf8mb4_uca1400_ai_ci
      NULL,
    n_hiding_spot_photos BIGINT NULL,
    INDEX idx_todo_hiding_spot_photo_context_nest (nest_id)
  );

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT;


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


/*
  TODO_BROOD_CLOSURE_STATUS is the published, reference-date-bounded result
  of the audit-only brood closure protocol.  The expensive calculation is
  performed during DATABASE/refresh_todo_list_snapshot.SQL and published with
  the other TODO snapshots.  A qualifying age-J event is published as
  is_resolved, distinct from is_presumed_dead; both states suppress further
  brood work without rewriting raw field rows.  Keeping this as a small status
  boundary prevents the audit's identity and GPS graph from being expanded
  during every PDF, map, or task query.

  A missing status row means "not suppressed" only during the installation
  or before the first successful refresh.  The app's snapshot-health check
  must require a current closure snapshot before a field PDF is relied on.
*/
CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT (
  brood_id VARCHAR(6) NOT NULL,
  reference_date DATE NOT NULL,
  is_presumed_dead TINYINT NOT NULL DEFAULT 0,
  is_resolved TINYINT NOT NULL DEFAULT 0,
  closure_reason VARCHAR(255) NULL,
  resolution_reason VARCHAR(255) NULL,
  resolution_date DATE NULL,
  later_nest_id VARCHAR(6) NULL,
  later_nest_date DATE NULL,
  later_nest_parent_count BIGINT NULL,
  later_nest_authoritative_parent_count BIGINT NULL,
  nest_distance_m DECIMAL(10, 1) NULL,
  spatial_support_100m TINYINT NOT NULL DEFAULT 0,
  closure_candidate_date DATE NULL,
  reactivation_evidence_count BIGINT NOT NULL DEFAULT 0,
  would_reactivate TINYINT NOT NULL DEFAULT 0,
  PRIMARY KEY (reference_date, brood_id),
  INDEX idx_todo_brood_closure_brood (brood_id),
  INDEX idx_todo_brood_closure_dead (reference_date, is_presumed_dead)
);

/* Upgrade an existing closure snapshot without rewriting its rows. */
SET @todo_closure_is_resolved_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = 'FIELD_2026_BADOatNZ'
    AND table_name = 'TODO_BROOD_CLOSURE_STATUS_SNAPSHOT'
    AND column_name = 'is_resolved'
);
SET @todo_closure_is_resolved_sql := IF(
  @todo_closure_is_resolved_exists = 0,
  'ALTER TABLE FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT ADD COLUMN is_resolved TINYINT NOT NULL DEFAULT 0 AFTER is_presumed_dead',
  'SELECT 1'
);
PREPARE todo_closure_is_resolved_stmt FROM @todo_closure_is_resolved_sql;
EXECUTE todo_closure_is_resolved_stmt;
DEALLOCATE PREPARE todo_closure_is_resolved_stmt;

SET @todo_closure_resolution_reason_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = 'FIELD_2026_BADOatNZ'
    AND table_name = 'TODO_BROOD_CLOSURE_STATUS_SNAPSHOT'
    AND column_name = 'resolution_reason'
);
SET @todo_closure_resolution_reason_sql := IF(
  @todo_closure_resolution_reason_exists = 0,
  'ALTER TABLE FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT ADD COLUMN resolution_reason VARCHAR(255) NULL AFTER closure_reason',
  'SELECT 1'
);
PREPARE todo_closure_resolution_reason_stmt FROM @todo_closure_resolution_reason_sql;
EXECUTE todo_closure_resolution_reason_stmt;
DEALLOCATE PREPARE todo_closure_resolution_reason_stmt;

SET @todo_closure_resolution_date_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = 'FIELD_2026_BADOatNZ'
    AND table_name = 'TODO_BROOD_CLOSURE_STATUS_SNAPSHOT'
    AND column_name = 'resolution_date'
);
SET @todo_closure_resolution_date_sql := IF(
  @todo_closure_resolution_date_exists = 0,
  'ALTER TABLE FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT ADD COLUMN resolution_date DATE NULL AFTER resolution_reason',
  'SELECT 1'
);
PREPARE todo_closure_resolution_date_stmt FROM @todo_closure_resolution_date_sql;
EXECUTE todo_closure_resolution_date_stmt;
DEALLOCATE PREPARE todo_closure_resolution_date_stmt;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT;

/*
  PDF-facing brood source.  BROODS_LATEST remains the general operational
  brood view; only the TODO PDF/map/summary path applies presumed-dead
  suppression.  This keeps unrelated app consumers and biological records
  unchanged.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_BROODS_FOR_PDF AS
SELECT b.*
FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
LEFT JOIN FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS s
  ON CONVERT(s.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(b.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND s.reference_date = b.reference_date
WHERE COALESCE(s.is_presumed_dead, 0) = 0
  AND COALESCE(s.is_resolved, 0) = 0;


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

SELECT IF(
  COALESCE(@todo_schema_lock_result, 0) = 1,
  RELEASE_LOCK(@todo_schema_lock_name),
  1
) AS todo_schema_lock_released;
