# Thread 1 Prompt Log

Status: tracked sanitized history. Raw transcripts and attachments remain
local/ignored.

Thread role:

- Repository cartographer

Reconstruction status:

- strongest coverage of all threads
- many entries below are exact prompts from the visible Codex conversation
- a smaller number are grouped summaries of repeated exact prompts that dealt with the same merge, AGENTS, or documentation episode
- some prompts arrived through pasted-text attachments or screenshots and are only partially recoverable

Primary sources:

- current visible Codex conversation history in this thread
- [THREAD1_REPOSITORY_MAP.md](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/THREAD1_REPOSITORY_MAP.md)
- current local `AGENTS.md`
- repo-visible consequences of earlier Thread 1 guidance

## Repository Cartography Prompts

1. `Exact`
   Prompt: "THREAD 1 — Repository cartographer ... understand the existing repository structure and app logic without changing anything ... produce a repository map."
   Main output: initial repository map for `main/`, `DataEntry/`, `gpxui/`, schema, validators, GPS, and to-do logic.

2. `Exact`
   Prompt: "THREAD 1 — Save repository map proposal ... save that same repository map to notes/codex_proposals/THREAD1_REPOSITORY_MAP.md."
   Main output: first ignored local Thread 1 map file.

3. `Exact`
   Prompt: "My collaborator has updated the main branch ... summarise in detail what you have done/produced since you were spawned."
   Main output: progress summary of Thread 1 outputs to date.

4. `Exact`
   Prompt: "THREAD 1 — Update repository map after upstream main sync ... major structural changes, including a central DataEntry/inspectors app, deleted table-specific inspector.R files, new main mapping files, and a new main/R/DATA_todos.R."
   Main output: refreshed post-sync structural cartography.

5. `Exact`
   Prompt: "where in the repo do I code the to-do algorithm?"
   Main output: location guidance for repo-visible to-do logic.

6. `Exact`
   Prompt: "refresh your repository-map documentation so that it reflects the current local repository state."
   Main output: updated map on `cass_prep` after later merges.

7. `Exact`
   Prompt: "Please update your md documentation on the latest repository structure so that other agents in this project have the most up to date map."
   Main output: another ignored repository-map refresh.

8. `Exact`
   Prompt: "If I wanted to add another dynamic panel to the Overview panel ... what files in the repo would I need to modify?"
   Main output: file-level Overview dashboard code path.

9. `Exact`
   Prompt: "Please read the local AGENTS.md first and stay within the current Thread 1 role ... update your repository/schema map based on recent DDL changes to the core source tables."
   Main output: schema-focused update covering `observer_upload`, `eggs_handled`, and long-format `EGGS`.

10. `Exact`
    Prompt: "Read the local AGENTS.md first and stay strictly within your current Thread 1 role ... Update all current Thread 1 markdown documentation so it matches the latest local repository state."
    Main output: current refresh of the Thread 1 repository map and prompt log.

## AGENTS / Governance Prompts

11. `Exact`
    Prompt: "Please review the current local AGENTS.md and report whether your thread’s role, scope, assumptions, or recommended workflow has changed based on recent project progress."
    Main output: Thread 1 recommendations for revising `AGENTS.md`.

12. `Exact`
    Prompt: follow-up answers to open AGENTS questions, including:
    `DATABASE/` should be canonical source of truth,
    remove QField goals,
    clarify `spatial_objects`,
    allow safe local mock-data artifacts,
    likely allow inspection of `tests/testthat/*.R`,
    describe app capabilities more loosely.
    Main output: refined AGENTS recommendations after Luke’s decisions.

13. `Exact`
    Prompt: "please add your changes to AGENTS.md directly"
    Main output: tracked edits to `AGENTS.md` aligning it with current project structure and thread roles.

14. `Exact`
    Prompt: "Importantly, I want the AGENTS.md to be pushed to cass_prep, but I want the main to ignore it when pulling from cass_prep. Is this set up possible?"
    Main output: explanation that Git cannot selectively ignore a tracked file during merges, plus clean PR-branch workflow guidance.

15. `Exact`
    Prompt: "give me the exact Terminal steps for the safest workflow to track it on cass_prep without accidentally sending it upstream"
    Main output: branch-discipline workflow for tracking `AGENTS.md` only on `cass_prep`.

16. `Exact`
    Prompt: "please integrate the 'always use this' checklist for your future cass_prep -> main workflow into the AGENTS.md, making it clear that the cass_prep branch is Luke's branch integrated with Codex ..."
    Main output: tracked AGENTS update documenting `cass_prep` as the Codex-integrated branch and the clean cherry-pick PR workflow.

## Git / Merge / Branch Support Prompts

17. `Exact`
    Prompt: "My colleague has made 17 commits to the main branch of this project. Please give me the steps in Terminal to safely merge these updates to my cass_prep branch."
    Main output: safe `fetch` + `merge` workflow guidance.

18. `Exact`
    Prompt group: repeated merge-help requests after new `main` updates and editor confusion, including:
    how to quit pagers and editors,
    what to do after `git merge --no-ff origin/main`,
    how to interpret branch divergence and merge status.
    Main output: step-by-step merge and conflict-resolution guidance.

19. `Exact`
    Prompt group: troubleshooting local git problems, including:
    `fatal: not a git repository`,
    stash/patch/commit workflow,
    preserving local changes in `DATABASE/views.SQL`, `main/R/pdf_todo.R`, and `main/templates/todo_pdf.qmd`.
    Main output: backup, patch, commit, and merge-resolution instructions.

20. `Exact`
    Prompt group: later main-sync and PR-preparation questions, including:
    "I need to pull some updates from the main to the cass_prep branch then do a pull request ..."
    "did this work correctly?"
    "all fine here?"
    Main output: confirmation of merge state and safe next-step guidance.

21. `Exact`
    Prompt: "I want to commit all my changes on cass_prep, and push to the remote" followed by "Give me the terminal code for me to run myself"
    Main output: exact terminal commands for `git add`, `git commit`, and `git push`.

## Logging / Coordination Prompts

22. `Exact`
    Prompt: "In my original AGENTS.md I believe I had contemplated the notion to have a log that documented all the prompts that I've had across all the agents. Does this exist? If not, is it possible to create that now?"
    Main output: confirmation that the idea existed but the local-only logging structure did not yet exist.

23. `Exact`
    Prompt: "create the initial local-only logging structure, and do what you can to document all the prompts up until now (structure it according to THREAD/agent)"
    Main output: creation of `notes/codex_logs/` plus reconstructed prompt logs.

24. `Exact`
    Prompt: "Please provide me a detailed prompt that I can submit to each agent in the project that asks them to add all my prompts to the respective LOG in the codex_logs folder. Please also ask them to add a summary to the log of the milestones reached through the prompt history."
    Main output: reusable cross-thread logging prompt.

25. `Exact`
    Prompt: "I would like all THREAD-specific md documents to be updated ... Please draft a prompt that I can paste into each of the 5 threads ..."
    Main output: thread-specific prompts for refreshing proposal docs and logs.

## UI / Repository Guidance Prompts

26. `Exact`
    Prompt: "Which thread would be the best to chat to about adding another note to the app interface ..."
    Main output: Thread-routing advice that this help-note patch belongs with Thread 1 / app cartography guidance.

27. `Exact`
    Prompt group:
    "Okay, great, you are Thread 1, so please show me how to do this patch"
    "I have the enter_data.html file open and can edit it, please give me the code to copy and paste"
    "I want the text to stand out"
    Main output: safe HTML snippet for `main/www/help/enter_data.html` with a highlighted GPS-first note.

28. `Exact`
    Prompt: "I've saved the file, please check that I've edited it appropriately so that it can be rendered safely"
    Main output: render-safety confirmation for the edited help HTML.

29. `Exact`
    Prompt: "I would like to slightly modify the mock data, which thread should I chat with about that?"
    Main output: routing advice toward Thread 3 by default, with scope caveats.

30. `Exact`
    Prompt: "what are these files in the repository? They are hanging up my owncloud sync and causing issues"
    Main output: explanation of `.Rproj.user/...` artifacts and their local-only nature.

## Other Exact Thread 1 Prompts Worth Remembering

31. `Exact`
    Prompt group: several short status-check messages during merges, for example:
    "please confirm that I'm on the right track"
    "what now?"
    "is cass_prep somehow up to date now?"
    Main output: live branch-state interpretation during merge workflow.

32. `Partial`
    Prompt: a few requests arrived through attached pasted-text files whose full wording is not recoverable from repo state alone.
    Recoverable theme: merge troubleshooting, ignore checks, and local branch hygiene.

## Milestones reached through prompt history

- Initial Thread 1 repository cartography was completed and then saved locally to `notes/codex_proposals/THREAD1_REPOSITORY_MAP.md`.
- Thread 1 repeatedly refreshed the repository map after multiple `origin/main` syncs and local `cass_prep` changes.
- The current repo-wide governance file `AGENTS.md` was revised from Thread 1 analysis and now documents the `cass_prep` branch as Luke’s Codex-integrated branch.
- The `cass_prep -> main` clean-PR workflow was documented so `AGENTS.md` can remain on `cass_prep` without being pushed upstream accidentally.
- Local prompt logging was initialized under `notes/codex_logs/`.
- Thread 1 documented the current schema facts that matter across threads:
  `DATABASE/` is canonical
  `observer_upload` is CAPTURES-only
  `eggs_handled` is current in CAPTURES
  `EGGS` remains long format
- Thread 1 guided a safe local help-panel patch that added a highlighted GPS-first note to `main/www/help/enter_data.html`.
- Thread 1 drafted the cross-thread prompt packs used to refresh logs and proposal documents in other threads.
- The current `RESIGHTINGS.ring` contract is now documented across the project:
  nullable `varchar(50)` metal-ring identity, mandatory nonblank value for
  age-C H-class hiding-photo events, per-chick GPS/photo rows, separate tent
  versus hiding-photo evidence, and `RESIGHTINGS_PUBLIC` unchanged.

## Gaps / unrecoverable history

- Some user prompts came through pasted-text attachments whose full exact wording is not preserved in repo state.
- Some merge/editor support happened through short screenshot-driven exchanges, so only the central prompt theme is recoverable.
- Not every assistant response is re-summarized here; this log prioritizes user prompts and resulting milestones.
- Some repository-state changes were performed manually by Luke in Terminal or RStudio after guidance from Thread 1, so the log can describe the guidance and the resulting visible repo state, but not always the exact full command history.

## Notes for future maintenance

- Thread 1 now spans classic repository cartography, branch/governance support, and repo-surface routing advice.
- The most important current Thread 1 local outputs are:
  [THREAD1_REPOSITORY_MAP.md](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/THREAD1_REPOSITORY_MAP.md)
  [THREAD1_PROMPT_LOG.md](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_logs/THREAD1_PROMPT_LOG.md)
- When new Thread 1 work happens, update both the repo map and this prompt log together if the work changes branch-state interpretation, repo structure understanding, or Thread 1 governance assumptions.

## Exact Prompt Entry: 2026-10-23 Repository-wide recovery/documentation pass

The user authorized a final sequential documentation pass so every specialist
role can be recreated safely after a long-running conversation becomes
overloaded. The requested scope was documentation only: inspect current Git,
source architecture, all refreshed specialist handoffs, prompt logs, and the
protected dirty validator/source state; update `AGENTS.md`, this map, the
Thread 3 recovery appendix, the sanitized index/logs, and optionally a
sanitized Thread 8 log. Do not start or message Thread 8, alter SQL/R/tests/
validators/databases/runtime, or stage/commit/push/merge/rebase.

Current recovery result:

- `origin/main` was recorded from the local ref as `9beb203`;
- the protected checkout is `codex/split-todo-calculator-2026-10-19` at
  `d3c7bd4`, with dirty SQL, PDF, focused tests, four inspector exports, and
  refreshed Thread 2/4/5/6 documentation;
- the clean remote architecture is bounded SQL installation plus a separate
  staged refresh/publication workflow;
- the current Overview has eight panels;
- Thread 7 is the seasonal GEO rollout specialist, Thread 8 is the future
  field-manual specialist, and Thread 9 owns disposable local replay;
- the current local validator protocol is v1.3.4; the earlier Thread 3.1
  delivery incident was later resolved by manual delivery and successful
  documentation-only reconciliation, while dirty inspector edits remain
  unapproved and unverified.

Only the explicitly authorized documentation outputs were changed. No source,
schema, validator semantics, tests, database, runtime, Git history, or live
deployment state was changed. This entry is sanitized and records no raw data,
credentials, coordinates, or private overrides.

## Exact Prompt Entry: 2026-09-22 Repository Cartographer Protocol Refresh

- `Exact`
- Prompt summary: perform a fresh read-only inspection after substantial post-July
  changes; refresh the Thread 1 repository map and prompt log; verify combo views,
  expanded to-do/parent/PDF/map logic, the five-panel Overview, reference-date and
  Git-version behavior, validator artifacts, tests, package boundaries, and the
  Thread 6 role conflict; modify only the two ignored Thread 1 documents.
- Main output: replaced the July `cass_prep` map with a current `main` handoff at
  `c343b64`, documented current cross-thread files and unresolved wiring risks,
  and made no tracked source, SQL, data, or `AGENTS.md` changes.

## Exact Prompt Entry: 2026-09-27 Negative-brood methodology documentation

- `Exact`
- Prompt summary: read the current project state and cross-thread memos, then
  document the agreed negative-brood methodology across the project. The
  requested contract covers negative-ID table ownership, one-row-per-bird event
  entry, X-X representation, required GPS linkage, tent versus hiding-spot
  photos, parent-note examples, TODO behavior, PDF/map inclusion, positive
  `notA` retention, hatch-date blanks, and the separate roles of Threads 1, 2,
  3.1, and 4. It explicitly requires distinguishing agreed protocol,
  implementation, local mock state, and live deployment.
- Main output: updated `AGENTS.md`,
  `notes/codex_proposals/THREAD1_REPOSITORY_MAP.md`, and this ignored prompt
  log only. No SQL, validator, app, test, database, or live-data changes were
  made by Thread 1. Existing uncommitted source/test changes from Threads 2 and
  4 were inspected and documented, not staged or reverted.

## Milestones reached through prompt history: negative-brood protocol

- The project now has a single documented distinction between positive
  stationary nests, negative unknown-origin broods, and `NO_NEST` events.
- The cross-thread contract records that negative IDs are valid in `CAPTURES`
  and `RESIGHTINGS` only, require both GPS linkage fields, and are invalid in
  `NESTS` and `EGGS`.
- The event and photo methods are documented with one-row-per-bird entry, X-X
  handling, tent-photo versus H-class hiding-photo separation, and the valid
  eight-row occasion pattern.
- The operational contract records parent work, untrapped-brood work,
  day-1-through-day-6 hiding-photo tasks, task exclusions, blank hatch dates,
  colour/location provenance, and positive hatched-`notA` retention.
- Thread ownership is explicit: Thread 2 owns schema/derived views, Thread 3.1
  owns protocol/inspectors/mock validation, Thread 4 owns TODO/PDF/map/summary
  behavior, and post-save QA remains separate from save-time validation.
- At that earlier milestone, protocol version 1.2.0 and ignored negative-brood
  mock fixtures were recorded as local validation context. The current
  protocol is 1.2.1; the negative SQL/PDF/map/test implementation is complete
  and user-approved locally, while the newer ring SQL/view/test changes remain
  uncommitted and are not yet deployed or live-verified.

## Gaps / unrecoverable history: negative-brood refresh

- Thread 1 did not connect to the database or inspect deployed view definitions,
  so live support for negative broods cannot be confirmed here.
- The current worktree contains source changes from other threads, but their
  final commit/review status is outside this documentation-only task.
- Thread 3's proposal memo has older refresh metadata even though the official
  and local validator protocol copies now report version 1.2.0.
- The specialist memos now agree that `BROODS_LATEST`, negative TODO/PDF/map
  behavior, and protocol 1.2.0 are complete locally. Deployment and live
  inspector/view state remain separate checks.

## Exact Prompt Entry: 2026-09-27 Final cross-project negative-brood synthesis

- `Exact`
- Prompt summary: read the completed Thread 2, Thread 3.1, and Thread 4
  documentation, current implementation diff, and focused tests; synchronize
  project-level documentation for negative-ID semantics, event/photo entry,
  validator ownership, `BROODS_LATEST`, `TODO_LIST`, parent/brood/photo tasks,
  PDF map and summary retention, direct chick-location precedence, chick-band
  colour selection, tests, and cross-thread responsibilities.
- Main output: updated `AGENTS.md`,
  `notes/codex_proposals/THREAD1_REPOSITORY_MAP.md`, and this ignored log only.
  The local implementation is documented as complete and user-approved, while
  commit, push, PR review/merge, target-database deployment, live inspector/view
  state, and running-app verification remain outstanding. No database, live
  records, credentials, coordinates, SQL/R source, or tests were changed by
  Thread 1.

## Exact Prompt Entry: 2026-09-27 RESIGHTINGS ring-field documentation

- `Exact`
- Prompt summary: reinspect the completed Thread 2 schema, Thread 3.1
  validator, and Thread 4 hiding-photo task work, then synchronize project-level
  documentation for the nullable `RESIGHTINGS.ring` field, H-class hiding-photo
  requirements, per-chick event/photo/GPS entry, separate CAPTURES tent photos,
  `RESIGHTINGS_PUBLIC` stability, and cross-thread ownership.
- Main output: updated `AGENTS.md`,
  `notes/codex_proposals/THREAD1_REPOSITORY_MAP.md`, and this ignored log only.
  The documentation records protocol version 1.2.1, `RES_010`, the focused ring
  regression test, and the distinction between local approved implementation,
  uncommitted source changes, and undeployed/unverified live database state.
  No SQL, validator, R code, tests, database contents, credentials, records, or
  coordinates were modified by Thread 1.

## Exact Prompt Entry: 2026-10-23 Final Thread 3.1 synchronization

- `Exact`
- Prompt summary: synchronize the repository-wide documentation after the user
  manually delivered the Thread 3.1 validation-documentation recovery prompt
  and Thread 3.1 completed it successfully. Replace stale delivery-gap and
  replacement-specialist wording while preserving the protocol, protected WIP,
  and live-deployment caveats.
- Main output: updated `THREAD1_REPOSITORY_MAP.md`, `notes/codex_logs/INDEX.md`,
  and this log. The final status records the earlier empty-tool-result issue as
  a resolved historical coordination incident, confirms that the authoritative
  protocol remains v1.3.4, and states that the finalized documentation is ready
  to support future Thread 8 work. No source, SQL, validator, test, database,
  runtime, Git-history, or live-deployment state was changed.
## Exact Prompt Entry: 2026-10-23 documentation publication

- User request: after all specialist documentation was complete, create a new
  branch, commit and push the complete safe handoff set, and provide a PR link
  with detailed documentation/key-change comments.
- Publication decision: start from the latest `origin/main`, exclude the
  protected dirty SQL/PDF/validator/test checkout, track sanitized Thread 1-9
  handoffs and decision summaries, add a Codex-use transparency record, and
  include the reviewed Thread 8 manual.
- Confidentiality decision: raw prompts, attachments, database dumps, field
  identifiers, coordinates, private rollout rankings, and dated inventory
  states remain ignored.
- Deployment boundary: documentation publication does not prove live SQL,
  inspector, database, app, or field deployment.
