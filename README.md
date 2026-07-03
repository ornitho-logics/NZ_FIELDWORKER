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
 ┃ ┣ 📂inspectors
 ┃ ┗ 📂artifacts
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
