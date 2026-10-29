# Field Manual reader

`manual.md` is the reviewed app publication copy; `index.html` is its generated,
self-contained reader. The page needs no database, CDN, server-side search or
new runtime package. Calibri/Arial typography follows the field handbook.

After editing this app copy, rebuild from the repository root:

```sh
Rscript --vanilla main/tools/render_field_manual.R
```

To deliberately publish an updated private review draft, pass its path as the
sole argument. This replaces **only** the app copy and rebuilds its HTML. Review
the diff first: all files under `main/www` are browser-readable. Never import
private records, coordinates, credentials or unpublished operational reports.
The private review draft is not loaded at runtime or silently kept in sync.

`manual.css` and `manual.js` are embedded during the build, making the reading
page usable as a standalone saved HTML file. Contents links open collapsed
sections. Search is literal, case-insensitive and requires all entered words
within a passage; it shows up to 80 passage links with section context. It does
not send queries to a server or store them. Table content is searchable. Clear
or Escape removes highlighting. Print opens every section and restores its
previous state afterwards; the print layout is A4.

The page retains the review-draft and unverified-deployment notices. Adding a
tab does not install the database or inspector changes described in the text.
No service-worker/offline-cache policy is changed by this feature.

Rollback: remove only the Field Manual menu item and tab from `main/ui.R`, plus
this directory, `main/tools/render_field_manual.R` and its dedicated test. Do
not revert unrelated changes in the shared checkout. Keep the private review
draft and retained Word manual.
