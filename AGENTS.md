# AGENTS.md — NZ_FIELDWORKER / Banded Dotterel Fieldworker Database

## Project identity

This repository is `ornitho-logics/NZ_FIELDWORKER`, a modular R/Shiny application for organizing fieldwork. The project is being adapted for the 2026 Banded Dotterel / Pohowera field season in New Zealand.

The working local repository is:

`/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2025_Fieldworker/NZ_FIELDWORKER`

The app currently includes:

- `main/`: landing page, mapping, viewing, and reporting interface;
- `DataEntry/`: self-contained data-entry modules;
- `gpxui/`: GPS waypoint/track upload interface;
- `Admin/db_structure.SQL`: SQL database structure script;
- `main/R/`: shared helper code for database I/O, UI elements, server elements, maps, and data handling.

The immediate development goals are:

1. prepare the `FIELD_2026_BADOatNZ` SQL database for the 2026 field season;
2. optimize fieldworker-facing data-entry validation functions;
3. create a new workflow that generates a daily QField-compatible to-do map/dataframe;
4. preserve full human control over all code changes;
5. avoid any leakage of confidential raw data.

## Absolute human-control rule

Codex must not directly modify tracked source files, database files, raw data, configuration files, or project structure unless the user explicitly requests that exact edit in the current task.

By default, Codex may:

- inspect the repository;
- run read-only searches;
- run code/tests locally if they do not alter tracked files;
- propose full replacement functions;
- propose minimal diffs;
- write implementation plans;
- write review notes;
- create scratch/proposal files only inside ignored locations.

By default, Codex must not:

- edit existing tracked files;
- commit changes;
- push to GitHub;
- modify database schema;
- connect to the real database;
- inspect confidential raw data;
- write real data into tests, logs, examples, or prompt records;
- create non-ignored files.

The user will manually apply accepted code changes in RStudio.

## Scratch-file rule

Codex may create scratch files only in ignored directories such as:

- `notes/codex_proposals/`
- `notes/codex_logs/`
- `tmp/codex/`

If these directories are not ignored, Codex must first propose `.gitignore` additions and ask the user to add them manually.

Never create scratch files elsewhere without explicit permission.

## Confidentiality and data safety

The full field database is confidential. Codex must never access, query, export, summarize, or reproduce the real database.

The codebase itself is open source. The raw database is not.

Codex may use only:

- fake data;
- hand-written mock data;
- tiny user-provided snippets;
- structurally realistic examples with invented values;
- column names and schema descriptions provided by the user.

Codex must never include in prompts, logs, tests, examples, comments, or documentation:

- database credentials;
- server connection strings;
- usernames;
- passwords;
- real rows from the confidential database;
- unredacted sensitive site data;
- raw GPS locations from confidential data;
- exact rare-species locations unless the user explicitly provides them for that purpose.

If Codex sees credentials, it must not repeat them. It should advise the user to keep credentials out of prompt logs and committed files.

## Git and logging policy

The user wants all accepted code changes to be tracked through Git branches, commits, pushes, and pull requests.

Codex must not commit or push changes unless explicitly instructed.

Prompt and response logging is useful, but risky. By default:

- full prompts and full Codex responses should remain local and ignored;
- only sanitized summaries should be considered for tracked documentation;
- sanitized logs must omit credentials, real data, real database snippets, and confidential locations.

Preferred pattern:

- ignored full logs: `notes/codex_logs/`
- ignored proposals: `notes/codex_proposals/`
- optional tracked summaries, only after manual review: `docs/codex_decisions/`

## Expected response format for code work

For every substantive coding task, Codex should respond with:

1. **What I inspected**
   - files, functions, scripts, or SQL sections reviewed;

2. **What currently seems to happen**
   - a plain-language summary of current logic;

3. **Proposed change**
   - preferably a full replacement function if changing R code;
   - otherwise a minimal diff or SQL snippet;

4. **Where to apply it**
   - exact file path and approximate location;

5. **Why this change is needed**
   - including biological/data-entry reasoning where relevant;

6. **What this might break**
   - possible side effects, backwards compatibility issues, assumptions;

7. **Rollback**
   - how to undo the change manually;

8. **How to check it**
   - mock-data example, local test, manual app workflow, or validation checklist.

## Coding style

Codex should first study the style of the relevant script and then match it closely.

Prefer:

- clear, explicit R code;
- full replacement functions when practical;
- comments that explain non-obvious logic;
- existing packages already used in the codebase;
- simple helper functions over large monolithic blocks;
- plain-language validation messages for fieldworkers;
- mock examples that do not use real data.

Avoid:

- adding new dependencies unless necessary;
- rewriting code into a different style for aesthetic reasons;
- broad refactors unless requested;
- introducing tidyverse, dbplyr, sf, or other packages unless those packages are already used nearby or clearly justified;
- silently changing biological assumptions;
- using real database snippets in examples.

If a new package would simplify the solution, Codex should first explain why and ask before proposing package-dependent code.

## Database field naming

Use snake_case database field names throughout this project.

Canonical names include:

- `nest_id`
- `gps_id`
- `gps_point`
- `cam_id`
- `field_sex`
- `capture_status`
- `time_visit`
- `nest_state`
- `egg_id`
- `float_angle`
- `float_surface`
- `float_location`
- `harddrive_id`
- `falcon_upload`

Do not use camelCase database names such as:

- `nestID`
- `gpsID`
- `cameraID`

The term “waypoint” may be used in prose when referring generically to a GPS waypoint, but the database column is `gps_point`.

## Database backend

Do not assume SQLite.

The FIELDWORKER app is designed around a MySQL/MariaDB-style backend accessed from R via the `dbo` package and local `my.cnf()` credentials.

The target 2026 database is:

`FIELD_2026_BADOatNZ`

The historic database is:

`BADOatNZ`

Codex must not connect to either database unless the user explicitly instructs it to do so and provides a safe mock or local test context.

Codex may inspect `Admin/db_structure.SQL` and propose schema changes, but must always ask before proposing database schema changes in detail.

Schema-change proposals should be written in plain language first, then SQL.

## Database tables

The target 2026 database is expected to include these main tables:

- `CAPTURES`
- `EGGS`
- `NESTS`
- `OBSERVERS`
- `RESIGHTINGS`
- `RESIGHTINGS_PUBLIC`
- `GPS_POINTS`
- `GPS_TRACKS`

The current `Admin/db_structure.SQL` is an older 2024-era version and needs to be updated for 2026.

### CAPTURES

`CAPTURES` stores all in-hand bird captures and recaptures.

This includes:

- adults;
- hatchlings/chicks;
- juveniles;
- recaptures from current or previous seasons;
- 2026 geolocator deployments on nesting adults.

Expected columns are:

- `species`
- `site`
- `date`
- `cap_start`
- `caught`
- `released`
- `capture_method`
- `nest_id`
- `book_id`
- `form_id`
- `observer`
- `gps_id`
- `gps_point`
- `field_sex`
- `age`
- `ring`
- `UL`
- `LL`
- `UR`
- `LR`
- `tag_id`
- `tag_action`
- `tag_type`
- `tag_extras`
- `harness_size`
- `culmen`
- `tarsus`
- `total_head`
- `head_white`
- `head_black`
- `rufous_band`
- `wing`
- `weight`
- `wt_w_tag`
- `moult`
- `feather_wear`
- `fat`
- `blood`
- `primary`
- `breast`
- `other_sample`
- `cam_id`
- `photo_start`
- `photo_end`
- `capture_status`
- `parents`
- `comments`
- `falcon_upload`
- `nov`
- `pk`

Important relational fields include:

- `ring`
- colour-band fields: `UL`, `LL`, `UR`, `LR`
- tag fields: `tag_id`, `tag_action`, `tag_type`, `tag_extras`
- `nest_id`
- `site`
- `species`
- `date`
- `gps_id`
- `gps_point`

The `nest_id` links captured parents to nests and links offspring to their natal nest.

The `gps_id` and `gps_point` fields link capture locations to `GPS_POINTS`.

### EGGS

`EGGS` stores egg-level data.

For 2026, egg data should be long format: one row per egg, not one row per nest.

Expected columns are:

- `species`
- `observer`
- `date`
- `time_visit`
- `nest_id`
- `egg_id`
- `float_angle`
- `float_surface`
- `float_location`
- `cam_id`
- `photo_start`
- `photo_end`
- `comments`
- `nov`
- `pk`

Expected content includes:

- `nest_id`
- `egg_id`
- egg floatation data;
- egg media/photo metadata;
- comments;
- upload/status fields where relevant.

The `nest_id` links eggs to `NESTS`, `CAPTURES`, and other tables.

### NESTS

`NESTS` stores nest observations.

Expected columns are:

- `species`
- `site`
- `date`
- `time_visit`
- `observer`
- `nest_id`
- `nest_state`
- `gps_id`
- `gps_point`
- `clutch_size`
- `brood_size`
- `comments`
- `nov`
- `pk`

This includes:

- nest discovery;
- subsequent nest visits;
- current nest state;
- clutch size;
- brood size;
- comments;
- the unique `nest_id`.

The `nest_id` is unique within a season/site context, not globally.

Coordinates should be obtained by linking `NESTS` to `GPS_POINTS` using `gps_id` and `gps_point`.

### OBSERVERS

`OBSERVERS` stores observer metadata.

Expected columns are:

- `name`
- `observer`
- `gps_id`
- `cam_id`

The `observer` field should be used consistently across data-entry tables to identify who entered or collected the observation.

The `gps_id` and `cam_id` fields associate observers with GPS units and cameras where relevant.

### RESIGHTINGS

`RESIGHTINGS` stores opportunistic and targeted sightings of banded birds.

Expected columns are:

- `species`
- `observer`
- `gps_id`
- `gps_point`
- `date`
- `site`
- `rclass`
- `UL`
- `LL`
- `UR`
- `LR`
- `sex`
- `age`
- `behav`
- `nest_id`
- `cam_id`
- `photo_start`
- `photo_end`
- `harddrive_id`
- `comments`
- `falcon_upload`
- `nov`
- `pk`

This includes:

- sex;
- age;
- colour-band combination;
- resighting class via `rclass`;
- behaviour via `behav`;
- GPS point linkage;
- camera/photo metadata;
- nest association;
- brood observations.

Important rule: incubation observations are stored here. If a nest check records a nest as incubated, the identity of the incubating parent should be entered as a `RESIGHTINGS` observation with incubation behaviour in `behav`.

The `nest_id` must be present in `RESIGHTINGS` where a bird is associated with a nest.

Broods are also recorded in `RESIGHTINGS`, with each chick as an individual row and tending parents linked by shared `date`, `site`, `gps_id`, `gps_point`, and `nest_id` context where applicable.

### RESIGHTINGS_PUBLIC

`RESIGHTINGS_PUBLIC` stores public observations entered by Katie or collaborators.

Expected columns include:

- `species`
- `observer`
- `time`
- `date`
- `latitude`
- `longitude`
- `easting`
- `northing`
- `sex`
- `UL`
- `LL`
- `UR`
- `LR`
- `behav`
- `num_photos`
- `source`
- `source_identifier`
- `country`
- `site`
- `comments_obs`
- `comments_db`
- `falcon_upload`

### GPS_POINTS and GPS_TRACKS

`GPS_POINTS` and `GPS_TRACKS` are not manually edited.

They are automatically compiled when users use the GPS Manager / `gpxui` interface to upload GPS waypoints and tracks.

Expected SQL structure:

```sql
CREATE TABLE GPS_POINTS (
  gps_id int(2) NOT      NULL COMMENT 'gps id',
  gps_point int(10) NOT  NULL COMMENT 'gps point',
  datetime_ datetime NOT NULL COMMENT 'gps date-time (NZST / NZDT)',
  lat double NOT         NULL COMMENT 'latitude',
  lon double NOT         NULL COMMENT 'longitude',
  ele double NOT         NULL COMMENT 'elevation',
  pk int(10) NOT         NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps (gps_id,gps_point),
  KEY datetime_ (datetime_)
) ENGINE=InnoDB;

CREATE TABLE GPS_TRACKS (
  gps_id int(2) NOT        NULL COMMENT 'gps id',
  seg_id int(10) NOT       NULL COMMENT 'segment id',
  seg_point_id int(10) NOT NULL COMMENT 'segment point id',
  datetime_ datetime NOT   NULL COMMENT 'gps date-time (NZST / NZDT)',
  lat double NOT           NULL COMMENT 'latitude',
  lon double NOT           NULL COMMENT 'longitude',
  ele float NOT            NULL COMMENT 'elevation',
  pk int(10) NOT           NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps (gps_id,seg_id),
  KEY datetime_ (datetime_)
) ENGINE=InnoDB;
```

The `gps_id` and `gps_point` fields are the canonical linkage between field observations and point locations in `GPS_POINTS`.

## Identifier rules

Individuals have globally unique identifiers:

- metal ring code: globally unique across the project;
- full adult colour-band combination using `UL`, `LL`, `UR`, and `LR`: globally unique across the project;
- engraved flag/code, where present: globally unique across the project;
- `tag_id`, where present: unique to a device/tag and linked to deployment or retrieval information through `tag_action`, `tag_type`, and related tag fields.

Pre-fledging chicks may receive a single colour band on the left tarsus. Siblings from the same brood may share this single colour marker. Later, near fledging, they should be recaptured and given a unique engraved flag/code.

Nests have `nest_id` values that are unique within a season/site context, not necessarily globally unique across all years.

When proposing constraints or validation logic, Codex must respect these identifier rules.

## Validation philosophy

Validators are used during field data entry before records are submitted to `FIELD_2026_BADOatNZ`.

They are fieldworker-facing safeguards, not post-hoc cleaning tools.

Some existing validators are useful, some are too strict, and some are incorrect. Incorrect validators currently force users to override warnings too often, which increases the risk of real errors being submitted.

Validation messages should be written in plain language for field technicians.

Validators may include:

- single-field checks;
- cross-field checks;
- cross-table checks against current-season data;
- cross-database checks against historic `BADOatNZ` data, if implemented safely by the app.

Important example:

If `capture_status` is entered as recapture, then the `ring` and/or colour combination should already occur in previous records. If not, the validator should flag this as a possible data-entry error before submission.

The user should be able to override a validation flag if they are confident the entry is correct.

Recommended future design:

- validators should separate warnings from hard errors;
- validation output should identify the field, issue, severity, and message;
- overridden warnings should be stored in a validator/audit field where possible;
- validation messages should be understandable to fieldworkers;
- every important validation rule should eventually have mock examples:
  - one passing example;
  - one failing example;
  - one edge-case example.

## Post-submission cleaning

Post-submission cleaning is separate from validation.

Validation happens before upload.

Cleaning/QA happens after data have already entered `FIELD_2026_BADOatNZ`.

Do not mix these responsibilities unless explicitly instructed.

## QField to-do map goal

A new QField-compatible daily to-do map should be generated from database queries.

The QField map is an offline interactive field aid. It is not the primary data-entry pathway.

Users should continue entering completed field data through the FIELDWORKER browser app after returning from the field.

QField may allow users to tick off items locally on their smartphone, but this local tick-off state should not be treated as authoritative database input.

The authoritative task-completion signal is the subsequent FIELDWORKER data entry into `FIELD_2026_BADOatNZ`.

## QField task unit

The minimum viable QField to-do output should be one row per `nest_id`.

Each row should include metadata needed for fieldwork.

Likely columns include:

- `species`
- `season`
- `site`
- `nest_id`
- `task_type`
- `priority`
- `days_overdue`
- `days_until_hatch`
- `gps_id`
- `gps_point`
- `longitude`
- `latitude`
- `male_combo`
- `female_combo`
- `estimated_hatch_date`
- `clutch_size`
- `brood_size`
- `last_visit_date`
- `last_nest_state`
- `days_since_tent_photo`
- `todo_label`
- `todo_notes`
- `active_but_no_action`

The exact QField format should be investigated by the QField export specialist.

Coordinates for a given `nest_id` should be derived by linking `NESTS` to `GPS_POINTS` using `gps_id` and `gps_point`.

## QField task classes

The daily to-do map should include nests or broods requiring action.

Important task classes include:

### 1. Untrapped parent

Includes:

- unbanded parents of known nests;
- non-geotagged mate of a geotagged bird;
- nesting recruits that have only a single colour band and metal ring and need capture/unique colour marking.

Priority should be based on days until expected hatch, with higher priority as hatch approaches.

### 2. Unprocessed nest

A nest discovered in `NESTS` but not yet fully processed in `EGGS`.

These need egg photos and floatation data.

This is especially important because one person may discover the nest and enter basic nest data, while August later handles egg photography and floatation.

Priority should increase with days overdue.

### 3. Re-process nest

If clutch size changes after egg photos and floatation data were collected, the nest should appear again as needing re-processing.

Priority should increase with days overdue.

### 4. 20th day nest check

Nests should be checked conservatively at day 20 after estimated clutch completion.

If `nest_state` is still incubating on day 20, the nest should reappear two days later.

Once `nest_state` changes to starred or pipping, the nest should appear every day until the 20th day nest-check task is resolved.

A 20th day nest-check task is resolved when the nest either hatches or fails.

Failure is recorded in the `NESTS` table through a terminal `nest_state`, such as abandoned, predated, flooded, destroyed, or another failure code.

Hatching is inferred when chicks from that `nest_id` are added to the `CAPTURES` table when they are banded for the first time.

Once either failure or hatch is recorded, the nest should no longer appear as a 20th day nest-check task in future QField to-do outputs.

### 5. Hiding spot photos needed

Recently hatched chicks from known nests need in-situ hiding spot photos.

Earliest target is two days after hatching, once chicks are dry, mobile, and behaving naturally.

The task should be resolved once appropriate chick hiding spot photo observations are recorded in `RESIGHTINGS`, using the relevant `rclass` code, e.g. `H`.

## QField exclusion rules

Do not include completed or irrelevant tasks.

Remove from future to-do outputs:

- nests that failed by abandonment, predation, flooding, destruction, or other terminal failure;
- broods whose hiding spot photos have been completed;
- nests where both parents are known/banded and the nest is not yet near the 20-day check;
- tasks already resolved through FIELDWORKER data entry.

Active nests with no current action may still be shown as subdued map points for context.

## QField symbology concept

High-priority action points should be visually prominent.

Preferred concept:

- red-hot fill for highest priority;
- yellow fill for lowest active priority;
- small green point for active nest with no current action;
- subdued colours for active non-to-do nests.

Map labels should ideally encode:

- `nest_id`;
- male combo;
- female combo;
- estimated hatch date.

The user is interested in a label style where male/female/nest/hatch metadata are placed around the symbol, but implementation depends on QGIS/QField capabilities.

## Agent/thread roles

Codex should organize work into the following threads or subagents when possible.

### Thread 1 — Repository cartographer

Purpose: understand the existing repository without changing it.

Responsibilities:

- inspect repo layout;
- identify main R/Shiny entry points;
- identify which files build which browser interfaces;
- find where database connections are defined;
- find where validators are stored;
- find where to-do map logic currently exists, if any;
- map dependencies between `main`, `DataEntry`, and `gpxui`;
- produce a concise `PROJECT_MAP.md` proposal.

Restrictions:

- no edits to tracked files;
- no database connections;
- no raw data access.

Expected output:

- file/function map;
- likely app execution flow;
- list of key files for future threads;
- unresolved questions.

### Thread 2 — Database architect

Purpose: prepare `FIELD_2026_BADOatNZ`.

Responsibilities:

- inspect `Admin/db_structure.SQL`;
- compare current schema to the 2026 table requirements;
- propose plain-language schema changes;
- propose SQL only after explaining the change;
- identify constraints that should be enforced at the database level;
- identify fields needed for validators and QField task generation;
- advise on MySQL/MariaDB compatibility.

Restrictions:

- do not connect to real databases;
- do not execute schema changes;
- ask before proposing major schema changes;
- do not use real rows.

Expected output:

- schema review;
- proposed table/column edits;
- possible indexes/constraints;
- risks and rollback notes.

### Thread 3 — Validation specialist

Purpose: optimize pre-submission FIELDWORKER validation.

Responsibilities:

- locate existing validator functions;
- classify validators by table/module;
- identify validators that are too strict, too weak, duplicated, or incorrect;
- propose full replacement functions where useful;
- preserve existing code style and dependencies;
- write fieldworker-friendly messages;
- propose mock examples for validation rules.

Restrictions:

- validation only, not post-submission cleaning;
- no real database queries unless explicitly instructed;
- no real data in tests/examples;
- no new packages unless justified and approved.

Expected output:

- validator map;
- proposed replacement functions;
- mock examples;
- explanation of biological/data-entry assumption;
- what this might break;
- rollback notes.

### Thread 4 — Data cleaner

Purpose: post-submission QA/QC for `FIELD_2026_BADOatNZ`.

Responsibilities:

- propose scripts/reports to flag records submitted despite validator gaps;
- distinguish likely errors from biologically unusual but plausible records;
- design post-field checks before merging into historic `BADOatNZ`;
- propose QA reports using mock data or user-provided snippets.

Restrictions:

- no raw data access unless user explicitly provides a safe snippet;
- no database edits;
- no merging into historic database;
- do not overlap with Thread 3 unless asked.

Expected output:

- QA checklists;
- cleaning report designs;
- mock-data examples;
- proposed error/warning categories.

### Thread 5 — QField export specialist

Purpose: build database-to-QField daily to-do workflow.

Responsibilities:

- investigate the safest QField-compatible export path;
- design the one-row-per-`nest_id` task dataframe;
- propose SQL/R queries for task generation;
- propose GeoPackage/QGIS/QField export structure;
- design task priority scoring;
- design exclusion/completion rules;
- avoid direct database credentials in QGIS/QField projects.

Restrictions:

- QField is a map/task-display aid, not authoritative database input;
- no credential exposure;
- no real coordinates in examples;
- no database write-back from QField unless explicitly re-scoped.

Expected output:

- task dataframe specification;
- mock example output;
- R function proposal;
- QField packaging recommendation;
- what this might break;
- rollback notes.

### Thread 6 — QA/reproducibility reviewer

Purpose: keep the project safe, reproducible, and reviewable.

Responsibilities:

- review proposed changes for data leakage risk;
- review `.gitignore` needs;
- review test/mock-data strategy;
- review branch/commit/PR hygiene;
- check whether proposals are minimally invasive;
- check whether rollback notes are adequate.

Restrictions:

- no code edits unless explicitly requested;
- no real data access.

Expected output:

- risk checklist;
- reproducibility checklist;
- recommended ignored files/directories;
- PR-readiness review.

### Thread 7 — Tutor

Purpose: act as the user's local AI tutor across all threads.

Responsibilities:

- explain unfamiliar concepts plainly;
- summarize what other threads found;
- explain terms such as unit tests, CI, schema migrations, soft deletes, indexes, constraints, joins, GeoPackage, QFieldSync, and audit trails;
- help the user decide what is worth implementing now versus later;
- translate technical recommendations into RStudio/manual-edit steps.

Restrictions:

- do not make code changes;
- do not assume the user wants software-engineering overengineering;
- keep explanations tied to the FIELDWORKER use case.

Expected output:

- plain-language explanations;
- decision trees;
- trade-off summaries;
- next-step recommendations.

## Testing policy

The user is not yet familiar with formal testing.

When suggesting tests, explain them as small fake examples that check whether a function behaves correctly.

For validation rules, prefer simple mock examples:

- one example that should pass;
- one example that should fail;
- one edge case.

Never use real sensitive data in tests.

If the repository already uses a testing framework, follow it. If not, do not introduce a testing framework without explaining the benefit and asking first.

## Continuous integration

Do not introduce CI/GitHub Actions unless explicitly requested.

If CI is discussed, explain it as automatic checks that run on GitHub after a push or pull request.

For now, local checks and manual RStudio review are preferred.

## Database concepts

When discussing schema migrations, explain them plainly as tracked scripts that change the database structure in reproducible steps.

Do not introduce a migration framework unless the existing repository already uses one or the user asks for it.

When discussing soft deletes, explain them plainly as marking rows as deleted/inactive instead of physically deleting them.

Do not add soft-delete logic unless explicitly requested.

## Definition of done

A task is done only when Codex has provided:

- clear findings;
- a proposed manual change;
- the exact location where the user should apply it;
- mock-data checks or manual verification steps;
- risks;
- rollback instructions;
- no real-data leakage.

Codex should never describe a task as complete if it has not actually inspected the relevant files or if it made assumptions that still require confirmation.