TABLE_show <- function(x, session, view = FALSE) {
  get_data <- reactivePoll(
    10000,
    session = session,
    checkFunc = function() {
      if (view) {
        return(dbview_is_updated(x))
      }

      dbtable_is_updated(x)
    },
    valueFunc = function() {
      if (is.character(x)) {
        return(showTable(x))
      }

      x
    }
  )

  DT::renderDataTable(
    {
      o <- get_data()

      if ("error" %in% names(o)) {
        validate(need(FALSE, o$error[1]))
      }

      o
    },
    server = FALSE,
    rownames = FALSE,
    escape = FALSE,
    selection = "none",
    filter = 'top',
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
  toast(
    title = NULL,
    body = msg |> a(class = "text-primary font-weight-bold"),

    options = list(
      autohide = FALSE,
      close = TRUE,
      position = "topRight"
    )
  )
}

WarnToast <- function(msg) {
  toast(
    title = NULL,
    body = msg |> a(class = "text-primary font-weight-bold"),

    options = list(
      delay = 30000,
      autohide = TRUE,
      close = TRUE,
      position = "topRight"
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
  withSpinner(
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
  glue("{as.integer(format(time, '%m'))}{format(time, '%d%H%M')}")
}


download_filename <- function(prefix, ext, time = Sys.time()) {
  glue("{prefix}_{download_stamp(time)}.{ext}")
}


# UI theme
fieldworker_theme <- create_theme(
  bs4dash_vars(
    body_bg = "#f8fafc",
    body_color = "#1f2933",
    border_color = "#d8e1e8",
    card_bg = "#ffffff",
    card_cap_bg = "#f3f7fa",
    card_border_color = "#d8e1e8",
    card_shadow = "0 0.35rem 1rem rgba(15, 23, 42, 0.08)",
    input_bg = "#ffffff",
    input_color = "#1f2933",
    input_border_color = "#cbd5e1",
    input_focus_border_color = "#2f6fa3",
    input_placeholder_color = "#64748b",
    link_color = "#2f6fa3",
    link_hover_color = "#1d3658",
    main_header_bottom_border_color = "#d8e1e8",
    navbar_light_active_color = "#1d3658",
    navbar_light_color = "#334155",
    navbar_light_hover_color = "#1d3658",
    table_border_color = "#e2e8f0",
    table_head_bg = "#eef3f5",
    table_head_color = "#1f2933",
    text_muted = "#64748b"
  ),
  bs4dash_layout(
    main_bg = "#f8fafc",
    content_padding_x = ".65rem",
    content_padding_y = ".65rem"
  ),
  bs4dash_sidebar_light(
    bg = "#ffffff",
    color = "#334155",
    hover_bg = "#eef6fb",
    hover_color = "#1d3658",
    active_color = "#1d3658",
    submenu_bg = "#f8fafc",
    submenu_color = "#475569",
    submenu_hover_bg = "#eef6fb",
    submenu_hover_color = "#1d3658",
    submenu_active_bg = "#e2eff7",
    submenu_active_color = "#1d3658",
    header_color = "#64748b"
  ),
  bs4dash_status(
    primary = "#2f6fa3",
    secondary = "#64748b",
    success = "#00815f",
    info = "#1aa9fc",
    warning = "#e8c468",
    danger = "#d70427",
    light = "#f8fafc",
    dark = "#1f2933"
  ),
  bs4dash_color(
    blue = "#2f6fa3",
    lightblue = "#1aa9fc",
    navy = "#1d3658",
    green = "#00815f",
    orange = "#f38c38",
    red = "#d70427",
    gray_x_light = "#eef3f5",
    gray_600 = "#64748b",
    gray_800 = "#334155",
    gray_900 = "#1f2933",
    white = "#ffffff",
    black = "#111827"
  ),
  bs4dash_yiq(
    contrasted_threshold = 160,
    text_dark = "#1f2933",
    text_light = "#ffffff"
  )
)
