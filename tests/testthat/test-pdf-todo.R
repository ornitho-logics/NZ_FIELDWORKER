test_that("tagged-bird PDF follow-up uses the strict unseen threshold", {
  app <- load_main_app()
  prepare <- app$env$todo_pdf_prepare_unseen_tagged_birds

  view_1 <- data.frame(
    mark = c("MOCK-B", "MOCK-A", "MOCK-C", "MOCK-D", "MOCK-E"),
    sex = c("F", "M", "F", "M", "F"),
    nest_id = c("MOCK_NEST_02", "MOCK_NEST_01", NA, "MOCK_NEST_04", NA),
    days_since_cap = c(12, 15, 8, 20, 7),
    days_since_last_seen = c(NA, NA, NA, 3, NA)
  )

  observed <- prepare(view_1)

  expect_identical(
    names(observed),
    c("Mark", "Sex", "Nest", "Days Since Cap")
  )
  expect_identical(observed$Mark, c("MOCK-A", "MOCK-B", "MOCK-C"))
  expect_identical(observed$Nest, c("MOCK_NEST_01", "MOCK_NEST_02", ""))
  expect_identical(observed$`Days Since Cap`, c("15", "12", "8"))
})


test_that("tagged-bird follow-up table is included in the PDF body", {
  app <- load_main_app()
  body <- app$env$todo_pdf_body(
    rows = data.table::data.table(),
    unseen_tagged_birds = data.table::data.table(
      Mark = "MOCK-A",
      Sex = "M",
      Nest = "MOCK_NEST_01",
      `Days Since Cap` = "15"
    )
  )

  expect_true(any(grepl("## Tagged birds to resight", body, fixed = TRUE)))
  expect_true(any(grepl(
    paste(
      "The following tagged birds have not been seen since tag deployment,",
      "please resight and assess walking ability"
    ),
    body,
    fixed = TRUE
  )))
})
