# Tested through the installed DataEntry parser, issue combiner, and save gate.
# A stored inspector must return the expected zero-row issue schema, not list().
# This is NOT a replacement for archiving the original live inspector rows.
list(
    try_validator(
        data.table::data.table(
            rowid = integer(),
            variable = character(),
            reason = character()
        ),
        nam = "TEMPORARY validation pause"
    )
)
