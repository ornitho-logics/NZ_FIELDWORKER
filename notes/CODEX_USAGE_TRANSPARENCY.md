# Codex use and task handoff transparency

Last reconciled: 2026-10-23

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
