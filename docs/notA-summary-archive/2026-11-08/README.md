# Archived notA summary — 8 November 2026

**Current publication — 12 November 2026:** Luke requested restoration of
`notA_summary`. The installer is copied unchanged to
[`DATABASE/notA_summary.SQL`](../../../DATABASE/notA_summary.SQL), and its app
registration, help, and snapshot watch list are restored. The default reference
reconstruction again installs it after snapshot publication. This archive and
its manifest remain dated provenance; withdrawal instructions below are
historical. See the [restoration record](../../APP_FEATURE_RESTORATION_2026-11-12.md).

Luke requested removal of `notA_summary` from the app. Its Show Views tab,
explanatory text, and source watch list are removed. The unchanged
[SQL definition](notA_summary.SQL) and [provenance manifest](manifest.json)
are preserved here, outside the active `DATABASE/` installation directory.
This archive contains source code only, not field records or query results.

The report historically joined published nest/parent snapshots, distinguished
confirmed parents from pending or ambiguous evidence, and linked later nests
only through qualified individual identities. Those rules and source bytes
remain available for review. The archived SQL header describes the historical
installation and rollback workflow; it is not an instruction to execute either
against the current field server.

No DROP VIEW or biological-data change was performed. An already-installed
database view remains on the server unless a human separately approves and
performs a database change. App withdrawal requires no Adminer import or
snapshot refresh. Existing task snapshots and their association logic remain.

The reconstruction bootstrap no longer installs or queries this withdrawn
optional report by default. Its historical tests read the archived source;
database fixture/DDL tests still require a separately approved disposable
instance and are not run as part of source-only withdrawal checks.

To restore later, first obtain explicit approval, verify the source checksum,
and review compatibility with the then-current snapshot schema. On a reviewed
branch, restore the installer to its original path, reintroduce only its app
registration/help/watch fragments from the pinned source commit, and update
relevant tests and reconstruction choices. Do not overwrite whole shared app
files or silently enable it in every new-study setup. Human approval and
deployment remain separate from Git publication.

The original app UI/global fragments are retained in the
[Overview context archive](../../overview-archive/2026-11-08/overview-source.tar.gz)
and in the manifest's source commit. Other Show Views outputs, raw tables,
To-do tasks, maps, inspector archives, and reconstruction resources remain.

See the [combined withdrawal verification](../../APP_FEATURE_WITHDRAWAL_2026-11-08.md)
for the source checks, archive checksums, and test limits.
