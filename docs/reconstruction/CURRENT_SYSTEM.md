# CURRENT system reference contract

12 November 2026 publication addendum: both manuals and the eight archived
Overview panels are restored in source, alongside Mihai's newer phenology
panel. All nine panels have distinct output IDs. The notA summary is restored;
the separate OVERVIEW table entry remains hidden. Dated archives remain intact. Earlier
withdrawal descriptions are historical; source publication is not deployment.
See [the restoration record](../APP_FEATURE_RESTORATION_2026-11-12.md).

Reviewed against source on 2026-11-01. This reconstruction package's CURRENT
reference documents existing behaviour, not live installation or change authority.
Approved-decision addendum, 1 November 2026: the same-day X-X/first-banding
contract below supersedes the 31 October blanket same-day restriction.
The focused synthetic checks and isolated MariaDB 11.8.9 install/refresh pass
for the new source. See [the dated verification scope and limits](SAME_DAY_LINKAGE_VERIFICATION_2026-11-01.md);
this is not live installation or a new full field/PDF replay.

The 3 November language-reader and hatch-accounting additions have separate
verification scopes below. The earlier integration pass does not verify later
source changes.

## Authority and scope

- [AGENTS.md](../../AGENTS.md) governs authority, confidentiality, and human control.
- For implemented behaviour, inspect the selected revision's
  [views](../../DATABASE/views.SQL), [refresh](../../DATABASE/refresh_todo_list_snapshot.SQL),
  [table DDL](../../DATABASE/main_tables.SQL), inspector exports, and R consumers.
- Reconcile source/document disagreements explicitly; prose cannot change biology.
- [Thread 4](../../notes/codex_proposals/THREAD4_TODO_MAP_LIST_DEBUG_PLAN.md) and
  [Thread 9](../../notes/codex_proposals/THREAD9_LOCAL_REPLICA_PROTOCOL.md) retain
  dated history beneath current addenda. Older recovery states are not instructions.
- The [manual](../../main/www/field-manual/manual.md) records procedures. Approved
  human scientific decisions govern intended behaviour; source determines what
  the selected implementation actually does. A disagreement blocks adaptation
  until reconciled, rather than allowing code to override the human decision.
  Local/external protocols and
  live inspectors are separate artifacts, not implicitly synchronized by a commit.

## Events, identity, and chronology

### Field instructions and entry records

On 12 November 2026 Luke requested restoration of the Field Manual panel,
iframe, separate-window link, and public reader assets. The panel opens the
[Core Team Field Guide](../../main/www/field-manual/core-guide.md), with a link to
the [Full Protocol Manual](../../main/www/field-manual/manual.md). Their English
and German sources, rendered pages, shared assets, and renderer are restored
unchanged from the checksummed [archive](../field-manual-archive/2026-11-08/README.md).
The full manual retains the procedures, controlled values, exceptions, and
authorship/AI disclosure. This is source restoration, not proof that the live
app or inspectors match the manual; new-study publication still needs review.
Superseded review drafts and the relocation checklist remain excluded from
reconstruction prerequisites; Git history retains them.

The reader also has standard German translations in `core-guide-de.md`
and `manual-de.md`, rendered to `core-guide-de.html` and `index-de.html`.
English remains the reference language. The English/Deutsch switch retains
manual kind and stable section anchors, and the core/full switch retains the
language. Translations preserve field names, codes, thresholds, and rules;
they are not a second source of biology. A source-checksum comment in each
German Markdown file binds it to its reviewed English source. The builder
checks both references before generating the four static pages and fails if
a translation is stale. This does not certify native-language review. No
translation service, runtime dependency, or database connection is involved.

Comments supplement required event records, not replace them. A bird identity
written only in `NESTS.comments`, or attendance entered in `bird_inc`, does not
supply the separate structured RESIGHTINGS evidence for parent association.
Record each actual event in its proper table with the required identity,
behaviour, and nest link; never fabricate or duplicate events to clear a task.
This is documentation of the existing event model, not new comment-parsing or
save-time validation behaviour.

### Event identity and chronology

Raw CAPTURES, RESIGHTINGS, NESTS, and EGGS rows remain observations, identified by
their table and `pk`; a shared occasion does not make rows duplicate events.
Family encounters use date, site, and the complete `gps_id`/`gps_point` pair.
Conflicting nonblank nest/brood IDs, including across tables, veto inferred family
links. Different encounters can document real brood mixing; raw IDs are not rewritten.

Metal rings and engraved flags identify individuals; ordinary adult matching uses
LL/LR, with full/spacer aliases where needed. A shared chick colour is not unique.
Capture identity prefers post-handling marks, with `_in` fallback for missing
release fields. Ring keys are trimmed, uppercased, and dehyphenated; missing/sentinel
values do not become identities. Any `?` in a sighting's four leg fields excludes
the event from parent evidence unless a known capture ring reliably traces identity.
Archive captures supply identity/sex/tag context, never a historical current-nest link.

Evidence is bounded by `settings.reference_date`. Captures use release, then caught
time, then midnight; adult resightings enter association chronology at midnight.
Preserve match-specific dates/event keys/ambiguity, not a universal “latest row wins”.
Under the approved 1 November rule, an unambiguous confirming X-X observation links to one
unique eligible `capture_status = F` first-banding captured identity of the same
sex, nest, and date, including MM without any later proof. The former requirement
for an identity with later confirming evidence is superseded for this same-day
link only; different-day earlier X-X still requires the new bird's own one
confirming or three distinct eligible observations. Preserve the date;
infer no exact observed time/order. SQL will conservatively timestamp linked
proof at capture datetime, rather than the resighting's ordinary midnight value.
Different-day older X-X proof cannot transfer. Later X-X evidence stays separate.

## Parent association: the four gates

In [views.SQL](../../DATABASE/views.SQL), read `ADULT_CAPTURE_IDENTITIES_ALL`,
`ADULT_RESIGHTING_IDENTITIES_ALL`, `ADULT_IDENTITY_MATCHES`,
`ADULT_CHICK_GPS_PARENT_LINKS`, `ADULT_PARENT_NEST_ASSOCIATIONS`, then
`ADULT_PARENT_STATUS`. These are the authoritative parent pipeline.

| Gate | Evidence and ranking |
| --- | --- |
| Direct capture | TB/TN/HA or a capture with chick(s) in `caught_with`; level 3. MM alone is not definitive. |
| Capture with GPS-linked chick | Exact dated site/GPS linkage to one operational nest/brood; eligible opposite-parent evidence may resolve a blank ID; level 3. |
| Confirming resighting | One eligible nest-linked IN/NM/SC/BW/BC/FC/AC token observation with observed lower fields and a valid dated nest/brood; level 2. |
| Repeated resighting | Three distinct unambiguous nonconfirming events of the same nest, sex, and identity; level 1, including the initial event. |

### Nest-map association display (1 November 2026)

`M_association_display` and `F_association_display` are additive, display-only
columns on `ADULT_PARENT_STATUS` and its derived parent snapshot. Their labels
reuse the existing per-identity event scan and winning association level:
definitive capture method (`TN`, `TB`, `HA`, or `with chicks`), `GPS + chicks`,
confirming behaviour code(s), or the distinct qualifying nonconfirming count.
No selection, ambiguity, MM chronology, reference-date, or task gate uses these
columns. Selected evidence takes precedence over pending competitors; without
a selected parent, each pending identity keeps its own count and nest-specific
MM/ambiguity annotation. Existing pending-detail fields are unchanged.

The map reads only a small published snapshot after the latest refresh has
succeeded for the current reference date; it never queries the expanded live
association view for these annotations. Counts therefore reflect that snapshot,
not subsequently entered observations, until another successful build. Missing
new columns, an in-progress/failed build, a different reference date, duplicate
snapshot keys, or a disagreement with the live displayed bird withhold the
annotation, retaining the plain map identity. No raw records are changed.

The popup also uses one **Last encounter** field relative to the reference date:
the existing SQL brood encounter date for brood points, or the latest nest visit
for other points. Missing/future timing shows Unknown rather than substituting
an old nest visit for a missing brood encounter. Deployment of the new evidence
columns requires views installation followed by a successful refresh, then the
app update; no inspector or base-table migration is required. Rollback restores
the prior SQL/R sources and rebuilds the derived snapshots; never replace raw
base tables. Earlier dated verification records do not verify this later change.

The subsequent **Hatch timing (days)** popup field delegates to the existing
`todo_pdf_prepare_nest_summary()` formatter rather than copying its hatch rules.
The map supplies the same reference-date published task values and the existing
`EGGS_HATCH_PREDICTION` metadata, alongside its nest/brood rows. This preserves
negative overdue/brood-age values, task overrides, no-float suppression, and
explicit flotation exemptions. It uses small published task rows and one
narrow projection of the existing hatch-prediction view when map data changes;
there is no per-click query, new SQL object, schema change, refresh stage, or PDF
render. An unavailable/withheld value displays Unknown. This map-only addition
requires an app update, not another SQL import.

Select exactly one identity at the highest positive level for each nest and sex.
Ties at that level, ambiguous matching, or no positive level remain unresolved.
The direct gates share level 3; these are alternative evidence routes. TN resolves
direct association; MM annotates identity at that nest, not a separate task engine.

The 3 November cross-nest rule removes an older, still-level-zero candidate only
when the same reliably identified bird and sex has a uniquely selected level-2
or level-3 association at another nest on a strictly later field date than all
of the older candidate's encounters. Reference-date bounds, identity ambiguity,
shared-colour exclusions, and same-day uncertainty remain. Earlier resolved
associations are not erased. Remaining weak candidates are recounted, not
promoted to resolved status. Both dates are aggregated in the existing event
scan, followed by windows over the identity summaries; no raw-event self-join,
new public view column, refresh stage, or R association rule is added. See
[the chronology contract](PARENT_ASSOCIATION_CHRONOLOGY.md).

Luke's 31 October decision preserves eligible pre-MM evidence for a reliably
identified bird at the same nest. MM does not reset independently earned proof.
The approved 1 November exception assumes a confirming X-X resighting and unique
eligible same-sex/same-nest/same-date status-F capture target the same individual;
its same-day confirmation transfers to the new marked identity. Multiple competing
captured identities, ambiguous/ineligible evidence, other sex/nest, recapture only,
or evidence beyond the reference date cannot supply this link. Count all eligible
distinct F capture identity keys in the same-sex/same-nest/same-date
`first_marking_counts` pool before
later-proof or ambiguity filters: those filters cannot turn multiple captured
identities into fake uniqueness. Duplicate rows do not create additional keys.
The same-day link requires a unique replacement and an unambiguous confirming
resighting (`r`); original X-X history keeps a previous MM-only candidate displaced.
For different-day
older X-X, a later first-marked bird still needs its own one confirming or three
distinct eligible postcapture observations. Its own valid same-day confirming
linkage now supplies proof to retire older placeholders without transferring
their proof or backdating association. Original MM displacement history,
independent conflicts, and the four-gate hierarchy remain intact. Seven-day,
36-hour, and tag gates, juvenile-origin and brood-closure same-day safeguards
are unchanged. See [chronology contract](PARENT_ASSOCIATION_CHRONOLOGY.md)
and [machine-readable cases](parent-association-cases.json).

`M/F_selected_identity_key` and `M/F_selected_mark` differ from pending details.
Unknown means neither selected nor pending mark; a marked pending bird is known.
Confirmed unbanded requires selected explicit X-X without pending association;
missing data never implies X-X. GEO/death flags follow the selected identity.
A unique pending identity's GEO also separately vetoes another deployment.

## Chick work and brood closure

Negative IDs mean unknown-origin mobile broods, valid only in CAPTURES/RESIGHTINGS.
Positive nests may retain live broods after `notA`. `NO_NEST` is retired input;
an unrelated adult capture uses SQL NULL plus a complete GPS pair.
Age-C R/C captures require direct GPS; positive-nest first captures may supply a
complete optional pair. Handling/tent photos and individual H hiding photos differ.

The refresh canonicalizes one chick target per brood/normalized ring. A confirmed
D event removes that individual globally; a missing-ring D can use only a unique
global flag-to-ring bridge. Later F/R/C evidence can invalidate death suppression;
same-day precedence requires observed times. Unresolved deaths never erase siblings.
Operational brood counts account for death chronology; do not subtract deaths twice.

The 3 November hatch-accounting addition uses one refresh-time operational egg
count for task rows and their PDF consumers. For an H positive nest with a
previously documented complete clutch of at least three eggs, distinct original
first-banded chick rings can account for the full clutch even if the last real
visit still had eggs. Reference-date-qualified first-banding completion must be
later than that explicit egg visit. Unknown or conflicting origins, extra or
unresolved identities, untimed evidence, contrary egg observations, and terminal
history keep the inference closed. Duplicate rings count once, later recaptures
do not advance hatch accounting, and dead chicks establish hatch history without
becoming live targets. One/two-egg clutches remain conservative under this rule.
The task egg count becomes zero and routes to `notA nest-check`; it does not
rewrite NESTS, manufacture a visit, close the brood, or reset capture/tag clocks.
Four additive nullable chick-context columns carry origin count, accounting
timestamp, blocker count, and reference date. Installer fallbacks carry no proof;
the explicit refresh computes it from staged identities and bounded source guards.
No new expanded association view or pairwise origin graph is installed.

Focused verification: 55 assertions passed without failures, warnings, or skips
on isolated, socket-only MariaDB 11.4.2 with invented records. They execute the
actual capture/context stages, additive column inserts, and egg/notA task
branches; unrelated family-resolution inputs are represented by staged fixtures.
Hatch proof uses caught time, with release fallback, independently of existing
release-first operational clocks. A positive egg visit between caught and release
times therefore vetoes the inference. The owned server was shut down cleanly.
This is not target-version 11.8.9 integration, a full field-dump refresh/PDF
comparison, a new task-count report, or a live Adminer performance guarantee.

Validation assessment only: a correct morning nest visit must not become a
save-blocking error merely because the last chick is captured later elsewhere.
A future post-save reconciliation warning could flag stale positive egg counts
once complete-clutch accounting is reliable, asking for review or an actual
follow-up visit, not an invented zero-egg entry. Such a warning would need the
same duplicate, origin, chronology, death, and uncertainty guards and must not
block a truthful capture. No inspector message or validation severity is changed
by this assessment; live implementation needs separate human approval.

Before age 21, unhandled broods generate `Untrapped brood`; from day 21, incomplete
engraved-flag coverage generates `Broods to recapture for flagging`.

During days 1–6 after hatch/discovery, H-photo work compares distinct qualifying
H-photo rings against active captured chick-ring targets. Require age C, class H,
resolved linkage, GPS_POINTS match, and nonblank photo range. Duplicate photos count
once; absent targets keep work open within the window. Tent photos do not close it.
For blank-ID negative-brood family inference both selected parents need prior proof;
only the parent(s) actually observed need current BC/FC/AC rows. SC is not a substitute.

`TODO_BROOD_CLOSURE_STATUS` separates presumed death from developmental resolution.
Renesting requires prior identity proof and a qualifying later nest association.
The two-by-two route needs age >=21, strong identities for both parents, two
non-brood observation dates each, at least one strong negative each, and no later
positive brood evidence that defeats that chronology. Spatial proximity is support.
The age route triggers on day 36 only if no live encounter occurred in inclusive
days 21–35: hatch anchors positive broods, discovery anchors negative broods.
Later live evidence reactivates the applicable route; routes retain separate clocks.
An origin-linked age-J event resolves the whole brood, including J/D developmental
evidence, which does not prove survival. Closed/resolved broods lose operational
tasks through the publication guard, while eligible positive `notA nest-check` remains.

## Capture timing, tag instructions, and maps

Parent capture normally needs confirmed clutch completion plus seven days, and an
independent 36-hour interval evaluated at reference-date 08:00. Sex-targeted timing
uses the opposite parent's capture; an any-parent target uses the applicable shared
clock. Clutch reduction preserves the pre-reduction clock; hatch/brood exceptions
waive the clutch-age gate, not the disturbance gate. Blocked work is resighting.
Source contains a named correction exception; it is not a reusable biological rule.

Initial GEO deployment is restricted to positive B/C nests whose authoritative
completion date is strictly after 2026-10-09. Missing dates do not qualify.
Current planning uses X/B/T/? status and explicit actions, not the older quota planner;
release ceilings/quota fields are compatibility NULLs. Pair completion needs a
qualifying deployment for the current parent at this same nest, and retains timing
gates; it may precede the initial campaign cutoff. Both sexes' tag notes say
`pair completion`. Already-tagged selected/pending targets remain protected.
`tag any, but only if one is confirmed X-X` is conditional field verification,
including the guarded banded/unknown advisory, not automatic identity promotion.

The [PDF map](../../main/R/pdf_todo_map.R) outlines Parent capture points whose
notes contain `tag`; wording therefore has display consequences. The
[live map](../../main/R/leaflet_nest_latest.R) merges nest/brood layers, labels
hatched positives and negatives `brood`, retains failed `notA` separately, and
uses positive nest coordinates as fallback. This live layer is not TODO closure.

## Published state and historical notA report

Views install bounded helpers; the separate refresh builds indexed replacement
snapshots and promotes them together. `TODO_LIST` is the task contract; changing
source/reference date or downloading a PDF does not itself publish a new snapshot.
[App guards](../../main/R/system_utils.R) check date/latest refresh state.
The restored [notA_summary definition](../../DATABASE/notA_summary.SQL)
is again registered in the app and installed by the reference reconstruction
bootstrap after snapshot publication. It installs after the
first successful refresh, reads published nest/parent snapshots, and returns no rows for stale or
incomplete latest status. It reports historical terminal nest visits, confirmed
parents separately from pending details, and conservative later-nest identity links.
Later links require the same resolved identity/sex and a strictly later first-found
date: ring/flag or a fully supported classic lower key, never X-X/shared chick marks.
It neither declares brood death nor imports handwritten links. Repository inspection
and prior local replay establish no production schema, inspector, or running-app version.

The [Overview archive](../overview-archive/2026-11-08/README.md) retains the eight
original plot implementations and shared wiring context. The active helper is
again `main/R/ggplot_overview.R`, with date-limit/growth reactives and eight
renderers in `main/server.R`. Mihai's `phenology_server()` still owns
`overview_lay_date_show`; the restored chart uses
`overview_lay_date_history_show`. The new phenology and Data issues helpers,
their server calls, and current DataEntry wiring are preserved. The SQL
OVERVIEW definition remains in views.SQL, and its table entry stays hidden;
no SQL import or biological-record change is part of this restoration.

## Approved follow-up to the reconstruction review

Luke resolved the MM chronology question on 31 October and approved the narrow
same-day linkage exception on 1 November. Same-day confirming proof transfers
under that exception; older different-day X-X proof does not. Retired placeholders
are excluded only from the derived calculation, never deleted from raw observations.
The new implementation and its focused synthetic checks are recorded in
[the 1 November verification](SAME_DAY_LINKAGE_VERIFICATION_2026-11-01.md).
Deployment and full field/PDF replay remain unverified; earlier dated runs
retain their own source identities and results.

Luke separately approved aligning capture-mark field descriptions with the
existing manual/validator contract: R/C require incoming and release marks;
D requires recovered incoming marks and blank release fields/time; X means
an unmarked position, not a missing observation. Source comments and a separate
read-only comment-patch generator implement that wording correction. Validator
code, column types, constraints, and stored field records are unchanged. Live
comments have not been inspected or changed by this work. This follow-up is
separate from the earlier reconstruction-only verification record.
