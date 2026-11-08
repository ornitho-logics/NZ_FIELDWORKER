# Adapting the reconstruction to another study

This is a planning guide, reviewed 2026-10-31. The
[CURRENT contract](../../docs/reconstruction/CURRENT_SYSTEM.md) describes the
existing Banded Dotterel system. A study profile records proposed decisions;
it is planning metadata, not live application configuration or an automatic migration.
This documentation changes no interaction, task behaviour, validator, or database.

## Reuse and study-specific decisions

| Component | Reusable structure | Human approval required for a new study |
| --- | --- | --- |
| App shell | Modular Shiny dashboard, table-entry launchers, and report downloads | Study name, language, deployment surface, and field workflow |
| Event model | Separate capture, resighting, nest, egg, and GPS events | Applicable taxa, life stages, event classes, required measurements, and media |
| Identity | Preserve raw marks; derive normalized ring/flag keys; retain ambiguity | Global uniqueness, marking layout, allowable partial readings, and alias policy |
| Nest/brood linkage | Separate observed IDs from inferred associations and provenance | Nest naming, season/site scope, negative IDs, and family encounter definition |
| Parent status | Selected identity distinct from pending evidence and unknown status | Sex model, direct capture methods, confirming behaviours, and repeat thresholds |
| Tasks | Explicit reference-date build, indexed snapshots, and publication guards | Task classes, priorities, cadence, closure, and reactivation evidence |
| Capture safety | Independent age/completion and disturbance gates | Species-specific timing, time-of-day assumption, and permitted exceptions |
| Chick follow-up | Individual targets, conservative death resolution, and flag coverage | Growth/status boundaries, handling, developmental ages, and marking scheme |
| H-photo evidence | Per-individual evidence with location/media completeness | Whether this protocol applies, photo class, window, and target denominator |
| Hatching | Calibration table, explicit uncertainty, and chronology | Biological calibration, float categories, and laying intervals |
| Devices | Identity-specific deployment provenance and pair completion | Device types/actions, dates, plots, quotas, permits, and welfare restrictions |
| Available marks | Historical occupancy subtraction and explicit allocation | Colour alphabet, exclusions, reuse policy, site pool, and team allocation |
| Maps/PDF | Linked coordinates, task symbology, and printable outputs | CRS, polygons, imagery rights/access, plot panels, and layout |
| Validators | Hard/warning lists plus separate QA/mock-generation rules | Save-blocking policy, warning envelopes, and package severity behaviour |
| Archive/reporting | Compatibility boundary and snapshot-based historical reports | Historical schema, sex authority, reliable cross-season links, and retention |
| Operations | Source freeze, dependency record, and synthetic verification | Hosting, credentials handling, backup/recovery, and deployment authority |

Read the relevant implementation before approving a profile entry. Changing the
profile alone changes none of the SQL literals, R wrappers, or live inspectors.

## Decisions to settle before implementation

1. Define the study unit: species/site scope, seasons, nest versus mobile brood,
   identifier lifetime, GPS linkage, and how uncertainty is preserved.
2. Approve marking and identity rules. Chick family colours may be shared;
   metal rings, complete adult marks, and engraved flags have different roles.
3. Approve parent evidence, sex handling, and chronology. Reusing four gates
   does not establish their biological validity for another species.
4. Set observation/state vocabularies, required fields, and permitted overrides.
   Keep warning-level biological outliers distinct from impossible input.
5. Approve clutch/hatch calibration, capture disturbance windows, chick follow-up,
   death resolution, renesting, and brood closure/reactivation rules together.
6. Approve device deployment eligibility, initial cutoff, and pair completion.
   A mate's historic tag is not sufficient current-nest deployment provenance.
7. Define spatial conventions, safe invented fixtures, and export audiences.
   Approve any externally sourced imagery or location-bearing publication.
8. Agree external package revisions, database semantics, and release evidence.
   Keep source review, isolated execution, and live installation as separate gates.

## Implementation boundaries to review

The [base DDL](../../DATABASE/main_tables.SQL) defines canonical columns and enum
comments. [Support DDL](../../DATABASE/support_tables.SQL) defines settings,
inspectors, and spatial objects. Preserve table-specific fields: `observer_upload`
is CAPTURES-only; EGGS is long format and clutch media belongs on NESTS.

[Views](../../DATABASE/views.SQL) contain schema names, species/site filters,
nest patterns, identity aliases, archive dependencies, mark pools, and association
logic. [Refresh SQL](../../DATABASE/refresh_todo_list_snapshot.SQL) independently
materializes canonical inputs and task logic. Review corresponding live-helper
and refresh branches together; updating one copy may leave outputs inconsistent.

[Entry wrappers](../../DataEntry/CAPTURES/global.R) contain prefilled values,
dropdowns, and group names. The
[inspector exports](../../notes/codex_proposals/validator_sandbox/inspector_lists_by_table/)
contain executable study rules; live DB-stored lists are separately installed.
Do not treat export filenames as unique database row addresses.

[Main configuration](../../main/global.R), [server wiring](../../main/server.R),
[PDF logic](../../main/R/pdf_todo.R), [PDF maps](../../main/R/pdf_todo_map.R) and
[live maps](../../main/R/leaflet_nest_latest.R) carry study assumptions too.
Current map code expects A/B/C plot polygons and NZTM/EPSG:2193 for metric work.
`spatial_objects.study_area` is parsed as a named R expression of WKT strings;
changing only a polygon value is not a general CRS/layout adaptation.

Task labels and notes are interfaces: the PDF map tests notes for `tag`.
Replacing wording can change highlights without changing SQL selection.
Review [the template](../../main/templates/todo_pdf.qmd), legends, and the
[archived manual reference](../field-manual-archive/2026-11-08/readers/manual.md)
after semantics agree. The reference was withdrawn from the app on 8 November
2026; adapting it does not authorize republishing it. Any new study manual
requires separate human review and publication approval.
Use the [dependency guide](../../docs/reconstruction/DEPENDENCIES.md) for load order.

## Hard-coded repairs are excluded from generic policy

Current source includes an archive identity correction, approved spacer aliases,
and a named duplicate-correction task exception with special timing behaviour.
They encode particular historical evidence, not general bird biology.
This guide intentionally reproduces no affected rings, marks, or nest identifiers.

Do not carry these repairs into a new study as defaults, broaden their selectors,
or substitute new field identifiers by analogy. A human must review each category
and explicitly approve exclusion, a separately justified replacement, or retention
for a faithful reconstruction of this study. Preserve the original source/evidence
boundary; documentation approval does not authorize rewriting historical rows.

Similarly, approved historical single-colour/spacer aliases are not a new global
uniqueness constraint. A lower-band-only shortcut can conflate different birds.
An uncertain sighting is not definitive evidence merely because its syntax is valid.

## Practical adaptation workflow

Start from a selected reviewed revision and record proposed study decisions with
source locations, owner, rationale, and unresolved questions. Inventory coupled
SQL/R/inspector/manual consumers before making approved changes. Use targeted edits
and review their effects; blanket search-and-replace of years, schemas, sites, or
species misses biology and can corrupt compatibility references and identifiers.

Prepare a disposable synthetic reconstruction with no confidential records,
credentials, private overrides, field coordinates, or copied database defaults.
An empty successful install only proves structural readiness; it does not prove
task biology, package integration, map layout, or useful report content.

After separately authorized execution, verify boundary cases: ambiguous parents,
pending tagged identities, explicit X-X, conflicting families, death versus live
chronology, chick/juvenile resolution, cutoff equality, and stale publication.
Render the Typst PDF and inspect symbols, notes, tables, and page breaks.
Only then reconcile the public manual and request the human-controlled release.

## Evidence, limits, and rollback

No new study's calibration, identifier rules, package compatibility, or live state
is established by this guide. See [AGENTS.md](../../AGENTS.md) for approvals.
Record approved deviations from CURRENT rather than relabelling old behaviour.
For these docs, rollback is removal/revision of only the requested documents;
there is no runtime change to undo. Future code/database rollback must be scoped
to the approved implementation and tested independently of confidential records.
