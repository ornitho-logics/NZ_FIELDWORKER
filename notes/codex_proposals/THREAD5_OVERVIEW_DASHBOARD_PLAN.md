# Thread 5 Overview Dashboard: Current-State Design and Maintenance Protocol

## Protocol status

This is the current Thread 5 maintenance memo after static inspection on
2026-10-23. It supersedes the earlier July and October memos where they
describe fewer panels, visible pair tallies, archive-driven combo sex, or the
old panel order.

Two repository states must be kept distinct:

- The protected checkout is `codex/split-todo-calculator-2026-10-19` at
  `d3c7bd4`. It contains unrelated uncommitted SQL, PDF, validator, Thread 2,
  Thread 4, Thread 6, and test changes. It is not a deployment candidate.
- The original inspection used `origin/main` at `9beb203`; references to that
  revision below preserve the audit chronology. The documentation publication
  baseline is now `origin/main` at `f7d13fb`, which includes the refresh
  empty-statement correction merged through PR #147. This memo is
  documentation only and does not reconcile or deploy the protected WIP.

No database connection, Shiny run, raw-data inspection, credential inspection,
or live deployment check was performed.

## Ownership and boundaries

Thread 5 owns the Overview UI contract, plot calculations, panel-specific
reference-date behavior, plotting conventions, and Overview-focused tests.

- Thread 1 owns repository mapping, branch hygiene, and AGENTS governance.
- Thread 2 owns SQL architecture, view dependencies, object order, and
  deployment risk.
- Thread 3.1 owns inspectors, validation protocol, and mock-data realism.
- Thread 4 owns TODO, map, parent-association task semantics, and PDF behavior.
- Thread 6 owns combo normalization and available-combination generation.
- Thread 9 owns disposable local MariaDB replay and deployment troubleshooting.

Thread 5 may consume shared SQL objects, but should not silently redefine their
biological meaning. Changes to `CAPTURES_ARCHIVE`, `EGGS_HATCH_PREDICTION`,
`format_mark()`, parent-association SQL, or reference-date persistence require
the owning thread to be included in review.

## Current source map

The active Overview path is:

1. `main/ui.R` defines the Overview boxes and plot output IDs.
2. `main/server.R` owns `reference_date`, the shared date-limit reactive, the
   eight `renderPlot()` outputs, and the panel-specific error fallbacks.
3. `main/R/ggplot_overview.R` contains the Overview SQL, data preparation,
   identity reconciliation, models, plot helpers, and panel functions.
4. `main/global.R` sources the R helpers and registers the Overview view/browser
   configuration. It also loads `mgcv` and `patchwork` for chick growth.
5. `main/R/system_utils.R` and `main/R/system_utils_app.R` provide the
   reference-date/settings and database utility layer; they do not own the
   panel calculations.
6. `main/www/style.css` supplies generic card/header and page styling. There is
   no current Overview-specific mobile CSS that replaces the plot helpers.

The current local checkout and `origin/main` both contain eight Overview panel
families. The local checkout order is nest, geolocator, tagged histories, band
combinations, lay date, hatching forecast, chick growth, quotas. `origin/main`
currently orders them as quotas, lay date, hatching forecast, nest discovery,
unique combinations, geolocator, chick growth, and tagged histories, with
Cass-prefixed titles. The output IDs and calculation families are the same.
Do not infer that a source change is deployed merely because it exists in a
local branch or another remote topic branch.

## Current panel inventory

| Panel | Output ID | Current calculation scope | Plot |
|---|---|---|---|
| Nest discovery | `overview_nests_show` | Cass, `site = 'CR'` | Grey cumulative step ribbon |
| Geolocator deployments | `overview_geolocator_show` | Cass, `site = 'CR'` | Female/male cumulative step ribbons |
| Tagged-bird resighting histories | `overview_tagged_resightings_show` | Cass GEO deployments and sex-matched later resightings | Two-row history plot |
| Unique adult band combinations encountered | `overview_cr_combos_show` | Cass adult CAPTURES plus adult RESIGHTINGS | Female/male cumulative step ribbons |
| Estimated lay date | `overview_lay_date_show` | Cass nests linked to `EGGS_HATCH_PREDICTION` | Four-day histogram |
| Hatching Forecast | `overview_hatching_forecast_show` | Nonblank future prediction rows | One-day histogram with reference marker |
| Chick growth | `overview_chick_growth_show` | Age-C captures linked to known hatch dates | Three-column growth figure |
| Manipulation quotas | `overview_quota_show` | Project-wide counts | Four proportional quota pies |

All boxes are full-width, collapsible, and initially expanded. The local
checkout uses approximately `50vh` boxes for the first seasonal plots, `105vh`
for tagged histories, `55vh` for chick growth, and `40vh` for quotas. The
remote baseline uses the same output sizing families while changing order and
titles. Smartphone behavior is primarily handled in the plot themes, label
wrapping, free-y facet space, and stacked full-width boxes.

## Reference-date and reactive protocol

`server.R` initializes a local `reference_date <- reactiveVal(get_reference_date())`.
The database setting is watched through `reactivePoll()` and
`dbtable_is_updated('settings')`. The Set action validates the date, updates
the local reactive immediately, and schedules `set_reference_date()` through
`later()`. If persistence fails, the previous local value is restored.

`active_refdate()` is the date passed to every panel. The first five date-based
panels also receive `overview_plot_date_limits(active_refdate())`. Hatching
forecast calculates its own date limits around the reference date; quotas have
no date axis. Chick growth additionally polls `CAPTURES` and `NESTS` so new
measurements invalidate that output.

All panel SQL uses parameter placeholders and supplies the reference date via
`params`; date strings are not interpolated into SQL. A panel query error is
converted by `try_else()` to a panel-specific fallback such as
`overview_band_combos_graph() failed!`; an empty query result is a valid empty
plot and must not be represented as a query failure.

The main timing risk is `EGGS_HATCH_PREDICTION`: its view may itself depend on
the database settings reference date while the outer R query already uses the
new local date. A fast render immediately after Set can therefore combine a
new outer cutoff with view rows materialized under the prior setting. This
requires a read-only timing test or user-side verification; it is not a reason
to route the Overview plots through the SQL `OVERVIEW` view.

## Shared date ranges and plot helpers

`overview_date_limits()` queries the earliest qualifying date through the
active reference date from a union of:

- Cass Found rows in `NESTS`;
- all Cass-dated `CAPTURES` rows;
- all Cass-dated `RESIGHTINGS` rows; and
- calculated Cass lay dates from `EGGS_HATCH_PREDICTION`.

The union is an alignment window, not a statement that every event contributes
to every panel. If no usable start date exists, it falls back to 30 days before
the reference date. The seasonal panels use seven-day date breaks and angled
labels. The forecast uses three-day labels, starts three days before the red
reference line, and includes predicted dates strictly after the reference date.

`overview_cumulative_counts()` counts already-deduplicated events by day and
applies a within-sex cumulative sum. `overview_step_ribbon_data()` expands
each series into horizontal and vertical vertices. The ribbons therefore have
only cumulative steps, not diagonal interpolation. They are visual fills, not
uncertainty intervals.

The common cumulative style is:

- Female red `#c43c39` and Male blue `#2878b5`;
- semi-transparent overlapping fills;
- integer y-axis breaks through `overview_integer_breaks()`;
- no Date x-axis title; and
- summary annotations at the upper-left plot edge, with legend placement moved
  down when annotations would overlap it.

The cumulative panels do not display statistical confidence intervals. The
only interval currently plotted in Overview is the approximate 95% interval
around the marginal GAMM-style trend in the chick-growth panel.

## Panel protocols

### 1. Seasonal progression in nest discovery

**Source and filter.** `NESTS`; `nest_state = 'F'`, `site = 'CR'`, non-null
`date`, and `date <= reference_date`.

**Unit and date.** Rows are ordered by date/time and `pk`; the first qualifying
row per `nest_id` is retained. The plotted date is that first Found date.

**Plot and annotation.** A grey cumulative step ribbon shows the number of
found nests. The annotation is `Total nests found = N`. There is no sex
classification and no pair tally.

**Empty behavior.** An empty result returns aligned date axes and the zero
summary annotation without event steps. A query error uses the panel fallback.

**Risks.** The current R reduction is by `nest_id` but does not explicitly
exclude every blank/malformed identifier before grouping. Nest IDs are not
globally unique across seasons, so the active database and site filter define
the intended context.

### 2. Seasonal progression in geolocator deployments

**Source and filter.** `CAPTURES`; `site = 'CR'`, `tag_type = 'GEO'`,
`tag_action = 'D'`, nonblank `tag_id`, non-null date, and date through the
reference date.

**Unit and sex.** The deduplication key is `tag_id`; the first ordered row is
used for its date. `F`/`FU` maps to Female and `M`/`MU` maps to Male. A tag ID
with more than one distinct known sex is omitted; unknown-sex tags are omitted.
This counts unique tag IDs, not capture rows and not necessarily unique birds.

**Plot and annotation.** Overlapping female/male cumulative step ribbons show
the number deployed. The annotation contains only `N females = Y` and
`N males = Z` in the current source. Earlier pair-count annotations are
obsolete and are not part of this panel's current rendering.

**Empty behavior and risks.** Empty or unresolved-sex data produce aligned axes
and zero sex annotations. Reusing a tag ID counts it once, even if it appears
on more than one bird. `CAPTURES_ARCHIVE` genetic sex is not consulted here.

### 3. Resighting histories of geolocator-tagged birds

**Deployment source and filter.** GEO deployment rows come from Cass
`CAPTURES` with nonblank `tag_id`, `tag_type = 'GEO'`, `tag_action = 'D'`, a
known normalized field sex, and date through the reference date. The first
deployment is retained per lower-tarsus mark plus sex; the `X_X` unbanded
deployment is excluded.

**Resighting source and match.** Cass `RESIGHTINGS` rows through the reference
date are matched by normalized LL/LR and sex, with resightings on or after the
deployment date. The SQL path does not use the `ring` field for this adult
history match. CAPTURES sex is the deployment anchor; a sex-specific identity
such as the two `BY-YB` birds remains separate.

**Display.** The plot has female and male facets in one column/two rows, with
free y-scale and free y-space. Facet labels are annotated as `Females` and
`Males`; the y-axis label is the displayed mark, with underscores converted to
hyphens and the sex suffix removed. A diamond marks deployment and circles mark
resightings. A single-band LR bird can display the UR spacer colour, so a
stored one-band representation is shown as the more informative mark where
the right-upper colour is available.

Deployment `capture_status = 'C'` produces a dashed history line; other or
missing statuses use solid lines. Limp status recognizes `limp0`, `limp1`, and
`limp2` plus legacy free-text phrases. The visible levels are `No limp
reported`, `Possible/slight limp`, and `Limping`; missing comments default to
`No limp reported` as a display convention, not evidence that a gait check was
performed.

**Date range and styling.** The lower x-limit is two days before the first
deployment; the upper limit is the shared reference-date upper bound when
available. The x-axis title is omitted. The legend is vertical and below the
plot, and the caption explains diamonds, dashed lines, limp categories, and
the missing-comment convention.

**Empty behavior and risks.** Empty data produce a labelled empty plot with
the available date window. The match assumes lower-tarsus marks are stable
enough for the deployment/resighting link and that the recorded resighting sex
is correct after the capture anchor. It does not resolve arbitrary mark-change
history beyond the current LL/LR match.

### 4. Seasonal progression in unique adult band combinations encountered

**Sources and filters.** Current `CAPTURES` and current `RESIGHTINGS` are
queried separately. Both require adult age `A`, `site = 'CR'`, non-null date,
and date through the reference date. An optional explicit start date is
supported for diagnostics or future use.

**Identity normalization.** The R helper normalizes all four colour fields,
uses CAPTURES `_in` fields as fallbacks, maps `F`/`FU` to Female and `M`/`MU`
to Male, and anchors captured identities by recorded `ring`. It builds full,
lower-tarsus, flag, and spacer representations. Known single-LR/spacer cases
are handled when a UR value has a `T` spacer code or when a two-character LR
value encodes spacer plus lower-right colour. Engraved flag values in UL/UR
are retained as strong identity keys.

Resightings are matched to capture anchors in priority order: flag, full
representation, spacer representation, then lower-tarsus representation.
Candidate capture anchors are restricted to the observed sex where known.
Unmatched resightings are grouped by strong representation plus sex; lower-only
rows attach to a unique compatible strong group or remain a separate
sex-specific lower identity. This is the logic that prevents a captured bird
and its later resightings from being counted as two identities while retaining
legitimate sex-specific duplicates such as two `BY-YB` individuals.

**Important boundary.** The active plot does not query `CAPTURES_ARCHIVE` and
does not use archive genetic sex. `CAPTURES_ARCHIVE` remains relevant to other
views and combo workflows, but the current Overview combo reconciliation is a
current-season R-side identity pass. The SQL `format_mark()` function is not
the active identity reconciler for this plot.

**Unit, date, and annotation.** The deduplication unit is the reconciled
`identity_key`; the earliest current capture/resighting event date is plotted.
The annotation reports, by sex, total identities, identities with a capture,
and identities that are resighting-only. The captured count includes identities
that were later resighted; the resighting-only count excludes every captured
identity. Thus the two categories are mutually exclusive.

**Plot and diagnostic.** Female/male cumulative step ribbons are shown with
integer y breaks. `overview_band_combo_diagnostic()` reports aggregate adult
versus non-adult event rows, capture-only identities, resighting-only
identities, capture-plus-resighting identities, identities with multiple
normalized representations, and ambiguous resighting-event count. It does
not expose marks or raw records.

**Empty behavior and risks.** Empty or unresolved-sex results produce aligned
axes and zero sex annotations. Query failures show the panel-specific fallback.
Remaining risks include a bird changing marks in a way not captured by the
available representation keys, combination reuse by another bird, an
unresolved resighting, and identity anchors missing a usable recorded ring.

### 5. Seasonal progression in lay date

**Source and scope.** The primary source is `EGGS_HATCH_PREDICTION`, joined to
distinct nonblank Cass `NESTS` IDs. Prediction rows require non-null
`float_date` and `predicted_days_since_laying`, with `float_date <=
reference_date`.

**Calculation.** For each nest, the current helper computes:

```text
estimated_lay_date = MAX(float_date)
                     - ROUND(AVG(predicted_days_since_laying)) days
```

There is one estimated date per nest. The plot uses four-day bins and integer
y-axis breaks. It is not a sex-specific panel.

**Geolocator annotation.** The data query also attaches distinct Cass adult
GEO deployment IDs by nest. Numbers above bars are the number of unique GEO
tag IDs attached to parents of nests in that four-day lay-date bin. The
geolocator's deployment date does not define the bin; the associated nest's
estimated lay date does. A tag associated with a nest laid in an earlier bin
belongs to the earlier bin.

**Empty behavior and risks.** Empty output retains aligned date axes. The
estimate averages prediction rows before subtracting from the latest float
date, so multiple flotation occasions can create a biological approximation.
The query does not independently select one flotation occasion before averaging.
The panel is sensitive to the internal reference-date behavior of
`EGGS_HATCH_PREDICTION`.

### 6. Hatching Forecast

The helper queries `EGGS_HATCH_PREDICTION` for nonblank nests with predicted
hatch dates strictly after the active reference date, groups by nest, and
retains the earliest future prediction per nest. The current R plot uses a
one-day histogram, three-day x-axis labels, a lower limit three days before the
reference date, a red vertical reference-date line drawn above the histogram,
and a rotated `reference date` label just to the left of the line.

The current query does not join to Cass `NESTS` or apply `site = 'CR'`, even
though the remote UI title is Cass-labelled. That scope mismatch is an open
biological/UI question and must be resolved by Thread 5 with Thread 2 before
changing the query. Empty forecasts retain the reference marker without
inventing events. The plot is a view-backed forecast, not a confidence band or
guarantee of hatch success.

### 7. Seasonal progression in chick growth

**Source and filter.** `CAPTURES` age-C rows are inner-joined to the earliest
`NESTS` row with `nest_state = 'H'` for the same nonblank nest ID. Capture date
must be on or before the reference date, recorded `ring` must be nonblank, and
at least one of weight, culmen, or tarsus must be present. Negative ages are
excluded. The current query does not add a Cass site filter, so the UI's Cass
title should not be treated as a complete scope guarantee.

**Plot.** The patchwork figure has three columns: weight in grams, culmen in
millimetres, and tarsus in millimetres. The x-axis is days since the inferred
hatch date. Repeat measurements are joined within `ring`; single observations
remain points. Only the recorded `ring` is used for individual identity in the
plot; colour-band fields are not substituted.

**Population trend.** Each measure is fit with `mgcv::gam(..., method =
'REML')` using a thin-plate smooth of age plus random-effect smooths for ring
and nest ID when there is more than one level. Predictions exclude the
individual and brood random effects to show a marginal population trend. The
faint ribbon is an approximate normal 95% interval (`fit +/- 1.96 * se.fit`),
not a Bayesian CrI. Small or degenerate datasets omit the trend while retaining
the observations.

**Reference date and risks.** The server polls CAPTURES and NESTS every five
seconds for new growth data and passes the active reference date into the
query. The hatch-date proxy depends on the first `H` nest row, and the query
does not currently enforce a site filter. Those assumptions should be made
explicit before using the panel for cross-site reporting.

### 8. Current quotas for manipulations

This panel is intentionally project-wide and has no Cass filter. It is ordered
as eggs, geolocators, non-geolocator captures, and chicks in the local source;
the remote baseline puts it first in the Overview tab.

- **Eggs floated:** distinct `nest_id` plus `egg_id` in `EGGS`, dated through
  the reference date; quota 450.
- **Geolocators deployed:** distinct nonblank `tag_id` in GEO/D `CAPTURES`,
  dated through the reference date; quota 100.
- **Non-geolocator captures:** distinct `pk` in adult `CAPTURES`, dated through
  the reference date, with a nonblank blood sample or breast/primary sample
  code and either blank tag ID or `tag_action = 'O'`; quota 200.
- **Chicks processed:** distinct `pk` in age-C `CAPTURES` with a nonblank blood
  sample, dated through the reference date; quota 500.

Each pie uses a filled value capped at the quota and a white remainder of
`quota - filled`. The displayed subtitle retains the uncapped observed count
over the quota, so over-quota data remain visible. Zero data are an all-white
pie; query failures use the panel fallback.

## SQL view relationship

`OVERVIEW` is included in `main/global.R` as a database-browser view and has a
source watch list. The view exposes compact section/metric aggregates, but the
eight plot outputs above do not query it. The panel functions issue their own
parameterized reads from base tables and `EGGS_HATCH_PREDICTION`.

- `CAPTURES_ARCHIVE` is a compatibility/historical view used by other schema
  and combo workflows; it does not currently supply events or sex to the active
  unique-combo plot.
- `EGGS_HATCH_PREDICTION` supplies estimated lay dates and forecast dates and
  is also part of the shared date-range query.
- `format_mark()` is a SQL schema utility, not the active R-side identity
  reconciler for `overview_band_combos_graph()`.

Do not route the custom plots through `OVERVIEW` merely because the browser view
exists. If the view is changed, test the browser view and the custom panels as
separate consumers.

## Styling and responsive behavior

The generic CSS gives boxes rounded borders, light backgrounds, header accents,
and stacked full-width layout. It does not provide a dedicated Overview mobile
breakpoint. The plot code therefore controls mobile readability through:

- shortened or wrapped annotations where present;
- integer y-axis breaks;
- omitted Date x-axis titles;
- angled date labels;
- inside legends for cumulative sex plots;
- free y-space for the two tagged-history facets;
- a taller tagged-history output; and
- a one-row quota grid that may still be narrow on a phone.

The tagged-history legend and caption are below the plot in the current source.
Do not document a mobile-annotation topic branch as deployed unless it is
merged into the selected source revision.

## Current test coverage

`tests/testthat/test-main-server.R` and `test-app-wiring.R` currently cover:

- Overview output IDs, spinner wiring, and the eight server renderers;
- reference-date initialization and invalidation of all panels;
- parameterized query use and shared date limits;
- integer breaks, cumulative counts, and no-diagonal step ribbons;
- adult combo identity normalization, spacer/flag keys, sex-specific
  duplicates, capture/resighting overlap, and aggregate diagnostics;
- limp categories, displayed marks, deployment linetypes, facet structure,
  and tagged-history plot construction;
- lay-date bin width and geolocator annotation data;
- hatching forecast filtering and reference marker;
- chick-growth three-panel construction, ring-only identity, and query bounds;
- quota query construction and four pie outputs; and
- `OVERVIEW` browser registration and SQL presence.

Not covered or still weak:

- no full MariaDB execution fixture for the eight panel queries;
- no realistic fixture for every single-LR/spacer and engraved UL/UR variant;
- no archive genetic-sex precedence test for the active combo plot because the
  active plot intentionally does not use the archive;
- no end-to-end test of view-internal reference-date timing;
- no site-scope test for hatching forecast or chick growth;
- no biological validation of multi-occasion lay-date averaging;
- no screenshot/responsive test for the eight-box layout or quota grid; and
- no deployed-server test proving the selected Git revision is live.

## Developments since the July handoff

The dashboard moved from the original small set of nest/geolocator/lay-date
plots to eight panel families. Major changes include cumulative step ribbons,
shared date limits, proportional quota pies, hatching forecast with a visible
reference date, tagged-bird histories with structured limp categories and
changed-combination line styles, adult combo reconciliation across captures and
resightings, aggregate identity diagnostics, and a three-column chick-growth
figure with marginal GAMM-style trends.

The old assumptions that nest/geolocator plots are histograms, that pair counts
are shown in the two cumulative annotations, that the active combo plot uses
archive genetic sex, and that a GPS heatmap is part of the Overview are now
obsolete.

## Deferred and absent work

The earlier GPS track heatmap prototype was rejected and is absent from the
current UI, server, Overview helper, CSS, tests, and SQL dashboard path. It is
deferred, not silently implemented elsewhere.

Other deferred items include formal uncertainty for cumulative ribbons,
explicit unknown/conflicted-sex categories, a definitive site policy for
hatching and chick growth, a one-occasion lay-date estimator, and a responsive
quota layout.

## Maintenance protocol

Before changing a panel:

1. State the biological unit and deduplication key.
2. State the source table/view, event date, site scope, and reference-date
   cutoff.
3. State how sex conflicts, unknowns, flags, spacer colours, and mark changes
   are resolved.
4. Decide whether the shared date range applies.
5. Separate empty-data behavior from query failure.
6. Keep SQL parameterized and avoid introducing raw rows into tests or notes.
7. Add fake fixtures for duplicate rows, boundary dates, ambiguous identity,
   empty data, and conflicting metadata.
8. Update the focused tests and inspect both desktop and narrow-screen layout.
9. Compare the selected source revision with `origin/main` before claiming a
   PR is current.
10. Coordinate schema/view changes with Thread 2 and biological task changes
    with Thread 4.

## Recommended safe checks

Use only invented or repository-provided mock values for automated checks.

- Assert that reference-date events are included and later events excluded.
- Assert that repeated nest Found rows reduce to one earliest event.
- Assert that repeated GEO deployments reduce to one tag ID.
- Assert that one captured adult plus later resightings is one combo identity.
- Assert that two same-mark birds with different capture sexes remain separate.
- Assert spacer and engraved flag representations merge only when justified.
- Assert age-A filtering excludes chick/juvenile records from combo counts.
- Assert four-day lay bins count tags by nest lay bin, not deployment date.
- Assert the forecast starts after the reference date and the red marker is on
  top of the bars.
- Assert quota pies are proportional for zero, partial, exact, and over-quota
  values.
- Assert chick trends disappear gracefully for too-small mock datasets.
- Render a narrow mock plot layout without using confidential records.

## Rollback and authority

This file is tracked documentation. Rollback requires reverting only its
documentation commit. No database, SQL object, live inspector, app process, or
runtime configuration rollback is implied.

When documentation and source disagree, the selected clean Git revision and
its tests take precedence over this memo, downloaded dumps, stale preview
scripts, screenshots, or a deployed process whose revision has not been
verified.
