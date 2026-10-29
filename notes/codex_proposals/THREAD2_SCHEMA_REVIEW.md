# Thread 2 Schema Review: Current Database Architecture

Last refreshed: 2026-10-26

Historical publication reconciliation: this handoff was published from
`origin/main` at `f7d13fb`. The `9beb203` and `d3c7bd4` states below are the
recorded inspection provenance for the protected experimental checkout, not
the documentation branch's current source baseline. `f7d13fb` includes the
refresh empty-statement correction merged through PR #147. No live deployment
is inferred from that source merge.

The 2026-10-26 correction is a later uncommitted candidate, not a publication
from that older baseline. Use the final source-frozen verification record and
a fresh origin/main comparison for release preparation. SC (scraping) is
independently association-confirming in both ADULT_PARENT_STATUS and the
supporting ADULT_SCRAPE_RESIGHTING_STATUS helper. It is not a BC/FC/AC
parent-with-chicks substitute. The earlier inspection provenance below remains
historical; it does not establish current Git, replay or deployment state.

## Status and scope

This is the restart-grade handoff for Thread 2, the database architect. It
describes schema contracts, SQL-object dependencies, migration safety, and
handoffs to the validator, task/PDF/map, Overview, combo-list, and local-replay
threads. It does not own save-time validator implementation, task wording,
PDF layout, map styling, Overview panel design, or local MariaDB replay.

This refresh used static repository inspection only. It did not connect to a
database, inspect credentials, read raw field records, inspect GPS coordinates,
run a Shiny app, or execute SQL.

The repository state at inspection was deliberately split into three layers:

- `origin/main` was at `9beb203`; this is the collaborator-controlled remote
  baseline used for deployment comparisons.
- The checkout was branch
  `codex/split-todo-calculator-2026-10-19` at `d3c7bd4`, with protected dirty
  work in `DATABASE/views.SQL`, `main/R/pdf_todo.R`, Thread 4 documentation,
  validator sandbox exports, and focused tests.
- The live database and deployed Shiny process remain unknown. Local source,
  local snapshots, or a successful app render are not proof of live deployment.

The dirty files were preserved. This documentation refresh changed only this
tracked memo and the ignored Thread 2 prompt log.

## Authority hierarchy and state labels

Use the current `DATABASE/` directory as the schema layer, not the historical
`Admin/db_structure.SQL` file:

| File | Authority | Role |
|---|---|---|
| `DATABASE/main_tables.SQL` | current core-table DDL | biological event tables and GPS upload tables |
| `DATABASE/support_tables.SQL` | current support-table DDL | `settings`, `spatial_objects`, and DB-stored `inspectors` |
| `DATABASE/functions.SQL` | current helper-function DDL | `format_mark()` and related SQL helpers |
| `DATABASE/predict_hatching.SQL` | current stable support object | hatching calibration table and seed values |
| `DATABASE/views.SQL` | current derived-view source | archive, combo, nest, brood, identity, parent, hatch, task, and reporting views |
| `DATABASE/refresh_todo_list_snapshot.SQL` | current refresh workflow | reference-date-specific materialization and publication |
| `DATABASE/_reset.SQL` | destructive local reset helper | local-only drop workflow, not an in-place migration |

The dated `DATABASE/FIELD_2026_BADOatNZ_*.sql` files are read-only alignment
references for local testing. They are not a current schema source, migration
ledger, or proof of the live database. The latest inspected snapshot predates
the current DDL and view architecture.

When describing behavior, use these labels precisely:

- **Tracked source**: committed repository source at the selected Git revision.
- **Protected WIP**: uncommitted local changes in the current checkout. They
  must not be deployed merely because they are present on disk.
- **Remote baseline**: the selected `origin/main` source pair.
- **Local replay evidence**: results from an explicitly isolated local database,
  not inspected in this documentation pass.
- **Live deployment**: the target MariaDB objects and restarted app process.
  None is established by source inspection.

The local checkout currently contains an experimental split task calculator and
additional snapshot definitions in the dirty `DATABASE/views.SQL`. The clean
remote baseline has a different install/refresh boundary and does not establish
that the dirty split calculator is a deployable replacement. Treat the exact
`views.SQL` and `refresh_todo_list_snapshot.SQL` from one reviewed revision as a
matched pair.

## Current source-table contract

### `OBSERVERS`

`OBSERVERS` stores observer identity and device metadata. The `observer` value
is the lookup used by field tables. Current DDL permits free-text GPS and
camera-device values so one observer can record multiple devices. The latest
dated dump still reflects an older numeric GPS representation and must not
override the tracked DDL.

### `CAPTURES`

`CAPTURES` stores in-hand capture and recapture events, including adult and
chick handling, morphometrics, samples, tags, photos, and parent/nest
associations. Important relational fields are `nest_id`, `gps_id`,
`gps_point`, `ring`, `UL_in`, `LL_in`, `UR_in`, `LR_in`, `UL`, `LL`, `UR`,
`LR`, `field_sex`, `age`, `tag_id`, `tag_type`, and `tag_action`.

Current DDL facts:

- `nest_id` is `varchar(7)`. The negative examples `-C0201` and `-BA0202`
  fit; a future longer identifier would require an explicit migration.
- `gps_id` is unsigned tiny integer and `gps_point` is unsigned integer. The
  `(gps_id, gps_point)` index supports GPS lookup but does not enforce a
  matching GPS row.
- `eggs_handled` is a CAPTURES-only `enum('0','1')` field located between
  `gps_point` and `field_sex`.
- `observer_upload` is CAPTURES-only. It must not be assumed in EGGS, NESTS,
  RESIGHTINGS, or RESIGHTINGS_PUBLIC.
- `age` allows `A`, `J`, and `C`; controlled fields are represented by the
  current DDL enums and the matching DataEntry dropdowns where implemented.
- The targeted composite index `(nest_id, age, date, pk)` supports repeated
  brood/chick chronology and deterministic latest-row selection.

`CAPTURES` accepts positive nest IDs and negative unknown-origin brood IDs. An
adult capture unrelated to any nest or brood uses a blank `nest_id` with a
complete direct GPS pair. No sentinel is used for an unknown or unresolved
association. A negative-ID event requires the paired direct GPS fields. Capture
photo ranges describe handling/tent sequences; hiding-spot photographs belong
in separate H-class RESIGHTINGS rows.

Direct GPS is also mandatory for an adult capture with chicks recorded in
`caught_with`, and for an age-C CAPTURES row with `capture_status = 'R'` or
`'C'`, even when the positive `nest_id` is known. A positive-nest age-C first
capture may omit direct GPS only where the approved protocol permits it; when
GPS is supplied, `gps_id` and `gps_point` must be a complete pair.

### `EGGS`

`EGGS` is intentionally long format: one row per egg observation. Its key
fields are `nest_id`, `egg_id`, `date`, `time_visit`, `float_angle`,
`float_surface`, and `float_location`. Current `float_location` values are
`bottom`, `suspended`, and `surface`. The current DDL does not contain
`cam_id`, `photo_start`, `photo_end`, or `harddrive_id`; clutch media belong
to NESTS, not EGGS. Do not restore those older fields from historical field
lists without an explicit schema decision.

EGGS accepts only a positive known-nest ID. A negative brood has no known nest
or egg history, and no sentinel should be entered for a missing association.
EGGS does not contain `observer_upload`.

### `NESTS`

`NESTS` stores nest-check history, nest state, clutch/brood observations,
incubation observations, nest photographs, and the stationary GPS anchor for a
real nest/scrape. Its `nest_id` is a positive nest identifier only. Negative
brood IDs are invalid here; missing associations are not represented by a
sentinel.

The current `bird_inc` enum accepts `M`, `F`, `FM`, `MF`, `U`, and `E`; `FM`
and `MF` both express both sexes and should not be treated as biologically
different without collaborator confirmation. The current NESTS GPS fields
describe the stationary nest anchor, not a mobile brood location.

### `RESIGHTINGS`

`RESIGHTINGS` stores opportunistic and targeted sightings of marked birds and
chicks. It includes observed marks, `sex`, `age`, `rclass`, behavior, photos,
and nest/brood association.

The nullable `ring varchar(50)` field appears after `LR` and before `sex`. It
identifies the resighted individual, especially an age-C, `rclass = 'H'`
hiding-spot-photo chick. It supplements rather than replaces `UL`, `LL`, `UR`,
and `LR`. `RESIGHTINGS_PUBLIC` is separate and does not receive this field.

Positive and negative `nest_id` values are valid here. A negative-ID resighting
requires a paired direct `gps_id` and `gps_point`. Eligible age-C `R`, `P`,
`V`, and `C` family events also require a complete direct GPS pair when the
approved family route uses direct GPS. Do not omit `nest_id`
routinely: a blank raw ID is allowed only under an approved entry or
derived-association condition. An eligible ordinary age-C `R`, `P`, `V`, or
`C` family event may resolve through authoritative parent association. Luke's
S10 negative-brood parent/chick route may resolve the shared negative brood
through authoritative parent association. An eligible age-C `H` event may
resolve one positive nest or negative brood from approved prior ring/family
evidence and exact date/GPS matching. Exact validation predicates remain
Thread 3.1's responsibility.

### `RESIGHTINGS_PUBLIC`

This table is a separate public-source workflow with its own coordinate,
source, country, and comment fields. Its `country` enum is `NZ`, `AU`, or `O`.
It is not part of the internal parent/brood GPS-association workflow and must
not receive the internal RESIGHTINGS `ring` field.

### `GPS_POINTS` and `GPS_TRACKS`

The GPS upload pipeline creates these products. Observation-to-point linkage
uses `(gps_id, gps_point)` in `GPS_POINTS`. Track linkage uses `gps_id`,
`seg_id`, and `seg_point_id` in `GPS_TRACKS`. The current DDL uses unsigned
numeric identifiers and indexes GPS lookup keys. There are no foreign keys, so
paired-key validity is enforced by the upload workflow, validators, and
read-side joins.

## Identifier contract: positive, negative, and `NO_NEST`

The existing column name `nest_id` is retained for compatibility.

| Identifier | Meaning | Allowed source tables | Location contract |
|---|---|---|---|
| Positive ID | A real stationary nest/scrape. | `NESTS`, `EGGS`, `CAPTURES`, `RESIGHTINGS` | `NESTS` can provide the stationary fallback anchor. |
| Negative ID | A mobile brood of unknown origin, such as `-A0203`, `-B0204`, `-C0201`, or `-BA0202`. | `CAPTURES`, `RESIGHTINGS` only | Each event carries its own direct paired GPS; there is no NESTS fallback. |
| Blank `nest_id` | An adult capture unrelated to any nest or brood, with complete direct GPS. | `CAPTURES` adult context only | Exclude it from nest/brood identity; do not replace it with a sentinel. |

Negative IDs are not malformed positive IDs. They identify a mobile brood of
unknown origin and are repeated on later parent/chick events that are
confidently associated with that brood. Each observed individual remains a
separate event row. Negative IDs cannot be placed in NESTS or EGGS because no
stationary nest or egg history exists.

The source-table comments and validator protocol should enforce the distinction:

- NESTS and EGGS reject negative IDs and direct users to CAPTURES/RESIGHTINGS;
  they do not use a missing-association sentinel.
- CAPTURES and RESIGHTINGS permit negative IDs but require paired direct GPS.
- historical literal `NO_NEST` values are treated defensively as non-associations
  by derived SQL, but are no longer an active entry convention; new unrelated
  adult captures use blank `nest_id` plus a complete direct GPS pair.

## Hiding-spot-photo and derived association contract

The normal hiding-spot workflow is one separate RESIGHTINGS row per chick:
`age = 'C'`, `rclass = 'H'`, nonblank metal `ring`, direct paired GPS, and
`photo_start`/`photo_end`. The raw `RESIGHTINGS.nest_id` should be filled when
the positive nest or negative brood is known; a blank raw ID is not a general
omission route.

The approved advanced exception permits a raw H row to have a blank `nest_id`
only when prior chick-capture evidence or current same-occasion family
evidence resolves exactly one candidate. The raw biological row remains
unchanged. A derived task-level association is allowed only when it is
deterministic; ambiguous candidates remain unresolved.

The current checked-out `RESIGHTINGS_H_BROOD_ASSOCIATIONS` view is the shared
helper. Its current behavior is:

- an explicit raw positive or negative ID wins; no no-association sentinel is a
  brood association;
- an unlinked H row may use one same-date, exact-GPS adult RESIGHTINGS nest
  candidate;
- an unlinked H row may use an unambiguous latest prior age-C CAPTURES ring
  history candidate;
- multiple candidate nest IDs are reported as ambiguous and do not receive a
  derived ID;
- the helper reports the raw primary key, raw ID, ring, GPS pair, resolved ID,
  and an association method; it does not rewrite `RESIGHTINGS`;
- validator-side requirements for ring, direct GPS, and photo endpoints remain
  separate from this SQL resolution helper.

`BROODS_LATEST`, the hiding-photo task input, and the PDF chick-encounter query
consume the helper so that identity/location logic is not duplicated in R.
`RESIGHTINGS_PUBLIC` is unaffected. The helper is internal and does not require
a new base-table index solely for `ring`.

### Ring identity normalization handoff

Ring identity must be canonicalized before matching or counting. The shared
schema/view contract is:

- trim surrounding whitespace and uppercase the identity;
- treat the optional `CP` hyphen as formatting, so invented values `CP12345`
  and `CP-12345` share one identity key;
- treat SQL NULL, blank, whitespace-only, and textual `NA` as missing and never
  as a ring identity;
- preserve the entered/display spelling in raw data and outputs where useful;
- never collapse two different real ring codes merely because they look similar;
- do not rewrite raw CAPTURES or RESIGHTINGS rows.

The canonical key must be used consistently by H-association ring history,
captured-chick distinct-ring counts, and H-photo distinct-ring counts. The
current SQL owns these expressions; Thread 4 consumes their outputs and should
not duplicate their source unions or location ranking. Thread 2 owns this
contract and compatibility review; static invented checks should
confirm that `CP12345`/`CP-12345` match once, missing-like values do not count,
and genuinely different codes remain separate.

### Event-wide uncertain-mark gate

For parent-nest association evidence, any `?` in any of `UL`, `LL`, `UR`, or
`LR` makes the event ineligible. A complete lower combination, a full mark, or
an explicit `X-X` interpretation does not override that exclusion. The only
exception is a nonblank metal ring that can be normalized and traced to current
or archived capture history by date; the raw mark text remains unchanged. An
archive match establishes ring identity only. It must not import an archived
nest ID or archived season into current-family inference.

The current SQL exposes `has_uncertain_mark`, `ring_traced_to_capture`, and
`association_evidence_eligible` through the adult identity views, then applies
the eligibility gate to identity promotion, GPS-linked parent evidence, XX
supersession, MM evidence, negative-brood parent selection, same-occasion H and
chick association, the S10 linker, and the legacy scrape helper. This is a
read-side fail-closed rule. It does not rewrite biological rows, and it does
not suppress a qualifying H-photo ring/media count solely because an adult
event has an uncertain mark. Broader current-occasion conflicting-ID
validation remains Thread 3.1's save-time responsibility.

## Location and temporal contract

Operational brood location means the latest **valid direct chick-event
location**, not the latest event regardless of GPS completeness:

1. Filter age-C CAPTURES and RESIGHTINGS events through
   `settings.reference_date`.
2. Keep events with a non-null paired GPS key that resolves to `GPS_POINTS`.
3. Select the latest valid direct event for the brood ID.
4. If a positive brood has no valid direct chick-event location, use the
   positive nest's NESTS anchor.
5. Never use a NESTS fallback for a negative brood.
6. Exclude historical adult-capture sentinel rows from brood-derived outputs;
   the active entry contract uses blank `nest_id` plus complete direct GPS.

The current event ordering is deterministic: event date descending, event
datetime descending where available, source priority, then primary key
descending. CAPTURES uses `released`, then `caught`, then midnight; RESIGHTINGS
has no time field and therefore uses midnight. For equal-date direct-location
selection, the current source ranks H-class RESIGHTINGS first, then CAPTURES,
then other RESIGHTINGS, followed by primary-key order. This is an operational
compatibility rule and should be revisited if the field protocol gains a
reliable resighting time.

## Support objects and functions

### `settings`

`settings(variable, value)` provides the canonical `reference_date`. Major
operational views use the non-null `reference_date` row as a fail-closed input.
Changing the date changes derived output and requires a current task snapshot
before PDF/download workflows are considered current.

### `spatial_objects`

`spatial_objects` stores named WKT objects used by maps and mock-data helpers.
It is part of the app database structure even though it is not a biological
event table.

### `inspectors`

The validator architecture is DB-stored. `DataEntry/inspectors/` edits the
`inspectors` table; table-specific `global.R` files configure presentation,
defaults, and dropdowns. Current live biological tables should use the two
inspector classes `TABLE_hard` and `TABLE_warning`, with package-side validator
output following the documented `rowid`, `variable`, and `reason` contract.
Thread 2 does not edit live inspectors.

### `predict_hatching`

`predict_hatching` is a stable support table with a primary key on `egg_id` and
a float-state lookup index. It supplies calibration values to
`EGGS_HATCH_PREDICTION`; its biological validity remains a collaborator-owned
assumption.

### `format_mark()`

`format_mark(UL, LL, UR, LR)` trims values, suppresses literal `X` and `M` on
each side, joins retained upper/lower values with `.`, and returns an `X`-
placeholder left-right mark. It is a deterministic formatter, not a complete
identity-normalization system. View normalization for combo allocation must
remain explicit and must not silently change this function's output contract.

## Derived-view architecture

### `CAPTURES_ARCHIVE`

`CAPTURES_ARCHIVE` is a historical compatibility view over `BADOatNZ.CAPTURES`
and the historic `BADOatNZ.SEX` lookup. It supplies historic release marks,
metadata, morphology, tag fields, and `gen_sex` to current combo and Overview
logic. It is a cross-database compatibility gate: a 2026-only database cannot
create it unless the historic objects are available.

The current app source-watch mapping names `BADOatNZ.CAPTURES` but not the
historic `SEX` dependency. Any SEX-table change therefore requires an explicit
manual refresh/review rather than relying on the watcher alone.

### `USED_COMBOS_DETAIL` and `AVAILABLE_COMBOS`

`USED_COMBOS_DETAIL` combines historic archive marks, current release marks,
and current `_in` marks, all bounded by `reference_date` where applicable. It
trims/uppercases values, normalizes lower-leg combinations, preserves source
provenance, handles tag/spacer records, and flags rows that cannot be safely
normalized.

`AVAILABLE_COMBOS` generates candidate lower-leg pairs from the configured
site rules, subtracts normalized used combinations, applies fixed exclusions,
and ranks the remaining output for the PDF/team-mark workflow. CR/CX mapping
and selected site exclusions remain compatibility gates requiring collaborator
confirmation before generalization. The app exposes AVAILABLE_COMBOS but has no
equivalent explicit source-watch entry, so source changes require a deliberate
refresh/review.

### `NESTS_LATEST`

`NESTS_LATEST` remains the one-history-per-positive-nest view. It selects the
current nest state, clutch/brood values, hatch evidence, calibrated hatch
timing, and a stationary GPS location from NESTS/GPS_POINTS. It does not
fabricate rows for negative broods.

Parent `M_mark` and `F_mark` can be derived from both adult CAPTURES and adult
RESIGHTINGS by `nest_id`, allowing a previous capture followed by a later
nest-linked resighting to confirm parentage. The current `main/global.R` source
watch includes RESIGHTINGS for NESTS_LATEST; the older memo statement that it
was omitted is obsolete.

### `BROODS_LATEST`

`BROODS_LATEST` is the reusable one-row-per-positive-or-negative-brood source
for brood-aware map, PDF, parent, and task logic. It combines:

- positive nests with relevant hatch/brood evidence;
- negative IDs discovered in CAPTURES or RESIGHTINGS without NESTS/EGGS rows;
- parent marks and identity status from shared adult capture/resighting logic;
- chick capture and colour-band evidence;
- latest valid direct chick-event location, with positive-nest fallback only.

The contract includes these key fields:

```text
nest_id, brood_kind, is_negative_brood
discovery_date, latest_encounter_date, latest_encounter_datetime
latest_chick_event_date, latest_chick_event_source
gps_id, gps_point, lat, lon
location_source, location_event_date, location_event_datetime
location_event_pk, location_source_table
hatch_evidence_date, has_hatch_evidence
nest_state, hatch_state, clutch_size, brood_size, min_days_to_hatch
M_mark, F_mark, nest_photo, tent_photo, chick_band, reference_date
```

The current SQL is operationally Cass River scoped in the negative-brood path.
Extending this view to additional sites requires biological and collaborator
review; the source DDL's general negative-ID wording is not by itself approval
to broaden the derived view.

### `EGGS_HATCH_PREDICTION` and `GEO_ROLLOUT_PHENOLOGY`

`EGGS_HATCH_PREDICTION` joins long-format EGGS observations to
`predict_hatching`, prefers exact float-state matches, and supplies chronology
and reference-date fields to nest/task/PDF/Overview consumers. Incomplete
clutch and stable one-egg chronology are explicit biological assumptions.

`GEO_ROLLOUT_PHENOLOGY` supplies geolocator/phenology context used by the
parent/GEO task logic. Its quotas, ceiling, timing, and sex-balance rules are
operational policy rather than universal schema constraints.

### Identity and parent-status views

The current view layer includes normalized adult capture and resighting identity
surfaces, identity matches, GPS-linked chick/parent evidence, adult parent-nest
associations, and authoritative adult parent status. These views coordinate:

- metal-ring, flag, spacer, lower-mark, and full-mark identity keys;
- same-sex identity ambiguity and confirming/non-confirming association;
- MM/mobile-mistnet recapture chronology;
- single-colour recruits and `XX`/unknown identity handling;
- geolocator state, AU migrant state, dead/band-status state;
- exact GPS pair gates for eligible chick/parent links.

`ADULT_PARENT_STATUS` is the task-facing parent result. Thread 3.1 owns
save-time validation; Thread 4 owns task interpretation. SQL should not turn a
pending or ambiguous association into a confirmed parent merely to remove a
task.

### TODO context, task calculation, and publication

The operational chain is:

```text
source tables + settings + support objects
  -> bounded identity/parent/nest/brood/hatch inputs
  -> TODO_*_CONTEXT and TODO_PARENT_STATUS inputs
  -> task-family views / TODO_LIST_CALCULATE (where present in the selected revision)
  -> explicit *_SNAPSHOT_BUILD tables
  -> atomic snapshot publication
  -> lightweight TODO_LIST/TODO_PARENT_TASKS/TODO_NONPARENT_TASKS boundaries
  -> Shiny list, map, PDF, and status workflows
```

Current task families include parent capture, parent resighting, unprocessed
nest, scrape/tent photo processing, re-process nest, clutch check, nest check,
untrapped brood, hiding-spot photos, closure/notA follow-up, and related
disturbance/GEO tasks. Exact user-facing labels belong to Thread 4, but the
database contract must expose stable task columns and truthful parent/brood
status.

The protected current checkout contains a split calculator:
`TODO_LIST_PARENT_TASKS`, `TODO_LIST_NEST_TASKS`, `TODO_LIST_BROOD_TASKS`,
`TODO_LIST_CLOSURE_TASKS`, and `TODO_LIST_CALCULATE`. It also contains
snapshot-related definitions in the dirty `views.SQL`.

The clean `origin/main` baseline uses a different optimized install/refresh
boundary: the expensive calculation is not evidence that an active
`TODO_LIST_CALCULATE` should be installed in the production view layer. The
standalone `DATABASE/refresh_todo_list_snapshot.SQL` is the deployment-oriented
materialization workflow. Do not combine the dirty checkout's view file with a
different revision's refresh script.

The explicit snapshot schema currently includes task identity, reference date,
task label, notes, overdue/priority fields, nest state, clutch/brood values,
parent marks, location, authoritative parent marks, association-pending flags,
resighting identity counts, GEO priority/target/quota fields, migrant flags, and
the display overdue label. Consumers should use explicit projected columns,
not `SELECT *`, where a stable contract is required.

### `OVERVIEW`, `VIEW_1`, and app-facing outputs

The SQL `OVERVIEW` view is a reference-date-filtered metric source. The main
app's eight-panel Overview is primarily assembled in `main/R/ggplot_overview.R`
and also queries source tables, `EGGS_HATCH_PREDICTION`, and
`CAPTURES_ARCHIVE` directly. Do not assume the SQL `OVERVIEW` view alone is the
dashboard contract.

`VIEW_1` is a current tagged-bird/resighting output with a source watch for
`settings`, `CAPTURES`, and `RESIGHTINGS`. `main/global.R` still advertises
`VIEW_2`, but the current SQL inventory does not define `VIEW_2`; this is a
browser contract mismatch requiring an owner decision.

## App and downstream dependency map

The current main app source-watch mapping includes:

- `TODO_LIST`: `settings`, `NESTS`, `GPS_POINTS`, `CAPTURES`, `EGGS`,
  `predict_hatching`, `RESIGHTINGS`;
- `NESTS_LATEST`: the same current-season sources, including RESIGHTINGS;
- `BROODS_LATEST` and `LIVE_NEST_MAP`: the same current-season sources;
- `EGGS_HATCH_PREDICTION`: `settings`, `NESTS`, `EGGS`, `predict_hatching`;
- `OVERVIEW`: `settings`, `CAPTURES`, `NESTS`, `EGGS`, `RESIGHTINGS`;
- `CAPTURES_ARCHIVE`: historic `BADOatNZ.CAPTURES` only in the current watch;
- `VIEW_1`: `settings`, `CAPTURES`, `RESIGHTINGS`.

Consumers include:

- `main/server.R`, which loads NESTS_LATEST/BROODS_LATEST for maps and manages
  the refresh status workflow;
- `main/R/leaflet_nest_latest.R` and `main/R/kmz_nest_latest.R`, which consume
  nest/brood location and status fields;
- `main/R/pdf_todo.R` and `main/R/pdf_todo_map.R`, which consume bounded
  TODO_LIST, BROODS_LATEST, parent status, hatch context, and combo outputs;
- `main/R/ggplot_overview.R`, which has independent source/view queries;
- `main/R/system_utils.R`, which launches the refresh SQL through a local
  MariaDB/MySQL client and checks snapshot reference-date freshness;
- `DataEntry/*/global.R`, which configures table presentation and dropdowns;
- `gpxui/`, which supplies GPS_POINTS/GPS_TRACKS data.

Static alignment note: `DataEntry/CAPTURES/global.R` currently supplies
dropdowns for existing controlled fields and observer lookups, but the current
source inspection did not find an explicit `eggs_handled` dropdown entry. This
is an app-alignment item for the DataEntry owner, not a reason to change the
DDL. Do not edit it from Thread 2 unless separately requested.

## Dependency and deployment order

For a clean local replay or controlled deployment, use a matched source pair:

1. Select/create the target schema.
2. Create core tables from `main_tables.SQL`.
3. Create support tables from `support_tables.SQL`.
4. Load `predict_hatching.SQL`.
5. Create SQL functions from `functions.SQL`.
6. Install the selected `views.SQL` in its dependency order: historic archive
   and combo views, NESTS_LATEST, H-photo helper, BROODS_LATEST, hatch/phenology,
   identity/parent views, task input/family views, and reporting/public views.
7. Run the matching `refresh_todo_list_snapshot.SQL` separately with the SQL
   client configured to stop on error.
8. Verify snapshot publication and reference-date status before restarting or
   relying on Shiny/PDF consumers.

`CAPTURES_ARCHIVE` additionally requires compatible historic `BADOatNZ.CAPTURES`
and `BADOatNZ.SEX` objects. A failed large SQL paste can leave a mixed set of
old/new/missing views; success of the client command alone is not sufficient.
Use `SHOW CREATE VIEW`, `SHOW CREATE TABLE`, object inventory, reference-date
checks, and refresh-status checks in an approved target environment.

Never use `_reset.SQL` as an in-place migration. It starts by dropping the
database and is suitable only for an explicitly disposable local rebuild.

## Index and performance stance

Current DDL already provides:

- GPS lookup keys on `GPS_POINTS(gps_id, gps_point)` and event-table GPS fields;
- nest/date/site and event primary-key indexes appropriate to the source tables;
- `CAPTURES(nest_id, age, date, pk)` and
  `RESIGHTINGS(nest_id, age, date, pk)` for repeated brood chronology queries.

Do not add a `RESIGHTINGS.ring` index merely because the field exists. Current
helpers use ring within reference-date-bounded event logic and do not establish
a standalone index requirement. Any new index needs an EXPLAIN-backed query
benefit, a write-cost review, a duplicate-index check, and an object-specific
rollback statement.

## Compatibility gates and unresolved risks

1. The historic `BADOatNZ.SEX` dependency of CAPTURES_ARCHIVE is not fully
   represented by the current source-watch list.
2. `AVAILABLE_COMBOS` has no equivalent explicit source-watch mapping.
3. `VIEW_2` is advertised by the app but is not defined in the current SQL
   inventory.
4. `TODO_REFRESH_STATUS` is part of the remote optimized install/status design,
   while the current dirty `views.SQL` and refresh script must be checked as a
   matched pair before deployment; a status-table mismatch can make a healthy
   or failed refresh appear unknown.
5. The current checkout's dirty split calculator and snapshot blocks differ from
   the clean remote baseline. The dirty file also contains repeated
   snapshot/Overview definitions during the active WIP experiment. They are
   protected WIP, not an approved live schema. The refresh-only fix `ad1698b`
   was subsequently merged through PR #147 and is present in the publication
   baseline `f7d13fb`; that source merge is not evidence of live deployment.
6. The source tables have no foreign keys, so invalid nest/GPS links remain a
   validator/post-save-QA concern.
7. Negative-brood derived logic is currently Cass River scoped. Broader use
   needs biological confirmation.
8. `FM` and `MF` both represent both sexes but are distinct enum values.
   Canonicalization needs collaborator confirmation before changing summaries.
9. H-photo task closure uses distinct normalized rings, paired direct GPS,
   complete photo metadata, and reference-date-bounded qualifying associations.
   A missing or ambiguous association must remain open rather than being
   silently inferred.
10. Parent identity, MM, `XX`, single-colour recruit, geolocator, disturbance
    interval, seven-day capture, clutch-completion, and hatch-estimate logic are
    biological operational policy and require collaborator confirmation before
    generalization.

## Migration, rollback, and verification

No migration is authorized or executed by this memo. Do not re-run
`main_tables.SQL` or `_reset.SQL` against an existing database. For an approved
deployment, use object-specific statements, capture schema-only definitions,
and plan for metadata locks on view/table changes.

For the nullable RESIGHTINGS `ring` field, the reviewed reference migration is:

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

Run it only after metadata confirms the field is absent and after a schema/data
backup. Rollback is an explicit `DROP COLUMN ring` only if the field was added
by that migration and any entered values have been preserved; dropping it is
data-destructive and requires collaborator approval.

For view/task changes, rollback means restoring the previous approved
`CREATE VIEW` definitions and published snapshot boundary in dependency order,
not deleting biological rows. For refresh failure, discard only incomplete
`*_BUILD` objects after confirming the prior public snapshot remains intact.

Static verification for a candidate deployment should include:

- `SHOW CREATE TABLE` for source DDL, especially ring, enum, comments, and
  indexes;
- `SHOW CREATE VIEW` for archive, H helper, brood, TODO, and public boundaries;
- dependency/object inventory after install;
- reference-date and refresh-status checks;
- invented fixtures for positive nest, positive brood with later direct chick
  GPS, negative brood first seen in each event table, same-day events, H-photo
  resolution, ambiguous same-GPS candidates, missing GPS, and `NO_NEST`;
- SQL-level checks that duplicate H rows count once and ambiguous candidates do
  not receive a derived ID;
- focused static tests for split task boundaries, snapshot publication, PDF
  projections, app watchers, and `VIEW_1`.

This documentation pass did not run those checks against a database or execute
the test suite.

## Cross-thread handoffs

**Thread 1:** owns repository map, AGENTS governance, branch hygiene, and
clean-PR selection. Keep dirty WIP distinct from the deployable revision.

**Thread 3/3.1:** owns validator protocol and DB-stored inspectors. Enforce
negative-ID table restrictions, paired GPS, H-class ring/photo requirements,
and current CAPTURES/RESIGHTINGS existence rules. Do not make validators rewrite
raw nest IDs or fabricate NESTS rows.

**Thread 4:** owns task/PDF/map behavior. Consume BROODS_LATEST and the shared
H-association/parent-status outputs rather than duplicating source unions or
location ranking in R. Treat snapshot refresh as separate from SQL view install.

**Thread 5:** owns Overview panels and their source/query contracts. Check
CAPTURES_ARCHIVE and reference-date behavior independently of TODO correctness.

**Thread 6:** owns available-combo policy, normalized mark allocation, CR/CX
compatibility, and team-mark ordering. Preserve `format_mark()` and source
provenance unless the combo protocol is deliberately revised.

**Thread 8:** owns Field Manual/downstream documentation for H-event and
negative-brood workflows. The SQL helper remains conservative and deployment
must verify the exact derived-view definition.

**Thread 9:** owns isolated local MariaDB replay, stage timing, process/error
diagnostics, and refresh troubleshooting. Start from a clean selected revision,
not this dirty checkout, and report sanitized object/timing evidence only.

## Previous assumptions now obsolete

- `Admin/db_structure.SQL` is no longer the schema authority.
- EGGS is not an approved wide-format redesign; it remains long format.
- `observer_upload` is not a shared field; it is CAPTURES-only.
- `eggs_handled` is a current CAPTURES field between GPS linkage and field sex.
- `RESIGHTINGS.ring` is not future-only; it is present in the current tracked
  DDL and is part of the H-photo contract.
- `NO_NEST` is not an active adult-capture entry convention; new unrelated
  adult captures use blank `nest_id` plus complete direct GPS. Defensive SQL
  exclusions remain only to prevent historical literals from becoming real
  positive associations.
- A full or lower mark containing `?` is not reusable parent evidence merely
  because the other fields form a complete key; only a verified metal-ring
  exception makes the event eligible.
- `BROODS_LATEST` is not merely a proposed future object; it is implemented in
  the current SQL architecture and consumed by brood-aware downstream logic.
- The older claim that NESTS_LATEST does not watch RESIGHTINGS is stale; the
  current app mapping includes it.
- The current dirty split calculator must not be described as the clean remote
  deployment architecture.

## Recommended next Thread 2 checks

1. Select one clean revision and verify that its `views.SQL` and refresh script
   are a compatible install/refresh pair.
2. Compare the deployed target's object definitions to that pair using approved
   metadata-only checks.
3. Decide whether `TODO_REFRESH_STATUS`, `VIEW_2`, and the historic SEX watch
   are intentional compatibility gaps or should be corrected by their owners.
4. Ask collaborators to confirm Cass River scope, `FM`/`MF` semantics, parent
   identity thresholds, direct-location ordering, and H-photo exception rules
   before generalizing SQL.
