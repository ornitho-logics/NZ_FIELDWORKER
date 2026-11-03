# Map-popup association metadata — verification, 1 November 2026

## Authorized scope

Luke approved readable per-parent association labels and two additive columns
on the derived parent snapshot. No base-table, inspector, raw-record,
association-ranking, chronology, capture-timing, tag-eligibility, or task-gate
change is included. This is candidate source verification, not deployment.

The existing event and identity aggregates now retain display provenance.
`ADULT_PARENT_NEST_ASSOCIATIONS.association_display_basis` follows the winning
level; `ADULT_PARENT_STATUS` appends `M_association_display` and
`F_association_display`. The existing staged parent BUILD declares these two
LONGTEXT columns in the same order. The refresh adds no stage or source scan.
Its existing publication replaces the derived table; no manual base-table
ALTER is needed. Existing pending-detail fields keep their contracts.

The app reads only the published small parent snapshot after the latest
refresh succeeds for the current settings date. It does not query expanded
live associations on map clicks. Missing columns, duplicate keys, mismatched
reference dates, or a different live identity withhold annotations. Counts are
as of the snapshot and require another successful build to incorporate later
observations. Existing map identities and marker/category decisions are retained.

## Source identities

| Runtime source | SHA256 |
| --- | --- |
| `DATABASE/views.SQL` | `89f84034d29ad12735388ba14abb1fff205fae35147dd02c472d80e06b9162bd` |
| `DATABASE/refresh_todo_list_snapshot.SQL` | `494dd95b6f82b25d0359742ae1d5e887297b3a0632421d7703ee59f7ef3817e6` |
| `main/R/leaflet_nest_latest.R` | `88a3c59b1fd01f0d8e45664dde41bdf85c793bee14e699fac6589188c37fa119` |
| `main/global.R` | `f93bf5361552310ce4616920e79bff668196bd29ffd4aaafef4d9a19760675dc` |
| `main/server.R` | `42d2e0978986947c71365bfb75e9166ad331f958f8d755b747162243d1f40b12` |

## Executed checks

- PASS: one fresh owned no-network MariaDB 11.8.9 installation and refresh
  using only the tracked invented reconstruction fixtures; case-sensitive
  table names (`lower_case_table_names = 0`). Views installation 37.756 s;
  refresh 18.167 s. These are synthetic local timings, not field-server or
  Adminer performance guarantees.
- PASS: latest publication succeeded for the synthetic reference date,
  four task rows; current TODO and snapshot typed columns and NULL-aware
  byte-value multisets match, including duplicates. The task-row digest equals
  the earlier verified synthetic run's digest. No BUILD/PREVIOUS tables remain.
- PASS: six focused suites after a fixture-query formatting repair: 89
  MM/X-X chronology/provenance assertions; 106 identity-confirmation assertions;
  12 selected-death/per-identity-display assertions; 687 task-source contracts;
  108 then-current manual checks; 55 comment-patch safeguards. Zero failures,
  skips, or warnings. SQL fixture retry used the same engine in a fresh owned
  no-network case-insensitive instance; installation/refresh were not repeated.
- PASS: 34 independent in-memory popup assertions, including actual Leaflet
  widget construction without browser/tile requests. Checks cover date choice,
  reference date, zero/blank/escaped values, current nest/sex identity, older
  snapshot dates, duplicate keys, pending candidates, selected proof, and old
  snapshots without the new columns. No app configuration or database access.
- PASS: source unchanged during each SQL run; both owned servers shut down,
  socket files gone, and the owned case-sensitive volume detached.

The first SQL fixture run had two failures because a helper formatting change
prevented an existing string substitution from adding the confirming/total
count projections. The assertions were retained, the helper repaired, and all
fixtures then passed without changing production SQL or expected counts.
The successful install/refresh evidence from that first run remains valid for
the SQL hashes above; the failed fixture result is not represented as a pass.
Private run evidence is retained locally under ignored `tmp/codex/`.

The subsequent manual v2.4.17 text/HTML update is documentation only and is
checked separately; it does not replace the SQL run's source identities.

## Limits and manual deployment

NOT RUN: new full field-dump replay, production queries, deployed phone/browser
inspection, or actual Adminer import of this candidate. No field data/config
or credentials were used. Synthetic equality is not full field equivalence.

After review/merge, install the updated views, run the updated refresh to a
successful publication, then deploy/reload the app. Older snapshots continue
to show plain identities without the new annotations. No inspector update is
required. Preserve normal backup, quiet-window, and stop-on-error controls.
To roll back, restore the prior SQL/R source and rebuild derived snapshots;
do not recreate the biological base tables or rewrite field records.

## Later same-day hatch-timing display addition

The map-only Hatch timing (days) addition reuses the existing PDF summary
formatter, published task values, and hatch-prediction metadata. No SQL changed,
so the SQL source hashes and installation evidence above remain applicable.
The R/map and manual changes postdate the source identities above; they were
checked separately with 45 invented-data popup assertions (including PDF value
parity, brood ages, task/date overrides, no-float suppression, and explicit
flotation exemptions) and 112 manual assertions. All passed, without database,
app, browser, tile, or PDF-render access. No further SQL integration run or field
replay was performed for this display-only addition. It needs only an app update.
