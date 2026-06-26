TABLE_show <- function(x, session) {
  DT::renderDataTable(
    {
      get_data <- reactivePoll(
        5000,
        session = session,
        checkFunc = function() {
          dbtable_is_updated(x)
        },
        valueFunc = function() {
          if (is.character(x)) {
            return(showTable(x))
          } else {
            return(x)
          }
        }
      )
      get_data()
    },
    server = FALSE,
    rownames = FALSE,
    escape = FALSE,
    selection = "none",
    extensions = c("Scroller", "Buttons"),
    options = list(
      dom = "Blfrtip",
      buttons = list(
        "copy",
        list(
          extend = "collection",
          buttons = "excel",
          text = "Download"
        )
      ),
      scrollX = "600px",
      deferRender = TRUE,
      scrollY = 900,
      scroller = TRUE,
      searching = TRUE,
      columnDefs = list(
        list(className = "dt-center", targets = "_all")
      )
    ),
    class = c("compact", "stripe", "order-column", "hover")
  )
}

ErrToast <- function(msg) {
  bs4Dash::toast(
    title = "Oops!",

    body = msg |> a(class = "text-primary font-weight-bold") |> h5(),

    options = list(
      autohide = FALSE,
      close = TRUE,
      position = "topRight",
      icon = "fa-solid fa-face-sad-tear"
    )
  )
}

WarnToast <- function(msg) {
  bs4Dash::toast(
    title = "Hi!",

    body = msg |> a(class = "text-primary font-weight-bold") |> h4(),

    options = list(
      delay = 10000,
      autohide = TRUE,
      close = TRUE,
      position = "bottomRight",
      icon = "fa-solid fa-face-sad-tear"
    )
  )
}

startApp <- function(labels, hrefs, classes = "btn-primary bttn-primary") {
  classes <- rep(classes, length.out = length(labels))

  o <- glue(
    '
      <a href="{hrefs}" target="blank"
        class="btn btn-sm {classes} bttn bttn-fill bttn-md bttn-no-outline"
        role="button">
        <h4>{labels}</h4>
      </a>
    '
  ) |>
    glue_collapse()

  div(
    HTML(o),
    class = "d-grid gap-3 mx-auto mr-3"
  )
}

HR <- function() {
  a(hr(style = "border-top: 1px solid #9aaeb6;"))
}

S <- function(x = "-------", z = 1) {
  v <- str_split(x, ":", simplify = TRUE)
  if (length(v) == 2) {
    v <- glue("{em(v[1])}:{v[2]}")
  }
  v <- HTML(v)

  switch(
    z,
    "1" = strong(v, style = "color:#1d3658"),
    "2" = strong(v, style = "color:#d70427"),
    "3" = strong(v, style = "color:#ffb6a3"),
    "4" = strong(v, style = "color:#e8c468"),
    "5" = strong(v, style = "color:#b8d2ff")
  )
}

# box title style
bttl <- function(text, color = "#8a2d02", weight = "bold", icon = NULL) {
  icon_html <- if (!is.null(icon)) {
    sprintf("<i class='fas fa-%s'></i> ", icon)
  } else {
    ""
  }
  HTML(sprintf(
    "<span style='font-weight: %s; color: %s; '>%s%s</span>",
    weight,
    color,
    icon_html,
    text
  ))
}


select_combo_list <- function() {
  DBq(
    "SELECT DISTINCT UL, LL, UR, LR FROM CAPTURES where tag_id is not NULL"
  ) |>
    make_combo(short = "LR")
}


spinner <- function(x) {
  shinycssloaders::withSpinner(
    x,
    image = 'animated_ICO.png',
    image.width = "100cqw"
  )
}


ref_date_message <- function(refdate) {
  ago <- round(Sys.Date() - as.Date(refdate))

  if (ago == 0) {
    return(glue(
      "Reference date: {S(refdate, 1)} today. <i>Todo-s are for tomorrow!</i>"
    ))
  }

  if (ago > 0) {
    return(glue("Reference date: {S(refdate, 2)} {abs(ago)} days ago."))
  }

  glue("Reference date: {S(refdate, 2)} {abs(ago)} days from now.")
}


# download handlers
download_gt_pdf <- function(filename, table) {
  shiny::downloadHandler(
    filename = filename,
    content = function(file) {
      gt::gtsave(
        data = table(),
        filename = file
      )
    }
  )
}
