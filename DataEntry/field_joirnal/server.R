function(input, output, session) {
  upload_version <- reactiveVal(0L)
  status <- reactiveVal("")

  output$photo_upload <- renderUI({
    upload_version()
    tagList(
      fileInput("photo", "Photo (optional)", accept = "image/*",
                buttonLabel = "Choose photo", placeholder = "No photo selected",
                width = "100%"),
      helpText(paste("Maximum photo size:", format(journal_photo_limit, big.mark = ","), "bytes."))
    )
  })
  output$save_status <- renderText(status())

  observeEvent(input$save, {
    photo <- NULL
    if (!is.null(input$photo)) {
      # A storage limit, independent of biological entry validation.
      if (input$photo$size > journal_photo_limit) {
        status("This photo is too large. Choose a smaller photo and save again.")
        return()
      }
      photo <- tryCatch(
        readBin(input$photo$datapath, "raw", n = journal_photo_limit + 1L),
        error = function(e) NULL
      )
      if (is.null(photo) || length(photo) > journal_photo_limit) {
        status("The photo could not be attached. Choose the photo again and retry.")
        return()
      }
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
    upload_version(upload_version() + 1L)
    status("Entry saved. You can add another observation.")
  }, ignoreInit = TRUE)
}
