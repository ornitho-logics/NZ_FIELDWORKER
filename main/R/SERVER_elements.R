
ErrToast <- function(msg){
  toast(
    
    title = "Moin!",
    
    body = msg |> a(class = "text-primary font-weight-bold") |> h4(),
        
    options = list(
      autohide = FALSE,
      close    = TRUE,
      position = "topLeft",
      icon     = "fa-solid fa-face-sad-tear"
    )
  
  )


}

WarnToast <- function(msg){
  toast(
    
    title = "Moin!",
    
    body = msg |> a(class = "text-primary font-weight-bold") |> h4(),
        
    options = list(
      delay    = 10000,
      autohide = TRUE,
      close    = TRUE,
      position = "bottomRight",
      icon     = "fa-solid fa-face-sad-tear"
    )
  
  )


}

WaitToast <- function(msg) {
  toast(
    title = NULL,
    body = paste('<i class="fa-solid fa-hourglass-start"></i>', msg) |>
          HTML() |>
          h5()  ,
    options = list(
      autohide = TRUE,
      close    = FALSE,
      fade     = TRUE,
      delay    = 6000, 
      position = "topRight"
    )
  )
}

startApp <- function(labels, hrefs) {

  o = glue('
      <a  href="{hrefs}" target = "blank" 
        class="btn btn-sm btn-primary bttn bttn-fill bttn-md bttn-primary bttn-no-outline" role="button" >
        <h4> {labels} </h4>
      </a>
    ') |>
    glue_collapse()

  div(
    HTML(o),
    class = "d-grid gap-3 mx-auto mr-3"
  )

  
}


TABLE_show <- function(table_nam, session) {
  DT::renderDataTable({
    oi = shiny::getCurrentOutputInfo()
    wid = oi$outputId

    w = waiter::Waiter$new(
      id   = wid,
      html = tagList(waiter::spin_fading_circles(), h5(sprintf("Loading %s…", table_nam))),
      color = "#ffffff"
    )
    w$show()
    on.exit(w$hide(), add = TRUE)

    get_data = reactivePoll(
      5000, session,
      checkFunc = function() dbtable_is_updated(table_nam),
      valueFunc = function() {
        DBq(glue("select * FROM {table_nam}"))[, ":="(pk = NULL, nov = NULL)] |>
          data.frame()
      }
    )
    get_data()
  },
  server        = FALSE,
  rownames      = FALSE,
  escape        = FALSE,
  extensions    = c("Scroller", "Buttons"),
  options       = list(
    dom         = "Blfrtip",
    buttons     = list("copy", list(extend = "collection", buttons = "excel", text = "Download")),
    scrollX     = "600px",
    deferRender = TRUE,
    scrollY     = 900,
    scroller    = TRUE,
    searching   = TRUE,
    columnDefs  = list(list(className = "dt-center", targets = "_all"))
  ),
  class = c("compact", "stripe", "order-column", "hover"))
}
