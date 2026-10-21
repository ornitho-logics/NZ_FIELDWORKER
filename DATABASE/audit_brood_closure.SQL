/*
  AUDIT-ONLY brood-presumed-dead diagnostic.

  Run this file as one session. It creates only TEMPORARY tables and ends by
  returning a population-stage summary followed by one aggregate row per
  anchored brood. It does not create a view, table, task value, notA event, or
  snapshot row, and it does not change the existing parent-association logic.

  Conservative initial rule:
    * positive broods use hatch_evidence_date;
    * negative broods use discovery_date;
    * all anchored broods are considered for later positive-nest evidence;
    * only the conservative two-by-two negative-observation rule requires
      the brood to be >= 21 days beyond that anchor;
    * the conservative two-by-two rule needs both sexes to have a selected,
      non-X-X identity;
    * each sex needs qualifying observations on >= 2 dates, with >= 1 strong
      adult-only negative observation per sex, and any brood-positive event
      must precede both parents' final qualifying negative dates;
    * BW is weak evidence and may contribute a date but cannot close a brood;
    * a selected high-confidence parent association at a later positive nest
      is sufficient for a single-parent later-nest trigger; an unambiguous
      identity match is retained only to support a dual-parent trigger when
      both former parents occur at that same later nest; IN/NM/SC are not
      required for either pathway;
    * an independent audit-only spatial signal is reported when a later
      positive nest is within 100 m of the original positive nest, using
      nest-linked GPS_POINTS coordinates; and
    * later direct chick evidence, C-linked adult capture, exact age-C/GPS
      parent linkage, or BC/FC/AC evidence is reported as reactivation.

  Behaviour flags below are local to this audit. In particular, they do not
  alter ADULT_RESIGHTING_IDENTITIES.association_confirming, the four-gate
  ADULT_PARENT_STATUS pipeline, or any PDF task source.

  The script is intentionally staged. A single CREATE VIEW over the identity
  graph caused a long local DDL/metadata-lock pass, so this audit keeps each
  expensive boundary explicit and independently inspectable.
*/

DROP TEMPORARY TABLE IF EXISTS TODO_BROOD_CLOSURE_AUDIT;
DROP TEMPORARY TABLE IF EXISTS tmp_brood_units;
DROP TEMPORARY TABLE IF EXISTS tmp_identity_candidates_raw;
DROP TEMPORARY TABLE IF EXISTS tmp_identity_candidates;
DROP TEMPORARY TABLE IF EXISTS tmp_identity_summary;
DROP TEMPORARY TABLE IF EXISTS tmp_parent_events_raw;
DROP TEMPORARY TABLE IF EXISTS tmp_parent_events;
DROP TEMPORARY TABLE IF EXISTS tmp_parent_evidence_summary;
DROP TEMPORARY TABLE IF EXISTS tmp_nest_locations;
DROP TEMPORARY TABLE IF EXISTS tmp_later_nest_evidence_raw;
DROP TEMPORARY TABLE IF EXISTS tmp_later_nest_evidence;
DROP TEMPORARY TABLE IF EXISTS tmp_later_nest_parent_counts;
DROP TEMPORARY TABLE IF EXISTS tmp_later_nest_summary;
DROP TEMPORARY TABLE IF EXISTS tmp_spatial_later_nest_evidence;
DROP TEMPORARY TABLE IF EXISTS tmp_spatial_later_nest_summary;
DROP TEMPORARY TABLE IF EXISTS tmp_remaining_todo;
DROP TEMPORARY TABLE IF EXISTS tmp_closure_candidates;
DROP TEMPORARY TABLE IF EXISTS tmp_reactivation_events;
DROP TEMPORARY TABLE IF EXISTS tmp_reactivation_summary;
DROP TEMPORARY TABLE IF EXISTS tmp_brood_stage_summary;

CREATE TEMPORARY TABLE tmp_brood_units AS
SELECT
  b.nest_id AS brood_id,
  b.brood_kind,
  b.is_negative_brood,
  b.discovery_date,
  b.hatch_evidence_date,
  COALESCE(b.hatch_evidence_date, b.discovery_date) AS anchor_date,
  b.brood_size,
  sr.reference_date,
  DATEDIFF(
    sr.reference_date,
    COALESCE(b.hatch_evidence_date, b.discovery_date)
  ) AS age_days,
  CASE WHEN DATEDIFF(
    sr.reference_date,
    COALESCE(b.hatch_evidence_date, b.discovery_date)
  ) >= 21 THEN 1 ELSE 0 END AS age_qualified
FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
CROSS JOIN (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
) sr
WHERE b.reference_date = sr.reference_date
  AND (b.is_negative_brood = 1 OR b.has_hatch_evidence = 1)
  AND COALESCE(b.hatch_evidence_date, b.discovery_date) IS NOT NULL;

ALTER TABLE tmp_brood_units
  ADD PRIMARY KEY (brood_id),
  ADD INDEX idx_tmp_brood_units_anchor (anchor_date),
  ADD INDEX idx_tmp_brood_units_reference (reference_date);

CREATE TEMPORARY TABLE tmp_identity_candidates_raw AS
SELECT
  b.brood_id,
  a.sex,
  a.identity_key,
  'high' AS identity_confidence,
  3 AS confidence_rank
FROM tmp_brood_units b
JOIN FIELD_2026_BADOatNZ.ADULT_PARENT_NEST_ASSOCIATIONS a
  ON a.nest_id = b.brood_id
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
FROM tmp_brood_units b
JOIN FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES m
  ON m.nest_id = b.brood_id
 AND m.sex IN ('M', 'F')
 AND m.is_ambiguous_match = 0
 AND COALESCE(m.n_candidate_identities, 0) = 1
 AND m.identity_key IS NOT NULL
 AND m.identity_key NOT LIKE 'xx:%';

ALTER TABLE tmp_identity_candidates_raw
  ADD INDEX idx_tmp_identity_raw_brood_sex (brood_id, sex),
  ADD INDEX idx_tmp_identity_raw_identity (identity_key);

CREATE TEMPORARY TABLE tmp_identity_candidates AS
SELECT DISTINCT
  raw.brood_id,
  raw.sex,
  raw.identity_key,
  raw.identity_confidence,
  raw.confidence_rank
FROM tmp_identity_candidates_raw raw
WHERE (
    raw.confidence_rank = 3
    AND EXISTS (
      SELECT 1
      FROM tmp_identity_candidates_raw high
      WHERE high.brood_id = raw.brood_id
        AND high.sex = raw.sex
        AND high.confidence_rank = 3
    )
  )
  OR (
    raw.confidence_rank = 2
    AND NOT EXISTS (
      SELECT 1
      FROM tmp_identity_candidates_raw high
      WHERE high.brood_id = raw.brood_id
        AND high.sex = raw.sex
        AND high.confidence_rank = 3
    )
  );

ALTER TABLE tmp_identity_candidates
  ADD INDEX idx_tmp_identity_candidates_brood_sex (brood_id, sex),
  ADD INDEX idx_tmp_identity_candidates_identity (identity_key);

CREATE TEMPORARY TABLE tmp_identity_summary AS
SELECT
  b.brood_id,
  COALESCE(MAX(CASE WHEN c.sex = 'M' THEN c.identity_confidence END), 'unknown')
    AS M_identity_confidence,
  COALESCE(MAX(CASE WHEN c.sex = 'F' THEN c.identity_confidence END), 'unknown')
    AS F_identity_confidence,
  COUNT(DISTINCT CASE WHEN c.sex = 'M' THEN c.identity_key END)
    AS M_identity_count,
  COUNT(DISTINCT CASE WHEN c.sex = 'F' THEN c.identity_key END)
    AS F_identity_count
FROM tmp_brood_units b
LEFT JOIN tmp_identity_candidates c
  ON c.brood_id = b.brood_id
GROUP BY b.brood_id;

ALTER TABLE tmp_identity_summary
  ADD PRIMARY KEY (brood_id);

CREATE TEMPORARY TABLE tmp_parent_events_raw AS
SELECT
  b.brood_id,
  c.sex,
  c.identity_key,
  c.identity_confidence,
  m.resighting_pk,
  m.observation_date,
  m.nest_id AS observed_nest_id,
  UPPER(TRIM(COALESCE(m.behav, ''))) AS behav
FROM tmp_brood_units b
JOIN tmp_identity_candidates c
  ON c.brood_id = b.brood_id
JOIN FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES m
  ON m.identity_key = c.identity_key
 AND m.sex = c.sex
 AND m.is_ambiguous_match = 0
 AND m.identity_key NOT LIKE 'xx:%'
 AND m.observation_date > b.anchor_date
 AND m.observation_date <= b.reference_date;

ALTER TABLE tmp_parent_events_raw
  ADD INDEX idx_tmp_parent_events_brood (brood_id),
  ADD INDEX idx_tmp_parent_events_brood_date (brood_id, observation_date),
  ADD INDEX idx_tmp_parent_events_identity (identity_key);

CREATE TEMPORARY TABLE tmp_parent_events AS
SELECT
  raw.*,
  CASE WHEN raw.behav REGEXP
    '(^|[,[:space:]])(BC|FC|AC)([,[:space:]]|$)'
    THEN 1 ELSE 0 END AS has_positive_brood_behaviour,
  CASE WHEN raw.behav REGEXP
    '(^|[,[:space:]])(IN|NM|SC)([,[:space:]]|$)'
    THEN 1 ELSE 0 END AS has_nest_restart_behaviour,
  CASE WHEN raw.behav REGEXP
    '(^|[,[:space:]])(FA|FM|FF|RS|LF|AT|FT|OB)([,[:space:]]|$)'
    THEN 1 ELSE 0 END AS has_strong_negative_behaviour,
  CASE WHEN raw.behav REGEXP
    '(^|[,[:space:]])BW([,[:space:]]|$)'
    THEN 1 ELSE 0 END AS has_bw_behaviour
FROM tmp_parent_events_raw raw;

ALTER TABLE tmp_parent_events
  ADD INDEX idx_tmp_parent_events_brood_sex (brood_id, sex),
  ADD INDEX idx_tmp_parent_events_observed_nest (observed_nest_id),
  ADD INDEX idx_tmp_parent_events_date (observation_date);

CREATE TEMPORARY TABLE tmp_parent_evidence_summary AS
SELECT
  events.brood_id,
  COUNT(DISTINCT CASE
    WHEN events.sex = 'M'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 0
     AND (
       events.has_strong_negative_behaviour = 1
       OR events.has_bw_behaviour = 1
     )
    THEN events.resighting_pk END
  ) AS M_evidence_count,
  COUNT(DISTINCT CASE
    WHEN events.sex = 'F'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 0
     AND (
       events.has_strong_negative_behaviour = 1
       OR events.has_bw_behaviour = 1
     )
    THEN events.resighting_pk END
  ) AS F_evidence_count,
  COUNT(DISTINCT CASE
    WHEN events.sex = 'M'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 0
     AND (
       events.has_strong_negative_behaviour = 1
       OR events.has_bw_behaviour = 1
     )
    THEN events.observation_date END
  ) AS M_negative_observation_dates,
  COUNT(DISTINCT CASE
    WHEN events.sex = 'F'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 0
     AND (
       events.has_strong_negative_behaviour = 1
       OR events.has_bw_behaviour = 1
     )
    THEN events.observation_date END
  ) AS F_negative_observation_dates,
  COUNT(DISTINCT CASE
    WHEN events.sex = 'M' AND events.observed_nest_id = events.brood_id
    THEN events.observation_date END
  ) AS M_distinct_observation_dates,
  COUNT(DISTINCT CASE
    WHEN events.sex = 'F' AND events.observed_nest_id = events.brood_id
    THEN events.observation_date END
  ) AS F_distinct_observation_dates,
  SUM(CASE WHEN events.sex = 'M'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 0
     AND events.has_strong_negative_behaviour = 1
    THEN 1 ELSE 0 END) AS M_strong_negative_count,
  SUM(CASE WHEN events.sex = 'F'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 0
     AND events.has_strong_negative_behaviour = 1
    THEN 1 ELSE 0 END) AS F_strong_negative_count,
  SUM(CASE WHEN events.sex = 'M'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 0
     AND events.has_strong_negative_behaviour = 0
     AND events.has_bw_behaviour = 1
    THEN 1 ELSE 0 END) AS M_weak_bw_count,
  SUM(CASE WHEN events.sex = 'F'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 0
     AND events.has_strong_negative_behaviour = 0
     AND events.has_bw_behaviour = 1
    THEN 1 ELSE 0 END) AS F_weak_bw_count,
  SUM(CASE WHEN events.sex = 'M'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 1
    THEN 1 ELSE 0 END) AS M_positive_brood_count,
  SUM(CASE WHEN events.sex = 'F'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 1
    THEN 1 ELSE 0 END) AS F_positive_brood_count,
  SUM(CASE WHEN events.sex = 'M'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 1
    THEN 1 ELSE 0 END) AS M_nest_restart_count,
  SUM(CASE WHEN events.sex = 'F'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 1
    THEN 1 ELSE 0 END) AS F_nest_restart_count,
  MAX(CASE WHEN events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 1
    THEN events.observation_date END) AS latest_positive_brood_date,
  MAX(CASE WHEN events.sex = 'M'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 0
     AND (
       events.has_strong_negative_behaviour = 1
       OR events.has_bw_behaviour = 1
     )
    THEN events.observation_date END) AS M_last_negative_date,
  MAX(CASE WHEN events.sex = 'F'
     AND events.observed_nest_id = events.brood_id
     AND events.has_positive_brood_behaviour = 0
     AND events.has_nest_restart_behaviour = 0
     AND (
       events.has_strong_negative_behaviour = 1
       OR events.has_bw_behaviour = 1
     )
    THEN events.observation_date END) AS F_last_negative_date
FROM tmp_parent_events events
GROUP BY events.brood_id;

ALTER TABLE tmp_parent_evidence_summary
  ADD PRIMARY KEY (brood_id);

/*
  Canonical positive-nest locations for the spatial audit.  Coordinates come
  only from NESTS -> GPS_POINTS links; brood/resighting locations are never
  used here.  The selection order matches NESTS_LATEST: an S record is
  preferred, then F, then the earliest valid nest-linked GPS record.
*/
CREATE TEMPORARY TABLE tmp_nest_locations AS
SELECT
  locations.nest_id,
  locations.lat,
  locations.lon
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
  CROSS JOIN (
    SELECT value AS reference_date
    FROM FIELD_2026_BADOatNZ.settings
    WHERE variable = 'reference_date'
      AND value IS NOT NULL
  ) sr
  WHERE UPPER(TRIM(COALESCE(n.site, ''))) = 'CR'
    AND n.nest_id IS NOT NULL
    AND TRIM(n.nest_id) <> ''
    AND UPPER(TRIM(n.nest_id)) <> 'NO_NEST'
    AND LEFT(TRIM(n.nest_id), 1) <> '-'
    AND n.date <= sr.reference_date
    AND g.lat IS NOT NULL
    AND g.lon IS NOT NULL
) locations
WHERE locations.row_num = 1;

ALTER TABLE tmp_nest_locations
  ADD PRIMARY KEY (nest_id);

/*
  Later positive-nest evidence is deliberately independent of the conservative
  two-by-two pathway. A selected high-confidence association is sufficient
  for a single-parent trigger. The identity-match branch is retained only so
  that two former parents can be recognized at the same later nest; it must
  not create a single-parent trigger. The authoritative association and
  identity layers supply the parent identity and sex. NESTS supplies the later
  positive-nest history and date. Here "positive" means a nonnegative,
  non-NO_NEST CR nest_id in NESTS history; no nest-state or IN/NM/SC behaviour
  requirement is applied here.
*/
CREATE TEMPORARY TABLE tmp_later_nest_evidence_raw AS
SELECT
  b.brood_id,
  later_assoc.sex AS later_parent_sex,
  later_assoc.identity_key AS later_parent_identity,
  later_assoc.parent_mark AS later_parent_mark,
  later_assoc.nest_id AS later_nest_id,
  MIN(later_nest.date) AS later_nest_date,
  'authoritative parent association + later positive NESTS history'
    AS evidence_source,
  'authoritative_selected' AS evidence_type
FROM tmp_brood_units b
JOIN tmp_identity_candidates prior
  ON prior.brood_id = b.brood_id
 AND prior.identity_confidence = 'high'
JOIN FIELD_2026_BADOatNZ.ADULT_PARENT_NEST_ASSOCIATIONS later_assoc
  ON later_assoc.identity_key = prior.identity_key
 AND later_assoc.sex = prior.sex
 AND later_assoc.association_selected = 1
 AND later_assoc.association_ambiguous = 0
 AND later_assoc.identity_key NOT LIKE 'xx:%'
 AND later_assoc.nest_id IS NOT NULL
 AND TRIM(later_assoc.nest_id) <> ''
 AND UPPER(TRIM(later_assoc.nest_id)) <> 'NO_NEST'
 AND LEFT(TRIM(later_assoc.nest_id), 1) <> '-'
 AND later_assoc.nest_id <> b.brood_id
JOIN FIELD_2026_BADOatNZ.NESTS later_nest
  ON later_nest.nest_id = later_assoc.nest_id
 AND UPPER(TRIM(COALESCE(later_nest.site, ''))) = 'CR'
 AND later_nest.date > b.anchor_date
 AND later_nest.date <= b.reference_date
GROUP BY
  b.brood_id,
  later_assoc.sex,
  later_assoc.identity_key,
  later_assoc.parent_mark,
  later_assoc.nest_id

UNION

/*
  Audit-only identity evidence. ADULT_PARENT_NEST_ASSOCIATIONS can leave a
  uniquely ring-matched parent outside the selected later-nest identity when
  the full fieldworker parent-association gates have not selected it, or when
  another identity wins the later-nest selection. This branch is retained only
  to detect two former parents at the same later nest; it cannot trigger a
  single-parent closure. It does not change the authoritative
  parent-association view or any production task source.
*/
SELECT
  b.brood_id,
  later_identity.sex AS later_parent_sex,
  later_identity.identity_key AS later_parent_identity,
  later_identity.display_mark AS later_parent_mark,
  later_identity.nest_id AS later_nest_id,
  MIN(later_nest.date) AS later_nest_date,
  'unambiguous adult identity match + later positive NESTS history'
    AS evidence_source,
  'identity_match' AS evidence_type
FROM tmp_brood_units b
JOIN tmp_identity_candidates prior
  ON prior.brood_id = b.brood_id
 AND prior.identity_confidence IN ('high', 'medium')
JOIN FIELD_2026_BADOatNZ.ADULT_IDENTITY_MATCHES later_identity
  ON later_identity.identity_key = prior.identity_key
 AND later_identity.sex = prior.sex
 AND later_identity.is_ambiguous_match = 0
 AND COALESCE(later_identity.n_candidate_identities, 0) = 1
 AND later_identity.identity_key IS NOT NULL
 AND later_identity.identity_key NOT LIKE 'xx:%'
 AND later_identity.nest_id IS NOT NULL
 AND TRIM(later_identity.nest_id) <> ''
 AND UPPER(TRIM(later_identity.nest_id)) <> 'NO_NEST'
 AND LEFT(TRIM(later_identity.nest_id), 1) <> '-'
 AND later_identity.nest_id <> b.brood_id
 AND later_identity.observation_date > b.anchor_date
 AND later_identity.observation_date <= b.reference_date
JOIN FIELD_2026_BADOatNZ.NESTS later_nest
  ON later_nest.nest_id = later_identity.nest_id
 AND UPPER(TRIM(COALESCE(later_nest.site, ''))) = 'CR'
 AND later_nest.date > b.anchor_date
 AND later_nest.date <= b.reference_date
GROUP BY
  b.brood_id,
  later_identity.sex,
  later_identity.identity_key,
  later_identity.display_mark,
  later_identity.nest_id;

/* Add nest-to-nest distance without exposing either coordinate. */
CREATE TEMPORARY TABLE tmp_later_nest_evidence AS
SELECT
  distances.*,
  CASE
    WHEN distances.nest_distance_m IS NOT NULL
     AND distances.nest_distance_m <= 100
    THEN 1 ELSE 0
  END AS nests_within_100m
FROM (
  SELECT
    raw.*,
    CASE
      WHEN origin.lat BETWEEN -90 AND 90
       AND origin.lon BETWEEN -180 AND 180
       AND later_location.lat BETWEEN -90 AND 90
       AND later_location.lon BETWEEN -180 AND 180
      THEN ROUND(
        6371000 * 2 * ASIN(
          SQRT(
            POW(
              SIN(RADIANS(later_location.lat - origin.lat) / 2),
              2
            )
            + COS(RADIANS(origin.lat))
              * COS(RADIANS(later_location.lat))
              * POW(
                  SIN(RADIANS(later_location.lon - origin.lon) / 2),
                  2
                )
          )
        ),
        1
      )
      ELSE NULL
    END AS nest_distance_m
  FROM tmp_later_nest_evidence_raw raw
  LEFT JOIN tmp_nest_locations origin
    ON CONVERT(origin.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(raw.brood_id USING utf8mb4) COLLATE utf8mb4_general_ci
  LEFT JOIN tmp_nest_locations later_location
    ON CONVERT(later_location.nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
       = CONVERT(raw.later_nest_id USING utf8mb4) COLLATE utf8mb4_general_ci
) distances;

DROP TEMPORARY TABLE tmp_later_nest_evidence_raw;

ALTER TABLE tmp_later_nest_evidence
  ADD INDEX idx_tmp_later_nest_evidence_brood (brood_id),
  ADD INDEX idx_tmp_later_nest_evidence_nest (later_nest_id),
  ADD INDEX idx_tmp_later_nest_evidence_identity (later_parent_identity);

/*
  Spatial corroboration for parent-linked later-nest evidence.  This
  deliberately uses positive NESTS history, not brood or resighting
  locations.  A later nest must already be linked to at least one former
  parent by the corrected parent-evidence layer; the nest-to-nest distance is
  then reported as additional support when it is <= 100 m.  Nearby nests that
  belong to unrelated pairs must not create a presumed-dead candidate by
  themselves.
*/
CREATE TEMPORARY TABLE tmp_spatial_later_nest_evidence AS
SELECT
  evidence.brood_id,
  evidence.later_nest_id,
  MIN(evidence.later_nest_date) AS later_nest_date,
  MIN(evidence.nest_distance_m) AS nest_distance_m
FROM tmp_later_nest_evidence evidence
WHERE evidence.nests_within_100m = 1
GROUP BY
  evidence.brood_id,
  evidence.later_nest_id;

ALTER TABLE tmp_spatial_later_nest_evidence
  ADD INDEX idx_tmp_spatial_later_nest_brood (brood_id),
  ADD INDEX idx_tmp_spatial_later_nest_nest (later_nest_id);

CREATE TEMPORARY TABLE tmp_spatial_later_nest_summary AS
SELECT
  evidence.brood_id,
  1 AS spatial_later_nest_trigger,
  MIN(evidence.later_nest_date) AS spatial_later_nest_date,
  GROUP_CONCAT(DISTINCT evidence.later_nest_id
    ORDER BY evidence.later_nest_id SEPARATOR ', ') AS spatial_later_nest_ids,
  MIN(evidence.nest_distance_m) AS nearest_spatial_nest_distance_m,
  COUNT(DISTINCT evidence.later_nest_id) AS spatial_later_nest_count
FROM tmp_spatial_later_nest_evidence evidence
GROUP BY evidence.brood_id;

ALTER TABLE tmp_spatial_later_nest_summary
  ADD PRIMARY KEY (brood_id);

CREATE TEMPORARY TABLE tmp_later_nest_parent_counts AS
SELECT
  evidence.brood_id,
  evidence.later_nest_id,
  COUNT(DISTINCT CASE
    WHEN evidence.evidence_type = 'authoritative_selected'
    THEN CONCAT(
      evidence.later_parent_sex,
      ':',
      evidence.later_parent_identity
    )
  END) AS authoritative_parent_count_at_nest,
  COUNT(DISTINCT CONCAT(
    evidence.later_parent_sex,
    ':',
    evidence.later_parent_identity
  )) AS parent_count_at_nest
FROM tmp_later_nest_evidence evidence
GROUP BY evidence.brood_id, evidence.later_nest_id;

ALTER TABLE tmp_later_nest_parent_counts
  ADD PRIMARY KEY (brood_id, later_nest_id);

CREATE TEMPORARY TABLE tmp_later_nest_summary AS
SELECT
  evidence.brood_id,
  MAX(CASE
    WHEN parent_counts.authoritative_parent_count_at_nest >= 1
      OR parent_counts.parent_count_at_nest >= 2
    THEN 1 ELSE 0
  END) AS later_nest_trigger,
  MIN(evidence.later_nest_date) AS later_nest_date,
  GROUP_CONCAT(DISTINCT evidence.later_nest_id
    ORDER BY evidence.later_nest_id SEPARATOR ', ') AS later_nest_ids,
  GROUP_CONCAT(DISTINCT evidence.later_parent_sex
    ORDER BY evidence.later_parent_sex SEPARATOR ',') AS later_nest_parent_sexes,
  GROUP_CONCAT(DISTINCT evidence.later_parent_identity
    ORDER BY evidence.later_parent_identity SEPARATOR '; ') AS later_nest_parent_identities,
  GROUP_CONCAT(DISTINCT evidence.later_parent_mark
    ORDER BY evidence.later_parent_mark SEPARATOR '; ') AS later_nest_parent_marks,
  GROUP_CONCAT(DISTINCT CONCAT(
      evidence.later_parent_sex,
      ':',
      evidence.later_parent_identity
    ) ORDER BY evidence.later_parent_sex, evidence.later_parent_identity
    SEPARATOR '; ') AS later_nest_parent_detail,
  GROUP_CONCAT(DISTINCT CONCAT(
      evidence.later_nest_id,
      ' | ',
      DATE_FORMAT(evidence.later_nest_date, '%Y-%m-%d'),
      ' | ',
      evidence.later_parent_sex,
      ':',
      evidence.later_parent_identity
    ) ORDER BY evidence.later_nest_date, evidence.later_nest_id,
      evidence.later_parent_sex, evidence.later_parent_identity
    SEPARATOR '; ') AS later_nest_evidence_detail,
  GROUP_CONCAT(DISTINCT evidence.evidence_source
    ORDER BY evidence.evidence_source SEPARATOR '; ') AS later_nest_evidence_sources,
  MIN(evidence.nest_distance_m) AS nearest_later_nest_distance_m,
  MAX(evidence.nests_within_100m) AS any_later_nest_within_100m,
  COUNT(DISTINCT CONCAT(
    evidence.later_parent_sex,
    ':',
    evidence.later_parent_identity
  )) AS later_nest_parent_count,
  MAX(parent_counts.authoritative_parent_count_at_nest)
    AS later_nest_authoritative_parent_count_at_nest,
  MAX(parent_counts.parent_count_at_nest)
    AS later_nest_parent_count_at_nest
FROM tmp_later_nest_evidence evidence
JOIN tmp_later_nest_parent_counts parent_counts
  ON parent_counts.brood_id = evidence.brood_id
 AND parent_counts.later_nest_id = evidence.later_nest_id
GROUP BY evidence.brood_id;

ALTER TABLE tmp_later_nest_summary
  ADD PRIMARY KEY (brood_id);

/*
  Report task values still present for the old brood at the current snapshot.
  This is intentionally task-level only: notes, marks, and coordinates are
  not copied into the audit output.
*/
CREATE TEMPORARY TABLE tmp_remaining_todo AS
SELECT
  tasks.nest_id AS brood_id,
  COUNT(*) AS remaining_todo_count,
  GROUP_CONCAT(DISTINCT tasks.todo ORDER BY tasks.todo SEPARATOR '; ')
    AS remaining_todo_values
FROM FIELD_2026_BADOatNZ.TODO_LIST tasks
JOIN tmp_brood_units b
  ON b.brood_id = tasks.nest_id
WHERE tasks.reference_date = b.reference_date
GROUP BY tasks.nest_id;

ALTER TABLE tmp_remaining_todo
  ADD PRIMARY KEY (brood_id);

CREATE TEMPORARY TABLE tmp_closure_candidates AS
SELECT
  b.*,
  i.M_identity_confidence,
  i.F_identity_confidence,
  i.M_identity_count,
  i.F_identity_count,
  COALESCE(e.M_evidence_count, 0) AS M_evidence_count,
  COALESCE(e.F_evidence_count, 0) AS F_evidence_count,
  COALESCE(e.M_negative_observation_dates, 0)
    AS M_negative_observation_dates,
  COALESCE(e.F_negative_observation_dates, 0)
    AS F_negative_observation_dates,
  COALESCE(e.M_distinct_observation_dates, 0)
    AS M_distinct_observation_dates,
  COALESCE(e.F_distinct_observation_dates, 0)
    AS F_distinct_observation_dates,
  COALESCE(e.M_strong_negative_count, 0) AS M_strong_negative_count,
  COALESCE(e.F_strong_negative_count, 0) AS F_strong_negative_count,
  COALESCE(e.M_weak_bw_count, 0) AS M_weak_bw_count,
  COALESCE(e.F_weak_bw_count, 0) AS F_weak_bw_count,
  COALESCE(e.M_positive_brood_count, 0) AS M_positive_brood_count,
  COALESCE(e.F_positive_brood_count, 0) AS F_positive_brood_count,
  COALESCE(e.M_nest_restart_count, 0) AS M_nest_restart_count,
  COALESCE(e.F_nest_restart_count, 0) AS F_nest_restart_count,
  e.latest_positive_brood_date,
  e.M_last_negative_date,
  e.F_last_negative_date,
  COALESCE(n.later_nest_trigger, 0) AS later_nest_trigger,
  n.later_nest_date,
  n.later_nest_ids,
  n.later_nest_parent_sexes,
  n.later_nest_parent_identities,
  n.later_nest_parent_marks,
  n.later_nest_parent_detail,
  n.later_nest_evidence_detail,
  n.later_nest_evidence_sources,
  n.nearest_later_nest_distance_m,
  COALESCE(n.any_later_nest_within_100m, 0)
    AS any_later_nest_within_100m,
  COALESCE(n.later_nest_parent_count, 0) AS later_nest_parent_count,
  COALESCE(n.later_nest_authoritative_parent_count_at_nest, 0)
    AS later_nest_authoritative_parent_count_at_nest,
  COALESCE(n.later_nest_parent_count_at_nest, 0)
    AS later_nest_parent_count_at_nest,
  COALESCE(spatial_nest.spatial_later_nest_trigger, 0)
    AS spatial_later_nest_trigger,
  spatial_nest.spatial_later_nest_date,
  spatial_nest.spatial_later_nest_ids,
  spatial_nest.nearest_spatial_nest_distance_m,
  COALESCE(spatial_nest.spatial_later_nest_count, 0)
    AS spatial_later_nest_count,
  CASE
    WHEN COALESCE(n.later_nest_trigger, 0) = 1
     AND COALESCE(n.later_nest_parent_count_at_nest, 0) >= 2
    THEN 'both confidently identified former parents'
    WHEN COALESCE(n.later_nest_trigger, 0) = 1
     AND COALESCE(n.later_nest_authoritative_parent_count_at_nest, 0) >= 1
    THEN 'one authoritative former parent'
    ELSE NULL
  END AS later_nest_evidence_strength,
  COALESCE(t.remaining_todo_count, 0) AS remaining_todo_count,
  t.remaining_todo_values,
  CASE
    WHEN b.age_qualified = 1
     AND i.M_identity_confidence = 'high'
     AND i.F_identity_confidence = 'high'
     AND COALESCE(e.M_negative_observation_dates, 0) >= 2
     AND COALESCE(e.F_negative_observation_dates, 0) >= 2
     AND COALESCE(e.M_strong_negative_count, 0) >= 1
     AND COALESCE(e.F_strong_negative_count, 0) >= 1
     AND (
       e.latest_positive_brood_date IS NULL
       OR e.latest_positive_brood_date < LEAST(
         e.M_last_negative_date,
         e.F_last_negative_date
       )
     )
    THEN 1 ELSE 0
  END AS two_by_two_trigger,
  CASE
    WHEN COALESCE(n.later_nest_trigger, 0) = 1
    THEN n.later_nest_date
    WHEN b.age_qualified = 1
     AND i.M_identity_confidence = 'high'
     AND i.F_identity_confidence = 'high'
     AND COALESCE(e.M_negative_observation_dates, 0) >= 2
     AND COALESCE(e.F_negative_observation_dates, 0) >= 2
     AND COALESCE(e.M_strong_negative_count, 0) >= 1
     AND COALESCE(e.F_strong_negative_count, 0) >= 1
     AND (
       e.latest_positive_brood_date IS NULL
       OR e.latest_positive_brood_date < LEAST(
         e.M_last_negative_date,
         e.F_last_negative_date
       )
     )
    THEN GREATEST(e.M_last_negative_date, e.F_last_negative_date)
    ELSE NULL
  END AS closure_candidate_date
FROM tmp_brood_units b
JOIN tmp_identity_summary i
  ON i.brood_id = b.brood_id
LEFT JOIN tmp_parent_evidence_summary e
  ON e.brood_id = b.brood_id
  LEFT JOIN tmp_later_nest_summary n
  ON n.brood_id = b.brood_id
LEFT JOIN tmp_spatial_later_nest_summary spatial_nest
  ON spatial_nest.brood_id = b.brood_id
LEFT JOIN tmp_remaining_todo t
  ON t.brood_id = b.brood_id;

ALTER TABLE tmp_closure_candidates
  ADD PRIMARY KEY (brood_id),
  ADD INDEX idx_tmp_closure_candidate_date (closure_candidate_date);

CREATE TEMPORARY TABLE tmp_reactivation_events AS
SELECT
  c.brood_id,
  c.closure_candidate_date,
  'age-C CAPTURES' AS evidence_source,
  captures.date AS evidence_date
FROM tmp_closure_candidates c
JOIN FIELD_2026_BADOatNZ.CAPTURES captures
  ON captures.nest_id = c.brood_id
 AND captures.age = 'C'
 AND UPPER(TRIM(COALESCE(captures.site, ''))) = 'CR'
 AND captures.date > c.closure_candidate_date
 AND captures.date <= c.reference_date
WHERE c.closure_candidate_date IS NOT NULL

UNION

SELECT
  c.brood_id,
  c.closure_candidate_date,
  'age-C RESIGHTINGS' AS evidence_source,
  resightings.date AS evidence_date
FROM tmp_closure_candidates c
JOIN FIELD_2026_BADOatNZ.RESIGHTINGS resightings
  ON resightings.nest_id = c.brood_id
 AND resightings.age = 'C'
 AND UPPER(TRIM(COALESCE(resightings.site, ''))) = 'CR'
 AND resightings.date > c.closure_candidate_date
 AND resightings.date <= c.reference_date
WHERE c.closure_candidate_date IS NOT NULL

UNION

SELECT
  c.brood_id,
  c.closure_candidate_date,
  'resolved H photo' AS evidence_source,
  resightings.date AS evidence_date
FROM tmp_closure_candidates c
JOIN FIELD_2026_BADOatNZ.RESIGHTINGS_H_BROOD_ASSOCIATIONS h
  ON h.resolved_nest_id = c.brood_id
JOIN FIELD_2026_BADOatNZ.RESIGHTINGS resightings
  ON resightings.pk = h.resighting_pk
 AND resightings.age = 'C'
 AND resightings.date > c.closure_candidate_date
 AND resightings.date <= c.reference_date
WHERE c.closure_candidate_date IS NOT NULL

UNION

SELECT
  c.brood_id,
  c.closure_candidate_date,
  'adult capture with C link' AS evidence_source,
  captures.date AS evidence_date
FROM tmp_closure_candidates c
JOIN FIELD_2026_BADOatNZ.CAPTURES captures
  ON captures.nest_id = c.brood_id
 AND captures.age = 'A'
 AND UPPER(TRIM(COALESCE(captures.site, ''))) = 'CR'
 AND captures.caught_with REGEXP
   '(^|[,[:space:]])[0-9]*C([,[:space:]]|$)'
 AND captures.date > c.closure_candidate_date
 AND captures.date <= c.reference_date
WHERE c.closure_candidate_date IS NOT NULL

UNION

SELECT
  c.brood_id,
  c.closure_candidate_date,
  'age-C GPS parent link' AS evidence_source,
  links.capture_date AS evidence_date
FROM tmp_closure_candidates c
JOIN FIELD_2026_BADOatNZ.ADULT_CHICK_GPS_PARENT_LINKS_INPUT links
  ON links.nest_id = c.brood_id
 AND links.capture_date > c.closure_candidate_date
 AND links.capture_date <= c.reference_date
WHERE c.closure_candidate_date IS NOT NULL

UNION

SELECT
  c.brood_id,
  c.closure_candidate_date,
  'parent BC/FC/AC' AS evidence_source,
  events.observation_date AS evidence_date
FROM tmp_closure_candidates c
JOIN tmp_parent_events events
  ON events.brood_id = c.brood_id
 AND events.identity_confidence = 'high'
 AND events.observed_nest_id = c.brood_id
 AND events.has_positive_brood_behaviour = 1
 AND events.observation_date > c.closure_candidate_date
 AND events.observation_date <= c.reference_date
WHERE c.closure_candidate_date IS NOT NULL;

ALTER TABLE tmp_reactivation_events
  ADD INDEX idx_tmp_reactivation_brood (brood_id),
  ADD INDEX idx_tmp_reactivation_date (evidence_date);

CREATE TEMPORARY TABLE tmp_reactivation_summary AS
SELECT
  events.brood_id,
  COUNT(*) AS reactivation_evidence_count,
  MIN(events.evidence_date) AS first_reactivation_date,
  GROUP_CONCAT(DISTINCT events.evidence_source
    ORDER BY events.evidence_source SEPARATOR '; ') AS reactivation_evidence_sources
FROM tmp_reactivation_events events
GROUP BY events.brood_id;

ALTER TABLE tmp_reactivation_summary
  ADD PRIMARY KEY (brood_id);

CREATE TEMPORARY TABLE TODO_BROOD_CLOSURE_AUDIT AS
SELECT
  candidates.*,
  CONCAT(
    'M strong=', candidates.M_strong_negative_count,
    ', BW=', candidates.M_weak_bw_count,
    ', BC/FC/AC=', candidates.M_positive_brood_count,
    ', IN/NM/SC=', candidates.M_nest_restart_count,
    '; F strong=', candidates.F_strong_negative_count,
    ', BW=', candidates.F_weak_bw_count,
    ', BC/FC/AC=', candidates.F_positive_brood_count,
    ', IN/NM/SC=', candidates.F_nest_restart_count
  ) AS behaviour_strength_breakdown,
  CASE
    WHEN candidates.later_nest_trigger = 1
     AND candidates.two_by_two_trigger = 1
     AND candidates.later_nest_parent_count_at_nest >= 2
    THEN 'dual-parent renesting trigger + two-by-two evidence'
    WHEN candidates.later_nest_trigger = 1
     AND candidates.spatial_later_nest_trigger = 1
     AND candidates.later_nest_parent_count_at_nest >= 2
    THEN 'dual-parent renesting + spatial proximity'
    WHEN candidates.later_nest_trigger = 1
     AND candidates.two_by_two_trigger = 1
    THEN 'later nest trigger + two-by-two evidence'
    WHEN candidates.later_nest_trigger = 1
     AND candidates.later_nest_parent_count_at_nest >= 2
    THEN 'dual-parent renesting trigger'
    WHEN candidates.later_nest_trigger = 1
    THEN 'later nest trigger'
    WHEN candidates.two_by_two_trigger = 1
    THEN 'two-by-two post-hatch non-brood evidence'
    ELSE NULL
  END AS closure_reason,
  CASE
    WHEN candidates.later_nest_trigger = 1
      OR candidates.two_by_two_trigger = 1
    THEN 1 ELSE 0
  END AS presumed_dead_candidate,
  COALESCE(reactivation.reactivation_evidence_count, 0)
    AS reactivation_evidence_count,
  reactivation.first_reactivation_date,
  reactivation.reactivation_evidence_sources,
  CASE WHEN reactivation.reactivation_evidence_count IS NOT NULL
    THEN 1 ELSE 0 END AS would_reactivate,
  CASE
    WHEN (
      candidates.later_nest_trigger = 1
      OR candidates.two_by_two_trigger = 1
    ) AND reactivation.reactivation_evidence_count IS NOT NULL
    THEN 'reactivated_after_candidate'
    WHEN candidates.later_nest_trigger = 1
      OR candidates.two_by_two_trigger = 1
    THEN 'presumed_dead_candidate'
    ELSE 'insufficient_evidence'
  END AS audit_status
FROM tmp_closure_candidates candidates
LEFT JOIN tmp_reactivation_summary reactivation
  ON reactivation.brood_id = candidates.brood_id;

ALTER TABLE TODO_BROOD_CLOSURE_AUDIT
  ADD PRIMARY KEY (brood_id),
  ADD INDEX idx_todo_brood_closure_status (audit_status),
  ADD INDEX idx_todo_brood_closure_candidate (presumed_dead_candidate);

/*
  Population audit. These counts explain why the detailed result may contain
  fewer presumed-dead candidates than the number of currently active broods.
  Later-nest eligibility is all-age; the >=21-day gate applies only to the
  conservative two-by-two pathway.
*/
CREATE TEMPORARY TABLE tmp_brood_stage_summary AS
SELECT
  10 AS stage_order,
  'snapshot brood rows' AS stage_name,
  COUNT(*) AS brood_count,
  'BROODS_LATEST rows at the settings reference date' AS stage_definition
FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
CROSS JOIN (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
) sr
WHERE b.reference_date = sr.reference_date

UNION ALL

SELECT
  20,
  'anchored brood rows',
  COUNT(*),
  'Snapshot rows with a hatch or discovery anchor date'
FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
CROSS JOIN (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
) sr
WHERE b.reference_date = sr.reference_date
  AND COALESCE(b.hatch_evidence_date, b.discovery_date) IS NOT NULL

UNION ALL

SELECT
  30,
  'hatch-or-negative anchored rows',
  COUNT(*),
  'Anchored rows that are positive with hatch evidence or are negative broods'
FROM FIELD_2026_BADOatNZ.BROODS_LATEST b
CROSS JOIN (
  SELECT value AS reference_date
  FROM FIELD_2026_BADOatNZ.settings
  WHERE variable = 'reference_date'
    AND value IS NOT NULL
) sr
WHERE b.reference_date = sr.reference_date
  AND (b.is_negative_brood = 1 OR b.has_hatch_evidence = 1)
  AND COALESCE(b.hatch_evidence_date, b.discovery_date) IS NOT NULL

UNION ALL

SELECT
  40,
  'all-age later-nest audit rows',
  COUNT(*),
  'Anchored hatch-positive or negative broods assessed for later positive-nest evidence at any age'
FROM tmp_brood_units

UNION ALL

SELECT
  50,
  'age-qualified two-by-two rows',
  COUNT(*),
  'Anchored rows whose hatch or discovery anchor is at least 21 days before the reference date'
FROM tmp_brood_units
WHERE age_qualified = 1

UNION ALL

SELECT
  60,
  'both-parent high-identity rows',
  COUNT(*),
  'All-age anchored rows with one selected high-confidence M and F identity'
FROM tmp_identity_summary
WHERE M_identity_confidence = 'high'
  AND F_identity_confidence = 'high'

UNION ALL

SELECT
  70,
  'two-by-two evidence rows',
  COUNT(*),
  'Age-qualified rows meeting the conservative two dates and one strong observation per parent gate'
FROM tmp_closure_candidates
WHERE two_by_two_trigger = 1

UNION ALL

SELECT
  80,
  'later-nest trigger rows',
  COUNT(*),
  'All-age rows with a selected high-confidence parent association at later positive NESTS history'
FROM tmp_closure_candidates
WHERE later_nest_trigger = 1

UNION ALL

SELECT
  85,
  'dual-parent renesting rows',
  COUNT(*),
  'All-age rows where both former parent identities match the same later positive nest'
FROM tmp_closure_candidates
WHERE later_nest_trigger = 1
  AND later_nest_parent_count_at_nest >= 2

UNION ALL

SELECT
  87,
  'parent-linked later-nest rows within 100 m',
  COUNT(*),
  'All-age rows with parent-linked later positive NESTS evidence whose nest location is within 100 m of the original positive nest'
FROM tmp_closure_candidates
WHERE spatial_later_nest_trigger = 1

UNION ALL

SELECT
  90,
  'presumed-dead candidate rows',
  COUNT(*),
  'Rows meeting the two-by-two or corrected parent-supported later-nest rule; spatial proximity is corroborative only'
FROM TODO_BROOD_CLOSURE_AUDIT
WHERE presumed_dead_candidate = 1

UNION ALL

SELECT
  100,
  'reactivated candidate rows',
  COUNT(*),
  'Candidate rows with later direct or linked positive brood evidence'
FROM TODO_BROOD_CLOSURE_AUDIT
WHERE audit_status = 'reactivated_after_candidate'

UNION ALL

SELECT
  110,
  'unreactivated presumed-dead rows',
  COUNT(*),
  'Candidate rows remaining after the reactivation check'
FROM TODO_BROOD_CLOSURE_AUDIT
WHERE audit_status = 'presumed_dead_candidate';

/* Summary output: counts only; no raw event rows or GPS fields. */
SELECT
  stage_order,
  stage_name,
  brood_count,
  stage_definition
FROM tmp_brood_stage_summary
ORDER BY stage_order;

/* Detailed output: aggregate evidence only; no raw event rows or GPS fields. */
SELECT *
FROM TODO_BROOD_CLOSURE_AUDIT
ORDER BY presumed_dead_candidate DESC, brood_id;
