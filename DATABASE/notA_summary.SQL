/*
  Historical notA nest/parent register for the app's notA_summary tab.

  Install this small, optional view AFTER the first successful To-do snapshot
  refresh. Its two published snapshot tables are created by that refresh, not
  by a clean views.SQL install. Do not rerun the large views/refresh scripts
  merely to install this report. Subsequent successful refreshes update it via
  the existing atomic snapshot publication; no new table or refresh stage is
  needed. This file creates/replaces only notA_summary and changes no records.

  Scope follows the current authoritative parent engine: BADO, Cass River,
  current field database, bounded by settings.reference_date. A row represents
  a nest whose latest published NESTS visit is notA, NOT a presumed-dead brood.
  Hatched broods can still be alive and have outstanding tasks elsewhere.

  Parent marks and pending details are kept separate. A historical dead parent
  remains a historical parent; death does not erase its confirmed association.
  Later links require the same selected, unambiguous identity and sex at both
  nests. X-X and event-only/shared single-colour identities never link nests.
  A lower-band-only key qualifies only for a complete classic two-colour band
  on each leg, with both displayed marks matching that full four-colour key.
  Spacer-dependent or partial lower keys require a ring/flag identity instead.
  "Later" means a strictly later recorded first-found date, not a claim about
  lay date, current activity, or proof that formal notA preceded renesting.
  Multiple later confirmed nests are retained, rather than arbitrarily picking
  one. No handwritten sheet links or comments are imported.

  Empty/stale/in-progress snapshot state returns no rows rather than mixing
  live associations with old published context. The app explains this boundary.
  Rollback: DROP VIEW FIELD_2026_BADOatNZ.notA_summary; and restore the old tab.
*/
SET SESSION lock_wait_timeout = 30;

CREATE OR REPLACE ALGORITHM = TEMPTABLE VIEW FIELD_2026_BADOatNZ.notA_summary AS
WITH published AS (
  SELECT status.reference_date
  FROM FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS status
  JOIN FIELD_2026_BADOatNZ.settings settings
    ON settings.variable = 'reference_date'
   AND status.reference_date = settings.value
  WHERE status.refresh_id = (
      SELECT MAX(latest.refresh_id)
      FROM FIELD_2026_BADOatNZ.TODO_REFRESH_STATUS latest
    )
    AND status.state = 'succeeded'
    AND status.completed_at IS NOT NULL
), nests AS (
  SELECT context.*
  FROM FIELD_2026_BADOatNZ.TODO_NEST_CONTEXT_SNAPSHOT context
  JOIN published ON published.reference_date = context.reference_date
  WHERE UPPER(TRIM(context.species)) = 'BADO'
), sexes AS (
  SELECT 'M' AS sex
  UNION ALL
  SELECT 'F'
), parent_fields AS (
  SELECT
    nest.nest_id,
    nest.reference_date,
    nest.first_found_date,
    sexes.sex,
    CASE sexes.sex WHEN 'M' THEN status.M_selected_identity_key
      ELSE status.F_selected_identity_key END AS identity_key,
    CASE sexes.sex WHEN 'M' THEN status.M_selected_mark
      ELSE status.F_selected_mark END AS selected_mark,
    CASE sexes.sex WHEN 'M' THEN status.M_confirmed_unbanded
      ELSE status.F_confirmed_unbanded END AS confirmed_unbanded,
    CASE sexes.sex WHEN 'M' THEN status.M_resight_association_pending
      ELSE status.F_resight_association_pending END AS association_pending,
    CASE sexes.sex WHEN 'M' THEN status.M_resight_association_ambiguous
      ELSE status.F_resight_association_ambiguous END AS association_ambiguous,
    CASE sexes.sex WHEN 'M' THEN status.M_mm_resight_pending
      ELSE status.F_mm_resight_pending END AS mm_pending,
    CASE sexes.sex WHEN 'M' THEN status.M_resighting_identity_count
      ELSE status.F_resighting_identity_count END AS identity_count,
    CASE sexes.sex WHEN 'M' THEN status.M_identity_single_colour_recruit
      ELSE status.F_identity_single_colour_recruit END AS single_colour_recruit,
    CASE sexes.sex WHEN 'M' THEN status.M_resight_association_details
      ELSE status.F_resight_association_details END AS pending_observations
  FROM nests nest
  CROSS JOIN sexes
  LEFT JOIN FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT status
    ON status.nest_id = nest.nest_id
   AND status.reference_date = nest.reference_date
), parents AS (
  SELECT
    fields.*,
    CASE
      WHEN COALESCE(fields.association_ambiguous, 0) <> 0 THEN 'ambiguous'
      WHEN COALESCE(fields.association_pending, 0) = 0
       AND COALESCE(fields.mm_pending, 0) = 0
       AND NULLIF(TRIM(fields.identity_key), '') IS NOT NULL
       AND UPPER(TRIM(fields.identity_key)) NOT IN ('NA', 'N/A', 'NULL')
       AND NULLIF(TRIM(fields.selected_mark), '') IS NOT NULL
       AND UPPER(TRIM(fields.selected_mark)) NOT IN ('X', 'XX', 'NA', 'N/A', 'NULL')
       AND fields.selected_mark NOT LIKE '%?%'
       AND (
         UPPER(TRIM(fields.selected_mark)) <> 'X-X'
         OR fields.confirmed_unbanded = 1
       )
       AND (
         UPPER(TRIM(fields.identity_key)) NOT LIKE 'XX:%'
         OR (UPPER(TRIM(fields.selected_mark)) = 'X-X'
             AND fields.confirmed_unbanded = 1)
       )
      THEN 'resolved'
      WHEN COALESCE(fields.association_pending, 0) <> 0
        OR COALESCE(fields.mm_pending, 0) <> 0
        OR COALESCE(fields.identity_count, 0) > 0
        OR NULLIF(TRIM(fields.pending_observations), '') IS NOT NULL
      THEN 'pending'
      ELSE 'unknown'
    END AS parent_status
  FROM parent_fields fields
), later_links AS (
  SELECT
    original.nest_id,
    original.reference_date,
    original.sex,
    GROUP_CONCAT(
      DISTINCT later.nest_id
      ORDER BY later.first_found_date, later.nest_id SEPARATOR ', '
    ) AS later_confirmed_nests
  FROM parents original
  JOIN parents later
    ON later.identity_key = original.identity_key
   AND later.sex = original.sex
   AND later.reference_date = original.reference_date
   AND later.nest_id <> original.nest_id
   AND later.first_found_date > original.first_found_date
   AND later.parent_status = 'resolved'
  WHERE original.parent_status = 'resolved'
    AND UPPER(TRIM(original.selected_mark)) <> 'X-X'
    AND UPPER(TRIM(later.selected_mark)) <> 'X-X'
    AND (
      original.identity_key LIKE 'ring:%'
      OR original.identity_key LIKE 'flag:%'
      OR (original.identity_key REGEXP '^lower:[OYWBRGL]{2}[|][OYWBRGL]{2}$'
          AND UPPER(TRIM(original.selected_mark)) =
              UPPER(REPLACE(SUBSTRING(original.identity_key, 7), '|', '-'))
          AND UPPER(TRIM(later.selected_mark)) =
              UPPER(REPLACE(SUBSTRING(later.identity_key, 7), '|', '-'))
          AND COALESCE(original.single_colour_recruit, 0) = 0
          AND COALESCE(later.single_colour_recruit, 0) = 0)
    )
  GROUP BY original.nest_id, original.reference_date, original.sex
)
SELECT
  nest.reference_date,
  nest.species,
  'CR' AS site,
  DATE(nest.last_visit_datetime) AS date,
  nest.nest_id,
  nest.nest_state,
  MAX(CASE WHEN parent.sex = 'M' AND parent.parent_status = 'resolved'
    THEN parent.selected_mark END) AS male,
  MAX(CASE WHEN parent.sex = 'M' THEN parent.parent_status END) AS male_status,
  MAX(CASE WHEN parent.sex = 'M' THEN parent.pending_observations END)
    AS male_pending_observations,
  MAX(CASE WHEN parent.sex = 'M' THEN links.later_confirmed_nests END)
    AS male_later_confirmed_nests,
  MAX(CASE WHEN parent.sex = 'F' AND parent.parent_status = 'resolved'
    THEN parent.selected_mark END) AS female,
  MAX(CASE WHEN parent.sex = 'F' THEN parent.parent_status END) AS female_status,
  MAX(CASE WHEN parent.sex = 'F' THEN parent.pending_observations END)
    AS female_pending_observations,
  MAX(CASE WHEN parent.sex = 'F' THEN links.later_confirmed_nests END)
    AS female_later_confirmed_nests,
  nest.observed_hatch_date
FROM nests nest
JOIN parents parent
  ON parent.nest_id = nest.nest_id
 AND parent.reference_date = nest.reference_date
LEFT JOIN later_links links
  ON links.nest_id = parent.nest_id
 AND links.reference_date = parent.reference_date
 AND links.sex = parent.sex
WHERE UPPER(TRIM(nest.nest_state)) = 'NOTA'
GROUP BY
  nest.reference_date, nest.species, nest.last_visit_datetime,
  nest.nest_id, nest.nest_state, nest.observed_hatch_date;
