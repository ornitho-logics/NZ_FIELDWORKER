## FIELDWORKER

__Fieldworker__ is a modular Shiny application for organizing fieldwork.

It brings field observations, maps, and daily planning together in one place.
This version supports breeding Banded Dotterel / Pohowera fieldwork in New
Zealand, connecting nest visits, egg measurements, captures, resightings, and GPS
records to help teams decide what to do next.

### What you can do

* **Plan the day's fieldwork.** Download a To-do PDF with task tables and a map
  for the selected reference date, covering nest checks, parent capture and
  resighting, chick banding, photographs, and flagging work.
* **Follow nests and broods on the map.** Explore their latest available
  locations and click a point for parents, association evidence, hatch timing,
  and the time since the last encounter.
* **Review tabular summaries.** Show Views provides To-do data, available
  band combinations, nest records, capture history, and hatching estimates.
* **Enter and check observations.** Dedicated forms support field records.
  Data-entry validators flag missing or inconsistent information and explain
  what needs attention before saving, with warnings for items needing review.
* **Link GPS records.** Upload waypoints and tracks and connect locations to
  the corresponding field observations.
* **Read field procedures.** Open the short Core Team Field Guide or the Full
  Protocol Manual, with English/Deutsch switching, search, and a separate-window
  reader.
* **Review the season.** Overview combines the current phenology panel with
  restored summaries of quotas, lay dates, hatching, nest discovery, band
  combinations, geolocator deployments, chick growth, and resighting histories.

Reports use the app's selected reference date. After entering new records,
**Build To-do snapshot** updates the daily task plan; downloading the PDF alone
does not rebuild it. Builds show progress and offer Dotterel Finder in a new
tab while you wait. Parent-association annotations on the map also use the
latest successful snapshot.

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
* a mapping, viewing, reporting, and database-summary interface.

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

### Further reading

* [Core Team Field Guide](main/www/field-manual/core-guide.md) and
  [Full Protocol Manual](main/www/field-manual/manual.md): the app's field
  procedures, with links between the short and full readers.
* [Manual and Overview restoration](docs/APP_FEATURE_RESTORATION_2026-11-12.md):
  current publication scope, preserved collaborator features, and deployment
  checks. The dated source archives remain available for provenance.
* [notA_summary installation](DATABASE/notA_summary.SQL): a small, separate
  view installer for the historical nest/parent report under Show Views. Install
  after the first successful To-do snapshot; subsequent builds update it.
* [Validator reference and selective editing](docs/validation/SELECTIVE_VALIDATION.md):
  GitHub-only documentation for maintainers, not additional app controls.
* [Database scripts and installation notes](DATABASE/): technical SQL details
  for database maintainers.
* [Reconstruction guide](docs/reconstruction/README.md): setup, verification,
  and a step-by-step agent recipe for adapting the project to another study.
* [Developer guide](notes/codex_proposals/THREAD1_REPOSITORY_MAP.md): repository
  map and links to the specialist handoffs.
* [Contribution and safety rules](AGENTS.md): read before using an AI assistant
  or changing database-facing code. Live changes remain human-controlled.
* [AI-use transparency](notes/CODEX_USAGE_TRANSPARENCY.md) and
  [decision summaries](notes/codex_logs/INDEX.md): how AI assisted development
  and how confidentiality and human review are handled. The public repository
  documents the software; confidential field data and credentials are not
  published here.
