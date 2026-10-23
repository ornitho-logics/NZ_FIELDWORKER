# Thread 9 local-replica protocol

Last reconstructed: 2026-10-23

Status: tracked recovery documentation for the local MariaDB replica and
refresh/replay workflow. This file is intentionally not a source-of-truth
document for task biology, PDF semantics, validators, or production
deployment. It records how Thread 9 should reproduce and diagnose the current
schema/refresh workflow without touching the live database.

## Role, ownership, and non-goals

Thread 9 owns the disposable local MariaDB 11.8.9 replica, safe SQL replay,
refresh-stage instrumentation, timing, failure diagnosis, and local render
verification. Thread 9 does not own the biological meaning of tasks, parent
association, closure evidence, map semantics, or PDF table ordering.

Thread 4 remains authoritative for `TODO_LIST`, task values, task eligibility,
brood closure semantics, map inputs, PDF table semantics, and field-facing
wording. Thread 2 remains authoritative for schema and SQL architecture.
Thread 3.1 remains authoritative for validators and inspector protocols.
Thread 5 remains authoritative for Overview panels. Thread 6 remains
authoritative for available colour-combination generation and ranking.

This protocol must not be used to:

- connect to the production server;
- request, store, or reproduce credentials;
- print raw field records, full database rows, or GPS coordinates;
- alter the live database, live inspectors, or deployed Shiny process;
- overwrite a user's dirty checkout;
- commit, push, merge, or create a PR without an explicit request;
- change biological rules merely to make a replay faster; or
- treat a successful local PDF as proof that production has been deployed.

The current working checkout is dirty. Any future Thread 9 work must first
record its Git state and use a disposable worktree or an isolated copy. It must
not edit or stage the existing dirty files merely to make the local replica
convenient.

## Source-of-truth hierarchy

Use the following order when sources disagree:

1. The exact branch/revision explicitly selected for the test, normally a
   clean worktree based on `origin/main` plus the proposed reviewed diff.
2. Tracked SQL under `DATABASE/`, especially `main_tables.SQL`,
   `support_tables.SQL`, `functions.SQL`, `predict_hatching.SQL`, `views.SQL`,
   and `refresh_todo_list_snapshot.SQL`.
3. Tracked application code under `main/`, including `server.R`,
   `main/R/pdf_todo.R`, `main/R/pdf_todo_map.R`, and the PDF template.
4. Focused tests under `tests/testthat/`.
5. A supplied local RDS/SQL dump, used only as disposable test input. Its
   dumped derived views are not authoritative; rebuild derived objects from
   the selected repository SQL.
6. A locally rendered PDF/PNG, used as a visual regression contract only.
7. User-reported Adminer output, used as evidence of what the user observed,
   not as a substitute for a controlled local replay.

The live server is outside Thread 9's authority. A local replay can establish
that a revision is internally consistent, but it cannot establish that the
server imported that revision or that the deployed Shiny process restarted.

## Current checked-in and pending state

At the final documentation publication audit:

- `origin/main` was `f7d13fb`, including the table-alignment/note work and the
  subsequent refresh empty-statement fix merged through PR #147.
- The active checkout was branch `codex/split-todo-calculator-2026-10-19`, at
  `d3c7bd4`, with unrelated dirty changes in SQL, PDF code, validators, and
  tests. It is not a clean deployment candidate and must be preserved.
- The isolated refresh-fix worktree produced `ad1698b` on
  `codex/fix-refresh-empty-statement-2026-10-23`. That commit
  changes one character sequence in `DATABASE/refresh_todo_list_snapshot.SQL`:
  the task-row statement terminator changes from `);;` to `);`.
- `ad1698b` was subsequently merged through PR #147 as `f7d13fb`. This proves
  source merge only; it does not prove production deployment.
- The earlier note/legend merge remains part of the history; PR #147 is the
  later source correction for the refresh terminator.

The user subsequently supplied an Adminer screenshot showing all refresh
 stages through `publishing` with no red error. That is positive user evidence
for the corrected file, but no live database query was run by Thread 9 and no
live state should be inferred beyond what the screenshot visibly showed.

## Architecture and dependency map

### Base and support layer

The current-season dump supplies the source tables. The local import must also
provide the historic `BADOatNZ.CAPTURES` and `BADOatNZ.SEX` objects needed by
compatibility logic. `settings.reference_date` is part of the test boundary
and must be preserved from the supplied current-season dump.

`support_tables.SQL` defines support tables such as `settings`,
`spatial_objects`, and `inspectors`. `functions.SQL` supplies SQL helpers such
as `format_mark()`. `predict_hatching.SQL` supplies the stable hatching
support table. `_reset.SQL` is destructive and is suitable only for a
disposable local database, never for a live database.

### Schema/view layer

`DATABASE/views.SQL` creates compatibility, identity, nest, brood, hatch,
available-combo, parent-status, closure, and snapshot-boundary objects. The
current optimized source deliberately does not create an active
`TODO_LIST_CALCULATE` view. It contains a defensive drop for an obsolete
object and leaves the expensive full task assembly to the explicit refresh
script.

The current source also creates or upgrades `TODO_REFRESH_STATUS`, retains
the status boundary used by the app, and sets a session-level metadata lock
wait limit. The lock setting applies to the importing session only; it is not a
global server change and it does not kill another session holding a lock.

### Refresh layer

`DATABASE/refresh_todo_list_snapshot.SQL` is the explicit materialization
pipeline. It builds compact, indexed replacement tables in stages:

1. `nest_context`
2. `brood_context`
3. `chick_capture_context`
4. `hiding_spot_photos`
5. `chick_gps_links`
6. `parent_status`
7. `brood_closure`
8. `task_rows`
9. `publishing`

The expensive task assembly is a refresh-time `WITH` query. This is the
important distinction from the historical Adminer failure: the installer no
longer asks MariaDB to validate/expand a giant live `TODO_LIST_CALCULATE` view
during `views.SQL` installation.

The refresh writes `_BUILD` tables, validates/builds their contents, and only
then uses one multi-table `RENAME TABLE` to promote them. Existing public
snapshots are kept available until publication. `_PREVIOUS` tables are removed
only after publication and public input-boundary views have been repointed.

### Public task and application layer

After publication, the input-boundary views point to the new snapshots;
`TODO_PARENT_TASKS`, `TODO_NONPARENT_TASKS`, and `TODO_LIST` expose the
published task rows. `TODO_LIST` is the public task source. The PDF queries
the published task source and related reference-date-bounded data; it should
not recompute the full task graph during an ordinary download.

The server guards PDF downloads with `todo_snapshot_is_current()` and reports
failed, running, or unavailable refresh health. A refresh failure therefore
must not silently replace a valid public snapshot, and a download should warn
or fail closed when the active reference-date snapshot is missing or stale.

## Clean local bootstrap

Use an isolated temporary MariaDB 11.8.9 instance with:

- a disposable data directory under `/tmp` or another ignored scratch area;
- a unique socket and PID file;
- `--no-defaults`;
- `--skip-networking` unless a narrowly scoped local test requires otherwise;
- no reuse of an existing MariaDB datadir, socket, port, or service; and
- no credentials or configuration files copied into the repository.

Before starting, verify the selected socket/datadir do not belong to an
existing service. After the test, stop only the disposable instance and retain
logs in an ignored scratch directory if they contain no raw data. Do not use a
broad recursive deletion target; remove only a validated temporary directory
after the instance is stopped and the artifacts are no longer needed.

Load the source tables from the supplied local dumps into the disposable
database. Load the historic compatibility inputs separately. Do not import
mysqldump-created derived views as the source of truth. If the dump contains a
view section, skip or replace that section before installing the selected
repository views.

The safe dependency order is:

1. database and base-table DDL;
2. current-season base-table data;
3. historic compatibility data required by the archive layer;
4. support tables and settings, preserving `reference_date`;
5. SQL functions;
6. hatching support data;
7. `views.SQL`;
8. `refresh_todo_list_snapshot.SQL`;
9. read-only validation queries;
10. local PDF render and visual inspection.

If a local database must be reset, use a newly created disposable datadir or
the reset script against the disposable database only. Never use this order as
permission to reset a server database.

## Reproducible replay and checks

### Before replay

Record, without staging or modifying files:

```text
git status --short --branch
git rev-parse HEAD
git log -1 --oneline origin/main
git diff --name-status origin/main...HEAD
```

If the checkout is dirty, stop using it as the control. Use a clean worktree
for the replay and write logs/previews only to ignored scratch directories.
Record the exact source revision and dump filenames in a local log, but do not
record credentials, raw rows, coordinates, or full dump contents.

### Install views

Run the selected `DATABASE/views.SQL` with the SQL client configured to stop on
error. Capture each statement boundary, elapsed time, success/failure, and
warnings. For MariaDB installation diagnostics, collect object names and
`SHOW CREATE`/metadata only where needed; do not dump confidential rows.

Immediately check aggregate/schema facts:

- `TODO_REFRESH_STATUS` exists;
- `TODO_LIST` is a view;
- `TODO_LIST_CALCULATE` is not an active view in the optimized source;
- expected snapshot/input/closure objects exist;
- no unexpected old task source is being used; and
- the installer did not leave a client-side error hidden by an old view.

The old Adminer 2006 report occurred in the historical large view-installation
path and was accompanied in at least one run by a metadata-lock wait. The
optimized source reduces that DDL risk. It does not prove that every future
lock, memory, client-timeout, or server-resource failure is impossible.

### Refresh snapshot

Run the refresh file as a separate operation, again stopping on errors. Record
stage markers and elapsed time. The corrected task-row statement must have one
terminator before the `publishing` marker. A client that reports
`Error 1065: Query was empty` after a successful-looking task stage has likely
encountered the historical `);;` typo and may stop before publication.

After completion, query only aggregate health information:

```sql
SELECT
  refresh_id, reference_date, state, started_at, completed_at, task_row_count
FROM TODO_REFRESH_STATUS
ORDER BY refresh_id DESC
LIMIT 1;
```

The successful state must be `succeeded`, `completed_at` must be non-null,
and `task_row_count` must equal the published task count for the same
reference date. A row left in `running` means the client/server process ended
before the final status update; it is not evidence that publication completed.

Then check counts and object types without printing raw records:

```sql
SELECT COUNT(*) AS published_task_rows FROM TODO_LIST;

SELECT TABLE_NAME, TABLE_TYPE
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('TODO_LIST', 'TODO_LIST_CALCULATE', 'VIEW_1');

SELECT COUNT(*) AS remaining_previous_tables
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name LIKE 'TODO\\_%\\_PREVIOUS';
```

The expected result is a successful status, a non-null published count, no
active `TODO_LIST_CALCULATE` view, and no stale `_PREVIOUS` tables after a
successful publication. Use `SHOW PROCESSLIST` only to inspect state and lock
waits; never copy raw query text containing confidential values into a log.

### Render and verify

Render from the same disposable database and exact source revision. Confirm:

- the snapshot reference date and PDF reference date agree;
- the task row count and task-type counts match the selected snapshot;
- the last page/map and summary use the current PDF layout;
- the current table ordering, title/subtitle, legend, team marks, and row
  alignment are present;
- the page-count guard does not create an unwanted fifth page; and
- the version footer identifies the rendering revision without exposing local
  data.

Use PDF text extraction and page count for deterministic checks, then render
full-page PNGs for visual checks. Store generated PDFs/PNGs only under an
ignored scratch/artifact directory. Do not include map coordinates or raw
field rows in the diagnostic report.

## Status lifecycle and recovery

`TODO_REFRESH_STATUS` is the durable, low-volume health record:

- `running`: a refresh was started but has not reached final publication and
  status update;
- `succeeded`: public snapshots were promoted, input boundaries were repointed,
  `_PREVIOUS` tables were removed, and the row count was recorded;
- `failed`/`busy` may be reported by app-side job handling, while a client
  interruption may leave the database row as `running`.

During a failed build, public snapshots should remain available. `_BUILD`
tables may remain and can be removed by the next refresh's controlled cleanup.
Do not manually promote a `_BUILD` table, delete a public snapshot, or mark a
status row successful merely to make the app appear healthy.

If the latest status is `running` after the client has clearly stopped:

1. verify the isolated client/server process is no longer active;
2. inspect processlist/metadata-lock state without exposing raw data;
3. leave the existing public snapshot untouched;
4. rerun the complete refresh from the start so input boundaries are reset;
5. check the new status row and published count; and
6. render only after the new snapshot is confirmed current.

If a metadata lock blocks publication, resolve the local reader/test process or
discard the disposable replica and replay cleanly. Do not increase lock waits
indefinitely and do not terminate unrelated MariaDB services.

## Confirmed facts, strong hypotheses, and unresolved questions

### Confirmed

- Adminer previously reported MariaDB 2006 during a large view installation.
- At least one run waited on a table metadata lock during view DDL.
- A partial install left some expected task objects and not others.
- Production connection counters did not show high concurrency; they do not rule
  out per-query memory, temporary-table pressure, metadata locks, or client
  timeouts.
- The current optimized `views.SQL` does not create a live
  `TODO_LIST_CALCULATE` view.
- The refresh script is separate and performs task assembly in staged build
  tables.
- The current origin refresh source contained a `);;` empty-statement typo at
  the task-row/publishing boundary; commit `ad1698b` corrects it.
- A user-supplied Adminer screenshot after importing the corrected file showed
  all stages through publishing with no red error.

### Strong hypotheses

- The original Adminer hang was amplified by expensive DDL validation and/or
  metadata locking, with client timeout or server-side resource pressure
  possible but not proven.
- The new empty-statement error explains a refresh that reached task-row work
  but remained `running` and unpublished; it is distinct from the old views
  installation failure.
- Snapshot publication is safer than recomputing the full graph for each PDF
  download because it bounds expensive work to the explicit refresh operation.

### Unresolved

- Whether the live server has merged/imported the exact corrected refresh file.
- Whether the live Adminer instance has permissions or timeouts different from
  the local replay.
- Whether the historical server run also involved an OOM or allocator issue;
  no OS evidence established that.
- Whether any external SQL script still depends on the retired
  `GEO_ROLLOUT_PHENOLOGY` object or compatibility objects beyond repository
  consumers.

## Regression checklist

Run this checklist for every proposed SQL or refresh change:

1. clean-worktree and exact-revision check;
2. local dump/reference-date check;
3. isolated MariaDB start/stop check;
4. base/support/function load check;
5. `views.SQL` statement replay with timings and warnings;
6. object inventory and absence of obsolete task sources;
7. refresh-stage replay through `publishing`;
8. status row `succeeded` and count equality;
9. no remaining `_PREVIOUS` tables after success;
10. failed-build simulation leaves the prior public snapshot available;
11. metadata-lock simulation with bounded wait, only in the disposable DB;
12. task count and task-type aggregate comparison with the control;
13. PDF text/column/ordering checks;
14. full-page PNG/page-count checks; and
15. source diff review confirming no raw data, credentials, generated artifacts,
    or unrelated dirty files are included.

The biological regression suite belongs to Thread 4 and must be run there or
against its supplied mock fixtures. Thread 9 may invoke approved local tests,
but must not reinterpret a biological difference as a performance fix.

## Thread 4 handoff

The local replica can answer: did this exact SQL revision install, did each
refresh stage run, did publication occur, what was the aggregate duration, and
does the resulting PDF render? It cannot decide whether a task row is
biologically correct. For any changed task count, task note, parent evidence,
brood closure, map label, or PDF table ordering, hand the comparison back to
Thread 4 with aggregate evidence and a sanitized description of the difference.

Thread 4 should supply a fixed mock/control dataset or approved local dump,
the expected task counts by type, and the expected PDF text/layout contract.
Thread 9 should not silently alter the task SQL to make those comparisons
match.

## Paste-ready restart prompt

> You are Thread 9, the local-replica and refresh-replay specialist for
> `2026_NZ_FIELDWORKER`. Read `AGENTS.md` and
> `notes/codex_proposals/THREAD9_LOCAL_REPLICA_PROTOCOL.md` first. Work only
> in a disposable isolated MariaDB 11.8.9 instance; do not connect to the
> production server, request credentials, print raw rows/GPS, or disturb an
> existing MariaDB service. Record the exact clean Git revision and preserve
> any dirty checkout. Load the approved local dump, rebuild derived objects
> from the selected repository SQL rather than dumped views, replay
> `DATABASE/views.SQL`, then replay
> `DATABASE/refresh_todo_list_snapshot.SQL` as separate instrumented stages.
> Verify `TODO_REFRESH_STATUS`, publication, task-count equality, absence of
> active `TODO_LIST_CALCULATE`, and the PDF/page-count/layout contract. Keep
> SQL installation failures, refresh failures, biological regressions, and
> deployment uncertainty separate. Do not edit, commit, push, merge, or deploy
> unless the user explicitly requests that exact action.

## Rollback of this document

This file is tracked recovery documentation. Revert its documentation commit to
roll it back. No application, SQL, database, test, or runtime behavior is
changed by this file.
