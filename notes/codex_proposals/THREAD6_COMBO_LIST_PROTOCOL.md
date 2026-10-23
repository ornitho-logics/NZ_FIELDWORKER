# Thread 6 Combo-List Protocol

## Status and purpose

This is the restart-grade specification for conservative colour-combination
availability and the FIELDWORKER PDF Team marks handoff.

- Refreshed: 2026-10-23.
- Original remote baseline inspected: `origin/main` at `9beb203`; references
  below preserve that audit chronology.
- Documentation publication baseline: `origin/main` at `f7d13fb`, including
  the refresh empty-statement correction merged through PR #147.
- Protected checkout inspected: `codex/split-todo-calculator-2026-10-19` at
  `d3c7bd4`, with unrelated uncommitted SQL, R, validator, documentation, and
  test changes. It is not a deployment candidate.
- Live database and deployed Shiny process: not established.
- Scope: `format_mark()`, `CAPTURES_ARCHIVE`, `USED_COMBOS_DETAIL`,
  `AVAILABLE_COMBOS`, and the PDF Team marks preparation boundary.
- Non-goals: save-time validators, task eligibility, map biology, Overview
  design, live deployment, database writes, and automatic recycling of used
  combinations.

This memo records source behavior, not a claim that the same definitions are
installed in the target database. A clean selected Git revision, the matching
SQL files, the matching refresh workflow, and object-level database checks are
required before deployment.

## Ownership and boundaries

Thread 6 owns canonical combo normalization, conservative used-pair subtraction,
candidate generation, ranking, CR/CX compatibility, ambiguity auditing, and the
PDF team-mark handoff.

- Thread 1 owns repository maps, branch hygiene, and AGENTS governance.
- Thread 2 owns SQL architecture, dependency order, derived types, permissions,
  migration risk, and deployment review.
- Thread 3.1 owns validators, mock-data realism, and alignment of mock band
  representations with this canonicalization.
- Thread 4 owns to-do/PDF/map task semantics, rendering, and PDF regression
  behavior. Thread 6 supplies the combo pool but does not reimplement task logic.
- Thread 5 owns Overview behavior.
- Thread 9 owns isolated local MariaDB replay, stage timing, and deployment
  troubleshooting.

The current `AGENTS.md` contains a `Thread 6 - Combo-list specialist` role and
matches this scope. The older QA/reproducibility placeholder is preserved in the
prompt log as history. No AGENTS edit is needed for this refresh.

## Source-of-truth and state labels

Use the following authority order when sources disagree:

1. `DATABASE/functions.SQL` for the formatter contract.
2. `DATABASE/views.SQL` for archive, audit, candidate, and downstream view logic.
3. `DATABASE/main_tables.SQL` and `DATABASE/support_tables.SQL` for columns and
   support-table contracts.
4. `main/R/pdf_todo.R` and `main/templates/todo_pdf.qmd` for PDF selection,
   allocation, and rendering.
5. Current focused tests as executable implementation evidence.
6. The latest local SQL dump as a deployment/alignment snapshot only.
7. The recyclable-combo workbook as an informational human register only.

State labels used in this memo:

- **Remote baseline:** committed files at the inspected `origin/main` revision.
- **Protected WIP:** uncommitted files in the active checkout. They must not be
  copied into a database merely because they are present locally.
- **Local snapshot/replay:** a disposable or downloaded artifact. It does not
  override tracked source and does not prove live deployment.
- **Live deployment:** database objects and a restarted app process. It is not
  established by this documentation pass.

The repository contains dated dumps through
`DATABASE/FIELD_2026_BADOatNZ_7311213.sql`; the newest user-supplied downloaded
snapshots are outside the repository. Both are snapshots, not SQL source truth.
The tracked remote baseline includes the later `GY` policy; the protected dirty
checkout's `DATABASE/views.SQL` is older in the combo section and lacks `GY`.
Keep this distinction explicit.

## Dependency chain

```text
functions.SQL: format_mark()
        |
        v
CAPTURES_ARCHIVE  -- historic BADOatNZ.CAPTURES + BADOatNZ.SEX dependency
        |
        +--> USED_COMBOS_DETAIL <--- current FIELD_2026 CAPTURES final/_in fields
                        |
                        v
              AVAILABLE_COMBOS
                        |
                        v
main/R/pdf_todo.R::todo_pdf_prepare_team_marks()
                        |
                        v
              Team marks table in the PDF
```

There is no current `CAPTURES_active` definition in the inspected tracked SQL
source or current app wiring. References to that name are historical or belong
to another source revision. Current-season final and `_in` fields are read
directly from `FIELD_2026_BADOatNZ.CAPTURES` inside `USED_COMBOS_DETAIL`.

`CAPTURES_ARCHIVE` is not a current-season union. It reads historic
`BADOatNZ.CAPTURES` and a grouped `BADOatNZ.SEX` lookup. The current-season
union is deliberately added later by `USED_COMBOS_DETAIL`.

## Formatter contract

`FIELD_2026_BADOatNZ.format_mark(UL, LL, UR, LR)`:

- trims each input;
- ignores blank strings and the placeholders `X` and `M` independently;
- joins the retained upper/lower field values on each leg side with `.`;
- uses `X` when a complete side has no visible retained value; and
- returns a left-right `varchar(50)` mark.

Invented examples:

| Inputs `(UL, LL, UR, LR)` | Display result |
| --- | --- |
| `B, G, R, O` | `B.G-R.O` |
| `M, YY, X, GB` | `YY-GB` |
| `NULL, BY, XX, GW` | `BY-GW` |

The formatter is a display function, not the complete combo identity rule.
`USED_COMBOS_DETAIL` canonicalizes raw fields first, then calls
`format_mark('X', canonical_LL, 'X', canonical_LR)` for a canonical two-pair
display mark.

## Candidate-combo generation

The allowed colour alphabet is exactly:

```text
B, G, R, O, W, L, Y
```

`L` means lime. Repeated colours are valid. The SQL does not require the four
bands to be unique.

The view cross-joins the alphabet with itself to produce all 49 ordered `LR`
pairs. Order matters: `BG` and `GB` differ, and `BB` is valid.

### Site rules

| Candidate site | Allowed `LL` | Allowed first `LR` character |
| --- | --- | --- |
| `CR` | `OY`, `YR`, `YO`, `YY`, `LY`, `BY`, `WY`, `GY` | any colour |
| `AR` | `BW` | any colour |
| `WN` | `WO` | `B`, `G`, or `R` |
| `WS` | `WO` | `O`, `W`, or `Y` |

The second `LR` character is any colour for every site. `CX` is not a candidate
site rule; it is a compatibility label applied to some original `CR`
candidates after subtraction and ranking. `AU` has no current candidate rule.

Before dynamic used subtraction, the current remote rules generate:

- 392 raw `CR` candidates;
- 49 raw `AR` candidates;
- 21 raw `WN` candidates; and
- 21 raw `WS` candidates.

After excluding `LL = 'YR'` and `LR IN ('OR', 'RO')`, the maxima are 329, 47,
20, and 20 respectively. Used-pair subtraction then reduces these counts.

## Used-combo evidence

`USED_COMBOS_DETAIL` uses `UNION ALL` over three evidence sources:

1. historical release fields from `CAPTURES_ARCHIVE`;
2. current-season final fields `CAPTURES.UL`, `LL`, `UR`, `LR`; and
3. current-season input fields `CAPTURES.UL_in`, `LL_in`, `UR_in`, `LR_in`.

The current SQL does not add `RESIGHTINGS` to this used-combo union. Comments in
older or dirty source may use broader wording, but the CTEs above are the current
remote-baseline behavior.

The source keeps provenance columns (`source_table`, `source_stage`, date, status,
and raw fields) for audit. It does not filter by `capture_status`.

Consequences:

- final marks from `F`, `R`, `C`, and `D` rows can all block a pair if they
  normalize;
- a dead bird does not automatically release its pair;
- a changed-combo event retains both a normalizable old `_in` pair and a
  normalizable new final pair;
- duplicates in the audit view are expected; availability subtracts distinct
  canonical `LL`/`LR` keys; and
- subtraction is global. A pair used in one site candidate universe is blocked
  everywhere the same pair appears.

`CAPTURES_ARCHIVE.mark` is not parsed for this purpose. The underlying four band
fields are re-normalized so classic and tagged representations converge.

## Reference-date gate

Each used-source CTE reads the non-null `settings.value` where
`variable = 'reference_date'`. A row is used when:

```text
date <= reference_date OR date IS NULL
```

Therefore:

- future-dated evidence is excluded until the reference date reaches it;
- an unknown date is conservatively treated as already used; and
- changing the app reference date changes the used and available sets.

`AVAILABLE_COMBOS` also cross-joins the non-null reference-date CTE. If no
non-null reference-date row exists, its candidate path returns no rows rather
than exposing an unsafe full candidate pool. Operations should still maintain
exactly one non-null reference-date setting; multiple rows are a configuration
fault even though the current candidate `DISTINCT` can mask the duplication.

## Canonical normalization

Before normalization, fields are uppercased, trimmed, and blank strings become
SQL NULL. Rows with all four raw fields null are omitted.

The only canonical side values are exactly two characters from
`[BGROWLY]`. A row is `is_normalizable = 1` only when both canonical `LL` and
`LR` satisfy that grammar. Otherwise its canonical `mark` is NULL and it remains
visible in the audit view with `is_normalizable = 0`.

### Left side

The current order is:

1. one colour in `UL` plus one colour in `LL` becomes `UL || LL`;
2. null, `X`, or `M` in `UL` plus a two-colour `LL` uses `LL`; and
3. null, `X`, or `M` in `LL` plus a two-colour `UL` uses `UL`.

Everything else is non-normalizable. In particular, `XX` is not currently a
left-side blank token.

Invented examples: `UL=Y, LL=O` becomes `YO`; `UL=M, LL=YY` becomes `YY`;
`UL=X, LL=BY` becomes `BY`.

### Right side, geolocator tag/spacer

A tag-style `UR` matches:

```text
^T[A-Z0-9]*[BGROWLY]$
```

The audit display field `UR_tag_norm` retains `T` plus the final allowed colour.
The canonical right-side rules are:

1. tag-style `UR` plus a two-colour `LR` uses `LR` unchanged. `LR` already
   supplies the complete right pair, so the spacer is not prepended;
2. tag-style `UR` plus a one-colour `LR` uses the final allowed colour after `T`
   as the first right colour, followed by `LR`; and
3. non-tag one-colour `UR` plus one-colour `LR` uses `UR || LR`.

Invented examples:

| Raw fields | Canonical right pair |
| --- | --- |
| `UR=TY, LR=R` | `YR` |
| `UR=TY, LR=GB` | `GB` |
| `UR=T9Y, LR=B` | `YB` |
| `UR=X, LR=YG` | `YG` |

This is the duplicate-prevention equivalence between a classic right pair and a
tagged representation. For example, `LL=YY, UR=TG, LR=GB` occupies `YY-GB`,
not a five-band identity.

A literal combined value such as `UR='TY.G'` is not accepted by the current
regex because the stored protocol expects the spacer in `UR` and the remaining
tibia colour in `LR`. Thread 3.1 mock generation must store those components in
the separate fields or explicitly normalize them before they reach SQL.

### Right side, classic and placeholders

After tag branches:

1. one-colour `UR` plus one-colour `LR` becomes `UR || LR`;
2. null, `X`, `XX`, or `M` in `UR` plus a two-colour `LR` uses `LR`; and
3. null, `X`, or `M` in `LR` plus a two-colour `UR` uses `UR`.

Examples: `UR=X, LR=YG` becomes `YG`; `UR=XX, LR=OR` becomes `OR`;
`UR=M, LR=WR` becomes `WR`. Partial sides, unexpected punctuation, malformed
tags, and other strings outside the exact grammar remain ambiguous.

Ambiguous rows are not silently freed. They are reported by the audit view but
cannot be subtracted confidently and therefore remain an operational leakage
risk requiring review of aggregate ambiguity counts before assigning new marks.

## Available subtraction, exclusions, and labels

`AVAILABLE_COMBOS` builds a distinct used key from audit rows where
`is_normalizable = 1`, left-joins candidates on both `LL` and `LR`, and keeps
only candidates with no matching used key.

The fixed exclusions are:

- every candidate with `LL = 'YR'`;
- every candidate with `LR = 'OR'`; and
- every candidate with `LR = 'RO'`.

These are operational rules, not inferred biological rules. Do not remove them
without a separately approved policy decision.

After subtraction and exclusions, `ROW_NUMBER()` ranks within each original
candidate site:

1. `LL` beginning with `Y`;
2. marks containing neither `L` nor `R`;
3. marks containing `L`, including marks containing both `L` and `R`;
4. remaining marks, including marks containing `R`; then
5. database-collation order of `LL`, followed by `LR`.

The current remote-baseline CR/CX compatibility gate is:

1. original `CR` with `LL` in `BY`, `WY`, `YY`, `YO`, `OY`, or `GY` remains
   labelled `CR`, regardless of lime content or rank;
2. other original `CR` candidates containing `L` anywhere become `CX`; and
3. other original `CR` candidates with `combo_rank > 30` become `CX`.

All other site labels remain `AR`, `WN`, or `WS`. The gate runs after global used
subtraction. A protected `LL` group cannot restore a pair already used.

The view exposes only `site_code`, `mark`, `LL`, and `LR`. `LL` and `LR` are
candidate pair expressions cast upstream to `CHAR(10)`; `site_code` is cast to
`CHAR(2)` upstream; and `mark` comes from `format_mark()`. Verify deployed
metadata with `SHOW COLUMNS`, because MariaDB can report expression-derived
types slightly differently after the final `CASE`.

The view's final SQL order is original site code plus source `combo_rank`. View
row order is not a consumer API; the PDF supplies an explicit order.

## PDF Team marks contract

`main/R/pdf_todo.R::todo_pdf_prepare_team_marks()` queries:

```sql
SELECT mark
FROM AVAILABLE_COMBOS
WHERE site_code = 'CR'
```

The live query orders by:

1. `LL = 'GY'` last;
2. `LL` beginning with `Y` first;
3. no `L` or `R`;
4. `R` before `L` for the PDF, including marks containing both; and
5. `LL`, then `LR`.

The PDF therefore intentionally differs from the SQL rank for marks containing
both `L` and `R`: SQL's `L` branch comes first, while the live PDF's `R` branch
comes first. The GY rule is the later compatibility addition and keeps GY marks
after existing CR marks.

The helper trims marks, removes blank/NA values, keeps at most 30, and errors if
the query fails or returns no usable marks. It then distributes the available
marks as evenly as possible across three teams, giving earlier teams any
remainder. Examples:

- 30 marks: 10, 10, 10;
- 28 marks: 10, 9, 9;
- 2 marks: 1, 1, 0.

The result is a rectangular table with `Team` plus as many numeric mark columns
as the largest team requires. Shorter teams receive empty cells; no marks wrap
into a fourth team label. The QMD/Typst table uses the actual number of columns.

Preview callers may inject `available_combos`. In that path the helper preserves
the supplied order except that current code moves rows whose `LL` is `GY` to the
end. Preview harnesses must therefore supply the same non-GY order as the live
SQL query if exact parity is required.

The PDF adds the current note that non-Lime 1.5x bands are used for the
geolocator spacer and 2x bands on the tarsi. Thread 4 owns the visual layout and
the task-table page budget; Thread 6 owns the mark pool and ordering contract.

## App, dump, and test integration

- `main/global.R` exposes `AVAILABLE_COMBOS` and `CAPTURES_ARCHIVE` in the view
  browser. `USED_COMBOS_DETAIL` is diagnostic and not user-facing there.
- `dbtabs_show_view_sources` has a watch mapping for `CAPTURES_ARCHIVE` but no
  explicit mapping for `AVAILABLE_COMBOS`. The generic view browser therefore
  may not reactively refresh combo output when settings or capture sources change.
  The PDF queries the view directly.
- `main/R/system_utils.R` includes `CAPTURES_ARCHIVE` in the bounded RDS export,
  but not the dynamic combo views. A downloaded RDS is not a replacement for
  rebuilding the views.
- `main/templates/todo_pdf.qmd` receives the already allocated rectangular table
  from `pdf_todo.R`; it does not perform combo subtraction.
- Current focused tests cover even 1-31-mark distribution, blank-result failure,
  actual table-column width, GY ordering, reference-date fail-closed SQL shape,
  and the CR used-pair join/gate structure.
- Database-execution coverage for every normalization branch, fixed exclusion,
  reference-date transition, and ambiguity case remains a Thread 2/Thread 9
  test gap.

## Reusable-combo policy

The workbook `Band combos that have become available again.xlsx`, `Sheet1`, is
informational only. Inspection is limited to site, `LL`, `LR`, and explanatory
status fields. No SQL or R source reads it automatically.

The automatic policy is conservative “ever used” subtraction:

- dead-bird (`D`) pairs remain blocked;
- changed-event (`C`) old `_in` pairs remain blocked;
- replacement/rebanding does not release the old pair; and
- external workbook entries do not override SQL subtraction.

Any future recycling mechanism needs a separate governed override source, an
approval/audit trail, a global-versus-site scope decision, a waiting period, and
rules for revocation when later evidence conflicts. Do not filter `D` or `C`
rows as an indirect reuse implementation.

## Failure modes and unresolved questions

Known risks and policy questions:

1. A non-normalizable used record is visible but does not block a candidate. A
   review threshold or quarantine policy has not been approved.
2. `XX` is accepted as a right-side blank marker but not a left-side blank marker.
   Changing that would be a policy change and needs mock-data/test review.
3. A literal dotted tag string in one field is not accepted by SQL; mock-data
   generation must use the separate stored fields.
4. The rationale and permanence of `YR`, `OR`, and `RO` exclusions are not
   encoded in source comments.
5. The lifespan and removal condition of `CX` remain temporary compatibility
   decisions.
6. The view ranks all candidates but the PDF alone applies the hard 30-mark cap.
   Whether the cap belongs in SQL remains unresolved.
7. `AVAILABLE_COMBOS` has no explicit app source-watch mapping.
8. The historic `BADOatNZ.SEX` dependency is not fully represented by the
   current watcher.
9. An exact-one-row invariant for `settings.reference_date` is operationally
   expected but not enforced by this view.
10. The live database may still contain an older view definition even after a
    source merge. Source and deployment must be checked separately.

## Safe read-only verification

Run only against an approved local/mock database unless a separate narrow live
inspection is authorized. These queries return aggregate or invented-example
results and do not print rows, rings, or coordinates.

Formatter smoke test:

```sql
SELECT
  FIELD_2026_BADOatNZ.format_mark('B', 'G', 'R', 'O') AS classic_example,
  FIELD_2026_BADOatNZ.format_mark('M', 'YY', 'X', 'GB') AS canonical_example;
```

Reference-date health:

```sql
SELECT COUNT(*) AS non_null_reference_dates,
       MIN(value) AS minimum_reference_date,
       MAX(value) AS maximum_reference_date
FROM FIELD_2026_BADOatNZ.settings
WHERE variable = 'reference_date' AND value IS NOT NULL;
```

Audit aggregates:

```sql
SELECT source_table, source_stage, is_normalizable, COUNT(*) AS n_rows
FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL
GROUP BY source_table, source_stage, is_normalizable
ORDER BY source_table, source_stage, is_normalizable;
```

Future-date leakage:

```sql
SELECT COUNT(*) AS used_rows_after_reference_date
FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL u
JOIN FIELD_2026_BADOatNZ.settings s
  ON s.variable = 'reference_date'
WHERE u.date_ IS NOT NULL AND u.date_ > s.value;
```

Unknown-date aggregate:

```sql
SELECT source_table, source_stage, COUNT(*) AS n_unknown_date_rows
FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL
WHERE date_ IS NULL
GROUP BY source_table, source_stage;
```

Tag-plus-two-colour-LR check:

```sql
SELECT COUNT(*) AS tag_two_colour_failures
FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL
WHERE LL REGEXP '^[BGROWLY]{2}$'
  AND UR_raw REGEXP '^T[A-Z0-9]*[BGROWLY]$'
  AND LR_raw REGEXP '^[BGROWLY]{2}$'
  AND (LR IS NULL OR LR <> LR_raw OR is_normalizable <> 1);
```

Global used-pair leakage:

```sql
SELECT COUNT(*) AS leaked_used_pairs
FROM FIELD_2026_BADOatNZ.AVAILABLE_COMBOS a
JOIN (
  SELECT DISTINCT LL, LR
  FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL
  WHERE is_normalizable = 1
) u ON a.LL = u.LL AND a.LR = u.LR;
```

Availability aggregate:

```sql
SELECT site_code, COUNT(*) AS n_available
FROM FIELD_2026_BADOatNZ.AVAILABLE_COMBOS
GROUP BY site_code
ORDER BY site_code;
```

Metadata and deployment checks:

```sql
SHOW COLUMNS FROM FIELD_2026_BADOatNZ.AVAILABLE_COMBOS;
SHOW COLUMNS FROM FIELD_2026_BADOatNZ.USED_COMBOS_DETAIL;
```

For a controlled deployment, compare `SHOW CREATE VIEW` for all three combo
objects with the selected source revision, verify the historic dependencies,
check the non-null reference date, then run the matching PDF/test workflow.

## Migration, rollback, and recovery

Install the matched `functions.SQL` and `views.SQL` source in dependency order;
do not paste a dirty WIP file into Adminer. Confirm `format_mark()` before the
dependent views and confirm `BADOatNZ.CAPTURES` plus `BADOatNZ.SEX` exist before
`CAPTURES_ARCHIVE`.

Rollback is source-based: restore the previously approved `functions.SQL` and
`views.SQL` definitions, recreate dependent views in dependency order, and
confirm `SHOW CREATE VIEW`, aggregate counts, reference-date behavior, and the
PDF. Do not delete live data or use `_reset.SQL` as an in-place rollback; that
file is destructive and local-only.

If the view returns no rows because `reference_date` is missing, stop and repair
the settings configuration rather than manually inserting marks. If ambiguity
counts rise or a normalized used pair appears in availability, stop assignment,
preserve the audit counts, and hand the issue to Thread 2/Thread 9 for a local
reproduction.

## Chronology and superseded decisions

- **2026-09-22, exact:** the active role changed from the historical QA/
  reproducibility placeholder to combo-list maintenance. The placeholder was
  preserved; the protocol and prompt log became the authorized artifacts.
- **2026-09-22 onward, reconstructed from source/history:** the combo workflow
  was specified around global conservative subtraction, archive/current final/
  `_in` sources, reference-date and unknown-date handling, tag/spacer
  normalization, ambiguity reporting, fixed exclusions, and PDF allocation.
- **2026-10-06, commit `70c5645`:** hardened used-pair subtraction, ranking,
  reference-date fail-closed behavior, and PDF team allocation tests.
- **2026-10-13, commits `9ca79d3` and `119465f`:** enabled the eligible OY
  compatibility group in `CR` and fixed sub-30 PDF table distribution/layout.
- **2026-10-22, commits `3bf72b3`, `29a1bba`, and merge `8a180a8`:** added
  `GY` as a CR left-leg family and placed GY marks after existing marks in the
  PDF, while preserving global subtraction.
- **2026-10-23, commit `9288147`:** improved general PDF table cell alignment;
  this is a PDF presentation change, not a combo identity change.
- Earlier directions that treated only final fields as used, released `D` pairs,
  trusted the workbook as an automatic override, or prepended a tag spacer to a
  two-colour `LR` are superseded by the current conservative policy.

## Paste-ready bootstrap prompt

```text
You are Thread 6, the combo-list specialist for NZ_FIELDWORKER. Read AGENTS.md,
THREAD1_REPOSITORY_MAP.md, THREAD2_SCHEMA_REVIEW.md,
THREAD3_VALIDATION_ARCHITECTURE.md, THREAD4_TODO_MAP_LIST_DEBUG_PLAN.md,
THREAD6_COMBO_LIST_PROTOCOL.md, and THREAD6_PROMPT_LOG.md first. Treat the
selected clean origin/main revision as source truth and keep any dirty checkout
separate. Inspect format_mark(), CAPTURES_ARCHIVE, USED_COMBOS_DETAIL,
AVAILABLE_COMBOS, settings.reference_date, and
todo_pdf_prepare_team_marks(). Preserve the seven-colour alphabet, CR/AR/WN/WS
candidate rules, GY CR family, YR/OR/RO exclusions, global subtraction, archive
plus current final plus current _in evidence, date <= reference_date plus NULL
dates, classic/tag normalization, is_normalizable audit behavior, CR/CX gate,
PDF GY-last ordering, 30-mark cap, even three-team allocation, and fail-loud
empty/error behavior. Do not automatically recycle D/C/workbook combinations.
Use invented examples and aggregate checks only. Do not inspect credentials,
print raw records, connect to live databases, or edit source unless explicitly
authorized. State whether behavior is source, local replay, or deployed.
```
