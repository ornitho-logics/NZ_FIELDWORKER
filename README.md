## FIELDWORKER

__Fieldworker__ is a modular Shiny application for organizing fieldwork.

### Directory structure

```
📦NZ_FIELDWORKER
 ┣ 📂DATABASE
 ┃ ┗ 📜*.SQL
 ┣ 📂DataEntry
 ┃ ┣ 📂OBSERVERS
 ┃ ┣ 📂CAPTURES
 ┃ ┣ 📂EGGS
 ┃ ┣ 📂NESTS
 ┃ ┣ 📂RESIGHTINGS
 ┃ ┣ 📂RESIGHTINGS_PUBLIC
 ┃ ┣ 📂spatial_objects
 ┃ ┗ 📂inspectors
 ┣ 📂gpxui
 ┃ ┣ 📜global.R
 ┃ ┣ 📜server.R
 ┃ ┗ 📜ui.R
 ┣ 📂main
 ┃ ┣ 📂R
 ┃ ┗ 📂www
```

The interface in `main/` is both:

* a landing page that links to the [DataEntry](https://github.com/ornitho-logics/DataEntry) and [gpxui](https://github.com/ornitho-logics/gpxui) interfaces.
* a mapping, viewing, reporting and database-summary interface.

The interfaces outside `main/` are self-contained and can be run independently if needed.

### How to install and run

1. Clone this repo locally.
2. Install the required R packages from the `global.R` files.
3. Get access to a MySQL/MariaDB database.
4. Create the database structure, see `./DATABASE` directory.
5. See [DataEntry](https://github.com/ornitho-logics/DataEntry) on
how to set the database credentials.
6. Run the main app:

```r
shiny::runApp("./main", launch.browser = TRUE)
```

### Updating To-do reports

The current view definitions are in `DATABASE/views.SQL`; the explicit snapshot
build is in `DATABASE/refresh_todo_list_snapshot.SQL`. Deploy the reviewed app
and SQL versions together. Updating the app or downloading a PDF does not
rebuild an existing database snapshot. **Build To-do snapshot** runs the
deployed refresh workflow for the selected reference date. It reports progress
and elapsed time, advises that builds can take up to 20 minutes or longer on a
busy server, and offers Dotterel Finder in a new tab while waiting. Do not start
another build while one is running. Local runtime measurements do not guarantee
the same duration through Adminer on the field server.

`DATABASE/notA_summary.SQL` is a separate, optional view installer. After the
first successful snapshot, select `FIELD_2026_BADOatNZ` in Adminer and execute
the entire small script with **Stop on error** enabled. It creates/replaces
only `notA_summary`, using published nest and parent snapshots. It does not
modify base-table records or add a refresh stage. Install it once; subsequent
successful snapshot builds update its results automatically. A full views
import or extra refresh is unnecessary merely to install this report when a
successful snapshot already exists. Reinstall only if the view definition
changes or the database is rebuilt.

The app's **Show Views → notA_summary** tab replaces View2 and has one row per
historical notA nest, both confirmed parents, separate pending details and
reliable later-nest links. Its scope follows the current BADO/Cass River parent
engine. A stale date or incomplete latest refresh yields no report rows. A
notA nest site is not evidence that its brood died. Rollback is to drop only
the `notA_summary` view and restore the prior tab registration.

Current tagging-note meanings and field restrictions are described in
[Section 8 of the app manual](main/www/field-manual/manual.md#section-8).
Notes containing `tag` receive the existing white map-point outline; that
highlight does not waive the row's conditions. The local save-time validator
protocol remains v1.3.20; the recent task wording/reporting changes do not
require an inspector or external YAML update.

### Project handoffs and Codex transparency

Read [`AGENTS.md`](AGENTS.md) before using Codex or changing database-facing
code. It defines the project's human-control, confidentiality, Git, validation,
and live-database safety rules.

The current specialist handoffs are under
[`notes/codex_proposals/`](notes/codex_proposals/). Start with
[`THREAD1_REPOSITORY_MAP.md`](notes/codex_proposals/THREAD1_REPOSITORY_MAP.md),
then read the handoff for the relevant schema, validator, TODO/PDF/map,
Overview, combo, GEO rollout, field-manual, or local-replay workstream.

[`notes/CODEX_USAGE_TRANSPARENCY.md`](notes/CODEX_USAGE_TRANSPARENCY.md)
documents how Codex was used, which artifacts are tracked, what remains
human-controlled, and why raw prompts, confidential field data, credentials,
coordinates, and private rollout reports are deliberately excluded. Sanitized
prompt/decision summaries are indexed in
[`notes/codex_logs/INDEX.md`](notes/codex_logs/INDEX.md).
