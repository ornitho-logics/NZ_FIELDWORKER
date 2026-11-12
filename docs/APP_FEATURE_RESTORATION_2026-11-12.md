# Manual, Overview, and notA restoration

Luke requested restoration of the field manuals, Overview panels, and notA
summary, while preserving Mihai's recent additions to main. The later validator
request is documentation-only: Mihai will select individual checks against
feedback. This change does not reactivate the old DB inspectors, change the
current per-app validators, or add validator controls to the rendered app.

## Restored source and retained collaborator work

- The Field Manual sidebar/tab, iframe, and separate-window link return. The
  default reader is the short Core Team Field Guide; it links to the full manual.
  All four English/German readers, Markdown sources, styles, search/navigation,
  reader README, and renderer match the 8 November source archive byte-for-byte.
  The scientific text, section anchors, translations, and AI-use disclosures
  are unchanged. Active sources are again under `main/www/field-manual/`,
  with the builder under `main/tools/`.
- All eight original Overview panels return with the unchanged
  `main/R/ggplot_overview.R` helper, shared date limits, original error
  fallbacks, and growth-data polling. The renderers require the Overview tab
  before running their chart calls.
- Mihai's newer Cass River phenology panel is retained unchanged. It keeps
  `overview_lay_date_show`; the restored lay-date chart uses
  `overview_lay_date_history_show`. There are nine distinct plot outputs and
  nine distinct renderer owners, with no overwritten renderer.
- Mihai's Data issues and Field Resightings features, `RESIGHTINGS_field`
  table registration, per-app inspector files/imports, phenology helper, and
  their existing focused tests are retained. No DataEntry file is changed.
- `notA_summary` returns to Show Views with its explanatory text and published
  snapshot watch list. `DATABASE/notA_summary.SQL` matches its dated archive
  exactly. It still separates pending/confirmed parents and uses conservative
  later-nest identity links; no biological rule is changed.
- The separate raw OVERVIEW table entry remains hidden. The copyright notice
  remains absent. All immutable archive source files and manifests remain;
  their guide pages identify the old withdrawal as historical.

The reconstruction rule crosswalk points to the active manual and restored
notA installer. Its development-only bootstrap again installs that view after
snapshot publication and checks that later refreshes do not require reinstalling
it. The bootstrap is syntax-checked only in this task; it is not executed.

## Validator documentation, not automatic reactivation

The [maintainer guide](validation/SELECTIVE_VALIDATION.md) explains the newer
file-first loader, the older DB-only loader, selective rule review, package
version/deployment uncertainty, and interaction with the Data issues audit.
The [current catalog](validation/VALIDATOR_CATALOG.md) lists all 265 current
checks; the [archived catalog](validation/ARCHIVED_VALIDATOR_CATALOG.md) lists
186 named original hard/warning groups. Both have machine-readable JSON
counterparts, source positions, descriptive labels, literal message inventories,
and source checksums. The archived groups are not a one-to-one mapping to the
new IDs and are not instructions to paste old lists over the current setup.
The generator parses source without evaluating any field validator.

No blanket restore SQL is generated or executed. Existing pause/restoration
tooling and the original inspector archive remain intact as historical tools.

## Verification and limits

All **1,258 focused assertions passed**, with no failed assertions or test errors:

| Scope | Passed assertions |
| --- | ---: |
| Restored manuals, archive bytes, four-page deterministic builds, and translation guards | 368 |
| App publication, nine unique output owners, reference-date reactions, and rendered UI markup | 105 |
| Current/archived validator inventories, drift checks, and parse-only safety fixtures | 545 |
| Mihai's unchanged phenology tests | 36 |
| Mihai's unchanged Data issues tests | 45 |
| Invented map/PDF display-link regressions | 28 |
| notA static source/registration checks | 13 |
| Ten existing invented-input Overview helper tests, run without app globals | 118 |

The two separately opted-in notA database/DDL tests were deliberately skipped.
No database socket, field dump, credentials, production query, package upgrade,
or live server was used. The UI was rendered to HTML in memory with fake test
status and literal app settings, without loading `main/global.R`, starting an
HTTP/Shiny app, or requesting map tiles. The Overview helper tests use stubbed
lookups; they are not production performance measurements.

The broader app-wiring/server test sources are updated and parsed, but their
full app-global loading paths were not run. No browser layout rehearsal, live
save test, full SQL/refresh replay, or complete reconstruction run is claimed.
Restoring a manual does not certify that the deployed validators match its text.

## Human-controlled installation

1. Review and merge the PR, then deploy its app files through the usual human
   process. Include the restored `main/www/field-manual/`,
   `main/tools/render_field_manual.R`, and `main/R/ggplot_overview.R`.
   Restart/reload the app and refresh clients.
2. Verify the short/full and English/Deutsch reader links, separate-window
   GitHub links, all nine Overview boxes, and the preserved Data issues and
   Field Resightings features. Test a reference-date change.
3. If the notA view is absent, save a fresh backup and select the field database
   in Adminer. After a successful To-do snapshot has created both published
   nest/parent snapshots, import or paste **all of**
   [`DATABASE/notA_summary.SQL`](../DATABASE/notA_summary.SQL), with Stop on error
   enabled. It creates/replaces only that small view and changes no field records.
   Preserve any independently customized existing definition before replacing it.
4. The large `views.SQL` and `refresh_todo_list_snapshot.SQL` are unchanged.
   Do not rerun them merely to restore app panels or install this small report.
   Later normal successful snapshot builds update notA results without another
   view installation. Stale or incomplete snapshots intentionally show no rows.
5. Validator reinstatement is a separate human decision using the maintainer
   guide. Do not automatically restore all archived checks or overwrite Mihai's
   per-app files. Preserve unsaved work before any later entry-app restart.

## Risks and rollback

The restored charts reinstate their original query workload and five-second
growth-data update check; live speed is unmeasured. Missing schema/functions,
incompatible dependencies, or old deployed snapshots can still cause panel
fallbacks or unavailable reports. No new runtime dependency is introduced.

For an app rollback, revert the restoration commit on a reviewed branch while
preserving later collaborator work, redeploy, and restart the app. Remove only
the restored public manual assets/helper if returning to the prior withdrawn
publication state; keep the dated archives. App rollback does not require
deleting biological records or restoring old base tables. For a separately
installed notA definition, restore the backed-up definition through the human
database workflow if needed; do not drop shared views or data indiscriminately.
