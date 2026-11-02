# CAPTURES incoming and release mark field hints

This comment-only update aligns the eight leg-field descriptions with the
[current manual](../main/www/field-manual/manual.md#section-6) and the tracked
[CAPTURES hard inspector](../notes/codex_proposals/validator_sandbox/inspector_lists_by_table/CAPTURES_hard.R),
especially its capture-mark and dead-recovery checks. It changes no validator,
input value, field type, default, requiredness, or application interaction.

## Meaning of the descriptions

| Status | Incoming: UL_in, LL_in, UR_in, LR_in | Release: UL, LL, UR, LR |
| --- | --- | --- |
| F | Enter X in all four under the manual's entry guidance; the existing validator also tolerates blanks here. | Record actual new marks, not all X. |
| R | Complete existing marks in all four positions. | Complete marks identical to incoming. |
| C | Complete previous marks, not all X. | Complete actual marks, with at least one position changed. |
| D, any age | All four recovered positions, using X only where no mark is present. | All four fields blank, and released time blank. |

X means an observed position with **no mark**, not missing or unreadable
information. Never replace an unreadable mark with X or enter a question mark
in a capture leg field; describe the exception and refer it for review.
For D, blank release fields mean no release occurred. They must not be filled
with X to make a complete release combination. Actual recovered flags/bands
belong in the incoming fields; do not invent a new marking event.

## Repository source versus installation

[main_tables.SQL](main_tables.SQL) changes only the eight CAPTURES COMMENT
literals. Existing databases retain their existing comments until an authorized
operator applies a separate update. Do not import the full base-table DDL as
an upgrade. No inspector installation, view rebuild, To-do snapshot refresh,
record rewrite, column widening, or new dependency is needed.

[capture_mark_field_hints_2026-10-31.SQL](capture_mark_field_hints_2026-10-31.SQL)
is one read-only WITH/SELECT query over information_schema. Its eight desired
comments are copied verbatim from the updated source literals. Keep those
strings synchronized if these descriptions are later reviewed again. The query
returns metadata, PASS/FAIL, desired/current comments, and apply_sql/rollback_sql
**result values**. It never executes the generated ALTER statements.

Both metadata joins include direct literal schema/table predicates to bound
inspection to FIELD_2026_BADOatNZ.CAPTURES and let MariaDB avoid expanding
unrelated views during metadata permission checks. The additional BINARY
exact-spelling guards and all metadata/collation safeguards remain in place.

The generator requires the exact selected schema and object spelling,
an InnoDB base table, and all eight ordinary columns to be nullable
varchar(10) with SQL NULL defaults, no extra/generated attributes, and known
charset/collation. The metadata check accepts MariaDB's unquoted NULL default
representation, not a quoted string default. Missing columns, changed metadata,
the wrong selected schema, or NO_BACKSLASH_ESCAPES fail closed. One failed
target suppresses **all** apply/rollback commands. Do not bypass a failed guard.

## Operator procedure, when separately authorized

1. Stop concurrent schema/comment changes. In Adminer select FIELD_2026_BADOatNZ
   and run the entire generator. It reads metadata only, not capture records.
2. Require exactly eight PASS rows for the expected fields. Review desired
   comments and actual type/charset/collation/default metadata. If any row fails,
   inspect the deployment difference before proceeding.
3. Save the eight rollback_sql **result values** privately before applying
   anything. Also retain the inspected original-comment metadata. Adminer's
   SQL export may save the generating SELECT rather than its result values.
4. Copy only the eight apply_sql **result values** into a new, separately
   authorized SQL command with **Stop on error** enabled. Never paste the
   rollback column alongside them. Use a connection with the same privileges
   and server/target schema, and do not alter columns between generation/apply.
5. Retain ALGORITHM=INSTANT, LOCK=NONE, and the finite 30-second metadata-lock
   timeout. Failure is a reason to stop and inspect, not to permit a table copy,
   remove safeguards, or rerun the complete base-table DDL.

Generated commands retain each column's inspected type, charset, and collation,
and explicitly keep NULL DEFAULT NULL. Each command reasserts the inspected
session sql_mode so QUOTE-escaped comments, including original rollback values
with apostrophes or backslashes, have the same interpretation on a new session.
They change session settings only, never global server configuration.

## Checks, risks, and rollback

The preparation checks compare all eight desired comments byte-for-byte with
the CAPTURES DDL and verify that removing those literals leaves the original
source unchanged. All comment lengths remain within MariaDB's 1024-character
limit. A fresh owned no-network MariaDB 11.8.9 synthetic database returned eight
PASS rows; NO_BACKSLASH_ESCAPES returned eight failures with all generated
commands withheld. These checks executed the read-only generator, not its ALTER
commands. No live metadata or deployment compatibility is claimed. See the
[follow-up evidence](../docs/reconstruction/MM_FOLLOWUP_VERIFICATION_2026-10-31.md).

After authorized installation, rerun the SELECT generator and verify every
current_comment equals desired_comment. The query still returns PASS and can
generate redundant ALTERs when hints already match; matching comments need no
reapplication. Open a fresh data-entry session and inspect the eight hints for
F/R/C/D guidance and retained colour/flag/tag descriptions, without submitting
invented field records. Metadata checks do not prove package cache refresh.

Even INSTANT/LOCK=NONE DDL needs a short metadata lock. Each ALTER commits
separately, so an interrupted application can leave a partial comment update.
Ordinary transaction ROLLBACK does not undo DDL. To restore hints, execute only
the relevant **saved pre-change** rollback_sql values with Stop on error and
the same safeguards; a newly rerun generator captures current comments instead
of recovering old ones. Stop if column metadata has changed since capture.
No biological rows or validator code need restoration.

For repository rollback, revert only these eight COMMENT literals and remove
the two new hint-documentation files if no longer needed. Preserve all other
shared reconstruction, SQL, manual, and test work. No live change is implied by
a repository edit, commit, or merge.
