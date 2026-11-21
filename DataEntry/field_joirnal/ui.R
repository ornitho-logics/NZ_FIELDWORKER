fluidPage(
  tags$head(
    tags$title("Field journal"),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$script(src = "journal-photo.js?v=2"),
    tags$style(HTML("
      body { background: #f2f5f1; color: #263c34; font-family: system-ui, sans-serif; }
      .journal-shell { max-width: 760px; margin: 5vh auto; padding: 0 12px; }
      .journal-card { background: white; border: 1px solid #dce5dc;
        border-radius: 20px; padding: clamp(20px, 5vw, 44px);
        box-shadow: 0 12px 36px rgba(30, 60, 45, .07); }
      .journal-eyebrow { color: #526f5e; text-transform: uppercase;
        letter-spacing: .15em; font-size: 12px; font-weight: 700; }
      h1 { font-weight: 700; margin-top: 12px; }
      .journal-intro { color: #61716b; line-height: 1.7; margin-bottom: 28px; }
      .form-control { border-radius: 8px; border-color: #ccd8cf; }
      textarea.form-control { resize: vertical; line-height: 1.6; }
      .journal-save { background: #285d47; color: white; border: 0;
        border-radius: 10px; padding: 12px 24px; font-weight: 600; width: 100%; }
      .journal-save:hover, .journal-save:focus { background: #1e4937; color: white; }
      .journal-status { margin-top: 16px; }
      .journal-status .alert { border-radius: 10px; margin-bottom: 0; line-height: 1.6; }
      .journal-save:disabled { opacity: .65; cursor: wait; }
      #photo-preview { display: block; max-width: 100%; max-height: 360px;
        border-radius: 10px; margin: 12px 0; object-fit: contain; }
      #photo-preview[hidden], #photo-remove[hidden] { display: none; }
      .journal-photo { margin-bottom: 24px; }
      .journal-photo label { display: block; }
    "))
  ),
  div(class = "journal-shell",
    div(class = "journal-card",
      div(class = "journal-eyebrow", "Notes from the field"),
      h1("Field journal"),
      p(class = "journal-intro",
        "Record migratory groups, unusual sightings, bad weather, and other environmental events."),
      fluidRow(
        column(6, dateInput("date", "Observation date", value = journal_today(),
                            format = "yyyy-mm-dd", width = "100%")),
        column(6, textInput("observer", "observer",
                            width = "100%"))
      ),
      textAreaInput("entry", "Field journal entry", rows = 9,
                    placeholder = "Describe the observation and any useful context…",
                    width = "100%"),
      div(class = "journal-photo",
        # No id/name: Shiny must not bind this input and upload the original.
        tags$label("Photo (optional)",
          tags$input(class = "journal-photo-picker", type = "file", accept = "image/*")
        ),
        helpText("Photos are resized before upload. Your original stays unchanged."),
        tags$img(id = "photo-preview", alt = "Photo prepared for this entry", hidden = NA),
        tags$p(id = "photo-status", role = "status", `aria-live` = "polite"),
        tags$button(id = "photo-remove", type = "button", class = "btn btn-default",
                    hidden = NA, "Remove photo")
      ),
      actionButton("save", "Connecting…", icon = icon("check"), class = "journal-save",
                   disabled = NA),
      div(class = "journal-status", role = "status", `aria-live` = "polite",
          uiOutput("save_status"))
    )
  )
)
