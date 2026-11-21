function(input, output, session) {
  status <- reactiveVal(NULL)
  attempt <- 0L
  output$save_status <- renderUI({
    result <- status()
    if (is.null(result)) return(NULL)
    style <- switch(result$state, success = "success", uncertain = "warning", "danger")
    tags$div(class = paste("alert", paste0("alert-", style)),
             role = if (result$state == "success") "status" else "alert",
             `data-attempt` = result$attempt, result$message)
  })

  feedback <- function(state, message) {
    status(list(state = state, message = message, attempt = attempt))
    session$sendCustomMessage("journal-save-result", list(state = state))
  }

  observeEvent(input$save, {
    attempt <<- attempt + 1L
    photo <- tryCatch(journal_photo(input$photo), error = identity)
    if (inherits(photo, "error")) {
      feedback("error", conditionMessage(photo))
      return()
    }

    saved <- tryCatch(journal_save(input$date, input$observer, input$entry, photo),
                       error = identity)

    if (inherits(saved, "error")) {
      result <- journal_save_failure(saved)
      feedback(result$state, result$message)
      return()
    }

    updateTextAreaInput(session, "entry", value = "")
    session$sendCustomMessage("journal-photo-reset", list(reset = TRUE))
    feedback("success", paste0("Entry saved to the database (reference #", saved$pk,
                                "). You can add another observation."))
  }, ignoreInit = FALSE)
}
