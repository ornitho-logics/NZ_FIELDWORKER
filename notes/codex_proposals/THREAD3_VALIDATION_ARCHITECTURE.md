# Thread 3.1 validation architecture and current-state handoff

## Audit status

This document records the current local validation contract after a
source-to-document reconciliation on 2026-09-30 and a Git/status refresh on
2026-10-06. It is a tracked documentation handoff, not a new biological-rule
proposal.

- Repository: `2026_NZ_FIELDWORKER`
- PR branch: `codex/parent-association-thread-docs-2026-10-06`
- Base revision: `1617e84`, matching `origin/main` when the branch was created
- The reviewed per-table `*_hard.R` and `*_warning.R` inspector lists are
  already tracked under `validator_sandbox/inspector_lists_by_table/`.
- This PR does not change validator code or the protocol; it tracks this handoff
  alongside the current Thread 4 SQL/PDF work.
- No live database was connected to.
- No live `inspectors` row was queried or changed.
- `AGENTS.md` is intentionally updated in this PR under the user's explicit
  request and now points to this tracked handoff and the inspector lists.

The current authoritative protocol is version **1.3.3**, generated 2026-09-30.
The official YAML and local mirror are byte-identical with SHA-256:

`9965d1f313ea172ac76f62b0b02e9c42895d659ee2fba9b62c526286c29b2732`

Version 1.3.3 requires a real nest or brood link for age-C first captures and permits
an optional complete GPS pair for positive-nest chicks captured away from the nest.
Version 1.3.2 adds save-blocking H-ring format and current-CAPTURES existence checks.
The H-ring rule remains restricted to normalized `rclass = H`; ordinary RESIGHTINGS
classes may still leave `ring` blank.

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

The parsed v1.3.3 protocol contains these rule families. The exact rule IDs and
descriptions remain in the YAML; this section explains their implementation role.

### Shared rules

Hard shared rules cover field-season date range, allowed site values, blank system
fields (`nov` and related upload flags), GPS pair completeness/existence, and global
photo-number uniqueness. Shared warning rules cover GPS timestamp plausibility and
other review-only timing/context checks. Photo and GPS rules are cross-table where the
submitted event depends on `GPS_POINTS` or an image range used elsewhere.

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
  already used by another event;
- `behav` may be blank for H, but entered chick behavior must use permitted codes;
- a positive-nest H row must not precede that nest’s first NESTS `F`, `I`, or `H`
  event; same-day entry is allowed.

An H row is normally linked with a positive or negative `nest_id`. The current
save-time exception in `RES_005B` permits a blank `nest_id` only for an H row with
the mandatory GPS pair and either a nonblank ring or a same-submission age-A row at
the same GPS pair with both lower-leg fields. RES_010A and RES_010B independently
require that a ring used for the ring branch has the CP format and exists in current
CAPTURES. This remains intentionally narrower than a full family-association proof.

Warning rules cover capture-history mark comparison, capture-history sex comparison
(`RES_005H`), social-parent mark mismatch, same-occasion adult context, mixed-brood
review, device defaults, tibia review, and GPS timing. `RES_006` remains a warning,
not a blocker: the adult parent may be entered in another portal session.

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

## Cross-table, chronology, and history boundaries

Save-time checks can use current table rows, `GPS_POINTS`, current-season tables,
`CAPTURES_ARCHIVE`, and selected nest-history surfaces. They should not assume that
companion rows are in the same portal submission. This is why same-occasion adult
context, delayed chick evidence, exact NESTS/RESIGHTINGS event identity, and some
family associations remain warning or post-save concerns.

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
RESIGHTINGS mark-history/social-parent warnings, and same-occasion adult warnings
provide evidence. Thread 4’s TODO/view logic can require stronger, reference-date and
family-link evidence than a row-level save validator. Do not add a hard MM rule merely
to make a task disappear; record truthful marks and behavior and resolve ambiguity in
post-save/task logic.

## Unlinked-H association discrepancy requiring follow-up

The current validator contract and the current local `RESIGHTINGS_hard.R` export agree
with protocol `RES_005B`: an unlinked H can pass the narrow save-time exception when
its mandatory H/GPS/ring evidence is present, or when the current submission includes
the specified age-A lower-leg evidence. The protocol does **not** require a prior
CAPTURES family-link query in this save-time rule, and the separate parent-context
warning remains non-blocking because rows may arrive in separate sessions.

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

Local protocol and inspector work is complete for the current v1.3.3 semantics. Live
deployment is **not established**. No live `inspectors` rows were inspected or changed.

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

The official YAML, mirror, local hard/warning exports, focused fixture test, and
documentation are aligned for approved protocol v1.3.3 behavior, including the
v1.3.2 H-ring rules. The
unresolved derived H-association/view discrepancy is still explicitly retained for
the responsible schema/TODO workstream.
