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
* **Review the bigger picture.** The Overview dashboard and summary views
  bring together field progress, nest histories, and parent associations,
  including historical nests that are no longer active.
* **Enter and check observations.** Dedicated forms support field records.
  Data-entry validators flag missing or inconsistent information and explain
  what needs attention before saving, with warnings for items needing review.
* **Link GPS records.** Upload waypoints and tracks and connect locations to
  the corresponding field observations.
* **Consult the Field Manual.** Browse or search the app's guide to field
  procedures, data entry, and interpreting the reports.

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

* [Field Manual](main/www/field-manual/manual.md): procedures and guidance for
  field teams, including how to read the To-do PDF and map.
* [Database scripts and installation notes](DATABASE/): technical SQL details
  for database maintainers, including the optional historical nest summary.
* [Reconstruction guide](docs/reconstruction/README.md): setup, verification
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
