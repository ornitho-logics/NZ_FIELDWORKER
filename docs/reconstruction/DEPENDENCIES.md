# Reconstruction dependencies and source order

Reviewed from repository source on 2026-10-31; no app, test, package installation,
or database was run for this document. This is a dependency contract, not a lockfile
or deployment record. The reconstruction package's machine dependency manifest
must record observed versions/revisions; no R/package/Quarto pins are invented here.

## SQL installation and publication order

Use an explicitly disposable database for reconstruction, with invented records.
The order below describes prerequisites, not permission to execute source scripts.
[AGENTS.md](../../AGENTS.md) retains the live-database and human-control boundaries.

| Order | Repository source / prerequisite | Contract |
| --- | --- | --- |
| 1 | [main_tables.SQL](../../DATABASE/main_tables.SQL) | Creates/selects the current schema and core event/GPS tables. Some CREATE TABLE statements are not idempotent. |
| 2 | [support_tables.SQL](../../DATABASE/support_tables.SQL) | Select the intended current schema first; creates settings, spatial_objects, and inspectors using unqualified names. |
| 3 | Synthetic current/support inputs | Supply one non-NULL `settings.reference_date`; spatial and inspector data are separate prerequisites for those features. DDL alone does not seed them. |
| 4 | Historic compatibility objects | Provide `BADOatNZ.CAPTURES` and `BADOatNZ.SEX` before archive-dependent views; use synthetic structure/data only. |
| 5 | [functions.SQL](../../DATABASE/functions.SQL) | Defines `FIELD_2026_BADOatNZ.format_mark()` before consumers. |
| 6 | [predict_hatching.SQL](../../DATABASE/predict_hatching.SQL) | Creates/seeds the calibration support table before hatch/view consumers. |
| 7 | [views.SQL](../../DATABASE/views.SQL) | Install the whole ordered helper/identity/compatibility/snapshot-boundary graph. |
| 8 | [refresh_todo_list_snapshot.SQL](../../DATABASE/refresh_todo_list_snapshot.SQL) | Build indexed contexts, parent/closure/task snapshots, and publish them together. |
| — | [Archived notA_summary.SQL](../notA-summary-archive/2026-11-08/notA_summary.SQL) | Withdrawn optional report, not a default installation step. Separate human approval is required to restore it. |
| 10 | R consumers and PDF resources | Consume a successful current snapshot; do not replace refresh with a PDF download. |

Steps 3/4 can be prepared independently, but both must precede their consumers.
Do not import dumped derived views as current source definitions. Preserve the
selected reference date throughout an authorized reconstruction.
[The reset file](../../DATABASE/_reset.SQL) drops the current schema/tables; it is
destructive scaffolding, not a prerequisite or a safe live upgrade procedure.
Dated field-hint/validator patch SQL is a separate reviewed migration concern.

## Historical archive boundary

`CAPTURES_ARCHIVE` in [views.SQL](../../DATABASE/views.SQL) reads historical
CAPTURES and left-joins ring-based genetic sex from historical SEX. Neither table's
DDL is supplied by the current-season base DDL. An RDS archive view is not a
substitute for these cross-schema dependencies during a clean SQL installation.

Historical CAPTURES must expose ring; UL/LL/UR/LR; date, study_year, site_code,
capture_status; latitude/longitude; field_sex, age; tarsus, culmen, wing, weight,
moult_left; tag_id and tag_type. SEX needs ring and gen_sex. Derive synthetic
types from the selected contract rather than importing confidential history.
The compatibility view also contains a specific identity repair; it is not a
generic normalization rule. See [adaptation exclusions](../../docs/reconstruction/ADAPTATION.md).
Archive identity contributes to parent matching and occupied-mark subtraction,
but cannot establish a current-season nest association by itself.

## MariaDB runtime contract

MariaDB **11.8.9** is the documented local reconstruction/replay baseline, not a
claim of broad MySQL/SQLite portability or the production server's version.
Required features include CTEs, window functions, session variables, prepared
statements/SIGNAL, advisory locks, temporary tables, and multi-table RENAME.
Views installation and refresh share a cooperative schema lock and bound session
metadata-lock waits. Run each complete script on one connection and stop on error;
connection-local refresh inputs must survive until publication completes.

Character semantics matter: current DDL/expressions use `utf8mb4_uca1400_ai_ci`
alongside explicit `utf8mb4_general_ci` comparisons. `format_mark()` has no explicit
return collation in tracked source. Record schema, connection, imported-column, and
function-return collations. Older replay needed disposable collation normalization;
that diagnostic adaptation is not an automatically approved production migration.

Record `lower_case_table_names` and preserve exact SQL object spelling. The focused
notA report replay used value 2; that does not prove a full case-sensitive install.
The reconstruction harness requires value 0 and, on macOS, creates/detaches its
own case-sensitive APFS sparse volume. An initial native macOS value-2 bootstrap
failed on a temporary-table CTE during refresh; it is retained as a failed
platform control, not resolved by changing reference SQL or skipping that stage.
The [Thread 9 record](../../notes/codex_proposals/THREAD9_LOCAL_REPLICA_PROTOCOL.md)
distinguishes completed local checks, missing older golden artifacts, and historical
failures. Stop at a collation/case/install error; a partial build is not publication.
RDS export requires base tables plus CAPTURES_ARCHIVE; SQL backup needs
`mariadb-dump` or `mysqldump` and a verified completion marker despite view warnings.

## External R package contracts

| Boundary | Required behaviour / repository consumer |
| --- | --- |
| DataEntry | [Entry wrappers](../../DataEntry/CAPTURES/global.R) use ui_append_rows/server_append_rows and prepare_for_dropdown; editor modules use table/inspector/code editors. Package owns loading, validation, and saves. |
| dbo / connection layer | [DBq/DBx](../../main/R/system_utils.R) expect db_con() plus DBI-compatible connections; group/schema and local configuration resolve externally. DBq returns a data.table error column on failure. |
| gpxui | [global](../../gpxui/global.R), [UI](../../gpxui/ui.R) and [server](../../gpxui/server.R) require gpx_ui(gps_ids) and gpx_server(), with GPS_POINTS/GPS_TRACKS linkage preserved. |

DataEntry validates submitted `x`; each check returns `rowid`, `variable`, `reason`,
including zero-row success, and preserves row numbers. Inspectors are `list(...)`
expressions wrapped in `try_validator`. Track hard/error versus warning behaviour
separately from post-save QA and mock-generation rules; extra output columns do
not automatically add UI severity. [Exports](../../notes/codex_proposals/validator_sandbox/inspector_lists_by_table/)
are source artifacts, not proof of installed DB rows or package severity handling.

Address inspector rows by table AND trailing comments role (`hard`/`warn`), verify
expected row counts/source fragments, and preserve descriptive comment prefixes.
The [central editor](../../DataEntry/inspectors/global.R) is not an installer contract.
Package internals/revisions are external and were not audited in this documentation
pass. Record the actual DataEntry/dbo/gpxui source revisions and dependency metadata
in the machine manifest; do not infer them from this repository's commit.

`DATAENTRY_CNF`, `GPXUI_CNF`, and dbo options identify operator-local configuration.
Do not copy those files or paths into fixtures/manifests. Sourcing entry globals can
query the database; app launch and refresh controls are not read-only diagnostics.

## R, Quarto, and Typst PDF path

[main/global.R](../../main/global.R) is the current direct R package inventory:
DataEntry, DBI, DT, data.table, stringr, glue, ggplot2, mgcv, ggrepel, htmltools,
htmlwidgets, ini, jsonlite, quarto, patchwork, png, curl, sf, zip, shiny,
shinyWidgets, shinycssloaders, bs4Dash, fresh, later, waiter, and leaflet.
Capture R/session information, transitive dependencies, and database driver versions
from the approved environment; this list supplies neither minimums nor a lockfile.
The app declares `Pacific/Auckland`; record the SQL/session time assumptions too.

[pdf_todo.R](../../main/R/pdf_todo.R) generates QMD from
[todo_pdf.qmd](../../main/templates/todo_pdf.qmd), then calls Quarto with
`output_format = "typst"`. Supply the R quarto package, Quarto CLI and its usable
Typst toolchain, fonts, writable render directory, and compatible graphics devices.
The to-do PDF path uses **Typst, not LaTeX**; installing TeX is not its remedy.
`pdfinfo` improves page counting; the R code has a fallback when it is absent.

[pdf_todo_map.R](../../main/R/pdf_todo_map.R) additionally needs sf's native spatial
libraries/CRS resources, ggplot2/ggrepel/patchwork/png/curl, A/B/C study-area geometry,
and available imagery/cache inputs. Metric plotting uses EPSG:2193 from EPSG:4326.
An offline synthetic check must supply safe invented spatial inputs and avoid
assuming network imagery. Rendering success still needs visual inspection.

No runtime compatibility or live deployment is established here. Rollback of this
documentation is scoped removal/revision; machine verification and live release
remain separate from these notes and from the [CURRENT contract](../../docs/reconstruction/CURRENT_SYSTEM.md).
