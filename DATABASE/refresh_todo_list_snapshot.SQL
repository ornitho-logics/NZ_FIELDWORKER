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

  The canonical chick-event, target, age-C encounter/latest, juvenile-origin,
  and context calculations are materialized into connection-local temporary
  inputs rather than persistent views. The source graph is therefore expanded
  once for this refresh, and the same-occasion family resolver is never
  validated or re-expanded during views.SQL deployment. The completed chick
  aggregate is then the only downstream input for those task branches.

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

/*
  Upgrade a legacy status table in place when this refresh script is run
  without a preceding views.SQL import.  Preserve existing history and make
  the operation idempotent for already-upgraded databases.
*/
SET @todo_status_next_id := (
  SELECT COALESCE(MAX(refresh_id), 0)
  FROM FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS
);

UPDATE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS
SET refresh_id = (@todo_status_next_id := @todo_status_next_id + 1)
WHERE refresh_id IS NULL
ORDER BY started_at, completed_at, reference_date;

ALTER TABLE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS
  MODIFY refresh_id BIGINT UNSIGNED NOT NULL;

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

ALTER TABLE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS
  MODIFY refresh_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT;

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

/*
  Temporary inputs belong to this Adminer connection. Clear any remnants from
  an interrupted retry before creating the fresh source graph below; do not
  repeat this cleanup after the graph has been materialized.
*/
DROP TEMPORARY TABLE IF EXISTS tmp_todo_hiding_photo_targets;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_parent_associations;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_identity_matches;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_raw_encounter_nest_consensus;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_chick_capture_events;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_chick_capture_event_status;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_chick_capture_targets;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_chick_capture_context_base;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_juvenile_origin_events;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_parent_chick_resighting_associations;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_ordinary_family_resighting_associations;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_chick_encounters;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_live_chick_encounters;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_chick_latest_encounter_context;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_chick_capture_context;

/*
  Reset the chick context pointer before removing a stale BUILD table. This
  typed, empty boundary is independent of both the old published table and
  the new BUILD table, so retries cannot retain a dangling view definition.
  The first 15 columns preserve the historical context contract; the extra
  encounter columns are nullable extensions used by the current task engine.
*/
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT AS
SELECT
  CAST(NULL AS CHAR(6)) AS nest_id,
  CAST(NULL AS SIGNED) AS n_chick_captures,
  CAST(NULL AS SIGNED) AS n_captured_chick_rings,
  CAST(NULL AS SIGNED) AS n_flagged_chick_rings,
  CAST(NULL AS SIGNED) AS n_unringed_chick_captures,
  CAST(NULL AS SIGNED) AS n_dead_chick_rings,
  CAST(NULL AS SIGNED) AS n_active_chick_rings,
  CAST(NULL AS SIGNED) AS n_active_flagged_chick_rings,
  CAST(NULL AS SIGNED) AS n_active_chick_captures,
  CAST(NULL AS SIGNED) AS n_unresolved_dead_chick_events,
  CAST(NULL AS SIGNED) AS observed_brood_size,
  CAST(NULL AS DATE) AS latest_brood_count_date,
  CAST(NULL AS SIGNED) AS n_deaths_after_latest_brood_count,
  CAST(NULL AS SIGNED) AS n_operational_brood_size,
  CAST(NULL AS CHAR(64)) AS operational_brood_size_source,
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
  CAST(NULL AS CHAR(128)) AS latest_encounter_provenance
WHERE 1 = 0;

/* Repair all other internal input boundaries before removing stale BUILD tables. */
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

/*
  Keep raw encounter conflict evidence independent from proof-eligible parent
  and chick inputs. This is a veto-only source for inferred same-occasion
  links; it does not supply an association by itself.
*/
CREATE TEMPORARY TABLE tmp_todo_raw_encounter_nest_consensus AS
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

ALTER TABLE tmp_todo_raw_encounter_nest_consensus
  ADD INDEX idx_tmp_todo_raw_encounter_gps_date
    (event_date, gps_id, gps_point);

CREATE TEMPORARY TABLE tmp_todo_chick_capture_events AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
),
/*
  Resolve missing R/C nest IDs from the latest unambiguous prior ring-linked
  brood. Explicit nest IDs are never overwritten: a chick can mix between
  broods after hatching, so an explicit later nest remains authoritative for
  that capture. Ambiguous same-date histories are left unresolved.
*/
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
    /* Keep the refresh path identical to the installed view path. */
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

ALTER TABLE tmp_todo_chick_capture_events
  ADD INDEX idx_tmp_todo_chick_event_pk (capture_pk),
  ADD INDEX idx_tmp_todo_chick_event_origin_date (origin_key, event_date),
  ADD INDEX idx_tmp_todo_chick_event_flag_date (flag_code, event_date);

/*
  Reuse one event-level bridge classification for the target and aggregate
  layers. The raw event input remains source-only; this mirror adds the
  derived bridge fields before any snapshot is materialized.
*/
CREATE TEMPORARY TABLE tmp_todo_chick_capture_event_status AS
WITH chick_events AS (
  SELECT
    events.*
  FROM tmp_todo_chick_capture_events events
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

ALTER TABLE tmp_todo_chick_capture_event_status
  ADD INDEX idx_tmp_todo_chick_status_pk (capture_pk),
  ADD INDEX idx_tmp_todo_chick_status_ring (ring_key),
  ADD INDEX idx_tmp_todo_chick_status_flag (flag_code);

/*
  Keep one canonical target row per brood/ring. Death resolution is global by
  normalized ring, while the target's flag state is aggregated across all
  captures for that brood/ring.
*/
CREATE TEMPORARY TABLE tmp_todo_chick_capture_targets AS
WITH chick_events AS (
  SELECT
    events.*
  FROM tmp_todo_chick_capture_event_status events
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

ALTER TABLE tmp_todo_chick_capture_targets
  ADD INDEX idx_tmp_todo_chick_target_nest_ring (nest_id, ring_key),
  ADD INDEX idx_tmp_todo_chick_target_ring (ring_key);

CREATE TEMPORARY TABLE tmp_todo_chick_capture_context_base AS
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
  FROM tmp_todo_chick_capture_event_status events
  LEFT JOIN tmp_todo_chick_capture_targets targets
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
  FROM tmp_todo_chick_capture_targets targets
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
  FROM tmp_todo_chick_capture_targets targets
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

ALTER TABLE tmp_todo_chick_capture_context_base
  ADD INDEX idx_tmp_todo_chick_context_base_nest (nest_id);

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
CREATE TEMPORARY TABLE tmp_todo_juvenile_origin_events AS
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
  FROM tmp_todo_chick_capture_events events
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
    FROM tmp_todo_chick_capture_events events
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
  FROM tmp_todo_chick_capture_events captures
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
  FROM tmp_todo_chick_capture_events captures
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
  FROM tmp_todo_chick_capture_events captures
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
  FROM tmp_todo_chick_capture_events captures
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
  FROM tmp_todo_chick_capture_events captures
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

ALTER TABLE tmp_todo_juvenile_origin_events
  ADD INDEX idx_tmp_todo_juvenile_origin_brood_date
    (brood_id, event_date);

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
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_BUILD;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_PREVIOUS;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_PREVIOUS;
DROP TABLE IF EXISTS FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_PREVIOUS;

SELECT 'TODO_REFRESH_STAGE|nest_context' AS refresh_stage;

/* Build the bounded operational context once for all task branches. */
CREATE TABLE FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT_BUILD (
  nest_id VARCHAR(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NULL,
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
  nest_id VARCHAR(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NULL,
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
  nest_id VARCHAR(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NULL,
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
  nest_id VARCHAR(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NULL,
  reference_date DATE NULL,
  M_selected_mark LONGTEXT NULL,
  F_selected_mark LONGTEXT NULL,
  M_selected_identity_key VARCHAR(255) NULL,
  F_selected_identity_key VARCHAR(255) NULL,
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
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT
LIKE FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD;

INSERT INTO FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_PARENT_STATUS;

/* Feed task assembly from the completed parent BUILD, not the live pipeline. */
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT_BUILD;

/*
  Materialize the two identity projections once after parent status has been
  built. The S10 chick-parent resolver and the later closure audit consume the
  same connection-local rows and indexes; neither path re-expands the source
  identity views independently.
*/
CREATE TEMPORARY TABLE tmp_todo_closure_parent_associations AS
SELECT
  association.nest_id,
  association.sex,
  association.identity_key,
  association.association_selected,
  association.association_ambiguous,
  association.association_evidence_datetime
FROM FIELD_2026_BADOatNZ.ADULT_PARENT_NEST_ASSOCIATIONS association;

ALTER TABLE tmp_todo_closure_parent_associations
  ADD INDEX idx_todo_closure_parent_assoc_nest_sex_identity
    (nest_id, sex, identity_key),
  ADD INDEX idx_todo_closure_parent_assoc_identity_sex
    (identity_key, sex);

CREATE TEMPORARY TABLE tmp_todo_closure_identity_matches AS
SELECT
  matched.nest_id,
  matched.sex,
  matched.identity_key,
  matched.match_class,
  matched.is_ambiguous_match,
  matched.n_candidate_identities,
  matched.association_evidence_eligible,
  matched.observation_date,
  matched.resighting_pk,
  matched.behav
FROM FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES matched;

ALTER TABLE tmp_todo_closure_identity_matches
  ADD INDEX idx_todo_closure_identity_match_nest_sex_identity
    (nest_id, sex, identity_key),
  ADD INDEX idx_todo_closure_identity_match_identity_sex_date
    (identity_key, sex, observation_date),
  ADD INDEX idx_todo_closure_identity_match_resighting
    (resighting_pk);

/*
  S10 is a task-resolution extension of the authoritative parent layer, not a
  second parent-history algorithm. It handles the narrow case where a negative
  brood already has exactly one selected M and F in
  ADULT_PARENT_NEST_ASSOCIATIONS, an unlinked current adult resighting is
  uniquely matched to one of those selected identities, and an unlinked chick
  resighting shares that adult event's exact date and GPS pair. The raw rows
  remain unchanged; ambiguous candidate broods are deliberately excluded.
*/
CREATE TEMPORARY TABLE tmp_todo_parent_chick_resighting_associations AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), selected_parent_identities AS (
  SELECT
    status.nest_id,
    'M' AS sex,
    status.M_selected_identity_key AS identity_key
  FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT status
  WHERE LEFT(TRIM(status.nest_id), 1) = '-'
    AND status.M_selected_identity_key IS NOT NULL
  UNION ALL
  SELECT
    status.nest_id,
    'F' AS sex,
    status.F_selected_identity_key AS identity_key
  FROM FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_INPUT status
  WHERE LEFT(TRIM(status.nest_id), 1) = '-'
    AND status.F_selected_identity_key IS NOT NULL
), resolved_negative_nests AS (
  SELECT nest_id
  FROM selected_parent_identities
  GROUP BY nest_id
  HAVING COUNT(DISTINCT sex) = 2
), selected_parent_proof AS (
  SELECT
    selected.nest_id,
    selected.sex,
    selected.identity_key,
    MIN(DATE(association.association_evidence_datetime))
      AS association_proof_date
  FROM selected_parent_identities selected
  JOIN tmp_todo_closure_parent_associations association
    ON association.nest_id = selected.nest_id
   AND association.sex = selected.sex
   AND association.identity_key = selected.identity_key
   AND association.association_selected = 1
   AND association.association_ambiguous = 0
   AND association.association_evidence_datetime IS NOT NULL
  GROUP BY selected.nest_id, selected.sex, selected.identity_key
), selected_parent_proof_summary AS (
  SELECT
    nest_id,
    MAX(association_proof_date) AS all_parent_proof_date
  FROM selected_parent_proof
  GROUP BY nest_id
  HAVING COUNT(DISTINCT sex) = 2
), unlinked_parent_resightings AS (
  SELECT
    r.pk AS parent_resighting_pk,
    r.date AS event_date,
    r.gps_id,
    r.gps_point,
    selected.nest_id,
    matched.identity_key,
    matched.sex
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  JOIN tmp_todo_closure_identity_matches matched
    ON matched.resighting_pk = r.pk
  JOIN selected_parent_identities selected
    ON selected.identity_key = matched.identity_key
   AND selected.sex = matched.sex
  JOIN selected_parent_proof proof
    ON proof.nest_id = selected.nest_id
   AND proof.sex = selected.sex
   AND proof.identity_key = selected.identity_key
   AND proof.association_proof_date <= r.date
  JOIN selected_parent_proof_summary all_proof
    ON all_proof.nest_id = selected.nest_id
   AND all_proof.all_parent_proof_date <= r.date
  JOIN resolved_negative_nests resolved
    ON resolved.nest_id = selected.nest_id
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
  LEFT JOIN tmp_todo_raw_encounter_nest_consensus encounter
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
CREATE TEMPORARY TABLE tmp_todo_ordinary_family_resighting_associations AS
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
  JOIN tmp_todo_raw_encounter_nest_consensus encounter
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
  tmp_todo_chick_encounters is the shared age-C encounter layer for
  flagging, PDF display, and refresh-time task snapshots. It combines
  reference-date-bounded CAPTURES and RESIGHTINGS rows with an unambiguous
  nest/brood association. Directly recorded CAPTURES nest links remain
  eligible without GPS; inferred associations require a valid exact GPS pair.
  RESIGHTINGS require a valid exact GPS pair.

  Ringed events use the normalized metal-ring identity. A ringless event is
  retained as an explicitly unresolved identity; it is never discarded just
  because a ringed event occurred on the same date. When a capture exists on
  the latest date, it is authoritative for ring-labelled rows; ringless or
  ambiguous resightings remain as conservative evidence. A resighting flag can
  resolve to a ring only when prior capture history maps that flag to exactly
  one ring. Known-dead identities remain visible as conservative evidence but
  are not counted as live latest encounters.
*/
CREATE TEMPORARY TABLE tmp_todo_chick_encounters AS
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), global_ring_status AS (
  SELECT
    ring_key,
    MAX(is_confirmed_dead) AS is_confirmed_dead,
    MAX(has_flagged_capture) AS has_flagged_capture
  FROM tmp_todo_chick_capture_targets
  WHERE ring_key IS NOT NULL
  GROUP BY ring_key
), capture_events AS (
  SELECT
    events.capture_pk AS event_pk,
    events.event_date,
    events.event_datetime,
    'CAPTURES' AS source_table,
    events.nest_id,
    events.gps_id,
    events.gps_point,
    events.ring_key,
    events.flag_code,
    events.capture_status,
    events.nest_id_source,
    1 AS source_rank,
    CASE
      WHEN events.ring_key IS NULL THEN 1
      ELSE 0
    END AS is_unresolved_identity,
    CASE
      WHEN UPPER(TRIM(COALESCE(events.capture_status, ''))) = 'D'
        OR COALESCE(targets.is_confirmed_dead, 0) = 1
      THEN 1
      ELSE 0
    END AS is_known_dead,
    COALESCE(targets.has_flagged_capture, 0) AS has_flagged_capture
  FROM tmp_todo_chick_capture_events events
  LEFT JOIN global_ring_status targets
    ON targets.ring_key = events.ring_key
  CROSS JOIN sr
  WHERE events.age = 'C'
    AND events.nest_id IS NOT NULL
    AND (
      events.nest_id_source = 'recorded'
      OR (
        events.gps_id IS NOT NULL
        AND events.gps_point IS NOT NULL
      )
    )
    AND events.event_date <= sr.reference_date
), raw_resightings AS (
  SELECT
    r.pk AS event_pk,
    r.date AS event_date,
    CAST(CONCAT(r.date, ' 00:00:00') AS DATETIME) AS event_datetime,
    r.gps_id,
    r.gps_point,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.nest_id, ''))) IN ('', 'NO_NEST')
      THEN NULL
      ELSE UPPER(TRIM(r.nest_id))
    END AS recorded_nest_id,
    CASE
      WHEN UPPER(TRIM(COALESCE(r.ring, ''))) IN (
        '', 'X', 'XX', 'X-X', 'NA', 'N/A', 'NULL'
      )
      THEN NULL
      ELSE REPLACE(UPPER(TRIM(r.ring)), '-', '')
    END AS ring_key,
    CASE
      WHEN UPPER(NULLIF(TRIM(r.UL), '')) REGEXP '^F[A-Z0-9]+$'
      THEN UPPER(NULLIF(TRIM(r.UL), ''))
      WHEN UPPER(NULLIF(TRIM(r.UR), '')) REGEXP '^F[A-Z0-9]+$'
      THEN UPPER(NULLIF(TRIM(r.UR), ''))
      ELSE NULL
    END AS flag_code
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS r
  CROSS JOIN sr
  WHERE UPPER(TRIM(COALESCE(r.site, ''))) = 'CR'
    AND r.age = 'C'
    AND r.gps_id IS NOT NULL
    AND r.gps_point IS NOT NULL
    AND r.date <= sr.reference_date
), resighting_primary_nest_candidates AS (
  SELECT
    raw.event_pk,
    raw.recorded_nest_id AS candidate_nest_id,
    'recorded' AS association_method
  FROM raw_resightings raw
  WHERE raw.recorded_nest_id IS NOT NULL

  UNION ALL

  SELECT
    raw.event_pk,
    h.resolved_nest_id,
    h.association_method
  FROM raw_resightings raw
  JOIN FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h
    ON h.resighting_pk = raw.event_pk
  WHERE h.resolved_nest_id IS NOT NULL

  UNION ALL

  SELECT
    raw.event_pk,
    ordinary.nest_id,
    ordinary.association_method
  FROM raw_resightings raw
  JOIN tmp_todo_ordinary_family_resighting_associations ordinary
    ON ordinary.resighting_pk = raw.event_pk
  WHERE ordinary.nest_id IS NOT NULL

  UNION ALL

  SELECT
    raw.event_pk,
    parent_link.nest_id,
    'parent_chick_same_occasion' AS association_method
  FROM raw_resightings raw
  JOIN tmp_todo_parent_chick_resighting_associations parent_link
    ON parent_link.resighting_pk = raw.event_pk
  WHERE parent_link.nest_id IS NOT NULL
), resighting_current_conflicts AS (
  SELECT raw.event_pk
  FROM raw_resightings raw
  JOIN FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h
    ON h.resighting_pk = raw.event_pk
  WHERE raw.recorded_nest_id IS NULL
    AND h.resolved_nest_id IS NULL
    AND COALESCE(h.association_method, '') <> 'ring_capture'

  UNION

  SELECT raw.event_pk
  FROM raw_resightings raw
  JOIN tmp_todo_raw_encounter_nest_consensus consensus
    ON consensus.event_date = raw.event_date
   AND consensus.gps_id = raw.gps_id
   AND consensus.gps_point = raw.gps_point
  WHERE raw.recorded_nest_id IS NULL
    AND consensus.n_explicit_nest_ids > 1
), resighting_ring_capture_candidates AS (
  SELECT
    raw.event_pk,
    TRIM(c.nest_id) AS candidate_nest_id,
    CAST(
      CONCAT(
        c.date,
        ' ',
        COALESCE(c.released, c.caught, '00:00:00')
      ) AS DATETIME
    ) AS capture_datetime
  FROM raw_resightings raw
  JOIN FIELD_2026_BADOatNZ.CAPTURES c
    ON NULLIF(REPLACE(UPPER(TRIM(c.ring)), '-', ''), '') = raw.ring_key
   AND c.age = 'C'
   AND UPPER(TRIM(COALESCE(c.site, ''))) = 'CR'
   AND c.date < raw.event_date
   AND c.nest_id IS NOT NULL
   AND TRIM(c.nest_id) <> ''
   AND UPPER(TRIM(c.nest_id)) <> 'NO_NEST'
  WHERE raw.recorded_nest_id IS NULL
    AND raw.ring_key IS NOT NULL
), resighting_latest_ring_capture_datetime AS (
  SELECT
    event_pk,
    MAX(capture_datetime) AS latest_capture_datetime
  FROM resighting_ring_capture_candidates
  GROUP BY event_pk
), resighting_latest_ring_nest_summary AS (
  SELECT
    candidates.event_pk,
    COUNT(DISTINCT candidates.candidate_nest_id) AS n_candidate_nests,
    MIN(candidates.candidate_nest_id) AS candidate_nest_id
  FROM resighting_ring_capture_candidates candidates
  JOIN resighting_latest_ring_capture_datetime latest
    ON latest.event_pk = candidates.event_pk
   AND latest.latest_capture_datetime = candidates.capture_datetime
  GROUP BY candidates.event_pk
), resighting_nest_candidates AS (
  SELECT
    primary_candidates.event_pk,
    primary_candidates.candidate_nest_id
  FROM resighting_primary_nest_candidates primary_candidates

  UNION ALL

  /* Prior-ring history is only a fallback after stronger current evidence. */
  SELECT
    raw.event_pk,
    history.candidate_nest_id
  FROM raw_resightings raw
  JOIN resighting_latest_ring_nest_summary history
    ON history.event_pk = raw.event_pk
   AND history.n_candidate_nests = 1
  LEFT JOIN tmp_todo_raw_encounter_nest_consensus consensus
    ON consensus.event_date = raw.event_date
   AND consensus.gps_id = raw.gps_id
   AND consensus.gps_point = raw.gps_point
  WHERE raw.recorded_nest_id IS NULL
    AND NOT EXISTS (
      SELECT 1
      FROM resighting_current_conflicts conflicts
      WHERE conflicts.event_pk = raw.event_pk
    )
    AND NOT EXISTS (
      SELECT 1
      FROM resighting_primary_nest_candidates primary_candidates
      WHERE primary_candidates.event_pk = raw.event_pk
    )
    AND (
      COALESCE(consensus.n_explicit_nest_ids, 0) = 0
      OR (
        consensus.n_explicit_nest_ids = 1
        AND UPPER(TRIM(consensus.explicit_nest_id)) =
            UPPER(TRIM(history.candidate_nest_id))
      )
    )
), resighting_nest_summary AS (
  SELECT
    raw.event_pk,
    COUNT(DISTINCT candidates.candidate_nest_id) AS n_candidate_nests,
    MIN(candidates.candidate_nest_id) AS nest_id
  FROM raw_resightings raw
  LEFT JOIN resighting_nest_candidates candidates
    ON candidates.event_pk = raw.event_pk
  GROUP BY raw.event_pk
), resighting_flag_ring_candidates AS (
  SELECT
    raw.event_pk,
    captures.ring_key
  FROM raw_resightings raw
  JOIN tmp_todo_chick_capture_events captures
    ON captures.flag_code = raw.flag_code
   AND captures.ring_key IS NOT NULL
   AND captures.event_date < raw.event_date
   AND UPPER(TRIM(COALESCE(captures.capture_status, ''))) IN ('F', 'R', 'C')
  WHERE raw.flag_code IS NOT NULL
), resighting_flag_ring_summary AS (
  SELECT
    event_pk,
    COUNT(DISTINCT ring_key) AS n_candidate_rings,
    MIN(ring_key) AS ring_key
  FROM resighting_flag_ring_candidates
  GROUP BY event_pk
), resighting_events AS (
  SELECT
    raw.event_pk,
    raw.event_date,
    raw.event_datetime,
    'RESIGHTINGS' AS source_table,
    nest_summary.nest_id,
    raw.gps_id,
    raw.gps_point,
    CASE
      WHEN raw.ring_key IS NOT NULL THEN raw.ring_key
      WHEN COALESCE(flag_summary.n_candidate_rings, 0) = 1
      THEN flag_summary.ring_key
      ELSE NULL
    END AS ring_key,
    raw.flag_code,
    CAST(NULL AS CHAR(1)) AS capture_status,
    'resighting' AS nest_id_source,
    2 AS source_rank,
    CASE
      WHEN raw.ring_key IS NOT NULL
       AND flag_summary.n_candidate_rings IS NOT NULL
       AND (
         flag_summary.n_candidate_rings <> 1
         OR flag_summary.ring_key <> raw.ring_key
       )
      THEN 1
      WHEN raw.ring_key IS NULL
       AND COALESCE(flag_summary.n_candidate_rings, 0) <> 1
      THEN 1
      ELSE 0
    END AS is_unresolved_identity,
    CASE
      WHEN COALESCE(targets.is_confirmed_dead, 0) = 1 THEN 1
      ELSE 0
    END AS is_known_dead,
    COALESCE(targets.has_flagged_capture, 0) AS has_flagged_capture
  FROM raw_resightings raw
  JOIN resighting_nest_summary nest_summary
    ON nest_summary.event_pk = raw.event_pk
   AND nest_summary.n_candidate_nests = 1
  LEFT JOIN resighting_flag_ring_summary flag_summary
    ON flag_summary.event_pk = raw.event_pk
  LEFT JOIN global_ring_status targets
    ON targets.ring_key = CASE
     WHEN raw.ring_key IS NOT NULL THEN raw.ring_key
     WHEN flag_summary.n_candidate_rings = 1 THEN flag_summary.ring_key
     ELSE NULL
   END
), all_events AS (
  SELECT * FROM capture_events
  UNION ALL
  SELECT * FROM resighting_events
)
SELECT
  all_events.event_pk,
  all_events.event_date,
  all_events.event_datetime,
  all_events.source_table,
  all_events.nest_id,
  all_events.gps_id,
  all_events.gps_point,
  all_events.ring_key,
  all_events.flag_code,
  all_events.capture_status,
  all_events.nest_id_source,
  all_events.source_rank,
    CASE
      WHEN all_events.ring_key IS NOT NULL
       AND all_events.is_unresolved_identity = 0
      THEN CONCAT('ring:', all_events.ring_key)
    ELSE CONCAT(
      LOWER(all_events.source_table),
      ':',
      all_events.event_pk
    )
  END AS event_identity_key,
  all_events.is_unresolved_identity,
  all_events.is_known_dead,
  all_events.has_flagged_capture
FROM all_events;

ALTER TABLE tmp_todo_chick_encounters
  ADD INDEX idx_tmp_todo_chick_encounter_nest_date
    (nest_id, event_date),
  ADD INDEX idx_tmp_todo_chick_encounter_ring
    (ring_key);

/*
  Preserve the canonical live age-C evidence needed by the brood-closure
  rule before the wider encounter table is released. Only existence by brood
  and date matters for the 21-35 day window, so this compact table avoids
  repeating the expensive direct/ring/GPS/family association graph later.
  A live CAPTURES F/R/C row remains live evidence even if another identity
  record later marks the same chick as dead. Resightings use the canonical
  known-dead flag, except that a ring-linked event dated before the recorded
  death remains historical live evidence; same-day and post-death events remain
  conservative. Ringless direct nest-linked resightings remain valid.
*/
CREATE TEMPORARY TABLE tmp_todo_closure_live_chick_encounters AS
SELECT DISTINCT
  encounters.nest_id,
  encounters.event_date
FROM tmp_todo_chick_encounters encounters
WHERE encounters.nest_id IS NOT NULL
  AND encounters.event_date IS NOT NULL
  AND encounters.source_table = 'CAPTURES'
  AND UPPER(TRIM(COALESCE(encounters.capture_status, ''))) IN ('F', 'R', 'C')
UNION
SELECT DISTINCT
  encounters.nest_id,
  encounters.event_date
FROM tmp_todo_chick_encounters encounters
LEFT JOIN (
  SELECT
    ring_key,
    MAX(dead_event_datetime) AS dead_event_datetime
  FROM tmp_todo_chick_capture_targets
  WHERE ring_key IS NOT NULL
    AND is_confirmed_dead = 1
    AND dead_event_datetime IS NOT NULL
  GROUP BY ring_key
) deaths
  ON deaths.ring_key = encounters.ring_key
WHERE encounters.nest_id IS NOT NULL
  AND encounters.event_date IS NOT NULL
  AND encounters.source_table = 'RESIGHTINGS'
  AND (
    encounters.ring_key IS NULL
    OR deaths.ring_key IS NULL
    OR (
      COALESCE(encounters.is_known_dead, 0) = 1
      AND encounters.event_date < DATE(deaths.dead_event_datetime)
    )
    OR COALESCE(encounters.is_known_dead, 0) = 0
  );

ALTER TABLE tmp_todo_closure_live_chick_encounters
  ADD PRIMARY KEY (nest_id, event_date);


/*
  This is the only latest age-C encounter calculation. Same-date capture
  rows suppress duplicate ring-identical resightings, but ringless and
  differently ringed resightings remain visible. The output deliberately
  distinguishes live identities, flagged identities, unflagged identities,
  known deaths, and unresolved identities so no downstream branch can treat
  an unknown encounter as zero work.
*/
CREATE TEMPORARY TABLE tmp_todo_chick_latest_encounter_context AS
WITH latest_dates AS (
  SELECT
    events.nest_id,
    MAX(events.event_date) AS latest_encounter_date
  FROM tmp_todo_chick_encounters events
  JOIN (
    SELECT value AS reference_date
    FROM FIELD_2026_BADOatNZ.settings
    WHERE variable = 'reference_date'
      AND value IS NOT NULL
  ) settings
    ON events.event_date <= settings.reference_date
  GROUP BY events.nest_id
), latest_events AS (
  SELECT events.*
  FROM tmp_todo_chick_encounters events
  JOIN latest_dates latest
    ON latest.nest_id = events.nest_id
   AND latest.latest_encounter_date = events.event_date
), latest_capture_rings AS (
  SELECT DISTINCT
    events.nest_id,
    events.event_date AS capture_date,
    events.ring_key
  FROM latest_events events
  WHERE events.source_table = 'CAPTURES'
    AND events.ring_key IS NOT NULL
), selected_latest_events AS (
  SELECT events.*
  FROM latest_events events
  WHERE events.source_table = 'CAPTURES'
     OR events.ring_key IS NULL
     OR events.is_unresolved_identity = 1
     OR NOT EXISTS (
       SELECT 1
       FROM latest_capture_rings captures
       WHERE captures.nest_id = events.nest_id
         AND captures.capture_date = events.event_date
         AND captures.ring_key = events.ring_key
     )
), summary AS (
  SELECT
    events.nest_id,
    MIN(events.event_date) AS latest_encounter_date,
    MAX(events.event_datetime) AS latest_encounter_datetime,
    COUNT(DISTINCT CASE
      WHEN events.is_known_dead = 0 THEN events.event_identity_key
    END) AS latest_encounter_count,
    COUNT(DISTINCT CASE
      WHEN events.is_known_dead = 0
       AND events.ring_key IS NOT NULL
       AND events.has_flagged_capture = 1
      THEN events.ring_key
    END) AS latest_encounter_flagged_count,
    COUNT(DISTINCT CASE
      WHEN events.is_known_dead = 0
       AND (
         events.ring_key IS NULL
         OR events.has_flagged_capture = 0
       )
      THEN events.event_identity_key
    END) AS latest_encounter_unflagged_count,
    COUNT(DISTINCT CASE
      WHEN events.is_unresolved_identity = 1
      THEN events.event_identity_key
    END) AS latest_encounter_unresolved_count,
    COUNT(DISTINCT CASE
      WHEN events.is_known_dead = 1
      THEN events.event_identity_key
    END) AS latest_encounter_known_dead_count,
    MAX(CASE
      WHEN events.is_unresolved_identity = 1
        OR events.is_known_dead = 1
      THEN 1
      ELSE 0
    END) AS latest_encounter_is_conservative,
    MAX(CASE
      WHEN events.is_unresolved_identity = 1
        OR events.is_known_dead = 1
      THEN 1
      ELSE 0
    END) AS latest_encounter_is_fallback,
    CASE
      WHEN COUNT(DISTINCT CASE
        WHEN events.is_known_dead = 0 THEN events.event_identity_key
      END) = 0
      THEN 'unavailable'
      WHEN MAX(CASE
        WHEN events.is_unresolved_identity = 1
          OR events.is_known_dead = 1
        THEN 1
        ELSE 0
      END) = 1
      THEN 'conservative'
      ELSE 'available'
    END AS latest_encounter_availability,
    GROUP_CONCAT(
      DISTINCT CASE
        WHEN events.is_known_dead = 0 THEN events.ring_key
      END
      ORDER BY events.ring_key
      SEPARATOR ', '
    ) AS latest_encounter_ring_list,
    GROUP_CONCAT(DISTINCT events.source_table ORDER BY events.source_table SEPARATOR ', ') AS latest_encounter_source,
    CASE
      WHEN MAX(CASE
        WHEN events.is_unresolved_identity = 1
          OR events.is_known_dead = 1
        THEN 1
        ELSE 0
      END) = 1
      THEN 'gps_family_with_unresolved_or_dead_identity'
      ELSE 'gps_family_resolved_identity'
    END AS latest_encounter_provenance
  FROM selected_latest_events events
  GROUP BY events.nest_id
)
SELECT
  summary.*,
  settings.reference_date
FROM summary
JOIN (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
) settings;

ALTER TABLE tmp_todo_chick_latest_encounter_context
  ADD INDEX idx_tmp_todo_chick_latest_nest
    (nest_id);


CREATE TEMPORARY TABLE tmp_todo_chick_capture_context AS
WITH context_units AS (
  SELECT nest_id
  FROM tmp_todo_chick_capture_context_base
  UNION
  SELECT nest_id
  FROM tmp_todo_chick_latest_encounter_context
)
SELECT
  context_units.nest_id,
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
FROM context_units
LEFT JOIN tmp_todo_chick_capture_context_base base
  ON base.nest_id = context_units.nest_id
LEFT JOIN tmp_todo_chick_latest_encounter_context latest
  ON latest.nest_id = context_units.nest_id;

SELECT 'TODO_REFRESH_STAGE|chick_capture_context' AS refresh_stage;

/*
  Materialize the shared chick-capture aggregate after the staged parent
  boundary is active. The temporary latest-encounter input consumes the
  same-occasion parent/chick resolver, so doing this earlier would expand the
  live ADULT_PARENT_STATUS graph before the parent BUILD was available.
*/
CREATE TABLE FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD (
  nest_id VARCHAR(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NULL,
  n_chick_captures BIGINT NULL,
  n_captured_chick_rings BIGINT NULL,
  n_flagged_chick_rings BIGINT NULL,
  n_unringed_chick_captures BIGINT NULL,
  n_dead_chick_rings BIGINT NULL,
  n_active_chick_rings BIGINT NULL,
  n_active_flagged_chick_rings BIGINT NULL,
  n_active_chick_captures BIGINT NULL,
  n_unresolved_dead_chick_events BIGINT NULL,
  observed_brood_size BIGINT NULL,
  latest_brood_count_date DATE NULL,
  n_deaths_after_latest_brood_count BIGINT NULL,
  n_operational_brood_size BIGINT NULL,
  operational_brood_size_source VARCHAR(64) NULL,
  latest_encounter_date DATE NULL,
  latest_encounter_datetime DATETIME NULL,
  latest_encounter_count BIGINT NULL,
  latest_encounter_flagged_count BIGINT NULL,
  latest_encounter_unflagged_count BIGINT NULL,
  latest_encounter_unresolved_count BIGINT NULL,
  latest_encounter_known_dead_count BIGINT NULL,
  latest_encounter_is_conservative TINYINT NULL,
  latest_encounter_is_fallback TINYINT NULL,
  latest_encounter_availability VARCHAR(16) NULL,
  latest_encounter_ring_list LONGTEXT NULL,
  latest_encounter_source VARCHAR(64) NULL,
  latest_encounter_provenance VARCHAR(128) NULL,
  INDEX idx_todo_chick_capture_context_nest (nest_id)
);

CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT
LIKE FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD;

INSERT INTO FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD (
  nest_id,
  n_chick_captures,
  n_captured_chick_rings,
  n_flagged_chick_rings,
  n_unringed_chick_captures,
  n_dead_chick_rings,
  n_active_chick_rings,
  n_active_flagged_chick_rings,
  n_active_chick_captures,
  n_unresolved_dead_chick_events,
  observed_brood_size,
  latest_brood_count_date,
  n_deaths_after_latest_brood_count,
  n_operational_brood_size,
  operational_brood_size_source,
  latest_encounter_date,
  latest_encounter_datetime,
  latest_encounter_count,
  latest_encounter_flagged_count,
  latest_encounter_unflagged_count,
  latest_encounter_unresolved_count,
  latest_encounter_known_dead_count,
  latest_encounter_is_conservative,
  latest_encounter_is_fallback,
  latest_encounter_availability,
  latest_encounter_ring_list,
  latest_encounter_source,
  latest_encounter_provenance
)
SELECT
  nest_id,
  n_chick_captures,
  n_captured_chick_rings,
  n_flagged_chick_rings,
  n_unringed_chick_captures,
  n_dead_chick_rings,
  n_active_chick_rings,
  n_active_flagged_chick_rings,
  n_active_chick_captures,
  n_unresolved_dead_chick_events,
  observed_brood_size,
  latest_brood_count_date,
  n_deaths_after_latest_brood_count,
  n_operational_brood_size,
  operational_brood_size_source,
  latest_encounter_date,
  latest_encounter_datetime,
  latest_encounter_count,
  latest_encounter_flagged_count,
  latest_encounter_unflagged_count,
  latest_encounter_unresolved_count,
  latest_encounter_known_dead_count,
  latest_encounter_is_conservative,
  latest_encounter_is_fallback,
  latest_encounter_availability,
  latest_encounter_ring_list,
  latest_encounter_source,
  latest_encounter_provenance
FROM tmp_todo_chick_capture_context;

/* Feed all downstream task branches from the completed chick aggregate. */
CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT_BUILD;

DROP TEMPORARY TABLE tmp_todo_chick_capture_context;
DROP TEMPORARY TABLE tmp_todo_chick_latest_encounter_context;
DROP TEMPORARY TABLE tmp_todo_chick_encounters;


SELECT 'TODO_REFRESH_STAGE|hiding_spot_photos' AS refresh_stage;

/*
  Keep the published H-photo pointer unchanged while this refresh runs. The
  full refresh is supported as one MariaDB client session (the app worker and
  a single Adminer multi-statement execution both satisfy this); the temporary
  input below is deliberately connection-local and is never published.
*/
CREATE TABLE FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD (
  nest_id VARCHAR(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NULL,
  n_hiding_spot_photos BIGINT NULL,
  INDEX idx_todo_hiding_spot_photo_context_nest (nest_id)
);

CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT
LIKE FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT;

CREATE TEMPORARY TABLE tmp_todo_hiding_photo_targets (
  nest_id VARCHAR(8) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NULL,
  ring_key VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NULL,
  is_active_target TINYINT NULL,
  INDEX idx_tmp_todo_hiding_targets_nest_ring (nest_id, ring_key)
);

INSERT INTO tmp_todo_hiding_photo_targets (
  nest_id,
  ring_key,
  is_active_target
)
SELECT
  target.nest_id,
  target.ring_key,
  target.is_active_target
FROM tmp_todo_chick_capture_targets target
WHERE target.is_active_target = 1;

/*
  This is the canonical H-photo calculation. H rows use the global resolver's
  direct, same-occasion-adult, and prior-ring-capture outcomes. The separate
  authoritative-parent S10 fallback is intentionally not part of this stage:
  valid H rows already carry an explicit nest_id, while the historical blank-ID
  cases remain covered by the resolver's canonical ring-capture path. Site/date/
  GPS/photo predicates, ambiguity exclusions, and distinct active sibling-ring
  counting are intentionally preserved.
*/
INSERT INTO FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD (
  nest_id,
  n_hiding_spot_photos
)
WITH sr AS (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
), h_photo_associations AS (
  SELECT
    h.resighting_pk,
    h.ring,
    h.resolved_nest_id,
    h.association_method
  FROM FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h
  WHERE h.resolved_nest_id IS NOT NULL
    AND h.association_method IN (
      'direct',
      'same_occasion_adult',
      'ring_capture'
    )
)
SELECT
  h.resolved_nest_id AS nest_id,
  COUNT(DISTINCT target.ring_key) AS n_hiding_spot_photos
FROM h_photo_associations h
JOIN FIELD_2026_BADOatNZ.RESIGHTINGS r
  ON r.pk = h.resighting_pk
JOIN tmp_todo_hiding_photo_targets target
  ON target.nest_id = h.resolved_nest_id
 AND target.ring_key = REPLACE(UPPER(TRIM(h.ring)), '-', '')
 AND target.is_active_target = 1
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

DROP TEMPORARY TABLE IF EXISTS tmp_todo_hiding_photo_targets;

SELECT 'TODO_REFRESH_STAGE|brood_closure' AS refresh_stage;

/*
  Build the compact published brood-closure status after the authoritative
  parent layer is available and before task rows are materialized.  This is
  the production form of the audit protocol: it keeps the expensive identity,
  history, and nest-GPS work inside one refresh session, then publishes only
  one small status row per anchored brood.

  The spatial check is deliberately restricted to a later nest already linked
  to a former parent by the corrected parent-evidence hierarchy.  A nearby
  nest belonging to another pair cannot suppress a brood by itself.
*/
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_broods;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_identities_raw;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_identities;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_old_proof;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_events;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_parent_summary;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_later_raw;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_nest_locations;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_later_summary;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_later_pairs;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_later_best;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_candidates;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_success;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_reactivation;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_age_window;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_age_candidates;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_age_reactivation;
DROP TEMPORARY TABLE IF EXISTS tmp_todo_closure_selected_candidates;

CREATE TEMPORARY TABLE tmp_todo_closure_broods AS
SELECT
  CONVERT(b.nest_id USING utf8mb4) COLLATE utf8mb4_uca1400_ai_ci AS brood_id,
  b.is_negative_brood,
  b.discovery_date,
  b.hatch_evidence_date,
  COALESCE(b.hatch_evidence_date, b.discovery_date) AS anchor_date,
  CASE
    WHEN b.is_negative_brood = 1
     AND b.discovery_date IS NOT NULL
    THEN b.discovery_date
    WHEN COALESCE(b.is_negative_brood, 0) = 0
     AND b.has_hatch_evidence = 1
     AND b.hatch_evidence_date IS NOT NULL
    THEN b.hatch_evidence_date
    ELSE NULL
  END AS age_rule_anchor_date,
  CASE
    WHEN b.is_negative_brood = 1
     AND b.discovery_date IS NOT NULL
    THEN 1
    WHEN COALESCE(b.is_negative_brood, 0) = 0
     AND b.has_hatch_evidence = 1
     AND b.hatch_evidence_date IS NOT NULL
    THEN 1
    ELSE 0
  END AS age_rule_eligible,
  b.reference_date,
  DATEDIFF(
    b.reference_date,
    COALESCE(b.hatch_evidence_date, b.discovery_date)
  ) AS age_days
FROM FIELD_2026_BADOatNZ.TODO_BROOD_CONTEXT_SNAPSHOT_BUILD b
WHERE b.reference_date = (
    SELECT value
    FROM FIELD_2026_BADOatNZ.settings
    WHERE variable = 'reference_date'
      AND value IS NOT NULL
    LIMIT 1
  )
  AND (b.is_negative_brood = 1 OR b.has_hatch_evidence = 1)
  AND COALESCE(b.hatch_evidence_date, b.discovery_date) IS NOT NULL;

ALTER TABLE tmp_todo_closure_broods
  ADD PRIMARY KEY (brood_id),
  ADD INDEX idx_todo_closure_brood_anchor (anchor_date);

CREATE TEMPORARY TABLE tmp_todo_closure_identities_raw AS
SELECT
  b.brood_id,
  a.sex,
  a.identity_key,
  'high' AS identity_confidence,
  3 AS confidence_rank
FROM tmp_todo_closure_broods b
JOIN tmp_todo_closure_parent_associations a
  ON CONVERT(a.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(b.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND a.association_selected = 1
 AND a.association_ambiguous = 0
 AND a.sex IN ('M', 'F')
 AND a.identity_key IS NOT NULL
 AND a.identity_key NOT LIKE 'xx:%'
UNION
SELECT DISTINCT
  b.brood_id,
  m.sex,
  m.identity_key,
  'medium' AS identity_confidence,
  2 AS confidence_rank
FROM tmp_todo_closure_broods b
JOIN tmp_todo_closure_identity_matches m
  ON CONVERT(m.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(b.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND m.sex IN ('M', 'F')
 AND m.is_ambiguous_match = 0
 AND COALESCE(m.n_candidate_identities, 0) = 1
 AND m.association_evidence_eligible = 1
 AND m.identity_key IS NOT NULL
 AND m.identity_key NOT LIKE 'xx:%';

CREATE TEMPORARY TABLE tmp_todo_closure_identities AS
SELECT DISTINCT raw.*
FROM tmp_todo_closure_identities_raw raw
WHERE (
    raw.confidence_rank = 3
    AND EXISTS (
      SELECT 1
      FROM tmp_todo_closure_identities_raw high
      WHERE high.brood_id = raw.brood_id
        AND high.sex = raw.sex
        AND high.confidence_rank = 3
    )
  )
  OR (
    raw.confidence_rank = 2
    AND NOT EXISTS (
      SELECT 1
      FROM tmp_todo_closure_identities_raw high
      WHERE high.brood_id = raw.brood_id
        AND high.sex = raw.sex
        AND high.confidence_rank = 3
    )
  );

ALTER TABLE tmp_todo_closure_identities
  ADD INDEX idx_todo_closure_identity_brood_sex (brood_id, sex),
  ADD INDEX idx_todo_closure_identity_key (identity_key);

CREATE TEMPORARY TABLE tmp_todo_closure_old_proof AS
SELECT
  identities.brood_id,
  identities.sex,
  identities.identity_key,
  MIN(DATE(association.association_evidence_datetime))
    AS old_association_proof_date
FROM tmp_todo_closure_identities identities
JOIN tmp_todo_closure_parent_associations association
  ON CONVERT(association.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(identities.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND association.sex = identities.sex
 AND association.identity_key = identities.identity_key
 AND association.association_selected = 1
 AND association.association_ambiguous = 0
 AND association.association_evidence_datetime IS NOT NULL
GROUP BY identities.brood_id, identities.sex, identities.identity_key;

/*
  The two-parent fallback may use two distinct, uniquely matched medium
  identities when neither parent has a selected high-confidence association.
  Preserve the old-event date for that route without weakening the
  high-confidence single-parent route above.  The old event is still required
  to be eligible and unambiguous; it is not an association supplied by a
  nearby nest or by the later attempt.
*/
INSERT INTO tmp_todo_closure_old_proof (
  brood_id,
  sex,
  identity_key,
  old_association_proof_date
)
SELECT
  identities.brood_id,
  identities.sex,
  identities.identity_key,
  MIN(m.observation_date) AS old_association_proof_date
FROM tmp_todo_closure_identities identities
JOIN tmp_todo_closure_identity_matches m
  ON CONVERT(m.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(identities.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND m.sex = identities.sex
 AND m.identity_key = identities.identity_key
 AND m.is_ambiguous_match = 0
 AND COALESCE(m.n_candidate_identities, 0) = 1
 AND m.association_evidence_eligible = 1
 AND m.observation_date IS NOT NULL
WHERE identities.identity_confidence = 'medium'
GROUP BY identities.brood_id, identities.sex, identities.identity_key;

ALTER TABLE tmp_todo_closure_old_proof
  ADD INDEX idx_todo_closure_old_proof_identity
    (brood_id, sex, identity_key),
  ADD INDEX idx_todo_closure_old_proof_date
    (brood_id, old_association_proof_date);

CREATE TEMPORARY TABLE tmp_todo_closure_events AS
SELECT
  b.brood_id,
  i.sex,
  i.identity_key,
  i.identity_confidence,
  m.resighting_pk,
  m.observation_date,
  m.nest_id AS observed_nest_id,
  CASE WHEN UPPER(TRIM(COALESCE(m.behav, ''))) REGEXP
    '(^|[,[:space:]])(BC|FC|AC)([,[:space:]]|$)'
    THEN 1 ELSE 0 END AS has_positive_brood_behaviour,
  CASE WHEN UPPER(TRIM(COALESCE(m.behav, ''))) REGEXP
    '(^|[,[:space:]])(IN|NM|SC)([,[:space:]]|$)'
    THEN 1 ELSE 0 END AS has_nest_restart_behaviour,
  CASE WHEN UPPER(TRIM(COALESCE(m.behav, ''))) REGEXP
    '(^|[,[:space:]])(FA|FM|FF|RS|LF|AT|FT|OB)([,[:space:]]|$)'
    THEN 1 ELSE 0 END AS has_strong_negative_behaviour,
  CASE WHEN UPPER(TRIM(COALESCE(m.behav, ''))) REGEXP
    '(^|[,[:space:]])BW([,[:space:]]|$)'
    THEN 1 ELSE 0 END AS has_bw_behaviour
FROM tmp_todo_closure_broods b
JOIN tmp_todo_closure_identities i
  ON i.brood_id = b.brood_id
JOIN tmp_todo_closure_identity_matches m
  ON m.identity_key = i.identity_key
 AND m.sex = i.sex
 AND m.is_ambiguous_match = 0
 AND m.association_evidence_eligible = 1
 AND m.identity_key NOT LIKE 'xx:%'
 AND m.observation_date > b.anchor_date
 AND m.observation_date <= b.reference_date;

ALTER TABLE tmp_todo_closure_events
  ADD INDEX idx_todo_closure_event_brood (brood_id),
  ADD INDEX idx_todo_closure_event_brood_date (brood_id, observation_date);

/*
  Existing high-confidence BC/FC/AC observations are valid live brood
  evidence even when they arrive through the adult identity-match layer
  rather than as a separate chick event. Add them to the compact date index
  used by the age-window rule without duplicating the identity graph.
*/
INSERT IGNORE INTO tmp_todo_closure_live_chick_encounters (nest_id, event_date)
SELECT DISTINCT
  events.brood_id,
  events.observation_date
FROM tmp_todo_closure_events events
WHERE events.identity_confidence = 'high'
  AND events.observed_nest_id = events.brood_id
  AND events.has_positive_brood_behaviour = 1
  AND events.observation_date IS NOT NULL;

/*
  Apply the one-time age rule independently of the existing closure evidence.
  The inclusive day-21 through day-35 window is permanent evidence: one live
  encounter anywhere in that window prevents this particular trigger. When
  no such encounter exists, the closure candidate is first eligible on day
  36. A live encounter on or after that date is handled by the separate age
  reactivation stage below.

  Positive broods qualify only when hatch evidence supplies the age anchor.
  Negative broods use discovery date as their established age proxy. The
  existing anchor_date remains unchanged for renesting and two-by-two logic.
*/
CREATE TEMPORARY TABLE tmp_todo_closure_age_window AS
SELECT
  b.brood_id,
  b.reference_date,
  b.age_rule_anchor_date,
  DATE_ADD(b.age_rule_anchor_date, INTERVAL 36 DAY)
    AS closure_candidate_date,
  DATEDIFF(b.reference_date, b.age_rule_anchor_date) AS age_rule_days
FROM tmp_todo_closure_broods b
WHERE b.age_rule_eligible = 1
  AND DATEDIFF(b.reference_date, b.age_rule_anchor_date) >= 36
  AND NOT EXISTS (
    SELECT 1
    FROM tmp_todo_closure_live_chick_encounters encounters
    WHERE CONVERT(encounters.nest_id USING utf8mb4)
            COLLATE utf8mb4_general_ci
        = CONVERT(b.brood_id USING utf8mb4)
            COLLATE utf8mb4_general_ci
      AND encounters.event_date BETWEEN
        DATE_ADD(b.age_rule_anchor_date, INTERVAL 21 DAY)
        AND DATE_ADD(b.age_rule_anchor_date, INTERVAL 35 DAY)
  );

ALTER TABLE tmp_todo_closure_age_window
  ADD PRIMARY KEY (brood_id),
  ADD INDEX idx_todo_closure_age_window_date (closure_candidate_date);

CREATE TEMPORARY TABLE tmp_todo_closure_parent_summary AS
SELECT
  e.brood_id,
  MAX(CASE WHEN e.sex = 'M' AND e.identity_confidence = 'high'
    THEN 1 ELSE 0 END) AS M_identity_high,
  MAX(CASE WHEN e.sex = 'F' AND e.identity_confidence = 'high'
    THEN 1 ELSE 0 END) AS F_identity_high,
  COUNT(DISTINCT CASE
    WHEN e.sex = 'M'
     AND e.observed_nest_id = e.brood_id
     AND e.has_positive_brood_behaviour = 0
     AND e.has_nest_restart_behaviour = 0
     AND (e.has_strong_negative_behaviour = 1 OR e.has_bw_behaviour = 1)
    THEN e.observation_date END
  ) AS M_negative_observation_dates,
  COUNT(DISTINCT CASE
    WHEN e.sex = 'F'
     AND e.observed_nest_id = e.brood_id
     AND e.has_positive_brood_behaviour = 0
     AND e.has_nest_restart_behaviour = 0
     AND (e.has_strong_negative_behaviour = 1 OR e.has_bw_behaviour = 1)
    THEN e.observation_date END
  ) AS F_negative_observation_dates,
  SUM(CASE
    WHEN e.sex = 'M'
     AND e.observed_nest_id = e.brood_id
     AND e.has_positive_brood_behaviour = 0
     AND e.has_nest_restart_behaviour = 0
     AND e.has_strong_negative_behaviour = 1
    THEN 1 ELSE 0 END
  ) AS M_strong_negative_count,
  SUM(CASE
    WHEN e.sex = 'F'
     AND e.observed_nest_id = e.brood_id
     AND e.has_positive_brood_behaviour = 0
     AND e.has_nest_restart_behaviour = 0
     AND e.has_strong_negative_behaviour = 1
    THEN 1 ELSE 0 END
  ) AS F_strong_negative_count,
  MAX(CASE
    WHEN e.observed_nest_id = e.brood_id
     AND e.has_positive_brood_behaviour = 1
    THEN e.observation_date END
  ) AS latest_positive_brood_date,
  MAX(CASE
    WHEN e.sex = 'M'
     AND e.observed_nest_id = e.brood_id
     AND e.has_positive_brood_behaviour = 0
     AND e.has_nest_restart_behaviour = 0
     AND (e.has_strong_negative_behaviour = 1 OR e.has_bw_behaviour = 1)
    THEN e.observation_date END
  ) AS M_last_negative_date,
  MAX(CASE
    WHEN e.sex = 'F'
     AND e.observed_nest_id = e.brood_id
     AND e.has_positive_brood_behaviour = 0
     AND e.has_nest_restart_behaviour = 0
     AND (e.has_strong_negative_behaviour = 1 OR e.has_bw_behaviour = 1)
    THEN e.observation_date END
  ) AS F_last_negative_date
FROM tmp_todo_closure_events e
GROUP BY e.brood_id;

CREATE TEMPORARY TABLE tmp_todo_closure_later_raw AS
SELECT
  b.brood_id,
  a.sex AS later_parent_sex,
  a.identity_key AS later_parent_identity,
  a.nest_id AS later_nest_id,
  GREATEST(
    MIN(n.date),
    DATE(a.association_evidence_datetime),
    old_proof.old_association_proof_date
  )
    AS later_nest_date,
  'authoritative_selected' AS evidence_type
FROM tmp_todo_closure_broods b
JOIN tmp_todo_closure_identities prior
  ON prior.brood_id = b.brood_id
 AND prior.identity_confidence = 'high'
JOIN tmp_todo_closure_parent_associations a
  ON a.identity_key = prior.identity_key
 AND a.sex = prior.sex
 AND a.association_selected = 1
 AND a.association_ambiguous = 0
 AND a.identity_key NOT LIKE 'xx:%'
 AND a.association_evidence_datetime IS NOT NULL
 AND a.nest_id IS NOT NULL
 AND TRIM(a.nest_id) <> ''
 AND UPPER(TRIM(a.nest_id)) <> 'NO_NEST'
 AND LEFT(TRIM(a.nest_id), 1) <> '-'
 AND CONVERT(a.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     <> CONVERT(b.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
JOIN tmp_todo_closure_old_proof old_proof
  ON old_proof.brood_id = b.brood_id
 AND old_proof.sex = prior.sex
 AND old_proof.identity_key = prior.identity_key
JOIN FIELD_2026_BADOatNZ.NESTS n
  ON CONVERT(n.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(a.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
 AND UPPER(TRIM(COALESCE(n.nest_state, ''))) IN ('S', 'F', 'I')
 AND n.date > b.anchor_date
 AND n.date <= b.reference_date
 AND NOT EXISTS (
   SELECT 1
   FROM FIELD_2026_BADOatNZ.NESTS earlier_nest
   WHERE CONVERT(earlier_nest.nest_id USING utf8mb4)
         COLLATE utf8mb4_general_ci
         = CONVERT(n.nest_id USING utf8mb4)
           COLLATE utf8mb4_general_ci
     AND UPPER(TRIM(COALESCE(earlier_nest.site, ''))) = 'CR'
     AND earlier_nest.date <= b.anchor_date
 )
GROUP BY b.brood_id, a.sex, a.identity_key, a.nest_id
UNION
SELECT
  b.brood_id,
  m.sex AS later_parent_sex,
  m.identity_key AS later_parent_identity,
  m.nest_id AS later_nest_id,
  GREATEST(
    MIN(n.date),
    MIN(m.observation_date),
    old_proof.old_association_proof_date
  ) AS later_nest_date,
  'identity_match' AS evidence_type
FROM tmp_todo_closure_broods b
JOIN tmp_todo_closure_identities prior
  ON prior.brood_id = b.brood_id
JOIN tmp_todo_closure_identity_matches m
  ON m.identity_key = prior.identity_key
 AND m.sex = prior.sex
 AND m.is_ambiguous_match = 0
 AND COALESCE(m.n_candidate_identities, 0) = 1
 AND m.association_evidence_eligible = 1
 AND m.identity_key NOT LIKE 'xx:%'
 AND m.nest_id IS NOT NULL
 AND TRIM(m.nest_id) <> ''
 AND UPPER(TRIM(m.nest_id)) <> 'NO_NEST'
 AND LEFT(TRIM(m.nest_id), 1) <> '-'
 AND CONVERT(m.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     <> CONVERT(b.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND m.observation_date > b.anchor_date
 AND m.observation_date <= b.reference_date
JOIN tmp_todo_closure_old_proof old_proof
  ON old_proof.brood_id = b.brood_id
 AND old_proof.sex = prior.sex
 AND old_proof.identity_key = prior.identity_key
JOIN FIELD_2026_BADOatNZ.NESTS n
  ON CONVERT(n.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(m.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
 AND UPPER(TRIM(COALESCE(n.nest_state, ''))) IN ('S', 'F', 'I')
 AND n.date > b.anchor_date
 AND n.date <= b.reference_date
 AND NOT EXISTS (
   SELECT 1
   FROM FIELD_2026_BADOatNZ.NESTS earlier_nest
   WHERE CONVERT(earlier_nest.nest_id USING utf8mb4)
         COLLATE utf8mb4_general_ci
         = CONVERT(n.nest_id USING utf8mb4)
           COLLATE utf8mb4_general_ci
     AND UPPER(TRIM(COALESCE(earlier_nest.site, ''))) = 'CR'
     AND earlier_nest.date <= b.anchor_date
 )
GROUP BY b.brood_id, m.sex, m.identity_key, m.nest_id;

CREATE TEMPORARY TABLE tmp_todo_closure_nest_locations AS
SELECT nest_id, lat, lon
FROM (
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
    ON g.gps_id = n.gps_id
   AND g.gps_point = n.gps_point
  JOIN (
    SELECT CONVERT(brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
      AS nest_id
    FROM tmp_todo_closure_broods
    UNION
    SELECT CONVERT(later_nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
    FROM tmp_todo_closure_later_raw
  ) relevant
    ON relevant.nest_id = CONVERT(n.nest_id USING utf8mb4)
      COLLATE utf8mb4_general_ci
  WHERE UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.nest_id IS NOT NULL
    AND LEFT(TRIM(n.nest_id), 1) <> '-'
    AND g.lat IS NOT NULL
    AND g.lon IS NOT NULL
) locations
WHERE row_num = 1;

/*
  A dual-parent fallback is complete only when one M and one F association
  are both available.  Pair dates therefore use the later of the two
  association dates; taking MIN(raw.later_nest_date) would allow one weaker or
  incomplete row to backdate a complete fallback route.
*/
CREATE TEMPORARY TABLE tmp_todo_closure_later_pairs AS
SELECT
  male.brood_id,
  male.later_nest_id,
  GREATEST(male.later_nest_date, female.later_nest_date) AS pair_date
FROM tmp_todo_closure_later_raw male
JOIN tmp_todo_closure_later_raw female
  ON female.brood_id = male.brood_id
 AND female.later_nest_id = male.later_nest_id
 AND female.evidence_type = 'identity_match'
 AND female.later_parent_sex = 'F'
WHERE male.evidence_type = 'identity_match'
  AND male.later_parent_sex = 'M';

CREATE TEMPORARY TABLE tmp_todo_closure_later_summary AS
SELECT
  raw.brood_id,
  raw.later_nest_id,
  CASE
    WHEN COUNT(DISTINCT CASE
      WHEN raw.evidence_type = 'authoritative_selected'
      THEN CONCAT(raw.later_parent_sex, ':', raw.later_parent_identity)
    END) >= 1
    THEN MIN(CASE
      WHEN raw.evidence_type = 'authoritative_selected'
      THEN raw.later_nest_date
    END)
    WHEN COUNT(DISTINCT raw.later_parent_sex) = 2
    THEN MIN(pairs.pair_date)
    ELSE MIN(raw.later_nest_date)
  END AS later_nest_date,
  COUNT(DISTINCT CONCAT(raw.later_parent_sex, ':', raw.later_parent_identity))
    AS later_nest_parent_count,
  COUNT(DISTINCT raw.later_parent_sex) AS later_nest_parent_sex_count,
  COUNT(DISTINCT CASE
    WHEN raw.evidence_type = 'authoritative_selected'
    THEN CONCAT(raw.later_parent_sex, ':', raw.later_parent_identity)
  END) AS later_nest_authoritative_parent_count,
  MIN(CASE
    WHEN origin.lat BETWEEN -90 AND 90
     AND origin.lon BETWEEN -180 AND 180
     AND later_location.lat BETWEEN -90 AND 90
     AND later_location.lon BETWEEN -180 AND 180
    THEN ROUND(
      6371000 * 2 * ASIN(
        SQRT(
          POW(SIN(RADIANS(later_location.lat - origin.lat) / 2), 2)
          + COS(RADIANS(origin.lat))
            * COS(RADIANS(later_location.lat))
            * POW(SIN(RADIANS(later_location.lon - origin.lon) / 2), 2)
        )
      ),
      1
    )
  END) AS nest_distance_m
FROM tmp_todo_closure_later_raw raw
LEFT JOIN tmp_todo_closure_nest_locations origin
  ON CONVERT(origin.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(raw.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
LEFT JOIN tmp_todo_closure_nest_locations later_location
  ON CONVERT(later_location.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(raw.later_nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
LEFT JOIN tmp_todo_closure_later_pairs pairs
  ON pairs.brood_id = raw.brood_id
 AND pairs.later_nest_id = raw.later_nest_id
GROUP BY raw.brood_id, raw.later_nest_id;

CREATE TEMPORARY TABLE tmp_todo_closure_later_best AS
SELECT *
FROM (
  SELECT
    later.*,
    CASE WHEN later.later_nest_authoritative_parent_count >= 1
       OR (
         later.later_nest_parent_count >= 2
         AND later.later_nest_parent_sex_count = 2
       )
      THEN 1 ELSE 0 END AS later_nest_trigger,
    CASE WHEN later.nest_distance_m <= 100 THEN 1 ELSE 0 END
      AS spatial_support_100m,
    ROW_NUMBER() OVER (
      PARTITION BY later.brood_id
      ORDER BY
        CASE WHEN later.later_nest_authoritative_parent_count >= 1
          OR (
            later.later_nest_parent_count >= 2
            AND later.later_nest_parent_sex_count = 2
          ) THEN 0 ELSE 1 END,
        later.later_nest_date,
        later.later_nest_parent_count DESC,
        later.later_nest_id
    ) AS row_num
  FROM tmp_todo_closure_later_summary later
) ranked
WHERE ranked.row_num = 1;

CREATE TEMPORARY TABLE tmp_todo_closure_candidates AS
SELECT
  b.brood_id,
  b.reference_date,
  CASE
    WHEN later.later_nest_trigger = 1 THEN later.later_nest_date
    ELSE GREATEST(parent.M_last_negative_date, parent.F_last_negative_date)
  END AS closure_candidate_date,
  CASE
    WHEN later.later_nest_trigger = 1
     AND later.later_nest_parent_count >= 2
     AND later.later_nest_parent_sex_count = 2
     AND later.spatial_support_100m = 1
    THEN 'dual-parent renesting + spatial proximity'
    WHEN later.later_nest_trigger = 1
     AND later.later_nest_parent_count >= 2
     AND later.later_nest_parent_sex_count = 2
    THEN 'dual-parent renesting trigger'
    WHEN later.later_nest_trigger = 1
     AND later.spatial_support_100m = 1
    THEN 'later nest trigger + spatial proximity'
    WHEN later.later_nest_trigger = 1
    THEN 'later nest trigger'
    ELSE 'two-by-two post-hatch non-brood evidence'
  END AS closure_reason,
  COALESCE(later.later_nest_id, NULL) AS later_nest_id,
  later.later_nest_date,
  later.later_nest_parent_count,
  later.later_nest_authoritative_parent_count,
  later.nest_distance_m,
  COALESCE(later.spatial_support_100m, 0) AS spatial_support_100m,
  CASE
    WHEN later.later_nest_trigger = 1 THEN 0
    WHEN b.age_days >= 21
     AND COALESCE(parent.M_identity_high, 0) = 1
     AND COALESCE(parent.F_identity_high, 0) = 1
     AND COALESCE(parent.M_negative_observation_dates, 0) >= 2
     AND COALESCE(parent.F_negative_observation_dates, 0) >= 2
     AND COALESCE(parent.M_strong_negative_count, 0) >= 1
     AND COALESCE(parent.F_strong_negative_count, 0) >= 1
     AND (
       parent.latest_positive_brood_date IS NULL
       OR parent.latest_positive_brood_date < LEAST(
         parent.M_last_negative_date,
         parent.F_last_negative_date
       )
     )
    THEN 1 ELSE 0
  END AS two_by_two_trigger
FROM tmp_todo_closure_broods b
LEFT JOIN tmp_todo_closure_parent_summary parent
  ON parent.brood_id = b.brood_id
LEFT JOIN tmp_todo_closure_later_best later
  ON later.brood_id = b.brood_id
WHERE later.later_nest_trigger = 1
   OR (
     b.age_days >= 21
     AND COALESCE(parent.M_identity_high, 0) = 1
     AND COALESCE(parent.F_identity_high, 0) = 1
     AND COALESCE(parent.M_negative_observation_dates, 0) >= 2
     AND COALESCE(parent.F_negative_observation_dates, 0) >= 2
     AND COALESCE(parent.M_strong_negative_count, 0) >= 1
     AND COALESCE(parent.F_strong_negative_count, 0) >= 1
     AND (
       parent.latest_positive_brood_date IS NULL
       OR parent.latest_positive_brood_date < LEAST(
         parent.M_last_negative_date,
         parent.F_last_negative_date
       )
     )
   );

/* Keep the new age route separate until each route has its own reactivation
   result. This prevents a day-20 event on an older route from vetoing a new
   day-36 age route, while a day-25 event still prevents only the age route. */
CREATE TEMPORARY TABLE tmp_todo_closure_age_candidates AS
SELECT
  age_window.brood_id,
  age_window.reference_date,
  'no live brood encounter during ages 21-35' AS closure_reason,
  age_window.closure_candidate_date,
  0 AS reactivation_evidence_count,
  0 AS would_reactivate
FROM tmp_todo_closure_age_window age_window;

ALTER TABLE tmp_todo_closure_age_candidates
  ADD PRIMARY KEY (brood_id),
  ADD INDEX idx_todo_closure_age_candidate_date (closure_candidate_date);

CREATE TEMPORARY TABLE tmp_todo_closure_reactivation AS
SELECT c.brood_id, COUNT(*) AS reactivation_evidence_count
FROM tmp_todo_closure_candidates c
JOIN FIELD_2026_BADOatNZ.CAPTURES x
  ON CONVERT(x.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(c.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND x.age = 'C'
 AND UPPER(TRIM(COALESCE(x.capture_status, ''))) IN ('F', 'R', 'C')
 AND UPPER(TRIM(COALESCE(x.site, ''))) = 'CR'
 AND x.date >= c.closure_candidate_date
 AND x.date <= c.reference_date
GROUP BY c.brood_id
UNION ALL
SELECT c.brood_id, COUNT(*)
FROM tmp_todo_closure_candidates c
JOIN FIELD_2026_BADOatNZ.RESIGHTINGS x
  ON CONVERT(x.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(c.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND x.age = 'C'
 AND UPPER(TRIM(COALESCE(x.site, ''))) = 'CR'
 AND x.date >= c.closure_candidate_date
 AND x.date <= c.reference_date
GROUP BY c.brood_id
UNION ALL
SELECT c.brood_id, COUNT(*)
FROM tmp_todo_closure_candidates c
 JOIN tmp_todo_ordinary_family_resighting_associations ordinary
  ON CONVERT(ordinary.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(c.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND ordinary.event_date >= c.closure_candidate_date
 AND ordinary.event_date <= c.reference_date
WHERE c.closure_candidate_date IS NOT NULL
GROUP BY c.brood_id
UNION ALL
SELECT c.brood_id, COUNT(*)
FROM tmp_todo_closure_candidates c
JOIN tmp_todo_chick_capture_events x
  ON CONVERT(x.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(c.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND x.nest_id_source = 'prior_ring'
 AND UPPER(TRIM(COALESCE(x.capture_status, ''))) IN ('F', 'R', 'C')
 AND x.event_date >= c.closure_candidate_date
 AND x.event_date <= c.reference_date
WHERE c.closure_candidate_date IS NOT NULL
GROUP BY c.brood_id
UNION ALL
SELECT c.brood_id, COUNT(*)
FROM tmp_todo_closure_candidates c
JOIN FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h
  ON CONVERT(h.resolved_nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(c.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
JOIN FIELD_2026_BADOatNZ.RESIGHTINGS x
  ON x.pk = h.resighting_pk
 AND x.age = 'C'
 AND UPPER(TRIM(COALESCE(x.site, ''))) = 'CR'
 AND x.date >= c.closure_candidate_date
 AND x.date <= c.reference_date
WHERE c.closure_candidate_date IS NOT NULL
GROUP BY c.brood_id
UNION ALL
SELECT c.brood_id, COUNT(*)
FROM tmp_todo_closure_candidates c
 JOIN tmp_todo_parent_chick_resighting_associations link
  ON CONVERT(link.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(c.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
JOIN FIELD_2026_BADOatNZ.RESIGHTINGS x
  ON x.pk = link.resighting_pk
 AND x.age = 'C'
 AND UPPER(TRIM(COALESCE(x.site, ''))) = 'CR'
 AND x.date >= c.closure_candidate_date
 AND x.date <= c.reference_date
WHERE c.closure_candidate_date IS NOT NULL
GROUP BY c.brood_id
UNION ALL
SELECT c.brood_id, COUNT(*)
FROM tmp_todo_closure_candidates c
JOIN FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT links
  ON CONVERT(links.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(c.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND links.capture_date >= c.closure_candidate_date
 AND links.capture_date <= c.reference_date
 AND COALESCE(links.is_dead, 0) = 0
WHERE c.closure_candidate_date IS NOT NULL
GROUP BY c.brood_id
UNION ALL
SELECT c.brood_id, COUNT(*)
FROM tmp_todo_closure_candidates c
JOIN tmp_todo_closure_events x
  ON x.brood_id = c.brood_id
 AND x.identity_confidence = 'high'
 AND CONVERT(x.observed_nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(c.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND x.has_positive_brood_behaviour = 1
 AND x.observation_date >= c.closure_candidate_date
 AND x.observation_date <= c.reference_date
GROUP BY c.brood_id;

/* The age route uses the compact canonical live evidence only. This keeps
   later encounters and high-confidence BC/FC/AC observations on or after
   day 36 as reactivation evidence without reopening the full graph. */
CREATE TEMPORARY TABLE tmp_todo_closure_age_reactivation AS
SELECT
  c.brood_id,
  COUNT(*) AS reactivation_evidence_count
FROM tmp_todo_closure_age_candidates c
JOIN tmp_todo_closure_live_chick_encounters encounters
  ON CONVERT(encounters.nest_id USING utf8mb4)
       COLLATE utf8mb4_general_ci
     = CONVERT(c.brood_id USING utf8mb4)
       COLLATE utf8mb4_general_ci
 AND encounters.event_date >= c.closure_candidate_date
 AND encounters.event_date <= c.reference_date
GROUP BY c.brood_id;

ALTER TABLE tmp_todo_closure_age_reactivation
  ADD PRIMARY KEY (brood_id);

/*
  An origin-linked age-J event resolves the whole brood. Live F/R/C evidence
  supports the existing resolution/reactivation rules, while an age-J D row is
  developmental resolution only. This is kept at event level rather than
  inferred from BROODS_LATEST's aggregate latest date, so D and unknown
  captures cannot masquerade as survival evidence.
*/
CREATE TEMPORARY TABLE tmp_todo_closure_success AS
SELECT
  b.brood_id,
  MIN(events.event_date) AS resolution_date,
  COUNT(*) AS resolution_evidence_count
FROM tmp_todo_closure_broods b
JOIN tmp_todo_juvenile_origin_events events
  ON CONVERT(events.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(b.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND events.event_date >= b.anchor_date
 AND events.event_date <= b.reference_date
GROUP BY b.brood_id;

ALTER TABLE tmp_todo_closure_success
  ADD PRIMARY KEY (brood_id);

/* Keep valid J evidence in the general reactivation audit when it occurs
   after a presumed-dead candidate, while is_resolved remains a separate
   outcome from is_presumed_dead. */
INSERT INTO tmp_todo_closure_reactivation (brood_id, reactivation_evidence_count)
SELECT
  c.brood_id,
  COUNT(*)
FROM tmp_todo_closure_candidates c
JOIN tmp_todo_juvenile_origin_events events
  ON CONVERT(events.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(c.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
 AND events.event_date >= c.closure_candidate_date
 AND events.event_date <= c.reference_date
 AND events.association_method <> 'developmental_age_j'
WHERE c.closure_candidate_date IS NOT NULL
GROUP BY c.brood_id;

/*
  Select one route only after old-route and age-route reactivation have been
  calculated independently. An old route that survives without reactivation
  retains precedence and its original chronology. The age route may replace
  an old route only after that old route has its own reactivation evidence; an
  age-route encounter cannot retroactively cancel a later independent
  renesting/two-by-two candidate. This avoids collapsing distinct causes into
  one brood-level counter too early.
*/
CREATE TEMPORARY TABLE tmp_todo_closure_selected_candidates AS
WITH old_reactivation AS (
  SELECT
    brood_id,
    SUM(reactivation_evidence_count) AS reactivation_evidence_count
  FROM tmp_todo_closure_reactivation
  GROUP BY brood_id
), route_inputs AS (
SELECT
  b.brood_id,
  b.reference_date,
  old_candidate.closure_reason AS old_closure_reason,
  old_candidate.closure_candidate_date AS old_closure_candidate_date,
  old_candidate.later_nest_id AS old_later_nest_id,
  old_candidate.later_nest_date AS old_later_nest_date,
  old_candidate.later_nest_parent_count AS old_later_nest_parent_count,
  old_candidate.later_nest_authoritative_parent_count
    AS old_later_nest_authoritative_parent_count,
  old_candidate.nest_distance_m AS old_nest_distance_m,
  old_candidate.spatial_support_100m AS old_spatial_support_100m,
  age_candidate.closure_reason AS age_closure_reason,
  age_candidate.closure_candidate_date AS age_closure_candidate_date,
  COALESCE(old_reactivation.reactivation_evidence_count, 0)
    AS old_reactivation_count,
  COALESCE(age_reactivation.reactivation_evidence_count, 0)
    AS age_reactivation_count,
  CASE
    WHEN age_candidate.brood_id IS NOT NULL
     AND (
       old_candidate.brood_id IS NULL
       OR COALESCE(old_reactivation.reactivation_evidence_count, 0) > 0
     )
    THEN 'age'
    ELSE 'old'
  END AS selected_route
FROM tmp_todo_closure_broods b
LEFT JOIN tmp_todo_closure_candidates old_candidate
  ON old_candidate.brood_id = b.brood_id
LEFT JOIN old_reactivation
  ON old_reactivation.brood_id = b.brood_id
LEFT JOIN tmp_todo_closure_age_candidates age_candidate
  ON age_candidate.brood_id = b.brood_id
LEFT JOIN tmp_todo_closure_age_reactivation age_reactivation
  ON age_reactivation.brood_id = b.brood_id
WHERE old_candidate.brood_id IS NOT NULL
   OR age_candidate.brood_id IS NOT NULL
)
SELECT
  route_inputs.brood_id,
  route_inputs.reference_date,
  CASE
    WHEN route_inputs.selected_route = 'age'
    THEN route_inputs.age_closure_reason
    ELSE route_inputs.old_closure_reason
  END AS closure_reason,
  CASE
    WHEN route_inputs.selected_route = 'age'
    THEN route_inputs.age_closure_candidate_date
    ELSE route_inputs.old_closure_candidate_date
  END AS closure_candidate_date,
  CASE
    WHEN route_inputs.selected_route = 'age'
    THEN NULL
    ELSE route_inputs.old_later_nest_id
  END AS later_nest_id,
  CASE
    WHEN route_inputs.selected_route = 'age'
    THEN NULL
    ELSE route_inputs.old_later_nest_date
  END AS later_nest_date,
  CASE
    WHEN route_inputs.selected_route = 'age'
    THEN NULL
    ELSE route_inputs.old_later_nest_parent_count
  END AS later_nest_parent_count,
  CASE
    WHEN route_inputs.selected_route = 'age'
    THEN NULL
    ELSE route_inputs.old_later_nest_authoritative_parent_count
  END AS later_nest_authoritative_parent_count,
  CASE
    WHEN route_inputs.selected_route = 'age'
    THEN NULL
    ELSE route_inputs.old_nest_distance_m
  END AS nest_distance_m,
  CASE
    WHEN route_inputs.selected_route = 'age'
    THEN 0
    ELSE COALESCE(route_inputs.old_spatial_support_100m, 0)
  END AS spatial_support_100m,
  CASE
    WHEN route_inputs.selected_route = 'age'
    THEN route_inputs.age_reactivation_count
    ELSE route_inputs.old_reactivation_count
  END AS reactivation_evidence_count,
  CASE
    WHEN route_inputs.selected_route = 'age'
    THEN CASE WHEN route_inputs.age_reactivation_count > 0
      THEN 1 ELSE 0 END
    ELSE CASE WHEN route_inputs.old_reactivation_count > 0
      THEN 1 ELSE 0 END
  END AS would_reactivate
FROM route_inputs;

ALTER TABLE tmp_todo_closure_selected_candidates
  ADD PRIMARY KEY (brood_id);

CREATE TABLE FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_BUILD (
  brood_id VARCHAR(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NOT NULL,
  reference_date DATE NOT NULL,
  is_presumed_dead TINYINT NOT NULL DEFAULT 0,
  is_resolved TINYINT NOT NULL DEFAULT 0,
  closure_reason VARCHAR(255) NULL,
  resolution_reason VARCHAR(255) NULL,
  resolution_date DATE NULL,
  later_nest_id VARCHAR(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NULL,
  later_nest_date DATE NULL,
  later_nest_parent_count BIGINT NULL,
  later_nest_authoritative_parent_count BIGINT NULL,
  nest_distance_m DECIMAL(10, 1) NULL,
  spatial_support_100m TINYINT NOT NULL DEFAULT 0,
  closure_candidate_date DATE NULL,
  reactivation_evidence_count BIGINT NOT NULL DEFAULT 0,
  would_reactivate TINYINT NOT NULL DEFAULT 0,
  PRIMARY KEY (reference_date, brood_id),
  INDEX idx_todo_brood_closure_build_brood (brood_id),
  INDEX idx_todo_brood_closure_build_dead (reference_date, is_presumed_dead)
);

CREATE TABLE IF NOT EXISTS FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT
LIKE FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_BUILD;

/* Upgrade the published snapshot in place without rewriting biological rows. */
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

INSERT INTO FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_BUILD (
  brood_id,
  reference_date,
  is_presumed_dead,
  is_resolved,
  closure_reason,
  resolution_reason,
  resolution_date,
  later_nest_id,
  later_nest_date,
  later_nest_parent_count,
  later_nest_authoritative_parent_count,
  nest_distance_m,
  spatial_support_100m,
  closure_candidate_date,
  reactivation_evidence_count,
  would_reactivate
)
SELECT
  b.brood_id,
  b.reference_date,
  CASE WHEN c.brood_id IS NOT NULL
      AND COALESCE(c.reactivation_evidence_count, 0) = 0
      AND s.brood_id IS NULL
    THEN 1 ELSE 0 END AS is_presumed_dead,
  CASE WHEN s.brood_id IS NOT NULL THEN 1 ELSE 0 END AS is_resolved,
  c.closure_reason,
  CASE WHEN s.brood_id IS NOT NULL
    THEN 'origin-linked age-J event'
    ELSE NULL
  END AS resolution_reason,
  s.resolution_date,
  c.later_nest_id,
  c.later_nest_date,
  c.later_nest_parent_count,
  c.later_nest_authoritative_parent_count,
  c.nest_distance_m,
  COALESCE(c.spatial_support_100m, 0),
  c.closure_candidate_date,
  COALESCE(c.reactivation_evidence_count, 0),
  CASE WHEN COALESCE(c.reactivation_evidence_count, 0) > 0
    THEN 1 ELSE 0 END
FROM tmp_todo_closure_broods b
LEFT JOIN tmp_todo_closure_selected_candidates c
  ON c.brood_id = b.brood_id
LEFT JOIN tmp_todo_closure_success s
  ON s.brood_id = b.brood_id
;

DROP TEMPORARY TABLE tmp_todo_closure_reactivation;
DROP TEMPORARY TABLE tmp_todo_closure_success;
DROP TEMPORARY TABLE tmp_todo_closure_selected_candidates;
DROP TEMPORARY TABLE tmp_todo_closure_age_reactivation;
DROP TEMPORARY TABLE tmp_todo_closure_age_candidates;
DROP TEMPORARY TABLE tmp_todo_closure_candidates;
DROP TEMPORARY TABLE tmp_todo_closure_age_window;
DROP TEMPORARY TABLE tmp_todo_closure_later_best;
DROP TEMPORARY TABLE tmp_todo_closure_later_summary;
DROP TEMPORARY TABLE tmp_todo_closure_later_pairs;
DROP TEMPORARY TABLE tmp_todo_closure_nest_locations;
DROP TEMPORARY TABLE tmp_todo_closure_later_raw;
DROP TEMPORARY TABLE tmp_todo_closure_parent_summary;
DROP TEMPORARY TABLE tmp_todo_closure_events;
DROP TEMPORARY TABLE tmp_todo_closure_identities;
DROP TEMPORARY TABLE tmp_todo_closure_identities_raw;
DROP TEMPORARY TABLE tmp_todo_closure_broods;
DROP TEMPORARY TABLE tmp_todo_closure_live_chick_encounters;
DROP TEMPORARY TABLE tmp_todo_closure_identity_matches;
DROP TEMPORARY TABLE tmp_todo_closure_parent_associations;
DROP TEMPORARY TABLE tmp_todo_parent_chick_resighting_associations;
DROP TEMPORARY TABLE tmp_todo_ordinary_family_resighting_associations;
DROP TEMPORARY TABLE tmp_todo_juvenile_origin_events;
DROP TEMPORARY TABLE tmp_todo_chick_capture_events;
DROP TEMPORARY TABLE tmp_todo_chick_capture_targets;
DROP TEMPORARY TABLE tmp_todo_chick_capture_event_status;
DROP TEMPORARY TABLE tmp_todo_chick_capture_context_base;
DROP TEMPORARY TABLE tmp_todo_raw_encounter_nest_consensus;

SELECT 'TODO_REFRESH_STAGE|task_rows' AS refresh_stage;

/*
  Build task rows while the existing TODO_LIST remains available. The full
  task calculator is a refresh-time WITH query below, rather than a live
  TODO_LIST_CALCULATE view, so views.SQL does not ask MariaDB to validate the
  complete nested task graph during DDL installation.
*/
CREATE TABLE FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT_BUILD (
  nest_id VARCHAR(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci NULL,
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
/*
  GEO history is retained for compatibility/reporting only.  It no longer
  supplies a release ceiling, sex quota, phenology deficit, or deployment
  candidate.  The bounded tag_deployment_plan below is the only new GEO-task
  selector.
*/
geo_observation_counts AS (
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
initial_clutch_status AS (
  SELECT
    p.nest_id,
    MAX(CASE
      WHEN p.calibration_match_type = 'found as incomplete' THEN 1
      ELSE 0
    END) AS found_as_incomplete,
    MAX(CASE
      WHEN p.calibration_match_type = 'stable one-egg/no increase' THEN 1
      ELSE 0
    END) AS stable_one_egg,
    MAX(CASE
      WHEN p.calibration_match_type IN (
        'found as incomplete',
        'stable one-egg/no increase'
      ) THEN 1
      ELSE 0
    END) AS processing_flotation_exempt,
    MAX(DATE_SUB(p.predicted_hatch_date, INTERVAL 26 DAY))
      AS inferred_clutch_completion_date,
    MAX(p.predicted_hatch_date) AS inferred_hatch_date
  FROM FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION p
  WHERE p.calibration_match_type IN (
    'found as incomplete',
    'complete clutch chronology',
    'stable one-egg/no increase'
  )
  GROUP BY p.nest_id
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
    CASE
      WHEN brood_last_visit.nest_id IS NOT NULL
      THEN brood_last_visit.latest_encounter_datetime
      ELSE context.last_visit_datetime
    END AS last_visit_datetime,
    CASE
      WHEN brood_last_visit.nest_id IS NOT NULL
      THEN DATEDIFF(sr.reference_date, brood_last_visit.latest_encounter_date)
      ELSE context.days_ago
    END AS days_ago,
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
    ON CONVERT(context.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(initial_clutch_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN brood_context brood_last_visit
    ON CONVERT(context.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(brood_last_visit.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
   AND brood_last_visit.reference_date = context.reference_date
   AND brood_last_visit.is_negative_brood = 0
   AND brood_last_visit.has_hatch_evidence = 1
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
    ON CONVERT(n.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(b.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
/*
  One shared flagging decision for positive and negative brood branches.
  When a canonical latest encounter is available, work is driven by the
  latest live unflagged identities. Conservative/unresolved identities keep
  work open. If no latest encounter is available, fall back to the existing
  capture-history rule rather than treating NULL counts as a closed brood.
*/
flagging_context AS (
  SELECT
    chick_captures.*,
    CASE
      WHEN chick_captures.latest_encounter_availability IN (
        'available', 'conservative'
      )
       AND chick_captures.latest_encounter_count IS NOT NULL
      THEN CASE
        WHEN COALESCE(chick_captures.latest_encounter_unflagged_count, 0) > 0
          OR COALESCE(chick_captures.latest_encounter_unresolved_count, 0) > 0
        THEN 1
        ELSE 0
      END
      WHEN COALESCE(chick_captures.n_operational_brood_size, 0)
             > COALESCE(chick_captures.n_active_flagged_chick_rings, 0)
      THEN 1
      ELSE 0
    END AS flagging_work_pending,
    CASE
      WHEN chick_captures.latest_encounter_availability IN (
        'available', 'conservative'
      )
       AND chick_captures.latest_encounter_count IS NOT NULL
      THEN GREATEST(
        0,
        COALESCE(chick_captures.latest_encounter_unflagged_count, 0)
      )
      ELSE GREATEST(
        0,
        COALESCE(chick_captures.n_operational_brood_size, 0)
          - COALESCE(chick_captures.n_active_flagged_chick_rings, 0)
      )
    END AS flagging_pending_count
  FROM chick_captures
),
hiding_spot_photos AS (
  SELECT *
  FROM FIELD_2026_BADOatNZ.TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT_BUILD
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
parent_resolution_status AS (
  /*
    Resolve a parent from the authoritative selected identity, regardless of
    whether that identity came from a capture/TN gate or a resighting gate.
    The old task note required a positive resighting count and a selected
    resighting mark, which incorrectly hid a capture-resolved parent. Keep
    the independent pending, ambiguity, MM, and death guards intact.
  */
  SELECT
    status.*,
    CASE
      WHEN COALESCE(status.M_resight_association_pending, 0) = 0
       AND COALESCE(status.M_resight_association_ambiguous, 0) = 0
       AND COALESCE(status.M_mm_resight_pending, 0) = 0
       AND COALESCE(status.M_identity_is_dead, 0) = 0
       AND NULLIF(TRIM(COALESCE(status.M_selected_identity_key, '')), '')
             IS NOT NULL
       AND UPPER(TRIM(status.M_selected_identity_key))
             NOT IN ('NA', 'N/A', 'NULL')
       AND (
         UPPER(TRIM(status.M_selected_identity_key)) NOT LIKE 'XX:%'
         OR (
           COALESCE(status.M_confirmed_unbanded, 0) = 1
           AND UPPER(TRIM(COALESCE(
             status.M_selected_mark,
             status.M_parent_mark,
             ''
           ))) = 'X-X'
         )
       )
       AND NULLIF(
             TRIM(COALESCE(status.M_selected_mark, status.M_parent_mark, '')),
             ''
           ) IS NOT NULL
       AND UPPER(TRIM(COALESCE(status.M_selected_mark, status.M_parent_mark)))
             NOT IN ('X', 'XX', 'NA', 'N/A', 'NULL')
       AND UPPER(TRIM(COALESCE(status.M_selected_mark, status.M_parent_mark)))
             NOT LIKE 'XX:%'
      THEN 1
      ELSE 0
    END AS M_authoritative_resolved,
    CASE
      WHEN COALESCE(status.F_resight_association_pending, 0) = 0
       AND COALESCE(status.F_resight_association_ambiguous, 0) = 0
       AND COALESCE(status.F_mm_resight_pending, 0) = 0
       AND COALESCE(status.F_identity_is_dead, 0) = 0
       AND NULLIF(TRIM(COALESCE(status.F_selected_identity_key, '')), '')
             IS NOT NULL
       AND UPPER(TRIM(status.F_selected_identity_key))
             NOT IN ('NA', 'N/A', 'NULL')
       AND (
         UPPER(TRIM(status.F_selected_identity_key)) NOT LIKE 'XX:%'
         OR (
           COALESCE(status.F_confirmed_unbanded, 0) = 1
           AND UPPER(TRIM(COALESCE(
             status.F_selected_mark,
             status.F_parent_mark,
             ''
           ))) = 'X-X'
         )
       )
       AND NULLIF(
             TRIM(COALESCE(status.F_selected_mark, status.F_parent_mark, '')),
             ''
           ) IS NOT NULL
       AND UPPER(TRIM(COALESCE(status.F_selected_mark, status.F_parent_mark)))
             NOT IN ('X', 'XX', 'NA', 'N/A', 'NULL')
       AND UPPER(TRIM(COALESCE(status.F_selected_mark, status.F_parent_mark)))
             NOT LIKE 'XX:%'
      THEN 1
      ELSE 0
    END AS F_authoritative_resolved
  FROM adult_parent_status status
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
    ON CONVERT(todo_parent_source.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_capture_timing.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
/*
  Use the youngest defensible per-egg estimate from exact/nearest flotation
  records as the final egg's laying date. Do not clamp that estimate to the
  first observed clutch-size record: a nest first found with an already old
  two- or three-egg clutch must retain its older float-derived chronology.
  When no valid float exists, current_clutch_start_datetime is the fallback
  for the current clutch. No egg_id ordering is assumed. A later third egg
  therefore resets the fallback to its new observed three-egg chronology,
  while a valid third-egg float can establish an older final-egg date. A float
  measurement is eligible only inside the current clutch-size episode, from
  current_clutch_start_datetime through the latest current observation; the
  inferred laying date itself may therefore predate discovery.
*/
adult_capture_final_egg_lay_status AS (
  SELECT
    clutch_start.nest_id,
    MAX(
      DATE_SUB(
        float_prediction.float_date,
        INTERVAL ROUND(float_prediction.predicted_days_since_laying) DAY
      )
    ) AS estimated_final_egg_lay_date
  FROM adult_capture_current_clutch_start clutch_start
  JOIN FIELD_2026_BADOatNZ.EGGS_HATCH_PREDICTION float_prediction
    ON CONVERT(clutch_start.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(float_prediction.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  WHERE clutch_start.current_clutch_size IN (2, 3)
    AND float_prediction.float_date IS NOT NULL
    AND float_prediction.calibration_match_type IN ('exact', 'nearest')
    AND DATE(float_prediction.float_date)
        >= DATE(clutch_start.current_clutch_start_datetime)
    AND DATE(float_prediction.float_date)
        <= DATE(clutch_start.current_clutch_datetime)
  GROUP BY
    clutch_start.nest_id,
    clutch_start.current_clutch_start_datetime
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
      WHEN x.clutch_completion_confirmed = 1
       AND DATEDIFF(
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
        /* Found-incomplete chronology is the stronger final-egg estimate. */
        WHEN initial_clutch_status.found_as_incomplete = 1
         AND initial_clutch_status.inferred_clutch_completion_date IS NOT NULL
        THEN initial_clutch_status.inferred_clutch_completion_date
        WHEN clutch_start.current_clutch_size IN (2, 3)
        THEN COALESCE(
          float_lay.estimated_final_egg_lay_date,
          DATE(clutch_start.current_clutch_start_datetime)
        )
        /* A stable one-egg clutch keeps the existing no-increase window, but
           its seven-day clock starts at egg 1's date, not completion + 2 days. */
        WHEN initial_clutch_status.stable_one_egg = 1
        THEN DATE(clutch_start.current_clutch_start_datetime)
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
         AND DATEDIFF(
               DATE(clutch_start.current_clutch_datetime),
               CASE
                 WHEN initial_clutch_status.found_as_incomplete = 1
                  AND initial_clutch_status.inferred_clutch_completion_date IS NOT NULL
                 THEN initial_clutch_status.inferred_clutch_completion_date
                 ELSE COALESCE(
                   float_lay.estimated_final_egg_lay_date,
                   DATE(clutch_start.current_clutch_start_datetime)
                 )
               END
             ) >= 3
        THEN 1
        WHEN clutch_start.current_clutch_size = 1
         AND initial_clutch_status.stable_one_egg = 1
         AND DATEDIFF(
               sr.reference_date,
               DATE(clutch_start.current_clutch_start_datetime)
             ) >= 4
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
      ON CONVERT(clutch_start.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
         = CONVERT(initial_clutch_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
    LEFT JOIN adult_capture_final_egg_lay_status float_lay
      ON CONVERT(clutch_start.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
         = CONVERT(float_lay.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
    CROSS JOIN sr
  ) x
  JOIN latest_nests
    ON CONVERT(x.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(latest_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
  A notA record with hatch evidence still needs parent work: the nest itself
  is closed, but the hatched brood keeps the parent-capture task alive.  Keep
  ordinary notA closure records out of the GEO/task candidate set.  A
  presumed-dead brood is excluded here as well, so its parents cannot become
  capture or pair-completion candidates; the final publication guard remains
  as a second defensive layer for every task type.
*/
parent_task_nests AS (
  SELECT n.*
  FROM active_nests n
  WHERE NOT EXISTS (
    SELECT 1
    FROM FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_BUILD closure
    WHERE CONVERT(closure.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
          = CONVERT(n.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
      AND closure.reference_date = n.reference_date
      AND (
        closure.is_presumed_dead = 1
        OR closure.is_resolved = 1
      )
  )
  UNION ALL
  SELECT n.*
  FROM latest_nests n
  JOIN hatched_nests h
    ON CONVERT(h.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(n.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  WHERE UPPER(TRIM(COALESCE(n.nest_state, ''))) = 'NOTA'
    AND NOT EXISTS (
      SELECT 1
      FROM FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_BUILD closure
      WHERE CONVERT(closure.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
            = CONVERT(n.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
        AND closure.reference_date = n.reference_date
        AND (
          closure.is_presumed_dead = 1
          OR closure.is_resolved = 1
        )
    )
),
/*
  Tag deployment is deliberately a small, explicit plan rather than a
  phenology/quota planner.  Initial deployment is restricted to positive nests
  on plots B and C whose authoritative completion date is strictly after
  2026-10-09.  Pair completion is a separate path: it may complete a pair at
  an active Plot B/C nest regardless of that nest's completion date, but only
  when the qualifying deployment occurred at that same nest.

  A missing completion date is never eligible for an initial deployment.

  X = authoritative confirmed X-X; B = authoritative resolved non-X-X parent
  without a GEO; T = authoritative parent with a GEO; ? = unknown or still
  unresolved.  Unknown status is never silently converted to X-X.  The guarded
  ?/? row is an instruction to verify X-X in the field, not permission to tag
  an unconfirmed bird.

  Pair completion requires a qualifying GEO deployment record for the current
  authoritative parent at the same nest, bounded only by the reference date.
  This prevents an unrelated GEO from creating a new tag instruction while
  allowing the nest's completion date and the original deployment date to
  precede the initial-deployment campaign window.
*/
tag_deployment_history AS (
  SELECT DISTINCT
    c.nest_id,
    c.capture_sex AS parent_sex,
    c.identity_key,
    c.display_mark AS parent_mark,
    c.capture_date AS deployment_date,
    c.capture_datetime AS deployment_datetime
  FROM FIELD_2026_BADOatNZ.ADULT_CAPTURE_IDENTITIES_ALL c
  CROSS JOIN sr
  WHERE c.nest_id IS NOT NULL
    AND TRIM(c.nest_id) <> ''
    AND LEFT(TRIM(c.nest_id), 1) IN ('B', 'C')
    AND c.capture_date <= sr.reference_date
    AND c.capture_sex IN ('M', 'F')
    AND c.has_geo = 1
    AND c.tag_type = 'GEO'
    AND c.tag_action IN ('D', 'S', 'N')
    AND c.tag_id IS NOT NULL
),
tag_deployment_candidates AS (
  SELECT
    parent_task_nests.nest_id,
    parent_task_nests.reference_date,
    adult_parent_status.M_parent_mark,
    adult_parent_status.F_parent_mark,
    adult_parent_status.M_selected_mark,
    adult_parent_status.F_selected_mark,
    adult_parent_status.M_selected_identity_key,
    adult_parent_status.F_selected_identity_key,
    adult_parent_status.M_has_geo,
    adult_parent_status.F_has_geo,
    adult_parent_status.M_confirmed_unbanded,
    adult_parent_status.F_confirmed_unbanded,
    adult_parent_status.M_unknown_status,
    adult_parent_status.F_unknown_status,
    adult_parent_status.M_resight_association_pending,
    adult_parent_status.F_resight_association_pending,
    adult_parent_status.M_resight_association_ambiguous,
    adult_parent_status.F_resight_association_ambiguous,
    adult_parent_status.M_is_dead,
    adult_parent_status.F_is_dead,
    adult_parent_status.M_identity_is_dead,
    adult_parent_status.F_identity_is_dead,
    adult_parent_status.M_is_au_migrant,
    adult_parent_status.F_is_au_migrant,
    adult_capture_age_status.clutch_completion_basis_date,
    CASE
      WHEN COALESCE(adult_parent_status.M_has_geo, 0) = 1
       AND COALESCE(adult_parent_status.M_resight_association_pending, 0) = 0
       AND COALESCE(adult_parent_status.M_resight_association_ambiguous, 0) = 0
      THEN 'T'
      WHEN COALESCE(adult_parent_status.M_confirmed_unbanded, 0) = 1
      THEN 'X'
      WHEN COALESCE(adult_parent_status.M_unknown_status, 0) = 1
        OR COALESCE(adult_parent_status.M_resight_association_pending, 0) = 1
        OR COALESCE(adult_parent_status.M_resight_association_ambiguous, 0) = 1
      THEN '?'
      WHEN NULLIF(TRIM(COALESCE(adult_parent_status.M_parent_mark, '')), '') IS NOT NULL
       AND UPPER(TRIM(adult_parent_status.M_parent_mark)) <> 'X-X'
       AND COALESCE(adult_parent_status.M_identity_is_dead, 0) = 0
       AND COALESCE(adult_parent_status.M_has_geo, 0) = 0
      THEN 'B'
      ELSE '?'
    END AS M_tag_status,
    CASE
      WHEN COALESCE(adult_parent_status.F_has_geo, 0) = 1
       AND COALESCE(adult_parent_status.F_resight_association_pending, 0) = 0
       AND COALESCE(adult_parent_status.F_resight_association_ambiguous, 0) = 0
      THEN 'T'
      WHEN COALESCE(adult_parent_status.F_confirmed_unbanded, 0) = 1
      THEN 'X'
      WHEN COALESCE(adult_parent_status.F_unknown_status, 0) = 1
        OR COALESCE(adult_parent_status.F_resight_association_pending, 0) = 1
        OR COALESCE(adult_parent_status.F_resight_association_ambiguous, 0) = 1
      THEN '?'
      WHEN NULLIF(TRIM(COALESCE(adult_parent_status.F_parent_mark, '')), '') IS NOT NULL
       AND UPPER(TRIM(adult_parent_status.F_parent_mark)) <> 'X-X'
       AND COALESCE(adult_parent_status.F_identity_is_dead, 0) = 0
       AND COALESCE(adult_parent_status.F_has_geo, 0) = 0
      THEN 'B'
      ELSE '?'
    END AS F_tag_status,
    CASE WHEN EXISTS (
      SELECT 1
      FROM tag_deployment_history history
      WHERE CONVERT(history.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
            = CONVERT(parent_task_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
        AND history.parent_sex = 'M'
        AND (
          history.identity_key = adult_parent_status.M_selected_identity_key
          OR CONVERT(UPPER(TRIM(history.parent_mark)) USING utf8mb4)
               COLLATE utf8mb4_general_ci
             = CONVERT(
                 UPPER(TRIM(COALESCE(
                   adult_parent_status.M_selected_mark,
                   adult_parent_status.M_parent_mark
                 ))) USING utf8mb4
               ) COLLATE utf8mb4_general_ci
        )
    ) THEN 1 ELSE 0 END AS M_new_protocol_geo,
    CASE WHEN EXISTS (
      SELECT 1
      FROM tag_deployment_history history
      WHERE CONVERT(history.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
            = CONVERT(parent_task_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
        AND history.parent_sex = 'F'
        AND (
          history.identity_key = adult_parent_status.F_selected_identity_key
          OR CONVERT(UPPER(TRIM(history.parent_mark)) USING utf8mb4)
               COLLATE utf8mb4_general_ci
             = CONVERT(
                 UPPER(TRIM(COALESCE(
                   adult_parent_status.F_selected_mark,
                   adult_parent_status.F_parent_mark
                 ))) USING utf8mb4
               ) COLLATE utf8mb4_general_ci
        )
    ) THEN 1 ELSE 0 END AS F_new_protocol_geo,
    CASE
      WHEN adult_parent_status.M_confirmed_unbanded = 1
        OR adult_parent_status.F_confirmed_unbanded = 1
        OR (
          adult_parent_status.M_unknown_status = 1
          AND adult_parent_status.F_unknown_status = 1
        )
      THEN 1
      ELSE 0
    END AS initial_tag_candidate,
    CASE
      WHEN adult_capture_age_status.clutch_completion_basis_date
        > CAST('2026-10-09' AS DATE)
      THEN 1
      ELSE 0
    END AS initial_deployment_eligible
  FROM parent_task_nests
  JOIN adult_parent_status
    ON CONVERT(parent_task_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_capture_age_status
    ON CONVERT(parent_task_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_capture_age_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  WHERE LEFT(TRIM(parent_task_nests.nest_id), 1) IN ('B', 'C')
    AND COALESCE(adult_parent_status.M_identity_is_dead, 0) = 0
    AND COALESCE(adult_parent_status.F_identity_is_dead, 0) = 0
    AND COALESCE(adult_parent_status.M_resight_association_ambiguous, 0) = 0
    AND COALESCE(adult_parent_status.F_resight_association_ambiguous, 0) = 0
),
tag_deployment_plan AS (
  SELECT
    candidates.nest_id,
    ROW_NUMBER() OVER (ORDER BY candidates.nest_id) AS geo_rank,
    1 AS geo_priority_tier,
    1 AS global_sex_priority,
    1 AS geo_priority_score,
    CASE
      WHEN candidates.M_tag_status = 'T'
       AND candidates.F_tag_status IN ('X', 'B', '?')
       AND candidates.M_new_protocol_geo = 1
      THEN 'pair completion'
      WHEN candidates.F_tag_status = 'T'
       AND candidates.M_tag_status IN ('X', 'B', '?')
       AND candidates.F_new_protocol_geo = 1
      THEN 'pair completion'
      WHEN candidates.initial_tag_candidate = 1
       AND candidates.initial_deployment_eligible = 1
      THEN 'initial'
      ELSE NULL
    END AS geo_reason,
    CASE
      WHEN candidates.M_tag_status = 'T'
       AND candidates.F_tag_status IN ('X', 'B', '?')
       AND candidates.M_new_protocol_geo = 1
      THEN 'F'
      WHEN candidates.F_tag_status = 'T'
       AND candidates.M_tag_status IN ('X', 'B', '?')
       AND candidates.F_new_protocol_geo = 1
      THEN 'M'
      WHEN candidates.initial_tag_candidate = 1
       AND candidates.initial_deployment_eligible = 1
      THEN 'A'
      ELSE NULL
    END AS geo_target,
    CASE
      WHEN candidates.M_tag_status = 'T'
       AND candidates.F_tag_status IN ('X', 'B', '?')
       AND candidates.M_new_protocol_geo = 1
      THEN 'F'
      WHEN candidates.F_tag_status = 'T'
       AND candidates.M_tag_status IN ('X', 'B', '?')
       AND candidates.F_new_protocol_geo = 1
      THEN 'M'
      WHEN candidates.initial_tag_candidate = 1
       AND candidates.initial_deployment_eligible = 1
      THEN 'A'
      ELSE NULL
    END AS geo_tag_target,
    CASE
      WHEN candidates.M_tag_status = 'T'
       AND candidates.F_tag_status IN ('X', 'B', '?')
       AND candidates.M_new_protocol_geo = 1
      THEN 1
      WHEN candidates.F_tag_status = 'T'
       AND candidates.M_tag_status IN ('X', 'B', '?')
       AND candidates.F_new_protocol_geo = 1
      THEN 1
      WHEN candidates.initial_tag_candidate = 1
       AND candidates.initial_deployment_eligible = 1
      THEN 1
      ELSE 0
    END AS geo_is_actionable,
    geo_observation_counts.n_geo_deployed,
    CAST(NULL AS SIGNED) AS release_ceiling,
    CAST(NULL AS SIGNED) AS release_slots_remaining,
    geo_observation_counts.n_male_geo_deployed,
    geo_observation_counts.n_female_geo_deployed,
    CAST(NULL AS SIGNED) AS male_quota_remaining,
    CAST(NULL AS SIGNED) AS female_quota_remaining,
    CAST(NULL AS CHAR(1)) AS preferred_balance_sex,
    CAST(NULL AS CHAR(2)) AS geo_band_target,
    CASE
      WHEN candidates.M_tag_status = 'T'
       AND candidates.F_tag_status = 'X'
       AND candidates.M_new_protocol_geo = 1
      THEN 'tag X-X F (pair completion)'
      WHEN candidates.F_tag_status = 'T'
       AND candidates.M_tag_status = 'X'
       AND candidates.F_new_protocol_geo = 1
      THEN 'tag X-X M (pair completion)'
      WHEN candidates.M_tag_status = 'T'
       AND candidates.F_tag_status = 'B'
       AND candidates.M_new_protocol_geo = 1
      THEN 'tag F (pair completion)'
      WHEN candidates.F_tag_status = 'T'
       AND candidates.M_tag_status = 'B'
       AND candidates.F_new_protocol_geo = 1
      THEN 'tag M (pair completion)'
      WHEN candidates.M_tag_status = 'T'
       AND candidates.F_tag_status = '?'
       AND candidates.M_new_protocol_geo = 1
      THEN 'resight/tag F (status ?; pair completion)'
      WHEN candidates.F_tag_status = 'T'
       AND candidates.M_tag_status = '?'
       AND candidates.F_new_protocol_geo = 1
      THEN 'resight/tag M (status ?; pair completion)'
      WHEN candidates.initial_tag_candidate = 1
       AND candidates.initial_deployment_eligible = 1
       AND candidates.M_tag_status = '?'
       AND candidates.F_tag_status = '?'
      THEN 'tag any, but only if one is confirmed X-X'
      WHEN candidates.initial_tag_candidate = 1
       AND candidates.initial_deployment_eligible = 1
      THEN 'tag any'
      ELSE NULL
    END AS geo_instruction,
    CASE
      WHEN candidates.M_tag_status = 'T'
       AND candidates.F_tag_status IN ('X', 'B', '?')
       AND candidates.M_new_protocol_geo = 1
      THEN 1
      WHEN candidates.F_tag_status = 'T'
       AND candidates.M_tag_status IN ('X', 'B', '?')
       AND candidates.F_new_protocol_geo = 1
      THEN 1
      ELSE 0
    END AS is_pair_completion,
    candidates.M_is_au_migrant,
    candidates.F_is_au_migrant
  FROM tag_deployment_candidates candidates
  CROSS JOIN geo_observation_counts
  WHERE (
      candidates.M_tag_status = 'T'
      AND candidates.F_tag_status IN ('X', 'B', '?')
      AND candidates.M_new_protocol_geo = 1
    )
    OR (
      candidates.F_tag_status = 'T'
      AND candidates.M_tag_status IN ('X', 'B', '?')
      AND candidates.F_new_protocol_geo = 1
    )
    OR (
      candidates.initial_tag_candidate = 1
      AND candidates.initial_deployment_eligible = 1
    )
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
      WHEN tag_deployment_plan.geo_instruction IS NOT NULL
      THEN tag_deployment_plan.geo_instruction
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_confirmed_unbanded = 1
       AND COALESCE(adult_parent_status.M_identity_is_dead, 0) = 1
       AND COALESCE(adult_parent_status.F_identity_is_dead, 0) = 0
      THEN 'F (M selected identity dead)'
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_confirmed_unbanded = 1
       AND COALESCE(adult_parent_status.F_identity_is_dead, 0) = 1
       AND COALESCE(adult_parent_status.M_identity_is_dead, 0) = 0
      THEN 'M (F selected identity dead)'
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
      WHEN tag_deployment_plan.geo_tag_target IS NOT NULL
      THEN tag_deployment_plan.geo_tag_target
      WHEN tag_deployment_plan.geo_target IS NOT NULL
      THEN tag_deployment_plan.geo_target
      WHEN tag_deployment_plan.geo_band_target IS NOT NULL
      THEN tag_deployment_plan.geo_band_target
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_confirmed_unbanded = 1
       AND COALESCE(adult_parent_status.M_identity_is_dead, 0) = 1
       AND COALESCE(adult_parent_status.F_identity_is_dead, 0) = 0 THEN 'F'
      WHEN adult_parent_status.M_confirmed_unbanded = 1
       AND adult_parent_status.F_confirmed_unbanded = 1
       AND COALESCE(adult_parent_status.F_identity_is_dead, 0) = 1
       AND COALESCE(adult_parent_status.M_identity_is_dead, 0) = 0 THEN 'M'
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
    adult_parent_status.M_identity_is_dead,
    adult_parent_status.F_identity_is_dead,
    adult_parent_status.M_has_geo,
    adult_parent_status.F_has_geo,
    adult_parent_status.M_single_colour_recruit,
    adult_parent_status.F_single_colour_recruit,
    adult_parent_status.M_mm_resight_pending,
    adult_parent_status.F_mm_resight_pending,
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
            WHERE CONVERT(hatched.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
                  = CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
             tag_deployment_plan.geo_tag_target,
             tag_deployment_plan.geo_band_target
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
             tag_deployment_plan.geo_tag_target,
             tag_deployment_plan.geo_band_target
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
             tag_deployment_plan.geo_tag_target,
             tag_deployment_plan.geo_band_target
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
    tag_deployment_plan.geo_instruction,
    tag_deployment_plan.geo_tag_target,
    tag_deployment_plan.geo_band_target,
    tag_deployment_plan.geo_target,
    tag_deployment_plan.geo_is_actionable,
    tag_deployment_plan.n_geo_deployed,
    tag_deployment_plan.release_ceiling,
    tag_deployment_plan.geo_rank,
    tag_deployment_plan.geo_priority_tier,
    tag_deployment_plan.global_sex_priority,
    tag_deployment_plan.geo_priority_score,
    tag_deployment_plan.geo_reason,
    tag_deployment_plan.is_pair_completion,
    tag_deployment_plan.n_male_geo_deployed,
    tag_deployment_plan.n_female_geo_deployed,
    tag_deployment_plan.male_quota_remaining,
    tag_deployment_plan.female_quota_remaining,
    tag_deployment_plan.preferred_balance_sex,
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
      ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
         = CONVERT(nest_discovery.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
      ON CONVERT(n.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
         = CONVERT(hatched_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
    LEFT JOIN nest_discovery
      ON CONVERT(n.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
         = CONVERT(nest_discovery.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
  LEFT JOIN adult_parent_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN tag_deployment_plan
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(tag_deployment_plan.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_capture_interval_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_capture_interval_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_capture_age_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_capture_age_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN float_summary
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(float_summary.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN initial_clutch_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(initial_clutch_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
      OR tag_deployment_plan.geo_instruction IS NOT NULL
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
       AND COALESCE(M_identity_is_dead, 0) = 1
       AND COALESCE(F_identity_is_dead, 0) = 0
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
      WHEN COALESCE(M_confirmed_unbanded, 0) = 1
       AND COALESCE(F_confirmed_unbanded, 0) = 1
       AND COALESCE(F_identity_is_dead, 0) = 1
       AND COALESCE(M_identity_is_dead, 0) = 0
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
          THEN 'resight/tag M (status ?; F w/GEO)'
          ELSE 'resight M (status ?; F w/GEO)'
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
          THEN 'resight/tag F (status ?; M w/GEO)'
          ELSE 'resight F (status ?; M w/GEO)'
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
    /* Never emit a capture/banding instruction for a selected-dead target.
       A dead competing identity remains harmless because these flags are
       selected-identity-specific; the other living parent's task is kept. */
    AND NOT (
      (target_parent = 'M' AND COALESCE(M_identity_is_dead, 0) = 1)
      OR (target_parent = 'F' AND COALESCE(F_identity_is_dead, 0) = 1)
      OR (
        target_parent = 'A'
        AND (
          COALESCE(M_identity_is_dead, 0) = 1
          OR COALESCE(F_identity_is_dead, 0) = 1
        )
      )
    )
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
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(nest_discovery.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
    ON CONVERT(n.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(hatched_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN nest_discovery
    ON CONVERT(n.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(nest_discovery.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
    candidate.nest_id,
    candidate.reference_date,
    'Parent resighting' AS todo,
    CASE
      /*
        The candidate branch owns eligibility and the 7d/36hr wording. Add
        only the authoritative opposite-sex resolution, so the fallback
        branch is as informative as the known-banded branch below without
        creating a second identity inference path.
      */
      WHEN COALESCE(association.M_authoritative_resolved, 0) = 1
       AND COALESCE(association.F_authoritative_resolved, 0) = 1
      THEN CONCAT_WS(
        '; ',
        NULLIF(TRIM(candidate.notes), ''),
        'M resolved',
        'F resolved'
      )
      WHEN COALESCE(association.M_authoritative_resolved, 0) = 1
      THEN CONCAT_WS(
        '; ',
        NULLIF(TRIM(candidate.notes), ''),
        'M resolved'
      )
      WHEN COALESCE(association.F_authoritative_resolved, 0) = 1
      THEN CONCAT_WS(
        '; ',
        NULLIF(TRIM(candidate.notes), ''),
        'F resolved'
      )
      ELSE candidate.notes
    END AS notes,
    candidate.days_overdue,
    candidate.priority,
    candidate.min_days_to_hatch,
    candidate.last_visit_days_ago,
    candidate.nest_state,
    candidate.clutch_size,
    candidate.brood_size,
    candidate.M_mark,
    candidate.F_mark,
    candidate.lat,
    candidate.lon
  FROM todo_untrapped_parent candidate
  LEFT JOIN parent_resolution_status association
    ON CONVERT(candidate.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(association.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
   AND candidate.reference_date = association.reference_date
  WHERE candidate.parent_task_class = 'Parent resighting'
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
          WHEN association.F_authoritative_resolved = 1
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
          WHEN association.M_authoritative_resolved = 1
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
  JOIN parent_resolution_status association
    ON CONVERT(parent_units.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(association.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
    ON CONVERT(parent_units.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(association.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  WHERE (
      association.nest_id IS NULL
      OR COALESCE(association.M_unknown_status, 0) = 1
      OR COALESCE(association.F_unknown_status, 0) = 1
    )
    AND NOT EXISTS (
      SELECT 1
      FROM todo_untrapped_parent candidate
      WHERE CONVERT(candidate.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
            = CONVERT(parent_units.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(processing_summary.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_parent_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_capture_age_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_capture_age_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN initial_clutch_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(initial_clutch_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(photo_summary.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  JOIN nest_discovery
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(nest_discovery.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_parent_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN FIELD_2026_BADOatNZ.ADULT_SCRAPE_RESIGHTING_STATUS
    adult_resighting_association_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_resighting_association_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(processing_summary.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  JOIN latest_clutch_history
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(latest_clutch_history.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
   AND latest_clutch_history.row_num = 1
  LEFT JOIN latest_clutch_processing_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(latest_clutch_processing_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN clutch_at_processing
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(clutch_at_processing.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
   AND clutch_at_processing.row_num = 1
  LEFT JOIN initial_clutch_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(initial_clutch_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_parent_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(latest_nest_event.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
   AND latest_nest_event.row_num = 1
  JOIN adult_capture_current_clutch_start
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_capture_current_clutch_start.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_parent_status
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
      WHERE CONVERT(prior_nest_event.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
            = CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
      WHERE CONVERT(stable_one_egg.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
            = CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
    ON CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
    -- Once age-C evidence has established an ordinary brood, the nest-check
    -- task is redundant even if the nest visit still carries a partial hatch
    -- sign. Keep the explicit H-state/positive-clutch/positive-brood case in
    -- the nest-check output: it is the field reminder for unhatched eggs
    -- remaining after chicks have been recorded. This exception does not
    -- alter the independent brood-photo task, which remains published below.
    AND (
      (
        UPPER(TRIM(COALESCE(active_nests.nest_state, ''))) = 'H'
        AND COALESCE(active_nests.clutch_size, 0) > 0
        AND COALESCE(active_nests.brood_size, 0) > 0
      )
      OR NOT EXISTS (
        SELECT 1
        FROM brood_context brood_evidence
        WHERE CONVERT(brood_evidence.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
              = CONVERT(active_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
          AND brood_evidence.reference_date = active_nests.reference_date
          AND brood_evidence.is_negative_brood = 0
          AND brood_evidence.has_hatch_evidence = 1
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
    ON CONVERT(brood_followup_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(chick_captures.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_parent_status
    ON CONVERT(brood_followup_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
    ON CONVERT(b.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(chick_captures.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_parent_status
    ON CONVERT(b.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
      WHEN COALESCE(chick_captures.n_unresolved_dead_chick_events, 0) > 0
      THEN 'confirm unresolved chick death identities before flagging'
      WHEN COALESCE(chick_captures.n_unringed_chick_captures, 0) > 0
      THEN 'recapture chicks; assign unique engraved UL flags (some chick captures lack metal-ring IDs)'
      ELSE CONCAT(
        'recapture chicks; assign flags (',
        GREATEST(
          0,
          COALESCE(chick_captures.flagging_pending_count, 0)
        ),
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
  LEFT JOIN flagging_context chick_captures
    ON CONVERT(brood_followup_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(chick_captures.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_parent_status
    ON CONVERT(brood_followup_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  WHERE DATEDIFF(
          brood_followup_nests.reference_date,
          brood_followup_nests.hatch_date
        ) >= 21
    AND (
      COALESCE(chick_captures.n_chick_captures, 0) = 0
      OR COALESCE(chick_captures.n_unringed_chick_captures, 0) > 0
      OR COALESCE(chick_captures.n_unresolved_dead_chick_events, 0) > 0
      OR COALESCE(chick_captures.flagging_work_pending, 0) = 1
    )
  UNION ALL
  SELECT
    b.nest_id,
    b.reference_date,
    'Broods to recapture for flagging' AS todo,
    CASE
      WHEN COALESCE(chick_captures.n_chick_captures, 0) = 0
      THEN 'no chick captures; recapture chicks and assign unique engraved UL flags'
      WHEN COALESCE(chick_captures.n_unresolved_dead_chick_events, 0) > 0
      THEN 'confirm unresolved chick death identities before flagging'
      WHEN COALESCE(chick_captures.n_unringed_chick_captures, 0) > 0
      THEN 'recapture chicks; assign unique engraved UL flags (some chick captures lack metal-ring IDs)'
      ELSE CONCAT(
        'recapture chicks; assign flags (',
        GREATEST(
          0,
          COALESCE(chick_captures.flagging_pending_count, 0)
        ),
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
  LEFT JOIN flagging_context chick_captures
    ON CONVERT(b.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(chick_captures.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_parent_status
    ON CONVERT(b.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
    AND DATEDIFF(b.reference_date, b.discovery_date) >= 21
    AND (
      COALESCE(chick_captures.n_chick_captures, 0) = 0
      OR COALESCE(chick_captures.n_unringed_chick_captures, 0) > 0
      OR COALESCE(chick_captures.n_unresolved_dead_chick_events, 0) > 0
      OR COALESCE(chick_captures.flagging_work_pending, 0) = 1
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
      COALESCE(chick_captures.n_active_chick_rings, 0),
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
    ON CONVERT(brood_followup_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(hiding_spot_photos.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN chick_captures
    ON CONVERT(brood_followup_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(chick_captures.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_parent_status
    ON CONVERT(brood_followup_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  WHERE DATEDIFF(
        brood_followup_nests.reference_date,
        brood_followup_nests.hatch_date
      ) BETWEEN 1 AND 6
    AND (
      COALESCE(chick_captures.n_active_chick_rings, 0) = 0
      OR COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0)
           < chick_captures.n_active_chick_rings
    )
  UNION ALL
  SELECT
    b.nest_id,
    b.reference_date,
    'Hiding spot photos needed' AS todo,
    CONCAT(
      COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0),
      '/',
      COALESCE(chick_captures.n_active_chick_rings, 0),
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
    ON CONVERT(b.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(hiding_spot_photos.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN chick_captures
    ON CONVERT(b.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(chick_captures.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN adult_parent_status
    ON CONVERT(b.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
  WHERE b.is_negative_brood = 1
    AND b.reference_date = sr.reference_date
    AND DATEDIFF(b.reference_date, b.discovery_date) BETWEEN 1 AND 6
    AND (
      COALESCE(chick_captures.n_active_chick_rings, 0) = 0
      OR COALESCE(hiding_spot_photos.n_hiding_spot_photos, 0)
           < chick_captures.n_active_chick_rings
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
    ON CONVERT(nota_followup_nests.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
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
  tag_deployment_plan.geo_rank AS geo_priority_rank,
  tag_deployment_plan.geo_priority_tier,
  tag_deployment_plan.geo_priority_score,
  tag_deployment_plan.geo_reason,
  tag_deployment_plan.geo_target,
  tag_deployment_plan.geo_tag_target,
  tag_deployment_plan.geo_is_actionable,
  tag_deployment_plan.n_geo_deployed,
  tag_deployment_plan.release_ceiling,
  tag_deployment_plan.release_slots_remaining,
  tag_deployment_plan.n_male_geo_deployed,
  tag_deployment_plan.n_female_geo_deployed,
  tag_deployment_plan.male_quota_remaining,
  tag_deployment_plan.female_quota_remaining,
  tag_deployment_plan.preferred_balance_sex,
  tag_deployment_plan.M_is_au_migrant,
  tag_deployment_plan.F_is_au_migrant,
  CASE
    WHEN CONVERT(t.todo USING utf8mb4) COLLATE utf8mb4_general_ci
         IN ('Untrapped parent', 'Parent capture', 'Parent resighting')
     AND t.min_days_to_hatch IS NOT NULL
     AND CEILING(t.min_days_to_hatch) <= 5
    THEN CONCAT(
      GREATEST(0, CEILING(t.min_days_to_hatch)),
      ' to H'
    )
    WHEN CONVERT(t.todo USING utf8mb4) COLLATE utf8mb4_general_ci
         = 'Untrapped parent'
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
  ON CONVERT(t.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(adult_parent_status.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
LEFT JOIN tag_deployment_plan
  ON CONVERT(t.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
     = CONVERT(tag_deployment_plan.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
-- WRYB remains available to map/summary consumers, but is not a Cass
-- operational task in TODO_LIST.
WHERE NOT EXISTS (
  SELECT 1
  FROM FIELD_2026_BADOatNZ.NESTS_LATEST wryb_nest
  WHERE CONVERT(wryb_nest.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
        = CONVERT(t.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
    AND UPPER(TRIM(COALESCE(wryb_nest.species, ''))) = 'WRYB'
)
AND (
  CONVERT(t.todo USING utf8mb4) COLLATE utf8mb4_general_ci
      = 'notA nest-check'
  OR NOT EXISTS (
    SELECT 1
    FROM FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_BUILD closure
    WHERE CONVERT(closure.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
          = CONVERT(t.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
      AND closure.reference_date = t.reference_date
      AND (
        closure.is_presumed_dead = 1
        OR closure.is_resolved = 1
      )
  )
);

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
  FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT
    TO FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_PREVIOUS,
  FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_BUILD
    TO FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT,
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

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS AS
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT;

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
DROP TABLE FIELD_2026_BADOatNZ.TODO_BROOD_CLOSURE_STATUS_SNAPSHOT_PREVIOUS;

UPDATE FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS
SET
  state = 'succeeded',
  completed_at = CURRENT_TIMESTAMP,
  task_row_count = (
    SELECT COUNT(*)
    FROM FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT
  )
WHERE refresh_id = @todo_refresh_id;
