/*
  Refresh the derived TODO task snapshot after source data or settings change.

  This is a staged refresh. The current public TODO_* views remain available
  while the replacement snapshots are computed. If MariaDB or the client
  fails during either expensive INSERT, only the *_BUILD tables are affected;
  the old public task output is not dropped. After the parent BUILD has been
  completed, the internal TODO_PARENT_STATUS_INPUT pointer also refers to that
  BUILD table; the first statements of the next retry reset it to the live
  pipeline. Execute this file with the SQL client set to stop on error.

  TODO_PARENT_STATUS_INPUT is reset to the live authoritative pipeline before
  stale BUILD tables are removed. After the new parent BUILD succeeds, the
  input boundary is repointed to that BUILD table, so the refresh-time task
  INSERT does not expand ADULT_PARENT_STATUS a second time. It is repointed
  to the promoted parent snapshot only after the task BUILD insert succeeds.

  TODO_BROOD_CONTEXT_INPUT is likewise reset before stale BUILD tables are
  removed, then repointed to a compact indexed brood BUILD table before task
  assembly. This avoids expanding BROODS_LATEST independently in each brood
  task branch while preserving the same source columns and predicates.

  TODO_CHICK_CAPTURE_CONTEXT_INPUT is reset and then repointed to a compact
  indexed chick-capture aggregate before task assembly. This avoids repeating
  the same CAPTURES grouping for untrapped-brood, flagging, and hiding-photo
  task branches while preserving the existing ring and engraved-flag rules.

  TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT is handled the same way for the shared
  H-photo evidence aggregate used by both brood task unions.

  The GPS-linked chick-parent result is staged before parent status. This keeps
  the expensive GPS matching graph out of repeated parent-status expansions
  while preserving the same definitive evidence gate.

  The explicit task schema avoids CREATE TABLE AS SELECT ... WHERE 1 = 0,
  which otherwise expands the full task calculator just to infer column types.
  This script never reads an RDS file and never queries the remote database
  through an application connection; it uses the live database selected by
  the SQL client.
*/

/* Fail fast on a publication metadata lock so the previous snapshot remains
   available instead of allowing an Adminer request to wait indefinitely. */
SET SESSION lock_wait_timeout = 30;

/* Keep a durable, low-volume health record for app/download warnings. A
   failed client leaves the row in 'running', while a successful refresh marks
   it 'succeeded' only after the public snapshot has been promoted and all
   PREVIOUS tables have been removed. */
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

INSERT INTO FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS (
  reference_date,
  state,
  started_at
)
SELECT
  CAST(value AS DATE),
  'running',
  CURRENT_TIMESTAMP
FROM FIELD_2026_BADOatNZ.settings
WHERE variable = 'reference_date'
  AND value IS NOT NULL
LIMIT 1;

SET @todo_refresh_id := LAST_INSERT_ID();

/* Repair all internal input boundaries before removing stale BUILD tables. */
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT;

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

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_PARENT_STATUS;

DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_PREVIOUS;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_PREVIOUS;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_PREVIOUS;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_PREVIOUS;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_PREVIOUS;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_PREVIOUS;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_PREVIOUS;

SELECT 'TODO_REFRESH_STAGE|nest_context' AS refresh_stage;

/* Build the bounded operational context once for all task branches. */
CREATE TABLE FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD (
  nest_id VARCHAR(6) NULL,
  species VARCHAR(20) NULL,
  last_visit_datetime DATETIME NULL,
  days_ago INT NULL,
  last_observer VARCHAR(100) NULL,
  nest_state VARCHAR(10) NULL,
  hatch_state VARCHAR(10) NULL,
  hatch_signs_present TINYINT NULL,
  bird_inc VARCHAR(20) NULL,
  clutch_size DECIMAL(10, 0) NULL,
  brood_size DECIMAL(10, 0) NULL,
  latest_float_date DATE NULL,
  average_ref_date_days_since_laid DECIMAL(6, 1) NULL,
  base_min_days_to_hatch INT NULL,
  nest_photo VARCHAR(5) NULL,
  tent_photo VARCHAR(5) NULL,
  lat DOUBLE NULL,
  lon DOUBLE NULL,
  reference_date DATE NULL,
  observed_hatch_date DATE NULL,
  first_found_date DATE NULL,
  first_processable_date DATE NULL,
  first_processable_datetime DATETIME NULL,
  last_photo_date DATE NULL,
  last_photo_datetime DATETIME NULL,
  last_float_date DATE NULL,
  last_float_datetime DATETIME NULL,
  n_photo_rows BIGINT NULL,
  n_float_rows BIGINT NULL,
  last_processed_datetime DATETIME NULL,
  latest_clutch_size DECIMAL(10, 0) NULL,
  latest_clutch_date DATE NULL,
  latest_clutch_datetime DATETIME NULL,
  latest_clutch_has_photo TINYINT NULL,
  latest_event_clutch_size DECIMAL(10, 0) NULL,
  latest_event_date DATE NULL,
  clutch_has_float TINYINT NULL,
  clutch_at_processing_size DECIMAL(10, 0) NULL,
  current_clutch_size DECIMAL(10, 0) NULL,
  current_clutch_datetime DATETIME NULL,
  current_clutch_start_datetime DATETIME NULL,
  capture_gate_clutch_size DECIMAL(10, 0) NULL,
  capture_gate_clutch_start_datetime DATETIME NULL,
  hatch_date DATE NULL,
  INDEX idx_todo_nest_context_reference (reference_date),
  INDEX idx_todo_nest_context_nest_reference (nest_id, reference_date)
);

CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT
LIKE FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD;

INSERT INTO FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD (
  nest_id,
  species,
  last_visit_datetime,
  days_ago,
  last_observer,
  nest_state,
  hatch_state,
  hatch_signs_present,
  bird_inc,
  clutch_size,
  brood_size,
  latest_float_date,
  average_ref_date_days_since_laid,
  base_min_days_to_hatch,
  nest_photo,
  tent_photo,
  lat,
  lon,
  reference_date,
  observed_hatch_date,
  first_found_date,
  first_processable_date,
  first_processable_datetime,
  last_photo_date,
  last_photo_datetime,
  last_float_date,
  last_float_datetime,
  n_photo_rows,
  n_float_rows,
  last_processed_datetime,
  latest_clutch_size,
  latest_clutch_date,
  latest_clutch_datetime,
  latest_clutch_has_photo,
  latest_event_clutch_size,
  latest_event_date,
  clutch_has_float,
  clutch_at_processing_size,
  current_clutch_size,
  current_clutch_datetime,
  current_clutch_start_datetime,
  capture_gate_clutch_size,
  capture_gate_clutch_start_datetime,
  hatch_date
)
SELECT
  nest_id,
  species,
  last_visit_datetime,
  days_ago,
  last_observer,
  nest_state,
  hatch_state,
  hatch_signs_present,
  bird_inc,
  clutch_size,
  brood_size,
  latest_float_date,
  average_ref_date_days_since_laid,
  base_min_days_to_hatch,
  nest_photo,
  tent_photo,
  lat,
  lon,
  reference_date,
  observed_hatch_date,
  first_found_date,
  first_processable_date,
  first_processable_datetime,
  last_photo_date,
  last_photo_datetime,
  last_float_date,
  last_float_datetime,
  n_photo_rows,
  n_float_rows,
  last_processed_datetime,
  latest_clutch_size,
  latest_clutch_date,
  latest_clutch_datetime,
  latest_clutch_has_photo,
  latest_event_clutch_size,
  latest_event_date,
  clutch_has_float,
  clutch_at_processing_size,
  current_clutch_size,
  current_clutch_datetime,
  current_clutch_start_datetime,
  capture_gate_clutch_size,
  capture_gate_clutch_start_datetime,
  hatch_date
FROM FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD;

SELECT 'TODO_REFRESH_STAGE|brood_context' AS refresh_stage;

/* Materialize the compact brood input once for all brood task branches. */
CREATE TABLE FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD (
  nest_id VARCHAR(6) NULL,
  species VARCHAR(20) NULL,
  is_negative_brood TINYINT NULL,
  discovery_date DATE NULL,
  latest_encounter_date DATE NULL,
  latest_encounter_datetime DATETIME NULL,
  hatch_evidence_date DATE NULL,
  has_hatch_evidence TINYINT NULL,
  nest_state VARCHAR(10) NULL,
  hatch_state VARCHAR(50) NULL,
  clutch_size DECIMAL(10, 0) NULL,
  brood_size DECIMAL(10, 0) NULL,
  lat DOUBLE NULL,
  lon DOUBLE NULL,
  nest_photo VARCHAR(5) NULL,
  tent_photo VARCHAR(5) NULL,
  reference_date DATE NULL,
  INDEX idx_todo_brood_context_nest_reference (nest_id, reference_date),
  INDEX idx_todo_brood_context_kind_reference (
    is_negative_brood,
    reference_date,
    nest_id
  )
);

CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT
LIKE FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD;

INSERT INTO FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD (
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
)
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

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD;

SELECT 'TODO_REFRESH_STAGE|chick_capture_context' AS refresh_stage;

/* Materialize the shared chick-capture aggregate once for all brood tasks. */
CREATE TABLE FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD (
  nest_id VARCHAR(6) NULL,
  n_chick_captures BIGINT NULL,
  n_captured_chick_rings BIGINT NULL,
  n_flagged_chick_rings BIGINT NULL,
  n_unringed_chick_captures BIGINT NULL,
  INDEX idx_todo_chick_capture_context_nest (nest_id)
);

CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT
LIKE FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD;

INSERT INTO FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD (
  nest_id,
  n_chick_captures,
  n_captured_chick_rings,
  n_flagged_chick_rings,
  n_unringed_chick_captures
)
SELECT
  nest_id,
  n_chick_captures,
  n_captured_chick_rings,
  n_flagged_chick_rings,
  n_unringed_chick_captures
FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT;

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

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD;

SELECT 'TODO_REFRESH_STAGE|hiding_spot_photos' AS refresh_stage;

/* Materialize the shared H-photo evidence aggregate once for brood tasks. */
CREATE TABLE FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD (
  nest_id VARCHAR(6) NULL,
  n_hiding_spot_photos BIGINT NULL,
  INDEX idx_todo_hiding_spot_photo_context_nest (nest_id)
);

CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT
LIKE FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD;

INSERT INTO FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD (
  nest_id,
  n_hiding_spot_photos
)
SELECT
  nest_id,
  n_hiding_spot_photos
FROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD;

SELECT 'TODO_REFRESH_STAGE|chick_gps_links' AS refresh_stage;

/* Materialize the GPS-linked parent gate once for the parent build. */
CREATE TABLE FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD (
  capture_pk VARCHAR(64) NULL,
  identity_key VARCHAR(255) NULL,
  capture_sex VARCHAR(1) NULL,
  nest_id VARCHAR(6) NULL,
  capture_date DATE NULL,
  capture_datetime DATETIME NULL,
  display_mark VARCHAR(50) NULL,
  has_geo TINYINT NULL,
  is_au_migrant TINYINT NULL,
  is_dead TINYINT NULL,
  is_single_colour_recruit TINYINT NULL,
  link_source VARCHAR(255) NULL,
  has_chick_gps_link TINYINT NULL,
  INDEX idx_parent_chick_gps_capture (capture_pk),
  INDEX idx_parent_chick_gps_nest (nest_id),
  INDEX idx_parent_chick_gps_identity (identity_key),
  INDEX idx_parent_chick_gps_capture_nest (capture_pk, nest_id)
);

CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT
LIKE FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD;

INSERT INTO FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD;

SELECT 'TODO_REFRESH_STAGE|parent_status' AS refresh_stage;

/* Build parent status first, without touching the published view. */
CREATE TABLE FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD (
  nest_id VARCHAR(6) NULL,
  reference_date DATE NULL,
  M_selected_mark LONGTEXT NULL,
  F_selected_mark LONGTEXT NULL,
  M_association_details LONGTEXT NULL,
  F_association_details LONGTEXT NULL,
  M_association_marks LONGTEXT NULL,
  F_association_marks LONGTEXT NULL,
  M_association_pending BIGINT NULL,
  F_association_pending BIGINT NULL,
  M_association_ambiguous BIGINT NULL,
  F_association_ambiguous BIGINT NULL,
  M_identity_count BIGINT NULL,
  F_identity_count BIGINT NULL,
  M_resighting_count BIGINT NULL,
  F_resighting_count BIGINT NULL,
  M_pending_resighting_count BIGINT NULL,
  F_pending_resighting_count BIGINT NULL,
  M_has_geo TINYINT NULL,
  F_has_geo TINYINT NULL,
  M_is_dead TINYINT NULL,
  F_is_dead TINYINT NULL,
  M_is_au_migrant TINYINT NULL,
  F_is_au_migrant TINYINT NULL,
  M_single_colour_recruit TINYINT NULL,
  F_single_colour_recruit TINYINT NULL,
  M_has_mm_capture TINYINT NULL,
  F_has_mm_capture TINYINT NULL,
  M_mm_capture_mark LONGTEXT NULL,
  F_mm_capture_mark LONGTEXT NULL,
  M_unknown_status TINYINT NULL,
  F_unknown_status TINYINT NULL,
  M_confirmed_unbanded TINYINT NULL,
  F_confirmed_unbanded TINYINT NULL,
  M_parent_mark LONGTEXT NULL,
  F_parent_mark LONGTEXT NULL,
  M_resight_association_details LONGTEXT NULL,
  F_resight_association_details LONGTEXT NULL,
  M_resight_association_marks LONGTEXT NULL,
  F_resight_association_marks LONGTEXT NULL,
  M_resight_association_pending BIGINT NULL,
  F_resight_association_pending BIGINT NULL,
  M_resight_association_ambiguous BIGINT NULL,
  F_resight_association_ambiguous BIGINT NULL,
  M_resighting_identity_count BIGINT NULL,
  F_resighting_identity_count BIGINT NULL,
  M_resight_association_count BIGINT NULL,
  F_resight_association_count BIGINT NULL,
  M_resight_association_selected_mark LONGTEXT NULL,
  F_resight_association_selected_mark LONGTEXT NULL,
  M_resight_association_selected_has_geo TINYINT NULL,
  F_resight_association_selected_has_geo TINYINT NULL,
  M_captured_has_geo TINYINT NULL,
  F_captured_has_geo TINYINT NULL,
  M_identity_has_geo TINYINT NULL,
  F_identity_has_geo TINYINT NULL,
  M_identity_mark LONGTEXT NULL,
  F_identity_mark LONGTEXT NULL,
  M_identity_is_dead TINYINT NULL,
  F_identity_is_dead TINYINT NULL,
  M_identity_single_colour_recruit TINYINT NULL,
  F_identity_single_colour_recruit TINYINT NULL,
  M_mm_resight_pending TINYINT NULL,
  F_mm_resight_pending TINYINT NULL,
  M_mm_resight_count BIGINT NULL,
  F_mm_resight_count BIGINT NULL,
  M_mm_xx_parent_confirmed TINYINT NULL,
  F_mm_xx_parent_confirmed TINYINT NULL,
  M_alternate_parent_confirmed TINYINT NULL,
  F_alternate_parent_confirmed TINYINT NULL,
  M_alternate_parent_marks LONGTEXT NULL,
  F_alternate_parent_marks LONGTEXT NULL,
  M_alternate_parent_details LONGTEXT NULL,
  F_alternate_parent_details LONGTEXT NULL,
  M_post_mm_xx_seen TINYINT NULL,
  F_post_mm_xx_seen TINYINT NULL,
  M_last_capture_datetime DATETIME NULL,
  F_last_capture_datetime DATETIME NULL,
  last_any_adult_capture_datetime DATETIME NULL,
  both_parents_need_geo TINYINT NULL,
  M_has_unique_scrape_resight TINYINT NULL,
  F_has_unique_scrape_resight TINYINT NULL,
  INDEX idx_todo_parent_status_nest (nest_id),
  INDEX idx_todo_parent_status_reference (reference_date)
);

CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT
LIKE FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD;

INSERT INTO FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_PARENT_STATUS;

/* Feed task assembly from the completed parent BUILD, not the live pipeline. */
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD;

SELECT 'TODO_REFRESH_STAGE|task_rows' AS refresh_stage;

/*
  Build task rows while the existing TODO_LIST remains available. The full
  task calculator is a refresh-time WITH query below, rather than a live
  TODO_LIST_CALCULATE view, so views.SQL does not ask MariaDB to validate the
  complete nested task graph during DDL installation.
*/
CREATE TABLE FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD (
  nest_id VARCHAR(6) NULL,
  reference_date DATE NULL,
  todo VARCHAR(64) NOT NULL,
  notes LONGTEXT NULL,
  days_overdue BIGINT NULL,
  priority BIGINT NULL,
  min_days_to_hatch BIGINT NULL,
  last_visit_days_ago INT NULL,
  nest_state VARCHAR(10) NULL,
  clutch_size DECIMAL(10, 0) NULL,
  brood_size DECIMAL(10, 0) NULL,
  M_mark LONGTEXT NULL,
  F_mark LONGTEXT NULL,
  lat DOUBLE NULL,
  lon DOUBLE NULL,
  authoritative_M_mark LONGTEXT NULL,
  authoritative_F_mark LONGTEXT NULL,
  M_resight_association_pending BIGINT NULL,
  F_resight_association_pending BIGINT NULL,
  M_mm_resight_pending TINYINT NULL,
  F_mm_resight_pending TINYINT NULL,
  M_resighting_identity_count BIGINT NULL,
  F_resighting_identity_count BIGINT NULL,
  geo_priority_rank BIGINT NULL,
  geo_priority_tier TINYINT NULL,
  geo_priority_score TINYINT NULL,
  geo_reason VARCHAR(15) NULL,
  geo_target VARCHAR(1) NULL,
  geo_tag_target VARCHAR(1) NULL,
  geo_is_actionable TINYINT NULL DEFAULT 0,
  n_geo_deployed BIGINT NULL DEFAULT 0,
  release_ceiling INT NULL DEFAULT 0,
  release_slots_remaining BIGINT NULL,
  n_male_geo_deployed BIGINT NULL DEFAULT 0,
  n_female_geo_deployed BIGINT NULL DEFAULT 0,
  male_quota_remaining BIGINT NULL DEFAULT 0,
  female_quota_remaining BIGINT NULL DEFAULT 0,
  preferred_balance_sex VARCHAR(1) NULL,
  M_is_au_migrant BIGINT NULL,
  F_is_au_migrant BIGINT NULL,
  overdue_label VARCHAR(29) NULL,
  INDEX idx_todo_snapshot_nest (nest_id),
  INDEX idx_todo_snapshot_reference (reference_date),
  INDEX idx_todo_snapshot_task (todo)
);

CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT
LIKE FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD;

INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD (
  nest_id, reference_date, todo, notes, days_overdue, priority,
  min_days_to_hatch, last_visit_days_ago, nest_state, clutch_size, brood_size,
  M_mark, F_mark, lat, lon, authoritative_M_mark, authoritative_F_mark,
  M_resight_association_pending, F_resight_association_pending,
  M_mm_resight_pending, F_mm_resight_pending, M_resighting_identity_count,
  F_resighting_identity_count, geo_priority_rank, geo_priority_tier,
  geo_priority_score, geo_reason, geo_target, geo_tag_target, geo_is_actionable,
  n_geo_deployed, release_ceiling, release_slots_remaining,
  n_male_geo_deployed, n_female_geo_deployed, male_quota_remaining,
  female_quota_remaining, preferred_balance_sex, M_is_au_migrant,
  F_is_au_migrant, overdue_label
)
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
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
    999999 AS release_ceiling,
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
    CASE
      WHEN p.calibration_match_type = 'found as incomplete' THEN 1
      ELSE 0
    END AS found_as_incomplete,
    CASE
      WHEN p.calibration_match_type IN (
        'found as incomplete',
        'stable one-egg/no increase'
      ) THEN 1
      ELSE 0
    END AS processing_flotation_exempt,
    DATE_SUB(p.predicted_hatch_date, INTERVAL 26 DAY)
      AS inferred_clutch_completion_date,
    p.predicted_hatch_date AS inferred_hatch_date
  FROM FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION p
  WHERE p.calibration_match_type IN (
    'found as incomplete',
    'complete clutch chronology',
    'stable one-egg/no increase'
  )
),
/*
  All task-side context projections share this one bounded relation. During a
  staged refresh the relation is an indexed snapshot table; during a clean
  view installation it remains the live TODO_NEST_CONTEXT fallback.
*/
task_context AS (
  SELECT *
  FROM FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_INPUT
),
brood_context AS (
  SELECT *
  FROM FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_INPUT
),
latest_nests AS (
  SELECT
    context.nest_id,
    context.species,
    context.last_visit_datetime,
    context.days_ago,
    context.last_observer,
    context.nest_state,
    context.hatch_state,
    context.hatch_signs_present,
    context.bird_inc,
    context.clutch_size,
    context.brood_size,
    context.latest_float_date,
    context.average_ref_date_days_since_laid,
    CASE
      WHEN context.observed_hatch_date IS NOT NULL
      THEN DATEDIFF(
        context.observed_hatch_date,
        sr.reference_date
      )
      WHEN initial_clutch_status.inferred_hatch_date IS NOT NULL
      THEN DATEDIFF(
        initial_clutch_status.inferred_hatch_date,
        sr.reference_date
      )
      ELSE context.base_min_days_to_hatch
    END AS min_days_to_hatch,
    context.nest_photo,
    context.tent_photo,
    context.lat,
    context.lon,
    sr.reference_date
  FROM task_context context
  LEFT JOIN initial_clutch_status
    ON context.nest_id = initial_clutch_status.nest_id
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
first_processable_visit AS (
  SELECT
    context.nest_id,
    context.first_processable_date,
    context.first_processable_datetime
  FROM task_context context
),
photo_summary AS (
  SELECT
    context.nest_id,
    context.last_photo_date,
    context.last_photo_datetime,
    context.n_photo_rows
  FROM task_context context
),
float_summary AS (
  SELECT
    context.nest_id,
    context.last_float_date,
    context.last_float_datetime,
    context.n_float_rows
  FROM task_context context
),
-- The initial processing task is resolved by any qualifying photo and
-- flotation record from the first processable visit onward. This deliberately
-- spans dates and is independent of later transient zero-clutch/state rows;
-- clutch-increase reprocessing is handled separately below.
processing_summary AS (
  SELECT
    context.nest_id,
    context.first_processable_date,
    context.last_photo_date,
    context.last_photo_datetime,
    context.last_float_date,
    context.last_float_datetime,
    COALESCE(context.n_photo_rows, 0) AS n_photo_rows,
    COALESCE(context.n_float_rows, 0) AS n_float_rows,
    context.last_processed_datetime
  FROM task_context context
),
nest_discovery AS (
  SELECT
    context.nest_id,
    context.first_found_date
  FROM task_context context
),
latest_clutch_history AS (
  SELECT
    context.nest_id,
    context.latest_clutch_size AS clutch_size,
    context.latest_clutch_date AS clutch_date,
    CAST(COALESCE(context.latest_clutch_datetime, '00:00:00') AS TIME)
      AS clutch_time_visit,
    context.latest_clutch_datetime AS clutch_datetime,
    context.latest_clutch_has_photo AS clutch_has_photo,
    1 AS row_num
  FROM task_context context
  WHERE context.latest_clutch_size IS NOT NULL
),
latest_nest_event AS (
  SELECT
    context.nest_id,
    context.latest_event_clutch_size AS clutch_size,
    context.latest_event_date AS event_date,
    1 AS row_num
  FROM task_context context
),
latest_clutch_processing_status AS (
  SELECT
    context.nest_id,
    context.latest_clutch_has_photo AS clutch_has_photo,
    context.clutch_has_float
  FROM task_context context
),
clutch_at_processing AS (
  SELECT
    context.nest_id,
    context.clutch_at_processing_size AS clutch_size,
    1 AS row_num
  FROM task_context context
  WHERE context.clutch_at_processing_size IS NOT NULL
),
hatched_nests AS (
  SELECT
    context.nest_id,
    context.hatch_date
  FROM task_context context
  WHERE context.hatch_date IS NOT NULL
),
brood_followup_nests AS (
  -- BROODS_LATEST supplies hatch evidence from either an H nest visit or the
  -- first age-C capture. Using it here keeps the day-1-to-day-6 photo window
  -- open when a later nest-state visit is not literally H/notA.
  SELECT
    n.*,
    b.hatch_evidence_date AS hatch_date
  FROM latest_nests n
  JOIN brood_context b
    ON n.nest_id = b.nest_id
   AND b.reference_date = n.reference_date
  WHERE b.is_negative_brood = 0
    AND b.has_hatch_evidence = 1
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
  SELECT *
  FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT
),
hiding_spot_photos AS (
  SELECT *
  FROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT
),
todo_parent_source AS (
  SELECT
    latest_nests.nest_id,
    CONVERT(CAST(NULL AS CHAR(50)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS M_mark,
    CONVERT(CAST(NULL AS CHAR(50)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS F_mark
  FROM latest_nests
  UNION ALL
  SELECT
    b.nest_id,
    CONVERT(CAST(NULL AS CHAR(50)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS M_mark,
    CONVERT(CAST(NULL AS CHAR(50)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS F_mark
  FROM brood_context b
  CROSS JOIN sr
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
),
adult_parent_status AS (
  /* TODO_PARENT_STATUS_INPUT is live during a clean install and points to the
     populated parent BUILD table during a staged refresh. This keeps the
     authoritative four-gate calculation out of the task insert's second
     expansion while preserving a valid calculator before snapshots exist. */
  SELECT *
  FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT
),
adult_parent_geo_target_status AS (
  SELECT
    adult_parent_status.*,
    CASE
      WHEN geo_deployment_status.n_geo_deployed
           < geo_deployment_status.release_ceiling
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
       AND COALESCE(adult_parent_status.M_resight_association_pending, 0) = 0
       AND COALESCE(adult_parent_status.F_resight_association_pending, 0) = 0
      THEN 1
      ELSE 0
    END AS both_parents_need_geo_derived
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
      WHEN adult_capture_timing.F_last_capture_datetime IS NULL
        OR adult_capture_timing.F_last_capture_datetime
           <= DATE_SUB(
                CAST(CONCAT(sr.reference_date, ' 08:00:00') AS DATETIME),
                INTERVAL 36 HOUR
              )
      THEN 1
      ELSE 0
    END AS M_target_capture_window_open,
    CASE
      WHEN adult_capture_timing.M_last_capture_datetime IS NULL
        OR adult_capture_timing.M_last_capture_datetime
           <= DATE_SUB(
                CAST(CONCAT(sr.reference_date, ' 08:00:00') AS DATETIME),
                INTERVAL 36 HOUR
              )
      THEN 1
      ELSE 0
    END AS F_target_capture_window_open
  FROM todo_parent_source
  CROSS JOIN sr
  LEFT JOIN adult_parent_status adult_capture_timing
    ON todo_parent_source.nest_id = adult_capture_timing.nest_id
),
adult_capture_current_clutch_start AS (
  SELECT
    context.nest_id,
    context.capture_gate_clutch_size AS current_clutch_size,
    context.current_clutch_datetime,
    context.capture_gate_clutch_start_datetime AS current_clutch_start_datetime,
    context.last_float_datetime
  FROM task_context context
  WHERE context.capture_gate_clutch_size IS NOT NULL
),
adult_capture_age_status AS (
  SELECT
    x.nest_id,
    x.clutch_completion_basis_date,
    x.clutch_completion_confirmed,
    CASE
      -- Hatch signs without a flotation date mean the nest is already in
      -- the hatching window, so do not block parent capture on the missing
      -- seven-day estimate. The 36-hour capture interval is applied later.
      WHEN latest_nests.hatch_signs_present = 1
       AND latest_nests.latest_float_date IS NULL
      THEN 1
      WHEN DATEDIFF(
             x.reference_date,
             x.clutch_completion_basis_date
           ) >= 7
      THEN 1
      ELSE 0
    END AS capture_allowed_after_completion
  FROM (
    SELECT
      clutch_start.nest_id,
      sr.reference_date,
      CASE
        WHEN initial_clutch_status.found_as_incomplete = 1
        THEN initial_clutch_status.inferred_clutch_completion_date
        WHEN clutch_start.current_clutch_size >= 3
        THEN DATE(clutch_start.current_clutch_start_datetime)
        /* A two-egg clutch needs three full days of stability after the
           current clutch's float before it becomes a completion candidate.
           A later third egg changes current_clutch_size and therefore starts
           a new completion calculation. */
        WHEN clutch_start.current_clutch_size = 2
         AND clutch_start.last_float_datetime IS NOT NULL
         AND clutch_start.last_float_datetime
             >= clutch_start.current_clutch_start_datetime
        THEN DATE_ADD(
          DATE(clutch_start.last_float_datetime),
          INTERVAL 3 DAY
        )
        WHEN DATEDIFF(
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
        WHEN clutch_start.current_clutch_size >= 3 THEN 1
        WHEN clutch_start.current_clutch_size = 2
         AND clutch_start.last_float_datetime IS NOT NULL
         AND clutch_start.last_float_datetime
             >= clutch_start.current_clutch_start_datetime
         AND DATEDIFF(
               sr.reference_date,
               DATE(clutch_start.last_float_datetime)
             ) >= 3
        THEN 1
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
    CROSS JOIN sr
  ) x
  JOIN latest_nests
    ON x.nest_id = latest_nests.nest_id
  UNION ALL
  SELECT
    b.nest_id,
    CAST(NULL AS DATE) AS clutch_completion_basis_date,
    1 AS clutch_completion_confirmed,
    1 AS capture_allowed_after_completion
  FROM brood_context b
  CROSS JOIN sr
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
),
/*
  GEO deployment is now a pure pair-completion plan.  Phenology strata,
  release ceilings, and sex-balancing candidates no longer create GEO tasks.
  A target may remain association-pending, but an ambiguous or dead identity
  is not silently selected.
*/
geo_parent_targets AS (
  SELECT
    units.nest_id,
    units.reference_date,
    parent_status.M_parent_mark,
    parent_status.F_parent_mark,
    parent_status.M_has_geo,
    parent_status.F_has_geo,
    parent_status.M_is_dead,
    parent_status.F_is_dead,
    parent_status.M_is_au_migrant,
    parent_status.F_is_au_migrant,
    parent_status.M_resight_association_ambiguous,
    parent_status.F_resight_association_ambiguous,
    CASE
      WHEN parent_status.M_has_geo = 1
       AND COALESCE(parent_status.F_has_geo, 0) = 0
       AND COALESCE(parent_status.M_is_dead, 0) = 0
       AND COALESCE(parent_status.M_resight_association_ambiguous, 0) = 0
       AND COALESCE(parent_status.F_is_dead, 0) = 0
       AND COALESCE(parent_status.F_resight_association_ambiguous, 0) = 0
      THEN 'F'
      WHEN parent_status.F_has_geo = 1
       AND COALESCE(parent_status.M_has_geo, 0) = 0
       AND COALESCE(parent_status.F_is_dead, 0) = 0
       AND COALESCE(parent_status.F_resight_association_ambiguous, 0) = 0
       AND COALESCE(parent_status.M_is_dead, 0) = 0
       AND COALESCE(parent_status.M_resight_association_ambiguous, 0) = 0
      THEN 'M'
      ELSE NULL
    END AS pair_target
  FROM (
    SELECT active_nests.nest_id, active_nests.reference_date
    FROM active_nests
    UNION
    SELECT n.nest_id, n.reference_date
    FROM latest_nests n
    JOIN hatched_nests
      ON n.nest_id = hatched_nests.nest_id
    WHERE UPPER(TRIM(COALESCE(n.nest_state, ''))) = 'NOTA'
    UNION
    SELECT b.nest_id, b.reference_date
    FROM brood_context b
    CROSS JOIN sr
    WHERE b.is_negative_brood = 1
      AND b.reference_date = sr.reference_date
  ) units
  LEFT JOIN adult_parent_status parent_status
    ON units.nest_id = parent_status.nest_id
),
geo_parent_plan AS (
  SELECT
    targets.nest_id,
    CASE WHEN targets.pair_target IS NOT NULL
      THEN ROW_NUMBER() OVER (ORDER BY targets.nest_id) END AS geo_rank,
    CASE WHEN targets.pair_target IS NOT NULL THEN 1 ELSE NULL END AS geo_priority_tier,
    CASE WHEN targets.pair_target IS NOT NULL THEN 1 ELSE NULL END AS global_sex_priority,
    CASE WHEN targets.pair_target IS NOT NULL THEN 1 ELSE NULL END AS geo_priority_score,
    CASE WHEN targets.pair_target IS NOT NULL THEN 'pair completion' ELSE NULL END AS geo_reason,
    targets.pair_target AS geo_target,
    CASE WHEN targets.pair_target IS NOT NULL THEN 1 ELSE 0 END AS geo_is_actionable,
    deployment_status.n_geo_deployed,
    deployment_status.release_ceiling,
    deployment_status.release_ceiling - deployment_status.n_geo_deployed AS release_slots_remaining,
    deployment_status.n_male_geo_deployed,
    deployment_status.n_female_geo_deployed,
    deployment_status.male_quota_remaining,
    deployment_status.female_quota_remaining,
    deployment_status.preferred_balance_sex,
    CONVERT(CAST(NULL AS CHAR(2)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS geo_band_target,
    targets.pair_target AS geo_tag_target,
    CASE
      WHEN targets.pair_target IS NULL THEN NULL
      WHEN targets.pair_target = 'M'
       AND UPPER(TRIM(COALESCE(targets.M_parent_mark, ''))) = 'X-X'
      THEN CONCAT(
        'tag X-X M (pair completion)',
        CASE WHEN targets.nest_id = 'C2208' THEN '; CORRECT DUPLICATE' ELSE '' END
      )
      WHEN targets.pair_target = 'F'
       AND UPPER(TRIM(COALESCE(targets.F_parent_mark, ''))) = 'X-X'
      THEN 'tag X-X F (pair completion)'
      ELSE CONCAT(
        'tag ', targets.pair_target, ' (pair completion)',
        CASE WHEN targets.nest_id = 'C2208' AND targets.pair_target = 'M'
          THEN '; CORRECT DUPLICATE' ELSE '' END
      )
    END AS geo_instruction,
    CASE WHEN targets.pair_target IS NOT NULL THEN 1 ELSE 0 END AS is_pair_completion,
    targets.M_is_au_migrant,
    targets.F_is_au_migrant
  FROM geo_parent_targets targets
  CROSS JOIN geo_deployment_status deployment_status
),
todo_untrapped_parent_candidate AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Untrapped parent' AS todo,
    CASE
      WHEN active_nests.nest_id = 'B2203'
       AND UPPER(TRIM(COALESCE(adult_parent_status.F_parent_mark, ''))) = 'YY-TB.BL'
      THEN 1
      ELSE 0
    END AS duplicate_correction,
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
      WHEN adult_parent_status.both_parents_need_geo_derived = 1
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
      WHEN active_nests.nest_id = 'B2203'
       AND UPPER(TRIM(COALESCE(adult_parent_status.F_parent_mark, ''))) = 'YY-TB.BL'
      THEN 'F'
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
      WHEN adult_parent_status.both_parents_need_geo_derived = 1 THEN 'A'
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
    adult_parent_status.both_parents_need_geo_derived AS both_parents_need_geo,
    adult_capture_interval_status.no_parent_capture_yet,
    adult_capture_interval_status.any_target_capture_window_open,
    adult_capture_interval_status.M_target_capture_window_open,
    adult_capture_interval_status.F_target_capture_window_open,
    CASE
      -- Hatched nests no longer need the clutch-completion gate; retain the
      -- 36-hour parent-capture gate below.
      WHEN active_nests.nest_id = 'B2203'
       AND UPPER(TRIM(COALESCE(adult_parent_status.F_parent_mark, ''))) = 'YY-TB.BL'
      THEN 1
      WHEN UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'
        OR (
          UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'NOTA'
          AND EXISTS (
            SELECT 1
            FROM hatched_nests hatched
            WHERE hatched.nest_id = active_nests.nest_id
          )
        )
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
      WHEN active_nests.nest_id = 'B2203'
       AND UPPER(TRIM(COALESCE(adult_parent_status.F_parent_mark, ''))) = 'YY-TB.BL'
      THEN 1
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
        OR adult_parent_status.both_parents_need_geo_derived = 1
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
      n.latest_float_date,
      n.average_ref_date_days_since_laid,
      n.min_days_to_hatch,
      n.nest_photo,
      n.tent_photo,
      n.lat,
      n.lon,
      n.reference_date,
      nest_discovery.first_found_date,
      0 AS is_negative_brood
    FROM latest_nests n
    JOIN hatched_nests
      ON n.nest_id = hatched_nests.nest_id
    LEFT JOIN nest_discovery
      ON n.nest_id = nest_discovery.nest_id
    WHERE UPPER(TRIM(COALESCE(n.nest_state, ''))) = 'NOTA'
    UNION ALL
    SELECT
      b.nest_id,
      b.species,
      b.latest_encounter_datetime,
      DATEDIFF(b.reference_date, b.latest_encounter_date),
      CONVERT(CAST(NULL AS CHAR(10)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci,
      b.nest_state,
      b.hatch_state,
      1,
      CONVERT(CAST(NULL AS CHAR(2)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci,
      b.clutch_size,
      b.brood_size,
      CAST(NULL AS DATE),
      CAST(NULL AS DECIMAL(6,1)),
      DATEDIFF(b.discovery_date, b.reference_date),
      b.nest_photo,
      b.tent_photo,
      b.lat,
      b.lon,
      b.reference_date,
      b.discovery_date,
      1
    FROM brood_context b
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
      UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) IN ('F', 'I', 'H', 'PP', 'PD', 'NOTA')
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
      (
        active_nests.nest_id = 'B2203'
        AND UPPER(TRIM(COALESCE(adult_parent_status.F_parent_mark, ''))) = 'YY-TB.BL'
      )
      OR geo_parent_plan.geo_instruction IS NOT NULL
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
      WHEN duplicate_correction = 1
      THEN 'F: CORRECT DUPLICATE'
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
      WHEN duplicate_correction = 1
      THEN 'Parent capture'
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
parent_units AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    active_nests.min_days_to_hatch,
    active_nests.days_ago AS last_visit_days_ago,
    active_nests.nest_state,
    active_nests.clutch_size,
    active_nests.brood_size,
    active_nests.lat,
    active_nests.lon,
    nest_discovery.first_found_date
  FROM active_nests
  LEFT JOIN nest_discovery
    ON active_nests.nest_id = nest_discovery.nest_id
  UNION ALL
  SELECT
    n.nest_id,
    n.reference_date,
    n.min_days_to_hatch,
    n.days_ago AS last_visit_days_ago,
    n.nest_state,
    n.clutch_size,
    n.brood_size,
    n.lat,
    n.lon,
    nest_discovery.first_found_date
  FROM latest_nests n
  JOIN hatched_nests
    ON n.nest_id = hatched_nests.nest_id
  LEFT JOIN nest_discovery
    ON n.nest_id = nest_discovery.nest_id
  WHERE UPPER(TRIM(COALESCE(n.nest_state, ''))) = 'NOTA'
  UNION ALL
  SELECT
    b.nest_id,
    b.reference_date,
    DATEDIFF(b.discovery_date, b.reference_date),
    DATEDIFF(b.reference_date, b.latest_encounter_date) AS last_visit_days_ago,
    b.nest_state,
    b.clutch_size,
    b.brood_size,
    b.lat,
    b.lon,
    b.discovery_date AS first_found_date
  FROM brood_context b
  CROSS JOIN sr
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
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
  UNION ALL
  /*
    Known-banded parents with unresolved nest association bypass the GEO
    candidate path above. They must remain visible here even when no capture
    or pair-completion instruction is available; otherwise a single ordinary
    AT resighting can disappear from both parent-work tables. Keep this branch
    separate so it cannot be suppressed by GEO ranking or tag eligibility.
  */
  SELECT
    parent_units.nest_id,
    parent_units.reference_date,
    'Parent resighting' AS todo,
    CASE
      WHEN association.M_resight_association_pending = 1
       AND association.F_resight_association_pending = 1
      THEN CONCAT(
        'M with ',
        association.M_resight_association_count,
        CASE
          WHEN association.M_resight_association_count = 1
          THEN ' resighting'
          ELSE ' resightings'
        END,
        '; F with ',
        association.F_resight_association_count,
        CASE
          WHEN association.F_resight_association_count = 1
          THEN ' resighting'
          ELSE ' resightings'
        END
      )
      WHEN association.M_resight_association_pending = 1
      THEN CONCAT(
        'M with ',
        association.M_resight_association_count,
        CASE
          WHEN association.M_resight_association_count = 1
          THEN ' resighting'
          ELSE ' resightings'
        END,
        CASE
          WHEN association.F_resighting_identity_count > 0
           AND association.F_resight_association_pending = 0
           AND association.F_mm_resight_pending = 0
          THEN '; F resolved'
          ELSE ''
        END
      )
      ELSE CONCAT(
        'F with ',
        association.F_resight_association_count,
        CASE
          WHEN association.F_resight_association_count = 1
          THEN ' resighting'
          ELSE ' resightings'
        END,
        CASE
          WHEN association.M_resighting_identity_count > 0
           AND association.M_resight_association_pending = 0
           AND association.M_mm_resight_pending = 0
          THEN '; M resolved'
          ELSE ''
        END
      )
    END AS notes,
    DATEDIFF(
      parent_units.reference_date,
      COALESCE(parent_units.first_found_date, parent_units.reference_date)
    ) AS days_overdue,
    350
      + DATEDIFF(
          parent_units.reference_date,
          COALESCE(parent_units.first_found_date, parent_units.reference_date)
        )
      + 3 * GREATEST(
          0,
          5 - CEILING(COALESCE(parent_units.min_days_to_hatch, 99))
        ) AS priority,
    parent_units.min_days_to_hatch,
    parent_units.last_visit_days_ago,
    parent_units.nest_state,
    parent_units.clutch_size,
    parent_units.brood_size,
    CASE
      WHEN association.M_resight_association_pending = 1
      THEN COALESCE(
        association.M_resight_association_details,
        association.M_parent_mark
      )
      /* Keep a resolved opposite-sex identity visible on the same
         resighting row; only the unresolved identity needs detail text. */
      ELSE association.M_parent_mark
    END AS M_mark,
    CASE
      WHEN association.F_resight_association_pending = 1
      THEN COALESCE(
        association.F_resight_association_details,
        association.F_parent_mark
      )
      /* Keep a resolved opposite-sex identity visible on the same
         resighting row; only the unresolved identity needs detail text. */
      ELSE association.F_parent_mark
    END AS F_mark,
    parent_units.lat,
    parent_units.lon
  FROM parent_units
  JOIN adult_parent_status association
    ON parent_units.nest_id = association.nest_id
  WHERE association.M_resight_association_pending = 1
     OR association.F_resight_association_pending = 1
  UNION ALL
  /*
    A parent with no selected identity must still receive a resighting task
    when the capture branch did not produce an actionable row. This keeps
    unresolved nest association visible without weakening the four-gate
    evidence hierarchy or creating a second capture target.
  */
  SELECT
    parent_units.nest_id,
    parent_units.reference_date,
    'Parent resighting' AS todo,
    CASE
      WHEN parent_units.min_days_to_hatch IS NULL
      THEN 'not yet floated'
      WHEN association.nest_id IS NULL
       OR (
         COALESCE(association.M_unknown_status, 0) = 1
         AND COALESCE(association.F_unknown_status, 0) = 1
       )
      THEN 'parent identity unknown'
      WHEN COALESCE(association.M_unknown_status, 0) = 1
      THEN 'M identity unknown'
      ELSE 'F identity unknown'
    END AS notes,
    DATEDIFF(
      parent_units.reference_date,
      COALESCE(parent_units.first_found_date, parent_units.reference_date)
    ) AS days_overdue,
    350
      + DATEDIFF(
          parent_units.reference_date,
          COALESCE(parent_units.first_found_date, parent_units.reference_date)
        ) AS priority,
    parent_units.min_days_to_hatch,
    parent_units.last_visit_days_ago,
    parent_units.nest_state,
    parent_units.clutch_size,
    parent_units.brood_size,
    association.M_parent_mark AS M_mark,
    association.F_parent_mark AS F_mark,
    parent_units.lat,
    parent_units.lon
  FROM parent_units
  LEFT JOIN adult_parent_status association
    ON parent_units.nest_id = association.nest_id
  WHERE (
      association.nest_id IS NULL
      OR COALESCE(association.M_unknown_status, 0) = 1
      OR COALESCE(association.F_unknown_status, 0) = 1
    )
    AND NOT EXISTS (
      SELECT 1
      FROM todo_untrapped_parent candidate
      WHERE candidate.nest_id = parent_units.nest_id
    )
),
todo_parent_resighting AS (
  SELECT
    nest_id,
    reference_date,
    'Parent resighting' AS todo,
    CASE
      WHEN MAX(min_days_to_hatch) IS NULL
      THEN 'not yet floated'
      ELSE GROUP_CONCAT(DISTINCT notes ORDER BY notes SEPARATOR '; ')
    END AS notes,
    MAX(days_overdue) AS days_overdue,
    MAX(priority) AS priority,
    MAX(min_days_to_hatch) AS min_days_to_hatch,
    MAX(last_visit_days_ago) AS last_visit_days_ago,
    MAX(nest_state) AS nest_state,
    MAX(clutch_size) AS clutch_size,
    MAX(brood_size) AS brood_size,
    GROUP_CONCAT(
      DISTINCT NULLIF(TRIM(M_mark), '')
      ORDER BY M_mark
      SEPARATOR ' & '
    ) AS M_mark,
    GROUP_CONCAT(
      DISTINCT NULLIF(TRIM(F_mark), '')
      ORDER BY F_mark
      SEPARATOR ' & '
    ) AS F_mark,
    MAX(lat) AS lat,
    MAX(lon) AS lon
  FROM todo_parent_resighting_existing
  GROUP BY nest_id, reference_date
),
todo_unprocessed_nest AS (
  SELECT
    active_nests.nest_id,
    active_nests.reference_date,
    'Unprocessed nest' AS todo,
    CASE
      WHEN COALESCE(initial_clutch_status.processing_flotation_exempt, 0) = 0
       AND COALESCE(processing_summary.n_float_rows, 0) = 0
       AND COALESCE(processing_summary.n_photo_rows, 0) = 0
      THEN 'float + nest/tent photos'
      WHEN COALESCE(initial_clutch_status.processing_flotation_exempt, 0) = 0
       AND COALESCE(processing_summary.n_float_rows, 0) = 0
      THEN 'float only'
      WHEN COALESCE(processing_summary.n_photo_rows, 0) = 0
      THEN 'nest/tent photos only'
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
  LEFT JOIN initial_clutch_status
    ON active_nests.nest_id = initial_clutch_status.nest_id
  WHERE UPPER(TRIM(COALESCE(active_nests.species, ''))) = 'BADO'
    AND UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) IN ('F', 'I', 'PP', 'PD')
    AND COALESCE(adult_capture_age_status.clutch_completion_confirmed, 0) = 1
    AND (
      (
        COALESCE(initial_clutch_status.processing_flotation_exempt, 0) = 0
        AND COALESCE(processing_summary.n_float_rows, 0) = 0
      )
      OR COALESCE(processing_summary.n_photo_rows, 0) = 0
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
  LEFT JOIN FIELD_2026_BADOatNZ.ADULT_SCRAPE_RESIGHTING_STATUS
    adult_resighting_association_status
    ON active_nests.nest_id = adult_resighting_association_status.nest_id
  WHERE UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'S'
    AND COALESCE(photo_summary.n_photo_rows, 0) = 0
    AND (
      COALESCE(adult_resighting_association_status.M_has_unique_scrape_resight, 0) = 1
      OR COALESCE(adult_resighting_association_status.F_has_unique_scrape_resight, 0) = 1
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
    AND COALESCE(initial_clutch_status.processing_flotation_exempt, 0) = 0
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
    -- A lower later clutch count is egg loss/predation evidence, not evidence
    -- that another egg is still expected. Do not reopen the additional-egg
    -- task after a previously recorded larger clutch.
    AND NOT EXISTS (
      SELECT 1
      FROM FIELD_2026_BADOatNZ.TODO_NEST_HISTORY prior_nest_event
      WHERE prior_nest_event.nest_id = active_nests.nest_id
        AND prior_nest_event.date <= latest_nest_event.event_date
        AND prior_nest_event.clutch_size IS NOT NULL
        AND prior_nest_event.clutch_size > latest_nest_event.clutch_size
    )
    -- Once a one-egg clutch has remained unchanged for two full laying
    -- intervals, treat it as complete rather than requesting indefinite
    -- additional-egg checks. A later clutch increase removes this prediction
    -- and reopens the check for the next egg.
    AND NOT EXISTS (
      SELECT 1
      FROM FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION stable_one_egg
      WHERE stable_one_egg.nest_id = active_nests.nest_id
        AND stable_one_egg.calibration_match_type = 'stable one-egg/no increase'
    )
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
        'no entry'
      ),
      CASE
        WHEN (
          active_nests.hatch_signs_present = 1
          OR UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'
        )
         AND COALESCE(active_nests.clutch_size, 0) > 0
         AND COALESCE(active_nests.brood_size, 0) > 0
        THEN '; unhatched egg(s)'
        ELSE ''
      END
    ) AS notes,
    CASE
      WHEN active_nests.hatch_signs_present = 1
        OR (
          UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'
          AND COALESCE(active_nests.clutch_size, 0) > 0
        )
      THEN GREATEST(0, active_nests.days_ago - 1)
      ELSE GREATEST(
        0,
        6
          - CEILING(active_nests.min_days_to_hatch)
      )
    END AS days_overdue,
    CASE
      WHEN active_nests.hatch_signs_present = 1
        OR (
          UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'
          AND COALESCE(active_nests.clutch_size, 0) > 0
        )
      THEN 500 + GREATEST(0, active_nests.days_ago - 1)
      ELSE 300
        + GREATEST(
            0,
            6
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
        UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'
        AND COALESCE(active_nests.clutch_size, 0) > 0
        AND active_nests.days_ago >= 1
      )
      OR (
        UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) IN ('I', 'PP', 'PD')
        AND active_nests.min_days_to_hatch IS NOT NULL
        AND CEILING(active_nests.min_days_to_hatch)
            <= 6
        AND active_nests.days_ago >= 2
      )
    )
    -- Once age-C evidence has established a brood, the nest-check task is
    -- redundant even if the nest visit still carries a partial hatch sign.
    AND NOT EXISTS (
      SELECT 1
      FROM brood_context brood_evidence
      WHERE brood_evidence.nest_id = active_nests.nest_id
        AND brood_evidence.reference_date = active_nests.reference_date
        AND brood_evidence.is_negative_brood = 0
        AND brood_evidence.has_hatch_evidence = 1
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
    AND DATEDIFF(
          brood_followup_nests.reference_date,
          brood_followup_nests.hatch_date
        ) < 21
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
    CONVERT(CAST(NULL AS CHAR(10)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS nest_state,
    CAST(NULL AS SIGNED) AS clutch_size,
    CAST(NULL AS SIGNED) AS brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    b.lat,
    b.lon
  FROM brood_context b
  CROSS JOIN sr
  LEFT JOIN chick_captures
    ON b.nest_id = chick_captures.nest_id
  LEFT JOIN adult_parent_status
    ON b.nest_id = adult_parent_status.nest_id
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
    AND COALESCE(chick_captures.n_chick_captures, 0) = 0
    AND DATEDIFF(b.reference_date, b.discovery_date) < 21
),
todo_broods_to_recapture_for_flagging AS (
  SELECT
    brood_followup_nests.nest_id,
    brood_followup_nests.reference_date,
    'Broods to recapture for flagging' AS todo,
    CASE
      WHEN COALESCE(chick_captures.n_chick_captures, 0) = 0
      THEN 'no chick captures; recapture chicks and assign unique engraved UL flags'
      WHEN COALESCE(chick_captures.n_unringed_chick_captures, 0) > 0
      THEN 'recapture chicks; assign unique engraved UL flags (some chick captures lack metal-ring IDs)'
      ELSE CONCAT(
        'recapture chicks; assign flags (',
        GREATEST(
          COALESCE(brood_followup_nests.brood_size, 0),
          COALESCE(chick_captures.n_captured_chick_rings, 0)
        ) - COALESCE(chick_captures.n_flagged_chick_rings, 0),
        ' pending)'
      )
    END AS notes,
    DATEDIFF(
      brood_followup_nests.reference_date,
      brood_followup_nests.hatch_date
    ) AS days_overdue,
    475 + DATEDIFF(
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
  WHERE DATEDIFF(
          brood_followup_nests.reference_date,
          brood_followup_nests.hatch_date
        ) >= 21
    AND (
      COALESCE(chick_captures.n_chick_captures, 0) = 0
      OR COALESCE(chick_captures.n_unringed_chick_captures, 0) > 0
      OR GREATEST(
           COALESCE(brood_followup_nests.brood_size, 0),
           COALESCE(chick_captures.n_captured_chick_rings, 0)
         ) > COALESCE(chick_captures.n_flagged_chick_rings, 0)
    )
  UNION ALL
  SELECT
    b.nest_id,
    b.reference_date,
    'Broods to recapture for flagging' AS todo,
    CASE
      WHEN COALESCE(chick_captures.n_chick_captures, 0) = 0
      THEN 'no chick captures; recapture chicks and assign unique engraved UL flags'
      WHEN COALESCE(chick_captures.n_unringed_chick_captures, 0) > 0
      THEN 'recapture chicks; assign unique engraved UL flags (some chick captures lack metal-ring IDs)'
      ELSE CONCAT(
        'recapture chicks; assign flags (',
        GREATEST(
          COALESCE(b.brood_size, 0),
          COALESCE(chick_captures.n_captured_chick_rings, 0)
        ) - COALESCE(chick_captures.n_flagged_chick_rings, 0),
        ' pending)'
      )
    END AS notes,
    DATEDIFF(b.reference_date, b.discovery_date) AS days_overdue,
    475 + DATEDIFF(b.reference_date, b.discovery_date) AS priority,
    DATEDIFF(b.discovery_date, b.reference_date) AS min_days_to_hatch,
    DATEDIFF(b.reference_date, b.latest_encounter_date) AS last_visit_days_ago,
    CONVERT(CAST(NULL AS CHAR(10)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS nest_state,
    CAST(NULL AS SIGNED) AS clutch_size,
    CAST(NULL AS SIGNED) AS brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    b.lat,
    b.lon
  FROM brood_context b
  CROSS JOIN sr
  LEFT JOIN chick_captures
    ON b.nest_id = chick_captures.nest_id
  LEFT JOIN adult_parent_status
    ON b.nest_id = adult_parent_status.nest_id
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
    AND DATEDIFF(b.reference_date, b.discovery_date) >= 21
    AND (
      COALESCE(chick_captures.n_chick_captures, 0) = 0
      OR COALESCE(chick_captures.n_unringed_chick_captures, 0) > 0
      OR GREATEST(
           COALESCE(b.brood_size, 0),
           COALESCE(chick_captures.n_captured_chick_rings, 0)
         ) > COALESCE(chick_captures.n_flagged_chick_rings, 0)
    )
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
      ' chicks with rclass ''H'' photos'
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
      ' chicks with rclass ''H'' photos'
    ) AS notes,
    GREATEST(0, DATEDIFF(b.reference_date, b.discovery_date) - 1) AS days_overdue,
    400 + GREATEST(0, DATEDIFF(b.reference_date, b.discovery_date) - 1) AS priority,
    DATEDIFF(b.discovery_date, b.reference_date) AS min_days_to_hatch,
    DATEDIFF(b.reference_date, b.latest_encounter_date) AS last_visit_days_ago,
    CONVERT(CAST(NULL AS CHAR(10)) USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS nest_state,
    CAST(NULL AS SIGNED) AS clutch_size,
    CAST(NULL AS SIGNED) AS brood_size,
    adult_parent_status.M_parent_mark AS M_mark,
    adult_parent_status.F_parent_mark AS F_mark,
    b.lat,
    b.lon
  FROM brood_context b
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
  /*
    Keep the resolved parent identity available to every TODO/PDF consumer.
    Task-specific M_mark/F_mark values may add pending-association counts for
    the parent-resighting table, but these two fields are the canonical
    adult_parent_status result used for cross-table reconciliation.
  */
  adult_parent_status.M_parent_mark AS authoritative_M_mark,
  adult_parent_status.F_parent_mark AS authoritative_F_mark,
  adult_parent_status.M_resight_association_pending,
  adult_parent_status.F_resight_association_pending,
  adult_parent_status.M_mm_resight_pending,
  adult_parent_status.F_mm_resight_pending,
  adult_parent_status.M_resighting_identity_count,
  adult_parent_status.F_resighting_identity_count,
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
  SELECT * FROM todo_broods_to_recapture_for_flagging
  UNION ALL
  SELECT * FROM todo_hiding_spot_photos
  UNION ALL
  SELECT * FROM todo_nota_nest_check
) t
LEFT JOIN adult_parent_status
  ON t.nest_id = adult_parent_status.nest_id
LEFT JOIN geo_parent_plan
  ON t.nest_id = geo_parent_plan.nest_id
-- WRYB remains available to map/summary consumers, but is not a Cass
-- operational task in TODO_LIST.
WHERE NOT EXISTS (
  SELECT 1
  FROM FIELD_2026_BADOatNZ.NESTS_LATEST wryb_nest
  WHERE wryb_nest.nest_id = t.nest_id
    AND UPPER(TRIM(COALESCE(wryb_nest.species, ''))) = 'WRYB'
);;

SELECT 'TODO_REFRESH_STAGE|publishing' AS refresh_stage;

/*
  Promotion happens only after both INSERT statements above succeed. The
  MariaDB updates dependent view references when the referenced snapshot table
  is renamed, so public views are deliberately kept in place during the
  rename. If the rename waits on a metadata lock or fails, the old public
  snapshot remains available and the BUILD tables remain unpublished.
*/

RENAME TABLE
  FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT,
  FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT,
  FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT,
  FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT,
  FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT,
  FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT,
  FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_STATUS AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_TASKS AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT
WHERE todo IN (
  'Parent capture',
  'Parent resighting'
);

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_NONPARENT_TASKS AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT
WHERE todo NOT IN (
  'Parent capture',
  'Parent resighting'
)
  AND todo <> 'Untrapped parent';

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_LIST AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
)
SELECT parent_tasks.*
FROM FIELD_2026_BADOatNZ.TODO_PARENT_TASKS parent_tasks
JOIN sr
  ON parent_tasks.reference_date = sr.reference_date
UNION ALL
SELECT nonparent_tasks.*
FROM FIELD_2026_BADOatNZ.TODO_NONPARENT_TASKS nonparent_tasks
JOIN sr
  ON nonparent_tasks.reference_date = sr.reference_date;

DROP TABLE FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_PREVIOUS;
DROP TABLE FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_PREVIOUS;
DROP TABLE FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_PREVIOUS;
DROP TABLE FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_PREVIOUS;
DROP TABLE FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_PREVIOUS;
DROP TABLE FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_PREVIOUS;
DROP TABLE FIELD_2026_BADOatNZ.TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT_PREVIOUS;

UPDATE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS
SET
  state = 'succeeded',
  completed_at = CURRENT_TIMESTAMP,
  task_row_count = (
    SELECT COUNT(*)
    FROM FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT
  )
WHERE refresh_id = @todo_refresh_id;
