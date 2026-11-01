# Same-day X-X/first-banding verification — 1 November 2026

Luke explicitly approved treating confirming X-X evidence and one eligible
same-sex, same-nest, same-date first-banding capture as the targeted individual.
This record supersedes the earlier blanket same-day no-link expectation; it
does not rewrite the source identities or results of the 31 October runs.

## Change and preserved boundaries

Only `ADULT_PARENT_NEST_ASSOCIATIONS` in `DATABASE/views.SQL` changes executable
production logic in this follow-up. A small grouped first-marking pool counts
distinct eligible capture identities before later-proof or ambiguity filters.
A unique same-day link transfers that day's confirming proof without requiring
later sightings, including MM. The derived proof uses capture datetime rather
than inventing an observation time. One supersession join handles both linkage
and retirement; it does not independently re-expand that graph for each.

Different-day older X-X proof is not transferred. Ambiguity, competing captures,
sex/nest matching, date bounds, later X-X, original MM displacement history and
the established evidence hierarchy remain guarded. Seven-day/36-hour/tag gates,
juvenile-origin and brood-closure rules, table definitions, validators, external
YAML and application controls are not changed by this follow-up. The existing
refresh consumes the authoritative parent result without a second definition.

The manual is v2.4.14; its generated reader, chronology contract, machine-readable
rules/cases, current-system specification, handoff and agent guidance agree.

## Executed checks

One fresh isolated no-network MariaDB **11.8.9**, with case-sensitive names
(`lower_case_table_names=0`), used connected invented fixtures only.

| Focused suite | Passing assertions |
| --- | ---: |
| Actual extracted MM/X-X association SQL | 65 |
| Identity confirmation repairs | 106 |
| Selected-parent death handling | 11 |
| Existing To-Do source contracts | 687 |
| Manual content and deterministic reader rebuild | 80 |
| Existing capture-field hint guards | 55 |
| Total | 1,004 |

Zero failures, skips or warnings. Static contract assertions are not separate
SQL replays. The actual-SQL suite covers both sexes, same-day MM without later
proof, TN, different-day nontransfer, duplicates, competing F captures (including
a later ambiguous rival), eligibility, recaptures, another nest/sex, date cutoff,
later X-X, proof dating, earlier MM displacement, and invented two-/seven-event
observation-conservation scenarios. No real records appear in these tests.

The same instance completed source installation and a full **synthetic** refresh:

- Views installation: **37.423 seconds**.
- Refresh: **17.530 seconds**.
- Latest publication: succeeded, synthetic reference date 2026-11-02, four tasks.
- Current TODO/published snapshot: equal columns/types and null-aware byte-value
  row multiset, including duplicate multiplicity.
- No BUILD/PREVIOUS tables remained; source files were unchanged during execution.
- Existing comment generator returned eight PASS rows and withheld commands
  under unsupported escaping mode; no generated ALTER was executed.
- Owned server stopped, socket removed and owned volume detached.

These single tiny-fixture wall times are not field-scale or Adminer guarantees;
DDL validation is not SELECT runtime. No repeated field-scale profiling was used.

## Exact executed sources and retained evidence

| Source | SHA-256 |
| --- | --- |
| views.SQL | `877134c7ae8609376f62f4af34c0ca00c640cc562e23182211f8ba27a59d38de` |
| refresh_todo_list_snapshot.SQL (unchanged) | `02a5d744d18d4ec337c5c4908459af845fa8825e940012adb14e95fc323e4660` |
| Manual Markdown | `310d5a77823ee1379b1a9d20592a59b324b97dc03413bfac75b7c40c3e953030` |
| Generated manual reader | `36626df995c85ff9fdd00bef59d3e1ec1795c56e6fdaccf353b9d6c532ad0826` |
| MM/X-X test source | `4d5e8b34bf6145635dd7aaf8e08465cc52b1ae0a54d34a13bf64b8bec37ce31d` |

Ignored synthetic evidence: `tmp/codex/mm-chronology-2026-10-31/run-ccdd2e49cb/`,
including report.json, tests.json, stage logs and all thirteen frozen source hashes.
The first sandboxed attempt could not create its volume (`Device not configured`)
and ran no SQL; its failure is preserved separately in run-20c8477934. The approved
retry outside that sandbox restriction completed the checks above.

Target-specific local comparison evidence remains private, separate from these
invented reproducible fixtures; no field records or identities are published here.

## Limits, deployment and rollback

NOT RUN for this source: a fresh full field-dump refresh/PDF render, a live view
installation, an Adminer rehearsal or package/browser integration. No commit,
push, PR, merge or deployment was performed. Existing PDFs and earlier field
refreshes remain tied to their own older frozen source, not this new hash.
Old full golden artifacts remain NOT AVAILABLE; no full historical equivalence
is claimed. The reconstruction reference guard is not weakened or rebaselined.

For an unpublished rollback, reverse only this same-day source/test/documentation
patch, preserving other dirty work. A deployed rollback would require the human
to reinstall the previous reviewed views and rebuild the snapshot. Do not import
base-table DDL over populated tables or treat transactional ROLLBACK as DDL undo.
