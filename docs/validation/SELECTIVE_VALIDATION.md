# Restoring and selectively maintaining validation

This guide is for Mihai and other maintainers working in GitHub. It adds no
settings screen, switches, or other controls to the rendered app. Luke requested
maintainer documentation on 12 November 2026, so Mihai can choose individual
checks against user feedback. No check is reinstated, disabled, or changed by
this PR; the current per-app lists and original archives are preserved.
Publishing source does not confirm which package or inspector definitions are
currently installed on the field server.

## Find the check reported by a user

Use the searchable [current validator catalog](VALIDATOR_CATALOG.md) or its
[machine-readable counterpart](validator_catalog.json). For the original paused
rules, use the [archived validator catalog](ARCHIVED_VALIDATOR_CATALOG.md) or its
[JSON inventory](archived_validator_catalog.json): 186 named groups in the twelve
original hard/warning exports. Original groups can contain several conditions;
they do not map one-to-one to Mihai's newer IDs. Archive source links are pinned
to the verified original commit, and every export is checked against its manifest.

The current catalog inventories all 265 checks in the six biological entry modules:

| Table | Checks |
| --- | ---: |
| CAPTURES | 98 |
| EGGS | 26 |
| NESTS | 53 |
| OBSERVERS | 6 |
| RESIGHTINGS | 57 |
| RESIGHTINGS_PUBLIC | 25 |

Each entry has a table-qualified ID, descriptive heading, source-line link,
and example literal messages. For example, `CAPTURES:val3` means
`DataEntry/CAPTURES/inspector.R`, `try_validator(nam = "val3")`: the first-chick
nest/brood requirement. `OBSERVERS:val1` is a different check, covering observer
code format. IDs are local to their table, not globally unique. Preserve existing
IDs when editing; gaps in numbering are not errors, and should not be renumbered.
One ID can cover several related conditions. Follow the complete source rather
than treating each listed message as a separate independently switchable rule.

Ask users for the form/table, exact message, field, and intended exception.
Use an invented example in GitHub; do not post confidential records, screenshots
containing private data, credentials, or precise field locations.

## First establish which loader the deployment uses

There are two versions of the workflow, and they must not be confused:

| Deployment | Source that controls checks | Effect of old DB pause rows |
| --- | --- | --- |
| Newer file-first DataEntry, with a local `inspector.R` | That module's local file takes precedence. A nonempty literal list evaluates its checks. | They are not consulted for that module. |
| Older DB-only DataEntry, or newer loader without a local file | `inspectors` rows selected for the actual biological table. | The six temporary no-check rows continue the pause. |

The inspected upstream DataEntry 1.2.1 implementation at
[`9cade6e`](https://github.com/ornitho-logics/DataEntry/blob/9cade6ee70dbfc415dcbb8fe62e1e1b91dd50cae/R/validation-eval.R)
checks for `inspector.R` before consulting the DB. Its empty-list combiner also
differs from the older version. The local development installation inspected
for this task was 2026.0.0.7 and remained DB-only; it was not upgraded.
Neither observation proves which package the field server runs.

Mihai's current repository adds nonempty local inspector lists for all six
biological forms, plus the necessary data.table/stringr imports. This PR retains
those files unchanged. Do not overwrite them with the older archived exports or
run a database restore merely because an old pause receipt exists.

The human maintainer can inspect the installed loader on the deployment host
without reading records or credentials:

```r
packageVersion("DataEntry")
body(getFromNamespace("inspector_loader", "DataEntry"))
```

Also check that the module runs with its own app directory as the working
directory: the newer loader checks `inspector.R` relative to that directory.
Check the actual loader body, not a version number alone.

## Choose what to reinstate, rather than restoring everything

1. Search the archived catalog by the reported condition or original group name,
   then read its complete source. The JSON includes all literal messages collected
   from the group, while the Markdown shows up to three examples.
2. Search the current catalog for the same field or condition. Check whether
   Mihai already implements it, split it across several IDs, relaxed it, or left
   it out. Similar labels are hints, not proof of equivalent logic.
3. Record a short decision for each proposed change: original group/source,
   current table and ID(s), the specific condition to retain or relax, feedback
   summarized without real records, intended save behavior, approver, and tests.
4. If a desired check is absent, port only that reviewed condition into a
   separate branch against the current per-app file. Review its schema, field
   names, required lookups, wrappers, and package behavior. Do not paste an
   entire archived export over Mihai's file or renumber his existing rules.
5. Test with invented pass, fail, and edge cases. Have the human maintainer
   deploy the selected change and compatible package, preserving unsaved entries
   before restarting/reopening forms. Verify an intended save without submitting
   test records to the field database.
6. Keep the original archive unchanged and retain the review commit for a narrow
   rollback. No SQL import or blanket validator activation is part of this PR.

The old [guarded DB restoration guide](README.md#restoring-checks) remains as
historical operational documentation. Its generator restores all twelve old
exports only over the exact six reviewed DB pause rows; it is **not** a selective
migration into the newer per-app setup and is not the recommended action here.
Do not run it merely because the old pause receipt exists.

In the legacy DB arrangement, use the actual table name and the final
`hard` or `warn` token in `inspectors.comments` to identify a list. Those
role labels are not individual check IDs and are not automatic severity
switches. The newer per-app list has no hard/warn selector introduced by this
PR. Inspect the deployed save gate before promising that a check is non-blocking.

## Disable one file-based check, without losing its source

1. Start a reviewed branch from current main. Find the table-qualified ID,
   exact heading, source span, and user-visible condition in the catalog.
2. Record why the check is too strict, the intended exception, who approved the
   decision, and how it will be reviewed. Prefer a narrow rule correction when
   the underlying protocol still applies. Do not disable related checks by guess.
3. If temporary disabling is approved, keep the heading and existing `nam`
   label, but replace that wrapper's evaluated argument with this typed no-issue
   result. Preserve the complete original expression in Git and record the
   disabling commit so it can be restored precisely:

   ```r
   data.table::data.table(
     rowid = integer(),
     variable = character(),
     reason = character()
   )
   ```

   Change only that argument, not the entire list or every occurrence of a
   message. Leave the surrounding `try_validator(..., nam = "existing ID")`
   and list separators valid. Do not change a rule's role comment and assume it
   is disabled; do not delete the whole `inspectors` table.
4. Review [Data issues](../../main/R/data_issues.R). It reuses a selected set of
   these same expressions, identified by their headings. Changing a heading,
   removing an expression, or turning its body into a no-op may also disable
   that post-save check or report it unavailable. Keeping a check for post-save
   review while removing it from saving requires a separately reviewed change;
   this documentation does not introduce such routing.
5. Parse the edited file and run focused invented-input checks: intended pass,
   intended failure, and an edge case. Confirm unrelated checks still run and
   saving is not blocked by a malformed definition. Keep the required zero-row
   columns even if every check is disabled; older DataEntry versions reject
   `list()` or absent definitions.
6. Regenerate both catalogs, inspect the diff, and have the human deploy only
   the reviewed change. Restore the original rule with a focused revert when
   feedback is resolved, retaining later unrelated edits.

No check has been selected for disabling in this PR. Its purpose is to make
each current check understandable and its future changes traceable.

## Keep all four catalogs current

From the repository root:

```sh
Rscript --vanilla tools/validation/build_validator_catalog.R --check
```

The generator parses code without evaluating it. It records existing IDs,
headings, positions, literal messages, and source MD5s; these MD5s are drift
checks, not a security guarantee. To regenerate the current catalog, use `--markdown` and
`--json`. Use `--archived-markdown` and `--archived-json` for the original
inventory. Review and update the corresponding Markdown/JSON pair together.
If an editable legacy export has diverged from the pinned archive, generation
stops rather than silently describing it as the original; recover the original
source from the checked archive before rebuilding that inventory.
The immutable original archive remains unchanged.
