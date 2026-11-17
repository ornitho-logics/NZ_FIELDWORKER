# Thread 7 geolocator rollout handoff

Status: tracked, sanitized specialist handoff
Last reconciled: 2026-10-26
Scope: seasonal GEO deployment planning for Cass River Banded Dotterels

## Current operational clarification — 31 October 2026

Later explicit field decisions supersede conflicting dated planning defaults
below. The late-wave initial-deployment cutoff uses clutch completion strictly
after 9 October 2026, not initiation or discovery. The conditional
`tag any, but only if one is confirmed X-X` note can cover one confirmed
banded/untagged parent with an unknown mate, as well as its existing
both-unknown use. It is restricted to eligible positive B/C nests and open
seven-day/36-hour gates. Confirm the unknown bird as X-X and nest-associated
before deployment. A bird that proves banded does not authorize that initial
deployment. The known banded mate may qualify later only through the existing
same-nest deployment provenance and independent timing checks.

Existing GEO evidence remains effective while a bird's nest association is
pending: retain its resighting follow-up and suppress another tag for that
individual. Never resolve an association merely to remove a task. Eligible
tag-bearing notes use `pair completion` consistently; their white map outlines
are a prompt to read the row, not an eligibility waiver. See Section 8 of app
manual v2.4.12 and current refresh SQL for the exact operational contract.

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

## A05 manual guidance: pair aim versus one-visit eligibility

The pair objective is a longitudinal deployment aim, not permission to handle
both parents during one visit. The field manual may use the following rule:

> The programme aims to tag both members of selected active pairs when each
> bird becomes independently eligible. This is a pair-level objective, not
> permission to handle both birds on one visit. At every visit, follow the
> current `Parent capture` task and capture only the parent whose identity, tag
> status, timing, welfare, permit, weather, and condition gates are open. If
> the mate is not yet eligible, leave it unhandled and keep or recheck its
> follow-up task; do not capture it solely to complete the pair. A later
> pair-completion action waits for a current capture task and the required
> seven-day and 36-hour intervals.

The current task output remains the operational authority. Thread 4 owns the
exact task and reference-date calculation; this section explains how a
fieldworker should interpret a pair-completion note. A `Parent resighting`,
`resight M`, `resight F`, or `resight/band` row is not a GEO-capture
authorization merely because the other parent is tagged.

### Short pre-capture checklist

| Check | Field action |
| --- | --- |
| Current task | Confirm a current `Parent capture` task for the intended parent at the current reference date. If the live task is resighting-only, resight or wait; do not convert it into a deployment task. |
| Identity and current tag | Confirm a reliable individual identity and current no-GEO status. An unknown target may be confirmed at capture only when the tagged mate and the live task explicitly provide that pathway; otherwise verify first. |
| Seven-day timing | Confirm that the applicable clutch-age gate is open in the task output. Hatch signs, a confirmed hatch event, or an approved hatch-state override can change this gate only when the current task says capture is eligible. |
| Thirty-six-hour timing | Confirm that the post-adult-capture interval is open. Do not handle the mate on the same visit when doing so would violate the 36-hour disturbance rule; the mate must wait for a fresh timing/task review. |
| Welfare and authority | Confirm permits, weather, bird condition, handling limits, and bander judgement before any capture or deployment. |
| Pair follow-up | If one parent is completed and the mate is not eligible, record the pair as pending and recheck it after the task engine refreshes; do not force same-visit pair completion. |
| Wave and stock | Treat roughly 50 first-wave and 50 second-wave devices as a planning envelope. The field lead may pause or continue after reviewing current phenology, sex/pair coverage, reserve, and confirmed physical stock. |

The timing table is explanatory rather than a second task engine. Exact dates,
eligibility, and any transition from resighting-only to capture work must come
from the current `TODO_LIST`/PDF task output. The seven-day clutch-age gate and
the separate 36-hour disturbance interval both remain mandatory unless the
current task explicitly exposes an approved exception.

Phenology strata guide population-level allocation only. They predict timing
patterns and do not classify an individual bird as resident or migrant. An
individual exclusion (including an orange-flag/AU-migrant rule) still requires
the relevant identity/mark evidence or an approved conservative override.

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
