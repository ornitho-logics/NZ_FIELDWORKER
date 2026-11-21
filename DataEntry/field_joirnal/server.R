function(input, output, session) {
  status <- reactiveVal("")
  output$save_status <- renderText(status())

  observeEvent(input$save, {
    photo <- tryCatch(journal_photo(input$photo), error = identity)
    if (inherits(photo, "error")) {
      status(conditionMessage(photo))
      return()
    }

    saved <- tryCatch({
      journal_save(input$date, input$observer, input$entry, photo)
      TRUE
    }, error = function(e) FALSE)

    if (!saved) {
      status("Could not save the entry. Your form is still here; please try again.")
      return()
    }

    updateTextAreaInput(session, "entry", value = "")
    session$sendCustomMessage("journal-photo-reset", list(reset = TRUE))
    status("Entry saved. You can add another observation.")
  }, ignoreInit = TRUE)
}
