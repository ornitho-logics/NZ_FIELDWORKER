# NOTE: subsets are done when mapping


#' n = NESTS()
NESTS <- function() {

  gps = DBq(glue('SELECT n.gps_id, n.gps_point, CONCAT_WS(" ",n.date,n.time_visit) datetime_found, n.nest_id, lat, lon
                  FROM NESTS n JOIN GPS_POINTS g on n.gps_id = g.gps_id AND n.gps_point = g.gps_point
                    WHERE n.gps_id is not NULL ') )
  gps[, datetime_ := as.POSIXct(datetime_found)]
  gps = gps[, .(lat = mean(lat), lon = mean(lon), datetime_found = min(datetime_found)), .(nest_id)]


  setorder(gps, nest_id)
  
  gps
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