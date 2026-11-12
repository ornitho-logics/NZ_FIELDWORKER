# Field Manual readers

The Field Manual panel opens the **Core Team Field Guide**, with a prominent
switch to the **Full Protocol Manual**. Both readers are static, searchable,
printable pages; neither needs a database, CDN, or new runtime dependency.
An **English / Deutsch** switch provides both manuals in standard German as
well as English. English remains the reference text; the German translation
should be reviewed by the team before relying on its terminology.

## Sources and generated pages

| Purpose | Authoritative Markdown source | Generated reader |
| --- | --- | --- |
| Short daily-use guide | [core-guide.md](core-guide.md), Edition 2 | [core-guide.html](core-guide.html), app default |
| Full procedures and exceptions | [manual.md](manual.md), v2.4.22 | [index.html](index.html), existing URL preserved |
| German short guide | [core-guide-de.md](core-guide-de.md), translation | [core-guide-de.html](core-guide-de.html) |
| German full reference | [manual-de.md](manual-de.md), translation | [index-de.html](index-de.html) |

Edit these app Markdown sources directly. Do not maintain a second review copy.
Update both translations when their corresponding English source changes.
The full reference retains its section anchors, controlled values, detailed
requirements, and authorship/AI disclosure. The guide links to those procedures;
it does not introduce independent scientific rules.

After changing a source, the shared CSS, or the shared JavaScript, rebuild
all four pages from the repository root:

```sh
Rscript --vanilla main/tools/render_field_manual.R
```

The builder converts links between the Markdown sources into HTML links for
browser readers while preserving section fragments. Each HTML page embeds its
own source checksum, the shared styles, and the shared search code. Repeated
builds with unchanged inputs must produce identical pages.

Each German source starts with an `English-source-md5` HTML comment recording
the English source it translates. After reviewing a translation against changed
English text, update this checksum using `tools::md5sum()` on the corresponding
English Markdown file. Do not update the checksum without reviewing the text.
The builder checks both translation references before writing any HTML and
stops on a stale or missing reference. This is a freshness guard, not proof
of translation quality or field-server deployment. Numeric limits, code values,
field names, and scientific rules must remain unchanged across languages.

The optional single builder argument remains a deliberate import into
`manual.md` for an explicitly approved external publication source. It does not
import the core guide or keep private working files synchronized. Review any
import before building: everything under `main/www` is browser-readable. Never
publish private records, coordinates, credentials, or operational reports.

## Reading and checking

- The two navigation links identify the current reader and work in the app or
  in a separate browser window. No additional sidebar item is needed.
- The language links retain the current manual kind and stable section anchor.
  Switching between the short and full manuals retains the selected language.
  Language selection is URL-based, with no cookie, tracking, or database write.
  Unstable generated search-passage IDs are not transferred across languages.
- Search applies only to the selected document and sends no query to a server.
  Each result identifies its section. The full manual retains expand/collapse
  controls; the short guide is open text without unnecessary collapse controls.
- Print opens the full manual's sections and restores their previous state
  afterwards. Both readers use the existing A4 print styling; no fixed printed
  page count is promised.
- Both readers offer Markdown downloads and a separate-window link. The full
  disclosure retains the workaround for GitHub links in the embedded app.
- Comments cannot replace required event records: a bird identity in NESTS
  comments is not a RESIGHTINGS event or parent-association evidence. This
  reminder appears in both documents and the end-of-day checks.

Run the focused `test-field-manual.R` checks only within the approved local
testing scope. Inspect both readers at phone and desktop widths, including
search, navigation, full-procedure links, printing, and old section URLs.
These checks require no field data or database connection.

## Reconstruction and cleanup

The superseded `docs/field-manual-review/` review copies and relocation checklist
are removed; Git history retains them. The [reconstruction package](../../../docs/reconstruction/README.md),
machine-readable agent recipe, synthetic fixtures, and specialist handoffs remain.
For association semantics and verification limits, use the
[parent-association contract](../../../docs/reconstruction/PARENT_ASSOCIATION_CHRONOLOGY.md),
not an old draft's version label or a successful documentation build.

No SQL, inspector, database, or service-worker policy change is part of this
reader update. The app must be updated through the human-controlled deployment
workflow before users see the new default. Git merge is not deployment.

Rollback: restore the previous reviewed reader sources/builder and the former
`main/ui.R` manual iframe/link, then rebuild. Do not revert unrelated app or
database changes. The full manual remains at its existing URL throughout.
