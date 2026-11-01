# MM/X-X and capture-field hint follow-up — 31 October 2026

This is separate from the earlier reconstruction-only verification. Luke
explicitly approved preserving pre-MM evidence for known individuals, applying
sex-aware X-X/new-marking chronology, fixing any relevant gaps, and aligning
capture-field hints without changing validator behaviour. No production access,
publication, field-dump replay or live migration was performed.

## Source scope

- `DATABASE/views.SQL`: only `ADULT_PARENT_NEST_ASSOCIATIONS`. Remove transfer
  of earlier X-X proof, allow unique replacement through one confirming or
  three distinct eligible postcapture observations, preserve original conflict
  history, protect independent proof and deduplicate third-event chronology.
  Public view columns and ordinary identity matching remain unchanged.
- `DATABASE/main_tables.SQL`: eight incoming/release leg COMMENT literals only.
  No type/default/constraint or biological-row changes.
- Separate read-only hint generator and instructions; no generated ALTER run.
- Manual v2.4.13 and regenerated reader, focused tests, specialist handoff and
  reconstruction contracts/machine-readable examples.
- Refresh SQL, inspector implementations, validator YAML, Shiny controls,
  capture timing and tag eligibility remain unchanged by this follow-up.

Frozen SHA256 at the accepted run:

| Source | SHA256 |
| --- | --- |
| views.SQL | `5d5c0ef80cec89bf1716b00f94ee78d64a047fd77f928aa05377a75640ca057d` |
| main_tables.SQL | `9a58fa8a2118722ac81cb741cf5b7f1234031bbe4d0c7a5e57b1bd0921d65b2a` |
| refresh_todo_list_snapshot.SQL | `02a5d744d18d4ec337c5c4908459af845fa8825e940012adb14e95fc323e4660` |
| capture_mark_field_hints_2026-10-31.SQL | `0c5fc5e06a0a4adc8ae5ef8588babdeecb9ad30fbe37781f5e2482544188fcc6` |

The private run report records thirteen source/test/manual hashes and confirms
they were unchanged during the accepted run. This documentation was written
after execution. Unrelated existing changes and the untracked `to-do` item were
preserved; no Git staging, commit, push or PR was performed.

## Completed checks

- PASS: independent source review of chronology, ambiguity, grouping, proof
  dates, same-sex partitions, unchanged output columns and planning shape.
- PASS: full current views install and actual refresh on an owned MariaDB
  11.8.9 instance, networking disabled, case-sensitive names (`lower_case_table_names=0`)
  on a newly owned case-sensitive volume. Only invented connected fixtures.
- PASS: latest publication succeeded for the synthetic reference date
  2026-11-02 with four synthetic tasks; current To-Do and snapshot had identical
  column types and null-aware byte-value row multisets, including duplicates.
  No BUILD/PREVIOUS tables remained.
- PASS: 36 new actual-extracted-SQL chronology assertions; 106 identity repair,
  11 selected-death, 685 existing To-Do rule, 75 manual and 55 field-hint
  assertions. Total 968; zero failures, errors, skips or warnings. The 685
  existing rule checks include static contracts and are not 685 SQL replays.
- PASS: read-only hint generator returned eight PASS rows; the unsupported
  NO_BACKSLASH_ESCAPES mode failed all eight and withheld apply/rollback commands.
  Eight source/generator comments match exactly and remain below 1024 characters.
- PASS: fourteen reconstruction-tool safety checks, JSON parsing/unique case
  IDs, deterministic static manual rebuild and whitespace checks.
- PASS: owned server stopped, private socket removed, case-sensitive volume
  detached. No existing server, field config, field data or package library used.

Accepted ignored evidence:
`tmp/codex/mm-chronology-2026-10-31/run-52bcb11f94/`, including report.json,
tests.json, tests.log and per-install stage logs. Generated evidence is private,
not a clean-clone prerequisite or a substitute for tracked reproducible cases.

## Measured synthetic costs and rejected intermediate candidate

Final tiny-fixture installation took **35.600 seconds** for views; refresh took
**17.339 seconds**. DDL planning/validation is not SELECT execution cost. These
are single-run observations, not controlled field-scale benchmarks or Adminer
time guarantees. No expensive field replay or later profiling run was used.

The first intermediate correction passed predicate tests but duplicated an
association aggregate through multiple branches. Its synthetic install took
173.211 seconds and refresh 64.692 seconds, so it was simplified before handoff.
That intermediate run also had source drift and is not accepted final evidence.
The final pipeline reuses small grouped chronology data in a single aggregate
chain and window-counts candidate identities instead of joining the same proof
graph twice. Hint metadata lookup uses literal base-table pruning alongside
exact-spelling guards, avoiding unrelated view expansion.

Earlier harness failures (socket sandbox denial, missing schema context,
nested fixture-CTE visibility and semicolon-containing SQL comments) remain in
ignored logs. They were not treated as biological failures or passed results.

## Explicit release limits and rollback

NOT RUN: a new approved field-dump refresh, final team PDF, Adminer/browser
installation, live hint update or production performance check. Old field
golden artifacts remain NOT AVAILABLE; no exact historical field equivalence
is claimed. Synthetic task count four is not an operational team task count.

The reconstruction reference guard deliberately still rejects protected runtime
changes since `9e010e5`; a later approved release must establish its own baseline
or explicit adaptation approval. This patch does not relax that guard or turn
the earlier reference report into a pass for changed production source.

For an unpublished candidate, remove only this reviewed SQL/comment/manual/test
follow-up. Do not discard unrelated reconstruction work. For human-controlled
live rollback, restore the prior reviewed view source and rebuild the snapshot;
restore comments only from saved pre-change rollback values. Do not import
main_tables.SQL over populated tables or use ordinary transaction ROLLBACK as
an undo mechanism for DDL.

## Approved-decision addendum — 1 November 2026

The 31 October source scope, frozen hashes, results and measured costs above
are retained unchanged as historical evidence. Luke's approved 1 November
decision supersedes the blanket same-day no-link expectation: an eligible
confirming X-X and unique eligible `capture_status = F` first-banding identity
of the same sex, nest and date are assumed the targeted same individual,
including MM without later sightings. Same-day proof transfers; different-day
older proof does not. The new bird's own valid same-day linkage can now retire
an older placeholder without transferring its proof. Preserve the date and
infer no observed time/order; SQL will date linked proof at capture datetime.
The first_marking_counts pool counts all distinct eligible same-nest/sex/date
F capture identity keys before later-proof or ambiguity filters; filtering
cannot manufacture uniqueness. Link only a unique replacement and unambiguous
confirming resighting, preserving original X-X history and MM displacement.

New focused verification: **PASS**, recorded separately in
[SAME_DAY_LINKAGE_VERIFICATION_2026-11-01.md](SAME_DAY_LINKAGE_VERIFICATION_2026-11-01.md).
The changed association SELECT passed 65 actual-SQL chronology assertions,
1,004 assertions overall and one fresh isolated synthetic MariaDB 11.8.9
install/refresh. Prior counts/hashes above remain historical, not reused.
The new full field/PDF replay, live installation, Adminer and package/browser
integration remain NOT RUN; see the new record for exact sources and limits.
