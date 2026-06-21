


HR <- function() {
  a(hr(style = "border-top: 1px solid #9aaeb6;"))
}

S <- function(x = "-------", z = 1) {
  v <- str_split(x, ":", simplify = TRUE)
  if (length(v) == 2) {
    v <- glue("{em(v[1])}:{v[2]}")
  }
  v <- HTML(v)

  switch(z,
    "1" = strong(v, style = "color:#1d3658"),
    "2" = strong(v, style = "color:#d70427"),
    "3" = strong(v, style = "color:#ffb6a3"),
    "4" = strong(v, style = "color:#e8c468"),
    "5" = strong(v, style = "color:#b8d2ff")
  )
}

# box title style
bttl <- function(text, color = "#8a2d02",  weight = "bold", icon = NULL) {
  icon_html <- if (!is.null(icon)) sprintf("<i class='fas fa-%s'></i> ", icon) else ""
  HTML(sprintf(
    "<span style='font-weight: %s; color: %s; '>%s%s</span>",
    weight, color, icon_html, text
  ))
}


select_combo_list <- function() {
  DBq("SELECT DISTINCT UL, LL, UR, LR FROM CAPTURES where tag_id is not NULL") |>
    make_combo(short = "LR")
}


spinner <- function(x) {

  shinycssloaders::withSpinner(x, 
  image = 'animated_ICO.png',
  image.width = "100cqw")

}
