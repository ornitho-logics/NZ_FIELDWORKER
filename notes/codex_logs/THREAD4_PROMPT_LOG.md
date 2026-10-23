# THREAD 4 prompt log

This file is a tracked, sanitized summary log. It contains only reconstructed
technical prompts and summaries; it does not contain raw database rows,
coordinates, credentials, or field records.

Publication addendum: the refresh terminator fix discussed below was later
merged through PR #147 at `f7d13fb`. Historical entries retain the state that
was true when their prompts were written; source merge still does not prove
production deployment.

## 2026-10-23 - Reconstructed - Local-replica optimization handoff

The user reports that a new dedicated local-replica thread successfully
replayed the repository and rendered the desired PDF. Prepare the following
paste-ready prompt for that thread. This is a reconstructed technical brief,
not a verbatim transcript of every earlier message.

### Paste-ready prompt

We need to make the local disposable MariaDB/R/Shiny replica the primary
debugging environment for the FIELDWORKER TODO pipeline. Do not connect to the
production server, request credentials, or modify the live database. Do not
write raw rows, GPS coordinates, or confidential records into logs, tests, or
committed files. Preserve any dirty checkout; use a clean disposable worktree
or isolated copy for the candidate under test.

The immediate objective is to reproduce the current local PDF successfully,
then bring the local replica up to the intended current architecture and
optimize the SQL so the production Adminer deployment is reliable. The
biological task output must not be simplified merely to make SQL faster.
Every optimization needs row-level or field-level regression comparison
against the current known-good local render and focused tests.

#### Repository and revision discipline

First record the Git branch, HEAD, `origin/main`, worktree status, and the
exact source revisions used. Treat the clean selected revision as the source
of truth for the experiment. At the time of this handoff, the inspected
remote baseline was `origin/main` at `9beb203`; the calling checkout was dirty
at `d3c7bd4` on `codex/split-todo-calculator-2026-10-19`. Do not assume those
are interchangeable. A separate pushed but unmerged fix, `ad1698b`, changes
an empty refresh-script terminator from `);;` to `);`; test it as a candidate,
but do not describe it as merged until Git confirms that.

The protected dirty checkout included uncommitted changes in
`DATABASE/views.SQL`, `main/R/pdf_todo.R`, several inspector proposal files,
and focused tests. Do not reset, clean, stage, commit, or overwrite those
files. If a candidate needs changes, create a new clean worktree from the
selected baseline and apply only the intended patch there.

#### Local inputs and installation

Use the supplied local current-season SQL/RDS dump and the separate historic
`BADOatNZ.CAPTURES` and `BADOatNZ.SEX` inputs. Confirm that the current-season
dump contains the base tables and `settings.reference_date`; do not treat
dumped derived views as authoritative. Import everything into a disposable
MariaDB 11.8.9 instance with a unique socket, data directory, PID file, and
error log under ignored temporary storage. Use `--no-defaults` and
`--skip-networking` unless a narrowly scoped local test requires otherwise.
Do not reuse an existing service or datadir.

Install the selected schema in dependency order using the repository SQL:
base/support tables, functions, hatching support, then `DATABASE/views.SQL`.
Run the refresh script separately. Do not combine the installer and refresh
in one unbounded Adminer-style paste while diagnosing performance. Record
elapsed time, statement/stage boundaries, row counts, and the local MariaDB
error log after every stage.

#### What happened remotely

The failing production/Adminer paste was a very large `views.SQL` execution.
Adminer reported MariaDB error `2006` (“server has gone away”) and later
statements produced cascading errors because the original connection was
already dead. This is not proof that the first visible red line was the root
SQL syntax error, and it is not proof that the refresh/publish stage ran.

At one point `SHOW FULL PROCESSLIST` showed a `CREATE OR REPLACE VIEW` for the
historic capture compatibility layer waiting for a table metadata lock for
roughly two minutes. A second Adminer connection timed out. Other checks
later showed only the Adminer query and an idle connection. The administrator
was unavailable, so there is no confirmed OOM/restart/OS-log diagnosis.

The reported server settings were MariaDB 11.8.9, a 6 GiB InnoDB buffer pool,
256 MiB temporary-table limits, a roughly 510 MiB maximum packet, 8 MiB sort
buffer, 100 maximum connections, and `performance_schema` disabled. Later
status showed low connection counts, no aborted clients/connections, and
temporary tables including some disk-backed tables. These observations do
not prove that the server had enough memory during the failed statement.

An older refresh path also used an empty CTAS query such as
`CREATE TABLE ... AS SELECT * FROM TODO_LIST_CALCULATE WHERE 1 = 0`. MariaDB
still expanded the large task view to infer its schema. The intended fix is
explicit snapshot DDL and indexes, not another schema-inference query.

#### Architecture to reproduce and preserve

The remote optimized architecture separates:

1. **Install layer:** `DATABASE/views.SQL` defines compatibility, identity,
   nest, brood, hatch, parent-input, closure, status, and public-boundary
   views. It should not compile the entire task graph as one giant live view.
2. **Refresh layer:** `DATABASE/refresh_todo_list_snapshot.SQL` materializes
   reference-date-specific inputs and tasks into explicitly defined,
   indexed `_BUILD` tables, then atomically promotes them only after all
   stages succeed.
3. **Application layer:** `main/R/system_utils.R`, `main/server.R`, and the
   UI button run the refresh asynchronously, report stage/status, and only
   allow a PDF when the published snapshot is current for `settings`.

The expected refresh stages are nest context, brood context, chick-capture
context, hiding-spot photos, GPS-linked chick/parent evidence, parent status,
brood closure, task rows, and publishing. The exact names must be read from
the selected revision. Existing public snapshots must remain available while
BUILD tables are populated. Use `_PREVIOUS` and one atomic promotion step;
never drop the published output first and hope the replacement succeeds.

Be alert to the revision-specific `);;` empty-statement typo near the task-row
boundary in the current checkout's refresh script. If reproduced, confirm
whether the client stops there and whether it prevents publication. Test the
single-character fix independently from larger SQL changes.

#### Biology and output contracts that must not regress

Preserve the five-source hatch chronology and reference-date behavior, the
positive/negative brood distinction, and the parent evidence hierarchy. The
four parent gates must remain intact; the GPS-linked chick-parent evidence is
an additional evidence stage, not permission to weaken the original gates.
Canonical adult identity layers must include nestless captures and
nestless resightings, while ambiguous GPS/mark matches remain unresolved.
Association behaviors include `IN`, `NM`, `SC`, `BW`, `BC`, `FC`, and `AC`
(`Alert with chick(s)`). Preserve sex-aware identity matching, chronology,
MM follow-up, 7-day clutch-completion gate, and separate 36-hour disturbance
gate.

Preserve these task contracts:

- parent capture and parent resighting work remain distinct, with blocked
  captures able to appear as resight-only work;
- negative broods can generate parent work, banding, hiding-photo, and
  flagging work without fabricated NESTS rows;
- H-photo completion counts distinct valid age-C chick rings from qualifying
  H-class RESIGHTINGS, not duplicate rows or capture-handling photos;
- asynchronous hatch checks retain the `unhatched egg(s)` note;
- missing-parent resighting retains `not yet floated` when hatch timing is
  unavailable;
- negative-brood age uses days since discovery in task/PDF display and age
  gates;
- `Broods to recapture for flagging` is a dedicated task for chicks aged at
  least 21 days, recapture and unique engraved UL-flag assignment, with the
  same brood-oriented columns/table structure as `Broods to photograph`;
- a decrease in recorded clutch size caused by egg removal must not reset or
  unnecessarily delay the parent-capture 7-day clock. Historical maximum
  clutch size and its start datetime are used for that gate;
- the PDF map and final parent summary include eligible negative broods when
  valid location data exist, and the summary displays discovery-age hatch
  values when hatch date is unknown.

Use `tests/testthat/test-todo-view-rules.R`,
`tests/testthat/test-todo-refresh-worker.R`, `tests/testthat/test-pdf-todo.R`,
the map tests, and the current local PDF as contracts. Do not use a visually
plausible PDF as the only test: compare task IDs, task classes, notes, marks,
priorities, hatch/age fields, map coordinates/source, brood labels, and parent
summary membership.

#### Required local experiment

1. Rebuild the disposable database from the selected revision and verify base
   table/view inventories without printing raw rows.
2. Run `views.SQL` alone and measure each statement or safe batch. Confirm it
   completes without asking MariaDB to expand a monolithic task view.
3. Run `refresh_todo_list_snapshot.SQL` alone and record each stage's elapsed
   time, row counts, temporary-table behavior, and error-log messages.
4. Verify that BUILD tables are populated before promotion, that public
   snapshots retain the previous version on an induced failure, and that the
   new reference date is published only after all required stages succeed.
5. Render the PDF locally for the supplied reference date and compare it with
   the known-good PDF. Inspect the task tables, flagging table, map, negative
   broods, parent summary, labels, and footer.
6. Profile the slowest local stage using `EXPLAIN`, `EXPLAIN FORMAT=JSON`,
   row-count diagnostics, and temporary-table counters where safe. Prefer
   materializing bounded, indexed context once over rewriting biological
   predicates.
7. If optimizing, preserve the four-gate parent SQL and compare before/after
   outputs row by row. Do not deploy an optimization that only matches the
   total row count; all task fields and map/PDF inputs must match.
8. Test the exact Adminer/deployment-shaped sequence separately: install
   succeeds, refresh succeeds, and ordinary PDF download does not execute the
   expensive task graph.

#### Deliverables and stopping rules

Return a sanitized report with: selected revision, clean/dirty state, local
MariaDB version, install timing, per-refresh-stage timing, object inventory,
failure statement if any, error-log diagnosis, before/after row-count
comparison, PDF/map comparison, and remaining uncertainties. Keep logs and
generated PDFs in ignored scratch storage. Do not commit or push without an
explicit request.

Stop and report rather than guessing if the local dump lacks a required base
table/column, if the selected revision does not match the expected task
contract, if a refresh stage fails before publication, or if the local output
differs biologically from the known-good baseline. In each case preserve the
reproducible failing command and propose the smallest safe next experiment.

### End paste-ready prompt

Known gaps in this reconstruction: the exact original Adminer error line and
server-side cause were never captured, and the full original conversational
history is not stored in this sanitized log. The local replica and controlled
stage timings are therefore the authoritative next diagnostic step.

## 2026-09-30 - Exact - Thread 4 documentation reconciliation

Request: refresh the Thread 4 to-do/map/list/PDF operational reference against
the current repository, preserving the distinction between checked-out source,
dirty local work, remote Git state, database deployment, and live verification.
Update only the ignored Thread 4 proposal and prompt-log documents.

Inspected the local `main` checkout at `fc86bf0`, the remote comparison at
`dd26127`, the Thread 1/2/3/3.1/4/5/6/8 documentation, SQL view definitions,
Shiny wiring, PDF/map/list helpers, template, help text, and focused tests.

Updated:

- `notes/codex_proposals/THREAD4_TODO_MAP_LIST_DEBUG_PLAN.md`
- `notes/codex_logs/THREAD4_PROMPT_LOG.md`

The refreshed memo documents the current five-source hatch hierarchy, positive
and negative brood behavior, parent capture/resight/MM rules, hiding-photo ring
requirements, live-map versus PDF inclusion differences, PDF summary/map
contracts, task inventory, available-combo/KMZ boundaries, test evidence,
deployment order, rollback, and cross-thread handoffs.

Important discrepancy recorded: the pre-existing dirty `DATABASE/views.SQL`
references `RESIGHTINGS_H_BROOD_ASSOCIATIONS` without defining that helper
view. It was not repaired because this task authorized documentation only.
Focused PDF, live-map, and server tests passed; the TODO static-rule test has
one expected working-tree failure caused by that unresolved dirty SQL reference.

This was the status of that earlier checkout only. It is superseded by the
current checkout, where `RESIGHTINGS_H_BROOD_ASSOCIATIONS` is defined in
`DATABASE/views.SQL`; see the 2026-10-05 documentation refresh below.

No tracked operational source, database, Git history, deployment, or live
process was modified.

## 2026-10-04 - Exact - Hatch prediction fallback alignment

Request: add no-float chronology support for complete clutches and stable
one-egg/no-increase clutches, and make the PDF parent summary consume the same
reference-date prediction as `TODO_LIST`.

Updated the local SQL/PDF implementation and focused invented-data/static tests.
The one-egg rule requires two full days without an increase, then applies the
two-day laying interval and 26-day incubation interval. Existing flotation,
found-incomplete, observed-hatch, task-row, and brood behaviors remain
precedence-controlled. No real rows, coordinates, credentials, database
connections, commits, pushes, or deployments were used.

## 2026-10-05 - Exact - Brood-photo protocol clarification

Updated the ignored Thread 4 handoff to document the current `Broods to
photograph` contract: counts are per positive nest or negative brood, compare
distinct valid age-C capture rings with distinct qualifying H-photo rings,
retain the task through day 6, and report ratios such as `2/3 chicks with
rclass 'H' photos`. Clarified that CAPTURES handling photos do not resolve the
H-photo task, that same-occasion capture and H rows remain separate, and that
`Nests to process` uses NESTS nest/tent-photo flags and EGGS flotation evidence
instead. No source files, databases, live records, coordinates, or deployed
views were changed.

## 2026-10-05 - Exact - Processing-history and PDF-planning documentation refresh

Request: document the simplified TODO processing and PDF query-planning work
from commit `8796dd6` and follow-up `0899b11`, together with the recent Thread
4 protocol updates, without changing application code.

Updated the ignored Thread 4 handoff to describe the history-wide processing
CTEs, the separate NESTS-photo and EGGS-float evidence, the three operational
processing notes, the preserved `Re-process nest` pathway, the unified
`BROODS_LATEST` hatch-follow-up source, and the projected `TODO_LIST` query
with `derived_merge_off = TRUE` used by `todo_pdf_save()`. Clarified that the
query-planning change reduces MariaDB planning/memory pressure without moving
task eligibility into R, and that mobile-server behavior still requires live
resource verification.

Also corrected stale handoff claims: the current SQL defines
`RESIGHTINGS_H_BROOD_ASSOCIATIONS`, the current PDF footer uses shared dynamic
Git-version resolution, and the local checkout/branch/commit status is
distinct from database deployment or Shiny live verification.

No app code, SQL, tests, database, Git history, deployment, credentials, real
rows, or coordinates were changed. Only the ignored Thread 4 proposal and
sanitized prompt log were updated.

## 2026-10-06 - Exact - Parent capture/resighting handoff refresh

Request: update the Thread 4 protocol so a new agent can reproduce the current
reasoning for `Parents to capture` and `Parents to resight for nest
association`, including MM follow-up, already-banded resighting uncertainty,
7-day and 36-hour gates, note formats, ranking, chronology, and removal rules.

Updated the ignored Thread 4 handoff to document the current adult-parent CTE
chain, sex-aware LL/LR identity matching, spacer-dependent identities,
association behaviours `IN`, `NM`, `BW`, `BC`, and `FC`, the three-resighting
threshold including the initial event, direct TN association, alternate-parent
displacement, timing-blocked capture rows, MM notes such as `MM cap M with 1
resighting`, generic notes such as `M with 1 resighting`, PDF ranking, and
invented chronology examples. It also records that the current combined
male-and-female MM aggregation retains a legacy `M&F had MM cap` note rather
than displaying both dynamic sex-specific counts. The handoff now distinguishes
current dirty local WIP from committed, deployed, or live-verified behavior.

No application source, SQL, tests, database, Git history, deployment,
credentials, real rows, or coordinates were changed in this documentation-only
refresh.
