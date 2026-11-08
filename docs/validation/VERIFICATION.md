# Validation pause/restoration verification

Date: 8 November 2026. This is a sanitized verification summary, not a live
database export, execution transcript, or deployment instruction.

## Source preservation

- All twelve reviewed inspector R files and FILE_INDEX.txt were archived
  from commit `9574508481a15c5455e94b85259f5da346ca0e6e`.
- Every extracted member matched the SHA-256 and byte length in the archive
  manifest. No original inspector file was edited.
- The restoration generator pins the archive checksum, verifies all members,
  parses the R expressions without evaluating the rules, and writes no DB.

## In-memory package check

`Rscript --vanilla tools/validation/check_inspector_pause.R` passed 118 checks
with installed DataEntry `2026.0.0.7`. It used invented rows and private
DB-read stubs around the actual loader, parser, issue combiner, and save gate.
No app, DB connection, field dump, credentials, or biological records were used.
It reproduced the empty-table and `list()` failures, accepted the exact
no-check payload, verified multi-row composition, checked `nov` behavior,
and parsed the twelve original exports without evaluating their rules.

## Isolated MariaDB round trip

A newly initialized MariaDB `11.4.2` instance used its own datadir, explicit
Unix socket, disabled TCP networking, disabled name resolution, and
`--no-defaults`. The runner verified the owned datadir, socket, and disabled
networking before any mutation. Only a synthetic `inspectors` table was used.
The local runner used the published pause SQL and the generator's actual
restore output, including the complete archived source literals.

All twelve focused cases passed:

1. Pause six invented `list()` placeholder rows.
2. Repeat the pause without changing the already-paused state.
3. Restore all twelve archived inspector definitions.
4. Match every restored definition's SHA-256 to its archive member.
5. Repeat restoration harmlessly.
6. Inject an SQL exception after deleting pause rows; retain the original six
   pause rows, including their code, comments, and timestamps, after rollback.
7. Inject an SQL warning at the same point; roll back and surface an error.
8. Reject an unexpected extra inspector without changes.
9. Reject the wrong selected database without changes.
10. Reject a modified pause row without changes.
11. Reject an existing caller transaction without rolling back its pending edit.
12. Confirm the caller can roll back that edit to its prior synthetic state.

The initial warning-injection test showed that re-signalling a warning did
not produce an error exit. The generator was tightened to roll back warnings
and raise an explicit exception, and the full twelve-case suite passed again.
Raw local reports and generated SQL remain ignored, not committed.

## Compatibility and deployment limits

The isolated SQL test was MariaDB **11.4.2**, not the operator's reported
11.8.9. Adminer 5.4.2's official SQL-command parser was inspected for
`DELIMITER` handling; no Adminer browser round trip was performed for this
change. Database privileges, hidden triggers, server limits, UI behavior,
and other deployed package versions still require operator verification.

Luke reported that the narrowly guarded pause was manually applied and its
SQL receipt verified. The agent did not connect to the field server. App save
confirmation and live restoration are separate checks and are not claimed.
Merging the branch neither changes live validation state nor restores rules.

For intended use, archive download, safety guards, and human-operated restore
steps, see [the guide](README.md).
