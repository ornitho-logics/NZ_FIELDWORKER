# Archived field manuals — 8 November 2026

At Luke Eberhart-Hertel's request, the Field Manual panel and both manuals
were withdrawn from the app. This archive preserves the full reference and
core guide in English and German, without changing their content, attribution,
AI-use disclosure, or scientific descriptions. It is retained reference
material, not an active app publication or proof of current field instructions.

## Preserved material

| Document | English source | German source | Archived HTML |
| --- | --- | --- | --- |
| Core Team Field Guide | [core-guide.md](readers/core-guide.md) | [core-guide-de.md](readers/core-guide-de.md) | [English](readers/core-guide.html), [German](readers/core-guide-de.html) |
| Full Protocol Manual | [manual.md](readers/manual.md) | [manual-de.md](readers/manual-de.md) | [English](readers/index.html), [German](readers/index-de.html) |

The styles, search/navigation JavaScript, original reader README, and
[renderer](render_field_manual.R) are also preserved. The README inside
`readers/` describes the historical publication layout; use this page for
the current archive and restoration instructions.

[manifest.json](manifest.json) records each of the twelve files' original
path, archive path, byte length, SHA-256, MD5, and Git blob identity. All files
were moved byte-for-byte from source commit
`d8d20fb56c3d57a77256063de127cc6f613f2372`. The original content remains
recoverable through this archive and Git history. Do not edit this dated
snapshot; a future reviewed version should have its own source and date.

This archive is outside `main/www`, so Shiny does not expose it as an app
resource. GitHub copies remain deliberately available for inspection and
reconstruction.

## What changed and what did not

- The sidebar item, manual tab, separate-window link, and iframe were removed.
- The eleven reader assets were moved out of the public app directory.
- The renderer was moved out of `main/tools`; it cannot accidentally rebuild
  app assets through its old command. Its unchanged path assumptions describe
  the historical layout, so do not run it directly from the archive.
- Focused tests still check the archived procedures, translation freshness,
  deterministic HTML generation, and preserved bytes. Temporary test fixtures
  mirror the original layout without starting Shiny or reading a database.
- Reconstruction rules now resolve manual anchors against the archive. The
  reconstruction kit, validator archive, scientific rules, SQL, and other app
  panels remain available and unchanged in behavior.

## Human-controlled deployment

Merging is not deployment. Update the app through the normal human-controlled
deployment process. Ensure the former `main/www/field-manual/` files are
actually removed from the deployed public directory: an overlay copy that
leaves old files behind would leave their direct URLs reachable. Preserve any
server-side custom files before making targeted removals. Do not remove the
whole `www` directory or change unrelated panels.

Restart/reload the Shiny app through the normal deployment procedure, then
reload client sessions to remove the old navigation from existing
sessions. Existing open pages, downloaded copies, browser caches, and GitHub
history are not recalled or erased by this change. The current service worker
does not precache manual HTML or store navigation responses, so its offline
policy is not changed. No SQL import, inspector change, or snapshot rebuild
is needed to remove the app manuals.

## Restoring app publication, if explicitly requested later

1. Start a new reviewed branch from the then-current main. Verify archive
   checksums against the manifest before using its contents.
2. Copy each file back to its exact `original_path` from the manifest. Preserve
   source bytes and section anchors unless separate content changes are approved.
3. Review the manual sidebar item and tab fragment in `main/ui.R` at the pinned
   source commit. Reapply only those fragments to the current UI; do not replace
   the whole UI file or discard later collaborator changes.
4. Rebuild all four HTML readers using the restored renderer only after any
   translation/source checks have passed. Update tests to match the newly
   approved publication state, and verify links and absence of private content.
5. Obtain human approval for merge and deployment. Restoring repository files
   alone does not publish them to the field server or change validation policy.

## Checks

From the repository root, within an approved database-free testing scope:

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-field-manual.R", stop_on_failure = TRUE)'
```

No app startup, field dump, database access, or live deployment is part of
these checks. The [reconstruction guide](../../reconstruction/README.md) remains
the entry point for adapting the project to another study; it does not grant
permission to republish these manuals automatically.

See the [combined withdrawal verification](../../APP_FEATURE_WITHDRAWAL_2026-11-08.md)
for the focused checks and limits covering manuals, Overview, and notA reports.
