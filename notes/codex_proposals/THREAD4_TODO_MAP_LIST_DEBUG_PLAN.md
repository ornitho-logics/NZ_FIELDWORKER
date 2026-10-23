# THREAD 4 - To-do, map, list, and PDF operational reference

## Document status

This is the tracked Thread 4 handoff document refreshed on 2026-10-23. It is a
restart-grade operational reference for the local-replica/debugging thread. It
describes source and observed failure modes; it does not claim that any SQL,
R code, database views, or Shiny process is live.

- The documentation publication baseline is `origin/main` at `f7d13fb`.
- The original Thread 4 inspection baseline was `9beb203`; references to it
  below preserve the audit chronology rather than describing the publication
  branch.
- The calling checkout is branch `codex/split-todo-calculator-2026-10-19` at
  `d3c7bd4`, with unrelated uncommitted changes. It is protected WIP, not a
  deployment candidate.
- The refresh-only fix `ad1698b` (`);;` to `);`) was subsequently merged
  through PR #147 and is included in `f7d13fb`. This source merge does not
  establish live deployment.
- The current checkout contains an experimental active split task calculator;
  `origin/main` deliberately does not. Do not describe the dirty worktree as
  the current deployable architecture.
- This handoff and its sanitized companion
  `notes/codex_logs/THREAD4_PROMPT_LOG.md` are tracked. Raw transcripts remain
  ignored.

Status vocabulary used below:

- **Remote baseline** means the committed files at the inspected
  `origin/main` revision.
- **Protected WIP** means the current dirty checkout and its uncommitted
  source changes; preserve it and do not deploy it accidentally.
- **Local candidate** means a clean disposable worktree based on the selected
  revision plus an explicitly reviewed change.
- **Database deployment** means views/tables actually rebuilt in a target
  MariaDB database.
- **Live verification** means database diagnostics, Shiny restart, and
  user-facing output checks after deployment. None is claimed here.

No live database was connected to, changed, or rebuilt during this refresh.
No raw rows, coordinates, credentials, or field records are included here.

## Thread 4 scope and boundaries

Thread 4 owns the operational explanation and verification plan for the SQL
task engine and its list, map, KMZ, and PDF consumers. It does not own the
database schema, validator policy, overview-dashboard design, or available-mark
policy. Those are coordinated with Threads 1, 2, 3/3.1, 5, and 6.

The authoritative task source is the SQL `TODO_LIST` view. The PDF should not
reimplement task eligibility in R. R prepares display data, applies the PDF's
presentation labels and symbols, and renders the result.

## Current-state reconciliation (2026-10-23)

The repository now has three layers that must not be conflated:

1. **Install layer.** `DATABASE/views.SQL` defines compatibility, identity,
   nest, brood, hatch, parent-input, closure, and published-output views. In
   the remote optimized baseline it creates bounded input views and drops the
   obsolete active `TODO_LIST_CALCULATE` object rather than asking MariaDB to
   compile the entire task graph during installation.
2. **Refresh layer.** `DATABASE/refresh_todo_list_snapshot.SQL` performs the
   expensive reference-date-specific materialization. It builds indexed
   replacement tables, validates the results, and atomically publishes the
   task, parent, GPS-link, and closure snapshots. It is not redundant with the
   install script.
3. **Application layer.** The Shiny worker in `main/R/system_utils.R` starts
   the refresh script through the local MariaDB/MySQL client, writes stage
   status to `TODO_REFRESH_STATUS`, and exposes status in the download page.
   Ordinary PDF downloads should read the published snapshot, not expand the
   full task graph again.

The protected dirty checkout is different: its `DATABASE/views.SQL` contains
an experimental active split calculator (`TODO_LIST_PARENT_TASKS`,
`TODO_LIST_NEST_TASKS`, `TODO_LIST_BROOD_TASKS`, `TODO_LIST_CLOSURE_TASKS`, and
`TODO_LIST_CALCULATE`) as well as snapshot-related definitions. That WIP must
not be used as evidence that the remote baseline has the same objects, and it
must not be deployed by copying the dirty file. The local-replica thread should
start from a clean selected revision and port changes one architectural layer
at a time.

The safe debugging target is therefore not “make one enormous `CREATE VIEW`
paste finish.” It is: reproduce the selected revision locally, replay install
and refresh separately, time each stage, compare task rows and PDF inputs with
the known-good contract, and only then prepare a small reviewed deployment
candidate.

## Production/Adminer failure evidence

The observed remote failure was MariaDB error `2006`, “server has gone away,”
while Adminer was executing the very large `views.SQL` paste. The first
connection then returned cascading errors because its server connection was
already dead. This is not evidence of a SQL syntax error at the first red
line, and it is not proof that the later refresh stages ran.

The strongest observed process-list evidence was a
`CREATE OR REPLACE VIEW ... CAPTURES_ARCHIVE` statement waiting for a table
metadata lock for roughly two minutes. A second Adminer connection also
timed out during one attempt. Other snapshots showed only the Adminer query
and an idle connection after the failure. The administrator was not reachable,
so the exact server log cause is unknown: resource exhaustion, a restart,
metadata-lock interaction, or an application/proxy timeout remain possible.

The reported MariaDB facts were version 11.8.9, a 6 GiB InnoDB buffer pool,
256 MiB temporary-table limits, a roughly 510 MiB maximum packet, 8 MiB sort
buffer, 100 maximum connections, `performance_schema` disabled, low observed
connection counts, and no observed aborted clients/connections at the later
check. Those values do not prove that memory was sufficient during the failed
statement. No OOM log, swap metric, or exact killed-process record was
available.

An earlier expensive path used `CREATE TABLE ... AS SELECT * FROM
TODO_LIST_CALCULATE WHERE 1 = 0` to infer a schema. MariaDB still expanded the
large view while deriving the empty table definition. The current design uses
explicit snapshot schemas and indexes instead. This removes that avoidable
initialization cost but does not make a monolithic live view safe to compile on
a constrained server.

For local diagnosis, capture per-statement elapsed time, row counts, and the
server error log from the disposable MariaDB instance. Treat the Adminer
location as approximate unless the server process list or local replay proves
the exact statement. Do not infer that a partially created view set is
coherent merely because some later objects exist.

## Files and authorities inspected

The refresh inspected:

- `AGENTS.md`.
- Thread 1 repository map.
- Thread 2 schema review.
- Thread 3 validator architecture and the Thread 3.1 validator protocol notes.
- Thread 4 proposal and prompt log.
- Thread 5 Overview dashboard plan.
- Thread 6 combo-list protocol.
- `notes/codex_proposals/GEOLOCATOR_ROLLOUT_PROTOCOL.md`.
- Thread 8 H-event reconciliation and template-distillation notes.
- `DATABASE/main_tables.SQL`, `DATABASE/functions.SQL`,
  `DATABASE/predict_hatching.SQL`, and `DATABASE/views.SQL`.
- `DATABASE/refresh_todo_list_snapshot.SQL` as the separate refresh/publish
  source, not as a redundant copy of the install layer.
- `main/global.R`, `main/ui.R`, `main/server.R`.
- `main/R/system_utils.R` and `main/R/system_utils_app.R` for the background
  refresh worker, status markers, lock handling, and health checks.
- `main/R/pdf_todo.R`, `main/R/pdf_todo_map.R`,
  `main/R/leaflet_nest_latest.R`, `main/R/kmz_nest_latest.R`, and
  `main/R/html_tables.R`.
- `main/templates/todo_pdf.qmd` and the live-map help text.
- `tests/testthat/test-pdf-todo.R`,
  `tests/testthat/test-todo-view-rules.R`,
  `tests/testthat/test-todo-refresh-worker.R`, and the focused map/app tests.
- `notes/codex_proposals/THREAD9_LOCAL_REPLICA_PROTOCOL.md` for the
  disposable MariaDB replay boundary and its explicit ownership split.
- The inspected `origin/main` revision and the protected dirty worktree were
  compared separately; neither is silently treated as the other.

The local source files, not older Thread 4 prose, determine the implementation
claims below. Where the checked-out source, dirty WIP, or remote reference
disagree, the disagreement is called out explicitly.

## SQL-to-application data flow

The operational path is:

1. `settings.reference_date` provides the selected operational date.
2. `NESTS`, `CAPTURES`, `RESIGHTINGS`, `EGGS`, `GPS_POINTS`,
   `predict_hatching`, and settings feed the derived views.
3. `NESTS_LATEST` selects the latest reference-date-bounded positive nest
   observation and supplies the ordinary nest state, visit, clutch, hatch,
   parent, and location fields.
4. `BROODS_LATEST` provides the unified brood-facing source for positive nests
   with hatch evidence and negative/mobile broods. It is used by the PDF map
   and parent summary and by the interactive live-map preparation layer.
5. `EGGS_HATCH_PREDICTION` supplies hatch-date evidence, days-to-hatch, and
   reference-date laying-age fields.
6. In the remote optimized baseline, bounded helper views and published
   snapshot boundaries are installed by `views.SQL`; the expensive
   reference-date-specific task assembly is performed by
   `refresh_todo_list_snapshot.SQL`. `TODO_LIST` then exposes the published
   task rows, timing gates, note text, sort fields, parent marks, GEO
   diagnostics, and overdue fields. `AVAILABLE_COMBOS` separately supplies
   the available team-mark pool used by the PDF.
7. The Shiny worker in `main/R/system_utils.R` launches the refresh as a
   background client process, records `queued`, `running`, `successful`, or
   `failed` status, and prevents concurrent refreshes. `main/server.R` reads
   that status and guards the PDF download against a missing or stale
   reference-date snapshot.
8. Shiny reads the published views through the source-watch map in
   `main/global.R`. `main/server.R` supplies the to-do table, PDF inputs,
   interactive map, offline downloads, and view-data outputs.
9. `main/R/pdf_todo.R` normalizes task rows, calls the PDF map helper, and
   prepares the PDF sections. `main/templates/todo_pdf.qmd` renders the PDF.

`TODO_LIST` and the map views are reference-date-sensitive. A source view can
be syntactically present while still being stale in the target database. A
successful SQL file paste therefore does not prove that the running app is
using the new view definitions; the database view definition, Shiny process,
and rendered output all need separate checks.

## Recent processing and PDF query-planning changes

Commit `8796dd6` simplified the initial nest-processing decision without
changing the task class or its biological eligibility gate. The follow-up
commit `0899b11` only made the fieldworker notes explicit by changing the
combined and photo-only labels to `float + nest/tent photos` and
`nest/tent photos only`. These changes are part of the current checked-out
source, not a separate application fallback.

The same SQL commit added source-of-truth comments at the major view
boundaries. They identify the fieldwork purpose and CTE roles for the
compatibility/archive layer, `NESTS_LATEST`, H-event association,
`BROODS_LATEST`, `EGGS_HATCH_PREDICTION`, GEO rollout planning, `TODO_LIST`,
`VIEW_1`, and `OVERVIEW`. These comments are explanatory documentation inside
`DATABASE/views.SQL`; they do not create additional views, alter table data, or
replace the protocol documentation here.

The processing CTEs in `TODO_LIST` are deliberately layered so each evidence
source remains auditable:

- `nest_history` bounds NESTS records to the selected reference date and
  operational site.
- `first_processable_visit` finds the first F/I/PP/PD visit that starts the
  processing history for a positive nest.
- `processing_photo_summary` counts every qualifying NESTS row from that
  first visit onward where `nest_photo = '1'` or `tent_photo = '1'`.
- `float_visit_summary` and `float_summary` count qualifying EGGS float rows
  on or after the same first processable datetime. A float requires the
  relevant `float_angle` and `float_location` fields.
- `processing_summary` joins the photo and float histories and retains their
  last dates/times and counts for the task decision.

This is intentionally a history-wide check rather than a current-clutch-only
check. A later zero-clutch or state change must not erase an earlier valid
processing photo or float. The old `complete_clutch_processing_status` CTE was
removed because it re-evaluated evidence against the current clutch context
and could therefore forget earlier processing. `Re-process nest` remains a
separate task for later clutch-increase evidence.

The resulting `Unprocessed nest` notes are:

- no qualifying float and no qualifying NESTS processing photo: `float +
  nest/tent photos`;
- no qualifying float but a qualifying NESTS processing photo: `float only`;
- qualifying float but no qualifying NESTS processing photo: `nest/tent photos
  only`;
- both components present: no initial `Unprocessed nest` row.

The initial processing task still requires a positive BADO nest in F/I/PP/PD
state and confirmed clutch-completion timing. When the hatch-prediction source
has already classified the nest as found-incomplete, complete-clutch
chronology, or stable one-egg/no-increase, flotation is not required; missing
NESTS nest/tent photos can still produce `nest/tent photos only`. CAPTURES
photo fields and chick/tent handling photos do not count as NESTS processing
photos for this task.

The same commit also changed `brood_followup_nests` to use reference-date-
matched `BROODS_LATEST` hatch evidence. This preserves the day-1-through-day-6
brood photo follow-up after a later nest-state change and keeps positive and
negative brood evidence on the unified brood path.

The PDF query path was narrowed for resource safety. `todo_pdf_save()` now
defaults to a projected query of only the TODO_LIST columns consumed by the
PDF and passes `derived_merge_off = TRUE` to `DBq()`. This discourages MariaDB
from repeatedly merging the complex TODO_LIST CTE graph into the outer PDF
query, reducing planning and memory pressure observed during large/mobile
downloads. It is a query-planning safeguard only: task eligibility remains in
SQL, and the optional caller-supplied `todo` argument remains available for
local previews and compatibility. The PDF still obtains brood data and other
inputs separately, normalizes them in R, and renders through Quarto/Typst.

The corresponding regression tests assert that processing uses the consolidated
history-wide summaries, that the removed CTE is not used, and that brood photo
follow-up consumes `BROODS_LATEST`. They are source-contract tests rather than
proof of performance on a deployed MariaDB instance. Mobile download behavior
still requires deployment-side memory and process monitoring.

## Current derived views

### `NESTS_LATEST`

The checked-out view is restricted to the operational site and selected
reference date. It selects one latest nest event deterministically by date,
time, and primary key, uses the latest GPS-linked nest location, and carries
the current parent marks and hatch/visit fields.

The current nest-state behavior includes the following operational rules:

- `pD` and `pP` are treated as active/uncertain incubation-like states for
  task purposes rather than being silently treated as closed states.
- A scrape-only `S` history can expire according to the established scrape
  rules.
- Direct scrape-to-`notA` histories are handled differently from nests that
  had positive nest or incubation evidence.
- `notA` is terminal for ordinary failed nests, but historical hatch evidence
  is preserved for brood-facing consumers.

This view remains a positive-nest view. Negative/mobile brood identifiers do
not need fabricated `NESTS` rows and are not expected to appear here.

### `BROODS_LATEST`

`BROODS_LATEST` is the unified positive/negative brood source used by the PDF
map and parent summary. It combines:

- positive nest IDs with historical hatch evidence, including a hatched nest
  that later receives a terminal `notA` event;
- negative brood IDs discovered through reference-date-bounded CAPTURES or
  RESIGHTINGS, without requiring NESTS or EGGS history;
- parent identity fields from the shared capture/resighting logic;
- chick capture status and independently selected chick-band colour;
- the latest qualifying age-C direct GPS location, with a positive-nest NESTS
  fallback and no fabricated negative-brood fallback.

Failed positive `notA` nests without hatch/brood evidence are intentionally
excluded from this PDF-facing brood source. The interactive map combines
`NESTS_LATEST` and `BROODS_LATEST` separately so it can still show those failed
closures as `notA`.

### `EGGS_HATCH_PREDICTION`

The current five-source hatch-evidence hierarchy is:

1. direct nest chronology;
2. egg floatation/calibration evidence;
3. found-incomplete clutch inference;
4. complete-clutch chronology;
5. discovery fallback.

Found-incomplete nests use the documented two-day laying interval internally,
then the approximately 26-day post-completion incubation interval. There is no
separate general sixth hatch-date back-calculation source in the checked-out
SQL. The chronology source now also covers a stable one-egg/no-increase clutch:
after two full days without an increase, the last one-egg visit is extended by
the two-day laying interval before adding the approximately 26-day incubation
interval. Hatch signs and observed `H` events can supersede an unresolved
estimate for operational hatch-follow-up purposes.

The view exposes predicted hatch date, days to hatch, predicted days since
laying, and reference-date days since laying. These estimates are biologically
sensitive and should be checked against the current field protocol before a
future season reuses them.

## Snapshot refresh and publication contract

The current refresh contract is intentionally staged. The exact object names
must be read from the selected revision before deployment, but the remote
optimized workflow has these phases:

1. `nest_context` builds the reference-date-bounded operational nest context.
2. `brood_context` builds compact positive/negative brood inputs.
3. `chick_capture_context` aggregates distinct chick captures and flag state.
4. `hiding_spot_photos` aggregates qualifying H-photo evidence.
5. `chick_gps_links` materializes the GPS-linked chick/parent evidence once.
6. `parent_status` builds the four-gate parent result from the bounded inputs.
7. `brood_closure` builds the presumed-dead/closure result.
8. `task_rows` assembles the complete task snapshot.
9. `publishing` atomically promotes the completed snapshots and public views.

Each expensive stage writes an explicitly defined, indexed `_BUILD` table. It
must not use a zero-row CTAS query over a large view to infer a schema. The
previous public snapshot remains available while replacement BUILD tables are
being populated. Publication uses a single atomic `RENAME TABLE` sequence
only after stage checks succeed, with `_PREVIOUS` tables retained until the
new public boundaries are valid. A failure before publication must leave the
previous public output in place; stale BUILD tables can be cleaned up on the
next retry.

The app button is a request mechanism, not a synchronous SQL request. It
starts the background worker, which writes stage markers such as “Building
nest context”, “Linking chicks to parents”, “Building task rows”, and
“Publishing snapshot”, followed by a final success or failure status. The
interface warns that the build may take several minutes. PDF download should
be enabled only when the latest successful status and published snapshot
reference date match `settings.reference_date`; a failed new build must not
silently expose a partial result.

There is one known revision-specific trap: the refresh script inspected at the
current checkout contains an empty-statement typo (`);;`) at the task-row
boundary. MariaDB may report an empty query and stop before publication. The
pending `ad1698b` change removes that extra terminator. It is not yet part of
the inspected `origin/main`, so the local-replica thread must test the exact
selected file and must not claim this fix is deployed.

## Current TODO task inventory

The final `TODO_LIST` union currently supports these operational classes. The
PDF uses clearer fieldworker-facing headings in several cases.

| SQL task class | PDF heading | Main eligibility / exclusions |
| --- | --- | --- |
| `Parent capture` | `Parents to capture` | Physical capture/banding, explicit GEO/tag deployment, or eligible pair-completion work for an X-X, unknown, recruit, or already-colour-banded target; subject to 7-day and 36-hour gates. |
| `Parent resighting` | `Parents to resight for nest association` | MM follow-up, unresolved already-banded resighting association, or a temporarily timing-blocked capture need. Notes expose MM matching-resighting counts and generic association-resighting counts. |
| `Unprocessed nest` | `Nests to process` | nest processing such as egg photos and/or floatation when the nest is eligible; excluded for negative broods and for cases where hatch signs or incomplete-clutch rules make floatation inappropriate. |
| `take scrape photos` | `Take scrape photos` | qualifying scrape with a uniquely identified, banded parent and missing required scrape photos. |
| `Re-process nest` | `Nests to process` | a later processing requirement after relevant nest/clutch evidence changes. |
| `Clutch check` | `Nests to check for additional eggs` | a recent sub-three-egg clutch check, recurring under the current stability interval until the clutch is stable long enough. |
| `nest check` | `Nests to check for potential hatch` | predicted or observed hatch follow-up, with hatch-sign text from the last visit in the PDF note. |
| `Untrapped brood` | `Broods to band` | negative or hatched brood without the required chick capture/banding evidence. |
| `Hiding spot photos needed` | `Broods to photograph` | qualifying positive or negative brood within the day-1-through-day-6 window whose distinct captured-chick rings outnumber its distinct qualifying H-photo rings. |
| `Broods to recapture for flagging` | `Broods to recapture for flagging` | brood with chicks aged at least 21 days and remaining unflagged chick evidence; recapture and assign unique engraved UL flags. |
| `notA nest-check` | `Nests requiring a 'notA' closure visit` | closure follow-up for appropriate positive nests; negative broods never generate this class. |

The SQL may also build compatibility or intermediate rows such as
`Untrapped parent`, but the current final task union is the authority for what
the PDF displays. `Tagged birds to resight` is a separate PDF table sourced
from `VIEW_1`, not a `TODO_LIST` task class.

Negative/mobile broods can generate parent work, `Broods to band`, and hiding
photo work. They must not generate `Nests to process`, scrape photos,
re-processing, clutch checks, ordinary nest checks, or `notA` closure visits.
They have no fabricated hatch estimate or GEO/phenology target.

The flagging task is a dedicated brood-level follow-up. It applies at age 21
days or older, asks observers to recapture chicks and assign unique engraved
flags on the UL leg segment, and uses the same field columns and PDF table
shape as `Broods to photograph`. It must count already flagged/engraved chick
identities so completed chicks do not create duplicate work, retain the
remaining count in the note, and use discovery-age logic for negative broods.
The exact SQL branch, heading, subtitle, and tests are present in the current
source history and should be verified in the clean candidate selected for a
local replay. Do not infer that a task is deployed merely because its R/PDF
heading exists.

### Processing and brood-photo task separation

`Nests to process` and `Broods to photograph` are separate operational tasks
with different evidence sources:

- `Nests to process` uses positive-nest `NESTS` history and `EGGS` history. A
  qualifying nest-processing photo is `NESTS.nest_photo = '1'` or
  `NESTS.tent_photo = '1'`; a qualifying float is an `EGGS` row with the
  required float fields. Adult or chick handling photos in `CAPTURES` do not
  satisfy this task.
- `Broods to photograph` uses positive hatch evidence or negative-brood
  discovery from `BROODS_LATEST`. It does not require an `EGGS` history and
  does not use `NESTS` processing-photo flags to resolve a hiding-photo task.

For `Broods to photograph`, `TODO_LIST` works independently for each positive
nest ID or negative brood ID. It counts:

1. distinct valid age-C `CAPTURES.ring` values for that operational ID up to
   `settings.reference_date`; and
2. distinct valid chick rings from qualifying H-photo `RESIGHTINGS` rows for
   that same operational ID and date boundary.

Duplicate capture rows or duplicate H-photo rows for the same chick ring count
once. Rings are never pooled across different broods. The task remains open
when the H-photo count is lower than the captured-chick-ring count, and the PDF
note reports the current ratio, for example `2/3 chicks with rclass 'H'
photos`. It closes when the counts match, or expires after the day-6 window.

Examples:

- Three captured chick rings and no qualifying H-photo rings produce
  `0/3 chicks with rclass 'H' photos`.
- Three captured chick rings and one distinct qualifying H-photo ring produce
  `1/3 chicks with rclass 'H' photos`; a second H row for that same ring does
  not change the ratio.
- Three captured chick rings and three distinct qualifying H-photo rings
  resolve the task, so no row is emitted.
- A negative brood with two captured chick rings and one valid H-photo ring
  follows the same rule and reports `1/2`; it does not need a NESTS or EGGS
  record.
- An H row with a missing, blank, whitespace-only, or textual `NA` ring, or
  without direct GPS or required photo metadata, does not increase the
  photographed-ring count. A CAPTURES photo or a legacy chick-photo flag does
  not substitute for an H-class RESIGHTINGS row.

The separate `Broods to band` task continues to use the presence or absence of
age-C CAPTURES rows and its own age/leg-flag rules. A single occasion may
therefore generate separate chick-capture and hiding-photo work; those rows
must not be collapsed merely because they share a date, GPS pair, or brood ID.

## Parent identity, association, and task split

Parent identity is sex-aware and chronology-aware. The SQL prefers informative
capture/resighting evidence, preserves full tag-bearing marks when a later
partial observation omits tibia segments, and does not invent `X-X` without an
explicit X-X record. Full marks should include a `T` segment when the relevant
capture established a tag.

The operational split is:

- **Parents to capture:** physical capture/banding, explicit GEO/tag deployment,
  eligible pair completion, or another band-only instruction. X-X, unknown,
  recruit, and already-colour-banded-but-untagged targets can all be capture
  targets when the identity and task rules support capture. Unknown status can
  produce a combined `resight/band` instruction. A known already-banded parent
  is not put here merely because its nest association is uncertain.
- **Parents to resight for nest association:** MM association uncertainty,
  unresolved already-banded resighting association, or a capture need that is
  temporarily blocked by the 7-day/36-hour timing gates. This is where MM and
  non-associating resighting evidence is operationalized.
- A nest/brood may appear in both tables when one sex needs capture and the
  other needs resighting.

The association-confirming behaviour tokens are `IN`, `NM`, `SC`, `BW`, `BC`,
`FC`, and `AC` (`Alert with chick(s)`). They are matched as behaviour tokens. A matching identity is also
resolved after three nest-linked resightings, counting the initial resighting;
behaviour is not required for that repeated-resight path. A single identity
with one of the qualifying behaviours takes precedence over all same-sex
identities supported only by non-qualifying behaviour, even when an alternate
has reached three non-qualifying resightings. Multiple qualifying identities
remain ambiguous. Later contradictory evidence, later capture, or a later
live X-X parent record is resolved by chronology rather than by letting an
earlier X-X or dead record permanently win. A selected resighting identity is
allowed to replace the current capture/resighting identity only when its latest
eligible association date is not older than that identity evidence.

For a post-MM X-X record, X-X can become the current parent only when the
qualifying nest association is chronologically valid. A later capture and
banding event for that sex supersedes an earlier X-X observation when the
capture is the better current identity evidence.

Timing gates remain important:

- **7-day rule:** capture is suppressed before at least seven days have passed
  from the applicable clutch-completion basis. Resighting remains available
  when it is operationally needed.
- **36-hour rule:** a new parent capture is suppressed until the established
  post-capture interval has elapsed. The PDF note distinguishes resight-only
  work from capture-eligible work.
- Hatch signs, a confirmed `H` event, or the approved hatch-state overrides
  can bypass the clutch-age gate when parents still need banding; the 36-hour
  disturbance interval remains separate.

### Current parent-task protocol

The following is the detailed handoff for a new agent. The SQL source of truth
is the adult-parent CTE chain in `DATABASE/views.SQL`:
`adult_capture_events`, `adult_parent_identity_latest`,
`adult_mm_capture_latest`, `adult_mm_followup_status`,
`adult_resighting_association_status`, `adult_parent_status`,
`todo_untrapped_parent_candidate`, `todo_parent_resighting_existing`, and
`todo_mm_parent_resighting`. The PDF does not independently decide whether a
parent task exists; it only groups and displays the `TODO_LIST` rows.

#### Shared identity rules

Parent identity is sex-aware, reference-date-bounded, and chronological:

- Informative capture identity is retained when a later resighting contains
  only partial lower-leg information. A tag-bearing capture mark is not
  silently shortened.
- Ordinary resighting identities use informative LL/LR even when UL/UR were
  also entered. For example, LL `BY`, LR `LW` is operationally `BY-LW`.
- A spacer-dependent single-lower-band bird uses the required upper/spacer
  colour as part of its identity and requires a full observation to distinguish
  it safely.
- Male and female records with the same lower combination remain distinct.
- `X-X` is used only after an explicit X-X record or a chronology-resolved X-X
  association. Missing identity is not automatically converted to X-X.
- A qualifying later live parent can override an earlier dead or provisional
  identity for current association/GEO purposes. A later resighting of a mark
  already ruled out by chronology does not reinstate that mark by itself.
- Only CAPTURES and RESIGHTINGS records on or before `settings.reference_date`
  are eligible for the selected TODO_LIST.

#### Parents to capture

The capture table is for physical capture work: banding an X-X or unknown
parent, full-colour banding a recruit, deploying a GEO/tag, completing a tagged
pair, or an explicit duplicate-correction exception. It is not a general list
of every uncertain parent association.

Positive operational units come from eligible current `NESTS_LATEST` rows and
approved hatched positive `notA` rows. Negative broods come from
`BROODS_LATEST` and do not need fabricated NESTS rows. Failed non-hatched
`notA` closures do not become parent-capture units.

A parent-capture candidate is generated when at least one of these applies:

- the associated parent is confirmed unbanded/X-X;
- parent status is unknown and capture/banding is still required;
- a single-colour recruit or other band-only state needs full banding;
- an actionable GEO target exists, including pair completion for an eligible
  untagged mate; or
- an explicit special correction is active.

An already banded bird with unresolved nest association is not turned into a
band-only capture task. It remains in the association-resighting pathway until
the identity is resolved. The deliberate exception is an explicit tag target:
an already colour-banded bird may still be captured for a GEO/tag, producing a
note such as `tag M (pair completion)`.

Unknown status is expressed in the note. For example, `resight/band F (status
?)` means resight first to clarify the female and then band if appropriate;
`band X-X M` means the male is already sufficiently identified as unbanded and
can be banded directly. MM uncertainty alone does not create a capture task.

#### Parents to resight for nest association

The PDF heading is `Parents to resight for nest association`. It is populated
by two evidence pathways and one temporary timing pathway.

**MM-capture follow-up.** `adult_mm_capture_latest` selects the latest adult
MM capture by nest and sex. After `DATEDIFF(reference_date, mm_capture_date)
>= 2`, the follow-up can be emitted for an eligible positive nest, hatched
positive `notA` nest, or negative brood. This is a calendar-day SQL gate; it
does not replace the exact 36-hour capture-disturbance gate.

The later nest-linked resighting must match the captured identity. Ordinary
birds match by normalized LL/LR; spacer-dependent one-band birds require the
canonical full identity. MM association resolves after either:

1. one matching resighting with `IN`, `NM`, `SC`, `BW`, `BC`, `FC`, or `AC`; or
2. three matching resightings, counting the first matching resighting.

A same-sex X-X resighting with an association behaviour can instead establish
X-X as the associated parent. It displaces the earlier MM identity, and later
resightings of the ruled-out MM mark do not restore it. A later non-X-X capture
starts a new chronology for that newly captured bird.

MM notes expose the matching post-MM count through the reference date:

- `MM cap M with 0 resightings`;
- `MM cap M with 1 resighting`;
- `MM cap M with 2 resightings`;
- `MM cap M with 3 resightings`.

The same wording is used for females. Alternate evidence remains visible, for
example `MM cap M with 1 resighting & BY-LW seen` or `MM cap M with 0
resightings; X-X also seen`. The count is for matching post-MM resightings,
not unrelated same-sex birds.

Current implementation nuance: when both male and female MM follow-ups are
pending, the `todo_mm_parent_resighting` aggregation still uses its legacy
combined note branch (`M&F had MM cap`, with its existing X-X suffix logic)
instead of preserving both dynamic per-sex counts. Single-sex MM rows use the
counted `MM cap M/F with ... resighting(s)` wording. This note-format gap does
not change eligibility or resolution, but it is a source-level follow-up if
per-sex counts are required in every combined row.

**Banded-bird resighting association.** An already banded adult resighted at a
nest with only non-associating behaviour, such as `AT`, enters the same
association workflow even without an MM capture. This is essential for later
nests when most adults are already banded.

The candidate is a reference-date-qualified CR adult resighting with an
informative canonical identity. A same-sex TN capture of that same identity at
the nest is direct association evidence and suppresses this generic
resighting-only uncertainty. MM captures are not suppressed by that rule; they
continue through the separate MM pathway.

For each nest and sex, each canonical identity is grouped separately. One
approved behaviour or three matching resightings, including the initial event,
resolves an identity. Notes expose the unresolved count:

- `M with 1 resighting`;
- `M with 2 resightings`;
- `M with 1 resighting; F with 2 resightings`.

Exactly one qualifying same-sex identity is selected and displaces all
provisional alternatives, including an alternate that has reached three
non-qualifying resightings. If there is no qualifying identity, exactly one
identity resolved by three matching resightings is selected. If more than one
qualifying identity, or more than one non-qualifying identity, resolves, the
task remains open rather than silently selecting one bird.

**Temporarily resight-only capture work.** Some rows originate as capture
candidates but are classified as `Parent resighting` on the current date. This
does not cancel the capture need:

- The 7-day rule suppresses capture before seven days after the applicable
  clutch-completion basis. Hatch signs, a confirmed H event, and negative-brood
  discovery make the capture-age gate operationally satisfied.
- The 36-hour rule is checked at 08:00 on the reference date. A target parent
  cannot be captured until 36 hours after the previous adult capture at that
  nest. The target-specific window uses the other sex's last capture time.
- While a gate is closed, an unknown-status need can appear as `resight M`,
  `resight M (status ?)`, or a combined `resight/band` instruction. When the
  gate opens, the same need moves to `Parents to capture`.

The generic already-banded association pathway is not delayed by the 7-day
capture rule: it can appear as soon as the qualifying resighting is available
and the nest/brood unit is operational.

#### Invented chronology examples

These examples use invented IDs and are protocol illustrations only:

1. Male `BY-GW` is captured by MM at `C9999` on day 1 and matching `BY-GW` is
   resighted with `AT` on day 2. The next eligible TODO shows `MM cap M with
   1 resighting`; it remains until a qualifying behaviour or the third
   matching resighting.
2. If the next `BY-GW` record has `AT, IN`, the MM task resolves on that date
   and disappears from the resighting table. The bird remains in the summary
   or map and can still be a separate tag target.
3. Male `BY-BG` is first seen at `C9999` with `AT`, without a same-sex TN
   capture. The following day shows `M with 1 resighting`. A later `IN` or the
   third matching `AT` event removes the task.
4. `BY-GW` was captured by MM and `BY-LW` is later seen with `AT`. The MM and
   generic pathways can both remain visible. If `BY-LW` later receives `IN`,
   it becomes the sole resolved male, displaces `BY-GW`, and no band-only
   capture task is created because `BY-LW` is already banded.
5. If two male identities are both seen only with `AT`, the table retains the
   ambiguity. If both later resolve independently, it also remains ambiguous
   because there is more than one resolved candidate.
6. An unknown/X-X male needing banding but blocked by the 7-day or 36-hour
   gate can temporarily appear as `resight M (status ?)`. When the gate opens,
   it moves to the capture table.
7. A same-sex TN capture of a banded resighting identity directly resolves its
   nest association, so the generic resighting-only row is not emitted for
   that identity.

#### Ranking, resolution, and removal

The SQL retains `days_overdue`, `priority`, estimated hatch timing, and last
visit age. Its numeric priority combines days since nest discovery with hatch
urgency and is available for diagnostics. The PDF applies the visible order:
within `Parents to resight for nest association`, estimated hatch timing is
ascending, then `last_visit_days_ago` is descending so older last visits come
first, then `nest_id` provides a stable tie-breaker. The final SQL grouping
combines distinct notes into one row per nest and reference date. `TODO_LIST`
itself should not be assumed to have physical row order before PDF preparation.

Rows are removed or change category as follows:

- MM work disappears when the matching identity resolves, X-X becomes the
  chronology-supported parent, or one alternate identity resolves and
  displaces the provisional MM identity.
- Generic banded-resighting work disappears when one identity resolves and no
  competing identity remains. It remains open for no resolution or competing
  independent resolutions.
- A timing-blocked capture row moves to `Parents to capture` when its gates
  open; it is not permanently resolved merely because it was shown as a
  resighting task earlier.
- A new capture or qualifying resighting can change the parent marks shown in
  both tables, the PDF map, and the parent summary. Future events do not alter
  an earlier reference date.
- A row disappears permanently only when the association/capture need is
  resolved or the nest/brood is no longer an eligible operational unit.

GEO/pair-completion behavior is coordinated with the geolocator rollout
protocol. The checked-out SQL still contains a 60-device release ceiling and
the checked-out pre-25/sex-phenology targeting logic. The remote reference
has drifted in this area, including pair-completion ceiling treatment. Do
not infer the remote behavior from this local branch, and do not infer either
behavior is live until the database view and PDF output are verified.

## Hiding-spot photo resolution

The approved base contract is:

- age-C RESIGHTINGS;
- `rclass = 'H'`;
- a linked positive nest or negative brood ID;
- a nonblank normalized `ring` value;
- direct `gps_id` and `gps_point` linkage;
- required photo metadata.

Blank, whitespace-only, textual `NA`, non-H rows, missing ring, or missing
direct GPS do not resolve the task. Multiple H rows for one brood resolve one
task, while each row retains its individual ring identity. H rows and same-
occasion chick CAPTURES describe different actions and must not be collapsed.

The current SQL resolves the operational ID through
`RESIGHTINGS_H_BROOD_ASSOCIATIONS`. A direct `nest_id` is preferred; where the
raw H row is unlinked, the helper can use a deterministic prior chick-ring
capture association or an unambiguous same-occasion adult/family association
at the same GPS pair. Ambiguous candidates remain unresolved rather than
clearing a photo task silently. The raw `RESIGHTINGS.nest_id` value is not
modified.

The resulting `resolved_nest_id` is the identifier used by the H-photo count,
`TODO_LIST`, the PDF, and brood-facing map/table consumers. This keeps linked
and derived associations on the same per-brood counting path while retaining
the original field record unchanged.

## Interactive Nest Map contract

The interactive map intentionally differs from the PDF map.

The live map preparation layer in `main/R/leaflet_nest_latest.R` combines
`NESTS_LATEST` with `BROODS_LATEST` and returns one display row per identifier:

- active/unresolved positive nests retain their ordinary NESTS state and
  stationary NESTS location;
- a positive hatched nest is normalized to map category `brood`, including a
  hatched nest later closed with `notA`;
- a failed positive `notA` nest without hatch evidence remains visible as
  category `notA` and can be toggled independently;
- negative IDs retain their leading minus sign and use their latest valid
  age-C direct GPS location; they have no NESTS fallback;
- positive broods use the latest valid direct chick-event location and fall
  back to the positive NESTS location when no direct location exists;
- negative broods without valid coordinates are omitted from plotted markers
  with an informative warning rather than being assigned a false location;
- duplicate positive rows from the two views collapse to one marker.

The UI picker is `State / brood`. `brood` replaces the old H map category,
uses the established bright blue `#1aa9fc`, and is selected by default along
with `notA`. The legend contains `brood`, not H. `notA` remains independently
selectable. Popups preserve useful provenance, latest state, latest encounter,
location source, hatch evidence, and parent marks without exposing raw helper
columns. HTML values are escaped.

The live map source watcher polls both NESTS_LATEST and BROODS_LATEST and
includes their documented upstream dependencies. A missing BROODS_LATEST view
is currently handled as an unavailable brood layer with a warning; this should
be treated as a partial-deployment diagnostic, not as proof that no broods
exist. A complete render failure uses the existing user-facing fallback map.

## PDF map, task tables, and parent summary

The PDF map is prepared through `todo_pdf.R` and `pdf_todo_map.R`, then rendered
by `todo_pdf.qmd`. It has a three-panel A/B/C layout, study-area polygon
overlays, orientation/scale aids, a transparent imagery layer when available,
task symbols, and nest/brood labels. The map is forced to the final PDF page.

PDF map inclusion is intentionally narrower than live-map inclusion: active
positive nests and positive hatched broods are retained, including hatched
positive nests after terminal `notA`; failed non-hatched terminal `notA` nests
are excluded from the PDF brood/map set. Negative broods discovered by the
reference date are included when their location is usable.

Task-map symbols distinguish nest-check work from other tasks. Parent work is
shown by capture/resight/no-parent-work colour. Chick-band colour is selected
independently from location from qualifying age-C CAPTURES, using the
established LL-before-LR extraction. A later RESIGHTINGS location does not
replace the assigned chick colour. Text contrast changes for readable coloured
labels.

The parent summary beneath the map is built from the same brood-aware data. It
includes active positive nests, hatched positive nests retained after `notA`,
and negative broods; failed non-hatched closures are not included. It is
ranked by nest/brood ID, uses parent marks from the shared identity logic, and
shows the same task symbol and chick-colour label contract as the map.

Current PDF presentation includes:

- `Parents to capture` and `Parents to resight for nest association`, with
  `Nest/Brood` columns;
- `Broods to photograph`, with a `Brood` column;
- `Broods to recapture for flagging`, with the same brood-oriented columns and
  table structure as `Broods to photograph`;
- `Broods to band`, nest-processing, clutch-check, potential-hatch, scrape,
  closure, and tagged-bird follow-up sections when nonempty;
- compact two-line headings, alternating row shading, and reduced table
  borders for the parent/brood task tables;
- the note key, which should contain only note types present in the PDF;
- the version/footer and header styling currently present in the checked-out
  R source.

`todo_pdf_version_footer()` now uses the shared `git_version` object from
`main/global.R` and displays the resolved commit ID only. `resolve_git_version()`
prefers deployment/environment identifiers, then matching local Git refs, then
remote/local fallbacks; the app sidebar and PDF therefore share the same
resolution path in the checked-out source. A deployed checkout must still be
verified because missing Git metadata or environment variables can resolve to
`unknown`, and a remote database/app can be running a different commit.

Parent capture and resighting rows are prioritized with hatch urgency first,
placing hatch-stage rows ahead of ordinary rows, then negative brood rows, then
ascending estimated hatch timing with descending last-visit recency for ties.
The SQL retains `days_overdue` for task ranking and diagnostics even though the
PDF no longer displays the Overdue column in the parent tables. Other sections
continue to use their SQL priority/overdue fields. The PDF note key currently
explains the 7-day and 36-hour gates, MM capture uncertainty, pair completion,
status uncertainty, and GEO context; the checked-out R wording for several of
these definitions is older than the current SQL wording and should be revised
in a coordinated PDF change rather than silently inferred from this memo.

PDF data are obtained through the selected reference-date task and brood views
and then normalized in R for display. This keeps eligibility in SQL, but it
means that stale or partially rebuilt views can still produce a plausible,
incomplete PDF; `SHOW CREATE VIEW`, row-count checks, and a fresh Shiny process
are required for deployment verification.

## Available combos, tables, KMZ, and other consumers

`AVAILABLE_COMBOS` applies the current exclusions and rank tiers in SQL. The
current intended ordering is LL beginning with Y, then no L/R, then L, then R,
followed by the corresponding tiers after LL-Y. Exclusions include LL `YR`
and LR `OR`/`RO`. Historical CR/CX compatibility handling and PDF team-size
ordering should be treated as a separate policy from the biological task
engine and checked against Thread 6 before deployment.

The HTML/offline table helper currently queries the ordinary operational data
views and does not itself provide a full BROODS_LATEST/TODO_LIST replacement.
The offline KMZ currently defaults to NESTS_LATEST and retains an H-specific
palette. That is intentionally not silently changed by the live-map brood
contract. A future KMZ unification would require an explicit compatibility
decision and its own tests.

## Tests and evidence

The recent implementation evidence includes focused safe local tests for the
PDF, live map, server wiring, refresh worker, and TODO view contracts. The
processing/PDF planning regression coverage in
`tests/testthat/test-todo-view-rules.R` asserts that the consolidated
processing summaries are used, the removed `complete_clutch_processing_status`
CTE is absent, brood follow-up uses `BROODS_LATEST`, historical clutch size
preserves the capture gate after egg removal, and the dedicated 21-day
flagging task remains present. `tests/testthat/test-todo-refresh-worker.R`
checks worker command construction, lock/status handling, and failure-safe
publication assumptions. This documentation-only refresh did not rerun the
test suite.

The focused tests cover, using invented/mock data, the following contracts:

- PDF task preparation, labels, sorting, note-key filtering, negative-brood
  task exclusion, flagging headings/table structure, and adaptive summary
  layout;
- live-map merging, brood/notA categories, hatched-terminal-notA versus failed
  notA, negative IDs, coordinate fallback, duplicate collapse, warning paths,
  legend color, popup escaping, and empty-map behavior;
- H ring requirements, direct linked H resolution, blank/NA/non-H rejection,
  separate chick rings, and reference-date ordering;
- app wiring, refresh-worker behavior, and server behavior without a live
  database.

Remaining verification is deployment-sensitive rather than an undefined-view
gap:

- isolated MariaDB/mock-query tests for linked and unlinked H association,
  ambiguous shared-GPS rows, and multiple chicks;
- source-view dependency checks after a real database rebuild;
- live PDF, map, KMZ, and list checks after Shiny restart;
- resource monitoring for the projected PDF query on the deployed server,
  including a mobile download.

## Deployment and verification order

The safe deployment sequence is:

1. Confirm the intended Git branch and curate only approved commits from
   current `origin/main`; never deploy unrelated local or agent-only artifacts.
2. Apply schema changes first, including the nullable `RESIGHTINGS.ring` field
   and its validator/inspector update where required.
3. Apply required SQL functions and support tables.
4. Define approved helper views before dependent views. The current source
   defines `RESIGHTINGS_H_BROOD_ASSOCIATIONS`; rebuild and verify it before
   `BROODS_LATEST` and the snapshot boundaries, rather than assuming a
   previous database definition is still present.
5. Install the selected `views.SQL` only. Do not paste an experimental dirty
   calculator or treat the refresh section as a replacement for the install
   layer. Confirm the installer completes and that the expected boundaries,
   support views, and public snapshot objects exist.
6. Run the selected `refresh_todo_list_snapshot.SQL` separately. Monitor its
   stage/status output, and stop on error. Do not run the full refresh merely
   because ordinary PDF code was updated; refresh is required after source
   data or `reference_date` changes.
7. Check `SHOW CREATE VIEW`, snapshot row counts, reference-date ranges,
   `TODO_REFRESH_STATUS`, and small aggregate diagnostics. Confirm the
   definitions are the intended source, not merely that an SQL paste returned
   successfully.
8. Restart the Shiny process so source watchers and R helpers load the
   intended code.
9. Verify the app's reference date, task tables, live-map categories,
   negative-brood handling, 21-day flagging rows, PDF page count/map
   placement, parent summary, offline tables, and KMZ behavior.
10. Record the deployed commit, SQL version, database rebuild time, and Shiny
   restart time in a separately approved deployment record if an auditable
   history is required; do not put raw operational data in this handoff.

## Current risks and ambiguous assumptions

- The protected dirty topic branch differs from `origin/main`; remote
  behavior, protected WIP behavior, local-replica behavior, and live-server
  behavior must not be conflated.
- The current remote baseline has no active monolithic or split
  `TODO_LIST_CALCULATE` view after installation; a dirty WIP that does have
  one is not evidence that the baseline failed to install.
- A successful local PDF proves only that the selected local SQL/R/data
  combination is internally usable. It does not prove that Adminer imported
  the same revision, that the refresh reached publication, or that the live
  Shiny process restarted.
- `RESIGHTINGS_H_BROOD_ASSOCIATIONS` is now defined in the checked-out
  `DATABASE/views.SQL`, but a target database can still have an older or
  missing definition; verify it explicitly before rebuilding dependent views.
- The local SQL and remote SQL differ in GEO ceiling/pair-completion details.
- PDF version resolution depends on the deployed checkout's Git/environment
  metadata; verify that the PDF footer and app sidebar report the intended
  commit ID rather than `unknown`.
- KMZ and HTML table consumers are not automatically synchronized with the
  brood-aware interactive/PDF map contract.
- SQL view rebuilds can block or hang when dependent views are locked or
  rebuilt in an unsafe order. Use an isolated or maintenance-window database
  and inspect `SHOW PROCESSLIST` if a deployment stalls.
- A failed Adminer paste can leave a mixed schema: some views may be new,
  some old, and some absent. Existence checks alone are insufficient; compare
  `SHOW CREATE VIEW`, snapshot reference dates, and refresh status before
  diagnosing task biology.
- The `);;` refresh terminator is revision-specific. Test the exact refresh
  file that will be deployed and keep the pending fix distinct from the
  merged baseline until it is actually merged.
- `settings.reference_date` drives multiple views, so stale settings or a
  stale materialized view can make the app appear inconsistent.
- External imagery, spatial-object R expressions, and GPS linkage can fail
  independently of the task SQL; the PDF and interactive map have fallback
  behavior that must be checked rather than assumed.
- The 26-day incubation estimate, two-day egg-laying interval, 7-day capture
  rule, and 36-hour disturbance interval are protocol assumptions, not
  universal biological truths.
- The GEO release ceiling, pair-completion priority dates, plot restrictions,
  and sex/phenology quotas require explicit confirmation whenever the rollout
  protocol changes.

## Rollback

If a deployed rebuild is wrong:

1. Stop or isolate the affected Shiny process if it is repeatedly querying a
   locked or inconsistent view set.
2. Restore the previously approved SQL/view definitions from the deployment
   backup or known-good release, in dependency order.
3. Confirm `SHOW CREATE VIEW` for all dependent views and run the focused
   diagnostics before restarting Shiny.
4. Restart the app and verify a known reference date, task count, map category
   count, and PDF render.
5. Do not delete field records to repair a view problem.

For a source candidate, rollback means selecting the known-good Git revision
and re-running its install/refresh pair in the disposable replica. For a live
deployment, restore the previously approved SQL/view definitions and snapshot
workflow separately. No database or deployed process is changed merely by
merging repository files.

## Cross-thread handoff

- **Thread 1:** repository map, branch hygiene, AGENTS ownership, and the
  clean-PR workflow. Keep `AGENTS.md` tracked and include it only when an update
  is explicitly requested and reviewed.
- **Thread 2:** schema and derived-view ownership, especially
  `RESIGHTINGS.ring`, `BROODS_LATEST`, view dependencies, and source-watch
  mappings.
- **Thread 3/3.1:** validator protocol and live inspector deployment. H-class
  ring requirements must be aligned before relying on H-photo resolution.
- **Thread 5:** Overview outputs and reference-date assumptions. Do not infer
  TODO/map correctness from Overview counts alone.
- **Thread 6:** available-combo exclusions, CR/CX compatibility, and team-mark
  ordering.
- **GEO rollout protocol:** ceiling, pair completion, sex/phenology, timing,
  and plot eligibility. Reconcile local SQL against the approved protocol
  before changing deployment targets.
- **Thread 8:** H-event reconciliation. The current checkout defines
  `RESIGHTINGS_H_BROOD_ASSOCIATIONS` and uses it from `BROODS_LATEST` and
  `TODO_LIST`; direct, ring-derived, and same-occasion associations remain
  conservative, with ambiguous candidates left unresolved. Deployment still
  requires dependency-order rebuilds and focused association checks.
- **Thread 9:** disposable local MariaDB 11.8.9 replay, stage timing,
  process/error-log capture, refresh failure diagnosis, and local PDF render.
  Thread 9 must start from a clean selected revision and preserve this
  checkout's dirty files. It should send back timings, failing statements,
  object inventories, and sanitized diagnostics; Thread 4 interprets task
  biology and PDF/map contracts.

## Obsolete or superseded statements

Older Thread 4 notes describing the negative-brood feature as wholly future or
claiming that every `notA` row is excluded from every map are superseded by the
current live-map/PDF distinction. Older branch names, commit IDs, deployment
claims, and hard-coded PDF examples are historical context only. Statements
that a single `views.SQL` paste must also perform the entire refresh are
superseded in the remote optimized workflow: installation and materialization
are separate operations.

The current local implementation is not evidence that the matching SQL is
installed in the target database, that the Shiny worker has restarted, or that
the remote branch contains the same code. Those remain explicit verification
steps.
