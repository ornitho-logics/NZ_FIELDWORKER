# Thread 7 geolocator rollout handoff

Status: tracked, sanitized specialist handoff
Last reconciled: 2026-10-23
Scope: seasonal GEO deployment planning for Cass River Banded Dotterels

## Purpose

Thread 7 maintains the scientific method used to distribute geolocators across
sexes, nesting phenology, pair members, and first versus repeat attempts. It is
a planning and review specialist. It does not authorize a capture, write to the
database, or override the live task engine, permits, welfare decisions, weather,
or bander judgement.

This tracked handoff deliberately excludes current bird, nest, ring, tag, GPS,
inventory, and ranked-candidate details. Those operational details belong only
in ignored private reports supplied to the field lead.

## Scientific objective

The programme plans up to 100 devices, with an intended endpoint close to 50
males and 50 females and, where eligibility allows, both members of 50 pairs.
The rollout is stratified so an early nesting cohort does not consume the
allocation before later breeders are represented.

Pair completion improves information about movement, pair fidelity, renesting,
and breeding success. It is a priority after the hard identity, task, timing,
welfare, permit, current-tag, information-value, and inventory gates have
passed. It is never a waiver for those gates.

Historical phenology from Bomford and breeding evidence from Pierce are priors,
not fixed forecasts. Current-season data are right-censored at the reference
date and may differ because of weather, detection, management, demography, or
other ecological change.

## Ownership boundaries

- Thread 2 owns schema, views, functions, and migrations.
- Thread 3.1 owns save-time validation and the validator protocol.
- Thread 4 owns `TODO_LIST`, task eligibility, map/list/PDF semantics, and
  field-facing task notes.
- Thread 5 owns the Overview dashboard.
- Thread 6 owns safe colour-combination generation and assignment.
- Thread 8 owns the human field manual.
- Thread 9 owns disposable local database replay and refresh verification.

Thread 7 may propose ranking annotations for Thread 4, but the live task output
remains authoritative at the point of field action.

## Required evidence

Use a user-authorized, read-only snapshot and record its reference date. The
minimum planning inputs are:

- `settings.reference_date`;
- chronological adult `CAPTURES` identity, sex, tag, and nest-link history;
- `NESTS` chronology and first-known dates;
- `EGGS` and hatching-prediction evidence for lay-date estimation;
- adult `RESIGHTINGS` association evidence;
- current task, parent-status, and brood/nest outputs as dated operational
  evidence rather than proof of live deployment;
- separately confirmed physical device inventory.

Never import dumped derived views as source authority. Rebuild them from the
selected repository SQL when a local replay is required.

## Identity and pair reconstruction

Use chronology rather than one convenient row. Prefer a reliable metal ring,
then a reliable complete adult mark, and preserve tag-bearing identities when
later resightings omit upper-leg observations.

Generic `X-X`, `XX-XX`, blanks, or missing values do not identify a bird across
events. An explicit X-X observation may establish that one current parent is
unbanded, but it cannot link that parent to another X-X row. Ambiguous or
conflicting same-sex candidates remain unresolved.

Keep global identity/current-GEO status separate from nest association. A bird
can be globally known and tagged while still lacking enough evidence to be the
confirmed parent at a particular nest.

Use the authoritative parent-status/association pipeline where present. A
mobile-mist-net capture can create a follow-up association need; it does not by
itself establish parent identity at a nest.

## Phenology and attempt classification

Estimate a point lay date and uncertainty interval in this order:

1. direct egg chronology;
2. egg-specific float calibration;
3. incomplete-clutch or hatch back-calculation within its supported evidence
   path;
4. complete-clutch chronology;
5. nest-discovery fallback, labelled low confidence.

Retain method, confidence, lower date, point date, and upper date. Allocate
uncertain nests fractionally across weekly strata when their interval crosses a
boundary; pool strata only when data are too sparse or uncertain for weekly
ranking.

The earliest supported nest for a reliable parent is the first observed
attempt. A later nest sharing that identity is a possible repeat attempt.
Double brooding requires evidence of an earlier successful brood and a later
attempt by the same parent. Unknown identity means unresolved attempt class.

## Device chronology and inventory

Reconstruct each device history by `tag_id`, bird identity, sex, date, and
`tag_action`:

- `D`: a new deployment;
- `S`: the same device stayed on the bird;
- `N`: a replacement/new device was fitted;
- `R`: retrieval/removal;
- `O`: no tag action.

Count each distinct outgoing device first appearing on `D` or `N` once for
inventory. `S` does not consume another device. `R` ends current carriage but
does not return stock until the team confirms the physical device is reusable.
Report duplicate or conflicting histories separately.

Keep database-derived inventory and physical stock as separate evidence. Until
a discrepancy is reconciled, use the lower defensible available-stock value.

## Hard gates

A candidate enters a deployment recommendation only when all applicable gates
are open:

- active and biologically suitable nest or brood;
- known sex and reliable identity or a specifically approved capture-time
  identity pathway;
- no current GEO and no mortality or information-value exclusion;
- current task output authorizes the relevant parent capture rather than only a
  resighting/review action;
- nest-processing, seven-day, and 36-hour disturbance gates are open;
- reserve and physical inventory remain safe;
- permit, welfare, weather, bird condition, and bander judgement allow action.

At a nest with two untagged parents, release at most one parent at a time and
recheck the mate only after a fresh task/timing review.

## Allocation hierarchy

The approved hierarchy is:

1. Apply every hard gate.
2. For nests first known on or before 24 September 2026, an eligible untagged
   mate of a tagged parent has pair-completion priority over sex-by-phenology
   balancing. This never waives a hard gate.
3. Keep pair completion active while the target sex remains within its quota;
   once the female endpoint is reached, a later pair may receive only the male
   when that improves the final balance.
4. For nests first known from 25 September onward, prioritize the globally
   deficient sex, then the most deficient phenology strata and reserve need.
5. Recalculate quotas, strata, pair state, inventory, and task/timing gates
   after every deployment or retrieval.

A diagnostic score may order candidates that already pass all hard gates. It
must never override those gates or transform uncertain identity into an
eligible target.

## Output states

Use explicit states rather than a single ranked list:

- `DEPLOY NEXT`: all gates currently pass;
- `PAIR COMPLETION`: eligible mate of a tagged parent after all gates pass;
- `WAIT / VERIFY FIRST`: identity, association, inventory, attempt class, or
  timing remains unresolved;
- `BAND ONLY / NO TAG`: capture may be useful but deployment is not currently
  indicated;
- `DO NOT DEPLOY`: a hard biological, information-value, welfare, or current-GEO
  exclusion applies.

Every report must state its snapshot date, source revision, inventory basis,
uncertainty, and that field staff must recheck the live task output before
action.

## Confidential private artifacts

Dated candidate reports, snapshot states, biological overrides, detailed
inventory reconciliation, and ranked identities remain ignored and must not be
committed. They may contain operational details needed by the field lead but
are not required to understand or reproduce the method.

## Restart procedure

1. Read `AGENTS.md`, `THREAD1_REPOSITORY_MAP.md`, this handoff, and current
   Thread 2/4/6/9 handoffs.
2. Record Git revision/status and snapshot reference date.
3. Confirm the snapshot is authorized and read-only.
4. Reconstruct identity, current-GEO state, pair association, lay-date
   intervals, attempt class, and inventory independently.
5. Apply hard gates before ranking.
6. Produce a private dated report with aggregate public summary only.
7. Hand any app-facing task wording to Thread 4 and any schema need to Thread 2.
8. Never claim that a snapshot analysis is the current live deployment state.

## Verification and rollback

Compare candidate classes against the prior private report using anonymized
counts and reason categories. Investigate changes in identity, sex, inventory,
phenology, or task eligibility before field use. Because this tracked handoff
changes no runtime behavior, rollback is removal of the documentation change;
operational reports remain separately reproducible from their dated inputs.
