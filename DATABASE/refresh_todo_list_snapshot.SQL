/*
  Refresh the derived TODO task snapshot after source data or settings change.

  This is a staged refresh. The current public TODO_* views remain available
  while the replacement snapshots are computed. If MariaDB or the client
  fails during either expensive INSERT, only the *_BUILD tables are affected;
  the old public task output is not dropped. Execute this file with the SQL
  client set to stop on error.

  The explicit task schema avoids CREATE TABLE AS SELECT ... WHERE 1 = 0,
  which otherwise expands TODO_LIST_CALCULATE just to infer column types.
  This script never reads an RDS file and never queries the remote database
  through an application connection; it uses the live database selected by
  the SQL client.
*/

DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_PREVIOUS;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_PREVIOUS;

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

/* Build task rows while the existing TODO_LIST remains available. */
CREATE TABLE FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD (
  nest_id VARCHAR(6) NULL,
  reference_date DATE NULL,
  todo VARCHAR(25) NOT NULL,
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

/*
  Promotion happens only after both INSERT statements above succeed. The
  rename is atomic; public views are recreated from the newly populated
  tables, and the previous tables are kept until that recreation succeeds.
*/
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST;
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_TASKS;
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_NONPARENT_TASKS;
DROP VIEW IF EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_STATUS;

RENAME TABLE
  FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT,
  FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT;

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
