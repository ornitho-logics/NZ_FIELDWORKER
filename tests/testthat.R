library(testthat)

results <- test_dir(
  file.path("tests", "testthat"),
  reporter = "progress",
  stop_on_failure = FALSE
)

expectations <- unlist(
  lapply(results, `[[`, "results"),
  recursive = FALSE
)

count_expectations <- function(classes) {
  sum(vapply(
    expectations,
    function(expectation) {
      any(vapply(
        classes,
        function(class_name) inherits(expectation, class_name),
        logical(1)
      ))
    },
    logical(1)
  ))
}

summary <- data.frame(
  passed = count_expectations("expectation_success"),
  failed = count_expectations(c("expectation_failure", "expectation_error")),
  skipped = count_expectations("expectation_skip"),
  warnings = count_expectations("expectation_warning")
)

write.csv(
  summary,
  file.path("tests", "test-results.csv"),
  row.names = FALSE,
  quote = FALSE
)

if (summary$failed > 0) {
  stop("Test failures.", call. = FALSE)
}
