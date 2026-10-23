# Thread 6 Prompt Log

Status: tracked sanitized history. Raw transcripts and attachments remain
local/ignored.

Current thread role:

- available-colour-combination and Team-marks specialist

Historical initialization role found in older documentation:

- QA / reproducibility reviewer (superseded)

Reconstruction status:

- none found

Primary sources checked:

- ignored proposal-note filenames under `notes/codex_proposals/`
- cross-thread references visible from Thread 1 and current `AGENTS.md`

## Current Recovery Result

- No dedicated Thread 6 prompt transcript or ignored proposal memo was found in the local repo during initialization of `notes/codex_logs/`.
- Thread 6 is clearly defined in `AGENTS.md`, but I did not find a corresponding thread-specific prompt artifact comparable to Threads 1 through 5.

## Most Likely Explanation

- Thread 6 may not yet have been run as a distinct working thread, or
- its outputs may exist outside the current local ignored notes area, or
- its work may have been folded into Thread 1 and general Git/AGENTS governance tasks

## Placeholder For Future Entries

When a real Thread 6 prompt or memo appears, add entries here using:

- `Exact` for visible transcript history
- `Reconstructed` for repo-visible local-note recovery

## 2026-09-22 - Exact - Transition to combo-list role

Visible task title:

- `THREAD 6 - Combo-list protocol refresh`

Role transition requested:

- Preserve the historical QA/reproducibility placeholder above.
- Treat the active Thread 6 task as the combo-list agent despite the stale generic
  role in `AGENTS.md`.
- Do not edit `AGENTS.md`; document the conflict and suggest replacement wording.

Exact task scope:

- Inspect the complete workflow from `format_mark()` and `CAPTURES_ARCHIVE` through
  `USED_COMBOS_DETAIL`, `AVAILABLE_COMBOS`, and PDF team allocation.
- Verify candidate colours and site rules, reference-date behavior, release and `_in`
  sources, classic and tag/spacer normalization, ambiguity reporting, global used-pair
  subtraction, fixed exclusions, ranking, the temporary CR/CX gate, and the PDF's
  three teams of ten.
- Review dead birds, replaced `_in` combinations, and the approved recyclable-combo
  workbook without weakening conservative availability logic.
- Compare tracked source with the latest local SQL dump, tests, and PDF-preview
  scripts.
- Create `notes/codex_proposals/THREAD6_COMBO_LIST_PROTOCOL.md` and append this dated
  `Exact` entry.

Authorized writes:

- `notes/codex_proposals/THREAD6_COMBO_LIST_PROTOCOL.md`
- `notes/codex_logs/THREAD6_PROMPT_LOG.md`

Result:

- Created the current-state combo-list protocol memo.
- Recorded source/dump and live/preview ordering differences, unresolved policy
  decisions, safe aggregate verification queries, rollback guidance, cross-thread
  dependencies, and proposed Thread 6 wording for `AGENTS.md` without applying it.
- No SQL, R, spreadsheet, `AGENTS.md`, or database object was changed.

## 2026-10-23 - Exact - Documentation recovery pass

Request: rebuild the Thread 6 current-state protocol so the combo-list role can
be recreated safely after a long-running conversation is lost. The request was
documentation-only. It authorized updates only to the tracked Thread 6 protocol
and this ignored sanitized log. It prohibited SQL, R, validator, test, database,
runtime, branch, deployment, and live-database changes.

Inspected:

- `AGENTS.md`, Thread 1, Thread 2, Thread 3.1, Thread 4, and Thread 9 handoffs;
- the prior Thread 6 protocol and this prompt log;
- `DATABASE/functions.SQL`, `DATABASE/views.SQL`, `DATABASE/main_tables.SQL`,
  `DATABASE/support_tables.SQL`, and local dated SQL-dump inventory;
- `main/global.R`, `main/R/pdf_todo.R`,
  `main/templates/todo_pdf.qmd`, `main/R/system_utils.R`, and focused tests;
- remote history for combo and PDF changes, including the GY, OY/CR, sub-30
  allocation, and table-alignment commits; and
- the relevant Thread 9 local-replay boundary without connecting to a database.

Current-state findings:

- `origin/main` at `9beb203` is the selected remote baseline. It contains the
  current `GY` CR candidate family and PDF GY-last ordering.
- The active checkout is protected dirty WIP at `d3c7bd4`. Its dirty SQL combo
  section is older and lacks GY; it is not a deployment candidate. Existing
  dirty files were preserved exactly.
- The current combo evidence chain is historic `CAPTURES_ARCHIVE`, current
  `CAPTURES` final fields, and current `CAPTURES` `_in` fields. The current SQL
  does not union RESIGHTINGS into `USED_COMBOS_DETAIL`.
- There is no current `CAPTURES_active` object in the inspected tracked SQL or
  app wiring.
- The current policy remains global conservative subtraction, including rows
  with any capture status, unknown dates, changed `_in` pairs, and dead-bird
  pairs. The recyclable workbook remains informational.
- A tag plus a two-colour `LR` uses `LR` unchanged; a tag plus one-colour `LR`
  uses the final spacer colour followed by `LR`. A literal dotted tag string in
  one field is outside the current SQL grammar and remains a mock-data risk.
- `AVAILABLE_COMBOS` exposes only `site_code`, `mark`, `LL`, and `LR`; the PDF
  applies the 30-mark cap and distributes the selected marks evenly across
  three teams, with the remainder assigned to earlier teams.

Documentation result:

- Replaced `notes/codex_proposals/THREAD6_COMBO_LIST_PROTOCOL.md` with a
  restart-grade, sanitized specification covering authority/state labels,
  ownership, source chain, formatter, candidate rules, normalization,
  reference-date behavior, used evidence, subtraction, exclusions, ranking,
  CR/CX/GY policy, PDF allocation, workbook policy, tests, rollback, safe
  aggregate queries, chronology, unresolved risks, and a bootstrap prompt.
- Preserved the original QA/reproducibility placeholder and the 2026-09-22
  exact transition entry above. This entry is exact for the current delegated
  request; historical implementation details are labelled reconstructed from
  source and Git history.
- No raw capture rows, bird identities, coordinates, credentials, or workbook
  contents were added.
- No SQL, R, validator, test, spreadsheet, database, branch, deployment, or
  runtime behavior was changed.

Remaining uncertainty: the remote baseline and local source describe intended
behavior, not what is currently installed in the live database or running app.
Thread 9 must use a clean selected revision for any local replay, and Thread 2
must verify the historic archive dependencies and deployed `SHOW CREATE VIEW`
definitions before a production-facing conclusion.
