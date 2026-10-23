# Thread 2 Prompt Log

Status: tracked sanitized history. Raw transcripts and attachments remain
local/ignored.

Last refreshed: 2026-10-23

Thread role:

- Database architect

Reconstruction status:

- mixed coverage
- many mid- and late-phase prompts are exact from the visible Codex conversation
- the earliest seed prompt is still only partially recoverable because the first visible message is truncated
- older phases are supplemented by ignored local notes plus current repository inspection

Primary sources:

- current visible Codex conversation history in this thread
- `notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md`
- local `AGENTS.md`
- local `git log`
- current `DATABASE/*.SQL`
- prior content of this prompt log

Current reconstruction boundary:

- The current checkout is `codex/split-todo-calculator-2026-10-19` at
  `d3c7bd4`, with protected dirty SQL/app/test WIP.
- `origin/main` was inspected at `9beb203` as the remote baseline.
- The current `DATABASE/` source, relevant app consumers, Thread 1/3/4/5/6
  handoffs, and static tests were used to distinguish committed baseline,
  protected WIP, local alignment artifacts, and unverified live deployment.
- No database, credential file, raw field record, GPS coordinate, or local SQL
  dump contents were used for prompt reconstruction.

## Exact Prompt History

1. `Partial`
   Prompt:
   - initial request to "actively ... SQL script with you" about the schema workflow
   Main output:
   - start of the collaborative DDL and data-entry-schema sequence

2. `Exact`
   Prompts:
   - local-preview request for the revised `CAPTURES` chunk
   - request to use DBeaver
   - screenshot-driven DBeaver syntax/debug follow-ups
   Main output:
   - DBeaver plus local Shiny preview workflow for `CAPTURES`

3. `Exact`
   Prompts:
   - resume-from-step requests after local SQL fixes
   - column-order questions
   - local-vs-remote `.cnf` and `nz_fieldworker` connection questions
   - early R startup errors and missing helper-function troubleshooting
   Main output:
   - app-startup and local-connection troubleshooting tied to the new schema

4. `Exact`
   Prompts:
   - misaligned `CAPTURES` column-comment hover bug
   - request to translate SQL comment semantics into dropdowns
   Main output:
   - diagnosis of hover-comment misalignment
   - first pass at SQL-comment-to-dropdown alignment for `CAPTURES`

5. `Exact`
   Prompts:
   - `zerofill` and datatype questions around `gps_id`, `gps_point`, and `seg_id`
   - request that users be able to enter `1` or `01`
   Main output:
   - datatype and relational-consistency guidance for GPS-linked identifiers

6. `Exact`
   Prompts:
   - observer dropdown not working in `CAPTURES`
   - follow-up checks showing one-item source-list behavior
   Main output:
   - diagnosis of observer-dropdown behavior against `OBSERVERS`

7. `Exact`
   Prompts:
   - datatype review for `CAPTURES`
   - `int unsigned` vs `smallint unsigned`
   - Shiny render-width questions for `date`
   Main output:
   - CAPTURES datatype review
   - integer-size explanation
   - table-render width guidance

8. `Exact`
   Prompts:
   - move to the `EGGS` block
   - provide full `EGGS` SQL
   - recompose `EGGS` SQL in CAPTURES style
   - propose `DataEntry/EGGS/global.R` updates
   - permission to apply diffs to `DataEntry/EGGS/global.R`
   Main output:
   - long-format `EGGS` DDL redesign
   - EGGS app-alignment work

9. `Exact`
   Prompts:
   - add ignored local path to Git ignore rules
   - move to the `NESTS` block
   - `ENUM` meaning and tradeoffs
   - add `ENUM`s to multiple `CAPTURES` fields
   - check whether `CAPTURES/global.R` still matches the new DDL
   - ask what `<kbd>` does
   Main output:
   - NESTS and CAPTURES controlled-value cleanup
   - discussion of `ENUM` tradeoffs

10. `Exact`
    Prompts:
    - standardize dropdown comments with bolded option codes
    - extend the same style to `NESTS`
    - re-style `hatch_state`
    - clean up `RESIGHTINGS`
    - remove `=` from UL/LL/UR/LR descriptions and add emphasis markup
    - add appropriate `ENUM`s to `EGGS`, `NESTS`, and `RESIGHTINGS`
    Main output:
    - broad comment-style and controlled-value standardization across source tables

11. `Exact`
    Prompts:
    - clean up `RESIGHTINGS_PUBLIC`
    - add a 3-level `country` enum/comment
    - align non-CAPTURES globals with CAPTURES style
    - follow-up error from `DataEntry/OBSERVERS`
    - comment-length warning
    - replace `<strong>` with `<b>`
    - revert old site names
    Main output:
    - `RESIGHTINGS_PUBLIC` cleanup
    - comment-length/style simplification
    - broader `global.R` harmonization

12. `Exact`
    Prompts:
    - concern about "Unsigned INTEGER imported as numeric" warnings
    - request for a very small `DBq()` replacement that suppresses only that warning
    - add `bird_inc`
    - ask what to add to the NESTS global script for that new field
    - follow-up `global.R` sourcing error
    Main output:
    - warning-suppression work
    - `bird_inc` schema/app alignment

13. `Exact`
    Prompts:
    - detailed progress summary after upstream updates
    - attached request to refresh Thread 2 schema review after a main-branch sync
    Main output:
    - handoff/progress summary
    - post-sync Thread 2 schema-review refresh

14. `Exact`
    Prompts:
    - adjust column widths in rendered Shiny tables
    - ask for a simpler auto-width approach
    - explore EGGS long-to-wide and back-to-long format alternatives
    - DDL error when trying to recreate `RESIGHTINGS`
    Main output:
    - schema/UI render advice
    - EGGS structure alternatives
    - clarification on existing-table DDL behavior

15. `Exact`
    Prompts:
    - review local `AGENTS.md` for Thread 2 scope/governance changes
    - user clarifications about `DATABASE/` as a whole, `main_tables.SQL`, `views.SQL`, stable `predict_hatching`, and EGGS long format
    - turn the clarifications into proposed replacement wording
    - then apply them to `AGENTS.md`
    Main output:
    - updated Thread 2 governance wording around schema source of truth and scope

16. `Exact`
    Prompts:
    - remove then restore `BADOatNZ.SEX` involvement in `CAPTURES_ARCHIVE`
    - ask whether local `views.SQL` matches `main`
    Main output:
    - `CAPTURES_ARCHIVE` rollback/reconciliation work
    - branch-comparison guidance for `views.SQL`

17. `Exact`
    Prompts:
    - add `eggs_handled` to `CAPTURES`
    - make it a dropdown in `DataEntry/CAPTURES/global.R`
    - remove `observer_upload` from `EGGS`
    - document that `observer_upload` is CAPTURES-only
    - draft a handoff prompt for Thread 1
    Main output:
    - current-source-of-truth updates in `DATABASE/main_tables.SQL`
    - CAPTURES app alignment
    - narrowed `observer_upload` interpretation
    - cross-thread handoff prompt

18. `Exact`
    Prompt:
    - request to update `notes/codex_logs/THREAD2_PROMPT_LOG.md` with recoverable prompt history, milestones, and gaps
    Main output:
    - the first materially complete ignored local prompt-history log for Thread 2

19. `Exact`
    Prompt:
    - "I want to install the latest version of DataEntry from github"
    Main output:
    - confirmed local `DataEntry` install was already at GitHub SHA `5eeabc7c...`
    - confirmed `prepare_for_dropdown()` exists in the installed package

20. `Exact`
    Prompt:
    - "does the current `NESTS_LATEST` view extract the parent marks from RESIGHTINGS and CAPTURES events?"
    Main output:
    - static diagnosis that `NESTS_LATEST` was then deriving parent marks from `CAPTURES` only
    - separate confirmation that later `TODO_LIST` parent logic already used both `CAPTURES` and `RESIGHTINGS`

21. `Exact`
    Prompt:
    - request to edit `views.SQL` so `NESTS_LATEST` derives `M_mark` and `F_mark` from both `CAPTURES` and `RESIGHTINGS`, while checking that the untrapped-parent to-do still follows the renesting/resighting protocol
    Main output:
    - local `views.SQL` change to derive `NESTS_LATEST` parent marks from both sources by `nest_id`
    - explicit confirmation that `TODO_LIST` `Untrapped parent` logic was already capture-plus-resighting aware

22. `Exact`
    Prompt:
    - current request to refresh all Thread 2 local markdown documentation against the latest local repository state
    Main output:
    - refreshed `THREAD2_SCHEMA_REVIEW.md`
    - refreshed `THREAD2_PROMPT_LOG.md`

23. `Exact`
    Prompt:
    - request to correct the Thread 2 memos because they still mentioned an unstaged `DATABASE/views.SQL` edit even though `git status --short` was clean on Wednesday, July 29, 2026
    Main output:
    - memo refresh correcting the git-state snapshot
    - rewording the `NO_NEST` `views.SQL` changes as committed branch state rather than an unstaged worktree edit

24. `Exact`
    Prompt:
    - "TASK: DEFINE AND ALIGN THE DATABASE ARCHITECTURE FOR NEGATIVE BROOD IDS"
    Main output:
    - canonical positive/negative/`NO_NEST` identifier contract
    - source-DDL comment alignment and targeted event indexes
    - reusable `BROODS_LATEST` architecture contract, location precedence,
      migration guidance, and Thread 3.1/Thread 4 handoff

25. `Exact`
    Prompt:
    - finalize the negative-brood database architecture documentation against the
      approved implementation on `codex/negative-nest-protocol`;
    - replace stale wording that described `BROODS_LATEST` as future, proposed,
      or unimplemented;
    - document the implemented view, TODO/PDF/map dependencies, deployment order,
      and the distinction between local implementation and live deployment.
    Main output:
    - updated the current Thread 2 schema memo to describe the implemented
      `BROODS_LATEST` contract and current compatibility risks;
    - recorded that the implementation is complete only in the current local
      working tree and has not been committed, pushed, merged, deployed, or
      verified against the live database;
    - SQL, R code, tests, and cross-thread notes were inspected read-only; no
      tracked source files were changed, and no database, credentials, or
      confidential records were accessed.

26. `Exact`
    Prompt:
    - add the already-implemented nullable `ring varchar(50)` field to the
      tracked `RESIGHTINGS` DDL immediately after `LR` and before `sex`;
    - audit DataEntry, views, explicit column lists, positional inserts, tests,
      and the negative-brood architecture;
    - update only the owned Thread 2 documentation in addition to the requested
      tracked DDL edit, and provide an unexecuted migration/reference snippet.
    Main output:
    - added `RESIGHTINGS.ring` to `DATABASE/main_tables.SQL` without changing
      `RESIGHTINGS_PUBLIC`, adding an index, or rewriting dependent views;
    - documented that the field identifies the chick in an H-class hiding-spot
      event and remains a free-text identity field;
    - recorded static compatibility, deployment, and rollback guidance without
      connecting to the database or inspecting records.

## Reconstructed Prompt History

1. `Reconstructed`
   Likely prompt:
   - inspect the schema-oriented parts of the repository and produce an initial Thread 2 schema review without connecting to the live database
   Recoverable scope:
   - inspect active SQL files
   - compare tables, views, and support objects with app needs
   - identify schema gaps, dependency edges, and integrity risks
   Main output:
   - early Thread 2 schema-review reasoning later captured in local notes

2. `Reconstructed`
   Likely prompt:
   - refresh the Thread 2 schema review after `cass_prep` was synced with newer `origin/main`
   Recoverable scope:
   - reassess the move to `DATABASE/` as source of truth
   - account for central `inspectors`
   - account for long-format `EGGS`
   - account for the growing view layer
   Main output:
   - newer schema-review memo replacing earlier `Admin/db_structure.SQL` assumptions

3. `Partial`
   Recoverable emphasis from proposal notes and later prompts:
   - `CAPTURES_ARCHIVE` compatibility logic matters to current behavior
   - GPS linkage is anchored on `gps_id + gps_point`
   - `ENUM` / `tinyint` / `zerofill` consistency became a recurring schema concern
   - validator-storage implications of the `inspectors` table shaped schema decisions
   Main output:
   - recurring cross-table design and risk notes reused in later schema reviews

## Inferred Task Families

- local DDL preview and browser-render workflow for fieldworker data-entry tables
- controlled-value design using SQL comments, dropdowns, and `ENUM`s
- schema/app alignment between `DATABASE/main_tables.SQL` and `DataEntry/*/global.R`
- datatype and relational-link decisions for GPS-linked identifiers
- historical compatibility view management, especially `CAPTURES_ARCHIVE`
- migration of schema source-of-truth assumptions from `Admin/db_structure.SQL` to `DATABASE/`
- AGENTS/database-governance updates for Thread 2
- package/runtime alignment for schema-driven DataEntry apps
- derived-view logic for nest parentage, hatching, and operational to-do workflows
- cross-thread handoff documentation when schema facts changed

## Milestones reached through prompt history

1. CAPTURES local-preview workflow clarified
   What was achieved:
   - a repeatable DBeaver plus local Shiny preview workflow for `CAPTURES`
   Output/artifact/file:
   - no single file artifact; this was an operating procedure
   Status:
   - complete

2. CAPTURES dropdown/comment logic substantially aligned with schema intent
   What was achieved:
   - SQL comment semantics were translated into app dropdown expectations
   Output/artifact/file:
   - repeated changes and proposals around `DataEntry/CAPTURES/global.R`
   Status:
   - partial

3. GPS-linkage datatype stance clarified
   What was achieved:
   - a consistent design position around `gps_id`, `gps_point`, and `seg_id`
   Output/artifact/file:
   - schema guidance reused across multiple table revisions
   Status:
   - partial

4. EGGS long-format design established as the preferred current model
   What was achieved:
   - long-format `EGGS` was repeatedly preferred over wide alternatives
   Output/artifact/file:
   - `DATABASE/main_tables.SQL`
   - Thread 2 schema/governance notes
   Status:
   - complete

5. Cross-table cleanup framework established for NESTS, RESIGHTINGS, and RESIGHTINGS_PUBLIC
   What was achieved:
   - comment style, dropdown semantics, and controlled values were normalized across the source tables
   Output/artifact/file:
   - repeated DDL proposals and tracked SQL edits over time
   Status:
   - partial

6. Central inspectors architecture became the schema-facing validation model
   What was achieved:
   - validator storage moved from tracked per-table files to DB-stored inspector code
   Output/artifact/file:
   - `DATABASE/support_tables.SQL`
   - `DataEntry/inspectors/`
   Status:
   - complete

7. Schema source-of-truth governance shifted to `DATABASE/`
   What was achieved:
   - old `Admin/db_structure.SQL` assumptions were superseded by the split `DATABASE/*.SQL` model
   Output/artifact/file:
   - `AGENTS.md`
   - `THREAD2_SCHEMA_REVIEW.md`
   Status:
   - complete

8. Current CAPTURES-only / field-addition facts were formalized
   What was achieved:
   - `observer_upload` was narrowed to CAPTURES-only
   - `eggs_handled` was established as a CAPTURES field
   Output/artifact/file:
   - `DATABASE/main_tables.SQL`
   - `AGENTS.md`
   - Thread 1 handoff prompt
   Status:
   - complete

9. Historical compatibility view handling became an explicit Thread 2 concern
   What was achieved:
   - `CAPTURES_ARCHIVE` dependencies and rollback logic became part of the schema-review scope
   Output/artifact/file:
   - `DATABASE/views.SQL`
   - Thread 2 schema-review notes
   Status:
   - partial

10. DataEntry runtime alignment was clarified
    What was achieved:
    - local package state was checked against the repo’s use of `prepare_for_dropdown()`
    Output/artifact/file:
    - confirmation that installed `DataEntry` already matched the expected GitHub head
    Status:
    - complete

11. NESTS_LATEST parent-mark logic was broadened to match the renesting/resighting protocol
    What was achieved:
    - `NESTS_LATEST` was updated locally to derive `M_mark` and `F_mark` from both `CAPTURES` and `RESIGHTINGS` by `nest_id`
    - `TODO_LIST` `Untrapped parent` logic was checked and confirmed already capture-plus-resighting aware
    Output/artifact/file:
    - `DATABASE/views.SQL`
    Status:
    - partial

12. Thread 2 local documentation was refreshed against the current repo state
    What was achieved:
    - stale pre-`DATABASE/` schema assumptions were removed from the active Thread 2 notes
    Output/artifact/file:
    - `notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md`
    - `notes/codex_logs/THREAD2_PROMPT_LOG.md`
    Status:
    - complete

13. Negative brood-ID contract established
    What was achieved:
    - distinguished positive nests, negative unknown-origin mobile broods, and
      `NO_NEST` as three non-interchangeable values in the existing `nest_id`
      field
    - aligned source-table instructions, established location precedence, and
      specified the boundary for a future reusable brood view
    Output/artifact/file:
    - `DATABASE/main_tables.SQL`
    - `notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md`
    Status:
    - complete as the agreed methodology and source-schema contract; the derived
      view and downstream implementation were completed later in the local tree

14. Thread 2 memos were corrected to reflect a clean July 29 worktree
    What was achieved:
    - stale wording about an unstaged `views.SQL` edit was removed
    - the `NO_NEST` changes were reclassified as committed branch state
    Output/artifact/file:
    - `notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md`
    - `notes/codex_logs/THREAD2_PROMPT_LOG.md`
    Status:
    - complete

15. Negative-brood implementation and documentation alignment completed locally
    What was achieved:
    - the local branch now contains the implemented `BROODS_LATEST` view,
      negative-brood `TODO_LIST` branches, and matching PDF/map consumption;
    - the Thread 2 memo now documents the actual architecture rather than a
      future recommendation
    Output/artifact/file:
    - `DATABASE/views.SQL` (read-only source inspection for this documentation task)
    - `main/R/pdf_todo.R` and `main/R/pdf_todo_map.R` (read-only source inspection)
    - `notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md`
    - `notes/codex_logs/THREAD2_PROMPT_LOG.md`
    Status:
    - implementation complete in the current local working tree; not committed,
      pushed, merged, deployed, or live-database verified

16. RESIGHTINGS ring-field schema alignment
    What was achieved:
    - the tracked RESIGHTINGS DDL now matches the already-altered live table's
      nullable `ring varchar(50)` field and exact position after `LR`;
    - dependent source inspection found no positional RESIGHTINGS inserts,
      fixed full-table column lists, or current view/index requirement for ring
    Output/artifact/file:
    - `DATABASE/main_tables.SQL`
    - `notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md`
    - `notes/codex_logs/THREAD2_PROMPT_LOG.md`
    Status:
    - tracked DDL/documentation alignment complete locally; live deployment was
      already performed by the user and was not independently verified here

17. Current Thread 2 architecture recovery on the split-TODO branch
    What was achieved:
    - the schema memo was reconciled with the current `DATABASE/` authority,
      current source-table contracts, `BROODS_LATEST`, the H-photo association
      helper, parent-status dependencies, snapshot publication, and app-facing
      consumers;
    - the clean `origin/main` install/refresh architecture was separated from
      the protected dirty split-calculator WIP in the current checkout;
    - stale claims about EGGS format, CAPTURES-only fields, RESIGHTINGS ring,
      NESTS_LATEST source watches, and future-only brood architecture were
      explicitly marked obsolete;
    Output/artifact/file:
    - `notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md`
    Status:
    - documentation update complete; source behavior, database state, and
      deployment status unchanged

## Gaps / unrecoverable history

- The exact wording of the first seed prompt is still not recoverable because the earliest visible message is truncated.
- At least one later Thread 2 task arrived through an attached pasted-text file; only its broad purpose is recoverable from local notes plus surrounding conversation.
- Several screenshot-driven debugging phases are represented as exact prompt clusters rather than a fully verbatim turn-by-turn transcript.
- The exact line-by-line content of some older applied DDL edits is no longer fully recoverable from prompt history alone because later merges and local edits changed the same tracked SQL files.

## Exact prompt entry: 2026-09-22 schema architecture protocol refresh

Confidence: `Exact`

Prompt summary:

- inspect the current tracked schema layer and downstream SQL consumers;
- refresh the Thread 2 handoff after major developments since July 29;
- compare the latest dated local SQL snapshot only as a read-only alignment
  reference;
- document archive, combo, mark normalization, latest-nest, hatch prediction,
  to-do, parent/capture/resighting, clutch-check, reference-date, DataEntry, and
  app-output dependencies;
- update only the ignored Thread 2 schema memo and prompt log.

Main output:

- consolidated current-state `THREAD2_SCHEMA_REVIEW.md`;
- explicit documentation of current `TODO_LIST` parent/resighting/clutch logic;
- static identification of app source-watch mismatches for `NESTS_LATEST`,
  `CAPTURES_ARCHIVE`, and `AVAILABLE_COMBOS`;
- no tracked SQL, source code, database, dump, credentials, field records, or GPS
  coordinates changed or recorded.

## Sources used for reconstruction

- current visible Codex conversation history in this thread
- prior content of this prompt log
- `notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md`
- local `AGENTS.md`
- current repository inspection of:
  - `DATABASE/main_tables.SQL`
  - `DATABASE/views.SQL`
  - `DATABASE/support_tables.SQL`
  - `DATABASE/functions.SQL`
  - `DATABASE/predict_hatching.SQL`
  - `DATABASE/_reset.SQL`
- local `git log`
- local `git diff`

## Exact prompt entry: unlinked H-photo brood association implementation

Confidence: `Exact`

Prompt summary:

- implement the previously proposed database/view-side support for an unlinked
  age-C, rclass-H RESIGHTINGS event;
- preserve the raw nullable `nest_id` while deriving a task-level positive nest
  or negative brood ID only from prior chick capture linkage plus exact-date,
  exact-GPS parent identity matches;
- leave ambiguous candidates unresolved, keep `RESIGHTINGS_PUBLIC` unchanged,
  and do not modify raw biological rows or the database.

Output:

- added the internal `RESIGHTINGS_H_BROOD_ASSOCIATIONS` view;
- integrated uniquely resolved H events into `BROODS_LATEST` chick-event and
  latest-valid-direct-location selection;
- updated `TODO_LIST` hiding-spot qualification to count raw linked and uniquely
  resolved H-photo events with ring, direct GPS, and both photo endpoints;
- refreshed the ignored Thread 2 schema memo to describe the implementation.

Status:

- tracked SQL implementation is local and uncommitted; no database connection,
  deployment, live-data verification, or raw-row backfill was performed.

## Exact prompt entry: 2026-10-23 current-state Thread 2 documentation recovery

Confidence: `Exact`

Prompt summary:

- read the local `AGENTS.md` and remain within the Thread 2 database-architect
  role;
- inspect the current Git state, source-of-truth SQL files, relevant app code,
  tests, Thread 1/3/4/5/6 documentation, and the latest local snapshot only as
  a read-only comparison;
- preserve all concurrent dirty work and update only the Thread 2 schema memo
  and sanitized prompt log;
- reconcile source-table structure, support objects, derived-view dependencies,
  negative-brood/H-photo logic, parent identity, `reference_date`, TODO split
  and snapshot publication, app consumers, deployment ordering, and rollback;
- distinguish committed remote baseline, current protected WIP, local replay
  evidence, and unverified live deployment.

Output:

- refreshed `notes/codex_proposals/THREAD2_SCHEMA_REVIEW.md` as a current
  restart-grade architecture reference;
- appended this sanitized prompt-history entry and updated milestone/gap
  metadata;
- no SQL, R code, validator, test, database, dump, credential, or AGENTS file
  was modified.

Status:

- documentation update complete; the current checkout still contains unrelated
  protected dirty WIP and no live deployment claim is made.
