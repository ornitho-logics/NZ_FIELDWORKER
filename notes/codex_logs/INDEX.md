# Codex prompt and decision summary index

Last reconciled: 2026-10-23

## Purpose and privacy boundary

This tracked directory contains sanitized prompt and decision summaries for
Threads 1-9. It supports task handoff and transparency about Codex use without
publishing raw prompts, raw model responses, attachments, credentials, field
rows, bird/ring/tag/nest identities, private rollout rankings, or GPS data.

The summaries are chronology aids. They are not source authority, biological
data, or evidence of deployment. Read `AGENTS.md`,
`notes/CODEX_USAGE_TRANSPARENCY.md`, and the owning specialist handoff first.

## Confidence labels

- `Exact`: visible wording or a directly recorded decision.
- `Partial`: condensed from an available response or private artifact.
- `Reconstructed`: inferred from handoffs, source history, and artifact dates.
- `None found`: no reliable thread-specific history was available.

## Log inventory

- `THREAD1_PROMPT_LOG.md`: repository mapping, governance, recovery, and final
  cross-thread synchronization.
- `THREAD2_PROMPT_LOG.md`: schema/view/function architecture and migration-risk
  history.
- `THREAD3_PROMPT_LOG.md`: combined Thread 3 to Thread 3.1 validator lineage,
  protocol progression, and documentation recovery.
- `THREAD4_PROMPT_LOG.md`: TODO/list/map/PDF history and local-replica handoffs.
- `THREAD5_PROMPT_LOG.md`: Overview dashboard evolution and current eight-panel
  contract.
- `THREAD6_PROMPT_LOG.md`: combo-list ownership, normalization, and availability
  documentation.
- `THREAD7_PROMPT_LOG.md`: public sanitized GEO rollout decision chronology;
  private reports and candidate details are excluded.
- `THREAD8_PROMPT_LOG.md`: field-manual orientation, authoring, correction, and
  verification history.
- `THREAD9_PROMPT_LOG.md`: local MariaDB replay, staged refresh, diagnostics,
  and source-merge chronology.

## Specialist handoffs

- `THREAD1_REPOSITORY_MAP.md`
- `THREAD2_SCHEMA_REVIEW.md`
- `THREAD3_VALIDATION_ARCHITECTURE.md`
- `THREAD4_TODO_MAP_LIST_DEBUG_PLAN.md`
- `THREAD5_OVERVIEW_DASHBOARD_PLAN.md`
- `THREAD6_COMBO_LIST_PROTOCOL.md`
- `THREAD7_GEOLOCATOR_ROLLOUT_HANDOFF.md`
- `THREAD8_H_EVENT_RECONCILIATION.md`
- `THREAD8_TEMPLATE_DISTILLATION.md`
- `THREAD9_LOCAL_REPLICA_PROTOCOL.md`

Thread 8's tracked files document its role, template method, and technical
handoff. Working field-manual DOCX/PDF artifacts remain private and ignored
until the user explicitly approves publication.

## Cross-thread lineage

Thread 3 is the predecessor of Thread 3.1; treat their logs as one validation
lineage and use the current machine-readable validator protocol as rule
authority. Thread 3.1's manual documentation recovery completed successfully.
Dirty inspector-list changes from the protected experimental checkout are not
approved or deployed by this documentation PR.

Thread 7 is the seasonal GEO rollout specialist, not the former generic tutor
placeholder. Its tracked handoff contains reproducible method only. Private
dated reports, overrides, inventories, and identities remain ignored.

Thread 8 completed a private field-manual authoring pass. The draft remains
unpublished; its existence does not prove live deployment or authorize later
publication.

Thread 9 documents local replay and confirms that the refresh terminator fix
was merged through PR #147 at `f7d13fb`. Source merge is not proof of production
deployment.

## Restart reading order

1. `AGENTS.md` and the current Git status/revision.
2. `notes/CODEX_USAGE_TRANSPARENCY.md`.
3. `THREAD1_REPOSITORY_MAP.md`.
4. The owning specialist handoff and current source/tests.
5. The relevant sanitized prompt summary for chronology only.

## Maintenance rule

Append future milestones using the confidence labels above. Record the request,
decision, affected artifact classes, checks, and deployment boundary. Replace
real identifiers with invented examples or omit them. Never commit raw prompts,
attachments, database extracts, coordinates, credentials, or private rollout
states merely for completeness.
