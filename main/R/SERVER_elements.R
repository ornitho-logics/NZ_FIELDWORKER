
TABLE_show <- function(x, session) {
  DT::renderDataTable({
    get_data <- reactivePoll(5000, 
      session   = session,
      checkFunc = function() {
        
        dbtable_is_updated(x)
      
      },
      valueFunc = function() {
        
        if(is.character(x)){
          return(showTable(x))
        } else return(x)
  
      }
    )
    get_data()
  },
  server        = FALSE,
  rownames      = FALSE,
  escape        = FALSE,
  selection     = "none", 
  extensions    = c("Scroller", "Buttons"),
  options       = list(
    dom         = "Blfrtip",
    buttons     = list("copy", list(
      extend  = "collection",
      buttons = "excel",
      text    = "Download"
    )),
    scrollX     = "600px",
    deferRender = TRUE,
    scrollY     = 900,
    scroller    = TRUE,
    searching   = TRUE,
    columnDefs  = list(
      list(className = "dt-center", targets = "_all")
      )
  ),
  class = c("compact", "stripe", "order-column", "hover")
  )

}
  

ErrToast <- function(msg){
  bs4Dash::toast(
    
    title = "Oops!",
    
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
  bs4Dash::toast(
    
    title = "Hi!",
    
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
