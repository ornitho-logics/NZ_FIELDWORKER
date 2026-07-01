render_todo_table <- function(expr) {
  DT::renderDataTable(
    {
      x <- expr
      shiny::req(x)
      x
    },
    server = FALSE,
    rownames = TRUE,
    escape = FALSE,
    extensions = c("Scroller", "Buttons"),
    options = list(
      dom = "Blfrtip",
      buttons = list(
        "copy",
        list(
          extend = "collection",
          buttons = c("excel", "pdf"),
          text = "Download"
        )
      ),
      scrollX = "600px",
      deferRender = TRUE,
      scrollY = 900,
      scroller = TRUE,
      searching = TRUE,
      columnDefs = list(list(className = "dt-center", targets = "_all"))
    ),
    class = c("compact", "stripe", "order-column", "hover")
  )
}
