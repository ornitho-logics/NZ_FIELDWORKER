# Archived Overview dashboard — 8 November 2026

Luke requested withdrawal of all eight Overview panels from the app, with safe
preservation rather than destruction. The Overview sidebar/tab, its eight plot
outputs, chart-only reactives, and growth-data polling are removed. The separate
OVERVIEW table entry is also hidden from Show Views. Other Show Views outputs,
the To-do PDF, live nest map, data-entry forms, and raw field data are unchanged.

## Preserved code and provenance

- [ggplot_overview.R](ggplot_overview.R) is the original plotting/query helper,
  moved unchanged out of the automatically loaded `main/R` directory.
- [overview-source.tar.gz](overview-source.tar.gz) contains the original helper,
  UI/server/global wiring, original Intro help, relevant tests, and SQL context from the pinned
  published source commit. Shared files are snapshots for reference, not
  instructions to overwrite the current application.
- [manifest.json](manifest.json) pins the source commit, archive checksum,
  member sizes, member checksums, and Git blob identities.

The eight withdrawn panels cover manipulation quotas, lay-date phenology,
hatching forecast, nest discovery, unique adult band combinations, geolocator
deployments, chick growth, and tagged-bird resighting histories. All calculations,
model code, captions, and identity-handling logic remain in the preserved helper.
No field records, images, credentials, server logs, or private emails are included.

The SQL `OVERVIEW` definition remains in `DATABASE/views.SQL` as a retained
schema object; hiding the app entry does not drop a live view. No field-server
database connection, DROP statement, or biological-record change is part of
this withdrawal. The optional notA report has its own
[archive](../../notA-summary-archive/2026-11-08/README.md).

## Deployment and restoration

Merging is not deployment. Update the app through the normal human-controlled
deployment process, including removal of the former `main/R/ggplot_overview.R`
from the deployed helper directory. An overlay copy that leaves it behind
would continue loading unused definitions. Restart/reload the Shiny app through
the normal deployment procedure and reload existing client sessions after
deployment. No views import or To-do snapshot refresh is needed for app removal.

To restore later, first obtain explicit human approval, verify archive/member
checksums, and work on a branch from the then-current main. Restore the helper
to its original path and reapply only the archived Overview UI/server fragments
and view registration after reviewing shared dependencies. Do not replace whole
UI, server, global, or SQL files, which would discard later collaborator work.
Restore the relevant output/poll tests, check normal functionality with invented
inputs in an authorized environment, and obtain approval before deployment.

The existing synthetic plot tests explicitly load the archived helper for
historical regression checks; the running app does not load this archive.
Source-only withdrawal checks do not start Shiny, open a database, read dumps,
or establish live deployment. Reconstruction and scientific reference remain
available without silently recreating the withdrawn dashboard.

See the [combined withdrawal verification](../../APP_FEATURE_WITHDRAWAL_2026-11-08.md)
for the source checks, archive checksums, and test limits.
