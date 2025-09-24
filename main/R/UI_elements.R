


HR <- function() {
  a(hr(style = "border-top: 1px solid #00a897;"))
}

S <- function(x = "-------", z = 1) {
  v <- str_split(x, ":", simplify = TRUE)
  if (length(v) == 2) {
    v <- glue("{em(v[1])}:{v[2]}")
  }
  v <- HTML(v)

  switch(z,
    "1" = strong(v, style = "color:#b3dbbf"),
    "2" = strong(v, style = "color:#f3ffbd"),
    "3" = strong(v, style = "color:#ffb6a3"),
    "4" = strong(v, style = "color:#e8c468"),
    "5" = strong(v, style = "color:#b8d2ff")
  )
}
