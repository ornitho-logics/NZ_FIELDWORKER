
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

# the last element of ...  can have length > 1
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
