# Thread 1 Repository Map: Current State

Last refreshed: 2026-10-06

Status: tracked static handoff for the repository-cartographer role. The full
repository audit underlying this memo was completed on 2026-09-27; this refresh
reconciles the Git state and major merged changes through `origin/main` commit
`1617e84`. The current PR candidate is based directly on that commit and adds a
broader parent-resighting association workflow plus tracked Thread handoffs.
Current tracked source remains authoritative where an older historical detail
in this long-form map has not been restated below.

This pass used static inspection only. No Shiny app or test suite was run, no
database connection was made, and no credentials, database rows, or GPS
coordinates were inspected or reproduced.

## What I inspected

- Full current `AGENTS.md` and `README.md`.
- Git branch, status, recent history, and the file-level diff since the July map.
- Current tracked SQL in:
  `DATABASE/main_tables.SQL`, `DATABASE/support_tables.SQL`,
  `DATABASE/functions.SQL`, `DATABASE/predict_hatching.SQL`,
  `DATABASE/views.SQL`, and `DATABASE/_reset.SQL`.
- All current entry and helper files under `main/`, including `main/R/`,
  `main/templates/`, `main/www/help/`, and the relevant JavaScript/CSS assets.
- All `DataEntry/*/global.R`, `ui.R`, and `server.R` files, including the central
  `DataEntry/inspectors/` and `DataEntry/spatial_objects/` apps.
- The complete repo-visible `gpxui/` wrapper.
- All current files under `tests/testthat/` and the static
  `tests/test-results.csv` badge source.
- The previous Thread 1 map and prompt log.
- Current Thread 2-5 handoff material for context, including the negative-brood
  work reported by Threads 2, 3/3.1, and 4.
- The current official validator protocol and its synchronized local mirror,
  both reporting protocol version 1.3.3, plus the ignored negative-brood mock
  fixtures under `notes/codex_proposals/validator_sandbox/`.
- Relevant ignored validator protocol and inspector-list locations without
  opening mock workbooks or reading record-level CSV data.

## Current Git state

- PR branch: `codex/parent-association-thread-docs-2026-10-06`.
- Base revision: `1617e84`, identical to `origin/main` when this branch was
  created.
- The PR candidate changes `DATABASE/views.SQL`, `main/R/pdf_todo.R`, and two
  focused tests for parent association, plus `.gitignore` and the six curated
  Thread 1-6 handoff documents.
- `AGENTS.md` is intentionally untouched and excluded from the PR.
- The six curated handoffs under `notes/codex_proposals/` are now explicitly
  unignored so future reasoning/logic updates remain reviewable in Git.
- Raw prompt logs, generated previews, dumps, workbooks, mock data, and other
  proposal artifacts remain ignored.
- Existing Git stashes are outside this branch and are not altered by this work.

## Changes merged after the 2026-09-27 full audit

- Negative-brood, hiding-photo ring, map, PDF, and validator work is now merged
  rather than existing only as local WIP.
- Database downloads were hardened, RDS exports gained `CAPTURES_ARCHIVE`, and
  incomplete SQL dumps can finish with explicit derived-view warnings.
- Parent identity, MM follow-up, capture/resighting separation, terminal brood
  tasks, and PDF ordering/legend behavior received multiple focused revisions.
- The Overview gained tagged-bird resighting histories and a hatching forecast;
  experimental pair tallies were subsequently removed from visible graphs.
- Inspector messages and rules were updated, and the reviewed per-table hard and
  warning inspector lists are tracked under `validator_sandbox`.
- Hatch chronology, one-egg stability, TODO processing, and PDF query planning
  were refined through `1617e84`.
- The current PR candidate generalizes unresolved banded-parent association to
  one qualifying nest behaviour or three matching nest-linked resightings.

## High-level repository structure

- `DATABASE/`: canonical tracked SQL definitions plus ignored local snapshots.
- `DataEntry/`: six biological entry apps and two support/admin code editors.
- `gpxui/`: thin local wrapper around the external `gpxui` package.
- `main/`: the main Shiny dashboard, reports, maps, downloads, help, PWA assets,
  and table/view browsers.
- `tests/testthat/`: mocked app wiring, DataEntry server, Overview, view-polling,
  and leaflet tests.
- `notes/codex_proposals/`: six tracked Thread handoffs plus ignored local
  working artifacts; `notes/codex_logs/` remains ignored.
- `tmp/`: ignored local scratch/output area.

`README.md` still gives a valid high-level installation and directory overview,
but it does not describe most current operational views, the seven-panel Overview,
the generated to-do map, or current tests in detail.

## Changes since the July 29 map

- The checked-out integration state is a focused PR branch based directly on
  `origin/main` commit `1617e84`.
- `USED_COMBOS_DETAIL` and `AVAILABLE_COMBOS` were added to the tracked view
  layer; `AVAILABLE_COMBOS` is browser-visible and supplies PDF team marks.
- `TODO_LIST` was substantially expanded around parent identity/status,
  mobile-mistnet follow-up, capture eligibility, explicit parent capture versus
  resighting tasks, and clutch follow-up.
- `main/R/pdf_todo_map.R` was added. The to-do PDF now includes a plotted task map
  and a compact nest summary in addition to task tables and team marks.
- The Overview now has seven panels, including unique band combinations,
  tagged-bird resighting histories, and a hatching forecast.
- Three Overview panels now use cumulative step/ribbon plots; all date-based
  panels share the same derived date limits; cumulative panels show summary
  annotations.
- Overview labels were shortened/wrapped and date breaks reduced for smartphone
  readability. The latest commit also removes the redundant sex legend title and
  wraps quota titles.
- Git/version display logic was replaced with deployment-aware resolution and a
  current repository commit link.
- View polling gained `dbview_is_updated()`, although several view dependency
  mappings remain incomplete or absent.
- Current tests cover the unique-combo Overview output, shared reference-date
  queries, non-diagonal cumulative ribbons, mocked DataEntry writes, view polling,
  and leaflet overlays.
- The approved local negative-brood implementation now adds `BROODS_LATEST`,
  negative-ID TODO branches, direct chick-event location precedence, chick-band
  colour selection, hatched-positive-`notA` retention, PDF map/summary behavior,
  and focused regression tests.
- Source DDL now includes free-text observer GPS associations and the wider
  `NESTS.bird_inc` enum (`M`, `F`, `FM`, `MF`, `U`, `E`).
- `RESIGHTINGS` now has nullable `ring varchar(50)` for the alphanumeric
  metal-ring code. It is required for qualifying age-C H-class hiding-photo
  events, while `RESIGHTINGS_PUBLIC` is unchanged.
- The hiding-photo view logic ignores H events whose ring is SQL NULL, blank,
  whitespace-only, or textual `NA`; the focused test covers positive and
  negative broods, separate chick rows, and the pre-ring behavior.

## Database schema and snapshots

The tracked `DATABASE/` folder is the schema source of truth.

Core source tables in `DATABASE/main_tables.SQL`:

- `OBSERVERS`
- `CAPTURES`
- `EGGS`
- `GPS_POINTS`
- `GPS_TRACKS`
- `NESTS`
- `RESIGHTINGS`
- `RESIGHTINGS_PUBLIC`

Support objects:

- `settings`, `spatial_objects`, and `inspectors` in
  `DATABASE/support_tables.SQL`.
- `predict_hatching` in `DATABASE/predict_hatching.SQL`.
- `format_mark()` in `DATABASE/functions.SQL`.
- Destructive reset statements in `DATABASE/_reset.SQL`; this is not a migration
  ledger or a complete safe rebuild script.

Current active views in `DATABASE/views.SQL`:

- `CAPTURES_ARCHIVE`
- `USED_COMBOS_DETAIL`
- `AVAILABLE_COMBOS`
- `NESTS_LATEST`
- `BROODS_LATEST`
- `EGGS_HATCH_PREDICTION`
- `TODO_LIST`
- `OVERVIEW`

Current schema facts that remain important across threads:

- `observer_upload` is CAPTURES-only.
- `eggs_handled` is a current CAPTURES binary enum.
- `EGGS` remains long format, one row per egg observation.
- `NESTS.bird_inc` accepts both `FM` and `MF` for both sexes seen.
- `RESIGHTINGS.ring` is nullable `varchar(50)`, stores the photographed
  individual's alphanumeric metal-ring code, and is mandatory for age-C
  `rclass = "H"` hiding-spot-photo events.
- The ring supplements `UL`, `LL`, `UR`, and `LR`; it does not replace those
  mark fields. Each photographed chick has its own H event, ring, GPS pair, and
  photo metadata.
- `OBSERVERS.gps_id` is free text for multiple-device associations.
- Cross-table links are indexed but not protected by foreign keys.
- `CAPTURES_ARCHIVE` requires compatible external historic objects
  `BADOatNZ.CAPTURES` and `BADOatNZ.SEX`.

Latest ignored local snapshots visible at inspection:

- `DATABASE/FIELD_2026_BADOatNZ_7311213.sql`, modified 2026-07-31.
- `DATABASE/FIELD_2026_BADOatNZ.rds`, modified 2026-07-23.

These snapshots predate the current September tracked SQL. They are safe local
alignment/test artifacts, not the current schema definition and not evidence of
live database state.

## Negative-brood methodology and implementation status

The agreed project methodology is that a negative `nest_id` identifies a brood
of unknown origin: no eggs, nest, or stationary origin was found. Examples are
`-A0203`, `-B0204`, `-C0201`, and `-BA0202`. The leading minus sign is retained.
Negative IDs are valid in `CAPTURES` and `RESIGHTINGS` and forbidden in `NESTS`
and `EGGS`. `NO_NEST` is separate and means no nest/brood association.

The event contract is one row per observed or captured bird. Uncaptured parents
and chicks are `RESIGHTINGS`; captured parents and chicks are `CAPTURES`; later
sightings remain `RESIGHTINGS`, and later recaptures remain `CAPTURES`. Unbanded
birds may use `X-X`. Negative-ID events require both `gps_id` and `gps_point`.
Thus an X-X female, X-X male, and three chicks produce five `RESIGHTINGS` rows.

The photo contract separates handling from hiding-spot evidence. `CAPTURES`
records handling/banding and tent photographs; `chick_tent_photo = 1` and its
photo range refer to the tent photograph. A hiding-spot photograph is a separate
age-C `RESIGHTINGS` row with `rclass = H`, the photographed chick's nonblank
metal `ring`, its GPS pair, and its own photo metadata. Its photo range refers
to the hiding-spot image. An occasion can validly have three chick `CAPTURES`,
three chick H-class `RESIGHTINGS`, and two adult `CAPTURES`.

The operational contract allows negative broods to generate parent work, an
`Untrapped brood` task, and `Hiding spot photos needed` tasks from day 1 through
day 6 after discovery. An age-C H-class `RESIGHTINGS` event resolves the hiding
photo requirement. Negative broods do not generate nest processing, flotation,
clutch-check, nest-check, or notA-closure tasks and have no estimated hatch
date. Parent notes include `band X-X F; band X-X M`, `band X-X F`, and
`band/resight F; band X-X M` as appropriate.

The implemented parent task stream distinguishes `Parent capture` from
`Parent resighting` and retains the existing seven-day and 36-hour timing and
identity rules. The hiding-photo task is resolved only by the linked age-C
H-class resighting when its normalized `ring` is nonblank and not textual `NA`,
not by a capture-row hiding-photo flag. A qualifying H event resolves the task
for the identified chick; a blank or missing ring does not.

For the final PDF map and parent summary, active nests and confirmed hatched
broods remain included, including negative broods. A positive `notA` nest is
retained when historical NESTS evidence shows hatching with `brood_size > 0`;
non-hatched terminal nests may disappear. Negative broods have a blank hatch
date, use the colour assigned during age-C `CAPTURES`, and use the latest
qualifying age-C `CAPTURES`/`RESIGHTINGS` GPS event for location. Positive nests
may fall back to NESTS location when direct chick-event GPS is absent; negative
broods have no such fallback. Location and colour are separate concepts.

The location precedence is latest valid direct chick-event location through the
reference date: an age-C `CAPTURES` or `RESIGHTINGS` event must have a paired,
resolvable GPS key. A later age-C event with missing or unresolvable GPS does
not erase an earlier valid location. The colour label is selected separately
from the first informative single-colour `LL` or `LR` value in qualifying age-C
`CAPTURES`; movement changes location, not the stored label colour.

Status distinctions:

- **Agreed methodology:** the protocol above is the current cross-thread
  biological and operational contract.
- **Local protocol/mock implementation:** the official validator protocol and
  synchronized local mirror report version 1.3.3, and the ignored
  `validator_sandbox/negative_brood_methodology/` fixtures exercise negative-ID,
  GPS-pair, and table-ownership rules without real records or coordinates.
- **Current repository implementation:** the RESIGHTINGS `ring`, negative-
  brood, derived-view, app, PDF, map, and test changes are merged in tracked
  source. `BROODS_LATEST` is the unified
  positive/negative brood source; `TODO_LIST` consumes it for negative parent,
  untrapped-brood, and hiding-photo tasks; the PDF helper and map consume the
  same source for task rows, map inclusion, and parent summary.
- **Focused verification:** Thread 4 reports isolated fake-data/MariaDB and
  focused-test evidence, and the current tests include negative brood summary,
  duplicate-task normalization, sorting, map retention, and leaflet behavior.
  This Thread 1 pass itself remained static and did not rerun tests or render the
  app/PDF.
- **Commit/PR/deployment/live status:** repository source is merged through
  `1617e84`; deployment/recreation in the target database and verification in a
  running Shiny process remain separate operational checks. No database or
  Shiny app was accessed in this documentation refresh.

## Main app architecture

Entry files remain:

- `main/global.R`: packages, database/table/view lists, source-watch mappings,
  map colours, theme dependencies, and Git-version resolution.
- `main/ui.R`: the `bs4Dash` page, sidebar/controlbar, five Overview panels,
  launchers, downloads, data browsers, and nest map.
- `main/server.R`: reference-date state, Overview renders, launcher outputs,
  table/view renders, nest-map polling, and download handlers.

Current visible tabs/capabilities are:

- Downloads
- Intro
- Overview
- GPS
- Enter Data
- Show tables
- Show Views
- Database
- Nest Map

Current download paths are:

- generated to-do PDF;
- offline nest KMZ;
- offline interactive HTML tables;
- external RDS database download;
- server-side SQL dump download.

Current `Show tables` objects are:

- `OBSERVERS`, `CAPTURES`, `NESTS`, `EGGS`, `RESIGHTINGS`,
  `RESIGHTINGS_PUBLIC`, `GPS_POINTS`, `settings`, and `predict_hatching`.

`GPS_TRACKS` exists in DDL but is no longer listed in `dbtabs_show_tables`; whether
that omission is intentional is unresolved.

Current `Show Views` names are:

- `TODO_LIST`
- `AVAILABLE_COMBOS`
- `NESTS_LATEST`
- `CAPTURES_ARCHIVE`
- `EGGS_HATCH_PREDICTION`
- `OVERVIEW`
- `VIEW_1`
- `VIEW_2`

The final two are advertised placeholders with no active definitions in tracked
`DATABASE/views.SQL`.

## Reference-date handling

- Canonical storage is the `settings` row where
  `variable = 'reference_date'`.
- `get_reference_date()` reads that row; `set_reference_date()` uses a parameterized
  insert/upsert.
- `main/server.R` keeps an optimistic local `reactiveVal`, tracks a pending write,
  polls the settings table every five seconds, and rolls back the local value when
  persistence fails.
- The app warns when the reference date differs from the current date in
  `Pacific/Auckland`.
- `main/www/reference_date.js` renders the relative day label and the preferred
  timezone clock in the browser.
- Operational SQL views and app-side plots are reference-date aware. This is an
  operational input, not only a display preference.

## Git commit/version display

`main/global.R` now resolves the displayed commit in this order:

1. deployment environment variables (`FIELDWORKER_GIT_ID`, `GITHUB_SHA`,
   `SOURCE_VERSION`, or `RENDER_GIT_COMMIT`);
2. a local Git ref (`HEAD`, `origin/main`, or `main`) only when that ref matches
   the deployed app files;
3. the remote `origin/main` commit through `git ls-remote` with a short timeout;
4. `unknown` when no source resolves.

The seven-character ID is used in the page title and sidebar and links to the
corresponding `ornitho-logics/NZ_FIELDWORKER` commit. The selected source is also
reported to the startup log. Tests cover environment override and remote-output
parsing, but runtime deployment behavior was not re-tested in this cartography
pass.

## DataEntry architecture

Current app directories:

- `DataEntry/OBSERVERS/`
- `DataEntry/CAPTURES/`
- `DataEntry/NESTS/`
- `DataEntry/EGGS/`
- `DataEntry/RESIGHTINGS/`
- `DataEntry/RESIGHTINGS_PUBLIC/`
- `DataEntry/inspectors/`
- `DataEntry/spatial_objects/`

Repo-visible wrappers are mostly declarative:

- Biological event apps use `ui_append_rows()` / `server_append_rows`.
- `OBSERVERS` uses `ui_edit_table()` / `server_edit_table`.
- `inspectors` and `spatial_objects` use `ui_edit_rcode()` /
  `server_edit_rcode`.
- Biological `global.R` files define table name, group, excluded columns, empty
  rows, defaults, and dropdowns.

Current alignment details:

- `DataEntry/NESTS/global.R` matches the wider `bird_inc` enum.
- `DataEntry/EGGS/global.R` remains aligned with long-format EGGS.
- `DataEntry/CAPTURES/global.R` creates observer and `observer_upload` dropdowns
  but still has no `eggs_handled = c("0", "1")` dropdown.
- CAPTURES remains an outlier because its `global.R` also calls `shinyApp(...)`
  despite separate `ui.R` and `server.R` files.

The real data-grid behavior, database connection, save path, validation execution,
and dropdown helper implementation remain package-side in external `DataEntry`
and database infrastructure.

## Inspectors and validator protocol

Repo-visible central editor:

- `DataEntry/inspectors/global.R`
- `DataEntry/inspectors/ui.R`
- `DataEntry/inspectors/server.R`

Tracked storage definition:

- `DATABASE/support_tables.SQL` table `inspectors` with `table_name`, `inspector`,
  `comments`, and `updated_at`.

There are no current table-specific tracked `inspector.R` files. Live validator
code is DB-stored and loaded/executed through external package behavior.

Current protocol and local paste-ready locations:

- Official external protocol:
  `/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/bdot_db/data/working/bdot_dataentry_validator_protocol.yaml`
- Ignored local protocol mirror:
  `notes/codex_proposals/validator_sandbox/xlsx_short_tag_update/bdot_dataentry_validator_protocol_plot_aligned.yaml`
- Paste-ready two-list exports:
  `notes/codex_proposals/validator_sandbox/inspector_lists_by_table/`

Both protocol copies report version `1.3.3`, generated 2026-09-30. The negative-
brood additions require negative IDs to be valid only in `CAPTURES` and
`RESIGHTINGS`, invalid in `NESTS` and `EGGS`, and paired with both `gps_id` and
`gps_point` checked against `GPS_POINTS`. The first event may be a capture or a
resighting, with one row per individual and repeated X-X values allowed for
distinct unbanded birds. H-class age-C resightings represent hiding-spot photos;
the current `RES_010` hard rule requires a nonblank `ring` for H events, while
the ring remains nullable for other RESIGHTINGS classes and does not replace
the leg-mark fields. Each chick gets its own H row, ring, GPS pair, and photo
metadata. `RESIGHTINGS_PUBLIC` is unaffected.
`CAPTURES` retains the tent-photo flag and does not use a capture-row hiding
photo as a substitute. Current local exports provide `TABLE_hard` and
`TABLE_warning` files for all six biological tables. Mock workbooks/CSV exports
are supporting artifacts, not tracked app code or live validator state.

## Combo-list architecture

`USED_COMBOS_DETAIL` and `AVAILABLE_COMBOS` are now central operational views.

- `USED_COMBOS_DETAIL` combines historic release marks, current release marks,
  and current input marks up to the reference date. It normalizes lower-leg
  colour pairs, including tagged upper-right forms, and flags normalizable marks.
- `AVAILABLE_COMBOS` generates candidate lower-leg pairs from hard-coded site
  rules, removes combinations already represented in `USED_COMBOS_DETAIL`, applies
  exclusions, ranks the remainder, and emits site, mark, LL, and LR.
- The current CR/CX split is explicitly a temporary compatibility gate for the
  deployed PDF query, not a general site classification.
- `main/R/pdf_todo.R::todo_pdf_prepare_team_marks()` selects up to 30 CR marks
  and lays them out as three teams of ten.
- `AVAILABLE_COMBOS` is exposed in `Show Views`; `USED_COMBOS_DETAIL` is not.

The user has reassigned active Thread 6 to combo-list work. This conflicts with
`AGENTS.md`, which still defines Thread 6 as QA/reproducibility reviewer. During
this cartography pass, Thread 6 created
`notes/codex_proposals/THREAD6_COMBO_LIST_PROTOCOL.md` and updated
`notes/codex_logs/THREAD6_PROMPT_LOG.md` to record the active role.

## To-do, parent-status, PDF, and map workflow

`DATABASE/views.SQL::TODO_LIST` is the authoritative task engine. Its final output
currently emits these task classes:

- `Parent capture`
- `Parent resighting`
- `Unprocessed nest`
- `take scrape photos`
- `Re-process nest`
- `Clutch check`
- `nest check`
- `Untrapped brood`
- `Hiding spot photos needed`
- `notA nest-check`

`Untrapped parent` remains an intermediate candidate label in the SQL but is no
longer part of the final union; the final task stream splits parent work into
capture and resighting classes.

The negative-brood branch is separate from ordinary nest processing. It may
produce parent capture/resighting work, `Untrapped brood`, and day-1-through-
flotation, clutch-check, nest-check, or notA-closure tasks, and it has no hatch
estimate. Parent notes include `band X-X F; band X-X M`, `band X-X F`, and
`band/resight F; band X-X M` where applicable.

An H-class hiding-photo event resolves `Hiding spot photos needed` only when it
is linked to the brood, falls within the reference-date/age-C/site conditions,
and has a normalized nonblank, non-`NA` `RESIGHTINGS.ring`. The ring identifies
the photographed chick and is supplemental to the UL/LL/UR/LR fields. A
CAPTURES tent-photo row, including `chick_tent_photo = 1`, does not substitute
for the separate RESIGHTINGS H event.

Current parent logic combines captures and resightings by nest and sex, including:

- confirmed unbanded status;
- uncertain identity/status;
- geolocator status;
- single-colour recruits;
- mobile-mistnet captures needing later at-nest association evidence;
- seven-day clutch-completion capture eligibility;
- 36-hour spacing after the previous adult-parent capture, evaluated against
  08:00 on the reference date.

The clutch workflow now distinguishes initial processing, re-processing after a
clutch increase, and a dedicated one/two-egg `Clutch check`. Final rows carry
priority, overdue information, hatch estimate, latest visit/state, parent marks,
and location fields.

Current PDF path:

1. `main/server.R` download handler `todo_pdf`.
2. `main/R/pdf_todo.R::todo_pdf_save()` queries/prepares `TODO_LIST`,
   `BROODS_LATEST`, `AVAILABLE_COMBOS`, selected chick captures, and `study_area`.
3. `main/R/pdf_todo_map.R::todo_pdf_map_save()` builds the map.
4. `main/R/pdf_todo.R::todo_pdf_qmd()` fills
   `main/templates/todo_pdf.qmd`.
5. Quarto renders a Typst PDF.

The generated PDF contains task tables, a note key, team marks, a task map, and a
compact nest summary. The map:

- evaluates stored `study_area` content into named plot polygons;
- transforms geometry to NZTM / EPSG:2193;
- prepares Plot A/B/C panels;
- distinguishes nest-check versus other work and capture versus resighting;
- can label nests with chick-band colours;
- requests ArcGIS World Imagery and falls back to a map without imagery when the
  request fails;
- includes a hard-coded gate landmark in tracked source.

The separate live map still uses `NESTS_LATEST` through
`main/R/leaflet_nest_latest.R`. The separate KMZ and HTML exports remain in
`main/R/kmz_nest_latest.R` and `main/R/html_tables.R`.

## Overview architecture

The Overview tab now has five full-width collapsible panels:

1. Seasonal progression in nest discovery.
2. Seasonal progression in geolocator deployments.
3. Seasonal progression in unique band combinations encountered by capture or
   resighting.
4. Seasonal progression in estimated lay date.
5. Current manipulation quotas.

Repo-visible flow:

- Layout/output IDs: `main/ui.R`.
- Reactive bindings and one shared date-limit reactive: `main/server.R`.
- Queries and plotting: `main/R/ggplot_overview.R`.
- Wiring/behavior tests: `tests/testthat/test-app-wiring.R` and
  `tests/testthat/test-main-server.R`.

Current plotting behavior:

- Nest discovery, geolocator deployments, and unique combinations are cumulative
  step/ribbon plots.
- Geolocator and unique-combination plots split known sex into Female and Male;
  the combo plot prefers a single historic genetic sex when available, otherwise
  a single consistent observed sex.
- Lay date remains a histogram derived from `EGGS_HATCH_PREDICTION` and CR nest
  membership.
- Quotas remain four polar plots for floated eggs, geolocators, non-geolocator
  adult sampling captures, and processed chicks.
- `overview_date_limits()` finds the earliest relevant CR nest/capture/resighting/
  inferred-lay event and uses the active reference date as the common endpoint.
- Cumulative panels use explicit horizontal/vertical ribbon steps to avoid
  diagonal interpolation and show total annotations at the upper-left.
- Smartphone-oriented formatting uses weekly date breaks, wrapped axis/quota
  labels, concise annotations, full-width panels, and viewport-relative heights.
  There is no dedicated Overview CSS breakpoint.

The SQL `OVERVIEW` view remains a separate tabular metric view under `Show Views`;
the five app-side panels do not consume it directly.

## GPS and map architecture

The repo-visible `gpxui/` wrapper remains minimal:

- `gpxui/global.R` loads the external package, sets the upload size, declares
  `GPS_IDS <- 1:20`, reads only the config-path environment variable name, and
  sets the group.
- `gpxui/ui.R` calls `gpx_ui(gps_ids = GPS_IDS)`.
- `gpxui/server.R` calls `gpx_server()`.

Upload parsing, visualization, export, and database behavior are external-package
responsibilities. Canonical database linkage remains `gps_id + gps_point` into
`GPS_POINTS`; track rows use `gps_id`, `seg_id`, and `seg_point_id`.

The main live nest map uses street/satellite basemaps, plot overlays from
`spatial_objects`, nest-state filtering, responsive marker/label sizing, and
browser geolocation/follow controls. `main/www/live_nest_leaflet.js` owns the
mobile sizing and device-location controls.

## Tests and app wiring

Current test files:

- `tests/testthat/helper-apps.R`
- `tests/testthat/test-app-wiring.R`
- `tests/testthat/test-dataentry-servers.R`
- `tests/testthat/test-leaflet-plots.R`
- `tests/testthat/test-main-server.R`
- `tests/testthat/test-system-utils.R`
- `tests/testthat/test-hiding-spot-ring.R` (new local focused regression test;
  currently untracked)

Static coverage includes:

- all eight DataEntry wrapper shapes and mocked save flows;
- main UI, Git-ID environment override/parser, five Overview outputs, and SQL
  `OVERVIEW` presence;
- Overview reference-date alignment, cumulative-ribbon geometry, annotations,
  and legend placement;
- mapped/unmapped view polling and faulty-view error handling;
- plot WKT preparation and live-leaflet layer behavior;
- gpxui wrapper/package factory signatures.
- hiding-photo task resolution for nonblank H-event rings, including blank,
  whitespace, SQL `NULL`, textual `NA`, non-H, separate-chick, and pre-ring
  cases (from the new focused test; not rerun in this pass).

Known test/status discrepancy:

- `gpxui/global.R` declares `GPS_IDS <- 1:20`, while
  `tests/testthat/test-app-wiring.R` still expects `1:15`.
- `tests/test-results.csv` says `206` passed and `0` failed, but the file itself
  has not been updated since a July commit while tests have changed since then.
  The sidebar badge is therefore a static historical result, not proof that the
  current September commit passed 206 tests.
- No tests were run for this cartography task.

## Package-side versus repo-visible behavior

Directly visible in this repository:

- app entry files and UI wiring;
- source/support DDL, SQL functions, and view definitions;
- DataEntry wrapper configuration;
- Overview queries/plots;
- to-do PDF/map/KMZ/offline HTML generation;
- mocked wiring and selected behavior tests.

Mostly hidden in external packages or runtime infrastructure:

- `db_get()`, `db_con()`, and connection setup;
- `ui_append_rows()`, `server_append_rows`, `ui_edit_table()`,
  `server_edit_table`, `ui_edit_rcode()`, and `server_edit_rcode`;
- `prepare_for_dropdown()` and `inspector_loader()`;
- live validator loading, severity, and save-blocking behavior;
- GPX parsing, preview, export, and write behavior.

Static repo inspection can map interfaces and contracts, but it cannot prove
runtime package behavior or current database contents.

## Previous findings that remain valid

- `DATABASE/` is the tracked SQL source of truth.
- The dated SQL/RDS snapshots are local test/alignment artifacts, not schema truth.
- Validation is centrally DB-stored and edited through `DataEntry/inspectors/`.
- Table-specific `DataEntry/*/inspector.R` files are obsolete.
- `EGGS` is long format; `observer_upload` is CAPTURES-only; `eggs_handled` is a
  CAPTURES field.
- `spatial_objects` is an active map/PDF dependency.
- `NESTS_LATEST`, `EGGS_HATCH_PREDICTION`, and `TODO_LIST` remain operationally
  central.
- The main app can write `settings.reference_date` and produce a database dump;
  it is not globally read-only.
- Core data-entry and GPS mechanics remain largely package-side.
- Negative-brood table ownership, event-entry, photo, task, and map/summary
  rules are now the agreed cross-thread methodology; implementation status must
  still be distinguished from live deployment.

## Previous findings that are now obsolete

- The primary checked-out branch is a focused PR branch based on current
  `origin/main`, not the former negative-brood documentation branch.
- The Overview is not four or five panels; it has seven, including unique band
  combinations, tagged histories, and a hatching forecast.
- The current parent task output is not represented accurately by the old
  `Untrapped parent` list; final rows are split into `Parent capture` and
  `Parent resighting` and now include `Clutch check`.
- `main/R/pdf_todo.R` is no longer the entire PDF implementation; map generation
  is split into `main/R/pdf_todo_map.R`.
- The to-do PDF is no longer tables-only.
- The July view inventory is obsolete because it omitted the combo views.
- `main/R/data_overview.R` and older `main/R/data_*.R` helper paths are not current.
- The protocol is not version 1.0.5; current local/external copies report 1.3.3.
- The old example dump ending `7230743.sql` is not present; the newest visible
  snapshot ends `7311213.sql`.
- There is no current app-level `ver <- "v 4.2.3"` variable in `main/global.R`.

## Current discrepancies and risks

1. `AGENTS.md` says it belongs only on `cass_prep`, but the current committed
   base also contains it; branch governance still needs collaborator agreement.
2. `AGENTS.md` assigns Thread 6 to QA/reproducibility; the user says active Thread
   6 is now the combo-list agent.
3. Repository merge state does not establish live database deployment; derived
   views still need object-specific deployment verification.
4. `NESTS_LATEST` depends on `RESIGHTINGS`, but its source-watch mapping omits it.
5. `CAPTURES_ARCHIVE` depends on historic `BADOatNZ.SEX`, but its mapping names
   only historic CAPTURES.
6. `AVAILABLE_COMBOS` is browser-visible but has no source-watch mapping. Unmapped
   views receive a stable polling token and do not refresh from source checks.
7. `VIEW_1` and `VIEW_2` are browser-visible names without tracked DDL.
8. `GPS_TRACKS` exists but is absent from the current raw-table browser list.
9. CAPTURES DDL includes `eggs_handled`, but its DataEntry wrapper has no binary
   dropdown for it.
10. Both `FM` and `MF` are accepted for `bird_inc`; downstream code may treat them
    as separate values unless explicitly normalized.
11. The to-do map evaluates DB-stored R text for polygons, contains a hard-coded
    landmark, and makes an external imagery request. Those are runtime/security/
    availability boundaries that tests do not currently cover.
12. `main/www/help/intro.html` describes one Overview summary plot and links to an
    older repository organization, so help text lags current app behavior.
13. The sidebar test badge reads a static CSV at UI source time and may lag the
    latest test run.
14. `TODO_LIST` remains a large MariaDB view. Static CTE-limit and rule tests
    reduce regression risk but do not replace an isolated execution-plan and
    deployment benchmark against the target server.

## Current handoffs for Threads 2-6

### Thread 2: schema/database architecture

Start with:

- `notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md` (tracked schema handoff
  refreshed 2026-10-06)
- `DATABASE/main_tables.SQL`
- `DATABASE/support_tables.SQL`
- `DATABASE/functions.SQL`
- `DATABASE/predict_hatching.SQL`
- `DATABASE/views.SQL`

Thread 2 should own DDL/view dependencies, source-watch alignment, schema/app
field alignment, negative-ID table contracts, indexes, the nullable
`RESIGHTINGS.ring` field, and the implemented `BROODS_LATEST` architecture. The
source is approved locally; deployment is not yet established.

### Thread 3 / 3.1: validators and mock workflows

Start with:

- `notes/codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md`
- `notes/codex_proposals/validator_sandbox/THREAD3_CAPTURES_MOCK_VALIDATOR_PLAN.md`
- the official external protocol path listed above;
- `notes/codex_proposals/validator_sandbox/inspector_lists_by_table/`.

Thread 3.1 should treat protocol version 1.3.3 and the negative-brood mock
fixtures as current local validation context. It owns inspector lists, connected
mock validation, the `RES_010` H-class `RESIGHTINGS.ring` rule, and the
distinction between save-time validation, post-save QA, and mock-generation-only
rules. The protocol and local inspector drafts are aligned; live inspector rows
still require separate deployment verification.

### Thread 4: task engine, PDF, and maps

Start with the refreshed current-state handoff and then verify against current
code:

- `notes/codex_proposals/THREAD4_TODO_MAP_LIST_DEBUG_PLAN.md` (negative-brood
  implementation/deployment review refreshed 2026-09-27)
- `DATABASE/views.SQL`
- `main/R/pdf_todo.R`
- `main/R/pdf_todo_map.R`
- `main/templates/todo_pdf.qmd`
- `main/R/leaflet_nest_latest.R`
- `main/R/kmz_nest_latest.R`
- `notes/codex_logs/THREAD4_PROMPT_LOG.md` for historical prompt context.

Thread 4 should treat a linked age-C H-class `RESIGHTINGS` event with a
normalized nonblank, non-`NA` `ring` as the only hiding-photo completion
evidence; CAPTURES tent-photo metadata remains a separate event.

### Thread 5: Overview dashboard

Start with:

- `notes/codex_proposals/THREAD5_OVERVIEW_DASHBOARD_PLAN.md`
- `main/R/ggplot_overview.R`
- `main/ui.R`
- `main/server.R`
- `tests/testthat/test-app-wiring.R`
- `tests/testthat/test-main-server.R`
- `notes/codex_logs/THREAD5_PROMPT_LOG.md`
- `notes/codex_proposals/THREAD5_OVERVIEW_CUMULATIVE_RDS_PREVIEW.R`
- `notes/codex_proposals/run_fieldworker_full_app_from_latest_sql_dump.R`.

The preview scripts are ignored local tooling and are not source of truth over
tracked app code.

### Thread 6: combo-list agent

Treat the user’s current assignment and Thread 6 memo as authoritative over stale
AGENTS role text. Start with:

- `notes/codex_proposals/THREAD6_COMBO_LIST_PROTOCOL.md`
- `notes/codex_logs/THREAD6_PROMPT_LOG.md`
- the `USED_COMBOS_DETAIL` and `AVAILABLE_COMBOS` sections of
  `DATABASE/views.SQL`;
- `DATABASE/functions.SQL`;
- `main/R/pdf_todo.R::todo_pdf_prepare_team_marks()`;
- `CAPTURES` input/output mark fields in `DATABASE/main_tables.SQL`;
- `notes/codex_proposals/validator_sandbox/xlsx_short_tag_update/debug_captures_combo_pool.R`
  only as ignored mock-workflow context.

## Recommended next inspections

1. Preserve the approved implementation while preparing a focused commit that
   includes only the intended SQL, R, tests, and authorized documentation.
2. Before committing, review `git status --short`,
   `git diff --check`, and `git diff --name-status origin/main...HEAD` (or the
   corresponding branch comparison) so `AGENTS.md` and unrelated files are not
   carried into the collaborator-facing PR unintentionally.
3. Build the clean PR branch from `origin/main`, cherry-pick only the intended
   implementation commit(s), and remove `AGENTS.md` from that PR branch if it is
   present, following the workflow in `AGENTS.md`.
4. After review/merge, deploy the object-specific SQL in dependency order,
   including `BROODS_LATEST` and `TODO_LIST`, then verify the live view
   definitions and inspector rows through an approved read-only/deployment
   check. Do not infer live support from local files.
5. Run the focused no-database tests and render a safe mock PDF/map before and
   after deployment; then perform a narrow field-season smoke check without
   exposing confidential records or coordinates.
6. Thread 5 should reconcile its Overview handoff with the current source, and
   Thread 6 should maintain the combo allocation contract and its separate role
   documentation.
7. Reconcile view-source mappings, placeholder views, gpxui test expectations,
   DataEntry dropdowns, help text, and the static test badge in their owning
   threads before treating them as current guarantees.
