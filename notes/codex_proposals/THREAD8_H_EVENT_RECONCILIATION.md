# Thread 8 — unlinked H-event reconciliation

This tracked note records the specialist responses reviewed by Thread 8. No
RDS, live database, inspector, or SQL object was modified by the reconciliation.

## Converged architecture

The proposed solution has three distinct layers:

1. **Save-time H-row validation**: age C, rclass H, nonblank `RESIGHTINGS.ring`, complete H photo metadata, and direct `gps_id`/`gps_point` including positive-nest H rows.
2. **Derived family association**: a shared helper view identifies whether an unlinked H event can be assigned uniquely to a positive nest or negative brood from prior chick/parent evidence and same-occasion GPS.
3. **Operational task resolution**: `BROODS_LATEST` and `TODO_LIST` consume the derived association without changing raw `RESIGHTINGS.nest_id`.

Suggested helper view: `RESIGHTINGS_H_BROOD_ASSOCIATIONS`.

Suggested statuses: `explicit`, `derived`, `ambiguous`, and `unresolved`.

## Current gap confirmed

- `BROODS_LATEST` and `TODO_LIST` currently exclude H rows with blank raw `nest_id`.
- The current H validation exception does not require prior family-link evidence.
- The current positive-nest GPS branch can allow a positive-nest H row to omit direct GPS, which conflicts with the approved field methodology.
- Existing `test-hiding-spot-ring.R` does not cover derived associations, GPS/photo metadata, or parent matching.

## Schema limitation

`CAPTURES.parents` stores parent-sex composition rather than parent identities, and `caught_with` is not a parent-ring key. A machine-readable chick-ring-to-parent-ring relationship therefore needs to be derived from shared candidate `nest_id` plus adult identity history, or explicitly represented in a future approved data structure.

The manual must not promise task resolution until this relationship is deterministic and implemented.

## Conservative proposed association rule

For a blank-`nest_id` H event:

- require a prior age-C CAPTURES ring link to one candidate positive or negative unit;
- require prior adult identity evidence for the candidate social parent or parents;
- require the H chick and all family members actually resighted on that occasion to share the same `gps_id`/`gps_point` and date;
- require every known social parent for the candidate to agree when those parent identities are available;
- resolve only one candidate; otherwise leave the task open as ambiguous or unresolved;
- never use GPS alone and never overwrite raw `RESIGHTINGS.nest_id`.

Final decision: require every known social parent for the candidate nest or brood when those identities are available, whether that is one parent or both. Do not require an unobserved parent to appear in the field event.

## Manual wording consequence

Thread 8 should distinguish:

- a valid H row that may pass save validation;
- a derived family association sufficient to resolve the hiding-photo task; and
- the current implementation, which does not yet perform that derived resolution.

No statement should claim that the current deployed app resolves the unlinked case until the helper view, TODO/BROODS integration, tests, and deployment are verified.

## Private draft update record — 2026-10-23

The separate private field-manual draft documents the approved unlinked-H
exception without claiming that it is already deployed. It states that a
blank `RESIGHTINGS.nest_id` is permissible only after an earlier CAPTURES
event linked the chick ring(s) and social-parent ring(s), and when the current
occasion contains the parent/family evidence at one complete GPS pair. Every
social parent actually observed or identifiable in the event must be entered:
one parent is sufficient when only one is observed or identifiable; both are
required when both are available; an unobserved parent is not fabricated or
required.

The private draft also separates three questions for fieldworkers and reviewers:

1. whether the H row itself is a valid age-C, ring-bearing, direct-GPS,
   photo-linked RESIGHTINGS event;
2. whether the family evidence is sufficient for a deterministic derived
   association; and
3. whether the helper view and reference-date TODO refresh have actually been
   deployed to the target database.

The third question remains an implementation/deployment boundary. The private
draft does not promise that entering a blank ID will close a task in the
current live system. The draft and rendered outputs are not tracked or approved
for publication.
