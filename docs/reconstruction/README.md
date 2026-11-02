# Reconstructing and adapting FIELDWORKER

Start here without relying on chat history. This package describes the existing
reference system and a controlled route to a new study. It does not change the
running app, its forms, scientific rules, or deployment.

## Read order

1. Repository `AGENTS.md`: permissions and confidentiality.
2. [CURRENT_SYSTEM.md](CURRENT_SYSTEM.md): effective architecture and rule authority.
3. [ADAPTATION.md](ADAPTATION.md): scientific decisions that cannot be copied blindly.
4. [DEPENDENCIES.md](DEPENDENCIES.md) and [environment.lock.json](environment.lock.json).
5. [workflow.json](workflow.json): the machine-readable agent recipe.
6. [rules.json](rules.json): operational-rule/source/test/manual crosswalk.
7. [acceptance.json](acceptance.json): checks, required evidence, and missing-evidence policy.

[VERIFICATION.md](VERIFICATION.md) records the completed synthetic checks and
remaining integration limits. It is evidence about this kit, not new-study approval.

Luke's approved decision of **1 November 2026** supersedes the earlier blanket
same-day X-X restriction: confirming X-X and a unique eligible status-F first
banding of the same sex, nest, and date target the same individual, including MM
without later sightings. Same-day confirmation transfers with linked proof
conservatively dated at capture datetime, without inventing observed time/order.
First-marking uniqueness counts all eligible F identity keys before later-proof
or ambiguity filters; those filters cannot manufacture uniqueness from multiple
captured identities.
Different-day older proof cannot transfer; the new identity still needs its own
qualifying proof, which can now include its own same-day confirming linkage.
See [the chronology contract](PARENT_ASSOCIATION_CHRONOLOGY.md),
[intended cases](parent-association-cases.json) and manual v2.4.14. All eligibility,
ambiguity, displacement, timing, and tag guards remain; unrelated same-day rules
are unchanged. The [new source-bound verification](SAME_DAY_LINKAGE_VERIFICATION_2026-11-01.md)
records 1,004 passing assertions and a fresh isolated synthetic MariaDB 11.8.9
install/refresh, with field/PDF/live/browser limits stated separately. Prior
dated PASS results are not silently extended to this changed source.

The versioned validator YAML and inspector exports remain the detailed save-time
contract. This package complements them; it does not generate new validators
or override scientific decisions. Dated handoffs/logs explain history. A
conflicting historical instruction must be reported, not selected opportunistically.

## Writing convention

Use the Oxford comma in every prose list of three or more items, including
before the final "and" or "or". This applies to manuals, protocol descriptions,
inspector messages, and agent handoffs. Follow the rule in `AGENTS.md` when
adapting this package; do not alter code syntax or scientific meaning to change
punctuation. Verbatim historical quotations retain their original wording.

## Start an agent on any platform

Give the coordinator this prompt, with the repository attached:

> Read AGENTS.md and docs/reconstruction/README.md, then validate and follow
> docs/reconstruction/workflow.json in order. Use reference_reproduction first.
> For a new study, make a private copy of study-template.json, collect explicit
> scientific decisions, and use study_adaptation only after its decision gate
> passes. Create the named specialist roles using your platform's agent feature;
> if delegation is unavailable, perform each role sequentially with the same
> artifacts and an independent human review. Do not treat profile fields as
> settings already consumed by the app. Do not connect to production, use real
> records, alter the reference app, publish, or deploy without the required authority.
> Report every acceptance item as PASS, FAIL, NOT RUN, or NOT AVAILABLE and stop
> at a failed required gate. Produce a reviewable adaptation before asking for
> deployment approval. Keep unresolved biological choices unresolved.
> Use the Oxford comma in documentation, inspector messages, and handoffs.

No Codex/Claude/Gemini API, model name, thread ID, plugin, or chat transcript is
required. `spawn` in the recipe means the platform's equivalent worker-agent
operation. Delegation authorisation for a real run must come from that run's
human or applicable project instructions; the JSON is a recipe, not permission
to contact people or existing chats.

## Development-only commands

From the repository root:

Provision Python 3, the recorded R version, and MariaDB 11.8.9 first. The R
metadata/installer tools need `jsonlite`; obtain its exact version/source from
environment.lock.json (readable with Python's standard `json` module) rather
than assuming it is included with base R. A minimal package-manager/bootstrap
environment is a prerequisite to materialising the full lock, not proof that
the app's dependencies are already installed. See DEPENDENCIES.md for native
spatial/graphics requirements and the subsequent package-source plan.

```sh
python3 tools/reconstruction/verify.py
Rscript --vanilla tools/reconstruction/runtime_inventory.R --check
python3 tools/reconstruction/bootstrap.py --mariadb-bin /path/to/mariadb/bin
```

`install_environment.R` prints the pinned source installation plan by default.
To materialise pins after reviewing it, supply `--apply --library /new/library`;
the path must not already exist. `--only gpxui` repairs just that missing
dependency in a new isolated overlay using the exact public commit in
external-sources.json. Prepend the overlay per process using R_LIBS, preserving
existing library paths and any existing R_LIBS entries; never do this
by changing the app's existing package library. Source compilation needs the
documented native toolchain; a failed install does not authorize substituting
latest versions. R recommended packages must match the recorded R distribution.

The first command validates the recipe, crosswalk, local references, and absence
of changes to protected app/runtime paths since the documented reference.
For an approved adaptation, use `verify.py --mode study_adaptation --study
/path/approved-study.json --approved-changes /path/approved-changes.json
--reference-root /path/retained-reference-checkout`. Fill the literal-file
change-approval template first. The retained control must remain unchanged;
the target is checked against the named approved changes instead of rejecting
all legitimate adaptations. The default bootstrap always tests the reference,
not an arbitrary adapted runtime.
The second compares installed dependency metadata with the captured reference
lock; it loads no app or database configuration and installs nothing.
The third starts a NEW owned Unix-socket-only MariaDB instance, creates only
invented fixtures, installs the unmodified SQL, loads inspector exports into
that instance, executes the real refresh and focused SQL tests, installs the
historical view, checks publication/date transitions, and writes a JSON report.
Use Linux/macOS; use a Linux environment such as WSL for Windows. Neither a
running service nor a user-supplied socket/configuration/dump is accepted.
On macOS the runner creates a new sparse APFS case-sensitive volume, records
its owned device, and detaches it after server shutdown. Linux needs a
case-sensitive filesystem. The runner requires lower_case_table_names=0,
matching the complete reference replay; native macOS value 2 is not a full
refresh substitute. No existing disk image or database directory is reused.

Use `--render` for the additional production PDF-helper render. The renderer
uses the synthetic instance only.
The example uses production table/PDF and map-panel helpers with a test I/O
adapter for invented landmarks and absent satellite imagery; it never downloads
background tiles or claims production network/map-save integration coverage.
Every resulting page must also receive an
explicit visual review before PDF acceptance can pass; a file existing is not
that review. After inspecting every page image, use `record_review.py --report
/path/report.json --reviewer NAME --note TEXT --page-images /path/page-1.png
/path/page-2.png --attest-all-pages-reviewed`. Supply `--pdfinfo /path/pdfinfo`
if it is not on PATH. The tool requires all pages, binds PDF/image hashes, and
writes a new reviewed-report.json without rewriting original run evidence.
See `--help` and acceptance.json. Missing tools produce NOT RUN,
not a silently green full acceptance result. Only the selected focused tests
run; the app and its ordinary full test entrypoint are never started.

Reports and server files go to a new ignored `tmp/codex/` directory. Server
shutdown is owned by the runner; artifacts remain available. No full field dump,
production credentials, network connection, real map, or external historical
database is needed. The small archive tables in fixtures are structural mocks.
Do not use `_reset.SQL` for this workflow or for upgrading an existing database.

## What counts as reproduced

Reference reproduction means the captured source plus an explicitly compatible
environment passes the synthetic acceptance contract. It does not prove current
field-data correctness, live Adminer speed, welfare suitability for a new species,
or equality to unavailable older golden artifacts. Reproduction of the Shiny
package/browser integration requires a separately authorised browser review;
the mock checks do not substitute for it.

For a new study, keep reference fixtures unchanged as a control. Add separately
approved study fixtures and expected results, then produce a new source/decision/
environment manifest. No study-specific rule is enabled just because a reference
test passes. Operator approval, production setup, and live verification are
separate recorded steps. Never package real data to make the kit reproducible.

## Release and rollback

Record the exact source commit, file hashes, protocol version, environment,
approved study profile, and acceptance report together. The initial reference is
`9e010e5`; it is a selected source, not an assertion of deployment. Re-pin a future
approved reference deliberately, keeping the original comparison available.
The runtime lock is development metadata and has no auto-activation hook.

To remove this package, revert only its documentation/development-tool changes.
For the reconstruction package itself there is no app runtime or live database
migration to undo. The separately authorized 31 October MM/X-X source correction
and capture-field hint alignment have their own scope and rollback in
[the chronology contract](PARENT_ASSOCIATION_CHRONOLOGY.md) and
[hint instructions](../../DATABASE/README_capture_mark_field_hints_2026-10-31.md).
Do not reuse the old reference PASS for those later changes. The package does
not automatically install field-comment changes: the separately reviewed hint
generator returns commands for human-controlled application only. See the
[follow-up verification](MM_FOLLOWUP_VERIFICATION_2026-10-31.md) for its own
source provenance, synthetic results, and remaining release limits.
