# Thread 5 Overview Dashboard: Current-State Design and Maintenance Protocol

## Protocol status

This tracked memo replaces the 28 July 2026 handoff as the current Thread 5
protocol. It was reconciled with repository-visible source on 2026-10-06 using
static inspection only.

Current inspection point:

- PR branch: `codex/parent-association-thread-docs-2026-10-06`
- base commit: `1617e84`, matching `origin/main` when the branch was created
- tracked Overview implementation: `main/ui.R`, `main/server.R`, and
  `main/R/ggplot_overview.R`
- reference-date support: `main/R/system_utils.R` and
  `main/R/system_utils_app.R`
- no database connection, Shiny run, or data inspection was used for this
  refresh

The standalone SQL `OVERVIEW` view is visible in the app's view browser, but it
does not supply any of the dashboard plots documented below.

## What I inspected

- `AGENTS.md`
- `notes/codex_proposals/THREAD1_REPOSITORY_MAP.md`
- `notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md`
- the previous version of this memo
- `notes/codex_logs/THREAD5_PROMPT_LOG.md`
- Git history from the July handoff through `7c1d502`
- `main/ui.R`
- `main/server.R`
- `main/global.R`
- `main/R/ggplot_overview.R`
- `main/R/system_utils.R`
- `main/R/system_utils_app.R`
- `main/www/style.css`
- relevant definitions in `DATABASE/views.SQL` and `DATABASE/functions.SQL`
- relevant tests in `tests/testthat/`
- current ignored Thread 5 preview scripts in `notes/codex_proposals/`

## Current user-visible dashboard

The Overview tab now contains seven full-width `bs4Dash::box()` panels in this
order:

| Panel | Output ID | Scope | Display |
|---|---|---|---|
| Seasonal progression in nest discovery | `overview_nests_show` | Cass (`site = 'CR'`) | Cumulative step plot |
| Seasonal progression in geolocator deployments | `overview_geolocator_show` | Cass (`site = 'CR'`) | Sex-specific cumulative step plot |
| Resighting histories of geolocator-tagged birds | `overview_tagged_resightings_show` | Cass GEO deployments and later resightings | Female/male event histories |
| Seasonal progression in unique band combinations encountered (resighted or captured) | `overview_cr_combos_show` | Cass (`site = 'CR'`) | Sex-specific cumulative step plot |
| Seasonal progression in lay date | `overview_lay_date_show` | Cass nests | Daily histogram |
| Hatching Forecast | `overview_hatching_forecast_show` | Future predicted hatches | Daily histogram |
| Current quotas for manipulations (Cass and elsewhere in NZ). | `overview_quota_show` | Project-wide | Four proportional quota pies |

All boxes are collapsible but initially expanded. Nests, deployments, band
combinations, lay date, and hatching forecast use `50vh` boxes. The tagged-
resighting plot has an explicit `105vh` output height so its two sex facets,
multi-row legend, and caption are not clipped. The quota box is `40vh`, and its
plot output is `32vh`. There are no panel-local inputs; all seven use the
app-level reference date.

## Current Overview code path

1. `main/ui.R` defines the seven boxes and output IDs under
   `tabName = "overview"`.
2. `main/server.R` owns the active reference-date reactive, creates the shared
   date limits, and calls the seven plot helpers.
3. `main/R/ggplot_overview.R` contains all current Overview queries,
   aggregation helpers, plotting helpers, and panel functions. There is no
   active separate `main/R/data_overview.R` path on this branch.
4. `main/global.R` sources `main/R/*.R` through the app startup pattern and
   loads the plotting/runtime packages.
5. `main/R/system_utils.R` supplies `get_reference_date()`,
   `set_reference_date()`, and settings-table update checks used by the server.
6. `main/R/system_utils_app.R` contributes app-level utility behavior, but the
   panel calculations themselves remain in `ggplot_overview.R`.

Each render call is wrapped in `try_else()`. A query or helper error therefore
produces a simple panel-specific failure plot, such as
`overview_band_combos_graph() failed!`, rather than terminating the app.

## Reference-date and reactive protocol

At startup, `server.R` initializes `reference_date <- reactiveVal()` from
`get_reference_date()`. It also polls the `settings` table every five seconds
through `reactivePoll()` and `dbtable_is_updated("settings")`.

When a user presses the reference-date Set button:

- the selected value is validated as a non-missing `Date`;
- the local reactive value is updated immediately;
- `set_reference_date()` is scheduled to persist the setting;
- the previous local value is restored if persistence fails.

`active_refdate()` is the single server-side date supplied to every Overview
helper. Changing it invalidates all seven plot outputs. Nests, deployments,
tagged resightings, combinations, and lay date receive
`overview_plot_date_limits()`, a shared reactive around
`overview_date_limits(active_refdate())`. The hatching forecast uses its own
future-date limits, and quotas have no date axis.

All Overview SQL uses `?` placeholders with the reference date passed in
`params`. The date is not interpolated into query text.

One maintenance risk remains: `EGGS_HATCH_PREDICTION` reads the database
`settings.reference_date` internally, while the app supplies its newly selected
date to the outer lay-date query immediately. A render that occurs before the
settings write completes could combine the new outer cutoff with view rows
calculated using the previous setting. This is a timing risk to test explicitly;
it is not evidence that every date change is stale.

## Shared date-range calculation

`overview_date_limits(refdate)` creates the common x-axis limits for the first
date-based seasonal panels. It returns the earliest qualifying date through
`refdate` from a
union of:

- Cass NESTS rows;
- Cass CAPTURES rows;
- Cass RESIGHTINGS rows; and
- calculated lay dates for Cass nests.

The CAPTURES and RESIGHTINGS contributions are not limited to records that
qualify for the geolocator or band-combination panels. The common start can
therefore precede the first plotted event in one or more panels. That is
intentional: it aligns the four date axes to the same field-season window.

If no usable minimum date is returned, the helper falls back to
`refdate - 30 days`. The upper limit is always the supplied reference date.
The quota panel has no date axis and does not use these limits.

## Shared cumulative-plot protocol

`overview_cumulative_counts()` reduces events to daily counts, optionally by
sex, and applies `cumsum()` within group. It assumes its input has already been
deduplicated to the unit the panel intends to count.

`overview_step_ribbon_data()` expands each cumulative series into explicit
horizontal and vertical vertices. The resulting ribbons and lines contain only
steps; there is no diagonal interpolation between dates.

The translucent ribbons are visual fills under cumulative counts. They are not
confidence intervals, uncertainty bands, model predictions, or sampling-error
estimates. The dashboard currently displays no statistical uncertainty.

For sex-specific panels:

- Female is red (`#c43c39`);
- Male is blue (`#2878b5`);
- ribbon alpha is `0.38` so overlapping cumulative fills remain visible;
- the line and fill legends are combined under the title `Sex`; and
- the legend is placed inside the upper-left region and moved down when a
  summary annotation is present.

`overview_summary_annotation()` places bold summary text inside the upper-left
plot region. Its x position is the shared lower date limit and its y position is
relative to the top of the plot. Current annotations use short labels to fit
smaller screens.

## Seasonal progression in nest discovery

### Source and filters

- source: `FIELD_2026_BADOatNZ.NESTS`
- `UPPER(TRIM(site)) = 'CR'`
- `nest_state = 'F'`
- non-null `date`
- `date <= reference_date`

The event timestamp combines `date` with `time_visit`, defaulting missing time
to midnight. Rows are ordered by timestamp and `pk`.

### Counting and display

- deduplication key: `nest_id`
- retained event: first qualifying Found row for each `nest_id`
- sex: not applicable
- date plotted: date of that first qualifying row
- plot: grey cumulative step line and ribbon
- y-axis: `Cumulative number of` / `found nests`
- annotation: `Total nests found = N`
- scope: Cass only

### Empty-data behavior

An empty result produces aligned axes and the annotation
`Total nests found = 0` without event steps.

### Assumptions and risks

- Repeated Found visits for a nest are correctly reduced to the earliest one.
- The query does not explicitly exclude blank or missing `nest_id`; malformed
  identifiers could form one blank group and one missing-value group.
- `nest_id` is not globally unique across all seasons. The current query relies
  on the active database representing the intended season and on the Cass site
  filter to define context.
- Exact `nest_state = 'F'` coding is assumed.

## Seasonal progression in geolocator deployments

### Source and filters

- source: `FIELD_2026_BADOatNZ.CAPTURES`
- `UPPER(TRIM(site)) = 'CR'`
- `tag_type = 'GEO'`
- `tag_action = 'D'`
- non-null `date`
- `date <= reference_date`
- nonblank `tag_id`

### Counting, sex, and display

- deduplication key: `tag_id`
- retained event: first qualifying deployment date for each tag ID
- Female: `field_sex` of `F` or `FU`
- Male: `field_sex` of `M` or `MU`
- unknown values are ignored
- a tag ID with more than one distinct known sex is removed from the plot
- plot: overlapping red and blue cumulative step lines and ribbons
- y-axis: `Cumulative number of` / `geolocators deployed`
- annotation: `N females = Y` and `N males = Z`
- scope: Cass only

### Empty-data behavior

An empty or entirely unresolved-sex result produces aligned axes, zero female
and male annotations, and no event steps.

### Assumptions and risks

- The metric is unique deployed tag IDs, not capture rows and not necessarily
  unique birds.
- Re-deploying the same tag ID is counted once at its first qualifying date.
- Accidental reuse of a tag ID on different birds is also counted once.
- Unknown-sex deployments and tag IDs with conflicting known field sexes are
  omitted, so the plotted total can be lower than all qualifying deployments.
- `CAPTURES_ARCHIVE` genetic sex is not used for this panel.

## Resighting histories of geolocator-tagged birds

### Source and filters

- deployments come from Cass `CAPTURES` rows with `tag_type = 'GEO'`,
  `tag_action = 'D'`, a nonblank `tag_id`, and date through the reference date;
- the first deployment is retained for each normalized lower-tarsus mark and
  known sex;
- later Cass `RESIGHTINGS` are matched by normalized LL/LR identity and sex;
- only resightings on or after deployment and through the reference date are
  displayed.

### Display and interpretation

- female and male histories are separate free-height facets;
- a diamond marks deployment and circles mark later resightings;
- dashed history lines identify deployment during a changed-combination capture;
- circle fill reports comment-derived limp status: no limp reported,
  possible/slight limp, or limping;
- tag spacer colour is restored in the displayed mark when a one-colour LR
  requires it; and
- the output height is `105vh`, with a vertical multi-row legend and wrapped
  explanatory caption for mobile readability.

The limp classifier supports structured `limp0`, `limp1`, and `limp2` text and
legacy phrases. Missing limp information is displayed as no limp reported; this
is a presentation convention, not proof that gait was assessed. Identity is
based on lower-tarsus mark plus sex, so reused or incorrectly entered marks can
merge histories.

## Seasonal progression in unique band combinations encountered

### Current-event sources and filters

- sources: current `CAPTURES` and `RESIGHTINGS`
- both sources require `UPPER(TRIM(site)) = 'CR'`
- non-null event date
- event date `<= reference_date`
- marks are normalized with the SQL `format_mark()` function from the four
  colour-band fields

CAPTURES uses `field_sex`; RESIGHTINGS uses `sex`. In both sources, `M` and
`MU` map to Male, `F` and `FU` map to Female, and other values are unresolved.

### Historical sex resolution

`CAPTURES_ARCHIVE` is consulted only for sex attribution of marks already
encountered in the current Cass CAPTURES/RESIGHTINGS union. Its historical rows
do not add events or dates to the cumulative series.

If a mark has exactly one distinct known archive genetic sex, that sex overrides
current field sex. If archive genetic sex is absent or conflicted, a mark is
retained only when the current encounter rows provide exactly one distinct known
sex.

### Counting and display

- deduplication key: normalized band combination (`mark`)
- retained event: earliest current Cass CAPTURES or RESIGHTINGS date per mark
- exact unbanded sentinels `X-X` and `XX-XX` are excluded using a binary
  comparison to avoid case-insensitive collation treating `X` as equivalent to
  lowercase colour code `x`
- unresolved-sex marks are omitted
- plot: overlapping red and blue cumulative step lines and ribbons
- y-axis: `Cumulative number of` / `unique combinations`
- annotation: `N females = W` and `N males = V`
- scope: Cass only

### Empty-data behavior

An empty or entirely unresolved-sex result produces aligned axes, zero female
and male annotations, and no event steps. Query failures instead show the
panel-specific fallback message.

### Assumptions and risks

- This is a count of unique normalized combinations, not guaranteed unique
  biological individuals.
- A bird whose combination changes can contribute more than one mark.
- Reuse of a combination by another bird remains one mark.
- Duplicate encounters across CAPTURES and RESIGHTINGS do not double-count a
  mark because only its earliest date is retained.
- A genetic-sex conflict does not override current sex. A consistent known
  current sex can still classify that mark.
- The panel depends on `format_mark()`, `CAPTURES_ARCHIVE`, and therefore the
  archive view's historic `BADOatNZ.CAPTURES` and `BADOatNZ.SEX` dependencies.
- The `BINARY` sentinel comparison is essential under case-insensitive database
  collations and should be retained in future refactors.

## Seasonal progression in lay date

### Source and filters

- primary source: `EGGS_HATCH_PREDICTION`
- Cass membership: an inner join to distinct nonblank `nest_id` values from
  `NESTS` where `UPPER(TRIM(site)) = 'CR'`
- non-null `float_date`
- non-null `predicted_days_since_laying`
- `float_date <= reference_date`

For each nest, the app calculates:

```text
estimated date = latest float_date
                 - round(mean(predicted_days_since_laying)) days
```

### Counting and display

- deduplication key: `nest_id`
- one calculated date per nest
- sex: not applicable
- date plotted: calculated estimated lay/clutch-completion date
- plot: one-day-bin grey histogram
- y-axis: `N estimated lay dates`
- annotation: none
- scope: nests linked to Cass

### Empty-data behavior

An empty result produces an empty histogram with the common aligned date axes
and no zero-count annotation.

### Assumptions and risks

- The estimate averages all qualifying prediction rows for a nest, then
  subtracts that mean from the latest float date.
- If a nest has predictions from more than one flotation date, values from
  earlier dates can be averaged against the latest date. This is a biological
  approximation and may bias the estimate.
- Repeated egg records can each contribute to the average; the app deduplicates
  nests, not egg observations, before calculating the mean.
- Any NESTS row assigning the `nest_id` to Cass is sufficient for inclusion;
  the join does not select only the latest nest row.
- The panel depends on the calibration and row-selection logic inside
  `EGGS_HATCH_PREDICTION` and its `predict_hatching` support table.
- Incomplete-clutch rows emitted by the view with null `float_date` are excluded
  by the app query.
- The view's internal reference-date dependency creates the timing risk noted
  in the reference-date section.

## Hatching forecast

The forecast queries `EGGS_HATCH_PREDICTION`, groups by nonblank `nest_id`, and
retains the earliest predicted hatch date after the supplied reference date.
It plots one anticipated event per nest in one-day bins. A red vertical line and
label show the reference date; the x-axis begins three days before that date and
extends through the latest future prediction. Empty results retain the reference
marker without inventing events.

The panel reflects view output rather than a separate forecasting model in R.
Its reliability therefore depends on current egg prediction and incomplete-
clutch logic, and it should not be interpreted as confidence intervals or a
guarantee that every forecast nest will hatch.

## Current quotas for manipulations

The quota panel is deliberately project-wide. It has no `site = 'CR'` filter,
which is why its title explicitly says Cass and elsewhere in New Zealand. Each
metric includes rows dated on or before the reference date.

The four pies are ordered:

1. Eggs floated
2. Geolocators deployed
3. Non-geolocator captures
4. Chicks processed

### Eggs floated

- source: `EGGS`
- key: distinct `nest_id` plus `egg_id`
- filters: nonblank `nest_id`, non-null `egg_id`, non-null date, date cutoff
- quota: 450
- risk: the query does not test float measurement fields, so any qualifying
  identified EGGS record is counted even if its flotation fields are blank

### Geolocators deployed

- source: `CAPTURES`
- key: distinct nonblank `tag_id`
- filters: `tag_type = 'GEO'`, `tag_action = 'D'`, non-null date, date cutoff
- quota: 100
- risk: repeated deployment of one tag ID counts once, even if it represents
  more than one deployment event

### Non-geolocator captures

- source: `CAPTURES`
- key: distinct `pk`
- filters: adult age `A`; at least one nonblank value in `blood_samp`,
  `breast_samp`, or `primary_samp`; and either blank `tag_id` or
  `tag_action = 'O'`; non-null date; date cutoff
- quota: 200
- risk: the sampling test is nonblank rather than a single literal code; that
  is intentional for the current categorical sample fields but should be
  revisited if their coding changes

### Chicks processed

- source: `CAPTURES`
- key: distinct `pk`
- filters: chick age `C`, nonblank `blood_samp`, non-null date, date cutoff
- quota: 500
- risk: processing is represented only by the blood-sample criterion

### Pie semantics and empty behavior

For each quota, the filled value is capped at the quota and the white remainder
is `quota - filled`. The subtitle displays the uncapped observed count over the
quota, so over-quota totals remain visible even though the pie is fully filled.
The count-to-quota ratio therefore determines the slice proportion directly.

Zero counts produce an all-white pie. SQL/query failure is different from zero
data and causes the quota panel's fallback error display.

## Styling and smartphone behavior

The date plots use `theme_bw(base_size = 22)`, no minor grid, angled date labels,
and seven-day date breaks. Current y-axis titles use line breaks to reduce width.
The cumulative panels use the shared colour, ribbon, legend, and annotation
helpers described above.

The seven boxes are full width and therefore stack vertically. The September
smartphone adjustment increased date-break spacing and shortened labels. The
tagged-history panel later gained a `105vh` plot, vertical legend, and wrapped
caption to prevent clipping. `main/www/style.css` still contains no Overview-
specific mobile media query, and the quota panel draws four pies in one row at
every viewport size. Smartphone layout should therefore be treated as improved,
not fully responsive or formally verified.

## Query and performance protocol

A full Overview redraw currently makes eleven logical database reads:

- one shared date-range query;
- one query each for nests, geolocators, tagged histories, combinations, lay
  dates, and hatching forecast; and
- four quota queries.

There is no panel-result cache beyond normal Shiny reactive reuse of the shared
date-limits expression. All seven outputs invalidate when the reference date
changes. The band-combination query is the heaviest current panel because it
unions two event tables, normalizes marks, groups sex evidence, and joins the
archive view.

Future optimization should begin with timing and query-plan evidence. Do not
introduce a new SQL summary table or materialized view solely from assumption.

## Relationship to SQL views and helpers

- `CAPTURES_ARCHIVE`: used only by the band-combination panel to resolve genetic
  sex for current encountered marks.
- `EGGS_HATCH_PREDICTION`: used by the lay-date panel and the shared date-range
  calculation, and directly supplies the hatching forecast.
- `OVERVIEW`: not used by any dashboard panel; it remains a separate tabular
  view exposed by the app's view browser.
- `format_mark()`: used by the band-combination query to normalize four colour
  fields into the comparison key.

Because `CAPTURES_ARCHIVE` depends on historical schema objects, its watch-list
and invalidation behavior should be checked whenever historic sex sources
change. Thread 2 previously noted that the current dependency list may not
explicitly watch every historic source used by the view.

## Current test coverage

Repository tests currently check that:

- all seven Overview output IDs and spinner containers are wired in the UI;
- all seven plot helpers initialize and rerun when the reference date changes;
- Overview queries receive parameterized reference dates;
- the expected Cass and archive clauses are present in selected query text;
- the shared cumulative helper calculates counts;
- step ribbons contain no diagonal segments;
- date limits are applied;
- the legend can be placed inside the plot;
- annotation layers use the intended vertical adjustment; and
- tagged-history mark formatting, limp classification, changed-combination line
  style, mobile legend/caption layout, and `105vh` wiring are retained;
- hatching-forecast bins and the reference-date marker are retained; and
- the separate SQL `OVERVIEW` view remains exposed in app configuration.

Current gaps include:

- no MariaDB execution test for the full band-combination query;
- no fixture-level assertions for archive genetic-sex precedence or conflicts;
- no explicit regression test for the binary `X-X`/`XX-XX` collation fix;
- no biological fixture tests for each panel's deduplication key;
- no test of multi-date egg prediction averaging;
- no test of quota scope or over-quota behavior;
- no explicit empty-data suite for all seven panels;
- no reference-date timing test involving the view's internal setting;
- no screenshot or responsive-layout test; and
- no assertion that current labels, seven-day breaks, or panel heights remain
  synchronized with this protocol.

No tests were run during this documentation-only refresh.

## Developments since the July handoff

The principal implementation changes are:

- `0c62422`: replaced nest/geolocator histograms with cumulative plots, added
  the Cass band-combination panel, introduced shared date limits, and expanded
  tests;
- `67a20c4`: added cumulative-panel summary annotations;
- `6425370`: fixed unbanded-sentinel filtering under case-insensitive collation;
- `dfd5047`: increased date-break spacing and shortened/wrapped labels for
  smartphone readability; and
- `1ee3359`: restored the sex legend title to `Sex` after temporary text tests;
- `55bd7c5` through `93c1cbf`: added and then enlarged/wrapped the tagged-bird
  resighting-history panel and limp-status presentation;
- `c5d2bf5` through `bb49bc3`: added and refined the hatching forecast and its
  reference-date/week labeling; and
- `3b2984a`: removed experimental parent-pair tally queries from visible
  Overview graph annotations. The helper functions remain isolated and tested,
  but current graph renderers do not call them.

This means the July four-panel and September five-panel inventories, histogram
descriptions for nest and geolocator progression, and older layout details are
obsolete.

## Status of earlier plans

### Still valid

- Overview additions should remain isolated in UI, server wiring, and focused
  helper functions.
- Queries should be parameterized and reference-date aware.
- New biological counting rules need explicit deduplication and mock fixtures.
- Existing panels should remain independently collapsible and failure-isolated.
- Real database data and coordinates should not be copied into tests or notes.

### Obsolete

- The dashboard no longer consists of only nests, geolocators, lay dates, and
  quotas; band-combination, tagged-history, and hatching-forecast panels are
  implemented.
- Nest and geolocator progression are no longer histograms.
- Three-day date breaks and older long annotation labels are no longer current.
- The old SQL-dump preview helper does not accurately represent the present
  Overview implementation.

### Deferred or absent

The proposed GPS track heatmap is not present in current UI, server, helpers,
tests, or SQL. It remains deferred after the earlier prototype was rejected; no
tracked heatmap path should be assumed to exist.

There is also no current uncertainty model for any panel. Adding confidence or
sampling uncertainty would be a new analytical feature, not a styling change to
the existing ribbons.

## Ignored preview scripts

Two Thread 5 preview scripts remain in the ignored proposal area:

- `THREAD5_OVERVIEW_CUMULATIVE_RDS_PREVIEW.R` contains a useful historical
  five-panel
  read-only RDS prototype, but it predates current seven-day breaks, label
  changes, and some source hardening.
- `run_fieldworker_full_app_from_latest_sql_dump.R` reflects older override
  patterns and does not safely mirror all current `db_get()`-based Overview
  paths. It should not be treated as the current local-render protocol without
  a focused refresh.

These are scratch aids, not source of truth. Current tracked app code and SQL
definitions take precedence.

## Maintenance protocol

Before changing an Overview panel:

1. State the biological unit being counted.
2. State the deduplication key and which event date survives.
3. State site scope explicitly: Cass-only or project-wide.
4. State how unknown and conflicting sex values are handled.
5. Confirm whether historical data supplies events, attributes, or both.
6. Apply the reference date with a parameterized query.
7. Decide whether the panel belongs on the shared date range.
8. Define zero-data behavior separately from query-error behavior.
9. Add fake fixtures for duplicates, boundary dates, sex conflicts, and empty
   results.
10. Check desktop and narrow-screen rendering without using confidential rows.

Changes to `format_mark()`, `CAPTURES_ARCHIVE`,
`EGGS_HATCH_PREDICTION`, `predict_hatching`, or reference-date persistence
must be treated as cross-layer changes and reviewed with the relevant schema
protocol before altering dashboard logic.

## Recommended mock and read-only checks

- Verify that events on the reference date are included and later events are
  excluded.
- Verify one nest with repeated Found visits counts once at its earliest date.
- Verify one tag ID with repeated deployment rows counts once.
- Verify unknown and conflicting deployment sexes are omitted as documented.
- Verify archive genetic sex overrides current field sex for a known combo.
- Verify archive conflict falls back to a single consistent current sex.
- Verify lowercase colour code `x` is not removed with the uppercase unbanded
  sentinels under case-insensitive collation.
- Verify a combo seen in both current tables counts once at its first date.
- Verify one nest with multiple egg prediction rows produces exactly one lay
  estimate using the documented formula.
- Verify nests, deployments, combinations, and lay dates receive identical
  shared x-axis limits; tagged histories share the reference-date upper bound
  but derive their lower bound from deployment history.
- Verify quota zero, partial, exact, and over-quota cases.
- Verify each query-error fallback independently.
- Verify date changes after the settings write, especially the lay-date panel.

Use fake records for automated checks. If query-plan evidence is needed later,
propose a narrow read-only diagnostic for a human to run rather than connecting
from an agent task.

## Known decisions and open maintenance questions

- Confirm whether the geolocator metric should continue to mean unique tag IDs
  or should instead represent deployment events or birds.
- Confirm whether unknown/conflicted-sex geolocator deployments should be shown
  in a third category rather than omitted.
- Confirm whether unique combinations are an acceptable proxy when a bird's
  marks can change or combinations can be reused.
- Confirm whether the lay calculation should select one flotation occasion
  before averaging predictions.
- Confirm whether `Eggs floated` should require an actual float measurement
  rather than any identified EGGS record.
- Decide whether quota pies should reflow on smartphones.
- Decide whether reference-date persistence should complete before dependent
  view-backed plots rerender.

## Rollback

This file is ignored local documentation. To roll back this refresh, restore the
previous local copy of
`notes/codex_proposals/THREAD5_OVERVIEW_DASHBOARD_PLAN.md`. No tracked app or SQL
rollback is required.

## How to check this protocol

Compare each panel section against:

- its box and output ID in `main/ui.R`;
- its render call in `main/server.R`;
- its query and plot helper in `main/R/ggplot_overview.R`;
- relevant view/function definitions in `DATABASE/views.SQL` and
  `DATABASE/functions.SQL`; and
- wiring/helper expectations in `tests/testthat/`.

The protocol should be refreshed whenever any of those layers changes.
