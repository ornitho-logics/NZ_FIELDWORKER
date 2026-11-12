# Codex use and task handoff transparency

12 November 2026 publication update: Luke requested restoration of the core/full
English/German manuals and eight Overview panels, retaining Mihai's newer
phenology panel, Data issues tab, and validator wiring. The restored source
matches the dated archives; the archives and authorship/AI disclosures remain.
The copyright notice was removed separately and is not reintroduced.
The notA summary is also restored from its unchanged source archive. Validator
selection guidance and catalogs are GitHub documentation only; no app controls
or live inspector changes are introduced. See the
[restoration record](../docs/APP_FEATURE_RESTORATION_2026-11-12.md) for checks and
limits. No field data, server configuration, or live database was accessed.

8 November 2026 publication update: at Luke Eberhart-Hertel's request, the core
guide and full manual were withdrawn from the app. Their English/German
sources, rendered readers, shared assets, and renderer remain unchanged in a
[checksummed archive](../docs/field-manual-archive/2026-11-08/README.md), including
the authorship and AI-use disclosures. Reconstruction resources remain intact.
This records a source change, not agent deployment to the field server.
The same withdrawal also archives the eight-panel Overview dashboard and
notA summary; current app registrations and chart polling are removed, while
preserved source and reconstruction references remain available. No live
database view or biological record is deleted by these source changes.

Current reconstruction addendum: 2026-11-01. Earlier publication chronology below
retains its dates and does not define current deployed state.

`docs/reconstruction/` now collects the current reference contract, adaptation
decision intake, machine-readable role/DAG recipe, rule crosswalk, acceptance
requirements, and captured dependency metadata. `tools/reconstruction/` contains
development-only validators and an owned no-network synthetic bootstrap. These
are intentionally tracked reviewed artifacts; generated reports, server files,
PDFs, and synthetic runtime evidence remain ignored. The kit changes no app
runtime or operator workflow and neither grants live access nor publishes data.
See its README for exact checked and missing verification scopes.

Separate 31 October follow-up: Luke explicitly resolved the MM chronology
question and approved capture-mark field-description alignment. That later
candidate changes the parent-association SQL and manual wording, plus eight
source comments and a read-only live-comment patch generator; it is not part
of the earlier runtime-unchanged reconstruction verification. It uses only
invented local checks, changes no validator or raw field records, and grants
no live installation or publication authority. See the reconstruction
chronology contract and follow-up verification record for precise scope.

On 1 November Luke clarified the targeted same-day first-banding exception:
confirming X-X evidence and a unique eligible same-sex/nest first capture on
that date identify the targeted bird without later resightings. This supersedes
the earlier blanket refusal to link same-day evidence, not the different-day
X-X safeguards or independent timing/tag gates. Code, invented regression cases,
manual, and machine-readable reconstruction contracts are updated together;
dated verification records keep their original source identities and limits.
The preceding narrowly authorized local trace remains private; no raw field
records are included in the reconstruction package or these summaries.

Historical reconciliation: 2026-10-23

## Purpose

This document explains how Codex was used in the 2026 NZ FIELDWORKER project,
what artifacts it produced, how specialist threads divide responsibility, and
which evidence is intentionally excluded from Git. It supports collaborator
review and allows a replacement thread to resume work without treating an AI
summary as deployed truth.

`AGENTS.md` remains the controlling human-control, confidentiality, Git, and
database-safety policy. The collaborator-controlled `main` branch and reviewed
source remain authoritative.

## Human control

Codex may inspect, propose, document, and run approved local/mock checks. It may
edit, commit, and push only when the user explicitly authorizes those actions.
PR review, merge, production deployment, live database changes, permits,
animal-welfare decisions, and field actions remain human-controlled.

No tracked handoff or local test proves that a view, validator, database,
Shiny process, or field protocol has been deployed. Documents label source,
mock/local replay, protected WIP, and live state separately.

## Public disclosure, synthetic development, and privacy limits

The manual's authorship statement links this record, `AGENTS.md`, the
[sanitized prompt/decision index](codex_logs/INDEX.md), and the
[specialist handoffs](codex_proposals/). For implementation detail, read the
[validator architecture and mock workflow](codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md#mock-data-and-tests),
[reviewed inspector exports](codex_proposals/validator_sandbox/inspector_lists_by_table/),
[To-Do/map/PDF contract](codex_proposals/THREAD4_TODO_MAP_LIST_DEBUG_PLAN.md),
and [reconstruction/verification guide](../docs/reconstruction/README.md).
[Invented connected fixtures](../tools/reconstruction/fixtures.sql) and the
development-only runner make a small synthetic workflow reproducible. Some
older working mock spreadsheets, raw conversations, and generated diagnostics
remain private; the public record is a curated account, not an exhaustive archive.

The initial validator/data-entry development workflow used connected invented
mock fixtures with passing, failing, and boundary cases. Those tests did not
require real field records as fixtures. This must not be conflated with later
operational troubleshooting: Luke Eberhart-Hertel explicitly authorized local
copies of field snapshots and also supplied selected real-case examples and
screenshots in AI conversations. Local processing, public GitHub publication,
and disclosure to an AI service are different boundaries. Luke Eberhart-Hertel
clarified that the snapshots covered part of the field season and that the
complete season's dataset was never included in a prompt. Selected real examples
and summaries were discussed with the AI; larger database checks ran locally.
This is his account of the development workflow, not an independent audit of
provider-side transmission, retention, or model training. Development/testing
exercises should not be described as training an AI model.
No confidential examples or record values are reproduced in this disclosure.

Luke Eberhart-Hertel retained source review, merge, and deployment control and
performed field-server code/SQL/inspector installations manually, as he
confirmed in the project workflow. Agents were not authorized to autonomously
access or deploy to the field server. Authorized source edits, Git publication,
and isolated local test execution are distinct from production deployment.
Credentials, full confidential snapshots, sensitive locations, and raw operational
material are excluded from the public transparency resources. This states the
documented controls and their scope, not a claim that every possible system
event or third-party service has been independently audited.

## Specialist structure

- Thread 1 maps the repository and maintains cross-thread ownership/read order.
- Thread 2 owns schema, views, functions, support tables, and migration risk.
- Thread 3.1 owns save-time validation, protocol YAML alignment, inspector
  architecture, and mock validator workflows.
- Thread 4 owns TODO/list/map/PDF task semantics and field-facing task output.
- Thread 5 owns the eight-panel Overview dashboard.
- Thread 6 owns available colour-combination generation and safe assignment.
- Thread 7 owns private seasonal geolocator rollout planning; only its
  sanitized method is tracked.
- Thread 8 owns the field manual and translates reviewed technical contracts
  into field procedures.
- Thread 9 owns disposable MariaDB replay, staged refresh diagnostics, and
  local render verification, not biological semantics.

## Tracked recovery artifacts

The repository tracks:

- `AGENTS.md`;
- Thread 1-9 specialist handoffs under `notes/codex_proposals/`;
- sanitized prompt/decision summaries under `notes/codex_logs/`;
- the reviewed validator inspector-list exports;
- this transparency record.

The prompt summaries use these provenance labels:

- `Exact`: visible wording or a directly recorded decision;
- `Partial`: condensed from an available response or private artifact;
- `Reconstructed`: inferred from source history and durable handoffs.

They are chronology aids, not rule authority. When a prompt summary conflicts
with current source or protocol, the current authority order in `AGENTS.md` and
the owning specialist handoff controls.

## Intentionally excluded artifacts

The following remain ignored and must not be committed:

- raw prompts, raw model responses, screenshots, and attachments;
- unpublished Thread 8 field-manual drafts, renders, and artifact metadata;
- database dumps, RDS snapshots, workbooks, generated reports, and previews;
- credentials, connection details, `.cnf` files, and private URLs;
- raw field rows, bird/ring/tag/nest identities, and GPS coordinates;
- Thread 7 ranked-candidate reports, biological overrides, dated inventory
  states, and operational allocations;
- temporary MariaDB data directories, logs, sockets, and generated test PDFs;
- unrelated dirty implementation experiments.

This exclusion is part of transparency: it states what Codex used locally
without publishing confidential research data or credentials.

## Development and verification pattern

Specialist work followed this pattern where applicable:

1. Read `AGENTS.md` and record Git/source state.
2. Inspect current source before relying on prior conversation summaries.
3. Preserve unrelated user work and use topic branches/worktrees.
4. Use invented or approved local/mock data for validation.
5. Distinguish findings, proposed behavior, implementation, local test results,
   merged source, and live deployment.
6. Record risks, rollback, and verification instructions.
7. Require human review before merge or deployment.

Thread 9 used an isolated local MariaDB replica for schema/refresh diagnosis.
Thread 8 used a render-inspect-iterate workflow for the DOCX manual. Neither
workflow authorized changes to the live database.

## Restart sequence

A replacement Codex thread should read:

1. `AGENTS.md` and current Git status/revision;
2. `notes/CODEX_USAGE_TRANSPARENCY.md`;
3. `notes/codex_proposals/THREAD1_REPOSITORY_MAP.md`;
4. the owning specialist handoff;
5. current source and focused tests;
6. the relevant sanitized prompt log only for chronology.

The replacement thread must report discrepancies before changing behavior and
must not infer live deployment from documentation, a local dump, or a passing
mock/replay.

## Documentation PR boundary

The documentation publication branch was created from the then-current
`origin/main` at `f7d13fb`. It intentionally excludes the separate protected
dirty checkout containing experimental SQL, PDF, validator-export, and test
changes. The publication branch changes documentation and manual artifacts
only.
