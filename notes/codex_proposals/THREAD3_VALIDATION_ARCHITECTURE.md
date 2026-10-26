# Thread 3.1 validation architecture and current-state handoff

Publication reconciliation: this handoff is being published from
`origin/main` at `f7d13fb`. The `9beb203` and `d3c7bd4` values below preserve
the Thread 3.1 recovery audit's inspection provenance; they are not the
documentation branch's current source baseline. The publication pass updates
`AGENTS.md` and tracks the sanitized prompt summary separately, without
approving or deploying the protected validator WIP.

## Audit status

This document records the current local validation contract after a
documentation-only recovery and source-to-document reconciliation on
2026-10-23. It is a tracked documentation handoff for the local
inspector/protocol work, not evidence that live inspectors have been deployed.

- Repository: `2026_NZ_FIELDWORKER`
- Protected checkout: `codex/split-todo-calculator-2026-10-19` at `d3c7bd4`
- Local `origin/main` reference at inspection: `9beb203ac2757219def35e47bfe54bd6ac8684a2`
- The reviewed per-table `*_hard.R` and `*_warning.R` inspector lists are
  already tracked under `validator_sandbox/inspector_lists_by_table/`.
- The checkout already contains protected dirty WIP in four inspector exports,
  SQL, PDF code, tests, and several handoffs. This recovery pass changes only
  the two authorized Thread 3 documentation files; it does not approve,
  revalidate, stage, deploy, or otherwise modify that WIP.
- No live database was connected to.
- No live `inspectors` row was queried or changed.
- `AGENTS.md` was not changed in this update; its standing human-control and
  live-database restrictions remain authoritative.

The external canonical working protocol was version **1.3.5**, generated
2026-10-24, when this branch was prepared. The tracked local mirror on this
branch is updated to proposed version **1.3.6**, generated 2026-10-26, to record
the photo-range identity and same-session H-photo exception described below.
Because the external working file is outside this repository and is not changed
by this branch, v1.3.6 is a staged protocol/documentation update, not evidence
that the external copy or live inspectors have been synchronized.

Version 1.3.4 makes parent/chick co-entry save-blocking within one RESIGHTINGS
portal submission: every age-C row, including ordinary `rclass = R`, `P`, or `V`
rows, must be linked to an age-A parent whose behavior includes `BC` or `FC`,
and each such parent row must have at least one linked age-C row. Version 1.3.4
also separates active-nest `IN`/`NM` state checks from brood-association checks
and documents `BW` as broken-wing display. The current local RESIGHTINGS
implementation artifacts additionally contain an `AC` extension; the
hard-export portion is protected WIP, and the extension is not part of the
verified protocol identity or a deployment claim. Version
1.3.3 requires a real nest or brood link for age-C first captures and permits an
optional complete GPS pair for positive-nest chicks captured away from the nest.
Version 1.3.2 adds save-blocking H-ring format and current-CAPTURES existence
checks. The H-ring rule remains restricted to normalized `rclass = H`; ordinary
RESIGHTINGS classes may still leave `ring` blank.

## Authority order

When sources disagree, use this order and document the disagreement before changing
anything:

1. Current tracked schema and application wiring:
   `DATABASE/main_tables.SQL`, `DATABASE/support_tables.SQL`, `DATABASE/functions.SQL`,
   `DATABASE/views.SQL`, and the table-specific `DataEntry/*/global.R` files.
2. The official validator YAML:
   `/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/bdot_db/data/working/bdot_dataentry_validator_protocol.yaml`
3. The synchronized local protocol mirror:
   `notes/codex_proposals/validator_sandbox/xlsx_short_tag_update/bdot_dataentry_validator_protocol_plot_aligned.yaml`
4. The local paste-ready hard/warning exports under:
   `notes/codex_proposals/validator_sandbox/inspector_lists_by_table/`
5. Connected mock workbook, CSV exports, repair scripts, focused tests, and reports.
6. Older prompt logs and planning documents, which explain intent but do not override
   current schema, protocol, or implementation.

The official YAML is the validator behavior specification. The local exports show the
intended inspector implementation but do not prove what is stored in the live database.

## Architecture and execution flow

The application uses the external `DataEntry` package for table editing and validator
execution. Biological validators are stored centrally in the database `inspectors`
table; the old table-specific `DataEntry/*/inspector.R` files are obsolete.

The local architecture is:

1. `DataEntry/*/global.R` supplies table names, columns, dropdowns, defaults, and
   prefilled data to the package-driven data-entry UI.
2. `DataEntry/inspectors/global.R` identifies the `inspectors` table, with
   `table_name` as the identifier and `inspector` as the R-code column.
3. `DataEntry/inspectors/ui.R` and `server.R` expose the central inspector editor.
4. The external package loads the DB-stored inspector lists and evaluates them against
   the submitted table as `x` before save.
5. The portal reports `variable`, `reason`, and `rowid`. Hard and warning behavior is
   separated by inspector row name, not by an extra output column.

The intended live categories are exactly:

- `TABLE_hard`: save-blocking rules corresponding to protocol `hard_rules`;
- `TABLE_warning`: non-blocking review rules corresponding to protocol `warning_rules`.

There is no current live `TABLE_residual` or `TABLE_format_residual` category. Any
legacy format or migration rule must be assigned to hard or warning based on actual
save-time severity.

The external package-side details of inspector loading, ordering, exception display,
and warning presentation are not fully visible in this repository. They must be
verified in a controlled portal session before live deployment.

## Validator contract and safety rules

Each inspector expression receives the current submitted table as `x` and must return
a data frame/data table containing at least:

- `rowid`: submitted-table row number;
- `variable`: failing field name;
- `reason`: fieldworker-facing explanation.

No-problem results must be zero-row results with those columns. Validators must create
or preserve `rowid` before filtering or joining and must wrap each expression in
`try_validator(nam = "short name")`. Local validators normalize blank strings, textual
`NA`, and SQL `NA` separately where the rule requires it.

`variable = NA` or a message saying that a named validator threw an error is an
implementation failure, not a biological result. Blank-row saves, empty database
lookups, failed archive queries, and empty `rbindlist()` inputs must be guarded.

The current portal does not expose a general `type` or `severity` output column.
Severity therefore comes from the hard/warning inspector category. Mock-only and
post-save rules must not be pasted into live inspectors.

## Current schema and table roles

The source-of-truth SQL is in `DATABASE/`, not older `Admin/db_structure.SQL` paths.

- `CAPTURES`: in-hand captures, recaptures, banding, tags, morphometrics, samples,
  nest/brood links, and tent-photo metadata. It has `field_sex`, release and `_in`
  marks, `capture_status`, `capture_method`, `ring`, and CAPTURES-only fields such as
  `eggs_handled` and `observer_upload`.
- `EGGS`: one row per egg, with float and photo metadata. Negative IDs and `NO_NEST`
  are invalid.
- `NESTS`: nest visits and nest state, hatch state, clutch/brood counts, incubation
  indication, GPS linkage, and nest/tent-photo metadata.
- `RESIGHTINGS`: opportunistic and targeted observations, including parent/chick
  records and hiding-spot photographs. `ring varchar(50)` is nullable generally but
  required for H-class chick rows.
- `RESIGHTINGS_PUBLIC`: separate public-observation workflow; it is not part of the
  nest-parent/H-photo operational contract.
- `GPS_POINTS` and `GPS_TRACKS`: GPS upload products. Biological event GPS pairs are
  checked against `GPS_POINTS`.
- `CAPTURES_ARCHIVE`: historical capture lookup surface used by selected validators.
- `NESTS_LATEST`, `BROODS_LATEST`, `TODO_LIST`, and related views: downstream
  operational/task surfaces, not substitutes for save-time validation.
- `inspectors`: DB-managed validator storage and editing surface.

## Rule inventory by functional area

The v1.3.4 protocol established these rule families; the staged branch mirror
adds the v1.3.5 AC revision and v1.3.6 photo-range clarification. The exact rule
IDs and descriptions remain in the YAML; this section explains their implementation role.

### Shared rules

Hard shared rules cover field-season date range, allowed site values, blank system
fields (`nov` and related upload flags), GPS pair completeness/existence, and global
photo-number uniqueness. The photo rule preserves terminal roll-frame prefixes
(so `101-4122` and `102-4122` are different images) and ignores a final filename
extension. Its only reuse exception is for age-C `rclass = H` RESIGHTINGS rows
from the same camera and date that share either the same nonblank `nest_id` or the
same complete `gps_id/gps_point` pair. Adult `P`/`V` rows and cross-table rows do
not receive that exception. Shared warning rules cover GPS timestamp plausibility
and other review-only timing/context checks. Photo and GPS rules are cross-table
where the submitted event depends on `GPS_POINTS` or an image range used elsewhere.

### OBSERVERS

Hard checks cover required identity, observer initials, start/stop dates, GPS/camera
list syntax, and supported GPS identifier format. There are no current warning rules.

### EGGS

Hard checks cover required event/egg fields, positive nest syntax, date/time, float
angle/surface/location coherence, egg identifiers and clutch limits, photo metadata,
and photo sequence ordering. Warning checks cover likely matching NESTS visits,
missing/unusual float data, float-development spread, and event context.

The former live expectation that floating must occur on discovery day or within two
days is mock-generation-only (`EGG_M002`), not a save blocker.

#### EGGS floatation stage-spread matching

The `EGG_W004 stage spread` warning compares calibration-derived developmental
stages for eggs floated in the same EGGS event (same `nest_id`, date,
`time_visit`, and observer). The `predict_hatching` calibration is based on
Kentish plover data and is not a Banded Dotterel-specific incubation curve.

When an exact `(float_angle, float_surface, float_location)` calibration row is
unavailable, the inspector prioritizes the same `float_surface` before the
nearest angle. This prevents a `90°/surface/3` observation from being matched
to `90°/surface/0` merely because the angle is exact; it instead uses the
nearest available same-surface calibration, such as `75°/surface/3`.

The current calibration has no direct `80°/surface/3` or `90°/surface/3`
entries. This inspector does not invent those values or modify the
`predict_hatching` table. With the current table, both readings therefore use
the same-surface `75°/surface/3` calibration rather than creating an artificial
developmental-stage difference from the `90°/surface/0` rows.

For Banded Dotterels, the operational timing is approximately a two-day laying
interval plus 26 days after clutch completion, or about 28 days from the first
egg for a complete clutch. The Kentish calibration's `75°/surface/3` endpoint
is about 30 days, so it should not be interpreted as a literal Banded Dotterel
hatch date. The warning is a relative consistency check; it must not use an
unmatched surface-height calibration to manufacture a difference greater than
seven days.

### NESTS

Hard checks cover required fields, species/site/state codes, positive Cass and
non-Cass ID syntax, negative/`NO_NEST` rejection, first-event GPS, date/time, nest
chronology, hatch-state progression, clutch/brood numeric fields, camera/photo
metadata, photo uniqueness, terminal-state rules, and discovery tallies.

Important current semantics:

- Cass BADO IDs use the established A/B/C prefixes; Cass WRYB IDs use `WR`.
- Positive non-Cass species use their approved species prefixes.
- Negative IDs are not NESTS records.
- `S` has clutch size 0 and allows brood size 0/blank; `notA` normally uses clutch
  size 0, with the approved same-submission D-closure exception.
- Valid `bird_inc` codes remain valid independently of nest state.
- Hatching-state components are parsed by component rather than assumed to occur in a
  fixed textual order.

Warning checks cover hatch review, observer/GPS defaults, photo/clutch review,
clutch progression, offspring totals, brood-without-eggs review, predated rows,
H-row review, photo-visit review, photo flags, and GPS timestamp plausibility.

The old same-day H-row comparison to CAPTURES/RESIGHTINGS was removed from live
validation. `NEST_010D` is post-save QA: later chick capture/resighting is acceptable,
portal sessions may be separate, and CAPTURES need not precede RESIGHTINGS. The old
same-date `bird_inc` versus RESIGHTINGS comparison is also not a live warning because
RESIGHTINGS has no event-time field. `NEST_012` retains the review as post-save/manual
QA when a reliable event key exists.

### CAPTURES

Hard checks cover required fields; season/site/observer/time; capture status and
method; positive/negative/`NO_NEST` location branches; ring/mark and `_in`/release
coherence; age and field-sex codes; hatch evidence; prior nest history; tags,
morphometrics, samples, moult/fat; photo metadata and range order; global photo
uniqueness; uploader initials; comma-mark rejection; and status-specific field rules.

Location semantics are:

- positive nest-linked capture: established nest-location branch;
- negative brood ID: negative ID plus both direct GPS fields, with a valid
  `GPS_POINTS` pair;
- blank or `NO_NEST`: direct GPS branch, with both GPS fields as required by the
  current contract.

There is one narrower first-capture exception: an age-C row with
`capture_status = F` must carry a real positive nest ID or negative brood ID;
blank `nest_id` and `NO_NEST` are rejected. For a positive nest ID, both GPS fields
may remain blank when the chick was captured at the nest, or may be supplied
together when it was captured away from the nest. Partial GPS pairs remain invalid.
Negative brood rows continue to require both GPS fields.

Negative IDs do not undergo a NESTS lookup and do not use the positive-nest/direct-GPS
exclusivity rule.

Warnings cover prior ring/combo history, unusual status/method combinations, parent
spacing, same-sex adult multiplicity, photo-flag review, nest/hatch evidence,
morphometric/tibia review, and GPS timing. `CAP_W013` warns when a chick capture
comment suggests “in situ” hiding photos; hiding photos belong in a separate H-class
RESIGHTINGS event. A chick tent photo remains a CAPTURES event (`chick_tent_photo`),
not an H photo.

`CAP_013` blocks status `R` when input marks differ from release marks. If prior ring
history supports a changed-combination recapture, the message directs the worker to
use status `C`; unavailable history is not treated as proof of no match.

### RESIGHTINGS

Hard checks cover required core fields, permitted classes (`C`, `V`, `R`, `P`, `H`),
date/site/observer, GPS pair and GPS existence, age/sex/behavior coherence, mark
format and H-class band layout, informative marks, nest/brood linkage, positive-nest
chronology, post-death/pre-discovery restrictions, photo metadata and photo sequence,
global photo uniqueness, and camera/photo formats.

The H-class contract is:

- normalized `rclass = H` requires age `C`, and age-C H requires sex `U`;
- `species`, `observer`, `date`, `rclass`, `sex`, and `age` are required;
- `ring` must be nonblank; blank, whitespace-only, SQL `NA`, and textual `NA` fail
  with `variable = "ring"`;
- a nonblank H ring must use the CP metal-ring format `CP12345` or `CP-12345`;
- the normalized H ring must already exist in current-season `CAPTURES`; CP/CP-dash
  forms are treated as equivalent for this lookup;
- `ring` identifies the photographed chick but does not replace `UL`, `LL`, `UR`, or
  `LR`;
- the approved H band layout remains enforced;
- GPS pair, camera, photo start, and photo end are required and valid;
- photo end cannot precede photo start, and the image range must not overlap an image
  already used by another event, except for the approved same-session age-C H-photo
  reuse rule described above;
- `behav` may be blank for H, but entered chick behavior must use permitted codes;
- a positive-nest H row must not precede that nest’s first NESTS `F`, `I`, or `H`
  event; same-day entry is allowed.

An H row is normally linked with a positive or negative `nest_id`. The current
save-time exception in `RES_005B` permits a blank `nest_id` only for an H row with
the mandatory GPS pair and either a nonblank ring or a same-submission age-A row at
the same GPS pair with both lower-leg fields. RES_010A and RES_010B independently
require that a ring used for the ring branch has the CP format and exists in current
CAPTURES. This remains intentionally narrower than a full family-association proof,
but the separate same-session co-entry rule below still applies to an unlinked H row.

Warning rules cover capture-history mark comparison, capture-history sex comparison
(`RES_005H`), social-parent mark mismatch, mixed-brood review, device defaults,
tibia review, and GPS timing. The former one-directional
`RES_006`/`RES_007` same-occasion warnings have been removed from the live warning
export because the reciprocal requirement is now save-blocking in `RES_005J`.

`RES_005H` compares the RESIGHTINGS `sex` field to the identified bird’s capture
history, preferring nonblank archive `gen_sex`, then archive `field_sex`, then current
capture `field_sex`. `M`/`MU` and `F`/`FU` are equivalent. Unknown, ambiguous, or
unavailable history is not a definite contradiction. A definite mismatch is a
warning on `variable = "sex"`, not a save blocker.

### RESIGHTINGS_PUBLIC

Hard rules cover required public-source fields, allowed values, marks, date/time,
GPS/photo formats, and other row coherence. Warnings cover source recognition,
optional time, comma marks, tibia placement, and partial mark-history review. Its
workflow is separate from H-photo and negative-brood operational logic.

## Negative-brood methodology

A leading-minus `nest_id` is a linked operational brood identifier for unknown origin:
no eggs were observed, no nest was found, and no stationary nest location is known.
The minus sign is part of the value and must be retained.

- Negative IDs are valid in CAPTURES and RESIGHTINGS.
- Negative IDs are rejected in NESTS and EGGS with directions to enter birds in
  RESIGHTINGS or CAPTURES.
- Every negative-ID CAPTURES or RESIGHTINGS row requires the negative ID, both
  `gps_id` and `gps_point`, and a GPS pair present in `GPS_POINTS`.
- This is an explicit exception to positive-nest/direct-GPS exclusivity because a
  negative brood has no stationary NESTS location to inherit.
- The first event may be CAPTURES or RESIGHTINGS.
- Each bird and each encounter is a separate row. Repeated X-X rows can represent
  distinct unbanded parents or chicks and must not be deduplicated.
- Subsequent negative-ID events retain the same operational ID and carry their own
  event GPS pair.
- `NO_NEST` means no associated nest or brood; it is not a negative brood.

Hiding-spot photos are separate age-C, `rclass = H` RESIGHTINGS events. A chick can
therefore have one CAPTURES row for handling/banding/tent photos and a separate H row
for its hiding-spot photo. Negative H rows additionally require the negative ID and
both direct GPS fields. CAPTURES `chick_hide_photo` is retained for compatibility but
is not the normal hiding-photo record.

Photo-range identity is rollover-aware. A terminal `roll-frame` value is compared
using the roll prefix and four-digit frame together, so `101-4122` cannot collide
with `102-4122`; a final filename extension is ignored. `GLOBAL_005` remains a
save-blocking cross-table check for all ordinary reuse, including adult `P`/`V`
RESIGHTINGS rows and CAPTURES/NESTS/RESIGHTINGS combinations. The narrow exception
allows multiple age-C H rows to document one same-camera, same-date photo session
when they share the same nonblank `nest_id` or the same complete GPS pair. When an
existing saved row is edited, its own stored `pk` is excluded from the comparison.

## Cross-table, chronology, and history boundaries

Save-time checks can use current table rows, `GPS_POINTS`, current-season tables,
`CAPTURES_ARCHIVE`, and selected nest-history surfaces. Most cross-table history
checks still must not assume that companion rows are in the same portal submission.
There is one explicit approved exception: parent/chick co-entry is mandatory when
the current RESIGHTINGS submission contains age-C rows or age-A `BC`/`FC` rows.
The association is tested only within the current submission, using the same date
and either the same nonblank `nest_id` or the same complete `gps_id/gps_point` pair.
Saved rows from earlier sessions do not satisfy this hard rule. The protected
working-tree RESIGHTINGS exports currently extend the qualifying behavior set
with `AC`; that extension is WIP and is not certified by protocol 1.3.4.

Archive-aware rules distinguish:

1. a successful lookup with matching history;
2. a successful lookup with no match; and
3. an unavailable lookup.

Only the first two support a definite comparison. `RES_005H`, RESIGHTINGS combo
history, and CAPTURES prior-combo logic explicitly preserve that distinction. Some
duplicate checks still fail open without a dedicated outage message; this remains an
implementation-quality item, not a new biological rule.

The parent/MM operational methodology is also deliberately not a new hard validator:
CAPTURES capture-method/nest linkage, first-marking/tag warnings, caught-with context,
RESIGHTINGS mark-history/social-parent warnings provide evidence. Thread 4’s
TODO/view logic can require stronger, reference-date and
family-link evidence than a row-level save validator. Do not add a hard MM rule merely
to make a task disappear; record truthful marks and behavior and resolve ambiguity in
post-save/task logic.

## Parent/chick co-entry and behavior-stage rules

`RES_005J` is save-blocking and applies to every age-C RESIGHTINGS row, not only
H-photo rows. Under verified protocol 1.3.4, a chick row may use `rclass = H`,
`R`, `P`, or `V`, but it must be accompanied in the same portal submission by an
age-A row whose comma-separated behavior includes `BC` or `FC`. Conversely, a
parent row with `BC` or `FC` must have at least one linked age-C row in that
submission. The parent and chick can be linked by the same valid `nest_id` or by
the same `gps_id/gps_point` pair; the date must also match. This does not use
saved RESIGHTINGS history to bypass the rule.

The current local `RESIGHTINGS_hard.R` and `RESIGHTINGS_warning.R` artifacts add
`AC` (Alert with chick(s)) to this behavior set. The hard-export change is
protected WIP, and the official protocol still says `BC`/`FC`; this document
does not present `AC` as approved or live. A future implementation pass must
either promote `AC` into both protocol copies and the corresponding UI/helper
source, or remove the WIP extension after a human decision.

`BW` means broken-wing display, not brood watch. It is a shorebird parent behavior
that can occur at either the nest stage or the brood stage, so it remains part of
the broad parent/nest-link behavior set but does not by itself assert that an
individual chick was observed and does not trigger the reciprocal `BC`/`FC`/`AC`
rule.

`RES_005D` now restricts adult `IN`/`NM` rows to positive nest_ids whose latest
state is `F`, `I`, or `H`; `H` remains valid during asynchronous hatching. It no
longer blocks adult `BW`, `BC`, or `FC` rows merely because the nest is at a later
state. `RES_005K` requires positive-nest `BC`/`FC` rows to have latest state `H`
or `notA`, and requires `gps_id/gps_point` for age-C rows and brood-associated
adult `BW`/`BC`/`FC` rows when a `notA` nest still has `brood_size > 0`. The dirty
WIP export applies the same state logic to `AC`, but that is not yet protocol-
verified.

The existing unlinked-H exception remains a narrow row-level exception: mandatory
H GPS/ring/photo evidence still applies, and the row may omit `nest_id` only under
the existing conditions. It does not remove the new same-session requirement for
an accompanying age-A `BC`/`FC` parent under the verified protocol; the dirty
export extends this to `AC` as protected WIP.

Thread 2’s schema memo and Thread 4’s TODO/map planning describe a stricter internal
derived association: prior chick-CAPTURES ring/family evidence plus same-date, exact
GPS parent evidence, unique candidate resolution, and an ambiguity hold. That is a
reasonable task-level contract, but it is not the current live validator contract.

The checked-out schema layer does not currently establish that helper as deployed:

- `HEAD:DATABASE/views.SQL` has no `RESIGHTINGS_H_BROOD_ASSOCIATIONS` definition or
  reference;
- the pre-existing dirty working-tree `DATABASE/views.SQL` references the helper from
  `BROODS_LATEST` and hiding-photo CTEs but still does not define it;
- `tests/testthat/test-todo-view-rules.R` currently expects that reference not to be
  present;
- historical commit `5d625df` contains an earlier helper-view implementation, but it
  is not an ancestor of the current `HEAD` and is not deployment evidence.

Therefore the current state is not “derived association deployed.” The save-time H
validator should not be silently tightened in this documentation task. Before any
TODO/view rollout, Thread 2/4 must agree on the helper definition, evidence rules,
ambiguity behavior, SQL dependency order, and isolated tests. The stricter TODO
resolution contract should be documented as stricter than H-row save validation.

## Mock data and tests

The connected mock workflow is under:

`notes/codex_proposals/validator_sandbox/xlsx_short_tag_update/`

Relevant artifacts include:

- protocol mirror;
- `mock_badoatnz_portal_data_plot_aligned.xlsx`;
- `csv_exports/`;
- `run_mock_validators.R`;
- repair/export/audit scripts;
- `mock_validator_report.csv`;
- `negative_brood_methodology/` fixtures and test;
- focused tests for H GPS/ring/rules, negative broods, WRYB IDs, relaxed brood and
  `bird_inc`, NESTS photo/clutch checks, CAPTURES in-situ and status-change checks,
  social-parent marks, and RESIGHTINGS sex history.

The fixtures cover passing and failing negative IDs, missing GPS pairs, invalid NESTS/
EGGS negative IDs, H rows with missing/invalid/unseen ring values, repeated X-X
individuals, negative discovery through either table, separate tent/H-photo rows, and
history warnings. The connected report contains expected warnings and some known harness
limitations; a warning in the report is not proof that the live inspector is deployed.

Mock-generation rules shape fake data only. `post_save_qa` rules run after submission
and must not be compiled into save-time inspectors.

## Deployment status and manual rollout

The verified protocol and local implementation artifacts cover the current v1.3.4
semantics, but the checkout also contains protected dirty inspector WIP. Live
deployment is **not established**. No live `inspectors` rows were inspected or
changed.

Manual deployment, if separately approved, should be:

1. review the exact hard/warning export against the official YAML;
2. paste only the two approved rows per biological table into the intended database;
3. preserve a backup/export of the prior inspector rows;
4. validate parser behavior and blank-row behavior locally;
5. run a controlled portal save test with passing and failing invented rows;
6. verify that warnings do not block and hard rules do block;
7. record database/inspector update time and deployed source hash;
8. separately define and test any approved H-association SQL helper before enabling
   dependent TODO/map views.

Rollback is to restore the saved prior `inspectors` rows, restart the portal process if
the package caches inspectors, and rerun the controlled pass/fail save tests. Do not
rollback by editing biological data or by deleting unrelated SQL/R changes.

## Files inspected

The audit covered:

- `AGENTS.md`, `README.md`, and `main/www/help/intro.html`;
- `notes/codex_proposals/THREAD1_REPOSITORY_MAP.md`;
  `THREAD2_SCHEMA_REVIEW.md`; `THREAD4_TODO_MAP_LIST_DEBUG_PLAN.md`;
  `GEOLOCATOR_ROLLOUT_PROTOCOL.md` and related logs;
- this memo and `notes/codex_logs/THREAD3_PROMPT_LOG.md`;
- official YAML and local mirror;
- `DATABASE/main_tables.SQL`, `support_tables.SQL`, `functions.SQL`, and relevant
  `views.SQL` sections;
- all current table `global.R` wrappers and central `DataEntry/inspectors/` files;
- all 12 local inspector exports listed by `FILE_INDEX.txt`:
  `OBSERVERS`, `EGGS`, `NESTS`, `CAPTURES`, `RESIGHTINGS`, and
  `RESIGHTINGS_PUBLIC`, each with `_hard.R` and `_warning.R`;
- connected workbook, CSV exports, mock repair/generation/runner/report files;
- negative-brood fixtures and focused validator tests;
- recent Git history and the historical unlinked-H helper commit.

## Reconciliation result

The official YAML and mirror are aligned byte-for-byte for verified protocol
v1.3.4 behavior, including the v1.3.2 and v1.3.3 milestones and H-ring rules.
The local exports include protected changes that are not yet represented in the
protocol, notably `AC` in RESIGHTINGS and later photo/NESTS WIP. The unresolved
derived H-association/view discrepancy is still explicitly retained for the
responsible schema/TODO workstream. Local artifacts do not establish live
deployment.

## Documentation-recovery appendix — 2026-10-23

This appendix records a recovery attempt after the validation specialist became
unavailable for follow-up delivery. It is documentation status only. It does not
change the protocol, validator lists, inspector rows, mock workbook, SQL, tests,
or live database state.

### Current authority and state labels

The current authoritative local protocol is the external working file
`bdot_dataentry_validator_protocol.yaml`, version **1.3.4**, generated
2026-10-10. The synchronized local mirror under
`validator_sandbox/xlsx_short_tag_update/` reports the same identity and
version. The older v1.3.3 and v1.3.2 statements earlier in this handoff are
historical milestones and must not be read as the current protocol header.

The intended live inspector organization remains exactly two categories per
biological table: `TABLE_hard` and `TABLE_warning`. The tracked
`validator_sandbox/inspector_lists_by_table/` exports are review artifacts, not
proof that the corresponding rows exist in the live `inspectors` table.

At this recovery pass, the protected checkout contains dirty changes in four
inspector exports (`CAPTURES_hard.R`, `NESTS_hard.R`, `NESTS_warning.R`, and
`RESIGHTINGS_hard.R`) alongside dirty SQL, PDF, and focused tests. Those files
were inspected as protected WIP and were not revalidated, staged, committed,
or described as approved, pasted, merged, or live.

### Delivery limitation

The requested current follow-up to the successor validation thread could not be
delivered because the destination consumed repeated deliveries as empty tool
result turns. No validator decision was inferred from that failure. The current
documentation therefore preserves the last inspectable protocol and source
state while explicitly requiring a replacement Thread 3.1/3.2 audit before any
live inspector update or deployment claim.

### What remains authoritative

- The machine-readable protocol controls rule classes, hard versus warning
  intent, post-save QA, and mock-generation-only behavior.
- The current DataEntry contract requires `rowid`, `variable`, and `reason` and
  treats `TABLE_hard` output as save-blocking and `TABLE_warning` output as
  non-blocking review feedback.
- H-class hiding-photo rules remain restricted to normalized `rclass = "H"` and
  use `RESIGHTINGS.ring` as the photographed chick identity. Ordinary
  RESIGHTINGS classes may leave `ring` blank.
- The stricter derived H-event family association described by Threads 2, 4,
  and 8 is a TODO/schema contract, not an automatically implied save-time
  validator rule.
- Local protocol/mock evidence and tracked exports cannot establish live
  inspector rows, a deployed package version, or a running portal process.

### Safe replacement-thread bootstrap

1. Read `AGENTS.md`, this handoff, `THREAD1_REPOSITORY_MAP.md`, the current
   Thread 2/4 handoffs, and the ignored Thread 3 prompt log.
2. Record `git status --short --branch`, `HEAD`, and the local `origin/main`
   ref; preserve all dirty source, tests, and inspector exports.
3. Read both protocol YAML paths and verify their identity/version/checksum
   without changing either file.
4. Inspect the tracked hard/warning exports and connected mock fixtures, clearly
   separating current source, protected WIP, and historical artifacts.
5. Run only approved parser/mock checks against invented data; do not connect to
   live databases or write to `inspectors`.
6. Reconcile any proposed validator change with the protocol rule class and
   package contract before preparing a separate user-reviewed PR or deployment
   instruction.
7. Report what was revalidated, what remains uncertain, and whether any live
   state was actually inspected. Do not convert delivery failure into a rule
   decision.

### Recovery conclusion

The validation architecture is documented sufficiently to restart, but the
current dirty inspector-list edits remain pending protected WIP. No current
claim should say that they are approved or live. This appendix does not alter
the existing protocol version or validator semantics.

## Full documentation reconciliation — 2026-10-23

This section supersedes stale current-state wording above where it conflicts
with the verified 2026-10-23 checkout state. It was prepared from the manually
pasted recovery prompt and a read-only inspection of the repository. It does
not change runtime behavior, validator logic, protocol YAML, SQL, tests, mock
workbooks, inspector exports, or database state.

### Authority, status, and state labels

Use the following authority order when rebuilding or reviewing this workstream:

1. Current tracked schema and application wiring, especially
   `DATABASE/main_tables.SQL`, `DATABASE/support_tables.SQL`,
   `DATABASE/functions.SQL`, `DATABASE/views.SQL`, and the table-specific
   `DataEntry/*/global.R` wrappers.
2. The official working protocol YAML at
   `/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/bdot_db/data/working/bdot_dataentry_validator_protocol.yaml`.
3. The byte-identical local protocol mirror at
   `notes/codex_proposals/validator_sandbox/xlsx_short_tag_update/bdot_dataentry_validator_protocol_plot_aligned.yaml`.
4. Tracked hard/warning inspector exports under
   `notes/codex_proposals/validator_sandbox/inspector_lists_by_table/`.
5. Connected mock fixtures, parser checks, repair scripts, focused tests, and
   reports.
6. Prompt logs and older handoffs for intent and history only.

The protocol is the approved behavior specification. A tracked export is a
paste-ready review artifact, not evidence that the corresponding DB row exists.
“Protected WIP” means a pre-existing dirty working-tree change that this task
must preserve and must not silently treat as approved. “Mock-tested” means a
local invented-data check only. “Live/deployed” requires a separately authorized
inspection of the target database or portal; no such inspection occurred here.

Verified protocol identity:

```text
protocol_id: bdot_2026_2027_dataentry_validator_protocol
protocol_version: 1.3.4
generated_on: 2026-10-10
SHA-256: 1de6c733851c992e296d048bbf35ba5feffda11d1ad7e43c147fe5007359ea7f
```

The two protocol files are byte-identical. Neither was edited during this
reconciliation. The current local checkout is the protected branch
`codex/split-todo-calculator-2026-10-19` at `d3c7bd4`; its local
`origin/main` reference is `9beb203ac2757219def35e47bfe54bd6ac8684a2`.

### Validator architecture and contract

The external `DataEntry` package supplies the table editor and validator
execution. The central `DataEntry/inspectors/` app edits DB-managed inspector
code. Biological tables use exactly two intended live inspector categories:

- `TABLE_hard` maps protocol `hard_rules` to save-blocking errors.
- `TABLE_warning` maps protocol `warning_rules` to non-blocking warnings.

There is no permanent live residual or format category. A legacy parser, syntax,
format, or migration rule must be assigned to hard or warning according to its
actual save-time consequence. `post_save_qa` and `mock_generation_only` rules
remain outside save-time inspectors unless a later, explicit protocol decision
changes that boundary.

Each validator evaluates the submitted table as `x`, preserves the submitted
row number as `rowid`, and returns at least:

```text
rowid, variable, reason
```

An empty result must retain those columns. Each expression is wrapped in
`try_validator(nam = "...")`. The current portal does not automatically expose
extra severity/type columns, so severity is represented by the hard/warning
inspector row rather than by an extra result field. A `variable = NA` result is
an implementation failure signal, not a valid biological conclusion.

### Verified protocol inventory

The current protocol contains the following live save-time families. This is an
inventory, not a request to alter any export.

- Shared hard: `GLOBAL_002`, `GLOBAL_003`, `GLOBAL_004`, `GLOBAL_005A`,
  `GLOBAL_005`.
- Shared warning: `GLOBAL_W001`, `GLOBAL_W003`, `GLOBAL_W004`.
- OBSERVERS hard: `OBS_001`, `OBS_002`, `OBS_003`; no warning rules.
- EGGS hard: `EGG_001`, `EGG_002`, `EGG_003`, `EGG_004`, `EGG_006`, `EGG_009`.
  EGGS warnings include `EGG_005`, `EGG_007`, `EGG_W001`, `EGG_W003`, and
  `EGG_W004`.
- NESTS hard: `NEST_001`, `NEST_001A`, `NEST_002`, `NEST_003`, `NEST_004`,
  `NEST_005`, `NEST_007`, `NEST_009`, `NEST_013`, and `NEST_014`. NESTS
  warnings include `NEST_006`, `NEST_008`, `NEST_010`, `NEST_010B`,
  `NEST_010C`, `NEST_011`, `NEST_W001`, and `NEST_W002`.
- CAPTURES hard: `CAP_001`, `CAP_001A`, `CAP_002`, `CAP_003`, `CAP_004`,
  `CAP_005`, `CAP_006`, `CAP_006B`, `CAP_009`, `CAP_010`, `CAP_013`,
  `CAP_014`, `CAP_015`, `CAP_015B`, `CAP_016`, `CAP_016B`, `CAP_017`,
  `CAP_017B`, `CAP_018`, `CAP_019`, `CAP_020`, `CAP_021`, `CAP_021B`,
  `CAP_022`, `CAP_023`, `CAP_024`, `CAP_026`, `CAP_027`, `CAP_028`,
  `CAP_030`, and `CAP_031`. CAPTURES warnings include `CAP_007`, `CAP_008`,
  `CAP_011`, `CAP_012`, `CAP_012B`, `CAP_025`, `CAP_029`, `CAP_W001`,
  `CAP_W002`, `CAP_W004`, `CAP_W008`, `CAP_W011`, `CAP_W012`, and `CAP_W013`.
- RESIGHTINGS hard: `RES_001`, `RES_002`, `RES_003`, `RES_004`, `RES_004B`,
  `RES_004C`, `RES_004D`, `RES_005B`, `RES_005C`, `RES_005D`, `RES_005E`,
  `RES_005F`, `RES_005J`, `RES_005K`, `RES_009`, `RES_009B`, `RES_010`,
  `RES_010A`, `RES_010B`, and `RES_011`. RESIGHTINGS warnings include
  `RES_005`, `RES_005G`, `RES_005H`, `RES_008`, `RES_W001`, and `RES_W002`.
- RESIGHTINGS_PUBLIC hard: `PUB_001`, `PUB_002`, `PUB_003`, `PUB_007`, and
  `PUB_008`; warnings are `PUB_004`, `PUB_005`, and `PUB_006`.

The protocol also lists mock-generation-only and post-save material. Those
entries are intentionally not part of the live hard/warning inventory above.

### Negative broods and hiding-spot photos

A negative `nest_id` identifies a brood of unknown origin. It is valid in
`CAPTURES` and `RESIGHTINGS`, invalid in `NESTS` and `EGGS`, and its leading
minus sign is meaningful. `NO_NEST` is a separate sentinel and is not a
negative brood. Relevant negative-brood events require a complete direct
`gps_id`/`gps_point` pair. Age-C first captures require a real positive nest or
negative brood rather than blank or `NO_NEST` linkage. A positive-nest chick
captured at the nest may leave both GPS fields blank; if a direct location is
entered, the pair must be complete. A positive-nest chick captured away from
the nest may therefore carry a complete pair.

`RESIGHTINGS.ring` is nullable in general but mandatory for normalized age-C
`rclass = "H"` hiding-spot rows. It identifies the photographed chick and does
not replace `UL`, `LL`, `UR`, or `LR`. Each photographed chick gets its own H
row, complete GPS pair, and photo metadata. H-ring formatting and current-
season CAPTURES-existence checks are save-blocking under the verified protocol;
equivalent permitted ring formatting is normalized consistently. Ordinary
RESIGHTINGS classes may leave `ring` blank. `RESIGHTINGS_PUBLIC` is unaffected.

CAPTURES tent-photo fields remain distinct from RESIGHTINGS hiding-photo fields.
The verified protocol still retains the compatibility-era `chick_hide_photo`
and `CAP_029` wording; later working-tree requests to treat that field like a
tent-photo flag and remove the in-situ warning are protected implementation WIP
and are not represented as current protocol behavior here.

Derived H-event brood association, per-chick task closure, and ambiguity holds
belong to the schema/TODO workstreams unless the protocol explicitly defines a
save-time rule. They must not be inferred into the validator from Thread 2 or
Thread 4 descriptions.

### RESIGHTINGS parent/chick and active-nest behavior rules

Under verified protocol 1.3.4, `RES_005J` is save-blocking and covers ordinary
age-C rows as well as H rows. Every age-C `rclass = H`, `R`, `P`, or `V` row in
the current portal submission must have an age-A parent row in that same
submission whose behavior contains `BC` or `FC`. Every qualifying parent row
must have at least one linked age-C row. Matching requires the same date and
either the same nonblank `nest_id` or the same complete `gps_id/gps_point` pair.
Rows already saved in the database do not satisfy this same-session rule.

`IN` and `NM` are active-nest identity/linkage behaviors. The current positive
nest must have latest state `F`, `I`, or `H` for the relevant active-nest check;
`H` remains valid during asynchronous hatching. `BC` and `FC` are brood-
association behaviors and require latest positive-nest state `H` or `notA`.
When a `notA` nest still has brood, the applicable age-C and adult brood-
association rows require the complete GPS pair. `BW` means broken-wing display,
not brood watch: it can occur at either nest or brood stage and does not by
itself trigger the reciprocal parent/chick requirement.

The current local RESIGHTINGS artifacts add `AC` ("Alert with chick(s)") to the
parent/chick and brood-stage behavior set. The hard-export change is protected
WIP and represents a divergence
from the verified protocol, which currently names only `BC` and `FC` in
`RES_005J` and `RES_005K`. The SQL comment also mentions `AC`, but the repository
does not provide evidence that a corresponding portal helper is deployed. A
future authorized implementation task must reconcile the protocol, exports,
schema comment, and UI/helper source together.

### Protected WIP and cross-thread boundaries

The checkout was already dirty before this documentation pass. Relevant
protected validator WIP includes `CAPTURES_hard.R`, `NESTS_hard.R`,
`NESTS_warning.R`, and `RESIGHTINGS_hard.R`; other tracked dirty files include
SQL, PDF code, tests, and handoffs. AC-related RESIGHTINGS logic, NESTS
terminal-state/clutch changes, and an adult `HA` capture rule remain protected
WIP in that checkout. The photo-overlap handling for same-session H rows is no
longer part of that protected WIP: it was merged in PR #150, and this branch adds
the corresponding protocol/documentation reconciliation. Live inspector state
remains unknown.

### 2026-10-26 photo-range validation reconciliation

The photo-overlap implementation from merged PR #150 is represented by the
tracked `CAPTURES_hard.R`, `NESTS_hard.R`, and `RESIGHTINGS_hard.R` exports. Each
photo-bearing biological table now checks its own submitted rows and the other
two photo-bearing tables, excludes the same saved row by table plus `pk` during
edits, strips a final filename extension for comparison, and preserves a
terminal roll-frame prefix as part of image identity. Thus `101-4122` and
`102-4122` are distinct.

The only intentional shared-range exception is multiple age-C H-class
RESIGHTINGS rows from the same camera and date that share either the same
nonblank `nest_id` or the same complete `gps_id/gps_point` pair. Adult P/V rows,
cross-table CAPTURES/NESTS/RESIGHTINGS rows, and H rows with different linkage
remain save-blocking conflicts. The focused invented-data test covers all three
exports, self-edit exclusion, same-session H sharing, genuine conflicts, and
roll-frame separation; it passes 25 tests. This local test and the tracked
exports do not establish live inspector deployment.

Thread boundaries are deliberate:

- Thread 1 owns the repository map and source inventory.
- Thread 2 owns schema/view and derived H-photo/task-association questions.
- Thread 3.1 owns protocol interpretation, validator contract, and inspector
  artifact reconciliation.
- Thread 4 owns TODO/map/list behavior; its stronger derived family evidence
  must not be silently promoted into save-time validation.
- Thread 8 may use the field-facing summary below for the human manual, but
  should not imply deployment or expose implementation internals.
- Thread 9 owns local-replica/setup concerns and is not evidence of live state.

The earlier cross-thread delivery failure was a coordination issue: the
destination rendered repeated deliveries as empty tool-result turns. It was not
a validator finding, approval, rejection, or deployment event.

### Known uncertainties and deferred work

The live `inspectors` table, deployed portal process, and production database
were not inspected. The current `HEAD` SQL does not establish a deployed
`RESIGHTINGS_H_BROOD_ASSOCIATIONS` helper; the dirty SQL references related
logic without proving a complete deployable definition. The protocol/export
divergence for `AC` and the compatibility-era `chick_hide_photo`/`CAP_029`
behavior remains unresolved. The exact package-side helper tooltip source is
external to this repository. These are explicit follow-up items, not assumptions
to be filled in by a replacement thread.

### Restart and verification instructions for Thread 3.2

Use this sequence when recreating the validation workstream:

1. Read `AGENTS.md`, this handoff, the Thread 1/2/4 handoffs, and the prompt
   log. Record the branch, `HEAD`, local `origin/main`, and all dirty files.
2. Treat every pre-existing dirty implementation, SQL, test, workbook, and
   inspector file as protected. Do not reset, clean, rebase, merge, stage, or
   connect to a live database.
3. Read both protocol YAML files and verify identity, version, generated date,
   and checksum without editing them.
4. Compare the protocol rule inventory with all 12 tracked hard/warning
   exports, labeling each difference as approved protocol, local artifact,
   protected WIP, mock-tested behavior, or live unknown.
5. Use invented or connected mock data only for parser and validator checks.
   Do not treat a mock pass as proof of live deployment.
6. If a behavior is to change, update the protocol and implementation artifacts
   in a separate explicitly authorized task, then obtain human review before
   any inspector-table paste or deployment instruction.

Paste-ready bootstrap prompt:

> Read `AGENTS.md` and `THREAD3_VALIDATION_ARCHITECTURE.md` in full. Perform a
> read-only validation-workstream audit from the current checkout. Preserve all
> dirty files and do not access live databases, credentials, or DB-managed
> inspectors. Verify both protocol YAML files and their checksum, compare the
> 1.3.4 protocol with all tracked hard/warning exports, and separate approved
> behavior from protected WIP and historical material. Use invented/mock data
> only. Report discrepancies, do not edit implementation, and stop before any
> staging, commit, push, paste, deployment, or PR action.

### Field-manual-facing summary

Fieldworkers should see two practical categories: save-blocking errors that
must be corrected before submission, and warnings that ask for review without
claiming the observation is impossible. Age-C first captures need a real nest
or negative brood link; negative broods need a complete GPS pair. Hiding-spot
photos are one H row per photographed chick with its ring, complete GPS pair,
and photo metadata. Ordinary resightings may leave `ring` blank.

For RESIGHTINGS, a current-session age-C row must be accompanied by a linked
age-A parent row with `BC` or `FC`, and the parent row must have a linked chick
row; the rows share date and either `nest_id` or a complete GPS pair. `IN`/`NM`
are active-nest behaviors, `BC`/`FC` are brood-association behaviors, and `BW`
means broken-wing display and can occur at either stage. The current protocol
does not yet certify `AC`; field guidance must not present that WIP extension as
live until the protocol, helper text, and inspectors are reconciled together.
