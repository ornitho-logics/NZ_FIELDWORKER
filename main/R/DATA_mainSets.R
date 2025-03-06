# NOTE: subsets are done when mapping

# TODO

#' n = NESTS()
NESTS <- function() {
  # last state
  n = DBq('SELECT * FROM NESTS')

  n[, let(lat = -43.748691, lon = 172.385441)]

  setorder(n, nest_id)
  
  n
}

#' ns = subsetNESTS(NESTS(), state = input$nest_state, sp = input$nest_species, d2h = input$days_to_hatch)
#' Keep the subset separated from NESTS() so that N() is loaded only once. Subset is done through input$
subsetNESTS <- function(n, state, sp, d2h = 100) {
  
  # n = n[!is.na(lat)]
  
  # subsets
  if (!missing(state) | !is.null(state)) {
    n= n[last_state %in% state]
  }

  if (!missing(sp) | !is.null(sp)) {
    n= n[species %in% sp]
  }

  # if (!missing(d2h) | !is.null(d2h)) {
  #   n = n[days_till_hatching <= d2h | is.na(days_till_hatching)]
  # }
  
  n

}