# Thread 8 — unlinked H-event reconciliation

This tracked note records specialist responses reviewed by Thread 8. The
original reconciliation below is historical; its implementation-gap statements
must not be read as a current inventory of repository SQL. No local source
review establishes deployment or live inspector state.

## Current approved contract — 26 October 2026

- Keep save-time validation, derived association and To-Do resolution separate.
  `RESIGHTINGS_H_BROOD_ASSOCIATIONS` and the S10 task helper now exist in
  repository source. A valid saved row is not by itself proof of task closure.
- An H photograph remains its own age-C RESIGHTINGS event, with nonblank
  metal ring, complete direct GPS and its own photo metadata. A capture/tent
  photograph remains a separate CAPTURES event. Preserve raw nest IDs and
  observed marks; matching/normalisation must not rewrite field observations.
- Family encounters share date, site, gps_id and gps_point. Enter every
  individual actually encountered, including observed X-X parents; never
  fabricate chick sightings alongside genuine captures or an absent mate.
- Conflicting nonblank nest/brood IDs within that same family occasion must
  be flagged during entry, including explicit IDs and split-table companions.
  This is not a lifetime single-nest restriction: actual associations may
  change between separate encounters, including brood mixing.
- A question mark in any leg segment excludes that event from parent–nest
  association evidence unless a known metal ring is reliably traced to capture
  identity history. That ring exception overrides uncertainty about colour
  marks; preserve the question marks. Knowing an old ring/mark does not itself
  prove the current nest, and a prior season's nest ID is not a current link.
- The former no-nest sentinel is retired. An unrelated adult capture uses
  blank nest_id and both GPS fields. This is distinct from a negative brood
  link or an eligible blank-ID family inference; no replacement sentinel is
  introduced and historical records are not automatically rewritten.

The current correction pass is uncommitted and subject to source-frozen
validator/SQL/output verification. Read the reviewed protocol and specialist
handoffs for exact predicates; do not imply that a local correction is merged,
installed or live. The private manual is under concurrent human review and
must not be regenerated or overwritten by the implementation work.

## Historical reconciliation record

## Converged architecture

The proposed solution has three distinct layers:

1. **Save-time H-row validation**: age C, rclass H, nonblank `RESIGHTINGS.ring`, complete H photo metadata, and direct `gps_id`/`gps_point` including positive-nest H rows.
2. **Derived family association**: a shared helper view identifies whether an unlinked H event can be assigned uniquely to a positive nest or negative brood from prior chick/parent evidence and same-occasion GPS.
3. **Operational task resolution**: `BROODS_LATEST` and `TODO_LIST` consume the derived association without changing raw `RESIGHTINGS.nest_id`.

Suggested helper view: `RESIGHTINGS_H_BROOD_ASSOCIATIONS`.

Suggested statuses: `explicit`, `derived`, `ambiguous`, and `unresolved`.

## Historical gaps identified before implementation

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
