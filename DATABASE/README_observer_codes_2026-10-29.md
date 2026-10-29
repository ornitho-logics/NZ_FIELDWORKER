# Observer codes containing digits

This narrow follow-up permits two or three uppercase ASCII letters or digits,
including `P3`, using `^[A-Z0-9]{2,3}$`. Existing alphabetic codes remain valid;
lowercase, punctuation and codes outside the length limit remain invalid.
Numeric-only codes also satisfy this format. Do not rename existing observers
or rewrite historical records to adopt it.

The existing `varchar(3)` columns already store these values. No column
widening, new table/column, views installation, To-Do refresh, or new dependency
is required. `RESIGHTINGS_PUBLIC.observer` remains source-provided free text.
`observer_upload` is a CAPTURES-only field; do not add it to other tables.

## Repository changes versus installation

The five tracked hard-inspector exports and the reviewed local protocol mirror
are updated. Current observer registration/active-date rules and other validators
are unchanged. The external canonical YAML is not synchronized by this change.
Merging the branch does not update the live DB-stored inspectors or field hints.

### 1. Install the validator fragments

Back up `inspectors` privately and stop concurrent inspector editing. Select
`FIELD_2026_BADOatNZ` in Adminer, enable **Stop on error**, and execute the whole
`update_observer_code_validators_2026-10-29.SQL` file in one request. It updates
only the relevant fragments in the five existing `TABLE_hard` rows rather than
overwriting whole lists. Missing, duplicate, custom/differently formatted rows,
the wrong selected database, or a non-InnoDB inspectors table fail closed. A
failed preflight or post-update verification rolls back without committing.

Require the final `PASS`. An already-installed patch also passes without
changing the code. A `FAIL` is not permission to replace entire lists or weaken
the guard: inspect the deployment difference first. Unexpected SQL errors must
be investigated before a retry. Start new data-entry sessions so cached
validators reload. If editing DB-managed code through the inspector management
app instead, apply the same targeted fragments to the five reviewed hard rows;
preserve any additional approved live rules.

### 2. Update the six descriptive field hints

Execute the complete `observer_code_field_hints_2026-10-29.SQL` file. This is a
read-only query that generates statements from actual column metadata. Require
six `PASS` rows. Save the six `rollback_sql` **result values** privately, then
execute only the six `apply_sql` **result values** in a new Adminer SQL command
with **Stop on error**. Do not accidentally execute rollback values. Adminer's
SQL export can contain the generating query instead of the generated values.

These hint changes are optional for accepting `P3`, but recommended for clear
form guidance. They modify only
comments, preserve types/defaults/charset/collation and require
`ALGORITHM=INSTANT, LOCK=NONE`. They can still need a short metadata lock. Stop
on failure; do not remove the algorithm/lock requirements. Each ALTER commits
separately, so a failure can leave some comments updated. Do not import the
complete `main_tables.SQL` as an upgrade.

The generator fails closed under `NO_BACKSLASH_ESCAPES`, rather than emitting
incorrectly quoted rollback comments. Generated commands explicitly use the
inspected session SQL mode; they do not change the global server configuration.

### 3. Register and use the code

If not already registered, add the approved `P3` code with the correct person
and actual active dates through the OBSERVERS management form. No person, dates,
device IDs or other roster details are invented or inserted by these scripts.
Use exactly the same code on internal observation/capture forms. Existing
registration and date checks still apply; this is not a validation bypass.

## Verification and rollback

The focused `test-observer-codes.R` suite executes the actual parsed format,
uploader and active-observer validator expressions with invented examples.
It also checks the local protocol and installation safeguards. No live database
or confidential snapshot is needed for these tests.

The actual installation SQL was additionally exercised with invented-only
tables on an isolated no-network MariaDB 11.8.9 instance. Thirteen scenarios
passed: exact five-row source transformation, safe rerun, missing/duplicate/
custom rows, wrong database, nontransactional engine, failed-verification
rollback, six hint updates preserving attributes/records, exact original-comment
restoration with apostrophes/backslashes, unsupported generation SQL mode,
unexpected column metadata and wrong-database hint generation. The test server
was shut down afterwards. No live installation or production timing is claimed.

For manual portal verification, use an approved active code in a new session:
the format check should accept `P3`, reject `p3`/`P-3`/four-character codes, and
still reject unregistered/inactive observation codes. Do not submit invented
field records to production merely to test this feature.

To undo the validator change, restore the five affected inspector rows from
the private pre-change backup through the existing inspector management
workflow, then reopen data-entry sessions. Restoring an old alphabetic-only
validator may flag real records entered with a digit-containing code; do not
delete or rename those records as a rollback shortcut. Use the saved six
original-comment statements for hint-only rollback. Ordinary transaction
ROLLBACK does not undo the comment DDL. No raw field records need restoration.
