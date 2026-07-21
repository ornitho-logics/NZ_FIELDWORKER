project_root <- normalizePath(
  testthat::test_path("..", ".."),
  mustWork = TRUE
)


app_file <- function(...) {
  file.path(project_root, ...)
}


source_app_file <- function(path, env) {
  suppressPackageStartupMessages(
    source(path, local = env, chdir = TRUE, encoding = "UTF-8")$value
  )
}


dataentry_app_specs <- list(
  CAPTURES = list(
    kind = "append",
    server = "server_append_rows",
    n_empty_lines = 10,
    validation = TRUE
  ),
  EGGS = list(
    kind = "append",
    server = "server_append_rows",
    n_empty_lines = 20,
    validation = TRUE
  ),
  NESTS = list(
    kind = "append",
    server = "server_append_rows",
    n_empty_lines = 10,
    validation = TRUE
  ),
  OBSERVERS = list(
    kind = "edit_table",
    server = "server_edit_table",
    n_empty_lines = 5,
    validation = TRUE
  ),
  RESIGHTINGS = list(
    kind = "append",
    server = "server_append_rows",
    n_empty_lines = 10,
    validation = TRUE
  ),
  RESIGHTINGS_PUBLIC = list(
    kind = "append",
    server = "server_append_rows",
    n_empty_lines = 10,
    validation = TRUE
  ),
  inspectors = list(
    kind = "edit_rcode",
    server = "server_edit_rcode",
    n_empty_lines = 2,
    validation = FALSE,
    id_column = "table_name",
    code_column = "inspector"
  ),
  spatial_objects = list(
    kind = "edit_rcode",
    server = "server_edit_rcode",
    n_empty_lines = 2,
    validation = FALSE,
    id_column = "variable",
    code_column = "value"
  )
)


load_dataentry_app <- function(name) {
  if (!requireNamespace("DataEntry", quietly = TRUE)) {
    stop("The DataEntry package is required to test the DataEntry apps.")
  }

  env <- new.env(parent = globalenv())
  env$prepare_for_dropdown <- function(...) c("Observer A", "Observer B")
  env$shinyApp <- function(ui, server) {
    structure(list(ui = ui, server = server), class = "mock_shiny_app")
  }

  directory <- app_file("DataEntry", name)
  source_app_file(file.path(directory, "global.R"), env)

  list(
    name = name,
    env = env,
    ui = source_app_file(file.path(directory, "ui.R"), env),
    server = source_app_file(file.path(directory, "server.R"), env)
  )
}


load_main_app <- function() {
  env <- new.env(parent = globalenv())
  directory <- app_file("main")

  source_app_file(file.path(directory, "global.R"), env)

  r_files <- list.files(
    file.path(directory, "R"),
    pattern = "[.]R$",
    full.names = TRUE
  )

  for (path in r_files) {
    source_app_file(path, env)
  }

  list(
    env = env,
    ui = source_app_file(file.path(directory, "ui.R"), env),
    server = source_app_file(file.path(directory, "server.R"), env)
  )
}


load_gpxui_wiring <- function() {
  env <- new.env(parent = globalenv())
  calls <- new.env(parent = emptyenv())
  calls$required <- character()
  calls$ui <- 0
  calls$server <- 0

  env$require <- function(package, ...) {
    calls$required <- c(calls$required, as.character(substitute(package)))
    TRUE
  }

  env$gpx_ui <- function() {
    calls$ui <- calls$ui + 1
    shiny::tags$main(id = "gpxui-test-ui", "GPS manager")
  }

  env$gpx_server <- function() {
    calls$server <- calls$server + 1

    function(input, output, session) {
      output$ready <- shiny::renderText("ready")
    }
  }

  directory <- app_file("gpxui")
  source_app_file(file.path(directory, "global.R"), env)

  list(
    env = env,
    calls = calls,
    ui = source_app_file(file.path(directory, "ui.R"), env),
    server = source_app_file(file.path(directory, "server.R"), env)
  )
}


mock_app_globals <- function(values) {
  force(values)

  function(name, default = NULL) {
    if (name %in% names(values)) {
      values[[name]]
    } else {
      default
    }
  }
}


app_globals <- function(env, names) {
  setNames(
    lapply(names, get, envir = env, inherits = FALSE),
    names
  )
}


empty_validation_issues <- function(x, table_name, ...) {
  data.table::data.table(
    rowid = integer(),
    variable = character(),
    reason = character()
  )
}
