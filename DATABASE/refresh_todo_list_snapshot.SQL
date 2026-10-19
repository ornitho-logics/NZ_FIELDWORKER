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
  input boundary is repointed to that BUILD table, so TODO_LIST_CALCULATE does
  not expand ADULT_PARENT_STATUS a second time. It is repointed to the
  promoted parent snapshot only after the task BUILD insert succeeds.

  TODO_BROOD_CONTEXT_INPUT is likewise reset before stale BUILD tables are
  removed, then repointed to a compact indexed brood BUILD table before task
  assembly. This avoids expanding BROODS_LATEST independently in each brood
  task branch while preserving the same source columns and predicates.

  The GPS-linked chick-parent result is staged before parent status. This keeps
  the expensive GPS matching graph out of repeated parent-status expansions
  while preserving the same definitive evidence gate.

  The explicit task schema avoids CREATE TABLE AS SELECT ... WHERE 1 = 0,
  which otherwise expands TODO_LIST_CALCULATE just to infer column types.
  This script never reads an RDS file and never queries the remote database
  through an application connection; it uses the live database selected by
  the SQL client.
*/

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

/* Build task rows while the existing TODO_LIST remains available. */
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

INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE;

SELECT 'TODO_REFRESH_STAGE|publishing' AS refresh_stage;

/*
  Promotion happens only after both INSERT statements above succeed. The
  rename is atomic; public views are recreated from the newly populated
  tables, and the previous tables are kept until that recreation succeeds.
*/
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST;
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_TASKS;
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_NONPARENT_TASKS;
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_STATUS;
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_INPUT;
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_INPUT;
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT;

RENAME TABLE
  FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT,
  FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT,
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
  'Untrapped parent',
  'Parent capture',
  'Parent resighting'
);

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_NONPARENT_TASKS AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT
WHERE todo NOT IN (
  'Untrapped parent',
  'Parent capture',
  'Parent resighting'
);

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
