# Thread 9 prompt and decision log

This is a sanitized, reconstructed log rather than a raw transcript. It is
tracked for Codex-use transparency because raw prompts, outputs, local paths,
dump names, field records, GPS data, and credentials have been omitted. Dates
are exact where the conversation or Git history supplied them and otherwise
marked as reconstructed from the thread chronology.

## Current request

**2026-10-23, exact user evidence:** the user reported that the corrected
Adminer refresh completed without errors and supplied a screenshot showing the
refresh stages through `publishing`.

**Current recovery objective, reconstructed from the delegated handoff:** create
restart-grade local-replica documentation covering the isolated MariaDB
bootstrap, schema installation, staged refresh, diagnostics, failure recovery,
PDF verification, ownership boundaries, and the full sanitized decision history.
This documentation pass must not change source code, SQL behavior, tests,
database contents, runtime configuration, Git history, or deployment state.

## Decision history

### 1. Local-only failure investigation — exact request, early thread

The user authorized a local reconstruction of the production Adminer failure
using supplied current-season and historic dumps. The requested controls were
an isolated MariaDB 11.8.9 instance, no production connection, no credentials,
no raw GPS/field-record leakage, preservation of the dump reference date,
statement-level timing, lock/processlist/temporary-table diagnostics, separate
views installation and snapshot refresh tests, and no source edits before the
baseline comparison.

The requested Git controls included verifying the exact pre-enhancement
baseline and its relationship to the remote history, locating the state that
produced the successful local PDF, preserving a separate control, and not
deploying or opening a PR without explicit approval.

### 2. First diagnosis — reconstructed from the thread and Git history

The investigation separated four issues that had initially been conflated:

- the historical large views installation and its MariaDB 2006/client failure;
- metadata-lock waiting during at least one DDL run;
- expensive task/snapshot computation and temporary-table cleanup; and
- later refresh/publication failures after the schema had already installed.

The previous giant live `TODO_LIST_CALCULATE` view was identified as an
unnecessary DDL-time risk. The optimized architecture moved the expensive task
assembly into the explicit staged snapshot refresh and kept public snapshots
available until successful promotion.

### 3. Snapshot and PDF hardening — reconstructed

The work then established explicit `_BUILD`, public snapshot, and `_PREVIOUS`
roles; a refresh status table; reference-date checks; fail-closed PDF behavior;
dependency-free PDF page counting; and a keep-tables-together layout that falls
back to the compact layout if it would create an unwanted fifth page.

The PDF work also introduced the current field-facing ordering, map/summary
layout, labels/legend, current last-visit and hatch explanations, brood-work
label hierarchy, and current team-mark presentation. Those semantics belong to
Thread 4; Thread 9 only verifies that a selected revision can reproduce them.

### 4. Biological and field-protocol corrections — reconstructed

Several rounds of local PDF and SQL review corrected brood-band/photograph/
flagging logic, unhatched-egg notes, latest chick encounter counts, negative
brood handling, nest-processing timing, parent-association evidence, closure
logic, presumed-dead brood auditing, renesting evidence, and parent-capture
eligibility. The user repeatedly required that parent-resighting evidence and
existing behavior-class interpretation remain unchanged unless explicitly
approved.

The agreed presumed-dead approach remained separate from the existing parent
association layer: no new public RESIGHTINGS event and no new public `notA`
task. Later positive nest evidence, dual-parent matches, authoritative
single-parent matches, spatial corroboration, negative-observation evidence,
reactivation, and evidence provenance were audited before integration. The
exact biological rules and row-level examples are intentionally omitted here
to avoid recording confidential field identifiers; consult Thread 4 and the
reviewed source/tests for approved semantics.

### 5. PDF visual verification — reconstructed

The user requested repeated full-page PNG/PDF checks, including rotated map
layout, satellite imagery for a local render, smaller labels/symbols, map-label
padding, legend examples, centered table cells, adaptive table page breaks,
updated subtitles, dynamic note keys, current task ordering, and version
traceability. The local render became the visual control, but it was never
treated as proof of live deployment.

### 6. Deployment-aware version label — reconstructed

The app had previously displayed a stale local commit identifier. The resolved
design distinguishes local preview mode from production: local previews may
show `local-<commit>`, while production prefers the current public main ref,
then trusted build metadata, then a clean main checkout. The legacy stale
environment fallback was intentionally excluded. The runtime polls the
resolver so a merged main revision can become visible without relying on an
old startup value.

Thread 9 must document the revision used for a local render, but must not alter
deployment version logic as part of a database replay.

### 7. GEO deployment protocol — reconstructed

The old phenology/release-ceiling/sex-balancing deployment selector was
retired while preserving GEO history, overview reporting, authoritative parent
identity, and existing parent work. The current plan separates initial GEO
deployment from pair completion, preserves the 7-day and 36-hour gates, and
keeps unknown status distinct from `X-X`. This work is in the merged source
history and is not a Thread 9 replay decision.

### 8. Combo, inspector, and overview work — reconstructed

The thread history also includes the central inspector architecture, H-class
chick-ring methodology, Overview panel reordering/annotations, available
combo normalization and ranking, new combo placement, photo-overlap
validation, and PDF table/legend alignment. Their owners and handoffs are
recorded in the owning specialist handoffs. Thread 9 should only load their
tracked source and verify that a local database replay does not obscure their
behavior.

### 9. Adminer refresh incident — exact technical correction

The user reported that an Adminer import of the refresh file showed many
successful statements but ended with `Error 1065: Query was empty`; a status
query then showed the newest refresh as `running` with no completion time or
task count. Static inspection of the exact repository file located a doubled
statement terminator immediately before the `publishing` stage. Adminer with
“stop on error” can treat the second terminator as an empty query and stop
before publication.

The one-character fix was prepared as commit `ad1698b` and later merged to
`origin/main` through PR #147 at merge commit `f7d13fb`. The optimized views
source was not changed by that fix. A local replay
of the corrected refresh reached all stages, produced a successful status row,
and matched the published task count in the disposable replica. The user then
reported a clean Adminer import and showed all stages through publication.

This incident is therefore recorded as a refresh-script client/statement
boundary problem, not evidence that the removed `TODO_LIST_CALCULATE` view has
returned. The source fix is merged; deployment still requires the user's
separate normal process, and the screenshot alone is not a deployment record.

## Artifacts and revisions referenced by this log

- `origin/main` at the publication inspection: `f7d13fb`.
- Latest merged note/legend alignment commit in the recent history: `9288147`.
- Refresh empty-statement fix: `ad1698b`, merged by PR #147 as `f7d13fb`.
- Active dirty checkout at inspection: `codex/split-todo-calculator-2026-10-19`
  at `d3c7bd4`; intentionally not modified or staged during this recovery pass.
- Local PDF control: an origin/main-based worktree rendered the current local
  task PDF with the rotated map/summary layout and the current visual contract.
  Generated PDF/PNG paths are omitted from this tracked-style log.

## Corrections and superseded directions

- Do not use an old dirty worktree as the latest source merely because its
  filename resembles the desired source file.
- Do not treat dumped view definitions as authoritative.
- Do not conflate the old view-installation failure with the later refresh
  empty-statement error.
- Do not infer production deployment from a local render or from a GitHub PR
  branch existing.
- Do not reinstate `TODO_LIST_CALCULATE` to make the refresh easier to inspect.
- Do not let a stale status row, old snapshot, or mixed live/reference-date
  source produce a PDF that is reported as current.
- Do not broaden parent behavior-class interpretations while investigating
  local refresh performance.
- Do not include raw data, bird/nest identifiers, GPS coordinates, credentials,
  or full Adminer URLs in this log.

## Prompt-history coverage

This reconstruction covers the complete decision arc visible in the active
Thread 9 conversation: local-replica authorization; Git/baseline comparison;
Adminer views failure diagnosis; snapshot architecture; PDF and map revisions;
presumed-dead brood audit and renesting planning; GEO deployment planning;
version-label troubleshooting; current-origin/PR safety; latest-dump local
renders; status-table health checks; and the final Adminer refresh correction.
Exact raw prompt text is intentionally not reproduced. Where a date or artifact
was inferred from commit history or screenshots, it is labelled reconstructed
above rather than presented as an exact timestamp.

## Handoffs and open risks

Thread 4 needs aggregate local replay evidence, not raw rows, for any task or
PDF regression. Thread 2 needs SQL-stage timing, object inventory, and lock or
temporary-table evidence for schema changes. Thread 3.1, Thread 5, and Thread
6 should be consulted when a replay difference touches validators, Overview
outputs, or combo allocation.

Remaining risks are live deployment drift, Adminer timeout/permission
differences, unknown historical OS-level memory evidence, external consumers
of retired compatibility views, and user-selected reference-date mismatches.

No application, SQL, database, test, or runtime behavior was changed by this
documentation recovery pass.
