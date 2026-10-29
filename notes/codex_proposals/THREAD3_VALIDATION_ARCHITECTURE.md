# Thread 3.1 validation architecture and current-state handoff

Publication reconciliation: this handoff is being published from
`origin/main` at `f7d13fb`. The `9beb203` and `d3c7bd4` values below preserve
the Thread 3.1 recovery audit's inspection provenance; they are not the
documentation branch's current source baseline. This reconciliation does not
update `AGENTS.md`; Thread 8 owns any later
correction to its protocol identity or handoff wording. It also does not
approve or deploy the protected validator WIP.

## Audit status

This document records the current local validation contract after the
2026-10-26 PR-readiness reconciliation. It is a tracked documentation handoff
for the local inspector/protocol work, not evidence that live inspectors have
been deployed.

- Repository: `2026_NZ_FIELDWORKER`
- Protected checkout: `codex/recent-thread-diffs-2026-10-26` at `72889c6`
- Local `origin/main` reference at inspection: `cd8ef26`
- The reviewed per-table `*_hard.R` and `*_warning.R` inspector lists are
  already tracked under `validator_sandbox/inspector_lists_by_table/`.
- The checkout contains protected dirty WIP in inspector exports, SQL, tests,
  handoffs, and other workstreams. This reconciliation records the validator
  implementation artifacts and focused mock checks described below; it does
  not approve, paste, deploy, stage, commit, or otherwise modify live state.
- No live database was connected to.
- No live `inspectors` row was queried or changed.
- The earlier recovery pass did not change `AGENTS.md`; its standing
  human-control and live-database restrictions remain authoritative. A later
  narrow protocol-mirror reconciliation updates only the local protocol
  identity and the age-C CAPTURES status-R/status-C documentation.

The external canonical working protocol remains version **1.3.5**, generated
2026-10-24. The tracked local mirror on this branch is updated to proposed
version **1.3.19**, generated 2026-10-28. Version 1.3.19 records the
RESIGHTINGS uncertainty-evidence, same-occasion family-conflict, same-site,
`NO_NEST`, and mandatory explicit H-row `nest_id` corrections, plus the EGGS
schema/timing/floatation and NESTS follow-up-state clarifications. It retains the measurement-based age-C
`capture_status = R` and `capture_status = C` boundaries, the age-C changed-band
recapture exception, and the photo-range and same-session H-photo rules.
Because the external working file is outside this repository and is not changed
by this branch, v1.3.19 is a reviewed local
protocol/documentation artifact, not evidence that the external copy, live
inspectors, or deployed portal have been synchronized.

Version 1.3.5 makes parent/chick co-entry save-blocking within one RESIGHTINGS
portal submission: every age-C row, including ordinary `rclass = R`, `P`, or `V`
rows, must be linked to an age-A parent whose behavior includes `BC`, `FC`, or
`AC`, and each such parent row must have at least one linked age-C row. Version 1.3.4
also separates active-nest `IN`/`NM` state checks from brood-association checks
and documents `BW` as broken-wing display. Version 1.3.5 makes `AC` (Alert with
chick(s)) equivalent to `BC` and `FC` in the parent/chick, nest-state, GPS, and
mock-generation rules. Live deployment is still not established. Version
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
- `EGGS`: one row per egg, with float measurements and comments. The current
  schema has no camera, photo, or harddrive columns; negative IDs and `NO_NEST`
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
angle/surface/location coherence, egg identifiers, and clutch limits. The current
EGGS schema has no camera, photo, or harddrive columns, so those are not EGGS
validator targets. Warning checks cover likely matching NESTS visits, missing or
unusual float data, float-development spread, and event context.

`EGG_003` groups submitted rows by `nest_id`, observer, and date. A repeated
`nest_id`/observer/time key across dates is flagged as a date inconsistency, while
valid times within one nest/observer/date group must span no more than five
minutes. Repeated visits on different dates remain valid when they do not create
one cross-date event key. `EGG_006` enforces the location/surface relationship:
bottom and suspended eggs leave `float_surface` blank, while surface eggs use
0–3; the separate hard angle check accepts whole-number `float_angle` values from
0 through 90 for every location.

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
- `pP`, `P`, and `D` are review/follow-up states while the team confirms predation
  or desertion. Multiple pP/P/D visits may be entered before the final `notA`;
  they are not treated as an immediate irreversible terminal state. The state
  progression still flags unusual transitions for review and allows only one
  final `notA` closure.
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
method; positive/negative/blank location branches; ring/mark and `_in`/release
coherence; age and field-sex codes; hatch evidence; prior nest history; tags,
morphometrics, samples, moult/fat; photo metadata and range order; global photo
uniqueness; uploader initials; comma-mark rejection; and status-specific field rules.

Location semantics are:

- positive nest-linked capture: established nest-location branch;
- negative brood ID: negative ID plus both direct GPS fields, with a valid
  `GPS_POINTS` pair;
- blank: direct GPS branch, with both GPS fields as required by the current
  contract. `NO_NEST` is a retired sentinel and is rejected for new entries;
  historical values are not rewritten by this validator change.

There is one narrower first-capture exception: an age-C row with
`capture_status = F` must carry a real positive nest ID or negative brood ID;
blank `nest_id` and `NO_NEST` are rejected. For a positive nest ID, both GPS fields
may remain blank when the chick was captured at the nest, or may be supplied
together when it was captured away from the nest. Age-C `capture_status = R` and
`C` rows require both GPS fields even when a positive `nest_id` is present; a
positive-nest adult capture whose `caught_with` entry records chicks also requires
the complete GPS pair. Partial GPS pairs remain invalid. Negative brood rows
continue to require both GPS fields.

Negative IDs do not undergo a NESTS lookup and do not use the positive-nest/direct-GPS
exclusivity rule.

`CAP_009B` also checks same-occasion family consistency when CAPTURES is the
current table. A family capture is an age-C row or an age-A row whose
`caught_with` value records chicks. For the same date, site, complete
`gps_id/gps_point` pair, current family captures and relevant saved
CAPTURES/RESIGHTINGS companions must resolve to one positive or negative
`nest_id`. Conflicting IDs are save-blocking even when all current rows carry
explicit IDs; separate dates, sites, or GPS pairs remain separate encounters.
The current row's saved `pk` is excluded when editing. If the companion lookup
is unavailable, the check fails closed with a retry message rather than silently
passing.

Warnings cover prior ring/combo history, unusual status/method combinations, parent
spacing, same-sex adult multiplicity, photo-flag review, nest/hatch evidence,
morphometric/tibia review, and GPS timing. `CAP_W013` warns when a chick capture
comment suggests “in situ” hiding photos; hiding photos belong in a separate H-class
RESIGHTINGS event. A chick tent photo remains a CAPTURES event (`chick_tent_photo`),
not an H photo.

`CAP_013` blocks status `R` when input marks differ from release marks. If prior ring
history supports a changed-combination recapture, the message directs the worker to
use status `C`; unavailable history is not treated as proof of no match.

The v1.3.7 CAPTURES update explicitly supports older-chick recaptures with
`capture_status = C` (a changed band combination). These rows still require the
core age-C measurements `tarsus`, `culmen`, and `weight`, and retain the normal
location, ring/mark, and status-change checks. They are exempted from the initial
F/R chick-release layout and may include older-chick/adult-style measurements,
sample fields, and photo flags when those observations were actually collected;
entered optional fields are still checked for valid values and metadata. The
status-C warning range is broadened to cover plausible older-chick growth so that
routine recaptures do not generate a flood of low-value warnings. Age-C `F` and
`R` requirements are otherwise unchanged, and this local protocol mirror does
not establish live deployment.

Version 1.3.8 and 1.3.9 separated the age-C status-R morphometric warning
envelope from the older-chick status-C envelope and clarified its message. Version
1.3.11 now uses the supplied seven flagged-chick measurements and the explicit
operational cutoff. Status-R review limits are tarsus 18.43–26.99, culmen
6.47–13.79, and weight 6.73–21.99. Status-C lower review limits are tarsus
27.70, culmen 13.80, total_head 38.80, and weight 22.80; the existing broad
upper limits remain unchanged, and age-C status-R `total_head` and `wing` remain
hard-disallowed. The 27/22 boundary means a chick below tarsus 27 or weight 22
should not be treated as flag-ready. The limits are warnings only and are fixed
review thresholds, not dynamically recomputed percentiles; the sample's
total_head minimum is based on only three observations and should be revisited
if more data accumulate.

The preceding version 1.3.11 retained the status-R warning explicit to fieldworkers: values above
the status-R envelope may indicate that the chick is large enough for a changed-
band recapture with `capture_status = C` and an engraved flag in `UL`. The
warning asks the worker to recheck status and measurements and remains
non-blocking. No additional leg-segment rule was needed: status-R rows still
require complete unchanged input/release combinations and the initial chick
release layout, while status-C rows still require complete input/release marks,
a genuine change, and prior input-combination history. The existing status-C
exceptions for optional older-chick morphometrics, samples, and photo flags
remain unchanged.

Version 1.3.18 tightens the distinction between independent adult parent-nest
confirmation and the approved blank-ID family route. Adult RESIGHTINGS rows with
behaviour `IN`, `NM`, `SC`, `BW`, `BC`, `FC`, or `AC` must use an explicit valid
`nest_id` or negative brood ID and must record both observed lower-leg fields
`LL` and `LR`; explicit `X`/`XX` values in both fields are valid evidence for an
unbanded `X-X` observation. The narrowly approved blank-ID negative-family route
remains available only to `BC`/`FC`/`AC` when authoritative current association
resolves the family. It is a family-link exception, not independent parent-nest
confirmation, and does not apply to `SC`, `IN`, `NM`, or `BW`.

The same version clarifies `RES_005H`: verified prior ring or complete engraved-flag
identity may establish the historical sex group despite the newly entered observer
sex, while an archive-only lower-band match is not definitive and cannot by itself
override the raw RESIGHTINGS sex. The validator remains warning-level and never
rewrites the entered observation.

Version 1.3.12 expanded accepted uncertainty notation in RESIGHTINGS UL, LL, UR,
and LR. A literal `?` may stand alone or occur before or after one known colour,
such as `?R` or `R?`; UR also permits `T?`, while bare `T` remains invalid. These
entries preserve the observed order and known colour but are not wildcard evidence
or complete mark components. A row containing only uncertainty cannot become a
definitive identity for history, parent/S10, sex-history, or available-combination
checks. Independent complete evidence, including ring, full flag, or a complete
canonical mark component where the existing matching method supports it, remains
available. CAPTURES keeps
its existing mark-layout rules but now rejects `?` in all handled and recovered
mark fields for every capture status.

Version 1.3.13 adds the corresponding parent-link boundary. Any `?` in a
RESIGHTINGS leg-mark field excludes that row from parent-nest evidence unless a
metal ring is reliably traceable to capture history on or before the event date.
For that ring-identity lookup, permitted CP spellings are canonicalized by
trimming, uppercasing, and removing the optional hyphen, so `CP12345` and
`CP-12345` identify the same ring; malformed or placeholder strings do not
qualify. This normalization is limited to ring identity and does not alter mark
order or `nest_id` values.
The ring exception establishes individual identity, not a current nest link: a
current explicit valid `nest_id` may therefore be accepted even when the earlier
capture has a blank `nest_id`, and an archive capture may establish identity but
must not import its historical `nest_id` into the current family. Blank current
`nest_id` inference uses only current-season CAPTURES history and only when one
current nest/brood ID is uniquely resolvable. Future-only, unverified, or
conflicting-sex ring history does not override uncertain colours. Raw `?`
entries remain unchanged.

Version 1.3.14 adds `SC` (scraping) to the independent adult parent-nest
identity-link candidates. An adult `SC` row therefore confirms a parent-nest
association on its own and follows the ordinary nest-link requirement, but it
is not a parent-with-chicks behavior and does not trigger the reciprocal age-C
co-entry rule. Only `BC`, `FC`, and `AC` retain that parent-with-chicks role.

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
- every age-C H row must carry an explicit valid positive or negative `nest_id`;
  a same-session parent, H ring, prior capture history, or other inferred
  association cannot substitute for the entered H-row `nest_id`;
- the approved H band layout remains enforced;
- GPS pair, camera, photo start, and photo end are required and valid;
- photo end cannot precede photo start, and the image range must not overlap an image
  already used by another event, except for the approved same-session age-C H-photo
  reuse rule described above;
- `behav` may be blank for H, but entered chick behavior must use permitted codes;
- a positive-nest H row must not precede that nest’s first NESTS `F`, `I`, or `H`
  event; same-day entry is allowed.

Every age-C H row must carry an explicit valid positive or negative `nest_id`.
The former `RES_005B` blank-ID exception for H rows has been removed: a same-session
parent, H ring, prior capture history, or other inferred association cannot
substitute for the entered H-row `nest_id`. `RES_010A` and `RES_010B` independently
require that the ring has the CP format and exists in current CAPTURES. Ordinary
age-C `R`, `P`, `V`, and `C` rows retain their approved same-session blank-ID/family
routes; this change does not broaden those routes to H rows.

The current mark-format boundary accepts `?` alone, `?R`, `R?`, and the analogous
one-known-colour partial forms in all four RESIGHTINGS segments UL, LL, UR, and LR.
On UR, complete tag/spacer values such as `TY` remain valid and `T?` is valid when
the tag/spacer is known but its colour is uncertain; bare `UR = T` remains invalid.
Full flag syntax and existing complete mark syntax are unchanged, and no partial
engraved-code grammar is added. An uncertain segment is never treated as a
wildcard or complete mark component; a row containing only uncertainty cannot
become a definitive identity for parent/S10, sex-history, or available-combination
generation. Independent complete evidence such as a ring, full flag, or complete
canonical mark component remains available where the existing matching method
supports it. CAPTURES rejects the same notation in UL, LL, UR and LR, including
UL_in, LL_in, UR_in and LR_in; `RESIGHTINGS_PUBLIC` is unaffected.

Warning rules cover capture-history mark comparison, capture-history sex comparison
(`RES_005H`), social-parent mark mismatch, mixed-brood review, device defaults,
tibia review, and GPS timing. The former one-directional
`RES_006`/`RES_007` same-occasion warnings have been removed from the live warning
export because the reciprocal requirement is now save-blocking in `RES_005J`.

`RES_005H` compares the RESIGHTINGS `sex` field to the identified bird’s capture
history. For `CAPTURES_ARCHIVE`, only a verified ring or complete engraved-flag
match is definitive identity evidence; an archive-only lower-band or weak partial
mark match is not allowed to establish the sex group or silently override the raw
observation. For a definitive archive ring/flag match, prefer nonblank `gen_sex`,
then archive `field_sex`; otherwise retain the existing current-season matching
rules. `M`/`MU` and `F`/`FU` are equivalent. Unknown, ambiguous, or unavailable
history is not a definite contradiction. A definite mismatch is a warning on
`variable = "sex"`, not a save blocker, and no raw sex value is rewritten.

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
- Subsequent negative-ID events ordinarily retain the same operational ID and carry
  their own event GPS pair. The narrow S10 blank-`nest_id` exception applies only to
  a same-date, same-site, same-complete-GPS parent/chick family when authoritative
  `ADULT_PARENT_STATUS` supplies one unambiguous selected M and F identity for that
  negative nest and each observed parent matches its selected identity. Missing,
  pending, ambiguous, conflicting, or unmatched status requires the explicit
  negative `nest_id`.
- `NO_NEST` is a retired current-input sentinel and is rejected by CAPTURES and
  RESIGHTINGS. New unrelated events leave `nest_id` blank and use the required
  complete direct GPS pair; negative IDs remain the separate brood-of-unknown-
  origin identifier.

Hiding-spot photos are separate age-C, `rclass = H` RESIGHTINGS events. A chick can
therefore have one CAPTURES row for handling/banding/tent photos and a separate H row
for its hiding-spot photo. Every H row requires an explicit valid positive or negative
`nest_id`; negative H rows additionally require the negative ID and both direct GPS
fields. CAPTURES `chick_hide_photo` is retained for compatibility but is not the
normal hiding-photo record.

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
the current RESIGHTINGS submission contains age-C rows or age-A `BC`/`FC`/`AC` rows.
The association is tested within the current submission, using the same date and
either the same nonblank `nest_id` or the same complete `gps_id/gps_point` pair.
For the reciprocal parent-side check only, an already-saved age-C CAPTURES row
may satisfy the association when date, site, `gps_id`, and `gps_point` all match
the parent row exactly. The genuine capture must be saved before the parent
RESIGHTINGS submission; an unsaved capture in another portal session is not
visible to the validator. The qualifying parent-with-chicks behavior set is
`BC`, `FC`, and `AC` under the current local protocol mirror v1.3.19. Matching
requires the same date and site plus either the same valid `nest_id` or the same
complete `gps_id/gps_point` pair.

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
H-photo rows. Under the current local protocol mirror v1.3.19, a chick row may
use `rclass = H`, `R`, `P`, `V`, or `C`, but it must be accompanied in the same
portal submission by an
age-A row whose comma-separated behavior includes `BC`, `FC`, or `AC`. Conversely,
a parent row with `BC`, `FC`, or `AC` must have at least one linked age-C row in
that submission. The parent and chick can be linked by the same valid `nest_id` or
by the same `gps_id/gps_point` pair; the date must also match. This does not use
saved RESIGHTINGS history to bypass the rule.

`BW` means broken-wing display, not brood watch. It is a shorebird parent behavior
that can occur at either the nest stage or the brood stage, so it remains part of
the broad parent/nest-link behavior set but does not by itself assert that an
individual chick was observed and does not trigger the reciprocal `BC`/`FC`/`AC`
rule.

`RES_005D` now restricts adult `IN`/`NM` rows to positive nest_ids whose latest
state is `F`, `I`, or `H`; `H` remains valid during asynchronous hatching. It no
longer blocks adult `BW`, `BC`, `FC`, or `AC` rows merely because the nest is at a later
state. `RES_005K` requires positive-nest `BC`/`FC`/`AC` rows to have latest state `H`
or `notA`, and requires `gps_id/gps_point` for age-C rows and brood-associated
adult `BW`/`BC`/`FC`/`AC` rows when a `notA` nest still has `brood_size > 0`.

Every age-C H row must carry an explicit valid positive or negative `nest_id`.
The former unlinked-H exception has been removed: mandatory H GPS/ring/photo
evidence still applies, but a same-session parent, H ring, prior capture history,
or other inferred association cannot replace the entered H-row `nest_id`. This
does not change the approved blank-ID routes for ordinary age-C `R`, `P`, `V`, or
`C` rows.

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

The verified protocol and local implementation artifacts cover the current
reviewed v1.3.19 mirror semantics, while the external canonical file remains
v1.3.5. Live deployment is **not established**. No live `inspectors` rows were
inspected or changed.

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

The external YAML remains the canonical version 1.3.5 artifact and was not
modified. The tracked local mirror is a distinct proposed version 1.3.14 artifact;
the two files are therefore not byte-for-byte identical. The mirror records the
age-C R/C GPS requirement, adult caught-with-chicks GPS requirement, saved-CAPTURES
parent-side reciprocal exception, conservative two-parent negative-brood family
inference, and RESIGHTINGS `R?` tarsus handling described above. The tracked
RESIGHTINGS and CAPTURES exports plus focused tests implement those local changes,
but they remain review artifacts and do not establish live deployment. The
unresolved derived H-association/view discrepancy remains with the responsible
schema/TODO workstream.

## Documentation-recovery appendix — 2026-10-23

This appendix records a recovery attempt after the validation specialist became
unavailable for follow-up delivery. It is documentation status only. It does not
change the protocol, validator lists, inspector rows, mock workbook, SQL, tests,
or live database state.

### Current authority and state labels

The external canonical protocol is the working file
`bdot_dataentry_validator_protocol.yaml`, version **1.3.5**, generated
2026-10-24. The tracked local mirror under
`validator_sandbox/xlsx_short_tag_update/` is a distinct proposed version
**1.3.12**, generated 2026-10-26; it must not be mistaken for a byte-identical
copy or for a live deployment. The older v1.3.3 and v1.3.2 statements earlier
in this handoff are historical milestones and must not be read as the current
protocol header.

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

## Historical documentation reconciliation — 2026-10-23

This section is retained as a historical milestone. Its protocol identity and
byte-identity statements describe the 2026-10-23 inspection only; the current
2026-10-26 state is recorded in the sections above and takes precedence.

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
3. The then-byte-identical local protocol mirror at
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
protocol_version: 1.3.5
generated_on: 2026-10-24
SHA-256: 8f98882efeb71c468bae1e7b5bf46bee413dce99a490894496768317c9578d94
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
- CAPTURES hard: `CAP_001`, `CAP_001A`, `CAP_001B`, `CAP_002`, `CAP_003`, `CAP_004`,
  `CAP_005`, `CAP_006`, `CAP_006B`, `CAP_009`, `CAP_009B`, `CAP_010`, `CAP_013`,
  `CAP_014`, `CAP_015`, `CAP_015B`, `CAP_016`, `CAP_016B`, `CAP_017`,
  `CAP_017B`, `CAP_018`, `CAP_019`, `CAP_020`, `CAP_021`, `CAP_021B`,
  `CAP_022`, `CAP_023`, `CAP_024`, `CAP_026`, `CAP_027`, `CAP_028`,
  `CAP_030`, and `CAP_031`. CAPTURES warnings include `CAP_007`, `CAP_008`,
  `CAP_011`, `CAP_012`, `CAP_012B`, `CAP_025`, `CAP_029`, `CAP_W001`,
  `CAP_W002`, `CAP_W004`, `CAP_W008`, `CAP_W009`, `CAP_W011`, `CAP_W012`, and `CAP_W013`.
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
minus sign is meaningful. `NO_NEST` is a retired current-input sentinel, not a
negative brood; unrelated new events use blank `nest_id`. Relevant negative-brood events require a complete direct
`gps_id`/`gps_point` pair. Age-C first captures require a real positive nest or
negative brood rather than blank or `NO_NEST` linkage. A positive-nest age-C `F`
chick capture at the nest may leave both GPS fields blank; if a direct location
is entered, the pair must be complete. Age-C `R` and `C` captures require the
complete pair even with a positive nest, as do positive-nest adult captures whose
`caught_with` value records chicks. A positive-nest chick captured away from the
nest may therefore carry a complete pair.

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

Under the current local protocol mirror v1.3.19, `RES_005J` is save-blocking and
covers ordinary age-C rows as well as H rows. Every age-C `rclass = H`, `R`, `P`,
`V`, or `C` row in
the current portal submission must have an age-A parent row in that same
submission whose behavior contains `BC`, `FC`, or `AC`. Every qualifying parent row
must have at least one linked age-C row. Matching requires the same date and
site and either the same nonblank valid `nest_id` or the same complete
`gps_id/gps_point` pair.
An already-saved age-C CAPTURES row can satisfy the parent-side reciprocal check
only when date, site, `gps_id`, and `gps_point` match exactly; save the genuine
capture first. An unsaved row in another portal session does not satisfy it. The
chick-side requirement still needs a linked age-C RESIGHTINGS row in the current
submission.

`IN` and `NM` are active-nest identity/linkage behaviors. The current positive
nest must have latest state `F`, `I`, or `H` for the relevant active-nest check;
`H` remains valid during asynchronous hatching. `BC`, `FC`, and `AC` are brood-
association behaviors and require latest positive-nest state `H` or `notA`.
When a `notA` nest still has brood, the applicable age-C and adult brood-
association rows require the complete GPS pair. `BW` means broken-wing display,
not brood watch: it can occur at either nest or brood stage and does not by
itself trigger the reciprocal parent/chick requirement.

`AC` means “Alert with chick(s)” and is now an approved parent-with-chicks
behavior equivalent to `BC` and `FC` in `RES_005J`, `RES_005K`, and the
mock-generation guidance. The tracked exports are consistent with this protocol
update. Live deployment remains unestablished.

For a blank current `nest_id`, the narrow negative-brood family exception is
deliberately conservative: `ADULT_PARENT_STATUS` must provide exactly one
selected M and one selected F identity for one negative `nest_id`, with neither
sex pending or ambiguous, and each observed unlinked parent must match its
selected identity. One observed parent is sufficient; the absent mate is not
fabricated. Missing authoritative status, ambiguous or conflicting status, or an
unmatched observed identity fails closed and requires an explicit `nest_id`.
The corresponding S10 SQL interface is
`TODO_PARENT_CHICK_RESIGHTING_ASSOCIATIONS`, built from the selected-parent
fields in `TODO_PARENT_STATUS_INPUT`/`ADULT_PARENT_STATUS`; it matches the
observed parent and chick on exact date and GPS pair while preserving the raw
rows. The row-level RESIGHTINGS validator mirrors that contract from the saved
`ADULT_PARENT_STATUS` lookup and cannot see an unsaved cross-portal row.

Within one family occasion, defined by the same date, site, `gps_id`, and
`gps_point`, the hard RESIGHTINGS nest-link check also collects nonblank valid
`nest_id` values from current parent/chick rows and relevant saved CAPTURES or
RESIGHTINGS companions. More than one distinct ID—positive, negative, or a
positive/negative mixture—is a save-blocking conflict on the current rows. This
is an encounter-level consistency check, not a lifetime single-nest rule: a
chick may change nest/brood association between separate encounters.

Any current parent event containing `?` in UL, LL, UR, or LR is excluded from
parent–nest association evidence unless a known metal ring can be traced to
capture history and resolves to exactly one `nest_id`. An arbitrary nonblank or
unverified ring is not enough. The raw uncertain mark is preserved; it is not
rewritten into a colour or treated as a wildcard.

### Protected WIP and cross-thread boundaries

The checkout was already dirty before this reconciliation. Unrelated tracked
changes remain protected, including `AGENTS.md`, SQL, Thread 2/7 handoffs, and
other workstream files. The validator artifacts intentionally touched in this
pass are `CAPTURES_hard.R`, `RESIGHTINGS_hard.R`, the focused RESIGHTINGS and
CAPTURES mock tests, this handoff, and the local protocol mirror. Other inspector
WIP, including NESTS terminal-state/clutch changes and the adult `HA` capture
rule, remains protected and was not reworked here. No live inspector state was
queried or changed.

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
photos are one H row per photographed chick with its ring, explicit valid positive
or negative `nest_id`, complete GPS pair, and photo metadata. Ordinary resightings
may leave `ring` blank.

For RESIGHTINGS, a current-session age-C row must be accompanied by a linked
age-A parent row with `BC`, `FC`, or `AC`, and the parent row must have a linked
chick row; the rows share date and either `nest_id` or a complete GPS pair.
`IN`/`NM` are active-nest behaviors, `BC`/`FC`/`AC` are brood-association
behaviors, and `BW` means broken-wing display and can occur at either stage.
