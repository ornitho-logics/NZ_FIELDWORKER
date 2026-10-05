# Thread 6 Combo-List Protocol

## Status

- Full protocol audit: 2026-09-22; Git/status refresh: 2026-10-06.
- Current PR base: `origin/main` commit `1617e84`.
- Active scope: Thread 6 combo-list maintenance for the 2026 FIELDWORKER app.
- Method: static, read-only inspection of tracked code plus narrow inspection of the
  latest local SQL dump and the approved recyclable-combo workbook.
- No live database, credentials, raw coordinates, or broad historical rows were
  accessed.
- This tracked memo documents current behavior. The present PR does not change
  `USED_COMBOS_DETAIL`, `AVAILABLE_COMBOS`, or banding policy; it only carries
  the refreshed handoff alongside Thread 4 parent-association work.
- It does not authorize a database deployment or a change to banding policy.

## Purpose and ownership

The combo-list system supplies conservative colour-band combinations that may be
assigned in future capture events. It has two operational outputs:

1. `USED_COMBOS_DETAIL`, an audit view that normalizes historical and current band
   fields into canonical two-colour left and right pairs where possible.
2. `AVAILABLE_COMBOS`, a candidate generator that globally subtracts every confidently
   normalized used pair and supplies the CR list consumed by the FIELDWORKER PDF.

For this active task, Thread 6 owns the combo-list protocol, maintenance triage, and
cross-thread handoffs. The tracked `AGENTS.md` still assigns Thread 6 to generic
QA/reproducibility. That text is stale for this one-off active role and was not edited.

Cross-thread ownership remains important:

- Thread 2 owns SQL architecture, view/function deployment review, derived types,
  permissions, and schema migration risk.
- Thread 3 owns save-time validation and connected mock-data realism. It must keep
  classic and tagged representations aligned with the canonical rules below.
- Thread 4 owns the FIELDWORKER to-do/PDF integration, including visible ordering,
  team allocation, preview parity, and reactive app dependencies.
- Thread 6 owns this protocol and coordinates combo-specific changes across those
  boundaries.

## Source-of-truth hierarchy

Use this order when sources disagree:

1. `DATABASE/functions.SQL`
2. `DATABASE/views.SQL`
3. `DATABASE/main_tables.SQL`
4. `main/R/pdf_todo.R`
5. `main/global.R`
6. current tests and local PDF-preview scripts as implementation evidence only
7. the latest local `FIELD_2026_BADOatNZ_*.sql` dump as a deployment snapshot
8. the recyclable-combo workbook as a supplementary human-maintained reference

Important current conflicts:

- The latest local dump by filename is
  `DATABASE/FIELD_2026_BADOatNZ_7311213.sql`, completed on 2026-07-31. Its deployed
  combo views predate current tracked SQL.
- That dump's `AVAILABLE_COMBOS` lacks the current fixed exclusions, ranking, and
  CR/CX compatibility gate.
- That dump's `USED_COMBOS_DETAIL` lacks the current tag-plus-two-colour-`LR` rule
  and does not treat `XX` as blank in the relevant right-side branch.
- The Thread 1 and Thread 2 memos were refreshed before the combo views reached their
  current form and do not list both combo views.
- The local full-app preview implements part of the candidate and ordering logic but
  not the current CR/CX gate. It also relies on the snapshot copy of
  `USED_COMBOS_DETAIL` rather than recreating all current normalization behavior.

Tracked SQL is therefore the current source of truth. The dump and preview scripts
are useful for detecting drift, not for overriding tracked logic.

## SQL object chain

The dependency chain is:

```text
format_mark()
  -> CAPTURES_ARCHIVE
  -> USED_COMBOS_DETAIL
  -> AVAILABLE_COMBOS
  -> todo_pdf_prepare_team_marks()
  -> Team marks table in the FIELDWORKER PDF
```

`CAPTURES_ARCHIVE` reads historical `BADOatNZ.CAPTURES` and joins a grouped lookup
from `BADOatNZ.SEX`. It is not a current-season union. The explicit current-season
release and input sources are added later inside `USED_COMBOS_DETAIL`.

## `format_mark()` contract

`FIELD_2026_BADOatNZ.format_mark(UL, LL, UR, LR)`:

- trims each supplied field;
- suppresses blank strings, `X`, and `M` independently;
- joins multiple visible segments on one leg side with `.`;
- uses `X` when a complete side has no visible segment; and
- returns `left-right` as `varchar(50)`.

Invented examples:

| Input `(UL, LL, UR, LR)` | Output |
| --- | --- |
| `('B', 'G', 'R', 'O')` | `B.G-R.O` |
| `('M', 'YY', 'X', 'GB')` | `YY-GB` |
| `('M', NULL, 'X', NULL)` | `X-X` |

`format_mark()` is a display formatter, not the complete canonical combo normalizer.
For example, it would display a raw tag/spacer arrangement with its raw segments.
`USED_COMBOS_DETAIL` first canonicalizes those segments and then calls
`format_mark('X', LL, 'X', LR)` to produce the canonical combo mark.

## Candidate-combo rules

### Colour alphabet

The complete candidate alphabet is:

```text
B, G, R, O, W, L, Y
```

`L` means lime. Repeated colours are allowed. No SQL rule requires the four colours
within a combo to be unique.

### Pair generation

The view cross-joins the seven colours with themselves to generate all 49 ordered
two-colour `LR` pairs. Order matters, so `BG` and `GB` are distinct, and pairs such
as `BB` are valid candidates.

Each available mark is represented canonically by:

- `LL`: exactly two allowed colour characters;
- `LR`: exactly two allowed colour characters; and
- `mark`: `format_mark('X', LL, 'X', LR)`, normally `LL-LR`.

### Site rules

| Site | Allowed `LL` | Allowed first character of `LR` |
| --- | --- | --- |
| `CR` | `OY`, `YR`, `YO`, `YY`, `LY`, `BY`, `WY` | any allowed colour |
| `AR` | `BW` | any allowed colour |
| `WN` | `WO` | `B`, `G`, or `R` |
| `WS` | `WO` | `O`, `W`, or `Y` |

The second `LR` character may be any allowed colour for every site.

Before used-combo subtraction, the rules produce 343 CR, 49 AR, 21 WN, and 21 WS
raw candidates. The fixed exclusions below reduce those maxima to 282 CR, 47 AR,
20 WN, and 20 WS before dynamic used-combo subtraction.

No `AU` candidate rule is implemented in the current view, even though historical
records or manual analyses may identify an AU scheme.

## Used-combo sources

`USED_COMBOS_DETAIL` unions three sources with `UNION ALL`:

1. Historical release fields from `CAPTURES_ARCHIVE`.
2. Current-season release fields from `CAPTURES.UL`, `LL`, `UR`, and `LR`.
3. Current-season capture/input fields from `CAPTURES.UL_in`, `LL_in`, `UR_in`,
   and `LR_in`.

The view retains `source_table` and `source_stage` so release and input histories can
be audited separately. It does not restrict by `capture_status`.

Consequences of the conservative policy:

- `F`, `R`, `C`, and `D` rows can all block a combo if their fields normalize.
- A dead bird (`capture_status = 'D'`) does not automatically release its combo.
- For a changed-combo event (`capture_status = 'C'`), a normalizable old `_in`
  combination and a normalizable new release combination both remain used.
- Duplicate source rows are allowed in the audit view, but `AVAILABLE_COMBOS`
  subtracts distinct normalized `LL`/`LR` pairs.
- Used pairs are global. Historical/current site is not part of the subtraction key.
  A pair used at one site is unavailable anywhere that the same pair occurs in the
  current candidate universe.

`CAPTURES_ARCHIVE.mark` is not parsed for subtraction. The audit view re-normalizes
the underlying band fields so classic and tag-style representations can converge on
the same canonical pair.

## Reference-date behavior

Every used source cross-joins the non-null row where:

```sql
settings.variable = 'reference_date'
```

A source row is included when:

```text
date <= reference_date
OR date IS NULL
```

Therefore:

- future-dated rows are excluded until the app's reference date reaches them;
- unknown dates are treated conservatively as already used; and
- changing the FIELDWORKER reference date dynamically changes the used set and the
  available list.

Important failure mode: if the `reference_date` row is absent or its value is null,
the `sr` CTE is empty. All three used-source CTEs then become empty, while candidate
generation still succeeds. That can make the system present an unsafe near-full
candidate pool. A non-null reference date is an operational prerequisite.

## Canonical normalization

Before normalization, band fields are trimmed, uppercased, and converted from blank
strings to null. Rows with all four raw fields null are omitted.

Allowed normalized pairs must match exactly:

```text
^[BGROWLY]{2}$
```

### Left side

Normalization is applied in this order:

1. One allowed colour in `UL` plus one allowed colour in `LL` becomes `UL || LL`.
2. If `UL` is null, `X`, or `M`, an allowed two-colour `LL` is used unchanged.
3. If `LL` is null, `X`, or `M`, an allowed two-colour `UL` is used unchanged.
4. Everything else becomes null.

Invented examples:

| Raw `UL` | Raw `LL` | Canonical left pair |
| --- | --- | --- |
| `Y` | `O` | `YO` |
| `M` | `YY` | `YY` |
| `X` | `BY` | `BY` |
| NULL | `WY` | `WY` |

`XX` is not treated as a left-side blank token by current SQL.

### Right side: tag/spacer records

A tag-style `UR` matches:

```text
^T[A-Z0-9]*[BGROWLY]$
```

For audit display, matching values are reduced to `T` plus their final allowed colour
in `UR_tag_norm`. Canonical right-pair behavior is:

1. Tag-style `UR` plus a two-colour `LR`: use `LR` unchanged. The spacer colour is
   ignored because `LR` already supplies the complete right pair.
2. Tag-style `UR` plus a one-colour `LR`: use the final spacer colour from `UR` as
   the first canonical colour, followed by `LR`.

Invented examples:

| Raw `UR` | Raw `LR` | Canonical right pair |
| --- | --- | --- |
| `TY` | `R` | `YR` |
| `TG` | `GB` | `GB` |
| `T9Y` | `B` | `YB` |

This is the critical duplicate-prevention equivalence: a classic deployment with
right pair `GB` and a tagged deployment represented as `TG` plus `GB` occupy the same
canonical right-pair space.

### Right side: classic records

After tag branches, normalization is:

1. One allowed colour in `UR` plus one allowed colour in `LR` becomes `UR || LR`.
2. If `UR` is null, `X`, `XX`, or `M`, an allowed two-colour `LR` is used unchanged.
3. If `LR` is null, `X`, or `M`, an allowed two-colour `UR` is used unchanged.
4. Everything else becomes null.

Invented examples:

| Raw `UR` | Raw `LR` | Canonical right pair |
| --- | --- | --- |
| `Y` | `G` | `YG` |
| `X` | `YG` | `YG` |
| `XX` | `OR` | `OR` |
| `M` | `WR` | `WR` |

### `is_normalizable`

`is_normalizable = 1` only when both canonical `LL` and canonical `LR` are exactly
two allowed colours. The canonical `mark` is then generated as `LL-LR`.

If either side fails, `mark` is null and `is_normalizable = 0`. The raw fields,
normalized tag field, source, stage, date, and status remain available in
`USED_COMBOS_DETAIL` for audit.

Examples that remain ambiguous or nonstandard include:

- a tag marker with no spacer colour;
- a tag/spacer with a missing `LR`;
- partial sides that cannot form exactly two colours;
- flags, unexpected symbols, or strings outside the allowed colour patterns; and
- left-side `XX` in a position where only null, `X`, or `M` is accepted.

Ambiguous rows are reported but are not subtracted from `AVAILABLE_COMBOS`, because
they have no confident canonical key. This is visible rather than silent at the audit
layer, but it remains an operational risk: a human should review changes in the
non-normalizable count before relying on a new combo list.

## Available-combo subtraction and fixed exclusions

`AVAILABLE_COMBOS` builds a distinct global used set from rows where
`is_normalizable = 1`, then left-joins candidates on `LL` and `LR`. A candidate is
kept only when no used pair matches.

The following fixed exclusions are then applied before ranking:

- every candidate with `LL = 'YR'`;
- every candidate with `LR = 'OR'`; and
- every candidate with `LR = 'RO'`.

These are hard-coded operational rules. Their biological or inventory rationale is
not documented in tracked SQL and should be confirmed before changing them.

## Ranking and CR/CX compatibility logic

After used subtraction and fixed exclusions, `ROW_NUMBER()` assigns `combo_rank`
within each original candidate site using:

1. `LL` beginning with `Y` first;
2. marks containing neither `L` nor `R`;
3. marks containing `L`, including marks containing both `L` and `R`;
4. remaining marks containing `R`;
5. `LL` in database collation order; and
6. `LR` in database collation order.

Because ranking happens after used subtraction, ranks can change whenever the
reference date or used set changes.

The output then applies a temporary compatibility gate to original CR candidates:

1. `LL` in `BY`, `WY`, `YY`, or `YO` remains labelled `CR` regardless of lime or
   rank.
2. Other CR candidates containing `L` anywhere are relabelled `CX`.
3. Other CR candidates with `combo_rank > 30` are relabelled `CX`.
4. Remaining candidates keep their original site code.

`CX` is a compatibility bucket, not a biological candidate site in `site_rules`.
The rule means all `LY` candidates become `CX`, `YR` is already excluded, and an
`OY` candidate remains `CR` only if it has no `L` and is within the first 30 ranked
CR candidates.

The gate does not guarantee that the view returns at most 30 rows labelled `CR`:
the four preferred `LL` groups are retained as CR even when their ranks exceed 30.
The PDF applies the actual hard limit of 30.

The view's final `ORDER BY` uses original site and `combo_rank`. Consumers should
still specify their own `ORDER BY`; SQL view row order is not a stable API contract.

## Output contract and types

`AVAILABLE_COMBOS` exposes only:

| Column | Intended derivation |
| --- | --- |
| `site_code` | original two-character site or temporary `CX` label |
| `mark` | `format_mark('X', LL, 'X', LR)` |
| `LL` | candidate left pair, explicitly cast to `CHAR(10)` upstream |
| `LR` | candidate right pair, explicitly cast to `CHAR(10)` upstream |

The site candidate is explicitly cast to `CHAR(2)` upstream and `format_mark()`
returns `VARCHAR(50)`. MariaDB may expose expression-derived view columns with
slightly different reported character types after the final `CASE`; use
`SHOW COLUMNS` against the deployed view to verify exact runtime metadata.

`USED_COMBOS_DETAIL` exposes 14 audit columns:

```text
source_table, source_stage, ring, date_, capture_status,
UL_raw, LL_raw, UR_raw, LR_raw, UR_tag_norm,
LL, LR, mark, is_normalizable
```

Routine reports should aggregate this view and should not print `ring` or raw rows.

## PDF integration and team allocation

`todo_pdf_prepare_team_marks()` runs a fresh query when no combo data is injected:

```sql
SELECT mark
FROM AVAILABLE_COMBOS
WHERE site_code = 'CR'
ORDER BY ...
```

Its live PDF ordering is:

1. `LL` beginning with `Y` first;
2. marks containing neither `L` nor `R`;
3. marks containing `L` but not `R`;
4. marks containing `R`, including marks containing both `L` and `R`;
5. `LL`; and
6. `LR`.

This differs from the SQL ranking only for marks that contain both `L` and `R`:
the view puts them in the `L` tier, while the live PDF query puts them in the `R`
tier because its `R` test occurs first.

After querying, the R code:

- keeps nonblank marks;
- takes the first 30;
- pads with blanks when fewer than 30 remain;
- constructs a three-row by ten-column matrix with `byrow = TRUE`; and
- labels the rows `Team 1`, `Team 2`, and `Team 3`.

Thus Team 1 receives ordered marks 1-10, Team 2 receives 11-20, and Team 3 receives
21-30. The PDF displays a note that non-lime 1.5x bands are used for the tibia
geolocator spacer and 2x bands are used on the tarsi.

If the database query errors, `tryCatch()` substitutes an empty mark table. The PDF
then renders three teams of blank cells rather than surfacing the query error. This
is a fail-soft presentation behavior, not evidence that no combos are available.

When preview scripts inject `available_combos`, the helper does not re-run the SQL
sort and trusts the injected order. The RDS preview scripts pre-sort with the view's
`L`-before-`R` interpretation, while live PDF SQL uses the `R`-before-`L` branch for
marks containing both. Preview and live ordering are therefore not fully identical.

## App and test integration

- `main/global.R` includes `AVAILABLE_COMBOS` in `dbtabs_show_views`.
- `USED_COMBOS_DETAIL` is not exposed in that user-facing view list and functions as
  a diagnostic/audit view.
- `dbtabs_show_view_sources` has no `AVAILABLE_COMBOS` entry. If the generic view
  browser depends on that watch list, its reactive refresh may not track changes in
  `settings`, `CAPTURES`, or historical capture data correctly.
- The PDF download does not use that watch list; it directly queries
  `AVAILABLE_COMBOS` during PDF preparation.
- Current `tests/testthat/` files contain no dedicated assertions for combo
  normalization, exclusion, ranking, the CR/CX gate, or team allocation.
- The local full-app preview partially reconstructs candidate generation and PDF
  ordering but omits the CR/CX gate and does not recreate the latest normalization
  from tracked SQL.

These gaps should be handled by Thread 4 for PDF/app tests and Thread 2 for SQL-view
tests or a local MariaDB fixture if such work is approved later.

## Recyclable-combo policy

The approved workbook was inspected only for `Sheet1` site, `LL`, `LR`, and reason
fields. It is a small manual register. Its reasons include both confirmed mortality
and replacement/rebanding. No SQL or R source reads the workbook.

Current policy is conservative "ever used" logic:

- dead-bird marks remain used;
- changed-event `_in` marks remain used;
- replacement/rebanding does not free the old pair;
- workbook entries do not override `USED_COMBOS_DETAIL`; and
- no automatic expiry or reuse date exists.

The workbook is therefore informational only. A potentially reusable combo should
remain outside `AVAILABLE_COMBOS` until an explicit reuse policy is approved.

Any future automatic reuse mechanism needs a separate, reviewable override source
and explicit answers to at least:

- whether recovery of remains is sufficient to release a combo;
- whether a replaced old combination can be released immediately;
- whether reuse is global or site-specific;
- whether a waiting period is required;
- whether both historical release and current `_in` evidence can be overridden;
- how contradictory or later records revoke an override; and
- who approves and audits each release decision.

Do not weaken `USED_COMBOS_DETAIL` by filtering out `D` or `C` rows as an indirect
way to implement recycling.

## Known temporary rules and unresolved questions

1. Confirm the intended lifespan and removal condition for the temporary `CX`
   compatibility bucket.
2. Confirm the rationale and permanence of excluding `LL = 'YR'` and
   `LR IN ('OR', 'RO')`.
3. Decide whether view ranking or PDF ordering should control marks containing both
   `L` and `R`.
4. Decide whether the view should itself expose exactly 30 CR rows or whether the PDF
   should remain the only hard limiter.
5. Decide whether an absent/null reference date should fail closed rather than
   expose a near-full candidate pool.
6. Decide whether non-normalizable used rows require a stronger quarantine rule or
   a mandatory review threshold before combo assignment.
7. Confirm whether `XX` should also be treated as blank on the left side and in the
   branch where `LR` is blank and `UR` contains the pair.
8. Decide whether an AU candidate scheme should be implemented. It is not currently
   present.
9. Decide whether and how the recyclable-combo workbook should become a governed
   data source. It is currently informational only.
10. Align the local SQL dump and preview harness with tracked combo logic before
    treating either as a regression fixture.
11. Add the missing `AVAILABLE_COMBOS` dependency watch-list entry if reactive view
    browsing is expected to refresh from `settings`, `CAPTURES`, and historical data.

## Safe read-only verification queries

These queries expose schema or aggregate counts only. Run them against an approved
local/mock database unless the user separately authorizes narrow live inspection.

### Confirm the formatter with invented values

```sql
SELECT
  FIELD_2026_BADOatNZ.format_mark('B', 'G', 'R', 'O') AS classic_example,
  FIELD_2026_BADOatNZ.format_mark('M', 'YY', 'X', 'GB') AS canonical_example;
```

Expected: `B.G-R.O` and `YY-GB`.

### Confirm reference-date availability

```sql
SELECT
  COUNT(*) AS reference_date_rows,
  MIN(value) AS reference_date_min,
  MAX(value) AS reference_date_max
FROM FIELD_2026_BADOatNZ.settings
WHERE variable = 'reference_date'
  AND value IS NOT NULL;
```

Expected: exactly one non-null row.

### Count normalized and ambiguous used rows

```sql
SELECT
  source_table,
  source_stage,
  is_normalizable,
  COUNT(*) AS n_rows
FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL
GROUP BY source_table, source_stage, is_normalizable
ORDER BY source_table, source_stage, is_normalizable;
```

### Confirm future-dated rows did not enter the used view

```sql
SELECT COUNT(*) AS used_rows_after_reference_date
FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL u
JOIN FIELD_2026_BADOatNZ.settings s
  ON s.variable = 'reference_date'
WHERE u.date_ IS NOT NULL
  AND u.date_ > s.value;
```

Expected: zero.

### Count conservatively included unknown dates

```sql
SELECT
  source_table,
  source_stage,
  COUNT(*) AS n_unknown_date_rows
FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL
WHERE date_ IS NULL
GROUP BY source_table, source_stage;
```

### Check tag plus two-colour LR normalization

```sql
SELECT COUNT(*) AS tag_two_colour_failures
FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL
WHERE LL REGEXP '^[BGROWLY]{2}$'
  AND UR_raw REGEXP '^T[A-Z0-9]*[BGROWLY]$'
  AND LR_raw REGEXP '^[BGROWLY]{2}$'
  AND (
    LR IS NULL
    OR LR <> LR_raw
    OR is_normalizable <> 1
  );
```

Expected: zero.

### Confirm no normalized used pair leaks into availability

```sql
SELECT COUNT(*) AS leaked_used_pairs
FROM FIELD_2026_BADOatNZ.AVAILABLE_COMBOS a
JOIN (
  SELECT DISTINCT LL, LR
  FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL
  WHERE is_normalizable = 1
) u
  ON a.LL = u.LL
 AND a.LR = u.LR;
```

Expected: zero.

### Count available rows by output bucket

```sql
SELECT site_code, COUNT(*) AS n_available
FROM FIELD_2026_BADOatNZ.AVAILABLE_COMBOS
GROUP BY site_code
ORDER BY site_code;
```

This safely reveals the dynamic CR/CX split without printing marks.

### Verify deployed column metadata

```sql
SHOW COLUMNS FROM FIELD_2026_BADOatNZ.AVAILABLE_COMBOS;
SHOW COLUMNS FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL;
```

### Reproduce the live PDF selection safely

Use invented/mock data when printing marks. Against a real database, replace the
selected columns with `COUNT(*)` unless mark output is explicitly approved.

```sql
SELECT mark
FROM FIELD_2026_BADOatNZ.AVAILABLE_COMBOS
WHERE site_code = 'CR'
ORDER BY
  CASE WHEN LEFT(LL, 1) = 'Y' THEN 0 ELSE 1 END,
  CASE
    WHEN CONCAT(LL, LR) NOT REGEXP '[LR]' THEN 0
    WHEN CONCAT(LL, LR) REGEXP 'R' THEN 2
    WHEN CONCAT(LL, LR) REGEXP 'L' THEN 1
    ELSE 0
  END,
  LL,
  LR
LIMIT 30;
```

## Rollback guidance

The combo views do not mutate base-table records. Before changing or deploying them:

1. save `SHOW CREATE FUNCTION format_mark` and `SHOW CREATE VIEW` output for
   `CAPTURES_ARCHIVE`, `USED_COMBOS_DETAIL`, and `AVAILABLE_COMBOS`;
2. apply or restore objects in dependency order: function, archive view, used-detail
   view, available view;
3. verify aggregate counts and the zero-leak query above; and
4. generate a fresh PDF rather than relying on an already downloaded file.

To roll back a view change, recreate the previously saved definition in the same
dependency order. Dropping `USED_COMBOS_DETAIL` or `AVAILABLE_COMBOS` without an
immediate replacement can make the PDF team table blank because the R layer catches
query errors.

For this documentation refresh, rollback is simply deletion/restoration of this
ignored memo and removal of the dated prompt-log entry. No tracked source or database
rollback is required.

## Suggested `AGENTS.md` replacement wording (not applied)

```text
### Thread 6 - Combo-list specialist

Purpose: maintain the conservative colour-combination availability protocol used by
FIELDWORKER, from historical/current capture normalization through PDF team marks.

Responsibilities:

* maintain the Thread 6 combo-list protocol memo;
* review format_mark(), CAPTURES_ARCHIVE, USED_COMBOS_DETAIL, AVAILABLE_COMBOS, and
  PDF team allocation as one workflow;
* preserve conservative global duplicate prevention and audit non-normalizable marks;
* keep recyclable combos separate from automatic availability unless an explicit
  governed override policy is approved;
* coordinate SQL changes with Thread 2, validator/mock-data changes with Thread 3,
  and PDF/app changes with Thread 4;
* provide aggregate read-only checks, rollback guidance, and deployment handoffs.

Restrictions:

* no live database access or writes unless explicitly approved;
* no credentials, raw historical-row output, or sensitive location output;
* no automatic freeing of dead, replaced, or workbook-listed combos without an
  approved policy;
* no tracked-file changes outside the exact user-approved scope.

Expected output:

* current combo protocol and source map;
* normalization and candidate-rule review;
* ambiguity/recycling audit recommendations;
* SQL/PDF compatibility findings;
* safe verification and rollback steps.
```
