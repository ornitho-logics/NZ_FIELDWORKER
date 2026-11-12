# Temporarily pausing data-entry validation

## Current documentation-only selection request — 12 November 2026

Luke requested documentation so Mihai can choose which checks to reinstate
against feedback, without automatically restoring all old validators. Read
[selective validation](SELECTIVE_VALIDATION.md), the
[current catalog](VALIDATOR_CATALOG.md), and the
[original archived groups](ARCHIVED_VALIDATOR_CATALOG.md) first. These are
GitHub documents, not app controls. No check is activated or changed by this PR.
Newer file-first DataEntry uses Mihai's local
`DataEntry/TABLE/inspector.R` before DB definitions, while the older package
used DB-only inspectors. The old pause and guarded restore below apply only to
their reviewed DB state; neither source publication nor an old pause receipt
establishes the currently deployed behavior. No live restore is performed here.

The reviewed validators are preserved, not retired. A temporary validation
pause is an operator decision, not a change to the scientific protocol.
Merging this documentation does not install anything, change the live pause,
or re-enable validators. Field-server changes remain human-applied.

## Preserved original inspectors

The **8 November 2026 archive** contains all twelve approved hard/warning R
exports and their file index, unchanged from source commit
`9574508481a15c5455e94b85259f5da346ca0e6e`:

- [Download the source archive](archives/2026-11-08/inspectors.tar.gz).
- [Archive and per-file checksums](archives/2026-11-08/manifest.json).
- [Browse the immutable source snapshot](https://github.com/ornitho-logics/NZ_FIELDWORKER/tree/9574508481a15c5455e94b85259f5da346ca0e6e/notes/codex_proposals/validator_sandbox/inspector_lists_by_table).
- [Current editable exports](../../notes/codex_proposals/validator_sandbox/inspector_lists_by_table/).

Keep the dated archive and manifest unchanged. A future approved revision
should have its own dated archive. The existing editable exports remain in
their original location; this change neither replaces them with no-ops nor
deletes their code. The archive contains source code, not a field-data dump.
Its manifest pins each path, byte length, SHA-256, and Git blob identity.

These are the repository definitions Luke selected for restoration. They are
not an exact export of the deleted live rows: edits made only on the server,
old comment prefixes, and old timestamps require a separate pre-deletion
backup to recover. In particular, twelve archived export files do not imply
that twelve inspector rows were installed on the server.

## Why an empty inspector table blocks saving

In the inspected DataEntry version `2026.0.0.7`, the execution path is:

1. `inspector_loader()` selects definitions by the actual `table_name`.
2. Missing rows return `list()`; a stored `list()` has the same empty result.
3. `evalidators()` expects `rowid`, `variable`, and `reason` columns. Without
   them, it creates an internal validation issue.
4. `validate_before_save()` blocks saving when that issue is present.

Consequently, deleting inspectors, blanking their code, or using `list()` is
not a working pause. Adding an `active` column alone would not help: the
inspected loader does not filter by such a column. Do not drop or rename the
table, replace it with a view, or change package behavior to bypass this guard.

The [temporary no-check expression](noop_inspector.R) instead returns one
valid issue table with **zero rows**. It examines no entry values. The six
biological entry modules are CAPTURES, EGGS, NESTS, OBSERVERS, RESIGHTINGS, and
RESIGHTINGS_PUBLIC. One temporary no-check inspector per table is sufficient.
The temporary comments explicitly identify these as pause rows, not as the
original hard/warning lists.

## Narrow compatibility repair

[The manual SQL script](../../DATABASE/pause_inspectors_2026-11-08.SQL) repairs
only this reviewed starting state: exactly those six tables, one inspector
row each, every expression exactly `list()`, and every comment SQL NULL.
It is **not** a general installer for pausing arbitrary active rules.

Before using it, the human operator must:

1. Save a fresh database backup and preserve any existing original inspectors.
2. Confirm the selected database, table engine, row contents, and trigger
   visibility. Require InnoDB and no visible inspector triggers; lack of
   trigger visibility is not proof that hidden triggers are absent.
3. Close inspector editors and prevent concurrent edits during installation.
4. Read the entire script and run it in one Adminer SQL command with **Stop on
   error** enabled. It requires autocommit with no existing open transaction.
5. Require `PAUSED_6_VERIFIED` and six receipt rows. Keep the UTC receipt
   privately as the start of the pause interval. Report any error or other
   status without weakening guards or deleting rows.
6. Retry a normal intended entry. Preserve unsaved work before reopening a
   form. Agents must not insert test records into production.

One guarded atomic UPDATE replaces only the six placeholders. It performs
no DDL, INSERT, DELETE, or biological-table update. An unexpected starting
state is left untouched. An exact rerun after success makes no changes.
There is no dependence on `ROW_COUNT()`, which intervening Adminer statements
can invalidate. No views import, app source update, or snapshot rebuild is
required for this inspector-only repair.

The operator reported successful manual installation. This sanitized account
does not publish the execution transcript or private receipt. App-level save
confirmation remains separate from the SQL installation result.

## Limits during the pause

Database constraints, column types, permitted enum values, permissions, and
independent import/editor checks remain active. The pause does not promise
that every possible malformed value can be saved. The inspector and
spatial-object editors have independent structural/code checks and are not
the six biological-entry modules above.

With no reported issues, the current package sets `nov = 0`. During a pause,
that is **not proof that the original validators ran**. Keep a separate
private operator log of the pause start, pause end, and verification status.
Review affected entries after restoring checks; do not silently rewrite
historical `nov` values or change their meaning.

## Restoring checks

Do not just delete the temporary rows: that recreates the save failure.

For the archived restoration set and the exact temporary pause definitions
described above, generate a ready-to-review restore script from the repository
root:

```sh
Rscript --vanilla tools/validation/build_inspector_restore.R tmp/codex/validator-restore/restore_inspectors.SQL
```

The generator requires the project's existing `jsonlite` dependency and either
`shasum` or `sha256sum`. It verifies the pinned archive and all thirteen member
checksums, parses the twelve R expressions, and refuses to overwrite an
existing output file. It writes only into a Git-ignored output folder and
never connects to a database. The complete restored source is embedded in the
generated SQL as UTF-8 hexadecimal literals, avoiding backslash/quote-mode
ambiguity. No twelve-file manual paste is needed.

**When the human decides to resume validation:** save a fresh backup, close
inspector editors, select `FIELD_2026_BADOatNZ`, and run the ENTIRE generated
file in Adminer with Stop on error enabled, including its `DELIMITER` lines.
Require **`RESTORED_12_VERIFIED`** and twelve inspector rows. Preserve unsaved
form entries before reopening forms, and verify normal saving and the return
of intended checks. Do not execute this restore while a pause is still wanted.

The MariaDB anonymous block creates no permanent routine or table. It locks
and checks the exact pause state, restores all twelve definitions in one owned
transaction, verifies complete code hashes and role mapping, and commits only
after verification. SQL errors and warnings roll back its changes and produce
an error. Unknown edits abort unchanged, a pre-existing caller transaction is
not committed or rolled back, and an exact repeat after success is harmless.
Keep database backups: none of this restores unrelated live-only custom rules
or original metadata that was never in the selected archive.

For a different live state or a different approved restoration set, prepare a
new reviewed restore procedure rather than weakening the generated guards:

1. Verify the archive and file checksums against `manifest.json`, and review
   the selected definitions against the current schema and package version.
2. Back up the current inspector table privately. Confirm its exact temporary
   definitions and reject unexpected custom rows or code.
3. Prepare a separately reviewed restore transaction that removes only the
   verified pause rows and inserts the selected original lists together.
   Retain complete code, not just the filename or an abbreviated expression.
4. Use the actual biological `table_name`, such as `CAPTURES`, never
   `CAPTURES_hard`. Distinguish hard and warning rows using comments ending
   in `hard` and `warn`, respectively. Preserve original comment prefixes
   when available; label reconstructed metadata honestly when unavailable.
5. Verify expected counts, table/role mapping, and complete code before
   committing. Roll back any failed verification. The archived OBSERVERS
   warning export is an empty list; it is not a standalone no-check fix and
   must not be installed without its corresponding nonempty hard list.
6. Verify a normal save and the return of intended validation through an
   approved procedure. Record the pause end privately. No automatic restore
   execution, deployment, or biological-data rewrite is authorized by this
   documentation.

## Reproducible local check

From the repository root, with DataEntry and its existing dependencies installed:

```sh
Rscript --vanilla tools/validation/check_inspector_pause.R
```

The focused check uses invented rows, the installed loader/parser/save-gate
bodies, and private DB-read stubs. It starts no app, opens no database
connection, and changes no package namespace. It tests the empty-table and
`list()` failures, the valid no-check payload, multi-row composition, and the
existing `nov` behavior. It also parses the twelve current exports without
evaluating their rules. The inspected version passed 118 checks; that result
does not establish compatibility with every deployed package version.

The pause and generated restore passed twelve focused round-trip checks in an
isolated, no-network MariaDB 11.4.2 instance, including injected-error and
injected-warning rollback. See [verification and its limits](VERIFICATION.md).
The operator's server is a different version; no browser rehearsal or agent
connection to the field server is claimed. The SQL follows
[MariaDB's UPDATE documentation](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/changing-deleting-data/update)
and [compound-statement documentation](https://mariadb.com/docs/server/reference/sql-statements/programmatic-compound-statements/using-compound-statements-outside-of-stored-programs).
Detailed validation authority remains in the
[validation handoff](../../notes/codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md).
