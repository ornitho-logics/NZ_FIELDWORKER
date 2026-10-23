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
