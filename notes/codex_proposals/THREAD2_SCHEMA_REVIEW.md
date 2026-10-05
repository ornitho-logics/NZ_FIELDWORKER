# Thread 2 Schema Review: Current Database Architecture

Last refreshed: 2026-10-06

Status: tracked static handoff for future Database Architect work, reconciled
against `origin/main` commit `1617e84` and the current parent-association PR
candidate. The negative-brood implementation described below is now merged in
repository source. Neither that fact nor this memo proves that matching views
are deployed to the live database. This refresh used static source inspection
only, without a database connection or field-record access.

## October 2026 schema-layer update

- `BROODS_LATEST`, hiding-photo resolution, terminal brood handling, and the
  associated PDF/map consumers are merged in tracked source.
- `TODO_LIST` remains the main operational view and has since gained bounded
  PDF query planning, hatch chronology priorities, one-egg stabilization, and
  refined MM-parent chronology.
- The current PR candidate adds generic banded-parent association status and
  explicit MM alternate-parent resolution. It blocks capture/GEO eligibility
  while same-sex identity remains ambiguous and resolves an identity after one
  approved nest behaviour or three matching nest-linked resightings.
- These additions are view-layer changes only; they do not alter base-table DDL.

## Negative brood-ID architecture (2026-09-27)

This section is the current database contract for brood identifiers. It supersedes
any earlier implication that all brood work begins with a `NESTS` row. It was
derived by static review only; no database or dump was queried.

### Canonical identifier meanings

| Value in `nest_id` | Meaning | Allowed source tables | Location rule |
|---|---|---|---|
| Positive ID | A real, stationary nest/scrape. | `NESTS`, `EGGS`, `CAPTURES`, `RESIGHTINGS` | The `NESTS` history can supply a stationary fallback location. |
| Negative ID | A mobile brood of unknown origin, for example `-A0203`, `-B0204`, `-C0201`, or `-BA0202`. | `CAPTURES`, `RESIGHTINGS` only | Every event needs a direct `gps_id` + `gps_point`; there is no `NESTS` fallback. |
| `NO_NEST` | An event unrelated to any nest or brood. | `CAPTURES`, `RESIGHTINGS` | Direct GPS workflow; exclude from brood/nest identity logic. |

Do not rename `nest_id` during the field season. Negative IDs are not malformed
positive IDs and `NO_NEST` is not a negative brood. A negative ID represents one
shared unknown-origin brood and must be repeated on later parent/chick capture or
resighting events that are confidently associated with that brood. Each observed
individual remains a separate source-table event.

### Current capacity and controlled values

- `CAPTURES.nest_id` is `varchar(7)`; `-C0201` is six characters and `-BA0202`
  seven, so both fit exactly. `NESTS`, `EGGS`, and `RESIGHTINGS` use `varchar(8)`.
  No type widening is required for the stated methodology.
- `gps_id tinyint unsigned` and `gps_point int unsigned` are consistent across
  the event and GPS tables. Existing `(gps_id, gps_point)` keys support the GPS
  lookup; no GPS type or enum change is needed.
- `CAPTURES.age` and `RESIGHTINGS.age` both allow `C`; `RESIGHTINGS.rclass`
  already allows `H`; current sex enums are sufficient. No field or enum addition
  is required.
- A future ID longer than seven characters would require widening
  `CAPTURES.nest_id` first. Do not silently introduce one.

### Entry contract and source DDL alignment

`DATABASE/main_tables.SQL` now documents the following without changing any
column type or dropping compatibility fields:

- `NESTS` accepts only positive real-nest IDs and directs unknown-origin broods
  to `CAPTURES` or `RESIGHTINGS`; its GPS fields describe the stationary scrape.
- `EGGS` accepts only a positive known-nest ID. Negative broods have no egg
  history, and `NO_NEST` is invalid.
- `CAPTURES` and `RESIGHTINGS` allow a negative brood ID, require the paired
  direct GPS fields for it, and distinguish it from `NO_NEST`.
- `RESIGHTINGS.rclass = 'H'` is the hiding-spot-photo event: enter a chick as
  `age = 'C'`, with its metal `ring`, direct GPS, and photo endpoints. The raw
  `nest_id` may be blank under the approved advanced exception when an earlier
  chick `CAPTURES` link plus same-date/exact-GPS parent identities resolves one
  positive nest or negative brood uniquely. The nullable `ring` field is
  positioned after `LR` and before `sex`.
- CAPTURES image ranges describe handling/tent sequences, not hiding-spot photos.
- `RESIGHTINGS_PUBLIC` is unchanged and does not receive this field.

`CAPTURES.chick_hide_photo` is retained for compatibility but is now explicitly
legacy for new entry. Do not drop or repurpose it during the season. New
hiding-spot evidence belongs in its own age-C, H-class RESIGHTINGS row. A future
migration may remove it only after a compatibility audit of existing rows,
validators, views, package behavior, and export history.

### Location and temporal contract

The implemented operational interpretation is **latest valid direct chick-event
location**, not latest event regardless of location completeness.
That avoids a later incomplete event erasing a usable mobile-brood position.

1. Consider only age-C CAPTURES or RESIGHTINGS events through
   `settings.reference_date`, with both `gps_id` and `gps_point` present and
   resolvable through `GPS_POINTS`.
2. Choose the latest qualifying direct event for the brood ID.
3. For a positive ID with no qualifying direct chick event, fall back to its
   `NESTS` stationary location.
4. For a negative ID, do not fall back to `NESTS`; emit a missing-direct-location
   state instead.
5. Exclude `NO_NEST` from brood-derived outputs.

The implemented `BROODS_LATEST` view retains `location_source`,
`location_event_date`, `location_event_datetime`, `location_event_pk`,
`location_source_table`, `gps_id`, and `gps_point`, not just latitude/longitude.
CAPTURES event time is `released`, then `caught`, then midnight. RESIGHTINGS has
no time field, so its event time is midnight. Exact event ordering is
deterministic: event date descending, event datetime descending, source rank
(`RESIGHTINGS` H first, then `CAPTURES`, then other `RESIGHTINGS`), and `pk`
descending. The same ordering is applied when selecting the latest valid direct
GPS location, so a same-day H-class hiding-spot event can win deterministically.
This source-priority rule is an operational compatibility decision and remains a
biological review point if field teams later need a more precise time field.

### Implemented derived-view architecture

Do not broaden `NESTS_LATEST`: it remains the one-history-per-positive-nest
view. The current source layer adds `BROODS_LATEST` as the reusable one-row-per-
brood authority for positive and negative brood identity, direct/mobile location
selection, hatch evidence, parent marks, and source provenance. It does not
fabricate `NESTS` or `EGGS` rows.

The implemented output columns are:

```text
nest_id
brood_kind                    -- positive / negative
is_negative_brood
discovery_date
latest_encounter_date
latest_encounter_datetime
latest_chick_event_date
latest_chick_event_source
gps_id, gps_point, lat, lon
location_source               -- direct_chick_event /
                              -- positive_nest_fallback /
                              -- missing_direct_chick_location
location_event_date
location_event_datetime
location_event_pk
location_source_table
hatch_evidence_date
has_hatch_evidence
nest_state, hatch_state, clutch_size, brood_size
min_days_to_hatch
M_mark, F_mark
nest_photo, tent_photo
chick_band
reference_date
```

Implementation details:

- Every source event and nest-history branch is bounded by
  `settings.reference_date`. The current implementation is scoped to Cass River
  (`site = 'CR'`), even though the source-table contract permits the negative-ID
  syntax more generally.
- Positive units are built from reference-date-bounded `NESTS` history and may
  use a deterministic stationary `NESTS` GPS fallback. The fallback ranks state
  `S`, then `F`, then other states, followed by date/time/primary-key and GPS
  ordering. Positive terminal `notA` rows are retained only when historical hatch
  or brood evidence exists.
- Negative units are discovered from negative-ID `CAPTURES` and `RESIGHTINGS`
  events, with discovery date as the earliest qualifying event and latest
  encounter selected by the deterministic ordering above. Negative units have no
  `NESTS` or `EGGS` fallback.
- Latest chick-event metadata is selected from age-C CAPTURES/RESIGHTINGS. The
  location itself is selected from the latest age-C event whose paired GPS keys
  resolve in `GPS_POINTS`; a later age-C event with missing/unresolvable GPS does
  not erase an earlier valid location.
- Negative parent marks are selected from adult CAPTURES/RESIGHTINGS by sex. The
  ranking prioritizes `dead`, then geolocator evidence, then an informative mark,
  then recency and deterministic source/primary-key order. Positive parent marks
  continue to come from `NESTS_LATEST`, whose parent candidates use both captures
  and resightings.
- For age-C CAPTURES, the first informative single-colour `LL` or `LR` value is
  retained as `chick_band`. A scalar is appropriate for the current downstream
  label-colour contract; it is not a complete list of all sibling colours.
- Negative units intentionally expose `has_hatch_evidence = 1` as an operational
  retention sentinel while leaving `hatch_evidence_date` and hatch estimates
  blank. This keeps unknown-origin mobile broods in the map/summary without
  inventing a hatch date.

Dependencies are `settings`, `NESTS`, `CAPTURES`, `RESIGHTINGS`, `GPS_POINTS`,
`NESTS_LATEST`, and `format_mark()`. `EGGS_HATCH_PREDICTION` is not a direct
negative-brood dependency; positive hatch timing is inherited through the
existing positive-nest path.

`TODO_LIST` consumes `BROODS_LATEST` for negative parent work, `Untrapped brood`,
and `Hiding spot photos needed` tasks. Negative units do not enter nest,
flotation, clutch-check, scrape, or `notA`-closure task branches. The PDF helper
loads `BROODS_LATEST` directly (while retaining a legacy `nests_latest` argument
for older preview callers), and passes the same unified rows to the PDF summary
and map. The map keeps negative and hatched-positive units, excludes failed
positive `notA` units, and omits units with no valid map coordinates.

This is implemented in the current local source tree. It is not yet a deployed
database contract.

### Index decision

The tracked DDL already has the useful GPS lookup key on `GPS_POINTS`
`(gps_id, gps_point)` and matching event-table GPS keys. No extra GPS index is
needed. The tracked DDL now adds the smallest targeted new keys:

```sql
CAPTURES    KEY nest_age_date (nest_id, age, date, pk)
RESIGHTINGS KEY nest_age_date (nest_id, age, date, pk)
```

They support the repeated brood queries that constrain an ID and `age = 'C'`,
limit by date/reference date, then select a deterministic latest row. They do
not replace the existing simple `nest`, `date`, `site`, or GPS indexes because
those remain useful for other access paths. Cost: each CAPTURES/RESIGHTINGS
insert/update writes one additional secondary index. This is a reasonable trade
for field-season operational reads, but should be checked with `EXPLAIN` after
deployment rather than adding more speculative composite keys.

### Safe deployment and rollback

Never re-run `main_tables.SQL` or `_reset.SQL` against an existing database.
Before deployment, inspect only metadata and use a maintenance window because
`ALTER TABLE` can take a metadata lock and may briefly block concurrent writes.

```sql
-- Preflight: current columns/comments and existing indexes.
SELECT table_name, column_name, column_type, column_comment
FROM information_schema.columns
WHERE table_schema = 'FIELD_2026_BADOatNZ'
  AND table_name IN ('CAPTURES', 'NESTS', 'EGGS', 'RESIGHTINGS')
  AND column_name IN ('nest_id', 'gps_id', 'gps_point', 'rclass', 'photo_start',
                      'photo_end', 'chick_tent_photo', 'chick_hide_photo');

SELECT table_name, index_name, seq_in_index, column_name
FROM information_schema.statistics
WHERE table_schema = 'FIELD_2026_BADOatNZ'
  AND table_name IN ('CAPTURES', 'RESIGHTINGS', 'GPS_POINTS')
ORDER BY table_name, index_name, seq_in_index;
```

Apply these object-specific comment changes before adding each new index. They do
not alter stored values or column types:

```sql
ALTER TABLE FIELD_2026_BADOatNZ.CAPTURES
  MODIFY COLUMN nest_id varchar(7) DEFAULT NULL COMMENT 'Nest or brood association: <br> a positive ID identifies a real nest/scrape (SXXYY; e.g., A0203 or BA0202). <br> A <b>negative</b> ID (e.g., -A0203, -BA0202) identifies a mobile brood of unknown origin: it has no NESTS or EGGS row. For a negative ID, record both gps_id and gps_point and enter each observed/captured individual as a separate event. <br> Use <b>NO_NEST</b> only when the event is unrelated to any nest or brood.',
  MODIFY COLUMN gps_id tinyint(3) unsigned DEFAULT NULL COMMENT 'Handheld Garmin GPS ID. Required together with gps_point when nest_id is a negative brood ID or NO_NEST.',
  MODIFY COLUMN gps_point int(10) unsigned DEFAULT NULL COMMENT 'Waypoint number of the capture location stored in your handheld Garmin GPS unit. Required together with gps_id when nest_id is a negative brood ID or NO_NEST.',
  MODIFY COLUMN photo_start varchar(255) DEFAULT NULL COMMENT 'First image filename for this handling or tent-photo sequence. Record hiding-spot images as a separate age-C RESIGHTINGS event with rclass H.',
  MODIFY COLUMN photo_end varchar(255) DEFAULT NULL COMMENT 'Last image filename for this handling or tent-photo sequence. Record hiding-spot images as a separate age-C RESIGHTINGS event with rclass H.',
  MODIFY COLUMN chick_tent_photo enum('0','1') DEFAULT NULL COMMENT 'Was a chick handling/tent photo taken? <br> <b>0</b> (no) or <br> <b>1</b> (yes)',
  MODIFY COLUMN chick_hide_photo enum('0','1') DEFAULT NULL COMMENT 'Legacy field: do not use for new entries. Record each hiding-spot photo as a separate age-C RESIGHTINGS event with rclass <b>H</b> and direct GPS. <br> <b>0</b> (no) or <br> <b>1</b> (yes)';

ALTER TABLE FIELD_2026_BADOatNZ.EGGS
  MODIFY COLUMN nest_id varchar(8) DEFAULT NULL COMMENT 'Positive ID of the real nest/scrape where this egg belongs (SXXYY; e.g., A0203 or BA0202). <br> Negative brood IDs are not valid in EGGS because broods of unknown origin have no egg history; record their events in CAPTURES or RESIGHTINGS. <br> <b>NO_NEST</b> is not valid in EGGS.';

ALTER TABLE FIELD_2026_BADOatNZ.NESTS
  MODIFY COLUMN nest_id varchar(8) DEFAULT NULL COMMENT 'Positive ID of a real stationary nest/scrape (SXXYY; e.g., A0203 or BA0202). <br> Negative brood IDs are not valid in NESTS because a brood of unknown origin has no nest record; record its events in CAPTURES or RESIGHTINGS with direct GPS. <br> <b>NO_NEST</b> is not valid in NESTS.',
  MODIFY COLUMN gps_id tinyint(3) unsigned DEFAULT NULL COMMENT 'Handheld Garmin GPS ID for the stationary nest/scrape location, recorded when this positive nest_id is assigned.',
  MODIFY COLUMN gps_point int(10) unsigned DEFAULT NULL COMMENT 'Waypoint number for the stationary nest/scrape location, recorded with gps_id when this positive nest_id is assigned.';

ALTER TABLE FIELD_2026_BADOatNZ.RESIGHTINGS
  MODIFY COLUMN gps_id tinyint(3) unsigned DEFAULT NULL COMMENT 'Handheld Garmin GPS ID. Required together with gps_point when nest_id is a negative brood ID or NO_NEST.',
  MODIFY COLUMN gps_point int(10) unsigned DEFAULT NULL COMMENT 'Waypoint number of the resighting location stored in your handheld Garmin GPS unit. Required together with gps_id when nest_id is a negative brood ID or NO_NEST.',
  MODIFY COLUMN rclass enum('C','V','R','P','H') DEFAULT NULL COMMENT 'Resighting class: <br> <b>C</b> (failed capture attempt) <br> <b>V</b> (video session) <br> <b>R</b> (regular) <br> <b>P</b> (photography session) <br> <b>H</b> (chick hiding-spot photo session: enter the chick as age C, with nest_id and direct GPS)',
  MODIFY COLUMN nest_id varchar(8) DEFAULT NULL COMMENT 'Nest or brood association: <br> a positive ID identifies a real nest/scrape (SXXYY; e.g., A0203 or BA0202). <br> A <b>negative</b> ID (e.g., -A0203, -BA0202) identifies a mobile brood of unknown origin: it has no NESTS or EGGS row. For a negative ID, record both gps_id and gps_point and enter each observed individual as a separate event. <br> Use <b>NO_NEST</b> only when the event is unrelated to any nest or brood. <br> Enter nest_id when a resighting first establishes social parentage at a nest or brood.',
  MODIFY COLUMN photo_start varchar(255) DEFAULT NULL COMMENT 'First image filename for this resighting sequence. For hiding-spot images use a separate age-C event with rclass H, nest_id, and direct GPS.',
  MODIFY COLUMN photo_end varchar(255) DEFAULT NULL COMMENT 'Last image filename for this resighting sequence. For hiding-spot images use a separate age-C event with rclass H, nest_id, and direct GPS.';
```

Then add each new index only if the metadata query confirms its name is absent:

```sql
ALTER TABLE FIELD_2026_BADOatNZ.CAPTURES
  ADD INDEX nest_age_date (nest_id, age, date, pk);

ALTER TABLE FIELD_2026_BADOatNZ.RESIGHTINGS
  ADD INDEX nest_age_date (nest_id, age, date, pk);
```

Rollback for the index portion is safe and object-specific:

```sql
ALTER TABLE FIELD_2026_BADOatNZ.CAPTURES DROP INDEX nest_age_date;
ALTER TABLE FIELD_2026_BADOatNZ.RESIGHTINGS DROP INDEX nest_age_date;
```

Comment rollback requires restoring the prior reviewed comment text with
`MODIFY COLUMN`; it does not require data rewrite. Take a schema-only backup or
save `SHOW CREATE TABLE` output before any live deployment.

### Cross-thread handoff

**Thread 3.1 (inspectors):** implement save-time rules only after this contract
is accepted. Reject negative IDs in `NESTS` and `EGGS`; reject `NO_NEST` there;
require paired GPS fields for negative IDs and `NO_NEST` in CAPTURES/RESIGHTINGS;
allow current positive formats; warn or error when an H-class RESIGHTING is not
age C, lacks an ID, or lacks paired GPS. Do not make the inspector infer GPS or
create a NESTS row.

**Thread 4 (TODO/PDF/map):** retain `NESTS_LATEST` for positive stationary nests.
Use the implemented `BROODS_LATEST` for mobile-brood location, provenance, and
negative-ID output. Do not repeat the CAPTURES/RESIGHTINGS union or location
ranking in R. The current PDF/map helpers consume it, and `TODO_LIST` consumes it
for negative-brood tasks. A current separate risk is that the NESTS_LATEST source
watch in `main/global.R` omits `RESIGHTINGS` even though its parent marks use it;
the current browser view list also does not expose `BROODS_LATEST` as a separate
view entry because the PDF path queries it directly.

### Required invented-fixture coverage

The current focused tests and cross-thread mock plans use invented data to cover:
positive nest with NESTS-only location; positive brood with later direct chick
GPS; negative brood first seen in CAPTURES; negative brood first seen in
RESIGHTINGS; multiple same-day individuals; same-day capture plus H resighting;
negative ID missing GPS; `NO_NEST`; non-Cass negative syntax; historical
positive-H followed by `notA`; changing locations; chick-band colours; and
deterministic ordering. These are static/invented checks only; no live database
verification has occurred.

## Source-of-truth rule

Treat the tracked `DATABASE/` directory as the schema source of truth. Its files
have separate roles:

- `main_tables.SQL`: core field and GPS source-table DDL.
- `support_tables.SQL`: runtime support tables: `settings`, `spatial_objects`,
  and DB-stored `inspectors`.
- `predict_hatching.SQL`: stable hatch-calibration table and its controlled seed
  data.
- `functions.SQL`: `format_mark()`.
- `views.SQL`: operational derived layer.
- `_reset.SQL`: destructive local reset helper, not a migration history and not
  a complete rebuild runner.

The dated local dump `DATABASE/FIELD_2026_BADOatNZ_7311213.sql` is only an
alignment reference. It predates current tracked DDL and must not be treated as
an authoritative restore source.

## Current dependency order

For a clean local rebuild or controlled deployment, use this conceptual order:

1. Create/select `FIELD_2026_BADOatNZ`.
2. Create core tables from `main_tables.SQL`.
3. Create support tables from `support_tables.SQL`.
4. Create/load `predict_hatching` from `predict_hatching.SQL`.
5. Create `format_mark()` from `functions.SQL`.
6. Create views from `views.SQL` in dependency order: `CAPTURES_ARCHIVE` and
   combo views first, `NESTS_LATEST`, then `BROODS_LATEST`, then
   `EGGS_HATCH_PREDICTION`/phenology views, and finally `TODO_LIST` and the
   remaining reporting views.

`views.SQL` requires all preceding local objects. `CAPTURES_ARCHIVE` additionally
requires the historic database `BADOatNZ` to expose compatible `CAPTURES` and
`SEX` tables. A clean 2026-only database cannot create that view unless that
historical compatibility dependency exists.

`_reset.SQL` begins with `DROP DATABASE IF EXISTS FIELD_2026_BADOatNZ`; its later
individual `DROP TABLE` statements are therefore redundant. It drops objects but
does not re-run the ordered DDL files above. Never use it as an in-place migration
tool or against a database that has not been backed up.

## Core source tables

### OBSERVERS

Observer metadata and device/camera associations. `observer` is the application
lookup value. Current tracked DDL makes `gps_id` and `cam_id` free text so one
observer can list multiple values; this is intentional DDL drift from the latest
snapshot, which still has numeric `gps_id`.

### CAPTURES

The central in-hand event table. Important cross-table fields are `nest_id`,
`gps_id`, `gps_point`, release marks (`UL`, `LL`, `UR`, `LR`), input marks
(`UL_in`, `LL_in`, `UR_in`, `LR_in`), `field_sex`, `age`, capture
method/status, and tag fields. `eggs_handled` is a current CAPTURES-only enum
field and now sits between `gps_point` and `field_sex` in tracked DDL.
`observer_upload` remains CAPTURES-only.

`nest_id` permits negative brood-style values and the `NO_NEST` sentinel here.
The `(gps_id, gps_point)` index is non-unique; it supports lookup rather than
enforcing one unique GPS row.

### EGGS

Intentionally long format: one row per egg observation with `nest_id`, `egg_id`,
`date`, `time_visit`, `float_angle`, `float_location`, and `float_surface`.
`float_location` is an enum (`bottom`, `suspended`, `surface`). `NO_NEST`
and negative nest IDs are explicitly invalid. There is no `observer_upload`
field.

### GPS_POINTS and GPS_TRACKS

GPS upload products. The canonical observation-to-waypoint linkage is
`gps_id + gps_point` into `GPS_POINTS`; tracks instead use `gps_id + seg_id` and
`seg_point_id`. Both GPS identifiers are unsigned numeric fields in current DDL.
No foreign keys enforce those relationships, so upload consistency remains an
application/validator responsibility.

### NESTS

Nest-visit events with state, clutch/brood state, coordinates by GPS linkage, and
photo-processing fields. `nest_id` may not be negative or `NO_NEST`. The current
`bird_inc` enum is `M`, `F`, `FM`, `MF`, `U`, `E`; `FM` and `MF` are
both accepted and both mean both sexes seen. This is wider than the July snapshot.

### RESIGHTINGS

Adult/chick resighting events with observed marks, sex, age, behavior, ring, and
nest association. The nullable `ring varchar(50)` field appears after `LR` and
before `sex`; it identifies the resighted individual, especially a chick in an
H-class hiding-spot-photo event. This is a free-text identity field, not a
controlled-value dropdown. This table is now a first-class parentage source: an at-nest
resighting must carry `nest_id` when it is the first evidence linking an already
marked bird to a nest or brood. `NO_NEST` is allowed only for events not associated
with a nest or brood.

`RESIGHTINGS_H_BROOD_ASSOCIATIONS` is an internal derived view for the approved
unlinked H exception. It preserves the raw `RESIGHTINGS` row and reports a
task-level `derived_nest_id` only when a prior chick capture link and at least
one same-date, exact `(gps_id, gps_point)` parent mark match identify exactly
one candidate. It reports ambiguous and unresolved candidates without assigning
an ID. Positive candidates must exist in `NESTS`; negative candidates remain
mobile and do not require a `NESTS` row. `BROODS_LATEST` consumes only resolved
rows as chick events, so its latest-valid-direct-location logic can use the H
event for either brood kind. `TODO_LIST` counts both qualifying raw linked H
rows and qualifying uniquely resolved H rows, requiring the ring, direct GPS,
and both photo endpoints. No raw row is backfilled, and `RESIGHTINGS_PUBLIC` is
unchanged. The helper is internal rather than a user-facing Show View, so no
positional insert or new base-table index is required.

### RESIGHTINGS_PUBLIC

Public-source observations. It has separate coordinate fields, source metadata,
and `country` enum values `NZ`, `AU`, and `O`. It is not currently used by the
operational nest-parent or GPS workflow.

## Support objects

### settings and reference_date

`settings(variable, value)` holds the one canonical `reference_date`. Every major
operational view uses a one-row `sr` CTE sourced from it. If the row is absent or
its value is null, those views can become empty. The main app reads and writes the
same setting through `get_reference_date()` and `set_reference_date()`.

### inspectors

The validator architecture is DB-stored. The `inspectors` table holds
`table_name`, R validator code, notes, and `updated_at`; repository
`DataEntry/*/global.R` files configure table presentation rather than the live
validator rules. There is no primary/unique key in the DDL, so duplicate inspector
rows remain possible and must be managed operationally.

### spatial_objects and predict_hatching

`spatial_objects` stores named WKT objects used by map code, notably
`study_area`. `predict_hatching` is a stable calibration table used by both
hatch-prediction views. It contains a primary key on `egg_id` and a float-state
index.

### format_mark()

`format_mark(UL, LL, UR, LR)` is deterministic and SQL-only. It trims inputs,
suppresses literal `X` and `M` on each leg side, joins non-suppressed upper/lower
segments with `.`, and returns a normalized `left-right` mark with `X` as the
empty-side placeholder. It is used by derived views and app-side queries; changing
it is a contract change, not a cosmetic change.

## Current derived views

### CAPTURES_ARCHIVE

Historical compatibility view over `BADOatNZ.CAPTURES` plus an aggregated lookup
of `BADOatNZ.SEX`. It exposes historic release marks, a normalized mark, event
metadata, morphology, tag fields, and `gen_sex`. The historic sex lookup is
one-to-one at output time because it groups by trimmed ring and takes a nonblank
maximum. It is an explicit cross-database compatibility gate.

### USED_COMBOS_DETAIL and AVAILABLE_COMBOS

`USED_COMBOS_DETAIL` aggregates potential colour-combination use from three
sources, all filtered to `reference_date` (or undated history): historic archive
release marks, current CAPTURES release marks, and current CAPTURES input marks.
It normalizes the two lower-leg colour pairs used for allocation. The rules handle
single/two-band left and right forms, normalize tagged upper-right values, and
avoid incorrectly prepending a geolocator spacer when the lower-right value already
contains a complete two-colour pair. It outputs raw values, normalized `LL`/`LR`,
`mark`, and `is_normalizable`.

`AVAILABLE_COMBOS` generates candidate lower-leg pairs from hard-coded site rules,
excludes combinations already present in `USED_COMBOS_DETAIL`, applies disallowed
combination rules, ranks candidates, and emits `site_code`, `mark`, `LL`, `LR`.
The current `CR`/`CX` remapping is a temporary compatibility gate for the deployed
PDF query; it is not a general biological site taxonomy.

### NESTS_LATEST

Operational one-row-per-nest view. It uses `NESTS` history through `reference_date`
to choose the latest visit, latest clutch and brood values, a latest GPS point,
hatch signs, and hatch timing. It hides old scrape-only records and selected stale
`notA` records.

`M_mark` and `F_mark` are selected by `nest_id` from both adult `CAPTURES` and
adult `RESIGHTINGS`, restricted to Cass River, non-chick events, and usable sex
codes. Candidate marks are ranked so informative non-`X` marks win, then longer
informative marks, then lexical order. This supports the protocol where a parent
can be confirmed by an at-nest resighting without a new capture.

### EGGS_HATCH_PREDICTION

Produces per-egg prediction rows from egg float data and calibration rows with the
same `float_location`. It chooses exact angle/surface matches first, otherwise the
nearest calibration candidate. Output includes matching diagnostics, predicted
days-since-laying, hatch estimates, bounds, and `reference_date`.

It also creates a synthetic `found as incomplete` prediction when the first found
clutch was below its later final clutch size and no egg-float prediction exists.
That path infers clutch completion and hatch timing from nest history. This is a
biological operational assumption and needs continued collaborator review.

### TODO_LIST

`TODO_LIST` is the principal operational task source. It is Cass River scoped and
reference-date aware. The final stable output columns are:

`nest_id`, `reference_date`, `todo`, `notes`, `days_overdue`, `priority`,
`min_days_to_hatch`, `last_visit_days_ago`, `nest_state`, `clutch_size`,
`brood_size`, `M_mark`, `F_mark`, location fields, and `overdue_label`.

Current task families are parent capture, parent resighting, unprocessed nest,
scrape photos, re-process nest, clutch check, nest check, untrapped brood, hiding
spot photos, and `notA` follow-up.

Parent status combines recent capture and resighting identity evidence. It tracks
confirmed unbanded `X-X`, uncertain identity, geolocator status, single-colour
recruits, mobile-mistnet (`MM`) captures requiring later at-nest confirmation,
and ordinary already-banded birds whose nest association remains unresolved.
The PR candidate groups evidence by canonical same-sex identity. One approved
nest behaviour or three matching nest-linked resightings resolves an identity;
zero or multiple resolved identities remain ambiguous. MM alternate identities
use the same evidence threshold, while spacer-dependent one-band identities
retain their full-mark matching rule.

Capture eligibility includes two protocol rules encoded in SQL: at least seven
days after estimated clutch completion, and at least 36 hours after the previous
adult-parent capture, evaluated against 08:00 on the reference date. The task
notes distinguish whether a resighting only is currently appropriate. The new
clutch-check workflow keeps a recent one/two-egg clutch under review after a
parent-capture context. These are biological safeguards, not generic database
constraints.

### OVERVIEW

The SQL `OVERVIEW` view is a tabular metric source with `section`, `metric`, and
`n` rows, filtered to `reference_date`. It summarizes captures, nests, eggs, and
resightings. It is separate from the app-side four-panel Overview dashboard.

## Downstream consumers

- `DataEntry/*/global.R`: declarative table name, exclusions, defaults, and
  dropdowns. Current alignment issue: `CAPTURES.eggs_handled` is in tracked DDL
  but not in the CAPTURES dropdown list; add `c("0", "1")` before relying on the
  schema to render it as a controlled dropdown.
- `main/global.R`: lists browser-visible tables/views and source-watch lists.
- `main/R/leaflet_nest_latest.R` and `main/R/kmz_nest_latest.R`: consume
  `NESTS_LATEST` output including state, labels, and location fields.
- `main/R/pdf_todo.R` and `main/R/pdf_todo_map.R`: consume `TODO_LIST`,
  `BROODS_LATEST`, and `AVAILABLE_COMBOS`; they expect parent marks, hatch timing,
  task categories, priorities, negative-brood flags, chick colours, and location
  provenance. The legacy `nests_latest` argument remains as a compatibility
  wrapper for older local preview callers.
- `main/R/ggplot_overview.R`: queries source tables,
  `EGGS_HATCH_PREDICTION`, and `CAPTURES_ARCHIVE` directly. It does not use the
  SQL `OVERVIEW` view as the source for its four dashboard plots.
- `tests/testthat/`: checks view wiring, Overview output IDs, SQL-view presence,
  reference-date reactivity, and selected archive usage. It does not replace a
  database-level view execution test.

## Changes since the July 29 memo

- `TODO_LIST` now includes explicit parent-capture, parent-resighting, `MM`
  follow-up, geolocator-target, disturbance-interval, clutch-check, and expanded
  processing workflows.
- `NESTS_LATEST` parent marks now use both captures and resightings rather than
  capture-only history.
- `OVERVIEW` is now an active tracked SQL view and the app has a committed
  multi-panel Overview dashboard.
- `NESTS.bird_inc` now accepts `FM` and `MF` as well as the previous sex/unknown/
  empty values; the NESTS app dropdown matches the wider enum.
- `OBSERVERS.gps_id` is now free text for multiple-device association.
- Current CAPTURES DDL retains `eggs_handled`, moves it beside GPS linkage fields,
  and retains `observer_upload` only in CAPTURES.
- `RESIGHTINGS` now includes nullable `ring` after `LR` for chick identity in
  H-class hiding-spot-photo events; `RESIGHTINGS_PUBLIC` remains unchanged.

## Snapshot comparison

The latest local snapshot is dated 2026-07-31, so it is structurally behind the
tracked SQL. Material observed drift includes:

- older `NESTS.bird_inc` allowed only `M`, `F`, `U`, `E`;
- older `OBSERVERS.gps_id` was numeric rather than the current free-text
  multiple-ID field;
- older CAPTURES placement/comment semantics do not reflect current `NO_NEST` and
  `eggs_handled` source DDL;
- the snapshot preserves old comment formatting and auto-increment state, neither
  of which should drive new DDL decisions.

Use the snapshot for safe local read-only alignment/testing only. Do not apply it
to roll back or recreate the current database schema.

## Compatibility gates and unresolved risks

1. `CAPTURES_ARCHIVE` requires both historic `BADOatNZ.CAPTURES` and
   `BADOatNZ.SEX`. The app source-watch mapping currently names only historic
   CAPTURES, so a SEX-only change will not invalidate the browser view.
2. `NESTS_LATEST` now depends on `RESIGHTINGS`, but its source-watch list in
   `main/global.R` omits `RESIGHTINGS`; resighting-only parent updates may not
   refresh the browser/map on schedule.
3. `BROODS_LATEST` is implemented and consumed directly by `TODO_LIST` and the
   PDF/map helpers, but it is not currently listed as a separate browser view in
   `main/global.R`. Its underlying sources are partly covered by the `TODO_LIST`
   watch list; direct PDF loads still depend on a fresh deployed view.
4. `AVAILABLE_COMBOS` is browser-visible but has no explicit source-watch mapping.
   It depends on `settings`, current CAPTURES, the historic archive, and ultimately
   historic SEX.
5. `VIEW_1` is now defined in tracked `views.SQL` and its current source watch is
   `settings`, `CAPTURES`, and `RESIGHTINGS`. `main/global.R` still advertises
   `VIEW_2`, but tracked `views.SQL` has no `VIEW_2` definition; this remains a
   browser-contract mismatch.
6. `TODO_LIST` is a large window-function/CTE view. `showTable()` requests
   `derived_merge=off`, but other direct callers may still need performance and
   query-plan checks on the target MariaDB version.
7. Source tables use indexes rather than foreign keys, so invalid links can be
   stored unless validators and post-save QA catch them.
8. `FM` versus `MF` in `bird_inc` needs a canonicalization decision. Treating
   them as different categorical values can fragment summaries and validators.
9. The current `BROODS_LATEST` implementation is scoped to `site = 'CR'`. The
   source DDL comments describe negative IDs more generally, so extending the
   view beyond Cass River requires explicit collaborator and biological review.
10. The seven-day/36-hour rules, inferred incomplete-clutch dates, the geolocator
   target threshold, and the temporary combo site gate require biological or
   collaborator confirmation before being generalized or simplified.

## Migration and rollback stance

There is no migration ledger. For a live or valued local database, use reviewed,
object-specific `ALTER`/`CREATE OR REPLACE VIEW` statements and a backup; do not
re-run `main_tables.SQL` or `_reset.SQL` blindly. Deploy helper functions before
views, and re-create dependent views after changes to `format_mark()`, source
columns, or historic compatibility objects. Rollback should restore the prior
object-specific DDL/view definition, not a whole dated dump.

For an environment where the live RESIGHTINGS table does not yet contain the
field, first inspect metadata and then apply this reference migration manually.
It is not executed by this task because the active database has already been
altered:

```sql
SELECT TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, COLUMN_TYPE,
       IS_NULLABLE, COLUMN_COMMENT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
  AND TABLE_NAME = 'RESIGHTINGS'
  AND COLUMN_NAME IN ('LR', 'ring', 'sex')
ORDER BY ORDINAL_POSITION;

ALTER TABLE FIELD_2026_BADOatNZ.RESIGHTINGS
  ADD COLUMN `ring` varchar(50) DEFAULT NULL
  COMMENT 'alpha-numeric code of metal ring assigned to resighted individual (typically for chick with hiding spot photo; rclass H)'
  AFTER `LR`;
```

Rollback, only if the column was added solely by this migration and its values
have been reviewed, is:

```sql
ALTER TABLE FIELD_2026_BADOatNZ.RESIGHTINGS
  DROP COLUMN `ring`;
```

Dropping the field discards entered chick-ring values and requires an explicit
backup and collaborator approval. No index is proposed because current views
and helpers do not filter or join RESIGHTINGS by `ring`.

## Handoff checklist for future Thread 2 work

1. Start from the current tracked `DATABASE/*.SQL` files, then inspect consumers
   in `main/`, `DataEntry/`, and tests.
2. Confirm all source-table fields/enums are represented correctly in applicable
   `DataEntry/*/global.R` dropdowns and defaults.
3. Treat `reference_date` as an input to operational output, not a display-only
   setting.
4. When changing a view dependency, update `main/global.R` source-watch mappings
   and tests in the same review.
5. Treat historic `BADOatNZ` compatibility objects as external prerequisites;
   never assume a 2026-only reset provides them.
6. Ask for biological confirmation before changing parent identity, capture timing,
   clutch inference, geolocator targeting, or allocation rules.
