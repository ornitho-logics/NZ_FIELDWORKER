# Thread 3 Prompt Log

Status: tracked sanitized history for the combined Thread 3/3.1 lineage. Raw
transcripts, attachments, and field identifiers remain local/ignored.

Thread role:

- Validation specialist

Reconstruction status:

- strong for the main prompt sequence visible in this thread
- moderate for older planning prompts inferred from ignored Thread 3 artifacts
- still incomplete for any prehistory not preserved in the visible conversation or ignored local notes

## Sources used for reconstruction

- current visible Codex conversation history for Thread 3
- [THREAD3_VALIDATION_ARCHITECTURE.md](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md)
- [THREAD3_CAPTURES_MOCK_VALIDATOR_PLAN.md](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/THREAD3_CAPTURES_MOCK_VALIDATOR_PLAN.md)
- [THREAD3_protocol_inspector_lists_res_cap_pub_obs.R](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/THREAD3_protocol_inspector_lists_res_cap_pub_obs.R)
- per-table inspector exports under [inspector_lists_by_table](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/inspector_lists_by_table)
- local file index at [FILE_INDEX.txt](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/inspector_lists_by_table/FILE_INDEX.txt)
- current local protocol mirror at [bdot_dataentry_validator_protocol_plot_aligned.yaml](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/xlsx_short_tag_update/bdot_dataentry_validator_protocol_plot_aligned.yaml)

## Exact prompt history

1. `Exact`
   Prompt family: create a local, ignored validator mock-data sandbox for `CAPTURES`, do not connect to `FIELD_2026_BADOatNZ` or `BADOatNZ`, and report back using the required inspection memo structure.

2. `Exact`
   Prompt family: replace the initial `CAPTURES_mock_data.R` contents with a user-supplied fake `CAPTURES` table and adapt it to the thread protocol, including sandbox metadata such as `mock_case` and `intended_failure`.

3. `Exact`
   Prompt family: first finish `CAPTURES_mock_data.R`, then go through `CAPTURES` fields one by one and think critically about validations.

4. `Exact`
   Prompt family: derive as many straightforward validators as possible directly from DDL comments for `CAPTURES`.

5. `Exact`
   Prompt family: update `CAPTURES_validator_sandbox.R` so `nest_id` uses a special Cass River scheme when `site == "CR"` while retaining the legacy species-based scheme elsewhere.

6. `Exact`
   Prompt family: export the `CAPTURES` mock data as an Excel sheet and write the export logic in R for local troubleshooting.

7. `Exact`
   Prompt family: compose candidate validator expressions as comma-separated inspector `list(...)` code suitable for the `inspectors` table.

8. `Exact`
   Prompt family: compare the composed list against collaborator-supplied validators, avoid conflict or duplication, and verify that replacement expressions are actually compatible with the live `inspectors` workflow.

9. `Exact`
   Prompt family: debug repeated `variable = NA` failures and messy reason strings in `CAPTURES` validators by backtracing how validator tables are generated and comparing against collaborator lists that behaved correctly.

10. `Exact`
    Prompt family: produce similar format-oriented validator lists for the other main DDL tables: `OBSERVERS`, `NESTS`, `EGGS`, `RESIGHTINGS`, and `RESIGHTINGS_PUBLIC`.

11. `Exact`
    Prompt family: across all columns containing `nest_id`, allow brood-origin IDs that start with `-`.

12. `Exact`
    Prompt family: explain inspector code blocks in plain language so the validation logic is understandable to a non-programmer.

13. `Exact`
    Prompt family: update `NESTS` inspectors so the CR-specific `nest_id` scheme is allowed, then compare multiple existing `NESTS` inspector lists and determine whether one can safely replace the others.

14. `Exact`
    Prompt family: do the same CR `nest_id` update and inspector comparison for `EGGS`.

15. `Exact`
    Prompt family: troubleshoot `RESIGHTINGS` and `RESIGHTINGS_PUBLIC` inspectors when apparently valid data were flagged, including behaviour parsing, tag-mark handling, nest-link logic, source handling, and copy-paste-ready full hard / warning lists.

16. `Exact`
    Prompt family: fix `CAPTURES` inspector issues such as moult parsing, `UR` / `UR_in` tag notation, negative non-CR `nest_id` acceptance, warning-versus-error phrasing, duplicate-mark detection, observer-upload rules, morphometric checks, photo logic, chick / juvenile exceptions, and biological cross-table warnings.

17. `Exact`
    Prompt family: read the protocol YAML at [bdot_dataentry_validator_protocol.yaml](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/bdot_db/data/working/bdot_dataentry_validator_protocol.yaml) and generate protocol-driven `hard_rules` and `warning_rules` inspector lists for each main table.

18. `Exact`
    Prompt family: treat that YAML protocol as the official spec-of-record for validator behavior and keep syncing approved scratch outputs into `bdot_db/data/working/`.

19. `Exact`
    Prompt family: review `AGENTS.md`, explain the current multi-list validator pattern, then rewrite the validator guidance so each biological data-entry table has only `TABLE_hard` and `TABLE_warning`, not residual lists.

20. `Exact`
    Prompt family: after initially considering a new validator-table `type` column, abandon the `validation_overrides.R` monkeypatch approach and instead prefix reasons with `ERROR:` or `WARNING:`.

21. `Exact`
    Prompt family: write per-table `*_hard.R` and `*_warning.R` files so inspector code can be pasted cleanly into the DB `inspectors` table.

22. `Exact`
    Prompt family: inspect a local SQL dump of the current `inspectors` table if helpful, then determine whether the old inspectors can be wiped and replaced one-for-one by the new generated hard / warning lists.

23. `Exact`
    Prompt family: repeatedly debug blank-save behavior across `CAPTURES`, `NESTS`, `EGGS`, `RESIGHTINGS`, and `RESIGHTINGS_PUBLIC`, especially any save-time validators that returned `variable = NA`.

24. `Exact`
    Prompt family: fix `EGGS` logic around `float_angle`, `float_location`, `float_surface`, missing `observer_upload`, clutch-level synchrony, developmental spread based on `EGGS_HATCH_PREDICTION`, and cross-checks against matching `NESTS` events.

25. `Exact`
    Prompt family: expand cross-table GPS validation so any table with `gps_id` and `gps_point` checks both duplicate use and existence in `GPS_POINTS`.

26. `Exact`
    Prompt family: update `NESTS` state logic across protocol and inspectors for `pP`, `pD`, `P`, `D`, `S`, and removal of `B`, including consequences for clutch / brood counts, terminal-state logic, and mock-data generation.

27. `Exact`
    Prompt family: update mock workbook and CSV exports so short-tag logic is used in `UR` / `UR_in`, plot-linked `nest_id` values fall inside the correct polygons, nest histories terminate appropriately, and downstream tables remain biologically consistent.

28. `Exact`
    Prompt family: refine `RESIGHTINGS` and `RESIGHTINGS_PUBLIC` combo matching so missing `M` in upper leg segments can be tolerated in the warning-level history comparison while other marks remain informative.

29. `Exact`
    Prompt family: require `nest_id` in additional `RESIGHTINGS` contexts such as chicks, `BC`, and `FC`, and make adult `IN` / `NM` nest-link logic depend on whether the bird is already linked by date to an active current-season nest.

30. `Exact`
    Prompt family: add cross-table leg-marking validators so comma-separated entries like `R,R` are rejected everywhere those band-position columns occur.

31. `Exact`
    Prompt family: change specific fieldworker-facing reason text, for example the `EGGS` `float_surface` message when `float_location == "surface"`.

32. `Exact`
    Prompt family: provide AGENTS-oriented thread feedback about how Thread 3’s role, scope, assumptions, and workflow had changed, then answer follow-up governance questions about spec-of-record, hard / warning structure, mock data, and the future visible `type` column idea.

33. `Exact`
    Prompt family: explain what `TABLE_residual` meant and then rewrite the AGENTS validator guidance so only `TABLE_hard` and `TABLE_warning` remain conceptually valid.

34. `Exact`
    Prompt family: edit `AGENTS.md` directly so the validator section reflects the two-list architecture and current validator governance.

35. `Exact`
    Prompt family: allow observations as early as July 1, 2026, and apply those date-window changes directly.

36. `Exact`
    Prompt family: move all former residual / format rules into either hard or warning lists, write the replacement per-table local R files, and inspect a recent local SQL dump of the `inspectors` table if useful for one-for-one replacement.

37. `Exact`
    Prompt family: explain what `validation_overrides.R` was, then drop that approach because a monkeypatch would likely be rejected.

38. `Exact`
    Prompt family: keep the standard DataEntry validator UI and instead inject severity into the `reason` string using `ERROR:` or `WARNING:` prefixes.

39. `Exact`
    Prompt family: fix blank-save `variable = NA` problems for `CAPTURES`, `NESTS`, `EGGS`, `RESIGHTINGS`, and `RESIGHTINGS_PUBLIC`, and update the local `inspector_lists_by_table` files because those are the exact lists being pasted into the DB.

40. `Exact`
    Prompt family: in `EGGS`, make missing `float_angle` and `float_location` warnings rather than errors, define conditional `float_surface` requirements, and correct additional blank-save NA issues after `observer_upload` was removed from that table.

41. `Exact`
    Prompt family: add the new `eggs_handled` field to CAPTURES validation and require it only for adult captures with a positive `nest_id`.

42. `Exact`
    Prompt family: substantially revise CAPTURES rules for morphometric outlier warnings, sample fields, `observer_upload`, tag-related `wt_w_tag`, `fat`, photo metadata, sequence checks, tag placement, unusual band-code warnings, juvenile / chick restrictions, and hatch-evidence cross-checks.

43. `Exact`
    Prompt family: explain why duplicated `rowid` strings like `1,1` appeared in a CAPTURES validation and keep refining the CAPTURES rules.

44. `Exact`
    Prompt family: make NESTS photo-field validations parallel CAPTURES photo logic, add observer-default `gps_id` / `cam_id` warnings, and add brood / clutch plausibility checks tied to `nest_state`.

45. `Exact`
    Prompt family: allow `S` in `NESTS.nest_state`, remove `B`, enforce `S`-specific clutch / brood behavior, and add warnings for `P`, `pP`, zero-clutch brood situations, and other nest-failure state combinations.

46. `Exact`
    Prompt family: update NESTS mock generation and the NESTS CSV so failure states like `P` / `pP` always have biologically correct `clutch_size`, `brood_size`, and `hatch_state`, and so photo events align with clutch-size changes.

47. `Exact`
    Prompt family: fix remaining NESTS blank-save NA issues and relax state-sequence warnings so clutch decreases at terminal states like `P`, `pP`, and `notA` are not incorrectly flagged.

48. `Exact`
    Prompt family: revise CAPTURES mock data so `eggs_handled`, `nest_id`, adult recapture schemes, historical combos, and dead-row output marks are realistic and validator-consistent.

49. `Exact`
    Prompt family: do the same full conflict / realism pass for mock `RESIGHTINGS` combinations against the updated `CAPTURES` workbook.

50. `Exact`
    Prompt family: update CAPTURES mock data and protocol so chick / juvenile rows leave tag fields blank, leave adult-only fields blank where appropriate, and eliminate duplicate rings or duplicate full combos against both the current season and archive history.

51. `Exact`
    Prompt family: run the respective inspector lists against each mock table and repair obvious realism failures across all mock datasets, especially where adult combos in `RESIGHTINGS` were not found in historic or current-season CAPTURES.

52. `Exact`
    Prompt family: correct easy mock-data mistakes such as invalid non-CR `nest_id` values and DDL mismatches like stray `sex_group`, and ensure photo fields can stay blank in `RESIGHTINGS` when `rclass == "R"`.

53. `Exact`
    Prompt family: check whether `GPS_POINTS` and `GPS_TRACKS` needed updating after recent mock revisions, then do an extra realism pass aligning coordinates and timestamps to event use and add corresponding GPS timestamp warnings to inspectors.

54. `Exact`
    Prompt family: recreate mock data and add new cross-table capture rules, including parents caught at least 36 hours apart, new site- and age-specific CAPTURES marking schemes, and certain brood-related RESIGHTINGS scenarios with comments like “chick bands not observed”.

55. `Exact`
    Prompt family: repair CAPTURES mock and inspector issues around white engraved flags, recruit remarking schemes, `falcon_upload` flexibility in RESIGHTINGS, lone-chick warnings, and NESTS state-sequence false positives.

56. `Exact`
    Prompt family: provide SQL inserts for `GPS_POINTS` and `GPS_TRACKS` so they could be pasted into Adminer, and prefer a plain text file for that output.

57. `Exact`
    Prompt family: allow or troubleshoot blank `time` handling in `RESIGHTINGS_PUBLIC`, then avoid editing `server.R`, instead ensuring mock public rows use a valid fallback time such as `00:00`.

58. `Exact`
    Prompt family: ensure `RESIGHTINGS_PUBLIC` mock `sex` values obey the enum `M`, `MU`, `F`, `FU`, `U`, and troubleshoot save-time SQL errors stemming from invalid public mock content.

59. `Exact`
    Prompt family: correct adult mark realism so lower-right adult tarsus combinations use two characters when no tag is present, keep the position of the `M` band consistent between `_in` and output marks, and re-sync RESIGHTINGS to CAPTURES after those CAPTURES corrections.

60. `Exact`
    Prompt family: patch `RESIGHTINGS` hard / warning inspectors so `NO_NEST` is treated as a sentinel rather than a real nest, then directly repair the listed RESIGHTINGS mock rows in the workbook and CSV.

61. `Exact`
    Prompt family: do the same `NO_NEST` relaxation for CAPTURES warnings tied to `field_sex` and parents caught less than 36 hours apart.

62. `Exact`
    Prompt family: mirror RESIGHTINGS dead-after-death logic into the external official validator YAML and add a new error rule so CAPTURES or RESIGHTINGS with a real `nest_id` cannot occur before the `F` date / time for that nest.

63. `Exact`
    Prompt family: add capture-method rules so `TN` requires a positive `nest_id` and `TB` requires a positive or negative `nest_id`, then update mock data to match.

64. `Exact`
    Prompt family: extend duplicate-ring and duplicate-combo warnings so they also consult `CAPTURES_ARCHIVE`, promote certain EGGS egg-id warnings to hard errors, and relax the public source-identifier duplication warning.

65. `Exact`
    Prompt family: remove `WARNING:` and `ERROR:` prefixes from all reason notes and replace them with politely worded, concise messages that ask the user to double-check the entry or add a validator bypass comment if correct.

66. `Exact`
    Prompt family: refresh AGENTS-aware local logging by updating the Thread 3 prompt-history log itself, keeping a clear distinction between exact, reconstructed, and inferred history plus milestones and gaps.

67. `Exact`
    Prompt family: remind the user of the float-angle limits by `float_location`, then relax those limits into warnings that say the angle is typically between X and Y for that location.

68. `Exact`
    Prompt family: make NESTS mock data more realistic around floatation and photo frequency, add early clutch-size-change scenarios, add `notA` timing variability, and create some `pD` then later `I` histories.

69. `Exact`
    Prompt family: keep refining NESTS mock data so `P` / `pP` never carry positive clutch sizes, photo events occur only when they should, and photo ranges never overlap across tables.

70. `Exact`
    Prompt family: update CAPTURES mock data so `eggs_handled` distribution, missing leg segments, missing non-CR `nest_id` values, full-combo reuse, and archive-history conflicts are corrected.

71. `Exact`
    Prompt family: continue the full realism pass for RESIGHTINGS combinations against updated CAPTURES, update CAPTURES dead-capture and historical-tagged cases, and keep mock tables and protocol aligned.

72. `Exact`
    Prompt family: inspect and explain all current warning-producing inspectors across tables, including the reason notes that users see.

73. `Exact`
    Prompt family: change several warnings to errors, introduce `NO_NEST` into CAPTURES and DDL comments, broaden photo-state reason text in NESTS, and refine various warning messages for RESIGHTINGS and RESIGHTINGS_PUBLIC.

74. `Exact`
    Prompt family: relax CAPTURES rules so status `D` rows may have blank release marks, then keep refining CAPTURES mock realism around CR adult schemes, juvenile white flags, and same-sex same-nest review warnings.

75. `Exact`
    Prompt family: correct adult lower-right tarsus marks, keep `M` position consistent between `_in` and output marks, and re-check whether RESIGHTINGS stayed valid after recent CAPTURES corrections.

76. `Exact`
    Prompt family: patch RESIGHTINGS and CAPTURES warnings that were falsely triggered because `NO_NEST` had not yet been treated as a sentinel rather than a real nest.

77. `Exact`
    Prompt family: add the rule that adults dead on or before a given date cannot be resighted later, and adjust RESIGHTINGS combo-history logic accordingly.

78. `Exact`
    Prompt family: add a new error that nest-linked CAPTURES or RESIGHTINGS cannot occur before the `F` event for that `nest_id`.

79. `Exact`
    Prompt family: ensure duplicate-ring and duplicate-mark warnings consult archive history, and relax the public source-identifier warning because repeated source IDs are often legitimate.

80. `Exact`
    Prompt family: give a fresh inventory of warning-producing inspectors and their reason notes, then remove severity prefixes from all reason text and replace them with polite no-prefix wording.

81. `Exact`
    Prompt family: diagnose blank-save validator errors in CAPTURES and NESTS that stemmed from save-time rules not guarding against empty rows, then patch the local lists.

82. `Exact`
    Prompt family: in EGGS, treat missing floatation values as warnings, add conditional `float_surface` requirements, and fix false warnings where matching NESTS rows clearly existed in the DB.

83. `Exact`
    Prompt family: in RESIGHTINGS, relax combo-history warnings when the only missing element is the upper-leg `M`, improve active-nest linkage logic using mark-based lookup in `NESTS_LATEST`, and add more nest-id-required contexts.

84. `Exact`
    Prompt family: make photo-field validations in RESIGHTINGS parallel the CAPTURES / NESTS pattern, and tighten some of those from warning to error.

85. `Exact`
    Prompt family: in RESIGHTINGS_PUBLIC, relax combo-history rules when `M` is omitted from the upper leg, explain the “usual public-source list,” and then make that source warning case-insensitive.

86. `Exact`
    Prompt family: add a global error across all tables with band-segment columns when leg markings are comma-separated instead of condensed, such as `R,R` instead of `RR`.

87. `Exact`
    Prompt family: update EGGS reason wording so surface eggs explicitly ask for a `float_surface` value of 0, 1, 2, or 3 indicating millimeters above the surface.

88. `Exact`
    Prompt family: refresh the Thread 3 prompt-history log itself using local ignored notes and visible thread history.

89. `Exact`
    Prompt family: soften float-angle limits into warnings rather than hard errors, and phrase them as typical ranges for the relevant `float_location`.

90. `Exact`
    Prompt family: update the mock NESTS dataset so most visits with floatation data also have photos, allow a small number of early clutch-size changes, and ask Thread 4 to later verify the to-do algorithm on those scenarios.

91. `Exact`
    Prompt family: update mock NESTS so every nest gets exactly one `notA` event with flexible timing, and add a few `pD` histories that later recover with an `I` event.

92. `Exact`
    Prompt family: regenerate mock NESTS again so all `P` / `pP` states always have `clutch_size == 0`, and ensure multiple photo events occur only when clutch size changes.

93. `Exact`
    Prompt family: let clutch-size progression warnings ignore legitimate drops tied to `P`, `pP`, or `notA`.

94. `Exact`
    Prompt family: add CAPTURES mock corrections so `eggs_handled` exists and adult captures split between 0 and 1, all release-side mark fields are filled where appropriate, non-CR nest IDs use BA-style schemes, and live adult full-combo recaptures become warnings rather than errors.

95. `Exact`
    Prompt family: do another full conflict pass on mock RESIGHTINGS combinations against the updated CAPTURES workbook.

96. `Exact`
    Prompt family: ensure RESIGHTINGS_PUBLIC mock rows no longer use invalid sex forms with `?`, and troubleshoot save-time insert errors caused by bad mock content rather than the tracked app code.

97. `Exact`
    Prompt family: confirm whether the current mock RESIGHTINGS table is still fine after CAPTURES changes, then repair the rows that are not.

98. `Exact`
    Prompt family: patch RESIGHTINGS hard / warning files so `NO_NEST` is consistently treated as a sentinel and directly repair ten named mock rows in the workbook and CSV.

99. `Exact`
    Prompt family: explain why CAPTURES warnings tied to same-sex adults per `nest_id` and short disturbance intervals were likely false positives under the new `NO_NEST` logic.

100. `Exact`
    Prompt family: refresh all current Thread 3 markdown documentation so a future validator-specialist thread starts from the current local architecture after recent `origin/main` and `cass_prep` changes.

## Reconstructed prompt history

1. `Reconstructed`
   Likely early prompt: inspect and explain the central DB-stored inspector architecture after the project moved away from tracked per-table `inspector.R` files.
   Evidence:
   - [THREAD3_VALIDATION_ARCHITECTURE.md](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md)
   - its emphasis on `inspectors`, `try_validator`, `rowid`, `variable`, `reason`, package-side uncertainty, and repo / package boundaries

2. `Reconstructed`
   Likely early prompt: design the first safe local CAPTURES validator sandbox before touching live inspector rows.
   Evidence:
   - [THREAD3_CAPTURES_MOCK_VALIDATOR_PLAN.md](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/THREAD3_CAPTURES_MOCK_VALIDATOR_PLAN.md)
   - that memo’s original focus on mock rows, rowid preservation, zero-row pass cases, and provisional validator categories

3. `Partial`
   Likely prompt family: consolidate protocol-driven lists and by-table inspector exports into a repeatable ignored local workflow for DB paste-testing and mock-workbook regeneration.
   Evidence:
   - [THREAD3_protocol_inspector_lists_res_cap_pub_obs.R](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/THREAD3_protocol_inspector_lists_res_cap_pub_obs.R)
   - `*_hard.R` and `*_warning.R` files under [inspector_lists_by_table](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/inspector_lists_by_table)
   - workbook / CSV repair scripts under `xlsx_short_tag_update/`

## Inferred task families

- central validator architecture mapping and boundary-setting between repo code, DataEntry package behavior, and DB-stored inspectors
- ignored local sandbox creation for validator prototyping
- comment-derived format validators and controlled-vocabulary checks
- CR-specific, negative, and `NO_NEST` `nest_id` logic across tables
- hard-versus-warning protocol classification and per-table inspector export workflow
- elimination of `variable = NA` failures in blank-save and live paste-test scenarios
- biological state-sequence rules spanning `NESTS`, `EGGS`, `CAPTURES`, `RESIGHTINGS`, and `RESIGHTINGS_PUBLIC`
- connected mock workbook / CSV regeneration so fake data stay aligned with protocol logic
- GPS-point, timestamp, and cross-table mark-history realism checks
- fieldworker-facing reason-note refinement and validator bypass wording

## Milestones reached through prompt history

1. Central validator architecture clarified
   What was achieved:
   - repo-visible versus package-side validator responsibilities were mapped
   - the `inspectors` table and `DataEntry/inspectors/` app were established as the live validator path
   Output / artifact:
   - [THREAD3_VALIDATION_ARCHITECTURE.md](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md)
   Status:
   - complete

2. First local CAPTURES sandbox established
   What was achieved:
   - a fake-data workflow for testing validator output shape, rowid preservation, and pass / fail cases was formalized
   Output / artifact:
   - [THREAD3_CAPTURES_MOCK_VALIDATOR_PLAN.md](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/THREAD3_CAPTURES_MOCK_VALIDATOR_PLAN.md)
   Status:
   - complete, but now mainly historical as a small debug harness

3. Protocol became the validator spec-of-record
   What was achieved:
   - validator behavior was re-anchored to the YAML protocol rather than drifting table by table
   Output / artifact:
   - official external protocol in `bdot_db/data/working/`
   - current local mirror at [bdot_dataentry_validator_protocol_plot_aligned.yaml](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/xlsx_short_tag_update/bdot_dataentry_validator_protocol_plot_aligned.yaml)
   Status:
   - complete

4. Two-list inspector pattern stabilized
   What was achieved:
   - live biological data-entry tables were reorganized conceptually around only `TABLE_hard` and `TABLE_warning`
   Output / artifact:
   - per-table exports under [inspector_lists_by_table](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/inspector_lists_by_table)
   Status:
   - complete as local architecture guidance; live DB state still depends on paste-in updates

5. Cross-table mock workbook became the main validator QA harness
   What was achieved:
   - validation work moved beyond isolated single-table toy data into a connected workbook and CSV workflow
   Output / artifact:
   - workbook / repair scripts / CSV exports under `validator_sandbox/xlsx_short_tag_update/`
   Status:
   - complete

6. Blank-save robustness became a standing QA target
   What was achieved:
   - repeated `variable = NA` failures on blank saves across tables were treated as first-class bugs
   Output / artifact:
   - multiple revisions to the local by-table hard / warning exports
   Status:
   - partial and ongoing

7. Severity strategy changed twice
   What was achieved:
   - the thread first explored a visible `type` column
   - then fell back to `ERROR:` / `WARNING:` prefixes in `reason`
   - then later removed those prefixes again in favor of polite concise reason text
   Output / artifact:
   - evolving local inspector exports and validator documentation
   Status:
   - complete for the current local convention, though older artifacts still preserve earlier phases

8. `NO_NEST` and post-`cap_start` schema assumptions propagated
   What was achieved:
   - validators and mocks were progressively updated to reflect the new sentinel and the removal of `cap_start`
   Output / artifact:
   - updated protocol mirror
   - current by-table exports
   - updated mock workbook / CSV outputs
   Status:
   - partial and ongoing

9. Cross-table biological realism expanded substantially
   What was achieved:
   - many rules now depend on nest chronology, hatch evidence, active-versus-terminal states, dead-after-death logic, historical combo checks, and GPS timestamp plausibility
   Output / artifact:
   - protocol updates
   - expanded hard / warning lists
   - repeated mock-data repair scripts
   Status:
   - partial and ongoing

10. Thread 3 documentation matured into a handoff layer
    What was achieved:
    - the architecture memo, CAPTURES plan, and prompt log now together preserve the validator architecture, workflow, chronology, and major decision changes for a future new validation thread
    Output / artifact:
    - [THREAD3_VALIDATION_ARCHITECTURE.md](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md)
    - [THREAD3_CAPTURES_MOCK_VALIDATOR_PLAN.md](/Users/luketheduke2/ownCloud/kemp_projects/bdot/R_projects/2026_NZ_FIELDWORKER/notes/codex_proposals/validator_sandbox/THREAD3_CAPTURES_MOCK_VALIDATOR_PLAN.md)
    - this log
    Status:
    - complete for the current local branch state

## Gaps / unrecoverable history

- I cannot recover every exact prompt boundary from older Thread 3 work that predates the currently visible conversation.
- Some local artifacts clearly merge the results of many prompts, so exact one-to-one wording cannot always be reconstructed.
- I did not use any database contents, credentials, or non-ignored sources, so any chronology that would require those remains intentionally absent.
- Exact timestamps for intermediate sub-prompts were not reconstructed here.
- Some later prompt families were grouped rather than transcribed one by one because the visible thread contained many tightly related iterative fixes on the same validator family.

## Negative-brood methodology update — 2026-09-27

This task updated the local validation artifacts for the negative-brood methodology. The official protocol was
incremented to version 1.2.0 before the local mirror was synchronized.

The agreed behavior is:

- a leading-minus nest_id is an operational brood identifier for unknown-origin broods, valid in CAPTURES and
  RESIGHTINGS but invalid in NESTS and EGGS;
- negative CAPTURES and RESIGHTINGS rows must retain the negative ID and carry both gps_id and gps_point, with the
  pair checked against GPS_POINTS;
- the first event may be CAPTURES or RESIGHTINGS, with one row per observed or captured individual, including valid
  repeated X-X rows for distinct unbanded individuals;
- H-class age-C RESIGHTINGS is the hiding-spot photo record; CAPTURES retains tent-photo handling and constrains
  chick_hide_photo to blank/0;
- the mock-only CAPTURES-first assumption was removed.

Local hard/warning inspector exports, protocol-driven mock fixtures, and focused parser/behavior tests must remain
local and must not be pasted into the live inspectors table without separate approval. No live database, credentials,
confidential rows, or real coordinates were used.

## Final negative-brood protocol/documentation audit — 2026-09-27

This audit was limited to protocol and documentation alignment. I inspected AGENTS.md, the official validator YAML,
the synchronized local YAML mirror, the current CAPTURES/NESTS/EGGS/RESIGHTINGS hard and warning drafts, the connected
negative-brood mock fixtures, relevant schema comments, and the validation architecture memo.

The official protocol and local mirror already agree at version 1.2.0 and record the approved negative-brood
semantics: negative IDs are valid linked identifiers only in CAPTURES and RESIGHTINGS; they are forbidden in NESTS
and EGGS with directions to enter the birds in CAPTURES or RESIGHTINGS; every negative-ID event requires both GPS
fields validated against GPS_POINTS; this is an exception to the ordinary positive-nest/direct-GPS exclusivity rule;
the first event may be in either CAPTURES or RESIGHTINGS; each bird and encounter is a separate row; X-X is valid
for unbanded birds; H-class age-C RESIGHTINGS records hiding-spot photos; CAPTURES records tent photos; and NO_NEST
remains distinct from a negative brood. Mock-generation-only and post-save QA rules remain outside live save-time
validation.

The architecture memo was updated with an explicit final-alignment section. No YAML semantic discrepancy was found,
so neither YAML copy was edited and the protocol version was not incremented. AGENTS.md still contains older protocol
identity metadata (1.0.1 / 2026-07-21); it was intentionally not edited because that file is owned by Thread 1.

Local protocol and inspector work is complete, but deployment to the live inspectors table is not established. Manual
deployment and portal verification remain separate steps. No live database or live inspectors rows were queried or
changed, and no tracked SQL/R/test files, commit, push, merge, or pull request was made.

## RESIGHTINGS H-class ring requirement — 2026-09-27

The current schema contract adds nullable RESIGHTINGS.ring varchar(50), documented as the alphanumeric metal-ring
code for the resighted individual, especially the chick in an H-class hiding-spot-photo event. The validator update
adds protocol rule RES_010 as a save-blocking error: normalized rclass H requires a nonblank ring; missing,
whitespace-only, NA, and textual NA values are reported on variable ring with a fieldworker-facing metal-ring message.

Ring remains nullable for all other RESIGHTINGS classes and supplements rather than replaces UL, LL, UR, and LR.
No new CAPTURES-specific ring regex and no live CAPTURES cross-table ring-consistency blocker were introduced;
future ring-history comparison would require a separately approved warning or post-save QA contract.

The official protocol was incremented from 1.2.0 to 1.2.1, and the local mirror was synchronized byte-for-byte.
The RESIGHTINGS hard draft, connected mock workbook/CSV export, negative-brood fixture, focused fake-data checks,
validation architecture memo, and this sanitized log were updated locally. No live database or inspectors rows were
queried or changed. The Thread 2 schema memo does not yet list RESIGHTINGS.ring in its prose/ALTER contract even
though DATABASE/main_tables.SQL documents the field; this remains a schema-documentation handoff item.

## NESTS WRYB Cass-ID correction — 2026-09-28

Prompt family: update the NESTS inspector so WRYB is accepted and Cass River WRYB nest IDs use the WR prefix,
while preserving the existing BADO A/B/C and BA patterns. The local hard inspector now accepts WRYB and validates
`WR` plus the established two two-digit components; negative IDs remain rejected in NESTS. The official protocol and
local mirror were incremented to version 1.2.2 and aligned byte-for-byte. A focused fake-data test covers valid WRYB
IDs, preserved BADO IDs, invalid prefixes, negative IDs, unrelated species, and blank-save behavior.

The latest user-supplied RDS was inspected only for non-coordinate NESTS/CAPTURES/RESIGHTINGS linkage facts. The
brood_size portal message is the warning-level same-day chick-event count review for H rows, and bird_inc is the
warning-level comparison against linked RESIGHTINGS sex; neither is the WRYB species or nest-ID failure. No live
database or live inspectors row was queried or changed.

## NESTS photographed visit with blank clutch size — 2026-09-29

Added local warning `NEST_W002` to the paste-ready NESTS warning inspector. It reports `variable = "clutch_size"`
when clutch_size is blank but nest/tent photo flags or photo metadata indicate a photographed visit, and now also
when hatch_state is populated and contains N. The reason asks the fieldworker to enter the observed clutch size and
to use 0 when no eggs were present. The rule is warning-level; existing photo metadata and numeric clutch-size checks
remain unchanged.

The supplied dump was inspected only for the requested NESTS fields. Matching
events were reviewed, but their identifiers are omitted from this tracked log.
The focused parser/fake-data/read-only dump test passed. Protocol version 1.2.9 and the local mirror were synchronized;
the live database and live inspectors table were not queried or changed.

## Relax same-day H chick-event warning — 2026-09-28

Prompt family: relax the NESTS `brood_size` validation because chicks may be captured or resighted later than the H
visit and CAPTURES/RESIGHTINGS may be entered in separate portal sessions. The exact same-day H chick-event block was
removed from the local `NESTS_warning.R` export. Numeric non-negative whole-number brood_size validation and nest
chronology rules remain unchanged. The former check was moved to protocol `NEST_010D` post-save QA: later age-C
CAPTURES or RESIGHTINGS are accepted, CAPTURES need not precede RESIGHTINGS, and the QA check never blocks the
original NESTS save. Protocol version 1.2.3 and the local mirror were updated; a focused relaxed-warning test passed.

No live database or live inspectors row was queried or changed.

## Relax NESTS bird_inc linkage warning — 2026-09-28

Prompt family: relax the NESTS `bird_inc` warning because a same-date RESIGHTINGS row may describe a different visit.
The previous live warning matched nest_id, date, observer, and GPS pair, but RESIGHTINGS has no event-time field and
therefore cannot establish exact visit identity. The automatic `bird inc vs resight` block was removed from the local
NESTS warning export. The NESTS hard code-set check remains unchanged, so approved values including `E` continue to
pass. Protocol version 1.2.4 and the local mirror were updated; exact comparison is now manual/future post-save QA
only when an exact event key or reliable event-time linkage exists. Focused parser and fake-data checks passed.

No live database or live inspectors row was queried or changed.

## CAPTURES in situ comment warning — 2026-09-28

Added local warning `CAP_W013` to the paste-ready CAPTURES warning inspector. For `age = "C"`, comments matching
case-insensitive `in situ`, `insitu`, `in-situ`, or equivalent underscore-separated wording now report
`variable = "comments"` and direct the fieldworker to enter hiding-spot photos as a separate RESIGHTINGS event with
`rclass = "H"`. The warning is non-blocking because comments are free text and the phrase may be contextual rather
than an incorrect photo entry. Protocol version 1.2.6 and its local mirror were updated; live inspectors and the live
database were not changed.

## CAPTURES status-R mark-change correction — 2026-09-29

The CAPTURES hard inspector was updated under `CAP_013`. A status-R row whose nonblank input mark differs from the
corresponding release mark remains save-blocking. When the normalized ring is present in CAPTURES_ARCHIVE or current-
season CAPTURES history, the returned fieldworker message directs the user to change `capture_status` to `C`; the
existing generic mismatch message remains the fallback when prior ring history is unavailable. The current-season
fallback is required for valid same-season recaptures that have not entered the historical archive.

The latest user-supplied dump was checked only for the requested non-coordinate CAPTURES fields. One current status-R
mark mismatch was found and no additional current status-R mark mismatch was found. A separate pre-existing tag-weight
validation issue was retained. A focused parser/synthetic test and a read-only evaluation against the supplied dump
passed. The official protocol and local mirror were incremented to 1.2.7 and synchronized byte-for-byte. No live
database or live inspectors row was queried or changed.

## RESIGHTINGS sex-history warning — 2026-09-29

Added local warning `RES_005H` to the paste-ready RESIGHTINGS warning inspector. The rule compares the actual
RESIGHTINGS `sex` value with the identified bird's capture history: it matches by nonblank ring when available or
by the existing canonical partial leg-mark signature, prefers nonblank `CAPTURES_ARCHIVE.gen_sex`, otherwise uses
archive `field_sex`, and falls back to current `CAPTURES.field_sex` when no definitive archive match exists. M/MU
and F/FU are treated as equivalent; unknown or ambiguous history is not treated as a contradiction. Definite M/F
conflicts report `variable = "sex"` as a warning rather than a save blocker because capture history can be incomplete
or uncertain.

The supplied snapshot was inspected only for one requested non-coordinate
linkage; its field identifier is omitted from this tracked log. The reported
adult mismatch pattern was present in the snapshot. Synthetic male/female, M/MU and F/FU equivalence, archive `gen_sex` precedence,
parser, and connected mock lookup checks were added or run locally. Protocol version 1.3.1 and its local mirror were
synchronized byte-for-byte. No live database or live inspectors row was queried or changed.

## Thread 3.1 source-to-document reconciliation — 2026-09-30

This was a documentation and protocol audit, not a new biological-rule request. I
read `AGENTS.md`, the current schema and view SQL, DataEntry wrappers, central
inspector editor, official protocol, local protocol mirror, all current hard/warning
exports, connected mock workbook/CSV/runner/report artifacts, negative-brood fixtures,
focused validator tests, Thread 1/2/4 handoffs, geolocator notes, README/help text,
and recent Git history.

The official YAML and synchronized local mirror remain byte-identical at protocol
version 1.3.1, generated 2026-09-29, SHA-256
`fc0d86534c5e86f1517b0f1fb3655056cc34f51a1a285af2313076d2854540ad`. No machine-
readable validator semantics changed and the protocol version was intentionally not
incremented. The architecture memo was rewritten as a coherent current-state
handoff; this entry is sanitized and contains no credentials, live rows, coordinates,
or database connection details.

The current local inspector inventory remains exactly two categories per biological
table: `*_hard.R` and `*_warning.R` for OBSERVERS, EGGS, NESTS, CAPTURES, RESIGHTINGS,
and RESIGHTINGS_PUBLIC. No residual inspector category was added. Mock-generation-only
and post-save QA rules remain outside live save-time validation. The negative-brood,
H-class ring/photo, relaxed brood-size and `bird_inc`, WRYB, CAPTURES photo/status,
and RESIGHTINGS sex-history decisions are documented as current v1.3.1 behavior.

An unresolved cross-thread discrepancy was recorded rather than changed: current
`RES_005B` and the local RESIGHTINGS hard export allow the approved narrow unlinked-H
save-time exception without requiring a prior CAPTURES family-link query. Thread 2/4
documentation describes a stricter derived TODO association requiring prior chick
capture evidence and same-date exact-GPS family evidence. The current `HEAD` SQL does
not define `RESIGHTINGS_H_BROOD_ASSOCIATIONS`; the pre-existing dirty SQL references
it without defining it, while the tracked TODO-view test expects no such reference.
Historical commit `5d625df` is not an ancestor of the current branch. This remains a
schema/TODO deployment issue, not a reason to silently tighten the save validator.

The repository was on local `main` at `fc86bf0`, behind `origin/main` by ten commits.
Pre-existing changes to `DATABASE/views.SQL`, `main/R/ggplot_overview.R`, and
`tests/testthat/test-main-server.R` were preserved. No tracked source/test file,
database, live inspector row, commit, push, merge, or pull request was changed.

## Require CP H-ring format and prior CAPTURES history — 2026-09-30

Added two save-blocking H-only RESIGHTINGS rules after a fieldworker entered a
malformed chick-ring prefix during a hiding-spot-photo event. The real value is
omitted from this tracked log:

- `RES_010A` requires a nonblank H ring to use the existing CAPTURES metal-ring
  format `CP12345` or `CP-12345`, reporting `variable = "ring"`;
- `RES_010B` requires the normalized H ring to already exist in current-season
  `CAPTURES`. Case and the optional dash are normalized so an invented
  `CP12345` and `CP-12345` identify the same ring.

Non-H RESIGHTINGS classes remain allowed to leave `ring` blank. The existing
`RES_010` nonblank rule, H age/sex/GPS/photo/leg-mark requirements, and ring-versus-
leg-mark distinction remain unchanged. A format failure reports the CP-format
message; a valid-but-unseen CP ring reports that the chick must already have been
banded in CAPTURES before its hiding-spot photo.

The official protocol and local mirror were incremented to version 1.3.2 and remain
byte-identical with SHA-256
`ccc2527266c899d10b42fb56b27d17659d564664371090aeeeceb47052f59b2b`. The focused
H-rule fixture now covers an invented malformed-prefix example, valid existing
rings, equivalent CP-dash values,
missing CAPTURES history, and non-H exemption. No live database or live inspectors
row was accessed or changed.

## Require nest linkage for first-capture chicks — 2026-09-30

The CAPTURES hard validator was updated so an age-C row with
`capture_status = "F"` must carry a real positive `nest_id` or a negative brood
ID. Blank `nest_id` and `NO_NEST` now produce a save-blocking `variable =
"nest_id"` message explaining that the first chick capture must be linked to a
nest or brood.

For positive-nest first captures, GPS is optional: both fields may be blank for a
nest capture, or both may be supplied for an away-from-nest capture. A partial GPS
pair remains invalid, and any complete pair is still checked against GPS_POINTS.
Negative brood IDs retain their existing requirement for both GPS fields. Other
unlinked CAPTURES rows retain the ordinary direct-GPS branch.

The official protocol and local mirror were incremented to version 1.3.3 and
synchronized byte-for-byte with SHA-256
`9965d1f313ea172ac76f62b0b02e9c42895d659ee2fba9b62c526286c29b2732`.
Focused parser and connected negative-brood fixture checks passed. No live
database or live `inspectors` row was queried or changed.

## 2026-10-23 - Exact - Recovery delivery limitation

The successor validation follow-up was requested as part of a repository-wide
documentation recovery pass. The delivery could not be accepted because the
destination consumed repeated deliveries as empty tool-result turns. This is a
coordination limitation, not a validator decision.

The current external protocol and synchronized local mirror are version 1.3.4,
generated 2026-10-10. The protected checkout still contains dirty inspector
exports and related SQL/PDF/test WIP; none was revalidated, staged, committed,
pasted into live inspectors, merged, or described as deployed. A replacement
Thread 3.1/3.2 must read the current protocol, tracked hard/warning exports,
connected mock fixtures, and the Thread 2/4 handoffs before proposing any live
change. No credentials, raw rows, coordinates, or validator source beyond the
existing local artifacts were copied into this log.

## 2026-10-23 — Exact — manual validation-documentation recovery prompt

The user manually pasted the prompt titled **“THREAD 3.1 – Validation
documentation recovery and full handoff refresh.”** It explicitly requested a
documentation-only reconciliation so that the validation thread could be
recreated safely and Thread 8 could prepare the human field manual. It required
the current `AGENTS.md` to be read first, all existing dirty work to be
preserved, and the following to remain untouched: runtime behavior, biological
rules, validator logic, SQL, application code, tests, mock workbooks, inspector
exports, protocol YAML, live database state, staging, commits, pushes, merges,
rebases, and pull requests.

The authorized documentation targets were only:

- `notes/codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md`;
- `notes/codex_logs/THREAD3_PROMPT_LOG.md`; and
- narrowly supported Thread 3.1 corrections in `AGENTS.md`.

The prompt required inspection of repository state, all current hard/warning
exports, both protocol copies and their identity/version/date/checksum, the
central inspector editor, table wrappers, schema/view SQL, connected mock
fixtures and focused checks, recent validator history, and the Thread 1/2/4
handoffs. It required the reconciliation to distinguish approved specification,
local implementation artifact, protected WIP, mock-tested behavior, and
live/deployed behavior; to document negative broods, H-photo ring rules,
parent/chick same-session linkage, `IN`/`NM`, `BW`, and the v1.3.4 authority; to
record cross-thread boundaries, uncertainties, rollback, verification, and a
replacement-thread bootstrap; and to stop after documentation checks.

This prompt is a user instruction, not a validator decision. The current
working-tree state and the inspection results are recorded in the architecture
handoff. No live database or live inspector row was accessed, and no
implementation artifact was changed by this recovery task.

## Protocol-version progression — reconstructed milestone summary

The following progression consolidates the exact historical entries preserved
above and the current protocol header:

- **1.3.2** — H-class RESIGHTINGS ring format and current-season CAPTURES
  existence became save-blocking; ordinary RESIGHTINGS classes could still
  leave `ring` blank.
- **1.3.3** — age-C first CAPTURES rows required a real positive nest or
  negative brood; positive-nest chicks could omit GPS at the nest but a supplied
  GPS pair had to be complete; negative-brood GPS remained mandatory.
- **1.3.4** — same-session RESIGHTINGS parent/chick co-entry became
  save-blocking for ordinary age-C `H`/`R`/`P`/`V` rows and age-A `BC`/`FC`
  parent rows; linkage requires the same date and either the same nonblank
  `nest_id` or the same complete `gps_id/gps_point` pair. `IN`/`NM` active-nest
  state checks were separated from brood association, and `BW` was documented
  as broken-wing display.

The verified current identity is
`bdot_2026_2027_dataentry_validator_protocol`, version `1.3.4`, generated
2026-10-10, with SHA-256
`1de6c733851c992e296d048bbf35ba5feffda11d1ad7e43c147fe5007359ea7f`. The
official YAML and local mirror are byte-identical. The current local
RESIGHTINGS artifacts extend the behavior set with `AC`; the hard-export
portion is protected WIP, and the later extension is not silently promoted into
the verified protocol history.

## 2026-10-23 — Protected WIP and deployment boundary

The protected checkout is `codex/split-todo-calculator-2026-10-19` at `d3c7bd4`,
with local `origin/main` at `9beb203ac2757219def35e47bfe54bd6ac8684a2` when
inspected. Pre-existing dirty work includes four inspector exports, SQL, PDF
code, tests, and multiple handoffs. The WIP includes AC-related RESIGHTINGS
logic, same-session H-photo overlap handling, NESTS state/clutch changes, and
an adult HA capture rule. These changes remain protected and were not
revalidated, staged, committed, pushed, deployed, or declared approved.

The official protocol still contains the compatibility-era `chick_hide_photo`
and `CAP_029` behavior. Later requests to treat that field like
`chick_tent_photo` and remove the in-situ warning are also implementation WIP;
they were not changed or silently documented as current protocol behavior in
this recovery pass. The live `inspectors` table and running portal remain
unknown.

The earlier cross-thread delivery problem was that the destination rendered
repeated deliveries as empty tool-result turns. It was only a coordination
failure; it did not indicate validator approval, rejection, deployment, or a
biological-rule decision.

## Replacement Thread 3.2 bootstrap prompt

> Read `AGENTS.md` and
> `notes/codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md` in full. Perform
> a read-only validation-workstream audit from the current checkout. Preserve
> all dirty files and do not access live databases, credentials, or DB-managed
> inspectors. Verify the external protocol version and the staged local mirror
> version 1.3.6, compare the protocol with all tracked hard/warning exports, and separate approved
> behavior from protected WIP and historical material. Use invented/mock data
> only. Report discrepancies, do not edit implementation, and stop before any
> staging, commit, push, paste, deployment, or PR action.

The replacement thread must report what was inspected, what the protocol says,
which local artifacts diverge, what remains protected or uncertain, whether any
live state was inspected, and which documentation or mock checks were run. It
must not infer live deployment from a tracked export or a local mock pass.

## 2026-10-26 — Exact — photo-range validation documentation update

The user requested that documentation and protocol material associated with the
merged photo-overlap inspector PR be reconciled and staged on
`codex/sync-validator-protocol-ac-2026-10-26`, alongside the existing Thread 4
protocol work. This is a documentation/protocol update only; it does not write
the live `inspectors` table, deploy validators, or modify biological data.

The tracked local protocol mirror is advanced to version **1.3.6**, generated
2026-10-26. The new revision records the exact `GLOBAL_005` photo identity and
reuse rules:

- a terminal roll-frame prefix is part of the image identity, so `101-4122` and
  `102-4122` are different images;
- a final filename extension is ignored for the numeric comparison;
- multiple age-C `rclass = H` RESIGHTINGS rows may share a range only when they
  use the same camera and date and share either the same nonblank `nest_id` or
  the same complete `gps_id/gps_point` pair;
- adult `P`/`V` rows, cross-table CAPTURES/NESTS/RESIGHTINGS rows, and H rows with
  different linkage remain conflicts; and
- an edited saved row is not compared against its own stored `pk`.

The architecture handoff was updated to describe the same rules, the distinction
between the merged implementation and live deployment, and the fact that the
external working protocol file remains outside this repository. The focused
invented-data test for all three photo-bearing exports passes 25 tests. The
external canonical protocol was not edited by this branch, so the local v1.3.6
mirror remains a staged synchronization artifact until that separate file is
updated through its own approved workflow.

## 2026-10-26 — Age-C measurement-based flagging boundary

The user supplied a sanitized summary of seven current-season recaptured chicks
that had received engraved flags and requested a measurement-based distinction
between age-C `capture_status = R` and `capture_status = C` warnings. The supplied
minimums were tarsus 27.70, culmen 13.80, weight 22.80, and total_head 38.80
(total_head was available for only three of the seven birds); no wing values were
available.

The tracked CAPTURES warning export and local protocol mirror were updated to
version **1.3.10**. Status-R warning ceilings are now tarsus 26.99, culmen
13.79, and weight 21.99. These values implement the explicit operational rule
that a chick below tarsus 27 or weight 22 should not be treated as flag-ready,
while keeping the comparison strict despite the interval validator's inclusive
endpoints. Status-C lower review limits are tarsus 27.70, culmen 13.80,
total_head 38.80, and weight 22.80; existing broad upper bounds were retained
because the supplied sample does not support new maxima. `total_head` and `wing`
remain save-blocked for age-C status-R rows by the separate morphometric presence
rule. The range checks remain warnings and do not infer or force
`capture_status`.

The architecture handoff and `AGENTS.md` were updated to describe the new
boundary, the small-sample limitation for total_head, and the distinction between
the tracked local protocol mirror, inspector export, and live DB-managed
inspectors. No live database, live inspector row, credentials, or raw field data
were accessed or changed. No commit or push was performed; the unrelated
`main/R/pdf_todo.R` working-tree modification remains protected.
