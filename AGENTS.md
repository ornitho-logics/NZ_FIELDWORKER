# AGENTS.md — NZ_FIELDWORKER / Banded Dotterel Fieldworker Database

## Tracking and authority of this file

This `AGENTS.md` file documents Luke's Codex workflow and the shared operating
rules for this project. It is intentionally tracked in Git and is intended to
reach `main` through normal human-reviewed pull requests.

`AGENTS.md` must not be listed in `.gitignore`, silently removed from a PR, or
treated as private branch metadata. Changes to it still require an explicit
user request, must be reviewed like source changes, and must not weaken the
confidentiality, database-safety, or human-control rules below.

The collaborator-controlled `main` branch remains authoritative. Codex may
prepare and push a reviewed PR branch when explicitly requested, but the user
retains control of PR creation, merge, deployment, and live database changes.

## Project identity

This repository is `ornitho-logics/NZ_FIELDWORKER`, a modular R/Shiny application for organizing fieldwork.

The project is being adapted for the 2026 Banded Dotterel / Pohowera field season in New Zealand.

The working local repository is:

```text
/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER
```

The target 2026 field-season database is:

```text
FIELD_2026_BADOatNZ
```

The historic database is:

```text
BADOatNZ
```

The project currently includes:

* `main/`: main Shiny dashboard, including Overview, GPS, data-entry launchers, database browser, view-data outputs, nest maps, live nest map, to-do list, hatching estimates, local test status, PWA/offline assets, and database-copy download paths;
* `DataEntry/`: table-specific data-entry apps using the external `DataEntry` package;
* `DataEntry/inspectors/`: central inspector/validator management app for DB-stored validators;
* `DataEntry/spatial_objects/`: support/admin app for spatial object records used to display vector shapes in app maps and to support plot-linked mock-data generation;
* `gpxui/`: GPS waypoint/track upload interface using the external `gpxui` package;
* `DATABASE/`: current SQL source-of-truth folder for base tables, support tables, views, functions, reset logic, hatching prediction support, and the latest safe local mock-data dump used for local tests;
* `tests/testthat/`: repo-visible tests for app wiring and server/data-entry behavior;
* `notes/codex_proposals/`: six tracked Thread 1-6 handoffs and tracked reviewed
  inspector lists, alongside ignored local proposals, previews, mock artifacts,
  and generated outputs;
* `notes/codex_logs/`: ignored local logs if used;
* `tmp/codex/`: ignored local scratch area if used.

The immediate development goals are:

1. prepare and refine `FIELD_2026_BADOatNZ` for the 2026 field season;
2. optimize fieldworker-facing data-entry validation through the central DB-stored `inspectors` system;
3. maintain SQL-backed FIELDWORKER to-do/list/map/PDF outputs inside the existing app interface;
4. maintain and refine the current seven-panel Overview dashboard;
5. preserve full human control over all code and database changes;
6. avoid leakage of confidential raw data, credentials, GPS locations, or field records.

## Absolute human-control rule

Codex must not directly modify tracked source files, database files, raw data, configuration files, or project structure unless the user explicitly requests that exact edit in the current task.

By default, Codex may:

* inspect the repository;
* run read-only searches;
* run static code inspection;
* run code/tests locally only when the user explicitly allows it and only when those tests cannot write to the database;
* propose full replacement functions;
* propose minimal diffs;
* propose SQL snippets;
* write implementation plans;
* write review notes;
* create scratch/proposal files only inside ignored locations, except when the
  user explicitly requests a reviewed documentation artifact to be tracked.

By default, Codex must not:

* edit existing tracked files;
* commit changes;
* push to GitHub;
* merge or rebase;
* modify database schema;
* connect to the real database;
* inspect confidential raw data;
* inspect credentials;
* write to the database;
* run Shiny apps if doing so could write to the database;
* write real data into tests, logs, examples, markdown files, or prompt records;
* create non-ignored files without explicit approval.

The user retains final approval. Codex may apply, commit, and push accepted
changes only when explicitly requested; PR merge, production deployment, and
live database changes remain human-controlled unless separately authorized.

## Scratch-file rule

Codex may create scratch files only in ignored directories such as:

```text
notes/codex_proposals/
notes/codex_logs/
tmp/codex/
```

The following reviewed documents are tracked and are not scratch locations:

```text
notes/codex_proposals/THREAD1_REPOSITORY_MAP.md
notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md
notes/codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md
notes/codex_proposals/THREAD4_TODO_MAP_LIST_DEBUG_PLAN.md
notes/codex_proposals/THREAD5_OVERVIEW_DASHBOARD_PLAN.md
notes/codex_proposals/THREAD6_COMBO_LIST_PROTOCOL.md
notes/codex_proposals/validator_sandbox/inspector_lists_by_table/
```

Before creating any other scratch/proposal file, Codex must confirm that the
target path is ignored.

If the directory is not ignored, Codex must not create the file and should tell the user which ignore rule is missing.

Never create scratch files elsewhere without explicit permission.

## Confidentiality and data safety

The full field database is confidential. Codex must never access, query, export, summarize, or reproduce the real database unless the user explicitly approves a narrow, safe database-inspection task.

The codebase itself is open source. The raw database is not.

Codex may use only:

* fake data;
* hand-written mock data;
* tiny user-provided snippets that the user has explicitly cleared for use;
* structurally realistic examples with invented values;
* column names and schema descriptions provided by the user;
* public documentation and public package source code;
* repo-visible SQL schema and view definitions.

Codex must never include in prompts, logs, tests, examples, comments, or documentation:

* database credentials;
* server connection strings;
* usernames;
* passwords;
* real rows from the confidential database;
* unredacted sensitive site data;
* raw GPS locations from confidential data;
* exact rare-species locations unless the user explicitly provides them for that purpose.

If Codex sees credentials, it must not repeat them. It should advise the user to keep credentials out of prompts, logs, committed files, and screenshots.

## Database connection safety

The FIELDWORKER app and external packages may use local configuration files for database access.

The user’s local R environment may contain paths such as:

```r
getOption("dbo.my.cnf")
Sys.getenv("DATAENTRY_CNF")
cnf_path
```

Codex may discuss how these variables are used, but must never request or reproduce the contents of the config file.

If package or app testing requires a config path, Codex should tell the user to set the path locally without pasting credentials.

A safe local pattern is:

```r
cnf_path <- path.expand(getOption("dbo.my.cnf"))
Sys.setenv(DATAENTRY_CNF = cnf_path)
```

Do not write database config paths into tracked repository files unless explicitly approved.

No thread should assume the live database matches the local SQL source files unless the user explicitly approves a narrow, read-only inspection.

## Local artifacts and mock-data files

Some local artifacts are safe for threads to inspect when they are useful for the current task.

This may include:

* `DATABASE/FIELD_2026_BADOatNZ.rds` when a thread needs a safe local mock-data dump for tests or read-only workflow tracing;
* `.Rproj.user/` when a narrow repo-behavior or local-environment task genuinely depends on it;
* `tests/test-results.csv` when a thread only needs local test-status context.

These files are not the source of truth over the repository structure or SQL logic. Prefer current tracked source files first.

Codex must still avoid:

* local `.cnf` files;
* credentials or config artifacts;
* confidential raw data;
* real GPS coordinate exports;
* generated files that might contain real field records.

## Git and logging policy

The user wants accepted code changes to be tracked through Git branches, commits, pushes, and pull requests.

The collaborator should retain full control over `main`.

Codex must not commit, push, merge, rebase, or open pull requests unless explicitly instructed.

Prompt and response logging is useful, but risky. By default:

* full prompts and full Codex responses should remain local and ignored;
* only sanitized summaries should be considered for tracked documentation;
* sanitized logs must omit credentials, real data, real database snippets, confidential GPS locations, and sensitive site details.

Preferred pattern:

```text
notes/codex_logs/        # ignored full logs
notes/codex_proposals/   # tracked handoffs plus ignored working artifacts
tmp/codex/               # ignored scratch files
```

Before any commit or push, Codex must check:

```bash
git status --short
git diff --name-status origin/main...HEAD
```

## Pull-request workflow

Do not develop directly on `main`. Start collaborator-facing work from the
latest `origin/main`, preserve only the intended edits, and use a `codex/`
topic branch unless the user requests a different name.

Preferred workflow:

```bash
git fetch origin
git switch -c codex/<topic> origin/main
# apply or cherry-pick only the intended changes
git diff --check
git diff --name-status origin/main...HEAD
```

Before pushing, fetch again and confirm that `origin/main` is an ancestor of
the branch or otherwise reconcile new upstream commits without discarding local
work. Inspect the exact file list, confirm that raw logs/data/generated files
are absent, run approved safe checks, and then push:

```bash
git fetch origin
git merge-base --is-ancestor origin/main HEAD
git diff --name-status origin/main...HEAD
git push -u origin codex/<topic>
```

`AGENTS.md` and the six reviewed Thread handoffs are allowed in a PR when their
update is intentional. Full prompt logs, confidential data, credentials,
database dumps, generated previews, and unrelated local artifacts are not.

## Expected response format for code, schema, validator, or app work

For every substantive coding, schema, validator, map, to-do, dashboard, or export task, Codex should respond with:

1. **What I inspected**

   * files, functions, scripts, SQL sections, docs, or tests reviewed;

2. **What currently seems to happen**

   * a plain-language summary of current logic;

3. **Proposed change**

   * full replacement function, minimal diff, SQL snippet, mock-data prototype, or implementation plan as appropriate;

4. **Where to apply it**

   * exact file path, function, SQL object, inspector row, app module, or table/view;

5. **Why this change is needed**

   * including biological, data-entry, fieldwork, performance, or usability reasoning where relevant;

6. **What this might break**

   * side effects, backwards compatibility issues, package assumptions, validator consequences, schema impacts, performance issues, or UI impacts;

7. **Rollback**

   * how to undo the change manually;

8. **How to check it**

   * mock-data example, local read-only test, app workflow, SQL syntax check, validator paste test, PDF check, dashboard check, or manual verification checklist.

Codex should never claim a task is complete if it has not inspected the relevant files or if important assumptions remain unresolved.

## Coding style

Codex should first study the style of the relevant script and then match it closely.

Prefer:

* clear, explicit R code;
* full replacement functions when practical;
* small, well-scoped changes;
* comments that explain non-obvious logic;
* existing packages already used in the codebase;
* simple helper functions over large monolithic blocks;
* fieldworker-facing messages written in plain language;
* mock examples that do not use real data.

Avoid:

* adding new dependencies unless necessary;
* rewriting code into a different style for aesthetic reasons;
* broad refactors unless requested;
* introducing tidyverse, dbplyr, sf, terra, raster, leaflet extensions, or other packages unless those packages are already used nearby or clearly justified;
* silently changing biological assumptions;
* using real database snippets in examples.

If a new package would simplify a solution, Codex should first explain why and ask before proposing package-dependent code.

## Database field naming

Use the current database field names from the SQL files in `DATABASE/` as the source of truth.

The project generally uses snake_case database field names.

Important canonical names include:

```text
nest_id
gps_id
gps_point
cam_id
field_sex
capture_status
time_visit
nest_state
hatch_state
bird_inc
float_angle
float_surface
float_location
ring
eggs_handled
falcon_upload
observer_upload
nov
```

`observer_upload` is currently a CAPTURES-only field and should not be assumed to exist in other biological tables such as `EGGS`, `NESTS`, or `RESIGHTINGS`.

Avoid introducing camelCase database names such as:

```text
nestID
gpsID
cameraID
tagID
```

The term “waypoint” may be used in prose when referring generically to a GPS waypoint, but the database column is `gps_point`.

## Negative-brood and hiding-photo methodology

A negative `nest_id` identifies a brood of unknown origin: no eggs, nest, or
stationary origin was found. Negative IDs are valid in `CAPTURES` and
`RESIGHTINGS` only; they are invalid in `NESTS` and `EGGS`. `NO_NEST` is a
separate sentinel for an event unrelated to any nest or brood. The leading
minus sign must be retained.

For a hiding-spot photograph, enter each photographed chick as its own age-C
`RESIGHTINGS` event with:

* the relevant positive or negative `nest_id` when the brood/nest is linked;
* `rclass = "H"`;
* the chick's alphanumeric metal-ring code in nullable `ring`;
* both `gps_id` and `gps_point`; and
* the appropriate `photo_start`/`photo_end` metadata.

The `ring` value identifies the photographed chick. It supplements and does
not replace `UL`, `LL`, `UR`, or `LR`. A single occasion may therefore have
separate CAPTURES rows for handling/banding and separate H-class RESIGHTINGS
rows for hiding-spot photographs. CAPTURES `chick_tent_photo = 1` and its
photo range refer to the tent photograph, not the hiding-spot photograph.

Each reference-date-qualified, linked age-C H-class RESIGHTINGS event with a
nonblank normalized `ring` contributes one photographed-chick identity. SQL
NULL, blank, whitespace-only, and textual `NA` ring values do not count. The
task closes only when the number of distinct qualifying H-photo rings reaches
the number of distinct age-C CAPTURES rings for that positive nest or negative
brood; duplicate rows for one ring count once, and a brood with no captured
chick-ring evidence remains open during the task window. This ring requirement
does not apply to non-H RESIGHTINGS rows. `RESIGHTINGS_PUBLIC` is unaffected
and does not receive this field.

`RESIGHTINGS_H_BROOD_ASSOCIATIONS` preserves direct links and may derive a
brood/nest association from deterministic prior chick-ring evidence or an
unambiguous same-occasion adult/family association. Ambiguous rows remain
unresolved, and the raw `RESIGHTINGS.nest_id` is not rewritten.

This schema, validator, and task behavior is merged in tracked repository source.
That is not evidence that the target database, live inspectors, or deployed
Shiny process has been updated.

## Database backend

Do not assume SQLite.

The FIELDWORKER app is designed around a MySQL/MariaDB-style backend accessed from R through the `DataEntry`, `dbo`, and related database infrastructure.

The target 2026 database is:

```text
FIELD_2026_BADOatNZ
```

The historic database is:

```text
BADOatNZ
```

Current or historic field-season databases may include:

```text
FIELD_2024_BADOatNZ
FIELD_2025_BADOatNZ
```

Codex must not connect to any real database unless the user explicitly approves that specific task.

Codex may inspect local SQL files and propose schema changes, but must always ask before proposing database schema changes in detail.

Schema-change proposals should be written in plain language first, then SQL.

## Current SQL source-of-truth

The schema is now split across the `DATABASE/` directory.

Treat the `DATABASE/` folder as a whole as important for the structure of the data used in the app.

Important files include:

```text
DATABASE/main_tables.SQL
DATABASE/support_tables.SQL
DATABASE/views.SQL
DATABASE/functions.SQL
DATABASE/predict_hatching.SQL
DATABASE/_reset.SQL
```

Use these files as follows:

* `main_tables.SQL`: DDL for the core database tables;
* `views.SQL`: DDL for the views built from those tables;
* `support_tables.SQL`: DDL for support and admin tables used by the app;
* `functions.SQL`: SQL helper functions required by views or downstream logic;
* `predict_hatching.SQL`: DDL and seed data for the stable support table `predict_hatching`;
* `_reset.SQL`: local reset/rebuild workflow file.

Current base tables, support tables, views, and SQL functions should be checked from these files, not from older `Admin/db_structure.SQL` references.

Much of the app depends on the SQL in `views.SQL`, so those views should be treated as part of the active schema layer, not as optional extras.

Important current schema-layer objects include, but are not limited to:

```text
OBSERVERS
CAPTURES
EGGS
NESTS
RESIGHTINGS
RESIGHTINGS_PUBLIC
GPS_POINTS
GPS_TRACKS
inspectors
artifacts
settings
spatial_objects
predict_hatching
CAPTURES_active
CAPTURES_ARCHIVE
USED_COMBOS_DETAIL
AVAILABLE_COMBOS
NESTS_LATEST
RESIGHTINGS_H_BROOD_ASSOCIATIONS
BROODS_LATEST
EGGS_HATCH_PREDICTION
GEO_ROLLOUT_PHENOLOGY
TODO_LIST
VIEW_1
OVERVIEW
```

SQL functions, such as `format_mark`, may be required by views and should be reviewed before changing dependent schema or view logic.

Historical compatibility views such as `CAPTURES_ARCHIVE` are part of schema-review scope whenever they affect how the current app uses older data.

## Current repository structure

### `main/`

The main app is a multi-tab fieldwork dashboard.

Current functionality may include:

* start page;
* GPS help/links;
* data-entry launchers;
* database viewer;
* view-data tabs;
* nest map;
* live nest map;
* to-do list;
* overview dashboard;
* hatching estimates;
* local test-status badge;
* database-copy download path;
* PWA/offline assets.

Important files include:

```text
main/global.R
main/ui.R
main/server.R
main/R/*.R
main/templates/
main/www/help/*.html
main/www/*.js
main/www/style.css
```

Current `main/R/` helpers should be inspected by filename and function, rather than relying on older uppercase naming patterns.

Examples of current helper files may include:

```text
main/R/ggplot_overview.R
main/R/pdf_todo.R
main/R/pdf_todo_map.R
main/R/leaflet_nest_latest.R
main/R/kmz_nest_latest.R
main/R/html_tables.R
main/R/system_utils.R
main/R/system_utils_app.R
```

Do not assume older helper names or pre-merge path conventions still exist unless confirmed in the current branch.

### Database-copy downloads

The RDS download intentionally exports every base table plus the required
`CAPTURES_ARCHIVE` compatibility view. It excludes other derived views to keep
the web request bounded and fails clearly if `CAPTURES_ARCHIVE` cannot be read.

The SQL download uses `mariadb-dump` when available and falls back to
`mysqldump`. It uses `--force` so an invalid derived view does not discard an
otherwise complete base-table backup, but accepts the file only when the dump
completion marker is present. Warnings about derived views must still be
reported and investigated; they are not proof that the resulting view DDL is
usable.

### `DataEntry/`

Each table-specific data-entry module is mostly declarative and package-driven.

Current patterns include:

```r
ui_append_rows(table_name = ...)
server_append_rows
ui_edit_table(table_name = ...)
server_edit_table
ui_edit_inspectors(table_name = ...)
server_edit_inspectors
server_edit_rcode
```

Each table-specific `global.R` usually defines objects such as:

```text
table_name
group
exclude_columns
n_empty_lines
prefilled
dropdowns
```

The actual UI/server mechanics are mostly package-side in the external `DataEntry` package.

### `DataEntry/inspectors/`

This is the central validator/inspector management app.

The old table-specific files such as:

```text
DataEntry/CAPTURES/inspector.R
DataEntry/EGGS/inspector.R
DataEntry/NESTS/inspector.R
DataEntry/OBSERVERS/inspector.R
DataEntry/RESIGHTINGS/inspector.R
DataEntry/RESIGHTINGS_PUBLIC/inspector.R
```

are obsolete.

Validation code is stored in the database table:

```text
inspectors
```

and edited through the central `DataEntry/inspectors/` app.

### `DataEntry/spatial_objects/`

`DataEntry/spatial_objects/` is now a first-class support/admin module for managing spatial object records.

It should be treated as part of the DB-facing app surface.

Its records are used to visualize vector shapes in app maps and, in the case of plot polygons, to support mock-data generation workflows where mock `nest_id` naming is aligned to plot names.

### `gpxui/`

The GPS upload interface remains a wrapper around the external `gpxui` package.

Do not assume older repo-visible `FIELD_2025_BADOatNZ` / `nest_locations` concerns still apply unless the current code shows that they do.

## Database tables and support objects

### OBSERVERS

Current purpose: observer metadata and local device/camera associations.

Use the current SQL in `DATABASE/main_tables.SQL` as the source of truth.

Known important fields include:

```text
name
observer
start
stop
gps_id
cam_id
nznbbs_number
```

The `observer` field is the natural link to many other tables.

### CAPTURES

`CAPTURES` stores all in-hand bird captures and recaptures.

This includes:

* adults;
* hatchlings/chicks;
* juveniles;
* recaptures from current or previous seasons;
* geolocator deployments and retrievals;
* morphometrics;
* samples;
* photos;
* parent/nest associations where applicable.

Important relational and identity fields include:

```text
ring
UL
LL
UR
LR
tag_id
tag_action
tag_type
tag_extras
nest_id
site
species
date
gps_id
gps_point
```

Additional current CAPTURES-specific fields include:

```text
eggs_handled
observer_upload
```

`eggs_handled` is a new CAPTURES field.

`observer_upload` should exist only in `CAPTURES`, not in `EGGS` or other field tables, unless the SQL source of truth is explicitly changed in future.

Do not rename these fields without checking dependent app code, views, validators, tests, and downstream workflows.

### EGGS

`EGGS` is currently long format: one row per egg.

Use current SQL as the source of truth.

Known important fields include:

```text
species
observer
date
time_visit
nest_id
egg_id
float_angle
float_surface
float_location
cam_id
photo_start
photo_end
harddrive_id
comments
nov
pk
```

Older wide-format field names such as `float_angle_1`, `float_surface_1`, and `float_location_1` should be treated as stale unless encountered in current code that still needs cleanup.

### NESTS

`NESTS` stores nest observations and nest-check records.

Known important fields include:

```text
species
site
date
time_visit
observer
nest_id
nest_state
hatch_state
bird_inc
gps_id
gps_point
clutch_size
brood_size
comments
nov
pk
```

The `nest_id` is unique within a season/site context, not necessarily globally across all years.

Coordinates should generally be obtained by linking `NESTS` to `GPS_POINTS` using `gps_id` and `gps_point`.

### RESIGHTINGS

`RESIGHTINGS` stores opportunistic and targeted sightings of banded birds.

The nullable `ring varchar(50)` field stores the alphanumeric metal-ring code
of the resighted individual. It is mandatory for age-C `rclass = "H"`
hiding-spot-photo events, where it identifies the photographed chick. It does
not replace the `UL`, `LL`, `UR`, or `LR` observation fields. Each photographed
chick gets its own H-class row, ring, GPS pair, and photo metadata. The separate
`RESIGHTINGS_PUBLIC` table is unaffected.

Known important fields include:

```text
species
observer
gps_id
gps_point
date
site
rclass
UL
LL
UR
LR
ring
sex
age
behav
nest_id
cam_id
photo_start
photo_end
harddrive_id
comments
falcon_upload
nov
pk
```

Incubation or nesting association observations are stored here. If a nest-associated bird is recorded, `nest_id` should be present where required by the field protocol.

Broods may also be recorded in `RESIGHTINGS`, with each chick as an individual row and tending parents linked by shared `date`, `site`, `gps_id`, `gps_point`, and `nest_id` context where applicable.

### RESIGHTINGS_PUBLIC

`RESIGHTINGS_PUBLIC` stores public observations entered by Katie or collaborators.

Use current SQL as the source of truth for its exact fields.

### GPS_POINTS and GPS_TRACKS

`GPS_POINTS` and `GPS_TRACKS` are compiled through the GPS upload workflow.

Important fields include:

```text
GPS_POINTS: gps_id, gps_point, datetime_, lat, lon, ele, pk
GPS_TRACKS: gps_id, seg_id, seg_point_id, datetime_, lat, lon, ele, pk
```

The `gps_id` and `gps_point` fields are canonical linkage fields between field observations and point locations in `GPS_POINTS`.

Do not print or log real GPS coordinates unless the user explicitly approves a narrow, safe purpose.

### inspectors

The `inspectors` table stores DB-managed validation code.

Known fields include:

```text
table_name
inspector
comments
updated_at
```

Current inferred behavior:

* `table_name` identifies the target data-entry table;
* `inspector` stores R code, likely a `list(...)` of validator expressions;
* `comments` stores notes about the inspector;
* `updated_at` records update time;
* validation code is loaded through package-side behavior.

Multiple inspector rows per table are now a working pattern in this project, especially for separating hard, warning, and residual/format lists.

Live biological data-entry tables should now be organized into only two inspector types:

```text
TABLE_hard
TABLE_warning
```

Interpret these as follows:

* `TABLE_hard` maps to protocol `hard_rules` and produces save-blocking `error` conditions;
* `TABLE_warning` maps to protocol `warning_rules` and produces non-blocking `warning` conditions.

There should be no permanent third live inspector type such as `TABLE_residual` or `TABLE_format_residual`.
Any legacy regex, syntax, format, or migration-era validator should be reassigned into either
`TABLE_hard` or `TABLE_warning` based on whether it represents a true save-time error or a review-level warning.

Do not update this table unless explicitly instructed.

### spatial_objects

`spatial_objects` is a support table and has its own `DataEntry/spatial_objects/` app.

It is not one of the main biological field tables, but it is an important support table in the app database structure and should be treated as a real dependency.

Its records support vector overlays in maps and, for plot polygons, help keep mock-data naming schemes aligned with plot names.

### settings

`settings` is a support table used by the app.

Review it when dashboard behavior, reference dates, app settings, or runtime configuration are involved.

### predict_hatching

`predict_hatching` is a stable support table used by hatching prediction logic.

Treat it as important but biologically sensitive. Do not assume the hatching model is universally valid without user confirmation.

## Identifier rules

Individuals have globally unique identifiers:

* metal ring code: globally unique across the project;
* full adult colour-band combination using `UL`, `LL`, `UR`, and `LR`: globally unique across the project;
* engraved flag/code, where present: globally unique across the project;
* `tag_id`, where present: unique to a device/tag and linked to deployment or retrieval information through `tag_action`, `tag_type`, and related tag fields.

Pre-fledging chicks may receive a single colour band on the left tarsus. Siblings from the same brood may share this single colour marker. Later, near fledging, they should be recaptured and given a unique engraved flag/code.

Nests have `nest_id` values that are unique within a season/site context, not necessarily globally unique across all years.

When proposing constraints or validation logic, Codex must respect these identifier rules.

## Validation architecture

Validators are used during field data entry before records are submitted to `FIELD_2026_BADOatNZ`.

Validators are fieldworker-facing safeguards, not post-hoc cleaning tools.

The project uses a central DB-stored inspector system rather than tracked per-table `inspector.R` files.

Validation rules are managed through:

```text
DataEntry/inspectors/
```

and stored in:

```text
inspectors
```

The actual validator execution behavior is largely package-side in the external `DataEntry` package.

## DataEntry validator contract

Under the current `DataEntry` validator system:

* the current table being validated is available as `x`;

* each validator should return a `data.frame`, `data.table`, or similar object;

* the returned object must contain at least:

  * `rowid`
  * `variable`
  * `reason`

* `rowid` is the row number in the submitted table;

* `variable` is the field/column that failed validation;

* `reason` is the fieldworker-facing explanation;

* extra columns are ignored by the validation display unless package-side/UI behavior is changed;

* if there are no problems, the validator should return zero rows with the same required columns;

* when subsetting rows, validators must preserve `rowid`;

* each validator expression inside an inspector should be wrapped with `try_validator(nam = "...")`;

* the `nam` value should be short and recognizable;

* if a validator needs helper objects, temporary subsets, lookup tables, or local setup code, define those objects inside `{ ... }`;

* an inspector is a `list(...)` of one or more validator expressions.

Validator development should start locally with fake or mock data that includes passing, failing, and edge cases.

Only after local mock testing should a validator expression be pasted into the `inspectors` table.

## Validator protocol

Thread 3.1 now uses a machine-readable validator protocol as the official spec-of-record for validator behavior.

Current local protocol path:

```text
/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/bdot_db/data/working/bdot_dataentry_validator_protocol.yaml
```

Current protocol identity:

```text
protocol_id: bdot_2026_2027_dataentry_validator_protocol
protocol_version: 1.3.3
generated_on: 2026-09-30
```

Version 1.3.3 requires a real nest or brood link for age-C first captures and
permits an optional complete GPS pair for positive-nest chicks captured away
from the nest. Version 1.3.2 added save-blocking H-ring format and current-
CAPTURES existence checks. The H-ring rule remains restricted to normalized
`rclass = "H"`; ordinary RESIGHTINGS classes may leave `ring` blank.

Use the latest approved local database snapshot in `DATABASE/` only as a
read-only alignment reference for mock-data generation and protocol review.
Do not hard-code a snapshot filename as permanently current.

The protocol distinguishes four rule classes:

```text
error
warning
post_save_qa
mock_generation_only
```

Important rules:

* `mock_generation_only` rules must never be translated into live save-time validators;
* `post_save_qa` logic should not be moved into save-time inspectors unless explicitly approved;
* rules listed under protocol `hard_rules` should be implemented as `error`;
* rules listed under protocol `warning_rules` should be implemented as `warning`;
* adding extra columns such as `type` or `severity` to validator output will not automatically make them appear in the FIELDWORKER portal unless package-side/UI behavior supports it;
* the current portal validator table does not yet surface a visible `type` column; adding that feature is a future UI/package iteration;
* parser checks, local mock workbook checks, and paste-test checks should happen before any validator is pasted into the live `inspectors` table.

## Mock validator workflow

Thread 3.1 should use connected fake/mock datasets rather than tiny isolated examples whenever cross-table
rules are being developed or debugged.

Preferred workflow:

1. maintain the protocol in `bdot_dataentry_validator_protocol.yaml`;
2. maintain the connected mock workbook and per-table CSV exports used for paste-tests;
3. test validator logic locally against mock data first;
4. triage any `variable = NA` or broken-inspector failures before proposing live inspector edits;
5. only after approval, sync the validated scratch outputs into `bdot_db/data/working/`.

Mock-generation targets and tendencies belong in protocol `mock_generation_only_rules`.
They must shape or audit the fake datasets only and must not be compiled into live portal validation.

## Post-submission QA

Post-submission QA is separate from validation.

Validation happens before upload.

Post-submission QA happens after data have already entered `FIELD_2026_BADOatNZ`.

Post-save QA should focus on:

* records submitted despite validator gaps;
* biologically unusual but possible records;
* missing relational links;
* inconsistent nest, egg, hatch, capture, and resighting states;
* data-entry patterns suggesting validator bypass;
* checks needed before merging 2026 data into historic `BADOatNZ`.

## Role of `nov`

`nov` appears to function as a validation/bypass or upload-status-related field.

The main app may summarize `nov` by observer or table to indicate validation bypass rates or records needing review.

Do not change the type, meaning, or interpretation of `nov` without checking:

* current `DATABASE/*.SQL`;
* `main/server.R`;
* current views;
* current `inspectors` behavior;
* collaborator intent.

Known issue: `nov` may be typed inconsistently across tables.

## FIELDWORKER to-do/list/PDF workflow

The active to-do workflow is currently SQL-view driven.

Important SQL objects include:

```text
NESTS_LATEST
BROODS_LATEST
EGGS_HATCH_PREDICTION
TODO_LIST
```

Important app/PDF files include:

```text
main/global.R
main/server.R
main/R/pdf_todo.R
main/R/pdf_todo_map.R
main/templates/todo_pdf.qmd
```

`TODO_LIST` should be treated as a core operational view and the authoritative task source for FIELDWORKER to-do outputs.

Current implemented to-do classes include:

```text
Parent capture
Parent resighting
Unprocessed nest
take scrape photos
Re-process nest
Clutch check
nest check
Untrapped brood
Hiding spot photos needed
notA nest-check
```

`Untrapped parent` remains an internal compatibility/intermediate label in the
CTE chain, but it is not part of the current final task union.

For hiding-spot work, `TODO_LIST` compares distinct age-C CAPTURES rings with
distinct qualifying H-photo rings per positive nest or negative brood. A blank
or missing ring does not count, duplicate rows for one chick count once, and
each photographed chick requires its own H-class row. The task remains open
while the H-photo count is lower and reports the ratio; it closes when the
counts match or expires after the current day-6 window. This evidence remains
separate from a CAPTURES tent-photo event.

Parent association is sex-aware, chronology-aware, and bounded by
`settings.reference_date`. Ordinary banded identities use LL/LR; a
spacer-dependent single-lower-colour identity uses the required full mark.
Association-confirming behaviour tokens are `IN`, `NM`, `BW`, `BC`, and `FC`.
A matching parent association resolves after one such behaviour observation or
after three matching nest-linked resightings, counting the initial resighting.
Unresolved or ambiguous association evidence remains in `Parent resighting`
rather than silently becoming capture/GEO work.

Current `nest check` tasks may carry note-level distinctions such as pre-hatch nest checks versus hatch-sign follow-up. Use current SQL and app code as source of truth for exact task names, note text, and cadence.

When testing to-do/list/PDF behavior, prefer local `.rds` snapshots or fake/mock data over live database queries.

The PDF query path deliberately projects only the `TODO_LIST` columns it uses
and disables derived-table merging to reduce MariaDB planning pressure. Static
tests do not prove production performance; benchmark view creation, row counts,
and PDF rendering against an approved local MariaDB fixture before deployment.

Do not print real coordinates or broad real-record dumps in diagnostics.

## Overview dashboard workflow

The Overview tab is a current seven-panel dashboard for FIELDWORKER users.

Its active code path is:

```text
main/ui.R
main/server.R
main/global.R
main/R/ggplot_overview.R
main/R/system_utils.R
main/R/system_utils_app.R
main/www/style.css
```

There is no active `main/R/data_overview.R` helper. The standalone SQL
`OVERVIEW` view is visible in the database browser but does not supply the
seven plotted panels.

The current panel order is:

1. seasonal progression in nest discovery;
2. seasonal progression in geolocator deployments;
3. resighting histories of geolocator-tagged birds;
4. seasonal progression in unique band combinations encountered;
5. seasonal progression in lay date;
6. hatching forecast; and
7. current manipulation quotas.

All panels use the app-level reference date. The first five date-based panels
share the seasonal range where applicable, hatching uses a future range, and
quotas have no date axis. The tagged-resighting panel intentionally uses a
taller `105vh` output with a multi-row legend and caption; preserve that mobile
layout when changing its facets, labels, or limp-status display.

The active helpers use parameterized queries and panel-specific fallback plots.
Experimental pair-tally helpers remain isolated and are not user-visible.
Additional dashboard panels may require new helpers under `main/R/`, but must
be staged and tested without disrupting the current seven outputs.

GPS-track heatmaps, new maps, summary cards, and panel-local filters remain
future work rather than current app behavior.

For GPS/track dashboards:

* use `GPS_TRACKS`, `GPS_POINTS`, and `OBSERVERS` only through approved read-only workflows or mock data;
* do not print or log real GPS coordinates;
* do not assume WGS84 lat/lon can be gridded directly into 50 m cells;
* if 50 m grids are needed, propose a projection strategy first, likely involving a metric CRS such as NZTM / EPSG:2193 for New Zealand;
* assess performance before proposing dynamic raw-track aggregation in Shiny;
* prefer staged development: mock prototype, simple app panel, reactive/cached version, optional SQL/view/pre-aggregation only if needed.

## Hatching model caution

The main app uses hatching prediction logic linked to egg floatation data and `predict_hatching`.

The biological validity and calibration of any hatching prediction model should be reviewed before treating hatch predictions as authoritative.

Threads working on to-do logic, hatching displays, or Overview panels should flag any dependence on hatching predictions.

## Testing policy

Explain tests and their results in plain language, using small fake examples or
local checks where practical.

For validation rules, prefer mock examples:

* one example that should pass;
* one example that should fail;
* one edge case.

For to-do/list/PDF logic, prefer local `.rds` smoke tests or mock data unless live database inspection is explicitly approved.

Never use real sensitive data in tests.

The repository includes a meaningful `tests/testthat/` layer. Key suites include
`test-app-wiring.R`, `test-main-server.R`, `test-pdf-todo.R`, and
`test-todo-view-rules.R`. Threads may inspect tests by default as repo-visible
evidence of current behavior, but should not run tests unless the user
explicitly approves.

If the repository already uses a testing framework, follow it. Do not introduce a new testing framework without explaining the benefit and asking first.

## Continuous integration

Do not introduce CI/GitHub Actions unless explicitly requested.

If CI is discussed, explain it as automatic checks that run on GitHub after a push or pull request.

For now, local checks and manual RStudio review are preferred.

## Database concepts

When discussing schema migrations, explain them plainly as tracked scripts that change the database structure in reproducible steps.

Do not introduce a migration framework unless the existing repository already uses one or the user asks for it.

When discussing soft deletes, explain them plainly as marking rows as deleted/inactive instead of physically deleting them.

Do not add soft-delete logic unless explicitly requested.

## Agent/thread roles

Codex should organize work into the following threads or subagents when possible.

### Thread 1 — Repository cartographer

Purpose: maintain an accurate map of the current local repository after merges,
refactors, and collaborator updates.

Responsibilities:

* inspect the current repo layout and recent Git state;
* identify the current app entry points in `main/`, `DataEntry/`, `DataEntry/inspectors/`, `DataEntry/spatial_objects/`, and `gpxui/`;
* map which files control each browser-visible interface;
* distinguish repo-visible behavior from package-side behavior in the external `DataEntry`, `dbo`, and `gpxui` packages;
* inspect `DATABASE/*.SQL`, `main/*.R`, `main/R/*.R`, `main/templates/`, `main/www/help/*.html`, `main/www/*.js`, and `tests/testthat/*.R`;
* identify deleted, renamed, stale, or obsolete paths from earlier repo maps;
* update the tracked repository handoff at
  `notes/codex_proposals/THREAD1_REPOSITORY_MAP.md` when explicitly requested.

Restrictions:

* no edits to tracked application or database source unless explicitly requested;
* no database connections;
* no app runs unless explicitly approved and confirmed read-only;
* no inspection of credentials, local `.cnf` files, or real confidential data unless explicitly approved;
* local `.rds` snapshots, `.Rproj.user/`, and `tests/test-results.csv` may be inspected when relevant, but they should not override tracked source files as the source of truth.

Expected output:

* current file/function map;
* main app and DataEntry architecture summary;
* current schema/view/support-table map;
* package-side versus repo-visible boundary notes;
* key handoff files for Threads 2, 3, 4, 5, and 6;
* unresolved questions and stale assumptions.

The tracked handoff is the detailed current map; this section defines the role.

### Thread 2 — Database architect

Purpose: maintain and refine the SQL structure that supports `FIELD_2026_BADOatNZ`, including base tables, support tables, SQL functions, and dashboard-facing views.

Responsibilities:

* inspect the current SQL source files in `DATABASE/`, especially:

  * `main_tables.SQL`;
  * `support_tables.SQL`;
  * `views.SQL`;
  * `functions.SQL`;
  * `predict_hatching.SQL`;
  * `_reset.SQL`;
* treat `DATABASE/main_tables.SQL` as the lead DDL file for the core database tables;
* compare schema objects to current app needs, data-entry modules, dashboard logic, validation architecture, GPS linkage, and current export/report needs;
* review dependencies between base tables, support tables, SQL functions, and views;
* include historical compatibility views such as `CAPTURES_ARCHIVE` in schema review when they affect current app behavior;
* identify schema gaps affecting validators, to-do logic, hatching logic, spatial objects, DB browser views, GPS linkage, and dashboard outputs;
* propose SQL only after explaining the change in plain language;
* identify safe indexes, constraints, compatibility risks, migration risks, and rollback steps;
* flag inconsistencies between AGENTS assumptions and the current SQL source of truth.

Scope note:

* Thread 2 is the lead agent for changes to `DATABASE/main_tables.SQL`.
* Other agents may change other SQL files in `DATABASE/` when their workflow depends on them.
* In particular, threads working on app logic such as to-do generation may need to change `DATABASE/views.SQL` when necessary.

Restrictions:

* do not connect to real databases unless explicitly instructed;
* do not execute schema changes;
* do not assume the live database matches local SQL files;
* ask before proposing major schema changes;
* do not use real rows;
* do not recommend destructive replacement workflows by default when `ALTER TABLE` or backup-first patterns are more appropriate.

Expected output:

* schema review across all active SQL files;
* table/view/function/support-table change proposals;
* dependency notes;
* possible indexes/constraints;
* migration risks and rollback notes.

### Thread 3 / 3.1 — Validation specialist

Purpose: maintain and refine the DB-stored FIELDWORKER validation system, including live inspector code, validator protocol specifications, and connected mock-data workflows used to test save-time behavior safely before portal updates.

Responsibilities:

* maintain the current DataEntry validator contract and inspector architecture;
* maintain protocol-aligned DB-stored inspectors using only two live inspector types per table:

  * `TABLE_hard`
  * `TABLE_warning`

* keep `TABLE_hard` aligned with protocol `hard_rules`;
* keep `TABLE_warning` aligned with protocol `warning_rules`;
* reassign any legacy or format-only validator into either `TABLE_hard` or `TABLE_warning` rather than maintaining a third live category;
* maintain the machine-readable validator protocol and keep it aligned with agreed field logic;
* use connected multi-table mock workbooks and per-table CSV exports to test cross-table rules before any live inspector paste;
* distinguish save-time blockers from warning-level rules, post-save QA logic, and mock-generation-only targets;
* keep approved scratch outputs synchronized into `bdot_db/data/working/` when requested;
* preserve working validators where possible;
* write short fieldworker-facing messages;
* investigate `variable = NA` or broken-inspector failures using mock data and parser checks before live edits.

Restrictions:

* no real database queries unless explicitly approved;
* no use of confidential rows, credentials, or real GPS data;
* do not translate `mock_generation_only_rules` into live validators;
* do not move `post_save_qa` logic into save-time inspectors unless explicitly approved;
* do not write to the `inspectors` table unless explicitly approved;
* do not assume extra output columns such as `type` or `severity` are visible in the portal unless package-side behavior confirms it.

Expected output:

* protocol-aligned inspector lists;
* mock workbook and CSV test artifacts;
* validator failure triage;
* clear warning versus error recommendations;
* rollback and verification notes.

### Thread 4 — FIELDWORKER to-do/list specialist

Purpose: maintain and refine the SQL-backed FIELDWORKER task-generation workflow and its user-facing map, list, and PDF outputs for the 2026 field season.

Responsibilities:

* inspect and patch proposals for `DATABASE/views.SQL`, especially
  `NESTS_LATEST`, `RESIGHTINGS_H_BROOD_ASSOCIATIONS`, `BROODS_LATEST`,
  `EGGS_HATCH_PREDICTION`, and `TODO_LIST`;
* trace how `NESTS`, `EGGS`, `CAPTURES`, `RESIGHTINGS`, and `GPS_POINTS` flow into FIELDWORKER to-do outputs;
* treat `TODO_LIST` as the authoritative task engine for FIELDWORKER task outputs and keep downstream app/PDF behavior aligned with it;
* keep SQL outputs consistent with `main/server.R`, `main/global.R`,
  `main/R/pdf_todo.R`, `main/R/pdf_todo_map.R`, and related app outputs;
* diagnose missing marks, stale labels, join failures, filtering issues, coordinate-linkage problems, and PDF-rendering mismatches;
* preserve the current parent-association and per-chick hiding-photo contracts;
* use local `.rds` snapshots and mock data for read-only smoke tests;
* propose minimal SQL or R patches with rollback and manual verification instructions.

Restrictions:

* no live database writes or schema changes;
* no live view rebuilds unless explicitly approved;
* no real coordinate output;
* no broad real-record dumps in diagnostics.

Expected output:

* static code traces;
* minimal SQL or R patch proposals;
* local smoke-test code;
* manual FIELDWORKER/PDF verification steps;
* rollback notes and side-effect warnings.

The detailed current contract is tracked in
`notes/codex_proposals/THREAD4_TODO_MAP_LIST_DEBUG_PLAN.md`.

### Thread 5 — Overview dashboard specialist

Purpose: maintain and carefully extend the FIELDWORKER app's current
seven-panel Overview dashboard.

Responsibilities:

* inspect and understand the Overview code path in `main/ui.R`, `main/server.R`, `main/global.R`, and Overview-related helpers under `main/R/`;
* preserve the seven current outputs, shared reference-date behavior, failure
  fallbacks, and mobile layout;
* propose additional Overview panels, plots, maps, cards, and dynamic controls
  only as staged work;
* design dynamic dashboard logic using mock data first;
* assess spatial, performance, and UI implications before proposing tracked-file edits;
* coordinate with Thread 2 when new database views or support tables might be needed;
* coordinate with Thread 4 when dashboard outputs depend on `TODO_LIST`, `NESTS_LATEST`, hatching estimates, or GPS linkage.

Potential work includes:

* additional summary plots;
* dynamic user-facing dashboard cards;
* GPS tracks heatmap panels;
* recent field-activity summaries;
* observer/user filters;
* date-window filters;
* expandable/collapsible dashboard boxes.

The detailed current panel contracts and known risks are tracked in
`notes/codex_proposals/THREAD5_OVERVIEW_DASHBOARD_PLAN.md`.

Restrictions:

* no tracked-file edits unless explicitly approved;
* no database queries unless explicitly approved;
* no real GPS coordinate output;
* no new package dependencies unless justified and approved;
* no schema/view changes without Thread 2-style review;

Expected output:

* Overview architecture traces;
* staged dashboard design proposals;
* mock-data prototypes;
* minimal UI/server/helper patch proposals;
* dependency and performance notes;
* rollback and manual app-check instructions.

### Thread 6 — Combo-list specialist

Purpose: maintain the conservative used/available colour-band-combination
system and its FIELDWORKER PDF integration.

Responsibilities:

* maintain the tracked Thread 6 combo-list protocol;
* inspect `format_mark()`, `CAPTURES_ARCHIVE`, `USED_COMBOS_DETAIL`,
  `AVAILABLE_COMBOS`, and `todo_pdf_prepare_team_marks()` as one dependency
  chain;
* preserve global subtraction across historical archive, current release, and
  current `_in` band fields;
* keep classic and tag/spacer representations aligned to the canonical LL/LR
  rules;
* maintain candidate-site rules, fixed exclusions, ranking, CR/CX compatibility,
  and fail-closed reference-date behavior;
* audit non-normalizable used marks and ensure no confidently used combination
  leaks into `AVAILABLE_COMBOS`;
* preserve the PDF's hard cap of 30 marks, even distribution across three
  teams, and fail-loud behavior when no combinations are available;
* treat the recyclable-combo workbook as informational unless an explicit,
  reviewable reuse policy is approved;
* coordinate SQL architecture with Thread 2, validator/mock alignment with
  Thread 3.1, and PDF ordering/allocation with Thread 4.

Restrictions:

* do not weaken used-combo subtraction or recycle a mark without explicit
  policy approval;
* do not connect to or modify a live database unless explicitly instructed;
* do not expose real bird records, rings, credentials, or raw database rows;
* do not assume a local dump or preview overrides current tracked SQL.

Expected output:

* combo-protocol maintenance notes;
* aggregate/read-only audit queries and focused tests;
* exclusion, ranking, normalization, and ambiguity review;
* cross-thread handoffs and rollback guidance.

The detailed current contract is tracked in
`notes/codex_proposals/THREAD6_COMBO_LIST_PROTOCOL.md`.

### Thread 7 — Tutor

Purpose: act as the user’s local AI tutor across all threads.

Responsibilities:

* explain unfamiliar concepts plainly;
* summarize what other threads found;
* explain terms such as validator, inspector, `rowid`, `nov`, unit tests, CI, schema migrations, soft deletes, indexes, constraints, joins, views, SQL functions, GeoPackage, raster heatmaps, projections, CRS, and audit trails;
* help the user decide what is worth implementing now versus later;
* translate technical recommendations into RStudio/manual-edit steps.

Restrictions:

* do not make code changes;
* do not assume the user wants software-engineering overengineering;
* keep explanations tied to the FIELDWORKER use case.

Expected output:

* plain-language explanations;
* decision trees;
* trade-off summaries;
* next-step recommendations.

## Cross-thread handoff rules

* Thread 1 keeps the repo map current and should flag stale paths for all other threads.
* Thread 2 owns schema, views, SQL functions, support tables, and migration-risk reasoning.
* Thread 3.1 owns save-time validation, the validator protocol, and the
  `RESIGHTINGS.ring` requirement for H-class hiding-photo events.
* Thread 4 owns FIELDWORKER to-do/list/map/PDF logic, especially `TODO_LIST`,
  including per-chick resolution of hiding-photo tasks and parent association.
* Thread 5 owns the seven-panel Overview dashboard and staged extensions.
* Thread 6 owns combo-list normalization, used-mark subtraction, candidate
  availability, and PDF team-mark handoff.
* Thread 7 translates technical findings into plain-language decisions.

Safety, reproducibility, confidentiality, rollback, test review, and PR hygiene
are shared requirements for every thread rather than a separate Thread 6 scope.

When a task crosses boundaries, the active thread should explicitly name the handoff and avoid silently taking over another thread’s scope.

## Definition of done

A task is done only when Codex has provided:

* clear findings;
* a proposed manual change or clear statement that no change is recommended;
* the exact location where the user should apply it;
* mock-data checks, local read-only checks, or manual verification steps;
* risks;
* rollback instructions;
* no real-data leakage.

Codex should never describe a task as complete if it has not actually inspected the relevant files or if it made assumptions that still require confirmation.
