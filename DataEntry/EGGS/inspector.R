

#' source("./DataEntry/EGGS/global.R")
#' source("./DataEntry/EGGS/inspector.R")
#'
#' dat = DBq('SELECT * FROM EGGS')
#' class(dat) = c(class(dat), 'EGGS')
#' ii = inspector(dat)
#' evalidators(ii)




inspector.EGGS <- function(dat, ...){  

x  = copy(dat)
x[, rowid := .I]


list(

  # Mandatory values
    x[, .(species, observer, date, time_visit, nest_id, egg1_float_angle, egg1_float_surface, egg1_float_location, egg2_float_angle, egg2_float_surface, egg2_float_location, egg3_float_angle, egg3_float_surface, egg3_float_location, egg4_float_angle, egg4_float_surface, egg4_float_location, rowid)] |>
      is.na_validator() |>
      try_validator(nam = 1)
  ,

  # Float angles 
      x[, .(egg1_float_angle,egg2_float_angle,egg3_float_angle,egg4_float_angle, rowid)] |>
    interval_validator(
      v = fread("    
            variable         lq     uq
            egg1_float_angle  20    90
            egg2_float_angle  20    90
            egg3_float_angle  20    90
            egg4_float_angle  20    90
            "),
      reason = "Out of range values."
    )|> try_validator(nam = "float angle")
  ,

  # Float surfaces 
      x[, .(egg1_float_surface,egg2_float_surface,egg3_float_surface,egg4_float_surface, rowid)] |>
    interval_validator(
      v = fread("    
            variable          lq     uq
            egg1_float_surface  0     4
            egg2_float_surface  0     4
            egg3_float_surface  0     4
            egg4_float_surface  0     4
            "),
      reason = "Out of range values."
    )|> try_validator(nam = "float surface")
  ,

  # Float location 
    {
    z = x[, .(
      egg1_float_location,
      egg2_float_location,
      egg3_float_location,
      egg4_float_location,
      rowid
    )]

    v = data.table(
      variable = names(z)[-which(names(z)=='rowid')],
      set = c(
        list(c("bottom", "suspended", "surface")), 
        list(c("bottom", "suspended", "surface")), 
        list(c("bottom", "suspended", "surface")), 
        list(c("bottom", "suspended", "surface"))

      )
    )

    is.element_validator(z, v)
    } |> try_validator(nam = "float location")




)}