# App-feature withdrawal and archive verification

Luke requested withdrawal of the core/full manuals, all Overview panels, and
the notA summary from the app, while preserving the work safely. This source
change does not deploy the app or drop any live database object.

## Preserved source

- The [manual archive](field-manual-archive/2026-11-08/README.md) retains twelve
  original files: English/German Markdown and HTML for both readers, styles,
  JavaScript, original reader README, and renderer. All twelve files match
  their original Git blobs byte-for-byte; SHA-256, MD5, original paths, and
  source commit are recorded in the manifest.
- The [Overview archive](overview-archive/2026-11-08/README.md) retains the
  complete 3,174-line plot/query helper and a compressed nine-file snapshot of
  the original shared UI/server/global/Intro/test/SQL context. Each archive
  member was checked against its pinned Git blob, and its SHA-256 is recorded.
- The [notA archive](notA-summary-archive/2026-11-08/README.md) retains the
  original SQL definition unchanged, with its checksum and source commit.
- No archived source content, attribution, AI-use disclosure, scientific rule,
  or original inspector definition was rewritten.

## Active app scope

The Field Manual and Overview sidebar/tab entries are removed. No manual
iframe, public manual asset, Overview plot helper, chart renderer, chart-only
reactive, growth-chart poller, or notA report/help/watch registration remains
in the active app. The separate OVERVIEW table entry is hidden as well.

Downloads, To-do PDF logic, remaining Show Views outputs, live nest maps,
Field Resightings, data-entry forms, validation-pause tooling, and raw tables
remain. The SQL OVERVIEW definition is retained in views.SQL, and an existing
notA view on the server is not dropped. App withdrawal is not database deletion.

The reconstruction crosswalk now resolves manual/report source against their
archives. The default bootstrap no longer installs or probes the withdrawn
notA report; the next-reference-date snapshot publication step remains. Archive
source is included in its frozen source manifest. No automatic republication
or restoration of the withdrawn features is authorized.

## Focused verification

All **438 database-free assertions** passed:

| Focused file | Passed assertions | Skipped test cases |
| --- | ---: | ---: |
| test-field-manual.R | 353 | 0 |
| test-withdrawn-app-features.R | 44 | 0 |
| test-nota-summary.R | 13 | 2 |
| test-thread8-display-nest-links-2026-10-26.R | 28 | 0 |

The two notA database tests were deliberately disabled; no socket or database
was used. The checks cover archive/source checksums, absent app registrations,
retained navigation/view lists, deterministic four-page manual builds in
temporary fixtures, stale-translation rejection, preserved protocol anchors,
and invented map/PDF display-link regressions. The archived Overview helper is
loaded only into an explicitly guarded test environment, not into the app.

Edited R sources parsed successfully. The edited reconstruction bootstrap
passed Python AST syntax inspection only; it was not executed. The broader
app-wiring/server tests were adapted to the new publication state, but were
not run in this focused source-only check. No full reconstruction bootstrap,
database replay, app startup, browser rehearsal, field dump, credentials,
server connection, or live deployment is claimed.

## Human deployment and restoration

Deploy the reviewed source through the usual human-controlled process. Ensure
old public manual files and the old Overview helper are actually removed,
rather than retained by an overlay deployment. Preserve server-only custom
files before targeted cleanup; do not delete the whole public/helper directory.
Restart/reload the app process and refresh client sessions. No Adminer SQL or
To-do snapshot rebuild is required for these app-only changes.

Downloaded, cached, or already-open copies are not erased, and GitHub archives
remain available. Each archive guide explains how to restore source through
a separate reviewed branch without overwriting later collaborator work.
