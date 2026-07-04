TABLE_show <- function(x, session, watch = x) {
  DT::renderDataTable(
    {
      get_data <- reactivePoll(
        5000,
        session = session,
        checkFunc = function() {
          dbtable_is_updated(watch)
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
      scrollX = TRUE,
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
      <a href="{hrefs}" target="_blank" rel="noopener noreferrer"
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

spinner <- function(x) {
  shinycssloaders::withSpinner(
    x,
    image = 'animated_ICO.png',
    image.width = "100cqw"
  )
}


# download handlers
download_with_feedback <- function(session, output_id, expr) {
  on.exit(
    session$sendCustomMessage("download-ready", output_id),
    add = TRUE
  )

  force(expr)
}


download_stamp <- function(time = Sys.time()) {
  paste0(
    as.integer(format(time, "%m")),
    format(time, "%d%H%M")
  )
}


download_filename <- function(prefix, ext, time = Sys.time()) {
  glue("{prefix}_{download_stamp(time)}.{ext}")
}


download_gt_pdf <- function(filename, table, session, output_id) {
  shiny::downloadHandler(
    filename = function() {
      if (is.function(filename)) {
        filename()
      } else {
        filename
      }
    },
    content = function(file) {
      download_with_feedback(
        session,
        output_id,
        gt::gtsave(
          data = table(),
          filename = file
        )
      )
    }
  )
}
